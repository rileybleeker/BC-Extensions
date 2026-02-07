page 50121 "Vendor Performance Card"
{
    PageType = Card;
    ApplicationArea = All;
    SourceTable = "Vendor Performance";
    Caption = 'Vendor Performance';
    Editable = false;

    layout
    {
        area(Content)
        {
            group(General)
            {
                Caption = 'General';

                field("Vendor No."; Rec."Vendor No.")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the vendor number.';
                }
                field(VendorName; Rec.GetVendorName())
                {
                    ApplicationArea = All;
                    Caption = 'Vendor Name';
                    ToolTip = 'Specifies the vendor name.';
                }
                field("Period Start Date"; Rec."Period Start Date")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the start date of the performance period.';
                }
                field("Period End Date"; Rec."Period End Date")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the end date of the performance period.';
                }
                field(PeriodDescription; Rec.GetPeriodDescription())
                {
                    ApplicationArea = All;
                    Caption = 'Period';
                    ToolTip = 'Specifies the performance period.';
                }
            }
            group(OverallPerformance)
            {
                Caption = 'Overall Performance';

                field("Overall Score"; Rec."Overall Score")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the overall vendor performance score (0-100).';
                    StyleExpr = ScoreStyle;
                    Style = Strong;
                }
                field("Risk Level"; Rec."Risk Level")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the vendor risk level based on performance.';
                    StyleExpr = RiskStyle;
                }
                field("Score Trend"; Rec."Score Trend")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies whether the vendor score is improving, stable, or declining.';
                    StyleExpr = TrendStyle;
                }
                field("Calculation Notes"; Rec."Calculation Notes")
                {
                    ApplicationArea = All;
                    ToolTip = 'Shows the calculation formula used for the overall score.';
                    MultiLine = true;
                }
            }
            group(DeliveryPerformance)
            {
                Caption = 'Delivery Performance';

                field("Total Receipts"; Rec."Total Receipts")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the total number of receipts in the period.';
                }
                field("On-Time Receipts"; Rec."On-Time Receipts")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the number of on-time receipts.';
                }
                field("Early Receipts"; Rec."Early Receipts")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the number of early receipts.';
                }
                field("Late Receipts"; Rec."Late Receipts")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the number of late receipts.';
                    StyleExpr = LateReceiptsStyle;
                }
                field("On-Time Delivery %"; Rec."On-Time Delivery %")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the percentage of on-time deliveries.';
                    StyleExpr = OnTimeStyle;
                }
            }
            group(LeadTimePerformance)
            {
                Caption = 'Lead Time Performance';

                field("Avg Promised Lead Time Days"; Rec."Avg Promised Lead Time Days")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the average promised lead time in days.';
                }
                field("Avg Actual Lead Time Days"; Rec."Avg Actual Lead Time Days")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the average actual lead time in days.';
                }
                field("Lead Time Variance Days"; Rec."Lead Time Variance Days")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the average lead time variance (positive = late, negative = early).';
                    StyleExpr = VarianceStyle;
                }
                field("Lead Time Std Dev"; Rec."Lead Time Std Dev")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the standard deviation of lead time variance.';
                }
                field("Lead Time Reliability %"; Rec."Lead Time Reliability %")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the percentage of deliveries within lead time tolerance.';
                    StyleExpr = ReliabilityStyle;
                }
            }
            group(QualityPerformance)
            {
                Caption = 'Quality Performance';

                field("Total Qty Received"; Rec."Total Qty Received")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the total quantity received.';
                }
                field("Qty Accepted"; Rec."Qty Accepted")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the quantity accepted.';
                }
                field("Qty Rejected"; Rec."Qty Rejected")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the quantity rejected.';
                    StyleExpr = RejectedStyle;
                }
                field("Quality Accept Rate %"; Rec."Quality Accept Rate %")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the quality acceptance rate.';
                    StyleExpr = QualityStyle;
                }
                field("PPM Defect Rate"; Rec."PPM Defect Rate")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the defect rate in parts per million.';
                }
                field("NCR Count"; Rec."NCR Count")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the number of non-conformance reports.';
                }
            }
            group(PricingPerformance)
            {
                Caption = 'Pricing Performance';

                field("Avg Price Variance %"; Rec."Avg Price Variance %")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the average price variance from catalog prices.';
                }
                field("Price Stability Score"; Rec."Price Stability Score")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the price stability score (0-100).';
                }
            }
            group(Metadata)
            {
                Caption = 'Calculation Info';

                field("Last Calculated"; Rec."Last Calculated")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies when the performance was last calculated.';
                }
            }
        }
    }

    actions
    {
        area(Processing)
        {
            action(Recalculate)
            {
                ApplicationArea = All;
                Caption = 'Recalculate';
                ToolTip = 'Recalculate performance metrics for this vendor and period.';
                Image = Recalculate;
                Promoted = true;
                PromotedCategory = Process;
                PromotedIsBig = true;

                trigger OnAction()
                var
                    VendorPerfCalc: Codeunit "Vendor Performance Calculator";
                begin
                    VendorPerfCalc.CalculateVendorPerformance(Rec."Vendor No.", Rec."Period Start Date", Rec."Period End Date");
                    CurrPage.Update(false);
                    Message('Performance recalculated.');
                end;
            }
        }
        area(Navigation)
        {
            action(ViewVendor)
            {
                ApplicationArea = All;
                Caption = 'View Vendor';
                ToolTip = 'Open the vendor card.';
                Image = Vendor;
                Promoted = true;
                PromotedCategory = Category4;
                RunObject = page "Vendor Card";
                RunPageLink = "No." = field("Vendor No.");
            }
            action(ViewLeadTimeVariance)
            {
                ApplicationArea = All;
                Caption = 'Lead Time Variance Entries';
                ToolTip = 'View lead time variance entries for this vendor and period.';
                Image = ItemTrackingLines;
                Promoted = true;
                PromotedCategory = Category4;

                trigger OnAction()
                var
                    LeadTimeVariance: Record "Lead Time Variance Entry";
                    LeadTimeVariancePage: Page "Lead Time Variance Entries";
                begin
                    LeadTimeVariance.SetRange("Vendor No.", Rec."Vendor No.");
                    LeadTimeVariance.SetRange("Actual Receipt Date", Rec."Period Start Date", Rec."Period End Date");
                    LeadTimeVariancePage.SetTableView(LeadTimeVariance);
                    LeadTimeVariancePage.Run();
                end;
            }
            action(ViewHistoricalPerformance)
            {
                ApplicationArea = All;
                Caption = 'Historical Performance';
                ToolTip = 'View all performance periods for this vendor.';
                Image = History;
                Promoted = true;
                PromotedCategory = Category4;

                trigger OnAction()
                var
                    VendorPerf: Record "Vendor Performance";
                    VendorPerfList: Page "Vendor Performance List";
                begin
                    VendorPerf.SetRange("Vendor No.", Rec."Vendor No.");
                    VendorPerfList.SetTableView(VendorPerf);
                    VendorPerfList.Run();
                end;
            }
        }
    }

    var
        ScoreStyle: Text;
        RiskStyle: Text;
        TrendStyle: Text;
        OnTimeStyle: Text;
        LateReceiptsStyle: Text;
        VarianceStyle: Text;
        ReliabilityStyle: Text;
        QualityStyle: Text;
        RejectedStyle: Text;

    trigger OnAfterGetRecord()
    begin
        SetStyles();
    end;

    local procedure SetStyles()
    begin
        // Score style
        if Rec."Overall Score" >= 80 then
            ScoreStyle := 'Favorable'
        else if Rec."Overall Score" >= 60 then
            ScoreStyle := 'Ambiguous'
        else if Rec."Overall Score" >= 40 then
            ScoreStyle := 'Attention'
        else
            ScoreStyle := 'Unfavorable';

        // Risk style
        case Rec."Risk Level" of
            Rec."Risk Level"::Low:
                RiskStyle := 'Favorable';
            Rec."Risk Level"::Medium:
                RiskStyle := 'Ambiguous';
            Rec."Risk Level"::High:
                RiskStyle := 'Attention';
            Rec."Risk Level"::Critical:
                RiskStyle := 'Unfavorable';
        end;

        // Trend style
        case Rec."Score Trend" of
            Rec."Score Trend"::Improving:
                TrendStyle := 'Favorable';
            Rec."Score Trend"::Stable:
                TrendStyle := 'Standard';
            Rec."Score Trend"::Declining:
                TrendStyle := 'Unfavorable';
            else
                TrendStyle := 'Subordinate';
        end;

        // On-time delivery style
        if Rec."On-Time Delivery %" >= 95 then
            OnTimeStyle := 'Favorable'
        else if Rec."On-Time Delivery %" >= 85 then
            OnTimeStyle := 'Ambiguous'
        else
            OnTimeStyle := 'Unfavorable';

        // Late receipts style
        if Rec."Late Receipts" = 0 then
            LateReceiptsStyle := 'Favorable'
        else if Rec."Late Receipts" <= 2 then
            LateReceiptsStyle := 'Ambiguous'
        else
            LateReceiptsStyle := 'Unfavorable';

        // Variance style
        if Abs(Rec."Lead Time Variance Days") <= 1 then
            VarianceStyle := 'Favorable'
        else if Abs(Rec."Lead Time Variance Days") <= 3 then
            VarianceStyle := 'Ambiguous'
        else
            VarianceStyle := 'Unfavorable';

        // Reliability style
        if Rec."Lead Time Reliability %" >= 90 then
            ReliabilityStyle := 'Favorable'
        else if Rec."Lead Time Reliability %" >= 75 then
            ReliabilityStyle := 'Ambiguous'
        else
            ReliabilityStyle := 'Unfavorable';

        // Quality style
        if Rec."Quality Accept Rate %" >= 99 then
            QualityStyle := 'Favorable'
        else if Rec."Quality Accept Rate %" >= 95 then
            QualityStyle := 'Ambiguous'
        else
            QualityStyle := 'Unfavorable';

        // Rejected style
        if Rec."Qty Rejected" = 0 then
            RejectedStyle := 'Favorable'
        else
            RejectedStyle := 'Unfavorable';
    end;
}
