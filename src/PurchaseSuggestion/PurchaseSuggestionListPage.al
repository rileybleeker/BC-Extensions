page 50150 "Purchase Suggestion List"
{
    PageType = List;
    ApplicationArea = All;
    UsageCategory = Lists;
    SourceTable = "Purchase Suggestion";
    Caption = 'Purchase Suggestions';
    CardPageId = "Purchase Suggestion Card";
    Editable = false;

    layout
    {
        area(Content)
        {
            repeater(Group)
            {
                field("Entry No."; Rec."Entry No.")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the entry number.';
                    Visible = false;
                }
                field("Status"; Rec."Status")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the status of the suggestion.';
                    StyleExpr = StatusStyle;
                }
                field("Suggestion Date"; Rec."Suggestion Date")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies when the suggestion was created.';
                }
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
                field("Suggested Qty"; Rec."Suggested Qty")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the suggested quantity to purchase.';
                }
                field("Unit of Measure"; Rec."Unit of Measure")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the unit of measure.';
                }
                field("Required Date"; Rec."Required Date")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies when the item is required.';
                }
                field("Location Code"; Rec."Location Code")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the location.';
                }
                field("Recommended Vendor No."; Rec."Recommended Vendor No.")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the recommended vendor.';
                }
                field("Recommended Vendor Name"; Rec."Recommended Vendor Name")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the recommended vendor name.';
                }
                field("Vendor 1 Score"; Rec."Vendor 1 Score")
                {
                    ApplicationArea = All;
                    Caption = 'Best Score';
                    ToolTip = 'Specifies the score of the best vendor.';
                }
                field("Vendor 1 Expected Date"; Rec."Vendor 1 Expected Date")
                {
                    ApplicationArea = All;
                    Caption = 'Expected Date';
                    ToolTip = 'Specifies the expected delivery date from the best vendor.';
                }
                field("Alternative Available"; Rec."Alternative Available")
                {
                    ApplicationArea = All;
                    ToolTip = 'Indicates if alternative vendors are available.';
                }
                field("Substitute Item Available"; Rec."Substitute Item Available")
                {
                    ApplicationArea = All;
                    ToolTip = 'Indicates if a substitute item is available.';
                }
                field("Selected Vendor No."; Rec."Selected Vendor No.")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the selected vendor.';
                }
                field("Purchase Order No."; Rec."Purchase Order No.")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the created purchase order number.';
                }
            }
        }
        area(FactBoxes)
        {
            part(VendorScoreFactbox; "Vendor Score Factbox")
            {
                ApplicationArea = All;
                SubPageLink = "No." = field("Recommended Vendor No.");
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
            action(Approve)
            {
                ApplicationArea = All;
                Caption = 'Approve';
                ToolTip = 'Approve the selected suggestion.';
                Image = Approve;
                Promoted = true;
                PromotedCategory = Process;
                PromotedIsBig = true;

                trigger OnAction()
                var
                    PurchSuggMgr: Codeunit "Purchase Suggestion Manager";
                begin
                    PurchSuggMgr.ApproveSuggestion(Rec);
                    CurrPage.Update(false);
                end;
            }
            action(Reject)
            {
                ApplicationArea = All;
                Caption = 'Reject';
                ToolTip = 'Reject the selected suggestion.';
                Image = Reject;
                Promoted = true;
                PromotedCategory = Process;

                trigger OnAction()
                var
                    PurchSuggMgr: Codeunit "Purchase Suggestion Manager";
                    RejectReason: Text[250];
                begin
                    if not GetRejectReason(RejectReason) then
                        exit;
                    PurchSuggMgr.RejectSuggestion(Rec, RejectReason);
                    CurrPage.Update(false);
                end;
            }
            action(CreatePO)
            {
                ApplicationArea = All;
                Caption = 'Create Purchase Order';
                ToolTip = 'Create a purchase order from the selected suggestion.';
                Image = MakeOrder;
                Promoted = true;
                PromotedCategory = Process;
                PromotedIsBig = true;

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
            action(Cancel)
            {
                ApplicationArea = All;
                Caption = 'Cancel';
                ToolTip = 'Cancel the selected suggestion.';
                Image = Cancel;

                trigger OnAction()
                var
                    PurchSuggMgr: Codeunit "Purchase Suggestion Manager";
                begin
                    if not Confirm('Cancel this suggestion?', false) then
                        exit;
                    PurchSuggMgr.CancelSuggestion(Rec);
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
            action(ViewRecommendedVendor)
            {
                ApplicationArea = All;
                Caption = 'View Recommended Vendor';
                ToolTip = 'Open the recommended vendor card.';
                Image = Vendor;
                RunObject = page "Vendor Card";
                RunPageLink = "No." = field("Recommended Vendor No.");
            }
            action(ViewPO)
            {
                ApplicationArea = All;
                Caption = 'View Purchase Order';
                ToolTip = 'Open the created purchase order.';
                Image = Order;

                trigger OnAction()
                var
                    PurchHeader: Record "Purchase Header";
                begin
                    if Rec."Purchase Order No." = '' then
                        Error('No purchase order has been created.');

                    PurchHeader.Get(PurchHeader."Document Type"::Order, Rec."Purchase Order No.");
                    Page.Run(Page::"Purchase Order", PurchHeader);
                end;
            }
        }
        area(Reporting)
        {
            action(ShowNew)
            {
                ApplicationArea = All;
                Caption = 'New Suggestions';
                ToolTip = 'Show only new suggestions.';
                Image = FilterLines;

                trigger OnAction()
                begin
                    Rec.SetRange("Status", Rec."Status"::New);
                    CurrPage.Update(false);
                end;
            }
            action(ShowApproved)
            {
                ApplicationArea = All;
                Caption = 'Approved Suggestions';
                ToolTip = 'Show only approved suggestions.';
                Image = FilterLines;

                trigger OnAction()
                begin
                    Rec.SetRange("Status", Rec."Status"::Approved);
                    CurrPage.Update(false);
                end;
            }
            action(ClearFilters)
            {
                ApplicationArea = All;
                Caption = 'Clear Filters';
                ToolTip = 'Remove all filters.';
                Image = ClearFilter;

                trigger OnAction()
                begin
                    Rec.Reset();
                    CurrPage.Update(false);
                end;
            }
        }
    }

    var
        StatusStyle: Text;

    trigger OnAfterGetRecord()
    begin
        SetStyles();
    end;

    local procedure SetStyles()
    begin
        case Rec."Status" of
            Rec."Status"::New:
                StatusStyle := 'Attention';
            Rec."Status"::"Under Review":
                StatusStyle := 'Ambiguous';
            Rec."Status"::Approved:
                StatusStyle := 'Favorable';
            Rec."Status"::"PO Created":
                StatusStyle := 'Favorable';
            Rec."Status"::Rejected:
                StatusStyle := 'Unfavorable';
            Rec."Status"::Cancelled:
                StatusStyle := 'Subordinate';
        end;
    end;

    local procedure GetRejectReason(var RejectReason: Text[250]): Boolean
    begin
        RejectReason := '';
        exit(true);  // Simple implementation - could add a dialog
    end;
}
