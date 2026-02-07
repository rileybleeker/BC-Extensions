pageextension 50150 "Req Worksheet Vendor Ext" extends "Req. Worksheet"
{
    layout
    {
        addafter("Vendor No.")
        {
            field("Recommended Vendor No."; Rec."Recommended Vendor No.")
            {
                ApplicationArea = All;
                ToolTip = 'The recommended vendor based on performance, price, and lead time.';
                StyleExpr = RecommendedVendorStyle;
                Visible = ShowVendorRecommendations;

                trigger OnDrillDown()
                var
                    Vendor: Record Vendor;
                begin
                    if Vendor.Get(Rec."Recommended Vendor No.") then
                        Page.Run(Page::"Vendor Card", Vendor);
                end;
            }
            field("Recommended Vendor Score"; Rec."Recommended Vendor Score")
            {
                ApplicationArea = All;
                ToolTip = 'The overall performance score of the recommended vendor.';
                StyleExpr = ScoreStyle;
                Visible = ShowVendorRecommendations;
            }
            field("Alt Vendor Available"; Rec."Alt Vendor Available")
            {
                ApplicationArea = All;
                ToolTip = 'Indicates if alternative vendors are available.';
                Visible = ShowVendorRecommendations;
            }
            field("Substitute Available"; Rec."Substitute Available")
            {
                ApplicationArea = All;
                ToolTip = 'Indicates if a substitute item is available with faster delivery.';
                Visible = ShowVendorRecommendations;
            }
            field("Recommended Lead Time"; Rec."Recommended Lead Time")
            {
                ApplicationArea = All;
                ToolTip = 'Lead time in days for the recommended vendor.';
                Visible = ShowVendorRecommendations;
            }
        }
    }

    actions
    {
        addlast(Processing)
        {
            group(VendorRecommendations)
            {
                Caption = 'Vendor Recommendations';
                Image = Suggest;

                action(EnrichSelectedLines)
                {
                    ApplicationArea = All;
                    Caption = 'Enrich Selected Lines';
                    ToolTip = 'Add vendor recommendations to selected lines.';
                    Image = Suggest;
                    Promoted = true;
                    PromotedCategory = Process;

                    trigger OnAction()
                    var
                        ReqLine: Record "Requisition Line";
                        EnrichCount: Integer;
                    begin
                        CurrPage.SetSelectionFilter(ReqLine);
                        EnrichCount := EnrichRequisitionLines(ReqLine);
                        Message('%1 lines enriched with vendor recommendations.', EnrichCount);
                        CurrPage.Update(false);
                    end;
                }
                action(EnrichAllLines)
                {
                    ApplicationArea = All;
                    Caption = 'Enrich All Lines';
                    ToolTip = 'Add vendor recommendations to all lines.';
                    Image = AllLines;

                    trigger OnAction()
                    var
                        ReqLine: Record "Requisition Line";
                        EnrichCount: Integer;
                    begin
                        ReqLine.SetRange("Worksheet Template Name", Rec."Worksheet Template Name");
                        ReqLine.SetRange("Journal Batch Name", Rec."Journal Batch Name");
                        EnrichCount := EnrichRequisitionLines(ReqLine);
                        Message('%1 lines enriched with vendor recommendations.', EnrichCount);
                        CurrPage.Update(false);
                    end;
                }
                action(ApplyRecommendedVendor)
                {
                    ApplicationArea = All;
                    Caption = 'Apply Recommended Vendor';
                    ToolTip = 'Set the vendor to the recommended vendor for selected lines.';
                    Image = Apply;
                    Promoted = true;
                    PromotedCategory = Process;

                    trigger OnAction()
                    var
                        ReqLine: Record "Requisition Line";
                        ApplyCount: Integer;
                    begin
                        CurrPage.SetSelectionFilter(ReqLine);
                        ApplyCount := ApplyRecommendedVendors(ReqLine);
                        Message('Recommended vendor applied to %1 lines.', ApplyCount);
                        CurrPage.Update(false);
                    end;
                }
                action(ViewVendorComparison)
                {
                    ApplicationArea = All;
                    Caption = 'View Vendor Comparison';
                    ToolTip = 'Compare available vendors for this item.';
                    Image = Vendor;

                    trigger OnAction()
                    begin
                        ShowVendorComparison();
                    end;
                }
                action(CreatePurchaseSuggestion)
                {
                    ApplicationArea = All;
                    Caption = 'Create Purchase Suggestion';
                    ToolTip = 'Create a purchase suggestion with vendor comparison.';
                    Image = Suggest;

                    trigger OnAction()
                    var
                        PurchSuggMgr: Codeunit "Purchase Suggestion Manager";
                        PurchSuggestion: Record "Purchase Suggestion";
                    begin
                        PurchSuggestion := PurchSuggMgr.GenerateFromRequisitionLine(Rec);
                        Page.Run(Page::"Purchase Suggestion Card", PurchSuggestion);
                    end;
                }
                action(ToggleRecommendations)
                {
                    ApplicationArea = All;
                    Caption = 'Show/Hide Recommendations';
                    ToolTip = 'Toggle visibility of vendor recommendation columns.';
                    Image = ShowSelected;

                    trigger OnAction()
                    begin
                        ShowVendorRecommendations := not ShowVendorRecommendations;
                    end;
                }
            }
        }
        addlast(Navigation)
        {
            action(PurchaseSuggestions)
            {
                ApplicationArea = All;
                Caption = 'Purchase Suggestions';
                ToolTip = 'View all purchase suggestions.';
                Image = OrderList;
                RunObject = page "Purchase Suggestion List";
            }
            action(VendorPerformance)
            {
                ApplicationArea = All;
                Caption = 'Vendor Performance';
                ToolTip = 'View vendor performance metrics.';
                Image = Statistics;
                RunObject = page "Vendor Performance List";
            }
        }
    }

    var
        ShowVendorRecommendations: Boolean;
        RecommendedVendorStyle: Text;
        ScoreStyle: Text;

    trigger OnOpenPage()
    begin
        ShowVendorRecommendations := true;
    end;

    trigger OnAfterGetRecord()
    begin
        SetStyles();
    end;

    local procedure SetStyles()
    begin
        // Recommended vendor style
        if Rec."Recommended Vendor No." <> '' then begin
            if Rec."Vendor No." = Rec."Recommended Vendor No." then
                RecommendedVendorStyle := 'Favorable'
            else
                RecommendedVendorStyle := 'Attention';
        end else
            RecommendedVendorStyle := 'Subordinate';

        // Score style
        if Rec."Recommended Vendor Score" >= 80 then
            ScoreStyle := 'Favorable'
        else if Rec."Recommended Vendor Score" >= 60 then
            ScoreStyle := 'Ambiguous'
        else if Rec."Recommended Vendor Score" > 0 then
            ScoreStyle := 'Attention'
        else
            ScoreStyle := 'Subordinate';
    end;

    local procedure EnrichRequisitionLines(var ReqLine: Record "Requisition Line"): Integer
    var
        VendorSelector: Codeunit "Vendor Selector";
        TempVendorRanking: Record "Vendor Ranking" temporary;
        ItemSubstitution: Record "Item Substitution";
        EnrichCount: Integer;
    begin
        if ReqLine.FindSet() then
            repeat
                if ReqLine.Type = ReqLine.Type::Item then begin
                    // Get vendor recommendations
                    VendorSelector.GetRankedVendors(
                        ReqLine."No.",
                        ReqLine."Location Code",
                        ReqLine.Quantity,
                        ReqLine."Due Date",
                        TempVendorRanking
                    );

                    if TempVendorRanking.FindFirst() then begin
                        ReqLine."Recommended Vendor No." := TempVendorRanking."Vendor No.";
                        ReqLine."Recommended Vendor Name" := TempVendorRanking."Vendor Name";  // Use cached name
                        ReqLine."Recommended Vendor Score" := TempVendorRanking."Overall Score";
                        ReqLine."Recommended Unit Cost" := TempVendorRanking."Unit Cost";
                        ReqLine."Recommended Lead Time" := TempVendorRanking."Lead Time Days";
                        ReqLine."Alt Vendor Available" := TempVendorRanking.Count() > 1;

                        // Check for substitutes
                        ItemSubstitution.SetRange(Type, ItemSubstitution.Type::Item);
                        ItemSubstitution.SetRange("No.", ReqLine."No.");
                        if ItemSubstitution.FindFirst() then begin
                            ReqLine."Substitute Available" := true;
                            ReqLine."Substitute Item No." := ItemSubstitution."Substitute No.";
                        end;

                        ReqLine."Recommendation Enriched" := true;
                        ReqLine.Modify();
                        EnrichCount += 1;
                    end;
                end;
            until ReqLine.Next() = 0;

        exit(EnrichCount);
    end;

    local procedure ApplyRecommendedVendors(var ReqLine: Record "Requisition Line"): Integer
    var
        ApplyCount: Integer;
    begin
        if ReqLine.FindSet() then
            repeat
                if (ReqLine."Recommended Vendor No." <> '') and (ReqLine."Vendor No." <> ReqLine."Recommended Vendor No.") then begin
                    ReqLine.Validate("Vendor No.", ReqLine."Recommended Vendor No.");
                    ReqLine.Modify(true);
                    ApplyCount += 1;
                end;
            until ReqLine.Next() = 0;

        exit(ApplyCount);
    end;

    local procedure ShowVendorComparison()
    var
        TempVendorRanking: Record "Vendor Ranking" temporary;
        VendorSelector: Codeunit "Vendor Selector";
        VendorComparisonPage: Page "Vendor Comparison";
    begin
        if Rec.Type <> Rec.Type::Item then
            exit;

        VendorSelector.GetRankedVendors(
            Rec."No.",
            Rec."Location Code",
            Rec.Quantity,
            Rec."Due Date",
            TempVendorRanking
        );

        VendorComparisonPage.SetData(TempVendorRanking, Rec."No.", Rec.Quantity, Rec."Due Date");
        VendorComparisonPage.RunModal();
    end;
}
