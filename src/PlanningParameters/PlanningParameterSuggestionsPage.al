page 50111 "Planning Parameter Suggestions"
{
    PageType = List;
    SourceTable = "Planning Parameter Suggestion";
    Caption = 'Planning Parameter Suggestions';
    UsageCategory = Lists;
    ApplicationArea = All;
    Editable = false;
    CardPageId = "Planning Suggestion Card";

    layout
    {
        area(Content)
        {
            repeater(Group)
            {
                field("Entry No."; Rec."Entry No.")
                {
                    ApplicationArea = All;
                    ToolTip = 'The unique entry number for this suggestion.';
                }
                field("Item No."; Rec."Item No.")
                {
                    ApplicationArea = All;
                    ToolTip = 'The item number for this suggestion.';
                }
                field("Location Code"; Rec."Location Code")
                {
                    ApplicationArea = All;
                    ToolTip = 'The location code filter used for analysis.';
                }
                field("Target Level"; Rec."Target Level")
                {
                    ApplicationArea = All;
                    ToolTip = 'Whether this suggestion applies to the Item or a Stockkeeping Unit (SKU).';
                    StyleExpr = TargetLevelStyle;
                }
                field("SKU Exists"; Rec."SKU Exists")
                {
                    ApplicationArea = All;
                    ToolTip = 'Indicates whether the Stockkeeping Unit already exists.';
                    Visible = Rec."Target Level" = Rec."Target Level"::SKU;
                }
                field(Status; Rec.Status)
                {
                    ApplicationArea = All;
                    ToolTip = 'The current status of this suggestion.';
                    StyleExpr = StatusStyle;
                }
                field("Confidence Score"; Rec."Confidence Score")
                {
                    ApplicationArea = All;
                    ToolTip = 'The confidence score for this suggestion (0-100).';
                    StyleExpr = ConfidenceStyle;
                }
                field("Demand Pattern"; Rec."Demand Pattern")
                {
                    ApplicationArea = All;
                    ToolTip = 'The detected demand pattern for this item.';
                }
                field("Suggestion Date"; Rec."Suggestion Date")
                {
                    ApplicationArea = All;
                    ToolTip = 'The date this suggestion was generated.';
                }
                field("Suggested Reordering Policy"; Rec."Suggested Reordering Policy")
                {
                    ApplicationArea = All;
                    ToolTip = 'The suggested reordering policy.';
                }
                field("Suggested Safety Stock"; Rec."Suggested Safety Stock")
                {
                    ApplicationArea = All;
                    ToolTip = 'The suggested safety stock quantity.';
                }
                field("Suggested Reorder Point"; Rec."Suggested Reorder Point")
                {
                    ApplicationArea = All;
                    ToolTip = 'The suggested reorder point.';
                }
                field("Suggested Reorder Quantity"; Rec."Suggested Reorder Quantity")
                {
                    ApplicationArea = All;
                    ToolTip = 'The suggested reorder quantity (EOQ).';
                }
                field("Suggested Maximum Inventory"; Rec."Suggested Maximum Inventory")
                {
                    ApplicationArea = All;
                    ToolTip = 'The suggested maximum inventory.';
                }
                field("Suggested Lot Accum Period"; Rec."Suggested Lot Accum Period")
                {
                    ApplicationArea = All;
                    ToolTip = 'The suggested lot accumulation period.';
                }
                field("Reviewed By"; Rec."Reviewed By")
                {
                    ApplicationArea = All;
                    ToolTip = 'The user who reviewed this suggestion.';
                }
            }
        }
        area(FactBoxes)
        {
            part(ItemFactBox; "Item Invoicing FactBox")
            {
                ApplicationArea = All;
                SubPageLink = "No." = field("Item No.");
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
                ToolTip = 'Approve this suggestion for application.';
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
                    if not Confirm('Are you sure you want to reject this suggestion?') then
                        exit;

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
            action(ApplySuggestion)
            {
                ApplicationArea = All;
                Caption = 'Apply Suggestion';
                Image = Apply;
                ToolTip = 'Apply this suggestion to the Item or Stockkeeping Unit.';
                Enabled = Rec.Status = Rec.Status::Approved;

                trigger OnAction()
                var
                    SuggestionMgr: Codeunit "Planning Suggestion Manager";
                    ConfirmMsg: Text;
                    SuccessMsg: Text;
                begin
                    if Rec."Target Level" = Rec."Target Level"::SKU then begin
                        ConfirmMsg := StrSubstNo('Apply all suggested parameters to SKU for Item %1 at Location %2?', Rec."Item No.", Rec."Location Code");
                        SuccessMsg := StrSubstNo('Parameters applied successfully to SKU for Item %1 at Location %2.', Rec."Item No.", Rec."Location Code");
                    end else begin
                        ConfirmMsg := StrSubstNo('Apply all suggested parameters to Item %1?', Rec."Item No.");
                        SuccessMsg := StrSubstNo('Parameters applied successfully to Item %1.', Rec."Item No.");
                    end;

                    if not Confirm(ConfirmMsg) then
                        exit;

                    if SuggestionMgr.ApplySuggestion(Rec."Entry No.", true, true, true, true, true, true) then
                        Message(SuccessMsg);

                    CurrPage.Update(false);
                end;
            }
            action(GenerateNew)
            {
                ApplicationArea = All;
                Caption = 'Generate New Suggestion';
                Image = Suggest;
                ToolTip = 'Generate a new suggestion for the selected item.';

                trigger OnAction()
                var
                    SuggestionMgr: Codeunit "Planning Suggestion Manager";
                    NewEntryNo: Integer;
                begin
                    NewEntryNo := SuggestionMgr.GenerateSuggestionForItem(Rec."Item No.", Rec."Location Code");
                    Message('New suggestion %1 generated.', NewEntryNo);
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
            action(ViewSKU)
            {
                ApplicationArea = All;
                Caption = 'View Stockkeeping Unit';
                Image = SKU;
                ToolTip = 'Open the stockkeeping unit card.';
                Enabled = Rec."Target Level" = Rec."Target Level"::SKU;

                trigger OnAction()
                var
                    SKU: Record "Stockkeeping Unit";
                begin
                    if SKU.Get(Rec."Location Code", Rec."Item No.", Rec."Variant Code") then
                        Page.Run(Page::"Stockkeeping Unit Card", SKU)
                    else
                        Message('Stockkeeping Unit does not exist yet. It will be created when you apply the suggestion.');
                end;
            }
            action(ViewCalculationNotes)
            {
                ApplicationArea = All;
                Caption = 'Calculation Notes';
                Image = Info;
                ToolTip = 'View the calculation notes for this suggestion.';

                trigger OnAction()
                begin
                    Message(Rec."Calculation Notes");
                end;
            }
            action(GenerateForAllLocations)
            {
                ApplicationArea = All;
                Caption = 'Generate for All Locations';
                Image = AllLines;
                ToolTip = 'Generate SKU-level suggestions for all locations with demand history.';

                trigger OnAction()
                var
                    SuggestionMgr: Codeunit "Planning Suggestion Manager";
                begin
                    SuggestionMgr.GenerateSuggestionsForAllLocations(Rec."Item No.");
                    CurrPage.Update(false);
                end;
            }
        }
        area(Promoted)
        {
            group(Category_Process)
            {
                Caption = 'Process';

                actionref(Approve_Promoted; Approve) { }
                actionref(Reject_Promoted; Reject) { }
                actionref(ApplySuggestion_Promoted; ApplySuggestion) { }
                actionref(GenerateNew_Promoted; GenerateNew) { }
            }
        }
    }

    var
        StatusStyle: Text;
        ConfidenceStyle: Text;
        TargetLevelStyle: Text;

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

        // SKU suggestions highlighted differently
        if Rec."Target Level" = Rec."Target Level"::SKU then
            TargetLevelStyle := 'Strong'
        else
            TargetLevelStyle := 'Standard';
    end;
}
