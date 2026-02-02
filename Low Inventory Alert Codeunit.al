codeunit 50103 "Low Inventory Alert"
{
    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Item Jnl.-Post Line", 'OnAfterInsertItemLedgEntry', '', false, false)]
    local procedure OnAfterInsertItemLedgEntry(var ItemLedgerEntry: Record "Item Ledger Entry"; ItemJournalLine: Record "Item Journal Line")
    var
        MfgSetup: Record "Manufacturing Setup";
    begin
        // DEBUG: Event subscriber fired
        Message('DEBUG: Event fired for Item %1, Qty %2', ItemLedgerEntry."Item No.", ItemLedgerEntry.Quantity);

        // Check if alerts are enabled
        if not MfgSetup.Get() then begin
            Message('DEBUG: Could not get Manufacturing Setup');
            exit;
        end;

        if not MfgSetup."Enable Inventory Alerts" then begin
            Message('DEBUG: Alerts not enabled');
            exit;
        end;

        if (MfgSetup."Logic Apps Endpoint URL" = '') then begin
            Message('DEBUG: URL is empty');
            exit;
        end;

        // Only process negative quantity entries (inventory decreases)
        if ItemLedgerEntry.Quantity >= 0 then begin
            Message('DEBUG: Quantity is not negative (%1)', ItemLedgerEntry.Quantity);
            exit;
        end;

        Message('DEBUG: Calling CheckInventoryThresholdCrossing');
        CheckInventoryThresholdCrossing(ItemLedgerEntry);
    end;

    local procedure CheckInventoryThresholdCrossing(ItemLedgerEntry: Record "Item Ledger Entry")
    var
        Item: Record Item;
        InventoryBeforePosting: Decimal;
        InventoryAfterPosting: Decimal;
        SafetyStockQty: Decimal;
    begin
        if not Item.Get(ItemLedgerEntry."Item No.") then begin
            Message('DEBUG: Could not get Item');
            exit;
        end;

        SafetyStockQty := GetSafetyStockForLocation(ItemLedgerEntry."Item No.", ItemLedgerEntry."Location Code");
        Message('DEBUG: Safety Stock = %1', SafetyStockQty);

        if SafetyStockQty = 0 then begin
            Message('DEBUG: Safety Stock is 0, exiting');
            exit;
        end;

        // Calculate inventory BEFORE this posting
        InventoryBeforePosting := CalculateInventoryAtPoint(
            ItemLedgerEntry."Item No.",
            ItemLedgerEntry."Location Code",
            ItemLedgerEntry."Entry No." - 1
        );

        // Calculate inventory AFTER this posting
        InventoryAfterPosting := InventoryBeforePosting + ItemLedgerEntry.Quantity;

        Message('DEBUG: Before=%1, After=%2, SafetyStock=%3', InventoryBeforePosting, InventoryAfterPosting, SafetyStockQty);

        // THRESHOLD CROSSING: Alert only if we crossed from ABOVE to BELOW
        if (InventoryBeforePosting > SafetyStockQty) and (InventoryAfterPosting <= SafetyStockQty) then begin
            Message('DEBUG: Threshold crossed! Sending alert...');
            SendInventoryAlert(ItemLedgerEntry, InventoryAfterPosting, SafetyStockQty);
        end else begin
            Message('DEBUG: No threshold crossing. Before>Safety? %1, After<=Safety? %2',
                InventoryBeforePosting > SafetyStockQty,
                InventoryAfterPosting <= SafetyStockQty);
        end;
    end;

    local procedure GetSafetyStockForLocation(ItemNo: Code[20]; LocationCode: Code[10]): Decimal
    var
        StockkeepingUnit: Record "Stockkeeping Unit";
        Item: Record Item;
    begin
        // Try location-specific safety stock first
        StockkeepingUnit.SetRange("Item No.", ItemNo);
        StockkeepingUnit.SetRange("Location Code", LocationCode);
        if StockkeepingUnit.FindFirst() then
            exit(StockkeepingUnit."Safety Stock Quantity");

        // Fallback to item-level safety stock
        if Item.Get(ItemNo) then
            exit(Item."Safety Stock Quantity");

        exit(0);
    end;

    local procedure CalculateInventoryAtPoint(ItemNo: Code[20]; LocationCode: Code[10]; UpToEntryNo: Integer): Decimal
    var
        ItemLedgEntry: Record "Item Ledger Entry";
        TotalQty: Decimal;
    begin
        TotalQty := 0;
        ItemLedgEntry.SetCurrentKey("Item No.", "Entry Type", "Location Code", "Posting Date");
        ItemLedgEntry.SetRange("Item No.", ItemNo);
        ItemLedgEntry.SetRange("Location Code", LocationCode);
        ItemLedgEntry.SetRange("Entry No.", 0, UpToEntryNo);

        if ItemLedgEntry.FindSet() then
            repeat
                TotalQty += ItemLedgEntry.Quantity;
            until ItemLedgEntry.Next() = 0;

        exit(TotalQty);
    end;

    local procedure SendInventoryAlert(ItemLedgerEntry: Record "Item Ledger Entry"; CurrentInventory: Decimal; SafetyStock: Decimal)
    var
        MfgSetup: Record "Manufacturing Setup";
        Client: HttpClient;
        RequestMessage: HttpRequestMessage;
        ResponseMessage: HttpResponseMessage;
        Headers: HttpHeaders;
        Content: HttpContent;
        JsonPayload: Text;
        ResponseText: Text;
    begin
        if not MfgSetup.Get() then
            exit;

        JsonPayload := BuildAlertPayload(ItemLedgerEntry, CurrentInventory, SafetyStock);

        Content.WriteFrom(JsonPayload);
        Content.GetHeaders(Headers);
        if Headers.Contains('Content-Type') then
            Headers.Remove('Content-Type');
        Headers.Add('Content-Type', 'application/json');

        RequestMessage.Method := 'POST';
        RequestMessage.SetRequestUri(MfgSetup."Logic Apps Endpoint URL");
        RequestMessage.Content := Content;

        // Add custom headers to request message if needed
        if MfgSetup."Logic Apps API Key" <> '' then begin
            RequestMessage.GetHeaders(Headers);
            Headers.Add('x-api-key', MfgSetup."Logic Apps API Key");
        end;

        // Fire-and-forget: don't fail transaction if HTTP call fails
        if Client.Send(RequestMessage, ResponseMessage) then begin
            if ResponseMessage.IsSuccessStatusCode() then begin
                // Success - log if needed
                LogAlertSuccess(ItemLedgerEntry."Entry No.", CurrentInventory, SafetyStock);
            end else begin
                // HTTP error - log but don't fail
                ResponseMessage.Content.ReadAs(ResponseText);
                LogAlertError(ItemLedgerEntry."Entry No.",
                    StrSubstNo('HTTP %1: %2', ResponseMessage.HttpStatusCode(), ResponseText));
            end;
        end else begin
            // Request failed - log but don't fail
            LogAlertError(ItemLedgerEntry."Entry No.", 'Failed to send HTTP request');
        end;
    end;

    local procedure BuildAlertPayload(ItemLedgerEntry: Record "Item Ledger Entry"; CurrentInventory: Decimal; SafetyStock: Decimal): Text
    var
        Item: Record Item;
        JsonObject: JsonObject;
        JsonText: Text;
    begin
        // Get item details
        if Item.Get(ItemLedgerEntry."Item No.") then;

        // Build simplified JSON object with only 3 fields
        JsonObject.Add('ItemNo', ItemLedgerEntry."Item No.");
        JsonObject.Add('Description', Item.Description);
        JsonObject.Add('CurrentInventory', CurrentInventory);

        JsonObject.WriteTo(JsonText);
        exit(JsonText);
    end;

    local procedure LogAlertSuccess(EntryNo: Integer; CurrentInventory: Decimal; SafetyStock: Decimal)
    var
        AlertLog: Record "Inventory Alert Log";
        ItemLedgEntry: Record "Item Ledger Entry";
    begin
        AlertLog.Init();
        AlertLog."Item Ledger Entry No." := EntryNo;

        // Get Item No. and Location Code from Item Ledger Entry
        if ItemLedgEntry.Get(EntryNo) then begin
            AlertLog."Item No." := ItemLedgEntry."Item No.";
            AlertLog."Location Code" := ItemLedgEntry."Location Code";
        end;

        AlertLog."Current Inventory" := CurrentInventory;
        AlertLog."Safety Stock" := SafetyStock;
        AlertLog."Alert Timestamp" := CurrentDateTime;
        AlertLog."Alert Status" := AlertLog."Alert Status"::Success;
        if AlertLog.Insert(true) then;
    end;

    local procedure LogAlertError(EntryNo: Integer; ErrorText: Text)
    var
        AlertLog: Record "Inventory Alert Log";
        ItemLedgEntry: Record "Item Ledger Entry";
    begin
        AlertLog.Init();
        AlertLog."Item Ledger Entry No." := EntryNo;

        // Get Item No. and Location Code from Item Ledger Entry
        if ItemLedgEntry.Get(EntryNo) then begin
            AlertLog."Item No." := ItemLedgEntry."Item No.";
            AlertLog."Location Code" := ItemLedgEntry."Location Code";
        end;

        AlertLog."Alert Timestamp" := CurrentDateTime;
        AlertLog."Alert Status" := AlertLog."Alert Status"::Failed;
        AlertLog."Error Message" := CopyStr(ErrorText, 1, MaxStrLen(AlertLog."Error Message"));
        if AlertLog.Insert(true) then;
    end;
}
