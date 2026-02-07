page 50131 "Vendor NCR Card"
{
    PageType = Card;
    ApplicationArea = All;
    SourceTable = "Vendor NCR";
    Caption = 'Vendor Non-Conformance Report';

    layout
    {
        area(Content)
        {
            group(General)
            {
                Caption = 'General';

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
                field("Category"; Rec."Category")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the category of non-conformance.';
                }
                field("Description"; Rec."Description")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies a brief description of the non-conformance.';
                }
            }
            group(VendorInfo)
            {
                Caption = 'Vendor';

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
            }
            group(ItemInfo)
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
                    ToolTip = 'Specifies the item variant.';
                }
                field("Lot No."; Rec."Lot No.")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the lot number.';
                }
                field("Serial No."; Rec."Serial No.")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the serial number.';
                }
            }
            group(SourceDocument)
            {
                Caption = 'Source Document';

                field("Purchase Order No."; Rec."Purchase Order No.")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the purchase order number.';
                }
                field("Posted Receipt No."; Rec."Posted Receipt No.")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the posted purchase receipt number.';
                }
                field("Location Code"; Rec."Location Code")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the location code.';
                }
            }
            group(Quantities)
            {
                Caption = 'Quantities';

                field("Receipt Qty"; Rec."Receipt Qty")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the total quantity received.';
                }
                field("Affected Qty"; Rec."Affected Qty")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the quantity affected by the non-conformance.';
                }
                field("Unit of Measure Code"; Rec."Unit of Measure Code")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the unit of measure.';
                }
            }
            group(Resolution)
            {
                Caption = 'Resolution';

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
                field("Cost Impact Currency"; Rec."Cost Impact Currency")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the currency of the cost impact.';
                }
            }
            group(Analysis)
            {
                Caption = 'Root Cause Analysis';

                field("Root Cause"; Rec."Root Cause")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the root cause of the non-conformance.';
                    MultiLine = true;
                }
                field("Corrective Action"; Rec."Corrective Action")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the corrective action taken.';
                    MultiLine = true;
                }
                field("Preventive Action"; Rec."Preventive Action")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the preventive action to avoid recurrence.';
                    MultiLine = true;
                }
            }
            group(AuditInfo)
            {
                Caption = 'Audit Information';

                field("Created By"; Rec."Created By")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies who created the NCR.';
                }
                field("Created DateTime"; Rec."Created DateTime")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies when the NCR was created.';
                }
                field("Closed Date"; Rec."Closed Date")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies when the NCR was closed.';
                }
                field("Closed By"; Rec."Closed By")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies who closed the NCR.';
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
            action(CloseNCR)
            {
                ApplicationArea = All;
                Caption = 'Close NCR';
                ToolTip = 'Close this NCR.';
                Image = Close;
                Promoted = true;
                PromotedCategory = Process;
                PromotedIsBig = true;

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
                ToolTip = 'Reopen this NCR.';
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
            action(SetUnderReview)
            {
                ApplicationArea = All;
                Caption = 'Set Under Review';
                ToolTip = 'Set the NCR status to Under Review.';
                Image = Approval;

                trigger OnAction()
                begin
                    Rec.Validate("Status", Rec."Status"::"Under Review");
                    Rec.Modify(true);
                    CurrPage.Update(false);
                end;
            }
            action(SetPendingVendor)
            {
                ApplicationArea = All;
                Caption = 'Set Pending Vendor Response';
                ToolTip = 'Set the NCR status to Pending Vendor Response.';
                Image = SendTo;

                trigger OnAction()
                begin
                    Rec.Validate("Status", Rec."Status"::"Pending Vendor Response");
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
            action(VendorNCRs)
            {
                ApplicationArea = All;
                Caption = 'All Vendor NCRs';
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
            action(VendorPerformance)
            {
                ApplicationArea = All;
                Caption = 'Vendor Performance';
                ToolTip = 'View vendor performance history.';
                Image = Statistics;

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
