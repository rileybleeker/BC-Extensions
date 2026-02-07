codeunit 50151 "Vendor Selector"
{
    procedure GetRecommendedVendor(ItemNo: Code[20]; LocationCode: Code[10]; RequiredQty: Decimal; RequiredDate: Date): Code[20]
    var
        TempVendorRanking: Record "Vendor Ranking" temporary;
    begin
        GetRankedVendors(ItemNo, LocationCode, RequiredQty, RequiredDate, TempVendorRanking);
        if TempVendorRanking.FindFirst() then
            exit(TempVendorRanking."Vendor No.");
        exit('');
    end;

    procedure GetRankedVendors(ItemNo: Code[20]; LocationCode: Code[10]; RequiredQty: Decimal; RequiredDate: Date; var TempVendorRanking: Record "Vendor Ranking" temporary)
    var
        ItemVendor: Record "Item Vendor";
        Item: Record Item;
        RankNo: Integer;
    begin
        TempVendorRanking.DeleteAll();
        RankNo := 0;

        // Get all vendors that supply this item
        ItemVendor.SetRange("Item No.", ItemNo);
        if ItemVendor.FindSet() then
            repeat
                if TryAddVendorRanking(TempVendorRanking, ItemVendor."Vendor No.", ItemNo, LocationCode, RequiredQty, RequiredDate, RankNo) then
                    RankNo += 1;
            until ItemVendor.Next() = 0;

        // Also check the item's default vendor
        if Item.Get(ItemNo) and (Item."Vendor No." <> '') then begin
            TempVendorRanking.SetRange("Vendor No.", Item."Vendor No.");
            if TempVendorRanking.IsEmpty then
                if TryAddVendorRanking(TempVendorRanking, Item."Vendor No.", ItemNo, LocationCode, RequiredQty, RequiredDate, RankNo) then
                    RankNo += 1;
            TempVendorRanking.Reset();
        end;

        // Sort by score descending
        TempVendorRanking.SetCurrentKey("Overall Score");
        TempVendorRanking.SetAscending("Overall Score", false);
    end;

    local procedure TryAddVendorRanking(var TempVendorRanking: Record "Vendor Ranking" temporary; VendorNo: Code[20]; ItemNo: Code[20]; LocationCode: Code[10]; RequiredQty: Decimal; RequiredDate: Date; RankNo: Integer): Boolean
    var
        Vendor: Record Vendor;
        VendorScore: Decimal;
        LeadTimeDays: Integer;
        QualityScore: Decimal;
        DeliveryScore: Decimal;
        PerformanceScore: Decimal;
    begin
        VendorScore := ScoreVendorForItem(VendorNo, ItemNo, LocationCode, RequiredQty, RequiredDate);
        if VendorScore <= 0 then
            exit(false);

        // Cache lead time to avoid recalculating
        LeadTimeDays := GetVendorLeadTimeDays(VendorNo, ItemNo, LocationCode);

        // Get vendor data (name and performance) with single lookup
        GetVendorScores(VendorNo, QualityScore, DeliveryScore, PerformanceScore);

        TempVendorRanking.Init();
        TempVendorRanking."Rank No." := RankNo + 1;
        TempVendorRanking."Vendor No." := VendorNo;
        TempVendorRanking."Item No." := ItemNo;
        TempVendorRanking."Overall Score" := VendorScore;
        TempVendorRanking."Unit Cost" := GetVendorUnitCost(VendorNo, ItemNo, RequiredQty);
        TempVendorRanking."Lead Time Days" := LeadTimeDays;
        TempVendorRanking."Expected Date" := CalcDate('<' + Format(LeadTimeDays) + 'D>', Today);
        TempVendorRanking."Can Meet Date" := TempVendorRanking."Expected Date" <= RequiredDate;
        TempVendorRanking."Performance Score" := PerformanceScore;
        // Cache vendor name to avoid repeated lookups in UI
        if Vendor.Get(VendorNo) then
            TempVendorRanking."Vendor Name" := Vendor.Name;
        TempVendorRanking.Insert();
        exit(true);
    end;

    procedure ScoreVendorForItem(VendorNo: Code[20]; ItemNo: Code[20]; LocationCode: Code[10]; RequiredQty: Decimal; RequiredDate: Date): Decimal
    var
        LeadTimeScore: Decimal;
        PriceScore: Decimal;
        QualityScore: Decimal;
        DeliveryScore: Decimal;
        PerformanceScore: Decimal;
        TotalScore: Decimal;
    begin
        // Get lead time and price scores (item-specific)
        LeadTimeScore := GetLeadTimeScore(VendorNo, ItemNo, LocationCode, RequiredDate);
        PriceScore := GetPriceScore(VendorNo, ItemNo, RequiredQty);

        // Get vendor scores with single database call
        GetVendorScores(VendorNo, QualityScore, DeliveryScore, PerformanceScore);

        // Weighted average - matching the performance calculator weights
        // Lead Time: 25%, Price: 15%, Quality: 30%, Delivery: 30%
        TotalScore := (LeadTimeScore * 0.25) + (PriceScore * 0.15) + (QualityScore * 0.30) + (DeliveryScore * 0.30);

        exit(Round(TotalScore, 0.01));
    end;

    procedure GetLeadTimeScore(VendorNo: Code[20]; ItemNo: Code[20]; LocationCode: Code[10]; RequiredDate: Date): Decimal
    var
        LeadTimeDays: Integer;
        DaysUntilRequired: Integer;
        Score: Decimal;
    begin
        LeadTimeDays := GetVendorLeadTimeDays(VendorNo, ItemNo, LocationCode);
        DaysUntilRequired := RequiredDate - Today;

        if DaysUntilRequired <= 0 then
            DaysUntilRequired := 1;

        // Score based on how well the lead time fits the requirement
        if LeadTimeDays <= DaysUntilRequired then
            Score := 100  // Can meet the date
        else begin
            // Penalize based on how many days late
            Score := 100 - ((LeadTimeDays - DaysUntilRequired) * 5);
            if Score < 0 then
                Score := 0;
        end;

        exit(Score);
    end;

    procedure GetPriceScore(VendorNo: Code[20]; ItemNo: Code[20]; RequiredQty: Decimal): Decimal
    var
        Item: Record Item;
        VendorCost: Decimal;
        BestCost: Decimal;
        Score: Decimal;
    begin
        VendorCost := GetVendorUnitCost(VendorNo, ItemNo, RequiredQty);

        // Use item unit cost as the baseline for comparison
        BestCost := VendorCost;
        if Item.Get(ItemNo) and (Item."Unit Cost" > 0) then
            if (BestCost = 0) or (Item."Unit Cost" < BestCost) then
                BestCost := Item."Unit Cost";

        // Score based on how close to best price
        if (VendorCost = 0) or (BestCost = 0) then
            Score := 50  // No price data, neutral score
        else if VendorCost <= BestCost then
            Score := 100
        else begin
            // Penalize based on price premium percentage
            Score := 100 - ((VendorCost - BestCost) / BestCost * 100);
            if Score < 0 then
                Score := 0;
        end;

        exit(Score);
    end;

    procedure GetQualityScore(VendorNo: Code[20]): Decimal
    var
        Vendor: Record Vendor;
    begin
        if not TryGetVendor(VendorNo, Vendor) then
            exit(50);  // No data, neutral score

        if Vendor."Quality Accept Rate %" > 0 then
            exit(Vendor."Quality Accept Rate %");

        exit(50);  // No data, neutral score
    end;

    procedure GetDeliveryScore(VendorNo: Code[20]): Decimal
    var
        Vendor: Record Vendor;
    begin
        if not TryGetVendor(VendorNo, Vendor) then
            exit(50);  // No data, neutral score

        if Vendor."On-Time Delivery %" > 0 then
            exit(Vendor."On-Time Delivery %");

        exit(50);  // No data, neutral score
    end;

    procedure GetPerformanceScore(VendorNo: Code[20]): Decimal
    var
        Vendor: Record Vendor;
    begin
        if not TryGetVendor(VendorNo, Vendor) then
            exit(0);

        exit(Vendor."Performance Score");
    end;

    procedure GetVendorScores(VendorNo: Code[20]; var QualityScore: Decimal; var DeliveryScore: Decimal; var PerformanceScore: Decimal)
    var
        Vendor: Record Vendor;
    begin
        // Optimized: Single Vendor.Get() for all scores
        if not Vendor.Get(VendorNo) then begin
            QualityScore := 50;
            DeliveryScore := 50;
            PerformanceScore := 0;
            exit;
        end;

        if Vendor."Quality Accept Rate %" > 0 then
            QualityScore := Vendor."Quality Accept Rate %"
        else
            QualityScore := 50;

        if Vendor."On-Time Delivery %" > 0 then
            DeliveryScore := Vendor."On-Time Delivery %"
        else
            DeliveryScore := 50;

        PerformanceScore := Vendor."Performance Score";
    end;

    local procedure TryGetVendor(VendorNo: Code[20]; var Vendor: Record Vendor): Boolean
    begin
        // Simple wrapper for future caching if needed
        exit(Vendor.Get(VendorNo));
    end;

    procedure CanVendorMeetDate(VendorNo: Code[20]; ItemNo: Code[20]; LocationCode: Code[10]; RequiredDate: Date): Boolean
    var
        LeadTimeDays: Integer;
        ExpectedDate: Date;
    begin
        LeadTimeDays := GetVendorLeadTimeDays(VendorNo, ItemNo, LocationCode);
        ExpectedDate := CalcDate('<' + Format(LeadTimeDays) + 'D>', Today);
        exit(ExpectedDate <= RequiredDate);
    end;

    procedure GetExpectedDeliveryDate(VendorNo: Code[20]; ItemNo: Code[20]; LocationCode: Code[10]): Date
    var
        LeadTimeDays: Integer;
    begin
        LeadTimeDays := GetVendorLeadTimeDays(VendorNo, ItemNo, LocationCode);
        exit(CalcDate('<' + Format(LeadTimeDays) + 'D>', Today));
    end;

    procedure GetVendorLeadTimeDays(VendorNo: Code[20]; ItemNo: Code[20]; LocationCode: Code[10]): Integer
    var
        ItemVendor: Record "Item Vendor";
        SKU: Record "Stockkeeping Unit";
        Item: Record Item;
        LeadTimeFormula: DateFormula;
        LeadTimeDays: Integer;
    begin
        // Priority: SKU > Item Vendor > Item > Default (7 days)

        // Check SKU
        if SKU.Get(LocationCode, ItemNo, '') then
            if Format(SKU."Lead Time Calculation") <> '' then begin
                LeadTimeFormula := SKU."Lead Time Calculation";
                exit(CalcDate(LeadTimeFormula, Today) - Today);
            end;

        // Check Item Vendor
        if ItemVendor.Get(VendorNo, ItemNo, '') then
            if Format(ItemVendor."Lead Time Calculation") <> '' then begin
                LeadTimeFormula := ItemVendor."Lead Time Calculation";
                exit(CalcDate(LeadTimeFormula, Today) - Today);
            end;

        // Check Item
        if Item.Get(ItemNo) then
            if Format(Item."Lead Time Calculation") <> '' then begin
                LeadTimeFormula := Item."Lead Time Calculation";
                exit(CalcDate(LeadTimeFormula, Today) - Today);
            end;

        // Default
        exit(7);
    end;

    procedure GetVendorUnitCost(VendorNo: Code[20]; ItemNo: Code[20]; Quantity: Decimal): Decimal
    var
        Item: Record Item;
    begin
        // Use item's last direct cost or unit cost as vendor pricing baseline
        // Note: For vendor-specific pricing, implement BC Price Source Group integration
        if Item.Get(ItemNo) then begin
            if Item."Last Direct Cost" > 0 then
                exit(Item."Last Direct Cost");
            exit(Item."Unit Cost");
        end;

        exit(0);
    end;

    procedure GetRecommendationReason(VendorNo: Code[20]; ItemNo: Code[20]; LocationCode: Code[10]; RequiredQty: Decimal; RequiredDate: Date): Text[500]
    var
        Vendor: Record Vendor;
        ReasonText: Text[500];
        LeadTimeDays: Integer;
        UnitCost: Decimal;
        CanMeet: Boolean;
    begin
        if not Vendor.Get(VendorNo) then
            exit('Vendor not found');

        LeadTimeDays := GetVendorLeadTimeDays(VendorNo, ItemNo, LocationCode);
        UnitCost := GetVendorUnitCost(VendorNo, ItemNo, RequiredQty);
        CanMeet := CanVendorMeetDate(VendorNo, ItemNo, LocationCode, RequiredDate);

        ReasonText := 'Recommended: ';

        if Vendor."Performance Score" >= 80 then
            ReasonText += 'High performance score (' + Format(Vendor."Performance Score", 0, '<Integer>') + '%). ';

        if CanMeet then
            ReasonText += 'Can meet required date. '
        else
            ReasonText += 'Lead time: ' + Format(LeadTimeDays) + ' days. ';

        if Vendor."On-Time Delivery %" >= 95 then
            ReasonText += 'Excellent delivery record. ';

        if Vendor."Quality Accept Rate %" >= 99 then
            ReasonText += 'Top quality. ';

        if UnitCost > 0 then
            ReasonText += 'Unit cost: ' + Format(UnitCost, 0, '<Precision,2:2><Standard Format,0>');

        exit(ReasonText);
    end;
}
