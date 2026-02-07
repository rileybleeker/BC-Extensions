pageextension 50151 "Planning Sugg Card Purch Ext" extends "Planning Suggestion Card"
{
    actions
    {
        addafter(ApplyToItem)
        {
            action(GeneratePurchaseSuggestion)
            {
                ApplicationArea = All;
                Caption = 'Generate Purchase Suggestion';
                ToolTip = 'Create a purchase suggestion with vendor recommendations for this item.';
                Image = Suggest;

                trigger OnAction()
                var
                    PurchSuggMgr: Codeunit "Purchase Suggestion Manager";
                    PurchSuggestion: Record "Purchase Suggestion";
                    Item: Record Item;
                    RequiredQty: Decimal;
                    RequiredDate: Date;
                begin
                    if not Item.Get(Rec."Item No.") then
                        Error('Item %1 not found.', Rec."Item No.");

                    // Calculate required quantity based on suggested reorder quantity
                    RequiredQty := Rec."Sugg. Reorder Quantity";
                    if RequiredQty = 0 then
                        RequiredQty := Rec."Sugg. Safety Stock" + Rec."Sugg. Reorder Point";

                    // Default required date to 2 weeks from now
                    RequiredDate := CalcDate('<2W>', Today);

                    PurchSuggestion := PurchSuggMgr.GenerateSuggestion(
                        Rec."Item No.",
                        Rec."Variant Code",
                        Rec."Location Code",
                        RequiredQty,
                        RequiredDate
                    );

                    PurchSuggestion."Planning Suggestion Entry No." := Rec."Entry No.";
                    PurchSuggestion.Modify();

                    Message('Purchase Suggestion %1 created with vendor recommendations.', PurchSuggestion."Entry No.");
                    Page.Run(Page::"Purchase Suggestion Card", PurchSuggestion);
                end;
            }
            action(ViewPurchaseSuggestions)
            {
                ApplicationArea = All;
                Caption = 'View Purchase Suggestions';
                ToolTip = 'View purchase suggestions for this item.';
                Image = OrderList;

                trigger OnAction()
                var
                    PurchSuggestion: Record "Purchase Suggestion";
                    PurchSuggestionList: Page "Purchase Suggestion List";
                begin
                    PurchSuggestion.SetRange("Item No.", Rec."Item No.");
                    if Rec."Location Code" <> '' then
                        PurchSuggestion.SetRange("Location Code", Rec."Location Code");
                    PurchSuggestionList.SetTableView(PurchSuggestion);
                    PurchSuggestionList.Run();
                end;
            }
            action(CompareVendors)
            {
                ApplicationArea = All;
                Caption = 'Compare Vendors';
                ToolTip = 'Compare available vendors for this item.';
                Image = Vendor;

                trigger OnAction()
                var
                    TempVendorRanking: Record "Vendor Ranking" temporary;
                    VendorSelector: Codeunit "Vendor Selector";
                    VendorComparisonPage: Page "Vendor Comparison";
                    RequiredQty: Decimal;
                    RequiredDate: Date;
                begin
                    RequiredQty := Rec."Sugg. Reorder Quantity";
                    if RequiredQty = 0 then
                        RequiredQty := 100;  // Default
                    RequiredDate := CalcDate('<2W>', Today);  // Calculate once

                    VendorSelector.GetRankedVendors(
                        Rec."Item No.",
                        Rec."Location Code",
                        RequiredQty,
                        RequiredDate,
                        TempVendorRanking
                    );

                    VendorComparisonPage.SetData(TempVendorRanking, Rec."Item No.", RequiredQty, RequiredDate);
                    VendorComparisonPage.RunModal();
                end;
            }
        }
        addafter(ViewItem)
        {
            action(ViewVendorPerformance)
            {
                ApplicationArea = All;
                Caption = 'Vendor Performance';
                ToolTip = 'View vendor performance metrics.';
                Image = Statistics;
                RunObject = page "Vendor Performance List";
            }
        }
    }
}
