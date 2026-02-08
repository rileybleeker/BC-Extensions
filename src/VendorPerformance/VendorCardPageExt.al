pageextension 50120 "Vendor Card Perf Ext" extends "Vendor Card"
{
    layout
    {
        addafter(General)
        {
            group(PerformanceIndicators)
            {
                Caption = 'Performance Indicators';

                field("Performance Score"; Rec."Performance Score")
                {
                    ApplicationArea = All;
                    ToolTip = 'The overall vendor performance score (0-100).';
                    StyleExpr = ScoreStyle;
                    Editable = false;

                    trigger OnDrillDown()
                    begin
                        ShowPerformanceHistory();
                    end;
                }
                field("Performance Risk Level"; Rec."Performance Risk Level")
                {
                    ApplicationArea = All;
                    ToolTip = 'The vendor risk level based on performance.';
                    StyleExpr = RiskStyle;
                    Editable = false;
                }
                field("Score Trend"; Rec."Score Trend")
                {
                    ApplicationArea = All;
                    ToolTip = 'Whether the vendor score is improving, stable, or declining.';
                    StyleExpr = TrendStyle;
                    Editable = false;
                }
                field("On-Time Delivery %"; Rec."On-Time Delivery %")
                {
                    ApplicationArea = All;
                    ToolTip = 'Percentage of deliveries received on time.';
                    Editable = false;
                }
                field("Quality Accept Rate %"; Rec."Quality Accept Rate %")
                {
                    ApplicationArea = All;
                    ToolTip = 'Percentage of received goods accepted.';
                    Editable = false;
                }
                field("Lead Time Variance Days"; Rec."Lead Time Variance Days")
                {
                    ApplicationArea = All;
                    ToolTip = 'Average variance from promised lead time (days).';
                    Editable = false;
                }
                field("Lead Time Reliability %"; Rec."Lead Time Reliability %")
                {
                    ApplicationArea = All;
                    ToolTip = 'Percentage of deliveries within the lead time variance tolerance.';
                    Editable = false;
                }
            }
        }
    }

    actions
    {
        addlast(Navigation)
        {
            group(VendorPerformanceGroup)
            {
                Caption = 'Vendor Performance';
                Image = Statistics;

                action(ViewPerformanceHistory)
                {
                    ApplicationArea = All;
                    Caption = 'Performance History';
                    ToolTip = 'View the vendor''s performance history by period.';
                    Image = History;
                    RunObject = page "Vendor Performance List";
                    RunPageLink = "Vendor No." = field("No.");
                }
                action(ViewLeadTimeVariance)
                {
                    ApplicationArea = All;
                    Caption = 'Lead Time Variance';
                    ToolTip = 'View lead time variance entries for this vendor.';
                    Image = ItemTrackingLines;
                    RunObject = page "Lead Time Variance Entries";
                    RunPageLink = "Vendor No." = field("No.");
                }
            }
        }
        addlast(Processing)
        {
            action(RecalculatePerformance)
            {
                ApplicationArea = All;
                Caption = 'Recalculate Performance';
                ToolTip = 'Recalculate the vendor''s performance metrics for the current month.';
                Image = Recalculate;
                Promoted = true;
                PromotedCategory = Process;

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
                    Message('Performance recalculated for vendor %1.', Rec."No.");
                end;
            }
            action(CalculateHistoricalPerformance)
            {
                ApplicationArea = All;
                Caption = 'Calculate Historical (Monthly)';
                ToolTip = 'Calculate the vendor''s historical performance month-by-month.';
                Image = History;

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
                    LeadTimeTracker.CreateEntriesFromHistory(Rec."No.", StartDate, EndDate);

                    // Then calculate monthly performance for each month
                    for i := MfgSetup."Perf Calc Period Months" - 1 downto 0 do begin
                        CurrentMonth := CalcDate('<-' + Format(i) + 'M>', WorkDate());
                        VendorPerfCalc.CalculateVendorPerformance(
                            Rec."No.",
                            CalcDate('<-CM>', CurrentMonth),
                            CalcDate('<CM>', CurrentMonth)
                        );
                    end;

                    CurrPage.Update(false);
                    Message('Historical performance calculated for %1 months (month-by-month).', MfgSetup."Perf Calc Period Months");
                end;
            }
            action(CalculateFullPeriod)
            {
                ApplicationArea = All;
                Caption = 'Calculate Full Period';
                ToolTip = 'Calculate the vendor''s performance across the ENTIRE historical period as one aggregated result.';
                Image = Calculate;
                Promoted = true;
                PromotedCategory = Process;

                trigger OnAction()
                var
                    VendorPerfCalc: Codeunit "Vendor Performance Calculator";
                    LeadTimeTracker: Codeunit "Lead Time Variance Tracker";
                    MfgSetup: Record "Manufacturing Setup";
                    StartDate: Date;
                    EndDate: Date;
                begin
                    MfgSetup.Get();

                    // Calculate dates for the full period
                    StartDate := CalcDate('<-' + Format(MfgSetup."Perf Calc Period Months") + 'M>', WorkDate());
                    EndDate := WorkDate();

                    // First, create historical lead time variance entries
                    LeadTimeTracker.CreateEntriesFromHistory(Rec."No.", StartDate, EndDate);

                    // Calculate performance for the FULL period as one record
                    VendorPerfCalc.CalculateVendorPerformance(Rec."No.", StartDate, EndDate);

                    CurrPage.Update(false);
                    Message('Full period performance calculated for %1 to %2 (%3 months).',
                        StartDate, EndDate, MfgSetup."Perf Calc Period Months");
                end;
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
        if Rec."Performance Score" >= 80 then
            ScoreStyle := 'Favorable'
        else if Rec."Performance Score" >= 60 then
            ScoreStyle := 'Ambiguous'
        else if Rec."Performance Score" >= 40 then
            ScoreStyle := 'Attention'
        else if Rec."Performance Score" > 0 then
            ScoreStyle := 'Unfavorable'
        else
            ScoreStyle := 'Subordinate';

        // Risk style
        case Rec."Performance Risk Level" of
            Rec."Performance Risk Level"::Low:
                RiskStyle := 'Favorable';
            Rec."Performance Risk Level"::Medium:
                RiskStyle := 'Ambiguous';
            Rec."Performance Risk Level"::High:
                RiskStyle := 'Attention';
            Rec."Performance Risk Level"::Critical:
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

    local procedure ShowPerformanceHistory()
    var
        VendorPerf: Record "Vendor Performance";
        VendorPerfList: Page "Vendor Performance List";
    begin
        VendorPerf.SetRange("Vendor No.", Rec."No.");
        VendorPerfList.SetTableView(VendorPerf);
        VendorPerfList.Run();
    end;
}
