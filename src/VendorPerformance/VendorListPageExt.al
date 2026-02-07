pageextension 50121 "Vendor List Perf Ext" extends "Vendor List"
{
    layout
    {
        addafter(Name)
        {
            field("Performance Score"; Rec."Performance Score")
            {
                ApplicationArea = All;
                ToolTip = 'The overall vendor performance score (0-100).';
                StyleExpr = ScoreStyle;
                Visible = ShowPerformanceColumns;

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
                Visible = ShowPerformanceColumns;
            }
            field("Score Trend"; Rec."Score Trend")
            {
                ApplicationArea = All;
                ToolTip = 'Whether the vendor score is improving, stable, or declining.';
                StyleExpr = TrendStyle;
                Visible = ShowPerformanceColumns;
            }
        }
    }

    actions
    {
        addlast(Navigation)
        {
            action(VendorPerformanceList)
            {
                ApplicationArea = All;
                Caption = 'Vendor Performance';
                ToolTip = 'View vendor performance metrics.';
                Image = Statistics;
                RunObject = page "Vendor Performance List";
            }
        }
        addlast(Processing)
        {
            action(CalculateAllPerformance)
            {
                ApplicationArea = All;
                Caption = 'Calculate All Performance';
                ToolTip = 'Calculate performance metrics for all vendors for the current month.';
                Image = Calculate;

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
                    Message('Performance calculation completed for all vendors.');
                end;
            }
            action(TogglePerformanceColumns)
            {
                ApplicationArea = All;
                Caption = 'Show/Hide Performance';
                ToolTip = 'Show or hide the performance score columns.';
                Image = ShowSelected;

                trigger OnAction()
                begin
                    ShowPerformanceColumns := not ShowPerformanceColumns;
                end;
            }
        }
    }

    var
        ScoreStyle: Text;
        RiskStyle: Text;
        TrendStyle: Text;
        ShowPerformanceColumns: Boolean;

    trigger OnOpenPage()
    begin
        ShowPerformanceColumns := true;
    end;

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
