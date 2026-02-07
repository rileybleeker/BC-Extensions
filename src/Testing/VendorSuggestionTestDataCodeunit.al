codeunit 50116 "Vendor Suggestion Test Data"
{
    // Test data generator for the Vendor Suggestion System
    // Creates vendors, items, item-vendor links, and performance data
    // for comprehensive testing of all vendor recommendation features

    procedure GenerateAllTestData()
    begin
        GenerateTestVendors();
        GenerateTestItems();
        GenerateItemVendorRecords();
        GenerateVendorPerformanceData();
        GenerateItemSubstitutions();

        Message('Vendor Suggestion test data generation complete.\' +
                '5 vendors (VEND-TEST-01 to 05)\' +
                '4 items (ITEM-VSTEST-01 to 04)\' +
                'Item-Vendor links and substitutions created.');
    end;

    procedure GenerateTestVendors()
    begin
        // High performer - best overall
        CreateVendor('VEND-TEST-01', 'Acme Premium Supplies', 98, 95);

        // Medium performer
        CreateVendor('VEND-TEST-02', 'Budget Parts Co', 85, 80);

        // Fast but lower quality
        CreateVendor('VEND-TEST-03', 'Quick Ship Express', 70, 90);

        // High quality, unreliable delivery
        CreateVendor('VEND-TEST-04', 'Quality First Inc', 95, 65);

        // Low performer
        CreateVendor('VEND-TEST-05', 'Basic Supplies LLC', 60, 60);

        Message('5 test vendors created (VEND-TEST-01 to 05)');
    end;

    procedure GenerateTestItems()
    begin
        // Multi-vendor item for main testing
        CreateItem('ITEM-VSTEST-01', 'Multi-Vendor Widget', 100.00, 'VEND-TEST-01');

        // No-vendor item for fallback testing
        CreateItem('ITEM-VSTEST-02', 'No-Vendor Part', 50.00, '');

        // Lead time test item (fast vs slow vendors)
        CreateItem('ITEM-VSTEST-03', 'Lead Time Test Item', 100.00, 'VEND-TEST-01');

        // Substitutable item
        CreateItem('ITEM-VSTEST-04', 'Substitutable Item', 100.00, 'VEND-TEST-01');

        Message('4 test items created (ITEM-VSTEST-01 to 04)');
    end;

    procedure GenerateItemVendorRecords()
    begin
        // ITEM-VSTEST-01: All 5 vendors with varying lead times and costs
        CreateItemVendor('ITEM-VSTEST-01', 'VEND-TEST-01', 10, 100.00);  // Best overall
        CreateItemVendor('ITEM-VSTEST-01', 'VEND-TEST-02', 14, 85.00);   // Cheaper, slower
        CreateItemVendor('ITEM-VSTEST-01', 'VEND-TEST-03', 5, 110.00);   // Fastest, pricey
        CreateItemVendor('ITEM-VSTEST-01', 'VEND-TEST-04', 21, 95.00);   // Slow
        CreateItemVendor('ITEM-VSTEST-01', 'VEND-TEST-05', 14, 75.00);   // Cheapest

        // ITEM-VSTEST-03: Two vendors for lead time penalty testing
        CreateItemVendor('ITEM-VSTEST-03', 'VEND-TEST-01', 5, 100.00);   // Fast - can meet date
        CreateItemVendor('ITEM-VSTEST-03', 'VEND-TEST-04', 30, 90.00);   // Very slow - late penalty

        // ITEM-VSTEST-04: Two vendors for substitution testing
        CreateItemVendor('ITEM-VSTEST-04', 'VEND-TEST-01', 14, 100.00);
        CreateItemVendor('ITEM-VSTEST-04', 'VEND-TEST-02', 14, 95.00);

        // Note: ITEM-VSTEST-02 intentionally has NO Item Vendor records

        Message('Item-Vendor records created for test items');
    end;

    procedure GenerateVendorPerformanceData()
    var
        PeriodStart: Date;
        PeriodEnd: Date;
    begin
        PeriodStart := CalcDate('<-CM>', Today);  // First of current month
        PeriodEnd := CalcDate('<CM>', Today);     // Last of current month

        // Create performance records matching vendor extension data
        CreateVendorPerformance('VEND-TEST-01', PeriodStart, PeriodEnd, 98, 95);
        CreateVendorPerformance('VEND-TEST-02', PeriodStart, PeriodEnd, 85, 80);
        CreateVendorPerformance('VEND-TEST-03', PeriodStart, PeriodEnd, 70, 90);
        CreateVendorPerformance('VEND-TEST-04', PeriodStart, PeriodEnd, 95, 65);
        CreateVendorPerformance('VEND-TEST-05', PeriodStart, PeriodEnd, 60, 60);

        Message('Vendor performance records created for current period');
    end;

    procedure GenerateItemSubstitutions()
    begin
        // ITEM-VSTEST-04 can be substituted with ITEM-VSTEST-01
        // (ITEM-VSTEST-01 has faster lead time options available)
        CreateItemSubstitution('ITEM-VSTEST-04', 'ITEM-VSTEST-01');

        Message('Item substitution created: ITEM-VSTEST-04 -> ITEM-VSTEST-01');
    end;

    procedure CleanupAllTestData()
    var
        Vendor: Record Vendor;
        Item: Record Item;
        ItemVendor: Record "Item Vendor";
        VendorPerformance: Record "Vendor Performance";
        ItemSubstitution: Record "Item Substitution";
        PurchaseSuggestion: Record "Purchase Suggestion";
    begin
        // Delete Item Substitutions
        ItemSubstitution.SetFilter("No.", 'ITEM-VSTEST-*');
        ItemSubstitution.DeleteAll();

        ItemSubstitution.Reset();
        ItemSubstitution.SetFilter("Substitute No.", 'ITEM-VSTEST-*');
        ItemSubstitution.DeleteAll();

        // Delete Item Vendor records
        ItemVendor.SetFilter("Item No.", 'ITEM-VSTEST-*');
        ItemVendor.DeleteAll();

        // Delete Vendor Performance records
        VendorPerformance.SetFilter("Vendor No.", 'VEND-TEST-*');
        VendorPerformance.DeleteAll();

        // Delete Purchase Suggestions for test items
        PurchaseSuggestion.SetFilter("Item No.", 'ITEM-VSTEST-*');
        PurchaseSuggestion.DeleteAll();

        // Block test items (cannot delete if ledger entries exist)
        Item.SetFilter("No.", 'ITEM-VSTEST-*');
        if Item.FindSet() then
            repeat
                Item.Blocked := true;
                Item.Modify();
            until Item.Next() = 0;

        // Block test vendors (cannot delete if ledger entries exist)
        Vendor.SetFilter("No.", 'VEND-TEST-*');
        if Vendor.FindSet() then
            repeat
                Vendor.Blocked := Vendor.Blocked::All;
                Vendor.Modify();
            until Vendor.Next() = 0;

        Message('Vendor Suggestion test data cleanup complete.\' +
                'Test vendors and items have been blocked.\' +
                'Item-Vendor, substitution, and performance records deleted.');
    end;

    local procedure CreateVendor(VendorNo: Code[20]; VendorName: Text[100]; QualityPct: Decimal; DeliveryPct: Decimal)
    var
        Vendor: Record Vendor;
        OverallScore: Decimal;
    begin
        if Vendor.Get(VendorNo) then begin
            // Update existing vendor
            Vendor.Name := VendorName;
            Vendor."Quality Accept Rate %" := QualityPct;
            Vendor."On-Time Delivery %" := DeliveryPct;
            OverallScore := (QualityPct * 0.5) + (DeliveryPct * 0.5);
            Vendor."Performance Score" := OverallScore;
            Vendor."Performance Risk Level" := GetRiskLevel(OverallScore);
            Vendor."Score Trend" := "Vendor Score Trend"::Stable;
            Vendor."Last Performance Calc" := CurrentDateTime;
            Vendor.Blocked := Vendor.Blocked::" ";
            Vendor.Modify(true);
            exit;
        end;

        Vendor.Init();
        Vendor."No." := VendorNo;
        Vendor.Name := VendorName;
        Vendor."Gen. Bus. Posting Group" := GetDefaultGenBusPostingGroup();
        Vendor."Vendor Posting Group" := GetDefaultVendorPostingGroup();
        Vendor.Insert(true);

        // Set performance fields (from table extension)
        Vendor."Quality Accept Rate %" := QualityPct;
        Vendor."On-Time Delivery %" := DeliveryPct;
        OverallScore := (QualityPct * 0.5) + (DeliveryPct * 0.5);
        Vendor."Performance Score" := OverallScore;
        Vendor."Performance Risk Level" := GetRiskLevel(OverallScore);
        Vendor."Score Trend" := "Vendor Score Trend"::Stable;
        Vendor."Last Performance Calc" := CurrentDateTime;
        Vendor.Modify(true);
    end;

    local procedure CreateItem(ItemNo: Code[20]; Description: Text[100]; UnitCost: Decimal; DefaultVendorNo: Code[20])
    var
        Item: Record Item;
    begin
        if Item.Get(ItemNo) then begin
            // Update existing item
            Item.Description := Description;
            Item."Unit Cost" := UnitCost;
            Item."Last Direct Cost" := UnitCost;
            if DefaultVendorNo <> '' then
                Item."Vendor No." := DefaultVendorNo;
            Item."Planning Suggestion Enabled" := true;
            Item.Blocked := false;
            Item.Modify(true);
            exit;
        end;

        Item.Init();
        Item."No." := ItemNo;
        Item.Description := Description;
        Item."Base Unit of Measure" := 'PCS';
        Item."Gen. Prod. Posting Group" := GetDefaultGenProdPostingGroup();
        Item."Inventory Posting Group" := GetDefaultInvPostingGroup();
        Item."Costing Method" := Item."Costing Method"::Average;
        Item."Unit Cost" := UnitCost;
        Item."Last Direct Cost" := UnitCost;
        Item."Unit Price" := UnitCost * 1.5;
        if DefaultVendorNo <> '' then
            Item."Vendor No." := DefaultVendorNo;
        Item."Planning Suggestion Enabled" := true;
        Item.Insert(true);
    end;

    local procedure CreateItemVendor(ItemNo: Code[20]; VendorNo: Code[20]; LeadTimeDays: Integer; UnitCost: Decimal)
    var
        ItemVendor: Record "Item Vendor";
        LeadTimeFormula: DateFormula;
    begin
        Evaluate(LeadTimeFormula, StrSubstNo('<%1D>', LeadTimeDays));

        if ItemVendor.Get(VendorNo, ItemNo, '') then begin
            // Update existing
            ItemVendor."Lead Time Calculation" := LeadTimeFormula;
            ItemVendor.Modify(true);
            exit;
        end;

        ItemVendor.Init();
        ItemVendor."Vendor No." := VendorNo;
        ItemVendor."Item No." := ItemNo;
        ItemVendor."Variant Code" := '';
        ItemVendor."Lead Time Calculation" := LeadTimeFormula;
        ItemVendor.Insert(true);
    end;

    local procedure CreateVendorPerformance(VendorNo: Code[20]; PeriodStart: Date; PeriodEnd: Date; QualityPct: Decimal; DeliveryPct: Decimal)
    var
        VendorPerformance: Record "Vendor Performance";
        OverallScore: Decimal;
        TotalReceipts: Integer;
        OnTimeReceipts: Integer;
        TotalQty: Decimal;
        AcceptedQty: Decimal;
    begin
        // Generate realistic-looking metrics
        TotalReceipts := 20 + Random(30);  // 20-50 receipts
        OnTimeReceipts := Round(TotalReceipts * DeliveryPct / 100, 1);
        TotalQty := TotalReceipts * (100 + Random(400));  // 100-500 units per receipt
        AcceptedQty := Round(TotalQty * QualityPct / 100, 0.00001);
        OverallScore := (QualityPct * 0.5) + (DeliveryPct * 0.5);

        if VendorPerformance.Get(VendorNo, PeriodStart) then begin
            // Update existing
            VendorPerformance."Period End Date" := PeriodEnd;
            VendorPerformance."Total Receipts" := TotalReceipts;
            VendorPerformance."On-Time Receipts" := OnTimeReceipts;
            VendorPerformance."Early Receipts" := Round((TotalReceipts - OnTimeReceipts) * 0.3, 1);
            VendorPerformance."Late Receipts" := TotalReceipts - OnTimeReceipts - VendorPerformance."Early Receipts";
            VendorPerformance."On-Time Delivery %" := DeliveryPct;
            VendorPerformance."Total Qty Received" := TotalQty;
            VendorPerformance."Qty Accepted" := AcceptedQty;
            VendorPerformance."Qty Rejected" := TotalQty - AcceptedQty;
            VendorPerformance."Quality Accept Rate %" := QualityPct;
            VendorPerformance."Overall Score" := OverallScore;
            VendorPerformance."Risk Level" := GetRiskLevel(OverallScore);
            VendorPerformance."Score Trend" := "Vendor Score Trend"::Stable;
            VendorPerformance."Avg Promised Lead Time Days" := 10;
            VendorPerformance."Avg Actual Lead Time Days" := 10 + (2 - Random(4));
            VendorPerformance."Lead Time Variance Days" := VendorPerformance."Avg Actual Lead Time Days" - VendorPerformance."Avg Promised Lead Time Days";
            VendorPerformance."Lead Time Reliability %" := 100 - Abs(VendorPerformance."Lead Time Variance Days" * 5);
            VendorPerformance."Calculation Notes" := 'Test data generated by Vendor Suggestion Test Data codeunit';
            VendorPerformance.Modify(true);
            exit;
        end;

        VendorPerformance.Init();
        VendorPerformance."Vendor No." := VendorNo;
        VendorPerformance."Period Start Date" := PeriodStart;
        VendorPerformance."Period End Date" := PeriodEnd;
        VendorPerformance."Total Receipts" := TotalReceipts;
        VendorPerformance."On-Time Receipts" := OnTimeReceipts;
        VendorPerformance."Early Receipts" := Round((TotalReceipts - OnTimeReceipts) * 0.3, 1);
        VendorPerformance."Late Receipts" := TotalReceipts - OnTimeReceipts - VendorPerformance."Early Receipts";
        VendorPerformance."On-Time Delivery %" := DeliveryPct;
        VendorPerformance."Total Qty Received" := TotalQty;
        VendorPerformance."Qty Accepted" := AcceptedQty;
        VendorPerformance."Qty Rejected" := TotalQty - AcceptedQty;
        VendorPerformance."Quality Accept Rate %" := QualityPct;
        VendorPerformance."Overall Score" := OverallScore;
        VendorPerformance."Risk Level" := GetRiskLevel(OverallScore);
        VendorPerformance."Score Trend" := "Vendor Score Trend"::Stable;
        VendorPerformance."Avg Promised Lead Time Days" := 10;
        VendorPerformance."Avg Actual Lead Time Days" := 10 + (2 - Random(4));
        VendorPerformance."Lead Time Variance Days" := VendorPerformance."Avg Actual Lead Time Days" - VendorPerformance."Avg Promised Lead Time Days";
        VendorPerformance."Lead Time Reliability %" := 100 - Abs(VendorPerformance."Lead Time Variance Days" * 5);
        VendorPerformance."Calculation Notes" := 'Test data generated by Vendor Suggestion Test Data codeunit';
        VendorPerformance.Insert(true);
    end;

    local procedure CreateItemSubstitution(ItemNo: Code[20]; SubstituteNo: Code[20])
    var
        ItemSubstitution: Record "Item Substitution";
    begin
        if ItemSubstitution.Get(ItemSubstitution.Type::Item, ItemNo, '', ItemSubstitution."Substitute Type"::Item, SubstituteNo, '') then
            exit;  // Already exists

        ItemSubstitution.Init();
        ItemSubstitution.Type := ItemSubstitution.Type::Item;
        ItemSubstitution."No." := ItemNo;
        ItemSubstitution."Variant Code" := '';
        ItemSubstitution."Substitute Type" := ItemSubstitution."Substitute Type"::Item;
        ItemSubstitution."Substitute No." := SubstituteNo;
        ItemSubstitution."Substitute Variant Code" := '';
        ItemSubstitution.Description := 'Test substitution';
        ItemSubstitution.Interchangeable := true;
        ItemSubstitution.Insert(true);
    end;

    local procedure GetRiskLevel(Score: Decimal): Enum "Vendor Risk Level"
    begin
        if Score >= 90 then
            exit("Vendor Risk Level"::Low);
        if Score >= 75 then
            exit("Vendor Risk Level"::Medium);
        if Score >= 60 then
            exit("Vendor Risk Level"::High);
        exit("Vendor Risk Level"::Critical);
    end;

    local procedure GetDefaultGenBusPostingGroup(): Code[20]
    var
        GenBusPostingGroup: Record "Gen. Business Posting Group";
    begin
        if GenBusPostingGroup.FindFirst() then
            exit(GenBusPostingGroup.Code);
        exit('');
    end;

    local procedure GetDefaultVendorPostingGroup(): Code[20]
    var
        VendorPostingGroup: Record "Vendor Posting Group";
    begin
        if VendorPostingGroup.FindFirst() then
            exit(VendorPostingGroup.Code);
        exit('');
    end;

    local procedure GetDefaultGenProdPostingGroup(): Code[20]
    var
        GenProdPostingGroup: Record "Gen. Product Posting Group";
    begin
        if GenProdPostingGroup.FindFirst() then
            exit(GenProdPostingGroup.Code);
        exit('');
    end;

    local procedure GetDefaultInvPostingGroup(): Code[20]
    var
        InventoryPostingGroup: Record "Inventory Posting Group";
    begin
        if InventoryPostingGroup.FindFirst() then
            exit(InventoryPostingGroup.Code);
        exit('');
    end;

    procedure GetTestVendorCount(): Integer
    var
        Vendor: Record Vendor;
    begin
        Vendor.SetFilter("No.", 'VEND-TEST-*');
        exit(Vendor.Count);
    end;

    procedure GetTestItemCount(): Integer
    var
        Item: Record Item;
    begin
        Item.SetFilter("No.", 'ITEM-VSTEST-*');
        exit(Item.Count);
    end;

    procedure GetTestItemVendorCount(): Integer
    var
        ItemVendor: Record "Item Vendor";
    begin
        ItemVendor.SetFilter("Item No.", 'ITEM-VSTEST-*');
        exit(ItemVendor.Count);
    end;
}
