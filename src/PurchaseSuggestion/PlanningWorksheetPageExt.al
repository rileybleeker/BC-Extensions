pageextension 50151 "Planning Worksheet Vendor Ext" extends "Planning Worksheet"
{
    layout
    {
        modify("Vendor No.")
        {
            trigger OnLookup(var Text: Text): Boolean
            var
                SelectedVendor: Code[20];
            begin
                if Rec.Type <> Rec.Type::Item then
                    exit(false);

                SelectedVendor := ShowVendorSelectionLookup();
                if SelectedVendor <> '' then begin
                    Text := SelectedVendor;
                    exit(true);
                end;
                exit(false);
            end;
        }
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
                    Caption = 'Compare Vendors';
                    ToolTip = 'Compare available vendors for this item.';
                    Image = Vendor;
                    Promoted = true;
                    PromotedCategory = Process;

                    trigger OnAction()
                    begin
                        ShowVendorComparison();
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
        if Rec."Recommended Vendor No." <> '' then begin
            if Rec."Vendor No." = Rec."Recommended Vendor No." then
                RecommendedVendorStyle := 'Favorable'
            else
                RecommendedVendorStyle := 'Attention';
        end else
            RecommendedVendorStyle := 'Subordinate';

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
                    VendorSelector.GetRankedVendors(
                        ReqLine."No.",
                        ReqLine."Location Code",
                        ReqLine.Quantity,
                        ReqLine."Due Date",
                        TempVendorRanking
                    );

                    if TempVendorRanking.FindFirst() then begin
                        ReqLine."Recommended Vendor No." := TempVendorRanking."Vendor No.";
                        ReqLine."Recommended Vendor Name" := TempVendorRanking."Vendor Name";
                        ReqLine."Recommended Vendor Score" := TempVendorRanking."Overall Score";
                        ReqLine."Recommended Unit Cost" := TempVendorRanking."Unit Cost";
                        ReqLine."Recommended Lead Time" := TempVendorRanking."Lead Time Days";
                        ReqLine."Alt Vendor Available" := TempVendorRanking.Count() > 1;

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

    local procedure ShowVendorSelectionLookup(): Code[20]
    var
        TempVendorRanking: Record "Vendor Ranking" temporary;
        VendorSelector: Codeunit "Vendor Selector";
        VendorComparisonPage: Page "Vendor Comparison";
        RequiredDate: Date;
        RequiredQty: Decimal;
    begin
        if Rec."Due Date" <> 0D then
            RequiredDate := Rec."Due Date"
        else
            RequiredDate := CalcDate('<2W>', Today);

        if Rec.Quantity > 0 then
            RequiredQty := Rec.Quantity
        else
            RequiredQty := 1;

        VendorSelector.GetRankedVendors(
            Rec."No.",
            Rec."Location Code",
            RequiredQty,
            RequiredDate,
            TempVendorRanking
        );

        if TempVendorRanking.IsEmpty then
            exit('');

        VendorComparisonPage.SetData(TempVendorRanking, Rec."No.", RequiredQty, RequiredDate);
        if VendorComparisonPage.RunModal() = Action::LookupOK then
            exit(VendorComparisonPage.GetSelectedVendor());

        exit('');
    end;
}
