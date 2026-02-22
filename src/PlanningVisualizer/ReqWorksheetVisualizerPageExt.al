pageextension 50161 "Req Wksh Visualizer Ext" extends "Req. Worksheet"
{
    actions
    {
        addlast(Processing)
        {
            group(PlanningVisualizer)
            {
                Caption = 'Visualizer';
                Image = AnalysisView;

                action(VisualizeItem)
                {
                    ApplicationArea = All;
                    Caption = 'Visualize';
                    ToolTip = 'Show projected inventory timeline with supply/demand events for the selected item.';
                    Image = AnalysisView;
                    Promoted = true;
                    PromotedCategory = Process;
                    PromotedIsBig = true;

                    trigger OnAction()
                    var
                        VisualizerPage: Page "Planning Worksheet Visualizer";
                    begin
                        if Rec.Type <> Rec.Type::Item then begin
                            Message('Visualization is only available for Item lines.');
                            exit;
                        end;

                        if Rec."No." = '' then begin
                            Message('Please select a line with an Item No.');
                            exit;
                        end;

                        VisualizerPage.SetData(
                            Rec."No.",
                            Rec."Location Code",
                            Rec."Variant Code",
                            Rec."Worksheet Template Name",
                            Rec."Journal Batch Name"
                        );
                        VisualizerPage.RunModal();
                    end;
                }
            }
        }
    }
}
