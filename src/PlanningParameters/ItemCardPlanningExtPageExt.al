pageextension 50110 "Item Card Planning Extension" extends "Item Card"
{
    layout
    {
        addlast(Planning)
        {
            group(PlanningSuggestions)
            {
                Caption = 'Planning Suggestions (ML)';

                field("Planning Suggestion Enabled"; Rec."Planning Suggestion Enabled")
                {
                    ApplicationArea = All;
                    ToolTip = 'Enable automatic planning parameter suggestions for this item.';
                }
                field("Demand Pattern"; Rec."Demand Pattern")
                {
                    ApplicationArea = All;
                    ToolTip = 'The detected demand pattern based on historical analysis.';
                    Editable = false;
                }
                field("Forecast Reliability Score"; Rec."Forecast Reliability Score")
                {
                    ApplicationArea = All;
                    ToolTip = 'The reliability score of forecasts for this item (0-100).';
                    Editable = false;
                }
                field("Last Suggestion Date"; Rec."Last Suggestion Date")
                {
                    ApplicationArea = All;
                    ToolTip = 'When the last planning suggestion was generated.';
                    Editable = false;
                }
                field("Last Applied Date"; Rec."Last Applied Date")
                {
                    ApplicationArea = All;
                    ToolTip = 'When the last planning suggestion was applied.';
                    Editable = false;
                }
                field("Suggestion Override Reason"; Rec."Suggestion Override Reason")
                {
                    ApplicationArea = All;
                    ToolTip = 'The reason for overriding the last suggestion.';
                }
            }
        }
    }

    actions
    {
        addlast(Processing)
        {
            action(GeneratePlanningSuggestion)
            {
                ApplicationArea = All;
                Caption = 'Generate Item-Level Suggestion';
                Image = Suggest;
                ToolTip = 'Generate a new planning parameter suggestion for this Item (not location-specific).';

                trigger OnAction()
                var
                    SuggestionMgr: Codeunit "Planning Suggestion Manager";
                    SuggestionEntryNo: Integer;
                begin
                    SuggestionEntryNo := SuggestionMgr.GenerateSuggestion(Rec."No.", '', '', false);
                    Message('Item-level suggestion %1 generated. Open Planning Parameter Suggestions to review.', SuggestionEntryNo);
                end;
            }
            action(GenerateSKUSuggestions)
            {
                ApplicationArea = All;
                Caption = 'Generate SKU Suggestions (All Locations)';
                Image = SuggestLines;
                ToolTip = 'Generate location-specific planning suggestions for all locations with demand history. Creates SKUs if needed.';

                trigger OnAction()
                var
                    SuggestionMgr: Codeunit "Planning Suggestion Manager";
                begin
                    if not Confirm('This will generate SKU-level suggestions for all locations with demand history.\Do you want to continue?') then
                        exit;

                    SuggestionMgr.GenerateSuggestionsForAllLocations(Rec."No.");
                end;
            }
            action(CreateSKUsForItem)
            {
                ApplicationArea = All;
                Caption = 'Create SKUs for All Locations';
                Image = CreateMovement;
                ToolTip = 'Create Stockkeeping Units for all locations that have demand history for this item.';

                trigger OnAction()
                var
                    SKUMgmt: Codeunit "Planning SKU Management";
                begin
                    if not Confirm('Create Stockkeeping Units for all locations with demand history?') then
                        exit;

                    SKUMgmt.BatchCreateSKUsForItem(Rec."No.");
                end;
            }
            action(ViewPlanningSuggestions)
            {
                ApplicationArea = All;
                Caption = 'View Planning Suggestions';
                Image = ViewDetails;
                ToolTip = 'View all planning suggestions for this item (both Item and SKU level).';
                RunObject = page "Planning Parameter Suggestions";
                RunPageLink = "Item No." = field("No.");
            }
            action(ViewStockkeepingUnits)
            {
                ApplicationArea = All;
                Caption = 'Stockkeeping Units';
                Image = SKU;
                ToolTip = 'View all Stockkeeping Units for this item.';
                RunObject = page "Stockkeeping Unit List";
                RunPageLink = "Item No." = field("No.");
            }
        }
        addlast(Category_Category5)
        {
            actionref(GeneratePlanningSuggestion_Promoted; GeneratePlanningSuggestion) { }
            actionref(GenerateSKUSuggestions_Promoted; GenerateSKUSuggestions) { }
            actionref(ViewPlanningSuggestions_Promoted; ViewPlanningSuggestions) { }
            actionref(ViewStockkeepingUnits_Promoted; ViewStockkeepingUnits) { }
        }
    }
}
