codeunit 50150 "Purchase Suggestion Manager"
{
    procedure GenerateSuggestion(ItemNo: Code[20]; VariantCode: Code[10]; LocationCode: Code[10]; RequiredQty: Decimal; RequiredDate: Date): Record "Purchase Suggestion"
    var
        PurchSuggestion: Record "Purchase Suggestion";
        TempVendorRanking: Record "Vendor Ranking" temporary;
        VendorSelector: Codeunit "Vendor Selector";
        VendorCount: Integer;
    begin
        PurchSuggestion.Init();
        PurchSuggestion.Validate("Item No.", ItemNo);
        PurchSuggestion."Variant Code" := VariantCode;
        PurchSuggestion."Location Code" := LocationCode;
        PurchSuggestion."Suggested Qty" := RequiredQty;
        PurchSuggestion."Required Date" := RequiredDate;
        PurchSuggestion."Suggestion Date" := Today;
        PurchSuggestion."Status" := PurchSuggestion."Status"::New;

        // Get ranked vendors
        VendorSelector.GetRankedVendors(ItemNo, LocationCode, RequiredQty, RequiredDate, TempVendorRanking);

        // Populate top 3 vendors
        if TempVendorRanking.FindSet() then begin
            VendorCount := 0;
            repeat
                VendorCount += 1;
                PopulateVendorSlot(PurchSuggestion, TempVendorRanking, VendorCount);
            until (TempVendorRanking.Next() = 0) or (VendorCount >= 3);

            // Set recommendation
            TempVendorRanking.FindFirst();
            SetRecommendation(PurchSuggestion, TempVendorRanking, ItemNo, LocationCode, RequiredQty, RequiredDate);

            PurchSuggestion."Alternative Available" := VendorCount > 1;
        end;

        // Check for substitutes
        CheckForSubstitutes(PurchSuggestion, RequiredDate);

        PurchSuggestion.Insert(true);
        exit(PurchSuggestion);
    end;

    procedure GenerateFromRequisitionLine(ReqLine: Record "Requisition Line"): Record "Purchase Suggestion"
    var
        PurchSuggestion: Record "Purchase Suggestion";
    begin
        PurchSuggestion := GenerateSuggestion(
            ReqLine."No.",
            ReqLine."Variant Code",
            ReqLine."Location Code",
            ReqLine.Quantity,
            ReqLine."Due Date"
        );

        PurchSuggestion."Requisition Worksheet Template" := ReqLine."Worksheet Template Name";
        PurchSuggestion."Requisition Worksheet Batch" := ReqLine."Journal Batch Name";
        PurchSuggestion."Requisition Line No." := ReqLine."Line No.";
        PurchSuggestion.Modify();

        exit(PurchSuggestion);
    end;

    local procedure PopulateVendorSlot(var PurchSuggestion: Record "Purchase Suggestion"; VendorRanking: Record "Vendor Ranking"; SlotNo: Integer)
    var
        Vendor: Record Vendor;
        VendorName: Text[100];
    begin
        if Vendor.Get(VendorRanking."Vendor No.") then
            VendorName := Vendor.Name;

        case SlotNo of
            1:
                begin
                    PurchSuggestion."Vendor 1 No." := VendorRanking."Vendor No.";
                    PurchSuggestion."Vendor 1 Name" := VendorName;
                    PurchSuggestion."Vendor 1 Unit Cost" := VendorRanking."Unit Cost";
                    PurchSuggestion."Vendor 1 Lead Time" := VendorRanking."Lead Time Days";
                    PurchSuggestion."Vendor 1 Score" := VendorRanking."Overall Score";
                    PurchSuggestion."Vendor 1 Expected Date" := VendorRanking."Expected Date";
                end;
            2:
                begin
                    PurchSuggestion."Vendor 2 No." := VendorRanking."Vendor No.";
                    PurchSuggestion."Vendor 2 Name" := VendorName;
                    PurchSuggestion."Vendor 2 Unit Cost" := VendorRanking."Unit Cost";
                    PurchSuggestion."Vendor 2 Lead Time" := VendorRanking."Lead Time Days";
                    PurchSuggestion."Vendor 2 Score" := VendorRanking."Overall Score";
                    PurchSuggestion."Vendor 2 Expected Date" := VendorRanking."Expected Date";
                end;
            3:
                begin
                    PurchSuggestion."Vendor 3 No." := VendorRanking."Vendor No.";
                    PurchSuggestion."Vendor 3 Name" := VendorName;
                    PurchSuggestion."Vendor 3 Unit Cost" := VendorRanking."Unit Cost";
                    PurchSuggestion."Vendor 3 Lead Time" := VendorRanking."Lead Time Days";
                    PurchSuggestion."Vendor 3 Score" := VendorRanking."Overall Score";
                    PurchSuggestion."Vendor 3 Expected Date" := VendorRanking."Expected Date";
                end;
        end;
    end;

    local procedure SetRecommendation(var PurchSuggestion: Record "Purchase Suggestion"; VendorRanking: Record "Vendor Ranking"; ItemNo: Code[20]; LocationCode: Code[10]; RequiredQty: Decimal; RequiredDate: Date)
    var
        Vendor: Record Vendor;
        VendorSelector: Codeunit "Vendor Selector";
    begin
        PurchSuggestion."Recommended Vendor No." := VendorRanking."Vendor No.";
        if Vendor.Get(VendorRanking."Vendor No.") then
            PurchSuggestion."Recommended Vendor Name" := Vendor.Name;

        PurchSuggestion."Recommendation Reason" := VendorSelector.GetRecommendationReason(
            VendorRanking."Vendor No.", ItemNo, LocationCode, RequiredQty, RequiredDate);

        // Pre-select recommended vendor
        PurchSuggestion."Selected Vendor No." := VendorRanking."Vendor No.";
        PurchSuggestion."Selected Vendor Name" := PurchSuggestion."Recommended Vendor Name";
    end;

    local procedure CheckForSubstitutes(var PurchSuggestion: Record "Purchase Suggestion"; RequiredDate: Date)
    var
        ItemSubstitution: Record "Item Substitution";
        VendorSelector: Codeunit "Vendor Selector";
        OriginalLeadTime: Integer;
        SubstituteLeadTime: Integer;
    begin
        ItemSubstitution.SetRange(Type, ItemSubstitution.Type::Item);
        ItemSubstitution.SetRange("No.", PurchSuggestion."Item No.");
        ItemSubstitution.SetRange("Variant Code", PurchSuggestion."Variant Code");

        if ItemSubstitution.FindFirst() then begin
            // Get lead times for comparison
            OriginalLeadTime := PurchSuggestion."Vendor 1 Lead Time";

            SubstituteLeadTime := VendorSelector.GetVendorLeadTimeDays(
                VendorSelector.GetRecommendedVendor(ItemSubstitution."Substitute No.", PurchSuggestion."Location Code", PurchSuggestion."Suggested Qty", RequiredDate),
                ItemSubstitution."Substitute No.",
                PurchSuggestion."Location Code"
            );

            if SubstituteLeadTime < OriginalLeadTime then begin
                PurchSuggestion."Substitute Item Available" := true;
                PurchSuggestion."Substitute Item No." := ItemSubstitution."Substitute No.";
                PurchSuggestion."Substitute Lead Time Savings" := OriginalLeadTime - SubstituteLeadTime;
            end;
        end;
    end;

    procedure ApproveSuggestion(var PurchSuggestion: Record "Purchase Suggestion")
    begin
        if PurchSuggestion."Status" <> PurchSuggestion."Status"::New then
            Error('Suggestion must be in New status to approve.');

        if PurchSuggestion."Selected Vendor No." = '' then
            Error('Please select a vendor before approving.');

        PurchSuggestion."Status" := PurchSuggestion."Status"::Approved;
        PurchSuggestion."Approved By" := CopyStr(UserId, 1, MaxStrLen(PurchSuggestion."Approved By"));
        PurchSuggestion."Approved DateTime" := CurrentDateTime;
        PurchSuggestion.Modify(true);
    end;

    procedure RejectSuggestion(var PurchSuggestion: Record "Purchase Suggestion"; RejectionReason: Text[250])
    begin
        if PurchSuggestion."Status" in [PurchSuggestion."Status"::"PO Created", PurchSuggestion."Status"::Cancelled] then
            Error('Cannot reject suggestion in current status.');

        PurchSuggestion."Status" := PurchSuggestion."Status"::Rejected;
        PurchSuggestion."Rejection Reason" := RejectionReason;
        PurchSuggestion.Modify(true);
    end;

    procedure CreatePurchaseOrder(var PurchSuggestion: Record "Purchase Suggestion"; Consolidate: Boolean): Code[20]
    var
        PurchHeader: Record "Purchase Header";
        PurchLine: Record "Purchase Line";
        ExistingPO: Record "Purchase Header";
        LineNo: Integer;
    begin
        if PurchSuggestion."Status" <> PurchSuggestion."Status"::Approved then
            Error('Suggestion must be approved before creating a purchase order.');

        if PurchSuggestion."Selected Vendor No." = '' then
            Error('No vendor selected.');

        // Check for existing open PO to consolidate
        if Consolidate then begin
            ExistingPO.SetRange("Document Type", ExistingPO."Document Type"::Order);
            ExistingPO.SetRange("Buy-from Vendor No.", PurchSuggestion."Selected Vendor No.");
            ExistingPO.SetRange(Status, ExistingPO.Status::Open);
            if ExistingPO.FindFirst() then begin
                PurchHeader := ExistingPO;
            end;
        end;

        // Create new PO if not consolidating or no existing PO found
        if PurchHeader."No." = '' then begin
            PurchHeader.Init();
            PurchHeader."Document Type" := PurchHeader."Document Type"::Order;
            PurchHeader.Insert(true);
            PurchHeader.Validate("Buy-from Vendor No.", PurchSuggestion."Selected Vendor No.");
            PurchHeader.Modify(true);
        end;

        // Find next line number
        PurchLine.SetRange("Document Type", PurchHeader."Document Type");
        PurchLine.SetRange("Document No.", PurchHeader."No.");
        if PurchLine.FindLast() then
            LineNo := PurchLine."Line No." + 10000
        else
            LineNo := 10000;

        // Create purchase line
        PurchLine.Init();
        PurchLine."Document Type" := PurchHeader."Document Type";
        PurchLine."Document No." := PurchHeader."No.";
        PurchLine."Line No." := LineNo;
        PurchLine.Insert(true);
        PurchLine.Validate(Type, PurchLine.Type::Item);
        PurchLine.Validate("No.", PurchSuggestion."Item No.");
        if PurchSuggestion."Variant Code" <> '' then
            PurchLine.Validate("Variant Code", PurchSuggestion."Variant Code");
        if PurchSuggestion."Location Code" <> '' then
            PurchLine.Validate("Location Code", PurchSuggestion."Location Code");
        PurchLine.Validate(Quantity, PurchSuggestion."Suggested Qty");
        if PurchSuggestion."Required Date" <> 0D then
            PurchLine.Validate("Expected Receipt Date", PurchSuggestion."Required Date");
        PurchLine.Modify(true);

        // Update suggestion
        PurchSuggestion."Status" := PurchSuggestion."Status"::"PO Created";
        PurchSuggestion."Purchase Order No." := PurchHeader."No.";
        PurchSuggestion.Modify(true);

        exit(PurchHeader."No.");
    end;

    procedure CreateConsolidatedPurchaseOrders(var TempPurchSuggestion: Record "Purchase Suggestion" temporary)
    var
        PurchSuggestion: Record "Purchase Suggestion";
        LastVendor: Code[20];
        PONo: Code[20];
    begin
        // Sort by vendor
        TempPurchSuggestion.SetCurrentKey("Selected Vendor No.");

        if TempPurchSuggestion.FindSet() then begin
            LastVendor := '';
            repeat
                PurchSuggestion.Get(TempPurchSuggestion."Entry No.");

                // Start new PO for new vendor
                if TempPurchSuggestion."Selected Vendor No." <> LastVendor then begin
                    LastVendor := TempPurchSuggestion."Selected Vendor No.";
                    PONo := '';  // Will create new PO
                end;

                // Create/add to PO
                PONo := CreatePurchaseOrder(PurchSuggestion, PONo <> '');
            until TempPurchSuggestion.Next() = 0;
        end;
    end;

    procedure CancelSuggestion(var PurchSuggestion: Record "Purchase Suggestion")
    begin
        if PurchSuggestion."Status" = PurchSuggestion."Status"::"PO Created" then
            Error('Cannot cancel suggestion after purchase order has been created.');

        PurchSuggestion."Status" := PurchSuggestion."Status"::Cancelled;
        PurchSuggestion.Modify(true);
    end;

    procedure GetPendingSuggestionsForVendor(VendorNo: Code[20]; var TempPurchSuggestion: Record "Purchase Suggestion" temporary)
    var
        PurchSuggestion: Record "Purchase Suggestion";
    begin
        TempPurchSuggestion.DeleteAll();

        PurchSuggestion.SetRange("Selected Vendor No.", VendorNo);
        PurchSuggestion.SetRange("Status", PurchSuggestion."Status"::Approved);

        if PurchSuggestion.FindSet() then
            repeat
                TempPurchSuggestion := PurchSuggestion;
                TempPurchSuggestion.Insert();
            until PurchSuggestion.Next() = 0;
    end;

    procedure GetTotalCostForVendor(VendorNo: Code[20]): Decimal
    var
        PurchSuggestion: Record "Purchase Suggestion";
        TotalCost: Decimal;
    begin
        PurchSuggestion.SetRange("Selected Vendor No.", VendorNo);
        PurchSuggestion.SetRange("Status", PurchSuggestion."Status"::Approved);

        if PurchSuggestion.FindSet() then
            repeat
                TotalCost += PurchSuggestion.GetTotalCost();
            until PurchSuggestion.Next() = 0;

        exit(TotalCost);
    end;
}
