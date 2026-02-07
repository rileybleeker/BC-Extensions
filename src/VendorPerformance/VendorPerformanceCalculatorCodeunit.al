codeunit 50120 "Vendor Performance Calculator"
{
    procedure CalculateVendorPerformance(VendorNo: Code[20]; PeriodStartDate: Date; PeriodEndDate: Date)
    var
        VendorPerformance: Record "Vendor Performance";
    begin
        // Create or update the performance record
        if not VendorPerformance.Get(VendorNo, PeriodStartDate) then begin
            VendorPerformance.Init();
            VendorPerformance."Vendor No." := VendorNo;
            VendorPerformance."Period Start Date" := PeriodStartDate;
            VendorPerformance."Period End Date" := PeriodEndDate;
            VendorPerformance.Insert(true);
        end else begin
            VendorPerformance."Period End Date" := PeriodEndDate;
        end;

        // Calculate all metrics
        CalculateDeliveryPerformance(VendorPerformance);
        CalculateLeadTimeMetrics(VendorPerformance);
        CalculateQualityMetrics(VendorPerformance);
        CalculatePricingMetrics(VendorPerformance);
        CalculateOverallScore(VendorPerformance);
        DetermineRiskLevel(VendorPerformance);
        VendorPerformance."Score Trend" := CalculateScoreTrend(VendorNo);

        VendorPerformance."Last Calculated" := CurrentDateTime;
        VendorPerformance.Modify(true);

        // Update Vendor record with latest performance data
        UpdateVendorPerformanceFields(VendorNo, VendorPerformance);
    end;

    local procedure UpdateVendorPerformanceFields(VendorNo: Code[20]; VendorPerf: Record "Vendor Performance")
    var
        Vendor: Record Vendor;
    begin
        if not Vendor.Get(VendorNo) then
            exit;

        Vendor."Performance Score" := VendorPerf."Overall Score";
        Vendor."Performance Risk Level" := VendorPerf."Risk Level";
        Vendor."On-Time Delivery %" := VendorPerf."On-Time Delivery %";
        Vendor."Quality Accept Rate %" := VendorPerf."Quality Accept Rate %";
        Vendor."Lead Time Variance Days" := VendorPerf."Lead Time Variance Days";
        Vendor."Score Trend" := VendorPerf."Score Trend";
        Vendor."Last Performance Calc" := VendorPerf."Last Calculated";
        Vendor.Modify(true);
    end;

    procedure CalculateMonthlySnapshot(VendorNo: Code[20]; Year: Integer; Month: Integer)
    var
        PeriodStartDate: Date;
        PeriodEndDate: Date;
    begin
        PeriodStartDate := DMY2Date(1, Month, Year);
        PeriodEndDate := CalcDate('<CM>', PeriodStartDate);
        CalculateVendorPerformance(VendorNo, PeriodStartDate, PeriodEndDate);
    end;

    procedure CalculateAllVendorsForPeriod(PeriodStartDate: Date; PeriodEndDate: Date)
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
            ProgressDialog.Open('Calculating vendor performance...\Vendor: #1########\Progress: #2### of #3###');

        if Vendor.FindSet() then
            repeat
                Counter += 1;
                if GuiAllowed then begin
                    ProgressDialog.Update(1, Vendor."No.");
                    ProgressDialog.Update(2, Counter);
                    ProgressDialog.Update(3, Total);
                end;
                CalculateVendorPerformance(Vendor."No.", PeriodStartDate, PeriodEndDate);
            until Vendor.Next() = 0;

        if GuiAllowed then
            ProgressDialog.Close();
    end;

    procedure CalculateAllVendorsMonthly(Year: Integer; Month: Integer)
    var
        PeriodStartDate: Date;
        PeriodEndDate: Date;
    begin
        PeriodStartDate := DMY2Date(1, Month, Year);
        PeriodEndDate := CalcDate('<CM>', PeriodStartDate);
        CalculateAllVendorsForPeriod(PeriodStartDate, PeriodEndDate);
    end;

    local procedure CalculateDeliveryPerformance(var VendorPerf: Record "Vendor Performance")
    var
        LeadTimeVariance: Record "Lead Time Variance Entry";
        TotalReceipts: Integer;
        OnTimeReceipts: Integer;
        EarlyReceipts: Integer;
        LateReceipts: Integer;
    begin
        LeadTimeVariance.SetRange("Vendor No.", VendorPerf."Vendor No.");
        LeadTimeVariance.SetRange("Actual Receipt Date", VendorPerf."Period Start Date", VendorPerf."Period End Date");

        if LeadTimeVariance.FindSet() then
            repeat
                TotalReceipts += 1;
                case LeadTimeVariance."Delivery Status" of
                    LeadTimeVariance."Delivery Status"::"On Time":
                        OnTimeReceipts += 1;
                    LeadTimeVariance."Delivery Status"::Early:
                        EarlyReceipts += 1;
                    LeadTimeVariance."Delivery Status"::Late:
                        LateReceipts += 1;
                end;
            until LeadTimeVariance.Next() = 0;

        VendorPerf."Total Receipts" := TotalReceipts;
        VendorPerf."On-Time Receipts" := OnTimeReceipts;
        VendorPerf."Early Receipts" := EarlyReceipts;
        VendorPerf."Late Receipts" := LateReceipts;

        if TotalReceipts > 0 then
            VendorPerf."On-Time Delivery %" := Round((OnTimeReceipts / TotalReceipts) * 100, 0.01)
        else
            VendorPerf."On-Time Delivery %" := 0;
    end;

    local procedure CalculateLeadTimeMetrics(var VendorPerf: Record "Vendor Performance")
    var
        LeadTimeVariance: Record "Lead Time Variance Entry";
        TempLeadTimeData: Record "Lead Time Variance Entry" temporary;
        MfgSetup: Record "Manufacturing Setup";
        TotalPromisedDays: Decimal;
        TotalActualDays: Decimal;
        TotalVarianceDays: Decimal;
        TotalVarianceSquared: Decimal;
        AvgVariance: Decimal;
        Count: Integer;
        WithinToleranceCount: Integer;
        TolerancePct: Decimal;
        AvgPromised: Decimal;
    begin
        MfgSetup.Get();
        TolerancePct := MfgSetup."Lead Time Variance Tolerance %";

        LeadTimeVariance.SetRange("Vendor No.", VendorPerf."Vendor No.");
        LeadTimeVariance.SetRange("Actual Receipt Date", VendorPerf."Period Start Date", VendorPerf."Period End Date");

        // First pass: collect data and calculate totals
        if LeadTimeVariance.FindSet() then
            repeat
                Count += 1;
                TotalPromisedDays += LeadTimeVariance."Promised Lead Time Days";
                TotalActualDays += LeadTimeVariance."Actual Lead Time Days";
                TotalVarianceDays += LeadTimeVariance."Variance Days";

                // Store for second pass (std dev calculation)
                TempLeadTimeData := LeadTimeVariance;
                TempLeadTimeData.Insert();
            until LeadTimeVariance.Next() = 0;

        if Count > 0 then begin
            AvgPromised := TotalPromisedDays / Count;
            VendorPerf."Avg Promised Lead Time Days" := Round(AvgPromised, 0.1);
            VendorPerf."Avg Actual Lead Time Days" := Round(TotalActualDays / Count, 0.1);
            VendorPerf."Lead Time Variance Days" := VendorPerf."Avg Actual Lead Time Days" - VendorPerf."Avg Promised Lead Time Days";
            AvgVariance := TotalVarianceDays / Count;

            // Second pass using temp table (in memory - faster than re-querying DB)
            if TempLeadTimeData.FindSet() then
                repeat
                    TotalVarianceSquared += Power(TempLeadTimeData."Variance Days" - AvgVariance, 2);

                    // Check if within tolerance
                    if AvgPromised > 0 then begin
                        if Abs(TempLeadTimeData."Variance Days" / AvgPromised * 100) <= TolerancePct then
                            WithinToleranceCount += 1;
                    end else
                        WithinToleranceCount += 1;
                until TempLeadTimeData.Next() = 0;

            if Count > 1 then
                VendorPerf."Lead Time Std Dev" := Round(Power(TotalVarianceSquared / (Count - 1), 0.5), 0.01)
            else
                VendorPerf."Lead Time Std Dev" := 0;

            VendorPerf."Lead Time Reliability %" := Round((WithinToleranceCount / Count) * 100, 0.01);
        end else begin
            VendorPerf."Avg Promised Lead Time Days" := 0;
            VendorPerf."Avg Actual Lead Time Days" := 0;
            VendorPerf."Lead Time Variance Days" := 0;
            VendorPerf."Lead Time Std Dev" := 0;
            VendorPerf."Lead Time Reliability %" := 0;
        end;
    end;

    local procedure CalculateQualityMetrics(var VendorPerf: Record "Vendor Performance")
    var
        PurchRcptLine: Record "Purch. Rcpt. Line";
        VendorNCRMgt: Codeunit "Vendor NCR Management";
        TotalQtyReceived: Decimal;
        QtyRejected: Decimal;
        NCRCount: Integer;
    begin
        // Get total quantity received from purchase receipt lines
        PurchRcptLine.SetRange("Buy-from Vendor No.", VendorPerf."Vendor No.");
        PurchRcptLine.SetRange("Posting Date", VendorPerf."Period Start Date", VendorPerf."Period End Date");
        PurchRcptLine.SetFilter(Type, '%1', PurchRcptLine.Type::Item);
        PurchRcptLine.CalcSums(Quantity);
        TotalQtyReceived := PurchRcptLine.Quantity;

        // Get NCR count and rejected quantity using CalcSums (optimized)
        NCRCount := VendorNCRMgt.GetNCRCountForVendor(VendorPerf."Vendor No.", VendorPerf."Period Start Date", VendorPerf."Period End Date");
        QtyRejected := VendorNCRMgt.GetTotalAffectedQty(VendorPerf."Vendor No.", VendorPerf."Period Start Date", VendorPerf."Period End Date");

        VendorPerf."Total Qty Received" := TotalQtyReceived;
        VendorPerf."Qty Rejected" := QtyRejected;
        VendorPerf."Qty Accepted" := TotalQtyReceived - QtyRejected;

        if TotalQtyReceived > 0 then begin
            VendorPerf."Quality Accept Rate %" := Round((VendorPerf."Qty Accepted" / TotalQtyReceived) * 100, 0.01);
            VendorPerf."PPM Defect Rate" := Round((QtyRejected / TotalQtyReceived) * 1000000, 1);
        end else begin
            VendorPerf."Quality Accept Rate %" := 100;  // No receipts = no rejections
            VendorPerf."PPM Defect Rate" := 0;
        end;

        VendorPerf."NCR Count" := NCRCount;
    end;

    local procedure CalculatePricingMetrics(var VendorPerf: Record "Vendor Performance")
    var
        PurchInvLine: Record "Purch. Inv. Line";
        Item: Record Item;
        TotalVariance: Decimal;
        TotalLines: Integer;
        ExpectedCost: Decimal;
        ActualCost: Decimal;
    begin
        // Calculate price variance from invoices vs item standard cost
        PurchInvLine.SetRange("Buy-from Vendor No.", VendorPerf."Vendor No.");
        PurchInvLine.SetRange("Posting Date", VendorPerf."Period Start Date", VendorPerf."Period End Date");
        PurchInvLine.SetFilter(Type, '%1', PurchInvLine.Type::Item);

        if PurchInvLine.FindSet() then
            repeat
                TotalLines += 1;
                ActualCost := PurchInvLine."Direct Unit Cost";

                // Get expected cost from Item's standard cost
                if Item.Get(PurchInvLine."No.") and (Item."Unit Cost" > 0) then
                    ExpectedCost := Item."Unit Cost"
                else
                    ExpectedCost := ActualCost;  // No standard cost, assume actual is expected

                if ExpectedCost > 0 then
                    TotalVariance += Abs((ActualCost - ExpectedCost) / ExpectedCost * 100);
            until PurchInvLine.Next() = 0;

        if TotalLines > 0 then begin
            VendorPerf."Avg Price Variance %" := Round(TotalVariance / TotalLines, 0.01);
            // Price stability = 100 - average variance (capped at 0-100)
            VendorPerf."Price Stability Score" := Round(100 - VendorPerf."Avg Price Variance %", 0.01);
            if VendorPerf."Price Stability Score" < 0 then
                VendorPerf."Price Stability Score" := 0;
        end else begin
            VendorPerf."Avg Price Variance %" := 0;
            VendorPerf."Price Stability Score" := 100;  // No data = assume stable
        end;
    end;

    local procedure CalculateOverallScore(var VendorPerf: Record "Vendor Performance")
    var
        MfgSetup: Record "Manufacturing Setup";
        WeightedScore: Decimal;
        TotalWeight: Decimal;
    begin
        MfgSetup.Get();

        // Weighted composite score formula
        WeightedScore := 0;
        TotalWeight := MfgSetup."On-Time Delivery Weight" +
                       MfgSetup."Quality Weight" +
                       MfgSetup."Lead Time Reliability Weight" +
                       MfgSetup."Price Stability Weight";

        if TotalWeight = 0 then
            TotalWeight := 100;  // Default weights sum to 100

        WeightedScore += VendorPerf."On-Time Delivery %" * (MfgSetup."On-Time Delivery Weight" / TotalWeight);
        WeightedScore += VendorPerf."Quality Accept Rate %" * (MfgSetup."Quality Weight" / TotalWeight);
        WeightedScore += VendorPerf."Lead Time Reliability %" * (MfgSetup."Lead Time Reliability Weight" / TotalWeight);
        WeightedScore += VendorPerf."Price Stability Score" * (MfgSetup."Price Stability Weight" / TotalWeight);

        VendorPerf."Overall Score" := Round(WeightedScore, 0.01);

        VendorPerf."Calculation Notes" := StrSubstNo(
            'Score = (OTD %.2f × %1%%) + (Qual %.2f × %2%%) + (LT %.2f × %3%%) + (Price %.2f × %4%%)',
            MfgSetup."On-Time Delivery Weight",
            MfgSetup."Quality Weight",
            MfgSetup."Lead Time Reliability Weight",
            MfgSetup."Price Stability Weight"
        );
    end;

    local procedure DetermineRiskLevel(var VendorPerf: Record "Vendor Performance")
    var
        MfgSetup: Record "Manufacturing Setup";
    begin
        MfgSetup.Get();

        if VendorPerf."Overall Score" >= MfgSetup."Low Risk Score Threshold" then
            VendorPerf."Risk Level" := VendorPerf."Risk Level"::Low
        else if VendorPerf."Overall Score" >= MfgSetup."Medium Risk Score Threshold" then
            VendorPerf."Risk Level" := VendorPerf."Risk Level"::Medium
        else if VendorPerf."Overall Score" >= MfgSetup."High Risk Score Threshold" then
            VendorPerf."Risk Level" := VendorPerf."Risk Level"::High
        else
            VendorPerf."Risk Level" := VendorPerf."Risk Level"::Critical;
    end;

    local procedure CalculateScoreTrend(VendorNo: Code[20]): Enum "Vendor Score Trend"
    var
        VendorPerf: Record "Vendor Performance";
        RecentScore: Decimal;
        PreviousScore: Decimal;
        RecentCount: Integer;
        PreviousCount: Integer;
        ScoreDiff: Decimal;
        TrendThreshold: Decimal;
    begin
        TrendThreshold := 5;  // 5% change threshold for trend detection

        // Get average of last 3 months
        VendorPerf.SetRange("Vendor No.", VendorNo);
        VendorPerf.SetCurrentKey("Vendor No.", "Period Start Date");
        VendorPerf.SetAscending("Period Start Date", false);

        if VendorPerf.FindSet() then
            repeat
                if RecentCount < 3 then begin
                    RecentScore += VendorPerf."Overall Score";
                    RecentCount += 1;
                end else if PreviousCount < 3 then begin
                    PreviousScore += VendorPerf."Overall Score";
                    PreviousCount += 1;
                end;
            until (VendorPerf.Next() = 0) or (PreviousCount >= 3);

        if (RecentCount = 0) or (PreviousCount = 0) then
            exit("Vendor Score Trend"::Unknown);

        RecentScore := RecentScore / RecentCount;
        PreviousScore := PreviousScore / PreviousCount;
        ScoreDiff := RecentScore - PreviousScore;

        if ScoreDiff > TrendThreshold then
            exit("Vendor Score Trend"::Improving)
        else if ScoreDiff < -TrendThreshold then
            exit("Vendor Score Trend"::Declining)
        else
            exit("Vendor Score Trend"::Stable);
    end;

    procedure GetCurrentScore(VendorNo: Code[20]): Decimal
    var
        VendorPerf: Record "Vendor Performance";
    begin
        VendorPerf.SetRange("Vendor No.", VendorNo);
        VendorPerf.SetCurrentKey("Vendor No.", "Period Start Date");
        VendorPerf.SetAscending("Period Start Date", false);
        if VendorPerf.FindFirst() then
            exit(VendorPerf."Overall Score");
        exit(0);
    end;

    procedure GetCurrentRiskLevel(VendorNo: Code[20]): Enum "Vendor Risk Level"
    var
        VendorPerf: Record "Vendor Performance";
    begin
        VendorPerf.SetRange("Vendor No.", VendorNo);
        VendorPerf.SetCurrentKey("Vendor No.", "Period Start Date");
        VendorPerf.SetAscending("Period Start Date", false);
        if VendorPerf.FindFirst() then
            exit(VendorPerf."Risk Level");
        exit("Vendor Risk Level"::Low);
    end;

    procedure GetRollingAverageScore(VendorNo: Code[20]; Months: Integer): Decimal
    var
        VendorPerf: Record "Vendor Performance";
        TotalScore: Decimal;
        Count: Integer;
    begin
        VendorPerf.SetRange("Vendor No.", VendorNo);
        VendorPerf.SetCurrentKey("Vendor No.", "Period Start Date");
        VendorPerf.SetAscending("Period Start Date", false);

        if VendorPerf.FindSet() then
            repeat
                TotalScore += VendorPerf."Overall Score";
                Count += 1;
            until (VendorPerf.Next() = 0) or (Count >= Months);

        if Count > 0 then
            exit(Round(TotalScore / Count, 0.01));
        exit(0);
    end;
}
