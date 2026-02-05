page 50110 "Planning Analysis Setup"
{
    PageType = Card;
    SourceTable = "Planning Analysis Setup";
    Caption = 'Planning Analysis Setup';
    UsageCategory = Administration;
    ApplicationArea = All;
    InsertAllowed = false;
    DeleteAllowed = false;

    layout
    {
        area(Content)
        {
            group(AnalysisSettings)
            {
                Caption = 'Analysis Settings';

                field("Default Analysis Months"; Rec."Default Analysis Months")
                {
                    ApplicationArea = All;
                    ToolTip = 'The default number of months of historical data to analyze (3-60 months).';
                }
                field("Minimum Data Points"; Rec."Minimum Data Points")
                {
                    ApplicationArea = All;
                    ToolTip = 'The minimum number of demand data points required for analysis (10-365).';
                }
                field("Forecast Periods Days"; Rec."Forecast Periods Days")
                {
                    ApplicationArea = All;
                    ToolTip = 'The number of days to forecast into the future (7-365).';
                }
            }
            group(CalculationParameters)
            {
                Caption = 'Calculation Parameters';

                field("Service Level Target"; Rec."Service Level Target")
                {
                    ApplicationArea = All;
                    ToolTip = 'The target service level percentage for safety stock calculations (80-99.9%).';
                }
                field("Safety Stock Multiplier"; Rec."Safety Stock Multiplier")
                {
                    ApplicationArea = All;
                    ToolTip = 'The Z-score multiplier for safety stock (auto-calculated from service level).';
                    Editable = false;
                }
                field("Lead Time Days Default"; Rec."Lead Time Days Default")
                {
                    ApplicationArea = All;
                    ToolTip = 'The default lead time in days if not specified on the item.';
                }
                field("Holding Cost Rate"; Rec."Holding Cost Rate")
                {
                    ApplicationArea = All;
                    ToolTip = 'The annual holding cost as a percentage of unit cost (used for EOQ calculation).';
                }
                field("Default Order Cost"; Rec."Default Order Cost")
                {
                    ApplicationArea = All;
                    ToolTip = 'The default cost per order/setup (used for EOQ calculation).';
                }
                field("Peak Season Multiplier"; Rec."Peak Season Multiplier")
                {
                    ApplicationArea = All;
                    ToolTip = 'Multiplier applied to Maximum Inventory for items with Seasonal demand pattern (1.0-2.0).';
                }
            }
            group(ApprovalSettings)
            {
                Caption = 'Approval Settings';

                field("Auto Apply Threshold"; Rec."Auto Apply Threshold")
                {
                    ApplicationArea = All;
                    ToolTip = 'Suggestions with confidence scores at or above this threshold will be auto-approved. Below this threshold, suggestions require manual approval.';
                }
            }
            group(BatchProcessing)
            {
                Caption = 'Batch Processing';

                field("Batch Size"; Rec."Batch Size")
                {
                    ApplicationArea = All;
                    ToolTip = 'The number of items to process per commit (for batch operations).';
                }
            }
            group(LastRun)
            {
                Caption = 'Last Batch Run';

                field("Last Full Run DateTime"; Rec."Last Full Run DateTime")
                {
                    ApplicationArea = All;
                    ToolTip = 'The date and time of the last batch processing run.';
                }
                field("Last Full Run Items"; Rec."Last Full Run Items")
                {
                    ApplicationArea = All;
                    ToolTip = 'The number of items processed in the last batch run.';
                }
            }
        }
    }

    actions
    {
        area(Processing)
        {
            action(ExpireOldSuggestions)
            {
                ApplicationArea = All;
                Caption = 'Expire Old Suggestions';
                Image = Delete;
                ToolTip = 'Mark suggestions older than 30 days as expired.';

                trigger OnAction()
                var
                    SuggestionMgr: Codeunit "Planning Suggestion Manager";
                begin
                    SuggestionMgr.ExpireOldSuggestions(30);
                end;
            }
        }
        area(Navigation)
        {
            action(ViewSuggestions)
            {
                ApplicationArea = All;
                Caption = 'Planning Suggestions';
                Image = Suggest;
                ToolTip = 'View all planning parameter suggestions.';
                RunObject = page "Planning Parameter Suggestions";
            }
        }
        area(Promoted)
        {
            group(Category_Process)
            {
                Caption = 'Process';

                actionref(ExpireOldSuggestions_Promoted; ExpireOldSuggestions) { }
            }
            group(Category_Navigate)
            {
                Caption = 'Navigate';

                actionref(ViewSuggestions_Promoted; ViewSuggestions) { }
            }
        }
    }

    trigger OnOpenPage()
    begin
        Rec.Reset();
        if not Rec.Get() then begin
            Rec.Init();
            Rec.Insert(true);
        end;
    end;
}
