codeunit 50114 "Planning SKU Management"
{
    // Manages Stockkeeping Unit operations for planning parameter suggestions

    procedure EnsureSKUExists(ItemNo: Code[20]; LocationCode: Code[10]; VariantCode: Code[10]): Boolean
    var
        SKU: Record "Stockkeeping Unit";
        Item: Record Item;
    begin
        // Check if SKU already exists
        if SKU.Get(LocationCode, ItemNo, VariantCode) then
            exit(true);

        // Validate Item exists
        if not Item.Get(ItemNo) then
            Error('Item %1 does not exist.', ItemNo);

        // Create new SKU with Item defaults
        SKU.Init();
        SKU."Location Code" := LocationCode;
        SKU."Item No." := ItemNo;
        SKU."Variant Code" := VariantCode;

        // Copy planning parameters from Item
        CopyPlanningParametersFromItem(Item, SKU);

        // Copy other relevant fields
        SKU.Description := Item.Description;
        SKU."Unit Cost" := Item."Unit Cost";
        SKU."Standard Cost" := Item."Standard Cost";
        SKU."Last Direct Cost" := Item."Last Direct Cost";
        SKU."Vendor No." := Item."Vendor No.";
        SKU."Vendor Item No." := Item."Vendor Item No.";
        SKU."Lead Time Calculation" := Item."Lead Time Calculation";
        SKU."Replenishment System" := ConvertReplenishmentSystem(Item."Replenishment System");
        SKU."Flushing Method" := Item."Flushing Method";

        SKU.Insert(true);

        exit(true);
    end;

    local procedure CopyPlanningParametersFromItem(Item: Record Item; var SKU: Record "Stockkeeping Unit")
    begin
        SKU."Reordering Policy" := Item."Reordering Policy";
        SKU."Reorder Point" := Item."Reorder Point";
        SKU."Reorder Quantity" := Item."Reorder Quantity";
        SKU."Safety Stock Quantity" := Item."Safety Stock Quantity";
        SKU."Maximum Inventory" := Item."Maximum Inventory";
        SKU."Minimum Order Quantity" := Item."Minimum Order Quantity";
        SKU."Maximum Order Quantity" := Item."Maximum Order Quantity";
        SKU."Order Multiple" := Item."Order Multiple";
        SKU."Safety Lead Time" := Item."Safety Lead Time";
        SKU."Lot Accumulation Period" := Item."Lot Accumulation Period";
        SKU."Rescheduling Period" := Item."Rescheduling Period";
        SKU."Dampener Period" := Item."Dampener Period";
        SKU."Dampener Quantity" := Item."Dampener Quantity";
        SKU."Overflow Level" := Item."Overflow Level";
        SKU."Time Bucket" := Item."Time Bucket";
    end;

    local procedure ConvertReplenishmentSystem(ItemReplenishment: Enum "Replenishment System"): Enum "SKU Replenishment System"
    begin
        case ItemReplenishment of
            "Replenishment System"::Purchase:
                exit("SKU Replenishment System"::Purchase);
            "Replenishment System"::"Prod. Order":
                exit("SKU Replenishment System"::"Prod. Order");
            "Replenishment System"::Assembly:
                exit("SKU Replenishment System"::Assembly);
            "Replenishment System"::Transfer:
                exit("SKU Replenishment System"::Transfer);
            else
                exit("SKU Replenishment System"::Purchase);
        end;
    end;

    procedure ApplySuggestionToSKU(Suggestion: Record "Planning Parameter Suggestion"; ApplyReorderPolicy: Boolean; ApplyReorderPoint: Boolean; ApplyReorderQty: Boolean; ApplySafetyStock: Boolean; ApplyMaxInventory: Boolean; ApplyLotAccumPeriod: Boolean): Boolean
    var
        SKU: Record "Stockkeeping Unit";
        xSKU: Record "Stockkeeping Unit";
    begin
        if Suggestion."Target Level" <> Suggestion."Target Level"::SKU then
            Error('This suggestion is not for a Stockkeeping Unit. Target Level: %1', Suggestion."Target Level");

        // Create SKU if it doesn't exist and option is enabled
        if Suggestion."Create SKU If Missing" then
            EnsureSKUExists(Suggestion."Item No.", Suggestion."Location Code", Suggestion."Variant Code");

        if not SKU.Get(Suggestion."Location Code", Suggestion."Item No.", Suggestion."Variant Code") then
            Error('Stockkeeping Unit does not exist for Item %1 at Location %2.', Suggestion."Item No.", Suggestion."Location Code");

        // Backup for rollback
        xSKU := SKU;

        // Apply with transaction protection
        if not TryApplyParametersToSKU(SKU, Suggestion, ApplyReorderPolicy, ApplyReorderPoint, ApplyReorderQty, ApplySafetyStock, ApplyMaxInventory, ApplyLotAccumPeriod) then begin
            // Rollback
            SKU := xSKU;
            SKU.Modify(false);
            Error('Failed to apply suggestion to SKU: %1', GetLastErrorText());
        end;

        exit(true);
    end;

    [TryFunction]
    local procedure TryApplyParametersToSKU(var SKU: Record "Stockkeeping Unit"; Suggestion: Record "Planning Parameter Suggestion"; ApplyReorderPolicy: Boolean; ApplyReorderPoint: Boolean; ApplyReorderQty: Boolean; ApplySafetyStock: Boolean; ApplyMaxInventory: Boolean; ApplyLotAccumPeriod: Boolean)
    begin
        if ApplyReorderPolicy then
            SKU.Validate("Reordering Policy", Suggestion."Suggested Reordering Policy");

        if ApplyReorderPoint then
            SKU.Validate("Reorder Point", Suggestion."Suggested Reorder Point");

        if ApplyReorderQty then
            SKU.Validate("Reorder Quantity", Suggestion."Suggested Reorder Quantity");

        if ApplySafetyStock then
            SKU.Validate("Safety Stock Quantity", Suggestion."Suggested Safety Stock");

        if ApplyMaxInventory then
            SKU.Validate("Maximum Inventory", Suggestion."Suggested Maximum Inventory");

        if ApplyLotAccumPeriod then
            SKU.Validate("Lot Accumulation Period", Suggestion."Suggested Lot Accum Period");

        SKU.Modify(true);
    end;

    procedure GetEffectivePlanningParameters(ItemNo: Code[20]; LocationCode: Code[10]; VariantCode: Code[10]; var ReorderingPolicy: Enum "Reordering Policy"; var ReorderPoint: Decimal; var ReorderQty: Decimal; var SafetyStock: Decimal; var MaxInventory: Decimal; var LotAccumPeriod: DateFormula; var SourceLevel: Text)
    var
        SKU: Record "Stockkeeping Unit";
        Item: Record Item;
    begin
        // Try SKU first (location-specific)
        if (LocationCode <> '') and SKU.Get(LocationCode, ItemNo, VariantCode) then begin
            ReorderingPolicy := SKU."Reordering Policy";
            ReorderPoint := SKU."Reorder Point";
            ReorderQty := SKU."Reorder Quantity";
            SafetyStock := SKU."Safety Stock Quantity";
            MaxInventory := SKU."Maximum Inventory";
            LotAccumPeriod := SKU."Lot Accumulation Period";
            SourceLevel := 'Stockkeeping Unit';
            exit;
        end;

        // Fallback to Item
        if Item.Get(ItemNo) then begin
            ReorderingPolicy := Item."Reordering Policy";
            ReorderPoint := Item."Reorder Point";
            ReorderQty := Item."Reorder Quantity";
            SafetyStock := Item."Safety Stock Quantity";
            MaxInventory := Item."Maximum Inventory";
            LotAccumPeriod := Item."Lot Accumulation Period";
            SourceLevel := 'Item';
            exit;
        end;

        Error('Item %1 not found.', ItemNo);
    end;

    procedure GetSKUsForItem(ItemNo: Code[20]; var TempSKU: Record "Stockkeeping Unit" temporary)
    var
        SKU: Record "Stockkeeping Unit";
    begin
        TempSKU.Reset();
        TempSKU.DeleteAll();

        SKU.SetRange("Item No.", ItemNo);
        if SKU.FindSet() then
            repeat
                TempSKU := SKU;
                TempSKU.Insert();
            until SKU.Next() = 0;
    end;

    procedure GetLocationsWithDemand(ItemNo: Code[20]; StartDate: Date; EndDate: Date; var TempLocation: Record Location temporary)
    var
        ItemLedgerEntry: Record "Item Ledger Entry";
        Location: Record Location;
    begin
        TempLocation.Reset();
        TempLocation.DeleteAll();

        ItemLedgerEntry.SetRange("Item No.", ItemNo);
        ItemLedgerEntry.SetRange("Posting Date", StartDate, EndDate);
        ItemLedgerEntry.SetFilter("Entry Type", '%1|%2|%3',
            ItemLedgerEntry."Entry Type"::Sale,
            ItemLedgerEntry."Entry Type"::Consumption,
            ItemLedgerEntry."Entry Type"::"Negative Adjmt.");

        if ItemLedgerEntry.FindSet() then
            repeat
                if ItemLedgerEntry."Location Code" <> '' then
                    if Location.Get(ItemLedgerEntry."Location Code") then
                        if not TempLocation.Get(Location.Code) then begin
                            TempLocation := Location;
                            TempLocation.Insert();
                        end;
            until ItemLedgerEntry.Next() = 0;
    end;

    procedure BatchCreateSKUsForItem(ItemNo: Code[20])
    var
        TempLocation: Record Location temporary;
        Setup: Record "Planning Analysis Setup";
        CreatedCount: Integer;
        StartDate: Date;
    begin
        Setup.GetSetup(Setup);
        StartDate := CalcDate(StrSubstNo('<-%1M>', Setup."Default Analysis Months"), Today());

        // Get all locations with demand
        GetLocationsWithDemand(ItemNo, StartDate, Today(), TempLocation);

        if TempLocation.IsEmpty() then begin
            Message('No locations with demand history found for item %1.', ItemNo);
            exit;
        end;

        if TempLocation.FindSet() then
            repeat
                if EnsureSKUExists(ItemNo, TempLocation.Code, '') then
                    CreatedCount += 1;
            until TempLocation.Next() = 0;

        Message('%1 Stockkeeping Units created/verified for item %2.', CreatedCount, ItemNo);
    end;
}
