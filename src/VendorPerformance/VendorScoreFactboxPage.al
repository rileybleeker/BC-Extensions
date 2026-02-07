page 50122 "Vendor Score Factbox"
{
    PageType = CardPart;
    ApplicationArea = All;
    SourceTable = Vendor;
    Caption = 'Vendor Performance';

    layout
    {
        area(Content)
        {
            group(PerformanceScore)
            {
                Caption = 'Performance';
                ShowCaption = false;

                field(OverallScore; OverallScore)
                {
                    ApplicationArea = All;
                    Caption = 'Overall Score';
                    ToolTip = 'The overall vendor performance score (0-100).';
                    StyleExpr = ScoreStyle;
                    DecimalPlaces = 0 : 0;

                    trigger OnDrillDown()
                    begin
                        ShowPerformanceHistory();
                    end;
                }
                field(RiskLevel; RiskLevel)
                {
                    ApplicationArea = All;
                    Caption = 'Risk Level';
                    ToolTip = 'The vendor risk level based on performance.';
                    StyleExpr = RiskStyle;
                }
                field(ScoreTrend; ScoreTrend)
                {
                    ApplicationArea = All;
                    Caption = 'Trend';
                    ToolTip = 'Whether the vendor score is improving, stable, or declining.';
                    StyleExpr = TrendStyle;
                }
            }
            group(KeyMetrics)
            {
                Caption = 'Key Metrics';
                ShowCaption = true;

                field(OnTimeDeliveryPct; OnTimeDeliveryPct)
                {
                    ApplicationArea = All;
                    Caption = 'On-Time Delivery %';
                    ToolTip = 'Percentage of deliveries received on time.';
                    DecimalPlaces = 0 : 1;
                }
                field(QualityAcceptPct; QualityAcceptPct)
                {
                    ApplicationArea = All;
                    Caption = 'Quality Accept %';
                    ToolTip = 'Percentage of received goods accepted.';
                    DecimalPlaces = 0 : 1;
                }
                field(LeadTimeVariance; LeadTimeVariance)
                {
                    ApplicationArea = All;
                    Caption = 'Lead Time Variance';
                    ToolTip = 'Average variance from promised lead time (days).';
                    DecimalPlaces = 0 : 1;
                    StyleExpr = VarianceStyle;
                }
            }
            group(RecentActivity)
            {
                Caption = 'Recent Activity';
                ShowCaption = true;

                field(TotalReceipts; TotalReceipts)
                {
                    ApplicationArea = All;
                    Caption = 'Receipts (Current Period)';
                    ToolTip = 'Number of receipts in the current performance period.';

                    trigger OnDrillDown()
                    begin
                        ShowLeadTimeVarianceEntries();
                    end;
                }
                field(LastCalculated; LastCalculated)
                {
                    ApplicationArea = All;
                    Caption = 'Last Updated';
                    ToolTip = 'When the performance was last calculated.';
                }
            }
        }
    }

    actions
    {
        area(Processing)
        {
            action(ViewPerformance)
            {
                ApplicationArea = All;
                Caption = 'View Performance History';
                ToolTip = 'View detailed performance history for this vendor.';
                Image = History;

                trigger OnAction()
                begin
                    ShowPerformanceHistory();
                end;
            }
            action(Recalculate)
            {
                ApplicationArea = All;
                Caption = 'Recalculate';
                ToolTip = 'Recalculate vendor performance for the current month.';
                Image = Recalculate;

                trigger OnAction()
                var
                    VendorPerfCalc: Codeunit "Vendor Performance Calculator";
                    PeriodStartDate: Date;
                    PeriodEndDate: Date;
                begin
                    PeriodStartDate := CalcDate('<-CM>', WorkDate());
                    PeriodEndDate := CalcDate('<CM>', WorkDate());
                    VendorPerfCalc.CalculateVendorPerformance(Rec."No.", PeriodStartDate, PeriodEndDate);
                    CurrPage.Update(false);
                end;
            }
        }
    }

    var
        OverallScore: Decimal;
        RiskLevel: Text;
        ScoreTrend: Text;
        OnTimeDeliveryPct: Decimal;
        QualityAcceptPct: Decimal;
        LeadTimeVariance: Decimal;
        TotalReceipts: Integer;
        LastCalculated: DateTime;
        ScoreStyle: Text;
        RiskStyle: Text;
        TrendStyle: Text;
        VarianceStyle: Text;

    trigger OnAfterGetRecord()
    begin
        LoadPerformanceData();
        SetStyles();
    end;

    local procedure LoadPerformanceData()
    var
        VendorPerf: Record "Vendor Performance";
    begin
        // Reset values
        OverallScore := 0;
        RiskLevel := '';
        ScoreTrend := '';
        OnTimeDeliveryPct := 0;
        QualityAcceptPct := 0;
        LeadTimeVariance := 0;
        TotalReceipts := 0;
        LastCalculated := 0DT;

        // Get most recent performance record
        VendorPerf.SetRange("Vendor No.", Rec."No.");
        VendorPerf.SetCurrentKey("Vendor No.", "Period Start Date");
        VendorPerf.SetAscending("Period Start Date", false);

        if VendorPerf.FindFirst() then begin
            OverallScore := VendorPerf."Overall Score";
            RiskLevel := Format(VendorPerf."Risk Level");
            ScoreTrend := Format(VendorPerf."Score Trend");
            OnTimeDeliveryPct := VendorPerf."On-Time Delivery %";
            QualityAcceptPct := VendorPerf."Quality Accept Rate %";
            LeadTimeVariance := VendorPerf."Lead Time Variance Days";
            TotalReceipts := VendorPerf."Total Receipts";
            LastCalculated := VendorPerf."Last Calculated";
        end;
    end;

    local procedure SetStyles()
    begin
        // Score style
        if OverallScore >= 80 then
            ScoreStyle := 'Favorable'
        else if OverallScore >= 60 then
            ScoreStyle := 'Ambiguous'
        else if OverallScore >= 40 then
            ScoreStyle := 'Attention'
        else if OverallScore > 0 then
            ScoreStyle := 'Unfavorable'
        else
            ScoreStyle := 'Subordinate';

        // Risk style
        case RiskLevel of
            'Low':
                RiskStyle := 'Favorable';
            'Medium':
                RiskStyle := 'Ambiguous';
            'High':
                RiskStyle := 'Attention';
            'Critical':
                RiskStyle := 'Unfavorable';
            else
                RiskStyle := 'Subordinate';
        end;

        // Trend style
        case ScoreTrend of
            'Improving':
                TrendStyle := 'Favorable';
            'Stable':
                TrendStyle := 'Standard';
            'Declining':
                TrendStyle := 'Unfavorable';
            else
                TrendStyle := 'Subordinate';
        end;

        // Variance style
        if Abs(LeadTimeVariance) <= 1 then
            VarianceStyle := 'Favorable'
        else if Abs(LeadTimeVariance) <= 3 then
            VarianceStyle := 'Ambiguous'
        else
            VarianceStyle := 'Unfavorable';
    end;

    local procedure ShowPerformanceHistory()
    var
        VendorPerf: Record "Vendor Performance";
        VendorPerfList: Page "Vendor Performance List";
    begin
        VendorPerf.SetRange("Vendor No.", Rec."No.");
        VendorPerfList.SetTableView(VendorPerf);
        VendorPerfList.Run();
    end;

    local procedure ShowLeadTimeVarianceEntries()
    var
        LeadTimeVarianceEntry: Record "Lead Time Variance Entry";
        LeadTimeVariancePage: Page "Lead Time Variance Entries";
    begin
        LeadTimeVarianceEntry.SetRange("Vendor No.", Rec."No.");
        LeadTimeVariancePage.SetTableView(LeadTimeVarianceEntry);
        LeadTimeVariancePage.Run();
    end;
}
