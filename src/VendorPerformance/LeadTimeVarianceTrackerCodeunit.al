codeunit 50121 "Lead Time Variance Tracker"
{
    var
        LastEntryNo: Integer;

    local procedure GetNextEntryNo(): Integer
    var
        LeadTimeVariance: Record "Lead Time Variance Entry";
    begin
        if LastEntryNo = 0 then begin
            LeadTimeVariance.Reset();
            if LeadTimeVariance.FindLast() then
                LastEntryNo := LeadTimeVariance."Entry No.";
        end;
        LastEntryNo += 1;
        exit(LastEntryNo);
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Purch.-Post", 'OnAfterPurchRcptLineInsert', '', false, false)]
    local procedure OnAfterPurchRcptLineInsert(PurchaseLine: Record "Purchase Line"; var PurchRcptLine: Record "Purch. Rcpt. Line"; CommitIsSupressed: Boolean)
    begin
        if PurchRcptLine.Type <> PurchRcptLine.Type::Item then
            exit;

        if PurchRcptLine.Quantity = 0 then
            exit;

        CreateLeadTimeVarianceEntry(PurchaseLine, PurchRcptLine);
    end;

    local procedure CreateLeadTimeVarianceEntry(PurchaseLine: Record "Purchase Line"; PurchRcptLine: Record "Purch. Rcpt. Line")
    var
        LeadTimeVariance: Record "Lead Time Variance Entry";
        PurchHeader: Record "Purchase Header";
    begin
        if not PurchHeader.Get(PurchaseLine."Document Type", PurchaseLine."Document No.") then
            exit;

        LeadTimeVariance.Init();
        LeadTimeVariance."Entry No." := GetNextEntryNo();
        LeadTimeVariance."Vendor No." := PurchRcptLine."Buy-from Vendor No.";
        LeadTimeVariance."Item No." := PurchRcptLine."No.";
        LeadTimeVariance."Variant Code" := PurchRcptLine."Variant Code";
        LeadTimeVariance."Purchase Order No." := PurchaseLine."Document No.";
        LeadTimeVariance."Purchase Order Line No." := PurchaseLine."Line No.";
        LeadTimeVariance."Posted Receipt No." := PurchRcptLine."Document No.";
        LeadTimeVariance."Order Date" := PurchHeader."Order Date";
        LeadTimeVariance."Promised Receipt Date" := GetPromisedReceiptDate(PurchaseLine, PurchHeader);
        LeadTimeVariance."Actual Receipt Date" := PurchRcptLine."Posting Date";
        LeadTimeVariance."Receipt Qty" := PurchRcptLine.Quantity;
        LeadTimeVariance."Unit of Measure Code" := PurchRcptLine."Unit of Measure Code";
        LeadTimeVariance."Location Code" := PurchRcptLine."Location Code";
        LeadTimeVariance.Insert(true);

        // Optionally trigger recalculation
        TriggerPerformanceRecalcIfEnabled(PurchRcptLine."Buy-from Vendor No.", PurchRcptLine."Posting Date");
    end;

    local procedure GetPromisedReceiptDate(PurchaseLine: Record "Purchase Line"; PurchHeader: Record "Purchase Header"): Date
    begin
        // Priority: Line Promised Receipt Date > Line Expected Receipt Date > Header Expected Receipt Date
        if PurchaseLine."Promised Receipt Date" <> 0D then
            exit(PurchaseLine."Promised Receipt Date");

        if PurchaseLine."Expected Receipt Date" <> 0D then
            exit(PurchaseLine."Expected Receipt Date");

        if PurchHeader."Expected Receipt Date" <> 0D then
            exit(PurchHeader."Expected Receipt Date");

        // Fallback: calculate from order date + lead time
        exit(CalcDate(GetLeadTimeFormula(PurchaseLine), PurchHeader."Order Date"));
    end;

    local procedure GetLeadTimeFormula(PurchaseLine: Record "Purchase Line"): DateFormula
    var
        Item: Record Item;
        ItemVendor: Record "Item Vendor";
        SKU: Record "Stockkeeping Unit";
        Vendor: Record Vendor;
        LeadTimeFormula: DateFormula;
    begin
        // Priority: Item Vendor > SKU > Item > Vendor
        // 1. Item Vendor Catalog - most specific (item + vendor combination)
        if ItemVendor.Get(PurchaseLine."Buy-from Vendor No.", PurchaseLine."No.", PurchaseLine."Variant Code") then
            if Format(ItemVendor."Lead Time Calculation") <> '' then
                exit(ItemVendor."Lead Time Calculation");

        // 2. SKU - location/variant specific
        if SKU.Get(PurchaseLine."Location Code", PurchaseLine."No.", PurchaseLine."Variant Code") then
            if Format(SKU."Lead Time Calculation") <> '' then
                exit(SKU."Lead Time Calculation");

        // 3. Item Card - default for item
        if Item.Get(PurchaseLine."No.") then
            if Format(Item."Lead Time Calculation") <> '' then
                exit(Item."Lead Time Calculation");

        // 4. Vendor Card - general vendor lead time
        if Vendor.Get(PurchaseLine."Buy-from Vendor No.") then
            if Format(Vendor."Lead Time Calculation") <> '' then
                exit(Vendor."Lead Time Calculation");

        // Default: 7 days
        Evaluate(LeadTimeFormula, '<7D>');
        exit(LeadTimeFormula);
    end;

    local procedure TriggerPerformanceRecalcIfEnabled(VendorNo: Code[20]; ReceiptDate: Date)
    var
        MfgSetup: Record "Manufacturing Setup";
        VendorPerfCalc: Codeunit "Vendor Performance Calculator";
        PeriodStartDate: Date;
        PeriodEndDate: Date;
    begin
        MfgSetup.Get();
        if not MfgSetup."Auto-Recalc on Receipt" then
            exit;

        // Calculate for the month of the receipt
        PeriodStartDate := CalcDate('<-CM>', ReceiptDate);
        PeriodEndDate := CalcDate('<CM>', ReceiptDate);

        VendorPerfCalc.CalculateVendorPerformance(VendorNo, PeriodStartDate, PeriodEndDate);
    end;

    procedure CreateEntriesFromHistory(VendorNo: Code[20]; StartDate: Date; EndDate: Date)
    var
        PurchRcptLine: Record "Purch. Rcpt. Line";
        PurchRcptHeader: Record "Purch. Rcpt. Header";
        PurchLine: Record "Purchase Line";
        LeadTimeVariance: Record "Lead Time Variance Entry";
        ProgressDialog: Dialog;
        Counter: Integer;
    begin
        // Delete existing entries for this vendor and date range before recreating
        LeadTimeVariance.SetRange("Vendor No.", VendorNo);
        LeadTimeVariance.SetRange("Actual Receipt Date", StartDate, EndDate);
        LeadTimeVariance.DeleteAll();

        // Create lead time variance entries from historical receipt data
        // This is useful for initial setup when you want to populate historical data

        PurchRcptLine.SetRange("Buy-from Vendor No.", VendorNo);
        PurchRcptLine.SetRange("Posting Date", StartDate, EndDate);
        PurchRcptLine.SetFilter(Type, '%1', PurchRcptLine.Type::Item);
        PurchRcptLine.SetFilter(Quantity, '>0');

        if GuiAllowed then
            ProgressDialog.Open('Processing receipt lines...\Line: #1#####');

        if PurchRcptLine.FindSet() then
            repeat
                Counter += 1;
                if GuiAllowed then
                    ProgressDialog.Update(1, Counter);

                // Get the receipt header
                if PurchRcptHeader.Get(PurchRcptLine."Document No.") then begin
                    LeadTimeVariance.Init();
                    LeadTimeVariance."Entry No." := GetNextEntryNo();
                    LeadTimeVariance."Vendor No." := PurchRcptLine."Buy-from Vendor No.";
                    LeadTimeVariance."Item No." := PurchRcptLine."No.";
                    LeadTimeVariance."Variant Code" := PurchRcptLine."Variant Code";
                    LeadTimeVariance."Purchase Order No." := PurchRcptLine."Order No.";
                    LeadTimeVariance."Purchase Order Line No." := PurchRcptLine."Order Line No.";
                    LeadTimeVariance."Posted Receipt No." := PurchRcptLine."Document No.";
                    LeadTimeVariance."Order Date" := PurchRcptHeader."Order Date";
                    LeadTimeVariance."Promised Receipt Date" := GetHistoricalPromisedDate(PurchRcptLine, PurchRcptHeader);
                    LeadTimeVariance."Actual Receipt Date" := PurchRcptLine."Posting Date";
                    LeadTimeVariance."Receipt Qty" := PurchRcptLine.Quantity;
                    LeadTimeVariance."Unit of Measure Code" := PurchRcptLine."Unit of Measure Code";
                    LeadTimeVariance."Location Code" := PurchRcptLine."Location Code";
                    LeadTimeVariance.Insert(true);
                end;
            until PurchRcptLine.Next() = 0;

        if GuiAllowed then
            ProgressDialog.Close();
    end;

    local procedure GetHistoricalPromisedDate(PurchRcptLine: Record "Purch. Rcpt. Line"; PurchRcptHeader: Record "Purch. Rcpt. Header"): Date
    var
        Item: Record Item;
        ItemVendor: Record "Item Vendor";
        SKU: Record "Stockkeeping Unit";
        Vendor: Record Vendor;
        LeadTimeFormula: DateFormula;
    begin
        // Priority: Promised Receipt Date > Expected Receipt Date > Calculated
        if PurchRcptLine."Promised Receipt Date" <> 0D then
            exit(PurchRcptLine."Promised Receipt Date");

        if PurchRcptLine."Expected Receipt Date" <> 0D then
            exit(PurchRcptLine."Expected Receipt Date");

        if PurchRcptHeader."Expected Receipt Date" <> 0D then
            exit(PurchRcptHeader."Expected Receipt Date");

        // Fallback: calculate from order date using lead time priority
        // 1. Item Vendor Catalog - most specific (item + vendor combination)
        if ItemVendor.Get(PurchRcptLine."Buy-from Vendor No.", PurchRcptLine."No.", PurchRcptLine."Variant Code") then
            if Format(ItemVendor."Lead Time Calculation") <> '' then
                exit(CalcDate(ItemVendor."Lead Time Calculation", PurchRcptHeader."Order Date"));

        // 2. SKU - location/variant specific
        if SKU.Get(PurchRcptLine."Location Code", PurchRcptLine."No.", PurchRcptLine."Variant Code") then
            if Format(SKU."Lead Time Calculation") <> '' then
                exit(CalcDate(SKU."Lead Time Calculation", PurchRcptHeader."Order Date"));

        // 3. Item Card - default for item
        if Item.Get(PurchRcptLine."No.") then
            if Format(Item."Lead Time Calculation") <> '' then
                exit(CalcDate(Item."Lead Time Calculation", PurchRcptHeader."Order Date"));

        // 4. Vendor Card - general vendor lead time
        if Vendor.Get(PurchRcptLine."Buy-from Vendor No.") then
            if Format(Vendor."Lead Time Calculation") <> '' then
                exit(CalcDate(Vendor."Lead Time Calculation", PurchRcptHeader."Order Date"));

        // Default: 7 days from order date
        Evaluate(LeadTimeFormula, '<7D>');
        exit(CalcDate(LeadTimeFormula, PurchRcptHeader."Order Date"));
    end;

    procedure CreateAllHistoricalEntries(StartDate: Date; EndDate: Date)
    var
        Vendor: Record Vendor;
        ProgressDialog: Dialog;
        Counter: Integer;
        Total: Integer;
    begin
        Vendor.SetRange(Blocked, Vendor.Blocked::" ");
        Total := Vendor.Count();
        Counter := 0;

        if GuiAllowed then
            ProgressDialog.Open('Creating historical variance entries...\Vendor: #1########\Progress: #2### of #3###');

        if Vendor.FindSet() then
            repeat
                Counter += 1;
                if GuiAllowed then begin
                    ProgressDialog.Update(1, Vendor."No.");
                    ProgressDialog.Update(2, Counter);
                    ProgressDialog.Update(3, Total);
                end;
                CreateEntriesFromHistory(Vendor."No.", StartDate, EndDate);
            until Vendor.Next() = 0;

        if GuiAllowed then
            ProgressDialog.Close();
    end;
}
