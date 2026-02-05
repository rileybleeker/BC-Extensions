page 50112 "Planning Suggestion Card"
{
    PageType = Card;
    SourceTable = "Planning Parameter Suggestion";
    Caption = 'Planning Suggestion Card';
    ApplicationArea = All;

    layout
    {
        area(Content)
        {
            group(General)
            {
                Caption = 'General';

                field("Entry No."; Rec."Entry No.")
                {
                    ApplicationArea = All;
                    ToolTip = 'The unique entry number for this suggestion.';
                    Editable = false;
                }
                field("Item No."; Rec."Item No.")
                {
                    ApplicationArea = All;
                    ToolTip = 'The item number for this suggestion.';
                    Editable = false;
                }
                field("Location Code"; Rec."Location Code")
                {
                    ApplicationArea = All;
                    ToolTip = 'The location code filter used for analysis.';
                    Editable = false;
                }
                field(Status; Rec.Status)
                {
                    ApplicationArea = All;
                    ToolTip = 'The current status of this suggestion.';
                    StyleExpr = StatusStyle;
                }
                field("Suggestion Date"; Rec."Suggestion Date")
                {
                    ApplicationArea = All;
                    ToolTip = 'The date this suggestion was generated.';
                    Editable = false;
                }
                field("Demand Pattern"; Rec."Demand Pattern")
                {
                    ApplicationArea = All;
                    ToolTip = 'The detected demand pattern for this item.';
                    Editable = false;
                }
            }
            group(ConfidenceMetrics)
            {
                Caption = 'Confidence & Demand Analysis';

                field("Confidence Score"; Rec."Confidence Score")
                {
                    ApplicationArea = All;
                    ToolTip = 'The confidence score for this suggestion (0-100).';
                    StyleExpr = ConfidenceStyle;
                    Editable = false;
                }
                field("Demand Variability"; Rec."Demand Variability")
                {
                    ApplicationArea = All;
                    ToolTip = 'Demand Variability (Standard Deviation) - Measures how much daily demand fluctuates from the average. Calculated using the calendar-day method which includes zero-demand days. Used in the Safety Stock formula as a buffer for demand uncertainty. Lower values indicate more predictable demand patterns.';
                    Editable = false;
                }
                field("Demand CV Pct"; Rec."Demand CV Pct")
                {
                    ApplicationArea = All;
                    ToolTip = 'Demand Coefficient of Variation (CV) % - Calculated as (Standard Deviation / Average Daily Demand) × 100. Measures relative variability as a percentage, allowing comparison across items with different demand levels. Capped at 100%. Lower percentages indicate more consistent demand. Used to calculate the Demand Stability component of the Confidence Score.';
                    Editable = false;
                }
                field("Data Points Analyzed"; Rec."Data Points Analyzed")
                {
                    ApplicationArea = All;
                    ToolTip = 'Number of unique days with actual demand transactions (Item Ledger Entries) during the analysis period. This counts days with sales, transfers, or production consumption - not total calendar days. More data points generally lead to higher confidence scores and more reliable suggestions.';
                    Editable = false;
                }
                field("Analysis Period Start"; Rec."Analysis Period Start")
                {
                    ApplicationArea = All;
                    ToolTip = 'Start of the analysis period.';
                    Editable = false;
                }
                field("Analysis Period End"; Rec."Analysis Period End")
                {
                    ApplicationArea = All;
                    ToolTip = 'End of the analysis period.';
                    Editable = false;
                }
            }
            group(ReorderingPolicy)
            {
                Caption = 'Reordering Policy';

                field("Current Reordering Policy"; Rec."Current Reordering Policy")
                {
                    ApplicationArea = All;
                    ToolTip = 'Current reordering policy on the item.';
                    Editable = false;
                    Style = Subordinate;
                }
                field("Suggested Reordering Policy"; Rec."Suggested Reordering Policy")
                {
                    ApplicationArea = All;
                    ToolTip = 'Suggested reordering policy.';
                    Style = Strong;
                }
            }
            group(SafetyStock)
            {
                Caption = 'Safety Stock';

                field("Current Safety Stock"; Rec."Current Safety Stock")
                {
                    ApplicationArea = All;
                    ToolTip = 'Current safety stock quantity on the item.';
                    Editable = false;
                    Style = Subordinate;
                }
                field("Suggested Safety Stock"; Rec."Suggested Safety Stock")
                {
                    ApplicationArea = All;
                    ToolTip = 'Suggested safety stock quantity.';
                    Style = Strong;
                }
            }
            group(ReorderPoint)
            {
                Caption = 'Reorder Point';

                field("Current Reorder Point"; Rec."Current Reorder Point")
                {
                    ApplicationArea = All;
                    ToolTip = 'Current reorder point on the item.';
                    Editable = false;
                    Style = Subordinate;
                }
                field("Suggested Reorder Point"; Rec."Suggested Reorder Point")
                {
                    ApplicationArea = All;
                    ToolTip = 'Suggested reorder point.';
                    Style = Strong;
                }
            }
            group(ReorderQuantity)
            {
                Caption = 'Reorder Quantity';

                field("Current Reorder Quantity"; Rec."Current Reorder Quantity")
                {
                    ApplicationArea = All;
                    ToolTip = 'Current reorder quantity on the item.';
                    Editable = false;
                    Style = Subordinate;
                }
                field("Suggested Reorder Quantity"; Rec."Suggested Reorder Quantity")
                {
                    ApplicationArea = All;
                    ToolTip = 'Suggested reorder quantity (EOQ).';
                    Style = Strong;
                }
            }
            group(MaximumInventory)
            {
                Caption = 'Maximum Inventory';

                field("Current Maximum Inventory"; Rec."Current Maximum Inventory")
                {
                    ApplicationArea = All;
                    ToolTip = 'Current maximum inventory on the item.';
                    Editable = false;
                    Style = Subordinate;
                }
                field("Suggested Maximum Inventory"; Rec."Suggested Maximum Inventory")
                {
                    ApplicationArea = All;
                    ToolTip = 'Suggested maximum inventory.';
                    Style = Strong;
                }
            }
            group(LotAccumPeriod)
            {
                Caption = 'Lot Accumulation Period';

                field("Current Lot Accum Period"; Rec."Current Lot Accum Period")
                {
                    ApplicationArea = All;
                    ToolTip = 'Current lot accumulation period on the item.';
                    Editable = false;
                    Style = Subordinate;
                }
                field("Suggested Lot Accum Period"; Rec."Suggested Lot Accum Period")
                {
                    ApplicationArea = All;
                    ToolTip = 'Suggested lot accumulation period.';
                    Style = Strong;
                }
            }
            group(ReviewInfo)
            {
                Caption = 'Review Information';
                Visible = (Rec.Status = Rec.Status::Approved) or (Rec.Status = Rec.Status::Rejected) or (Rec.Status = Rec.Status::Applied);

                field("Reviewed By"; Rec."Reviewed By")
                {
                    ApplicationArea = All;
                    ToolTip = 'The user who reviewed this suggestion.';
                    Editable = false;
                }
                field("Reviewed DateTime"; Rec."Reviewed DateTime")
                {
                    ApplicationArea = All;
                    ToolTip = 'When this suggestion was reviewed.';
                    Editable = false;
                }
            }
            group(ErrorInfo)
            {
                Caption = 'Error Information';
                Visible = Rec.Status = Rec.Status::Failed;

                field("Error Message"; Rec."Error Message")
                {
                    ApplicationArea = All;
                    ToolTip = 'Error message if processing failed.';
                    Editable = false;
                    Style = Unfavorable;
                }
            }
            group(CalculationNotesGrp)
            {
                Caption = 'Calculation Notes';

                field("Calculation Notes"; Rec."Calculation Notes")
                {
                    ApplicationArea = All;
                    ToolTip = 'Detailed notes about how the suggestions were calculated.';
                    MultiLine = true;
                    Editable = false;
                }
            }
        }
    }

    actions
    {
        area(Processing)
        {
            action(Approve)
            {
                ApplicationArea = All;
                Caption = 'Approve';
                Image = Approve;
                ToolTip = 'Approve this suggestion.';
                Enabled = Rec.Status = Rec.Status::Pending;

                trigger OnAction()
                var
                    SuggestionMgr: Codeunit "Planning Suggestion Manager";
                begin
                    SuggestionMgr.ApproveSuggestion(Rec."Entry No.");
                    CurrPage.Update(false);
                end;
            }
            action(Reject)
            {
                ApplicationArea = All;
                Caption = 'Reject';
                Image = Reject;
                ToolTip = 'Reject this suggestion.';
                Enabled = Rec.Status = Rec.Status::Pending;

                trigger OnAction()
                var
                    SuggestionMgr: Codeunit "Planning Suggestion Manager";
                    RejectReasonDialog: Page "Reject Reason Dialog";
                    RejectReason: Text[250];
                begin
                    RejectReasonDialog.LookupMode(true);
                    if RejectReasonDialog.RunModal() <> Action::LookupOK then
                        exit;

                    RejectReason := RejectReasonDialog.GetRejectReason();
                    if RejectReason = '' then begin
                        Message('A rejection reason is required.');
                        exit;
                    end;

                    SuggestionMgr.RejectSuggestion(Rec."Entry No.", RejectReason);
                    CurrPage.Update(false);
                end;
            }
            action(ApplyToItem)
            {
                ApplicationArea = All;
                Caption = 'Apply to Item';
                Image = Apply;
                ToolTip = 'Apply this suggestion to the item.';
                Enabled = Rec.Status = Rec.Status::Approved;

                trigger OnAction()
                var
                    SuggestionMgr: Codeunit "Planning Suggestion Manager";
                begin
                    if not Confirm('Apply all suggested parameters to item %1?', false, Rec."Item No.") then
                        exit;

                    if SuggestionMgr.ApplySuggestionToItem(Rec."Entry No.", true, true, true, true, true, true) then
                        Message('Parameters applied successfully to item %1.', Rec."Item No.");

                    CurrPage.Update(false);
                end;
            }
        }
        area(Navigation)
        {
            action(ViewItem)
            {
                ApplicationArea = All;
                Caption = 'View Item';
                Image = Item;
                ToolTip = 'Open the item card.';
                RunObject = page "Item Card";
                RunPageLink = "No." = field("Item No.");
            }
        }
        area(Promoted)
        {
            group(Category_Process)
            {
                Caption = 'Process';

                actionref(Approve_Promoted; Approve) { }
                actionref(Reject_Promoted; Reject) { }
                actionref(ApplyToItem_Promoted; ApplyToItem) { }
            }
        }
    }

    var
        StatusStyle: Text;
        ConfidenceStyle: Text;

    trigger OnAfterGetRecord()
    begin
        SetStyles();
    end;

    local procedure SetStyles()
    begin
        case Rec.Status of
            Rec.Status::Pending:
                StatusStyle := 'Attention';
            Rec.Status::Approved:
                StatusStyle := 'Favorable';
            Rec.Status::Rejected, Rec.Status::Failed:
                StatusStyle := 'Unfavorable';
            Rec.Status::Applied:
                StatusStyle := 'StrongAccent';
            Rec.Status::Expired:
                StatusStyle := 'Subordinate';
        end;

        if Rec."Confidence Score" >= 75 then
            ConfidenceStyle := 'Favorable'
        else if Rec."Confidence Score" >= 50 then
            ConfidenceStyle := 'Attention'
        else
            ConfidenceStyle := 'Unfavorable';
    end;
}
