codeunit 50130 "Vendor NCR Management"
{
    procedure CreateNCRFromQualityOrder(QualityOrder: Record "Quality Order")
    var
        VendorNCR: Record "Vendor NCR";
        ItemLedgerEntry: Record "Item Ledger Entry";
        PurchRcptLine: Record "Purch. Rcpt. Line";
        VendorNo: Code[20];
    begin
        // Find the vendor from the Item Ledger Entry
        if not ItemLedgerEntry.Get(QualityOrder."Item Ledger Entry No.") then
            exit;

        // Get vendor from the source document
        VendorNo := GetVendorFromItemLedgerEntry(ItemLedgerEntry);
        if VendorNo = '' then
            exit;

        // Check if NCR already exists for this quality order
        VendorNCR.SetRange("Quality Order Entry No.", QualityOrder."Entry No.");
        if not VendorNCR.IsEmpty then
            exit;

        // Create the NCR
        VendorNCR.Init();
        VendorNCR.Validate("Vendor No.", VendorNo);
        VendorNCR.Validate("Item No.", QualityOrder."Item No.");
        VendorNCR."NCR Date" := Today;
        VendorNCR."Category" := VendorNCR."Category"::Material;  // Default for quality failures
        VendorNCR."Description" := StrSubstNo('Quality test failed for Lot %1', QualityOrder."Lot No.");
        VendorNCR."Lot No." := QualityOrder."Lot No.";
        VendorNCR."Quality Order Entry No." := QualityOrder."Entry No.";
        VendorNCR."Item Ledger Entry No." := QualityOrder."Item Ledger Entry No.";
        VendorNCR."Location Code" := ItemLedgerEntry."Location Code";
        VendorNCR."Status" := VendorNCR."Status"::Open;
        VendorNCR."Priority" := VendorNCR."Priority"::Medium;

        // Get receipt info
        if FindPurchRcptLineForItemLedger(ItemLedgerEntry, PurchRcptLine) then begin
            VendorNCR."Posted Receipt No." := PurchRcptLine."Document No.";
            VendorNCR."Purchase Order No." := PurchRcptLine."Order No.";
            VendorNCR."Purchase Order Line No." := PurchRcptLine."Order Line No.";
            VendorNCR."Receipt Qty" := PurchRcptLine.Quantity;
            VendorNCR."Unit of Measure Code" := PurchRcptLine."Unit of Measure Code";
        end;

        VendorNCR."Affected Qty" := Abs(ItemLedgerEntry.Quantity);
        VendorNCR.Insert(true);
    end;

    procedure CreateNCRFromReceipt(PurchRcptLine: Record "Purch. Rcpt. Line"; Category: Enum "NCR Category"; Description: Text[250]; AffectedQty: Decimal)
    var
        VendorNCR: Record "Vendor NCR";
    begin
        VendorNCR.Init();
        VendorNCR.Validate("Vendor No.", PurchRcptLine."Buy-from Vendor No.");
        VendorNCR.Validate("Item No.", PurchRcptLine."No.");
        VendorNCR."Variant Code" := PurchRcptLine."Variant Code";
        VendorNCR."NCR Date" := Today;
        VendorNCR."Category" := Category;
        VendorNCR."Description" := Description;
        VendorNCR."Posted Receipt No." := PurchRcptLine."Document No.";
        VendorNCR."Purchase Order No." := PurchRcptLine."Order No.";
        VendorNCR."Purchase Order Line No." := PurchRcptLine."Order Line No.";
        VendorNCR."Location Code" := PurchRcptLine."Location Code";
        VendorNCR."Receipt Qty" := PurchRcptLine.Quantity;
        VendorNCR."Affected Qty" := AffectedQty;
        VendorNCR."Unit of Measure Code" := PurchRcptLine."Unit of Measure Code";
        VendorNCR."Status" := VendorNCR."Status"::Open;
        VendorNCR."Priority" := VendorNCR."Priority"::Medium;
        VendorNCR.Insert(true);
    end;

    local procedure GetVendorFromItemLedgerEntry(ItemLedgerEntry: Record "Item Ledger Entry"): Code[20]
    var
        PurchRcptLine: Record "Purch. Rcpt. Line";
        ValueEntry: Record "Value Entry";
    begin
        // Try to find through Value Entry
        ValueEntry.SetRange("Item Ledger Entry No.", ItemLedgerEntry."Entry No.");
        ValueEntry.SetFilter("Source Type", '%1', ValueEntry."Source Type"::Vendor);
        if ValueEntry.FindFirst() then
            exit(ValueEntry."Source No.");

        // Try to find through Purchase Receipt Line
        if FindPurchRcptLineForItemLedger(ItemLedgerEntry, PurchRcptLine) then
            exit(PurchRcptLine."Buy-from Vendor No.");

        exit('');
    end;

    local procedure FindPurchRcptLineForItemLedger(ItemLedgerEntry: Record "Item Ledger Entry"; var PurchRcptLine: Record "Purch. Rcpt. Line"): Boolean
    begin
        if ItemLedgerEntry."Document Type" <> ItemLedgerEntry."Document Type"::"Purchase Receipt" then
            exit(false);

        PurchRcptLine.SetRange("Document No.", ItemLedgerEntry."Document No.");
        PurchRcptLine.SetRange("No.", ItemLedgerEntry."Item No.");
        PurchRcptLine.SetRange("Variant Code", ItemLedgerEntry."Variant Code");
        exit(PurchRcptLine.FindFirst());
    end;

    procedure GetNCRCountForVendor(VendorNo: Code[20]; StartDate: Date; EndDate: Date): Integer
    var
        VendorNCR: Record "Vendor NCR";
        PurchRcptHeader: Record "Purch. Rcpt. Header";
        NCRCount: Integer;
    begin
        // Match NCRs by the RECEIPT posting date, not NCR creation date
        VendorNCR.SetRange("Vendor No.", VendorNo);
        if VendorNCR.FindSet() then
            repeat
                if VendorNCR."Posted Receipt No." <> '' then begin
                    if PurchRcptHeader.Get(VendorNCR."Posted Receipt No.") then begin
                        if (PurchRcptHeader."Posting Date" >= StartDate) and
                           (PurchRcptHeader."Posting Date" <= EndDate) then
                            NCRCount += 1;
                    end;
                end else begin
                    // Fallback to NCR Date if no receipt linked
                    if (VendorNCR."NCR Date" >= StartDate) and
                       (VendorNCR."NCR Date" <= EndDate) then
                        NCRCount += 1;
                end;
            until VendorNCR.Next() = 0;
        exit(NCRCount);
    end;

    procedure GetNCRCountForVendorItem(VendorNo: Code[20]; ItemNo: Code[20]; StartDate: Date; EndDate: Date): Integer
    var
        VendorNCR: Record "Vendor NCR";
    begin
        VendorNCR.SetRange("Vendor No.", VendorNo);
        VendorNCR.SetRange("Item No.", ItemNo);
        VendorNCR.SetRange("NCR Date", StartDate, EndDate);
        exit(VendorNCR.Count());
    end;

    procedure GetTotalCostImpact(VendorNo: Code[20]; StartDate: Date; EndDate: Date): Decimal
    var
        VendorNCR: Record "Vendor NCR";
    begin
        VendorNCR.SetRange("Vendor No.", VendorNo);
        VendorNCR.SetRange("NCR Date", StartDate, EndDate);
        VendorNCR.CalcSums("Cost Impact");
        exit(VendorNCR."Cost Impact");
    end;

    procedure GetTotalAffectedQty(VendorNo: Code[20]; StartDate: Date; EndDate: Date): Decimal
    var
        VendorNCR: Record "Vendor NCR";
        PurchRcptHeader: Record "Purch. Rcpt. Header";
        TotalAffected: Decimal;
    begin
        // Match NCRs by the RECEIPT posting date, not NCR creation date
        // This ensures NCR affected qty is compared against the same period's receipts
        VendorNCR.SetRange("Vendor No.", VendorNo);
        if VendorNCR.FindSet() then
            repeat
                if VendorNCR."Posted Receipt No." <> '' then begin
                    if PurchRcptHeader.Get(VendorNCR."Posted Receipt No.") then begin
                        if (PurchRcptHeader."Posting Date" >= StartDate) and
                           (PurchRcptHeader."Posting Date" <= EndDate) then
                            TotalAffected += VendorNCR."Affected Qty";
                    end;
                end else begin
                    // Fallback to NCR Date if no receipt linked
                    if (VendorNCR."NCR Date" >= StartDate) and
                       (VendorNCR."NCR Date" <= EndDate) then
                        TotalAffected += VendorNCR."Affected Qty";
                end;
            until VendorNCR.Next() = 0;
        exit(TotalAffected);
    end;

    procedure GetOpenNCRCount(VendorNo: Code[20]): Integer
    var
        VendorNCR: Record "Vendor NCR";
    begin
        VendorNCR.SetRange("Vendor No.", VendorNo);
        VendorNCR.SetFilter("Status", '%1|%2|%3',
            VendorNCR."Status"::Open,
            VendorNCR."Status"::"Under Review",
            VendorNCR."Status"::"Pending Vendor Response");
        exit(VendorNCR.Count());
    end;
}
