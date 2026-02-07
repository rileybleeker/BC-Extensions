page 50152 "Vendor Comparison"
{
    PageType = List;
    ApplicationArea = All;
    SourceTable = "Vendor Ranking";
    SourceTableTemporary = true;
    Caption = 'Vendor Comparison - Select a Vendor';
    Editable = false;
    InsertAllowed = false;
    DeleteAllowed = false;
    ModifyAllowed = false;
    UsageCategory = None;
    DataCaptionExpression = GetDataCaption();

    layout
    {
        area(Content)
        {
            group(ItemInfo)
            {
                Caption = 'Item Information';

                field(ItemNoField; ItemNo)
                {
                    ApplicationArea = All;
                    Caption = 'Item No.';
                    ToolTip = 'The item being compared.';
                    Editable = false;
                }
                field(QuantityField; RequiredQty)
                {
                    ApplicationArea = All;
                    Caption = 'Required Qty';
                    ToolTip = 'The required quantity.';
                    Editable = false;
                }
                field(RequiredDateField; RequiredDate)
                {
                    ApplicationArea = All;
                    Caption = 'Required Date';
                    ToolTip = 'The required date.';
                    Editable = false;
                }
            }
            repeater(VendorList)
            {
                field("Rank No."; Rec."Rank No.")
                {
                    ApplicationArea = All;
                    Caption = 'Rank';
                    ToolTip = 'The vendor ranking based on overall score.';
                }
                field("Vendor No."; Rec."Vendor No.")
                {
                    ApplicationArea = All;
                    ToolTip = 'The vendor number.';

                    trigger OnDrillDown()
                    var
                        Vendor: Record Vendor;
                    begin
                        if Vendor.Get(Rec."Vendor No.") then
                            Page.Run(Page::"Vendor Card", Vendor);
                    end;
                }
                field(VendorName; Rec."Vendor Name")
                {
                    ApplicationArea = All;
                    Caption = 'Name';
                    ToolTip = 'The vendor name.';
                }
                field("Overall Score"; Rec."Overall Score")
                {
                    ApplicationArea = All;
                    ToolTip = 'The overall vendor score combining all factors.';
                    StyleExpr = ScoreStyle;
                }
                field("Performance Score"; Rec."Performance Score")
                {
                    ApplicationArea = All;
                    ToolTip = 'The vendor performance score.';
                }
                field("Unit Cost"; Rec."Unit Cost")
                {
                    ApplicationArea = All;
                    ToolTip = 'The unit cost from this vendor.';
                }
                field(TotalCost; Rec."Unit Cost" * RequiredQty)
                {
                    ApplicationArea = All;
                    Caption = 'Total Cost';
                    ToolTip = 'The total cost for the required quantity.';
                }
                field("Lead Time Days"; Rec."Lead Time Days")
                {
                    ApplicationArea = All;
                    ToolTip = 'Lead time in days.';
                }
                field("Expected Date"; Rec."Expected Date")
                {
                    ApplicationArea = All;
                    ToolTip = 'Expected delivery date.';
                }
                field("Can Meet Date"; Rec."Can Meet Date")
                {
                    ApplicationArea = All;
                    ToolTip = 'Indicates if the vendor can meet the required date.';
                    StyleExpr = CanMeetStyle;
                }
            }
        }
    }

    actions
    {
        area(Processing)
        {
            action(SelectVendor)
            {
                ApplicationArea = All;
                Caption = 'Select This Vendor';
                ToolTip = 'Select this vendor for the purchase.';
                Image = Approve;
                Promoted = true;
                PromotedCategory = Process;
                PromotedIsBig = true;
                ShortcutKey = 'Return';

                trigger OnAction()
                begin
                    SelectedVendorNo := Rec."Vendor No.";
                    VendorSelected := true;
                    CurrPage.Close();
                end;
            }
            action(ViewVendorCard)
            {
                ApplicationArea = All;
                Caption = 'View Vendor Card';
                ToolTip = 'Open the vendor card.';
                Image = Vendor;
                RunObject = page "Vendor Card";
                RunPageLink = "No." = field("Vendor No.");
            }
            action(ViewVendorPerformance)
            {
                ApplicationArea = All;
                Caption = 'View Performance History';
                ToolTip = 'View vendor performance history.';
                Image = History;

                trigger OnAction()
                var
                    VendorPerf: Record "Vendor Performance";
                    VendorPerfList: Page "Vendor Performance List";
                begin
                    VendorPerf.SetRange("Vendor No.", Rec."Vendor No.");
                    VendorPerfList.SetTableView(VendorPerf);
                    VendorPerfList.Run();
                end;
            }
        }
    }

    var
        ItemNo: Code[20];
        RequiredQty: Decimal;
        RequiredDate: Date;
        SelectedVendorNo: Code[20];
        VendorSelected: Boolean;
        ScoreStyle: Text;
        CanMeetStyle: Text;

    procedure SetData(var TempVendorRanking: Record "Vendor Ranking" temporary; NewItemNo: Code[20]; NewQty: Decimal; NewDate: Date)
    begin
        ItemNo := NewItemNo;
        RequiredQty := NewQty;
        RequiredDate := NewDate;

        Rec.DeleteAll();
        if TempVendorRanking.FindSet() then
            repeat
                Rec := TempVendorRanking;
                Rec.Insert();
            until TempVendorRanking.Next() = 0;
    end;

    procedure GetSelectedVendor(): Code[20]
    begin
        exit(SelectedVendorNo);
    end;

    trigger OnAfterGetRecord()
    begin
        SetStyles();
    end;

    local procedure SetStyles()
    begin
        // Score style
        if Rec."Overall Score" >= 80 then
            ScoreStyle := 'Favorable'
        else if Rec."Overall Score" >= 60 then
            ScoreStyle := 'Ambiguous'
        else
            ScoreStyle := 'Attention';

        // Can meet style
        if Rec."Can Meet Date" then
            CanMeetStyle := 'Favorable'
        else
            CanMeetStyle := 'Unfavorable';
    end;

    local procedure GetDataCaption(): Text
    var
        Item: Record Item;
    begin
        if Item.Get(ItemNo) then
            exit(StrSubstNo('%1 - %2', ItemNo, Item.Description));
        exit(ItemNo);
    end;

    trigger OnQueryClosePage(CloseAction: Action): Boolean
    begin
        if VendorSelected then
            exit(true);
        if CloseAction = Action::LookupOK then begin
            SelectedVendorNo := Rec."Vendor No.";
            exit(true);
        end;
        exit(true);
    end;
}
