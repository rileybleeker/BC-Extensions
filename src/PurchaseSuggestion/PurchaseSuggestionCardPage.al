page 50151 "Purchase Suggestion Card"
{
    PageType = Card;
    ApplicationArea = All;
    SourceTable = "Purchase Suggestion";
    Caption = 'Purchase Suggestion';

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
                    ToolTip = 'Specifies the entry number.';
                    Editable = false;
                }
                field("Status"; Rec."Status")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the status.';
                    StyleExpr = StatusStyle;
                    Editable = false;
                }
                field("Suggestion Date"; Rec."Suggestion Date")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the suggestion date.';
                    Editable = false;
                }
            }
            group(ItemDetails)
            {
                Caption = 'Item';

                field("Item No."; Rec."Item No.")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the item number.';
                }
                field("Item Description"; Rec."Item Description")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the item description.';
                }
                field("Variant Code"; Rec."Variant Code")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the variant code.';
                }
                field("Location Code"; Rec."Location Code")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the location.';
                }
                field("Suggested Qty"; Rec."Suggested Qty")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the suggested quantity.';
                }
                field("Unit of Measure"; Rec."Unit of Measure")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the unit of measure.';
                }
                field("Required Date"; Rec."Required Date")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the required date.';
                }
            }
            group(Recommendation)
            {
                Caption = 'Recommendation';

                field("Recommended Vendor No."; Rec."Recommended Vendor No.")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the recommended vendor.';
                    Editable = false;

                    trigger OnDrillDown()
                    var
                        Vendor: Record Vendor;
                    begin
                        if Vendor.Get(Rec."Recommended Vendor No.") then
                            Page.Run(Page::"Vendor Card", Vendor);
                    end;
                }
                field("Recommended Vendor Name"; Rec."Recommended Vendor Name")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the recommended vendor name.';
                    Editable = false;
                }
                field("Recommendation Reason"; Rec."Recommendation Reason")
                {
                    ApplicationArea = All;
                    ToolTip = 'Explains why this vendor was recommended.';
                    Editable = false;
                    MultiLine = true;
                }
            }
            group(VendorComparison)
            {
                Caption = 'Vendor Comparison';

                group(Vendor1Group)
                {
                    Caption = 'Vendor 1 (Best)';
                    Visible = Rec."Vendor 1 No." <> '';

                    field("Vendor 1 No."; Rec."Vendor 1 No.")
                    {
                        ApplicationArea = All;
                        Caption = 'No.';
                        ToolTip = 'Specifies vendor 1.';
                    }
                    field("Vendor 1 Name"; Rec."Vendor 1 Name")
                    {
                        ApplicationArea = All;
                        Caption = 'Name';
                        ToolTip = 'Specifies vendor 1 name.';
                    }
                    field("Vendor 1 Score"; Rec."Vendor 1 Score")
                    {
                        ApplicationArea = All;
                        Caption = 'Score';
                        ToolTip = 'Specifies vendor 1 overall score.';
                        StyleExpr = Vendor1ScoreStyle;
                    }
                    field("Vendor 1 Unit Cost"; Rec."Vendor 1 Unit Cost")
                    {
                        ApplicationArea = All;
                        Caption = 'Unit Cost';
                        ToolTip = 'Specifies vendor 1 unit cost.';
                    }
                    field("Vendor 1 Lead Time"; Rec."Vendor 1 Lead Time")
                    {
                        ApplicationArea = All;
                        Caption = 'Lead Time (Days)';
                        ToolTip = 'Specifies vendor 1 lead time.';
                    }
                    field("Vendor 1 Expected Date"; Rec."Vendor 1 Expected Date")
                    {
                        ApplicationArea = All;
                        Caption = 'Expected Date';
                        ToolTip = 'Specifies vendor 1 expected delivery date.';
                    }
                }
                group(Vendor2Group)
                {
                    Caption = 'Vendor 2';
                    Visible = Rec."Vendor 2 No." <> '';

                    field("Vendor 2 No."; Rec."Vendor 2 No.")
                    {
                        ApplicationArea = All;
                        Caption = 'No.';
                        ToolTip = 'Specifies vendor 2.';
                    }
                    field("Vendor 2 Name"; Rec."Vendor 2 Name")
                    {
                        ApplicationArea = All;
                        Caption = 'Name';
                        ToolTip = 'Specifies vendor 2 name.';
                    }
                    field("Vendor 2 Score"; Rec."Vendor 2 Score")
                    {
                        ApplicationArea = All;
                        Caption = 'Score';
                        ToolTip = 'Specifies vendor 2 overall score.';
                    }
                    field("Vendor 2 Unit Cost"; Rec."Vendor 2 Unit Cost")
                    {
                        ApplicationArea = All;
                        Caption = 'Unit Cost';
                        ToolTip = 'Specifies vendor 2 unit cost.';
                    }
                    field("Vendor 2 Lead Time"; Rec."Vendor 2 Lead Time")
                    {
                        ApplicationArea = All;
                        Caption = 'Lead Time (Days)';
                        ToolTip = 'Specifies vendor 2 lead time.';
                    }
                    field("Vendor 2 Expected Date"; Rec."Vendor 2 Expected Date")
                    {
                        ApplicationArea = All;
                        Caption = 'Expected Date';
                        ToolTip = 'Specifies vendor 2 expected delivery date.';
                    }
                }
                group(Vendor3Group)
                {
                    Caption = 'Vendor 3';
                    Visible = Rec."Vendor 3 No." <> '';

                    field("Vendor 3 No."; Rec."Vendor 3 No.")
                    {
                        ApplicationArea = All;
                        Caption = 'No.';
                        ToolTip = 'Specifies vendor 3.';
                    }
                    field("Vendor 3 Name"; Rec."Vendor 3 Name")
                    {
                        ApplicationArea = All;
                        Caption = 'Name';
                        ToolTip = 'Specifies vendor 3 name.';
                    }
                    field("Vendor 3 Score"; Rec."Vendor 3 Score")
                    {
                        ApplicationArea = All;
                        Caption = 'Score';
                        ToolTip = 'Specifies vendor 3 overall score.';
                    }
                    field("Vendor 3 Unit Cost"; Rec."Vendor 3 Unit Cost")
                    {
                        ApplicationArea = All;
                        Caption = 'Unit Cost';
                        ToolTip = 'Specifies vendor 3 unit cost.';
                    }
                    field("Vendor 3 Lead Time"; Rec."Vendor 3 Lead Time")
                    {
                        ApplicationArea = All;
                        Caption = 'Lead Time (Days)';
                        ToolTip = 'Specifies vendor 3 lead time.';
                    }
                    field("Vendor 3 Expected Date"; Rec."Vendor 3 Expected Date")
                    {
                        ApplicationArea = All;
                        Caption = 'Expected Date';
                        ToolTip = 'Specifies vendor 3 expected delivery date.';
                    }
                }
            }
            group(Substitution)
            {
                Caption = 'Substitution Option';
                Visible = Rec."Substitute Item Available";

                field("Substitute Item Available"; Rec."Substitute Item Available")
                {
                    ApplicationArea = All;
                    ToolTip = 'Indicates if a substitute is available.';
                }
                field("Substitute Item No."; Rec."Substitute Item No.")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the substitute item.';

                    trigger OnDrillDown()
                    var
                        Item: Record Item;
                    begin
                        if Item.Get(Rec."Substitute Item No.") then
                            Page.Run(Page::"Item Card", Item);
                    end;
                }
                field("Substitute Lead Time Savings"; Rec."Substitute Lead Time Savings")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies how many days faster the substitute can be delivered.';
                }
            }
            group(Selection)
            {
                Caption = 'Selection';

                field("Selected Vendor No."; Rec."Selected Vendor No.")
                {
                    ApplicationArea = All;
                    ToolTip = 'Select the vendor for this purchase.';
                    Editable = Rec."Status" = Rec."Status"::New;
                }
                field("Selected Vendor Name"; Rec."Selected Vendor Name")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the selected vendor name.';
                    Editable = false;
                }
                field(TotalCost; Rec.GetTotalCost())
                {
                    ApplicationArea = All;
                    Caption = 'Total Cost';
                    ToolTip = 'Specifies the total cost for the selected vendor.';
                    Editable = false;
                }
                field(ExpectedDelivery; Rec.GetExpectedDate())
                {
                    ApplicationArea = All;
                    Caption = 'Expected Delivery';
                    ToolTip = 'Specifies the expected delivery date for the selected vendor.';
                    Editable = false;
                }
            }
            group(Result)
            {
                Caption = 'Result';
                Visible = (Rec."Status" = Rec."Status"::"PO Created") or (Rec."Status" = Rec."Status"::Rejected);

                field("Purchase Order No."; Rec."Purchase Order No.")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the created purchase order.';
                    Editable = false;

                    trigger OnDrillDown()
                    var
                        PurchHeader: Record "Purchase Header";
                    begin
                        if PurchHeader.Get(PurchHeader."Document Type"::Order, Rec."Purchase Order No.") then
                            Page.Run(Page::"Purchase Order", PurchHeader);
                    end;
                }
                field("Rejection Reason"; Rec."Rejection Reason")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies why the suggestion was rejected.';
                    Editable = false;
                    Visible = Rec."Status" = Rec."Status"::Rejected;
                }
            }
            group(AuditInfo)
            {
                Caption = 'Audit';

                field("Created By"; Rec."Created By")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies who created the suggestion.';
                }
                field("Created DateTime"; Rec."Created DateTime")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies when the suggestion was created.';
                }
                field("Approved By"; Rec."Approved By")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies who approved the suggestion.';
                }
                field("Approved DateTime"; Rec."Approved DateTime")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies when the suggestion was approved.';
                }
            }
        }
        area(FactBoxes)
        {
            part(VendorScoreFactbox; "Vendor Score Factbox")
            {
                ApplicationArea = All;
                SubPageLink = "No." = field("Selected Vendor No.");
            }
            systempart(Links; Links)
            {
                ApplicationArea = All;
            }
            systempart(Notes; Notes)
            {
                ApplicationArea = All;
            }
        }
    }

    actions
    {
        area(Processing)
        {
            action(SelectVendor1)
            {
                ApplicationArea = All;
                Caption = 'Select Vendor 1';
                ToolTip = 'Select vendor 1 (recommended).';
                Image = Vendor;
                Enabled = Rec."Vendor 1 No." <> '';

                trigger OnAction()
                begin
                    Rec.Validate("Selected Vendor No.", Rec."Vendor 1 No.");
                    Rec.Modify(true);
                    CurrPage.Update(false);
                end;
            }
            action(SelectVendor2)
            {
                ApplicationArea = All;
                Caption = 'Select Vendor 2';
                ToolTip = 'Select vendor 2.';
                Image = Vendor;
                Enabled = Rec."Vendor 2 No." <> '';

                trigger OnAction()
                begin
                    Rec.Validate("Selected Vendor No.", Rec."Vendor 2 No.");
                    Rec.Modify(true);
                    CurrPage.Update(false);
                end;
            }
            action(SelectVendor3)
            {
                ApplicationArea = All;
                Caption = 'Select Vendor 3';
                ToolTip = 'Select vendor 3.';
                Image = Vendor;
                Enabled = Rec."Vendor 3 No." <> '';

                trigger OnAction()
                begin
                    Rec.Validate("Selected Vendor No.", Rec."Vendor 3 No.");
                    Rec.Modify(true);
                    CurrPage.Update(false);
                end;
            }
            action(Approve)
            {
                ApplicationArea = All;
                Caption = 'Approve';
                ToolTip = 'Approve the suggestion.';
                Image = Approve;
                Promoted = true;
                PromotedCategory = Process;
                PromotedIsBig = true;
                Enabled = Rec."Status" = Rec."Status"::New;

                trigger OnAction()
                var
                    PurchSuggMgr: Codeunit "Purchase Suggestion Manager";
                begin
                    PurchSuggMgr.ApproveSuggestion(Rec);
                    CurrPage.Update(false);
                end;
            }
            action(CreatePO)
            {
                ApplicationArea = All;
                Caption = 'Create Purchase Order';
                ToolTip = 'Create purchase order.';
                Image = MakeOrder;
                Promoted = true;
                PromotedCategory = Process;
                PromotedIsBig = true;
                Enabled = Rec."Status" = Rec."Status"::Approved;

                trigger OnAction()
                var
                    PurchSuggMgr: Codeunit "Purchase Suggestion Manager";
                    PONo: Code[20];
                    Consolidate: Boolean;
                begin
                    Consolidate := Confirm('Consolidate with existing open PO for this vendor?', true);
                    PONo := PurchSuggMgr.CreatePurchaseOrder(Rec, Consolidate);
                    Message('Purchase Order %1 created.', PONo);
                    CurrPage.Update(false);
                end;
            }
            action(Reject)
            {
                ApplicationArea = All;
                Caption = 'Reject';
                ToolTip = 'Reject the suggestion.';
                Image = Reject;
                Promoted = true;
                PromotedCategory = Process;

                trigger OnAction()
                var
                    PurchSuggMgr: Codeunit "Purchase Suggestion Manager";
                begin
                    PurchSuggMgr.RejectSuggestion(Rec, '');
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
                ToolTip = 'Open the item card.';
                Image = Item;
                RunObject = page "Item Card";
                RunPageLink = "No." = field("Item No.");
            }
        }
    }

    var
        StatusStyle: Text;
        Vendor1ScoreStyle: Text;

    trigger OnAfterGetRecord()
    begin
        SetStyles();
    end;

    local procedure SetStyles()
    begin
        case Rec."Status" of
            Rec."Status"::New:
                StatusStyle := 'Attention';
            Rec."Status"::Approved:
                StatusStyle := 'Favorable';
            Rec."Status"::"PO Created":
                StatusStyle := 'Favorable';
            Rec."Status"::Rejected:
                StatusStyle := 'Unfavorable';
            else
                StatusStyle := 'Standard';
        end;

        if Rec."Vendor 1 Score" >= 80 then
            Vendor1ScoreStyle := 'Favorable'
        else if Rec."Vendor 1 Score" >= 60 then
            Vendor1ScoreStyle := 'Ambiguous'
        else
            Vendor1ScoreStyle := 'Attention';
    end;
}
