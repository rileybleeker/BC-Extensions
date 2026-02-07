page 50130 "Vendor NCR List"
{
    PageType = List;
    ApplicationArea = All;
    UsageCategory = Lists;
    SourceTable = "Vendor NCR";
    Caption = 'Vendor Non-Conformance Reports';
    CardPageId = "Vendor NCR Card";
    Editable = false;

    layout
    {
        area(Content)
        {
            repeater(Group)
            {
                field("NCR No."; Rec."NCR No.")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the NCR document number.';
                }
                field("NCR Date"; Rec."NCR Date")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the date of the non-conformance.';
                }
                field("Status"; Rec."Status")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the current status of the NCR.';
                    StyleExpr = StatusStyle;
                }
                field("Priority"; Rec."Priority")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the priority of the NCR.';
                    StyleExpr = PriorityStyle;
                }
                field("Vendor No."; Rec."Vendor No.")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the vendor number.';
                }
                field("Vendor Name"; Rec."Vendor Name")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the vendor name.';
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
                field("Category"; Rec."Category")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the category of non-conformance.';
                }
                field("Affected Qty"; Rec."Affected Qty")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the quantity affected by the non-conformance.';
                }
                field("Disposition"; Rec."Disposition")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies how the non-conforming material was handled.';
                }
                field("Cost Impact"; Rec."Cost Impact")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the cost impact of the non-conformance.';
                }
                field("Posted Receipt No."; Rec."Posted Receipt No.")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the posted purchase receipt number.';
                }
                field("Lot No."; Rec."Lot No.")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the lot number.';
                    Visible = false;
                }
                field("Created By"; Rec."Created By")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies who created the NCR.';
                    Visible = false;
                }
                field("Closed Date"; Rec."Closed Date")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies when the NCR was closed.';
                }
            }
        }
        area(FactBoxes)
        {
            part(VendorScoreFactbox; "Vendor Score Factbox")
            {
                ApplicationArea = All;
                SubPageLink = "No." = field("Vendor No.");
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
            action(NewNCR)
            {
                ApplicationArea = All;
                Caption = 'New NCR';
                ToolTip = 'Create a new non-conformance report.';
                Image = NewDocument;
                Promoted = true;
                PromotedCategory = New;
                PromotedIsBig = true;
                RunObject = page "Vendor NCR Card";
                RunPageMode = Create;
            }
            action(CloseNCR)
            {
                ApplicationArea = All;
                Caption = 'Close NCR';
                ToolTip = 'Close the selected NCR.';
                Image = Close;
                Promoted = true;
                PromotedCategory = Process;

                trigger OnAction()
                begin
                    if Rec."Status" = Rec."Status"::Closed then
                        Error('NCR %1 is already closed.', Rec."NCR No.");

                    if not Confirm('Close NCR %1?', false, Rec."NCR No.") then
                        exit;

                    Rec.Validate("Status", Rec."Status"::Closed);
                    Rec.Modify(true);
                    CurrPage.Update(false);
                end;
            }
            action(ReopenNCR)
            {
                ApplicationArea = All;
                Caption = 'Reopen NCR';
                ToolTip = 'Reopen the selected NCR.';
                Image = ReOpen;

                trigger OnAction()
                begin
                    if Rec."Status" <> Rec."Status"::Closed then
                        Error('NCR %1 is not closed.', Rec."NCR No.");

                    if not Confirm('Reopen NCR %1?', false, Rec."NCR No.") then
                        exit;

                    Rec.Validate("Status", Rec."Status"::Open);
                    Rec.Modify(true);
                    CurrPage.Update(false);
                end;
            }
        }
        area(Navigation)
        {
            action(ViewVendor)
            {
                ApplicationArea = All;
                Caption = 'View Vendor';
                ToolTip = 'Open the vendor card.';
                Image = Vendor;
                Promoted = true;
                PromotedCategory = Category4;
                RunObject = page "Vendor Card";
                RunPageLink = "No." = field("Vendor No.");
            }
            action(ViewItem)
            {
                ApplicationArea = All;
                Caption = 'View Item';
                ToolTip = 'Open the item card.';
                Image = Item;
                Promoted = true;
                PromotedCategory = Category4;
                RunObject = page "Item Card";
                RunPageLink = "No." = field("Item No.");
            }
            action(ViewPostedReceipt)
            {
                ApplicationArea = All;
                Caption = 'View Posted Receipt';
                ToolTip = 'Open the posted purchase receipt.';
                Image = PostedReceipt;
                Promoted = true;
                PromotedCategory = Category4;

                trigger OnAction()
                var
                    PurchRcptHeader: Record "Purch. Rcpt. Header";
                begin
                    if Rec."Posted Receipt No." = '' then
                        exit;

                    if PurchRcptHeader.Get(Rec."Posted Receipt No.") then
                        Page.Run(Page::"Posted Purchase Receipt", PurchRcptHeader);
                end;
            }
            action(VendorNCRsByVendor)
            {
                ApplicationArea = All;
                Caption = 'All NCRs for Vendor';
                ToolTip = 'View all NCRs for this vendor.';
                Image = List;

                trigger OnAction()
                var
                    VendorNCR: Record "Vendor NCR";
                    VendorNCRList: Page "Vendor NCR List";
                begin
                    VendorNCR.SetRange("Vendor No.", Rec."Vendor No.");
                    VendorNCRList.SetTableView(VendorNCR);
                    VendorNCRList.Run();
                end;
            }
        }
        area(Reporting)
        {
            action(OpenNCRs)
            {
                ApplicationArea = All;
                Caption = 'Open NCRs';
                ToolTip = 'Filter to show only open NCRs.';
                Image = FilterLines;

                trigger OnAction()
                begin
                    Rec.SetRange("Status", Rec."Status"::Open);
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
        PriorityStyle: Text;

    trigger OnAfterGetRecord()
    begin
        SetStyles();
    end;

    local procedure SetStyles()
    begin
        // Status style
        case Rec."Status" of
            Rec."Status"::Open:
                StatusStyle := 'Attention';
            Rec."Status"::"Under Review":
                StatusStyle := 'Ambiguous';
            Rec."Status"::"Pending Vendor Response":
                StatusStyle := 'Ambiguous';
            Rec."Status"::Closed:
                StatusStyle := 'Favorable';
        end;

        // Priority style
        case Rec."Priority" of
            Rec."Priority"::Low:
                PriorityStyle := 'Subordinate';
            Rec."Priority"::Medium:
                PriorityStyle := 'Standard';
            Rec."Priority"::High:
                PriorityStyle := 'Attention';
            Rec."Priority"::Critical:
                PriorityStyle := 'Unfavorable';
        end;
    end;
}
