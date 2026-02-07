page 50120 "Vendor Performance List"
{
    PageType = List;
    ApplicationArea = All;
    UsageCategory = Lists;
    SourceTable = "Vendor Performance";
    Caption = 'Vendor Performance';
    Editable = false;
    CardPageId = "Vendor Performance Card";

    layout
    {
        area(Content)
        {
            repeater(Group)
            {
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
                field(PeriodDescription; Rec.GetPeriodDescription())
                {
                    ApplicationArea = All;
                    Caption = 'Period';
                    ToolTip = 'Specifies the performance period.';
                }
                field("Overall Score"; Rec."Overall Score")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the overall vendor performance score (0-100).';
                    StyleExpr = ScoreStyle;
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
                field("On-Time Delivery %"; Rec."On-Time Delivery %")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the percentage of on-time deliveries.';
                }
                field("Quality Accept Rate %"; Rec."Quality Accept Rate %")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the quality acceptance rate.';
                }
                field("Lead Time Reliability %"; Rec."Lead Time Reliability %")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the lead time reliability percentage.';
                }
                field("Price Stability Score"; Rec."Price Stability Score")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the price stability score.';
                }
                field("Total Receipts"; Rec."Total Receipts")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the total number of receipts in the period.';
                }
                field("Last Calculated"; Rec."Last Calculated")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies when the performance was last calculated.';
                }
            }
        }
        area(FactBoxes)
        {
            systempart(Links; Links)
            {
                ApplicationArea = All;
            }
            systempart(Notes; Notes)
            {
                ApplicationArea = All;
            }
        }
    }

    actions
    {
        area(Processing)
        {
            action(CalculateAllVendors)
            {
                ApplicationArea = All;
                Caption = 'Calculate All Vendors';
                ToolTip = 'Calculate performance for all vendors for the current month.';
                Image = Calculate;
                Promoted = true;
                PromotedCategory = Process;
                PromotedIsBig = true;

                trigger OnAction()
                var
                    VendorPerfCalc: Codeunit "Vendor Performance Calculator";
                    PeriodStartDate: Date;
                    PeriodEndDate: Date;
                begin
                    PeriodStartDate := CalcDate('<-CM>', WorkDate());
                    PeriodEndDate := CalcDate('<CM>', WorkDate());
                    VendorPerfCalc.CalculateAllVendorsForPeriod(PeriodStartDate, PeriodEndDate);
                    CurrPage.Update(false);
                    Message('Vendor performance calculation completed.');
                end;
            }
            action(CalculateHistorical)
            {
                ApplicationArea = All;
                Caption = 'Calculate Historical';
                ToolTip = 'Calculate performance for all vendors for the past 12 months.';
                Image = History;
                Promoted = true;
                PromotedCategory = Process;

                trigger OnAction()
                var
                    VendorPerfCalc: Codeunit "Vendor Performance Calculator";
                    LeadTimeTracker: Codeunit "Lead Time Variance Tracker";
                    MfgSetup: Record "Manufacturing Setup";
                    StartDate: Date;
                    EndDate: Date;
                    CurrentMonth: Date;
                    i: Integer;
                begin
                    MfgSetup.Get();

                    // First, create historical lead time variance entries
                    StartDate := CalcDate('<-' + Format(MfgSetup."Perf Calc Period Months") + 'M>', WorkDate());
                    EndDate := WorkDate();
                    LeadTimeTracker.CreateAllHistoricalEntries(StartDate, EndDate);

                    // Then calculate monthly performance for each month
                    for i := MfgSetup."Perf Calc Period Months" - 1 downto 0 do begin
                        CurrentMonth := CalcDate('<-' + Format(i) + 'M>', WorkDate());
                        VendorPerfCalc.CalculateAllVendorsForPeriod(
                            CalcDate('<-CM>', CurrentMonth),
                            CalcDate('<CM>', CurrentMonth)
                        );
                    end;

                    CurrPage.Update(false);
                    Message('Historical performance calculation completed for %1 months.', MfgSetup."Perf Calc Period Months");
                end;
            }
            action(RecalculateSelected)
            {
                ApplicationArea = All;
                Caption = 'Recalculate Selected';
                ToolTip = 'Recalculate performance for the selected vendor and period.';
                Image = Recalculate;
                Promoted = true;
                PromotedCategory = Process;

                trigger OnAction()
                var
                    VendorPerfCalc: Codeunit "Vendor Performance Calculator";
                begin
                    VendorPerfCalc.CalculateVendorPerformance(Rec."Vendor No.", Rec."Period Start Date", Rec."Period End Date");
                    CurrPage.Update(false);
                    Message('Performance recalculated for vendor %1.', Rec."Vendor No.");
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
                Caption = 'Lead Time Variance';
                ToolTip = 'View lead time variance entries for this vendor.';
                Image = ItemTrackingLines;
                Promoted = true;
                PromotedCategory = Category4;
                RunObject = page "Lead Time Variance Entries";
                RunPageLink = "Vendor No." = field("Vendor No.");
            }
        }
    }

    var
        ScoreStyle: Text;
        RiskStyle: Text;
        TrendStyle: Text;

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
    end;
}
