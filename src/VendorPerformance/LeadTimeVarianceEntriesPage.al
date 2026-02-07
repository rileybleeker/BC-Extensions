page 50123 "Lead Time Variance Entries"
{
    PageType = List;
    ApplicationArea = All;
    UsageCategory = History;
    SourceTable = "Lead Time Variance Entry";
    Caption = 'Lead Time Variance Entries';
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
                }
                field("Vendor No."; Rec."Vendor No.")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the vendor number.';
                }
                field(VendorName; Rec.GetVendorName())
                {
                    ApplicationArea = All;
                    Caption = 'Vendor Name';
                    ToolTip = 'Specifies the vendor name.';
                }
                field("Item No."; Rec."Item No.")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the item number.';
                }
                field(ItemDescription; Rec.GetItemDescription())
                {
                    ApplicationArea = All;
                    Caption = 'Description';
                    ToolTip = 'Specifies the item description.';
                }
                field("Purchase Order No."; Rec."Purchase Order No.")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the purchase order number.';
                }
                field("Posted Receipt No."; Rec."Posted Receipt No.")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the posted receipt number.';
                }
                field("Order Date"; Rec."Order Date")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the purchase order date.';
                }
                field("Promised Receipt Date"; Rec."Promised Receipt Date")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the promised receipt date.';
                }
                field("Actual Receipt Date"; Rec."Actual Receipt Date")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the actual receipt date.';
                }
                field("Promised Lead Time Days"; Rec."Promised Lead Time Days")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the promised lead time in days.';
                }
                field("Actual Lead Time Days"; Rec."Actual Lead Time Days")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the actual lead time in days.';
                }
                field("Variance Days"; Rec."Variance Days")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the variance in days (positive = late, negative = early).';
                    StyleExpr = VarianceStyle;
                }
                field("On Time"; Rec."On Time")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies whether the delivery was on time.';
                }
                field("Delivery Status"; Rec."Delivery Status")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies whether the delivery was early, on time, or late.';
                    StyleExpr = StatusStyle;
                }
                field("Receipt Qty"; Rec."Receipt Qty")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the quantity received.';
                }
                field("Unit of Measure Code"; Rec."Unit of Measure Code")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the unit of measure.';
                }
                field("Location Code"; Rec."Location Code")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the location code.';
                }
                field("Created DateTime"; Rec."Created DateTime")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies when the entry was created.';
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
        area(Navigation)
        {
            action(ViewVendor)
            {
                ApplicationArea = All;
                Caption = 'View Vendor';
                ToolTip = 'Open the vendor card.';
                Image = Vendor;
                RunObject = page "Vendor Card";
                RunPageLink = "No." = field("Vendor No.");
            }
            action(ViewItem)
            {
                ApplicationArea = All;
                Caption = 'View Item';
                ToolTip = 'Open the item card.';
                Image = Item;
                RunObject = page "Item Card";
                RunPageLink = "No." = field("Item No.");
            }
            action(ViewPostedReceipt)
            {
                ApplicationArea = All;
                Caption = 'View Posted Receipt';
                ToolTip = 'Open the posted purchase receipt.';
                Image = PostedReceipt;

                trigger OnAction()
                var
                    PurchRcptHeader: Record "Purch. Rcpt. Header";
                begin
                    if PurchRcptHeader.Get(Rec."Posted Receipt No.") then
                        Page.Run(Page::"Posted Purchase Receipt", PurchRcptHeader);
                end;
            }
            action(ViewVendorPerformance)
            {
                ApplicationArea = All;
                Caption = 'Vendor Performance';
                ToolTip = 'View performance history for this vendor.';
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
        area(Processing)
        {
            action(CreateHistoricalEntries)
            {
                ApplicationArea = All;
                Caption = 'Create Historical Entries';
                ToolTip = 'Create lead time variance entries from historical receipt data.';
                Image = History;

                trigger OnAction()
                var
                    LeadTimeTracker: Codeunit "Lead Time Variance Tracker";
                    StartDate: Date;
                    EndDate: Date;
                begin
                    StartDate := CalcDate('<-12M>', WorkDate());
                    EndDate := WorkDate();
                    LeadTimeTracker.CreateAllHistoricalEntries(StartDate, EndDate);
                    CurrPage.Update(false);
                    Message('Historical lead time variance entries created.');
                end;
            }
            action(DeleteSelected)
            {
                ApplicationArea = All;
                Caption = 'Delete Selected';
                ToolTip = 'Delete the selected lead time variance entries.';
                Image = Delete;

                trigger OnAction()
                var
                    LeadTimeVariance: Record "Lead Time Variance Entry";
                begin
                    if not Confirm('Delete selected entries?') then
                        exit;
                    CurrPage.SetSelectionFilter(LeadTimeVariance);
                    LeadTimeVariance.DeleteAll();
                    CurrPage.Update(false);
                end;
            }
            action(DeleteAllForVendor)
            {
                ApplicationArea = All;
                Caption = 'Delete All for Vendor';
                ToolTip = 'Delete all lead time variance entries for the current vendor.';
                Image = Delete;

                trigger OnAction()
                var
                    LeadTimeVariance: Record "Lead Time Variance Entry";
                begin
                    if Rec."Vendor No." = '' then
                        exit;
                    if not Confirm('Delete all entries for vendor %1?', false, Rec."Vendor No.") then
                        exit;
                    LeadTimeVariance.SetRange("Vendor No.", Rec."Vendor No.");
                    LeadTimeVariance.DeleteAll();
                    CurrPage.Update(false);
                    Message('Entries deleted for vendor %1.', Rec."Vendor No.");
                end;
            }
        }
        area(Promoted)
        {
            group(Category_Process)
            {
                Caption = 'Process';

                actionref(DeleteSelected_Promoted; DeleteSelected) { }
                actionref(DeleteAllForVendor_Promoted; DeleteAllForVendor) { }
                actionref(CreateHistoricalEntries_Promoted; CreateHistoricalEntries) { }
            }
            group(Category_Navigate)
            {
                Caption = 'Navigate';

                actionref(ViewVendor_Promoted; ViewVendor) { }
                actionref(ViewItem_Promoted; ViewItem) { }
                actionref(ViewPostedReceipt_Promoted; ViewPostedReceipt) { }
                actionref(ViewVendorPerformance_Promoted; ViewVendorPerformance) { }
            }
        }
    }

    var
        VarianceStyle: Text;
        StatusStyle: Text;

    trigger OnAfterGetRecord()
    begin
        SetStyles();
    end;

    local procedure SetStyles()
    begin
        // Variance style
        if Abs(Rec."Variance Days") <= 0 then
            VarianceStyle := 'Favorable'
        else if Abs(Rec."Variance Days") <= 2 then
            VarianceStyle := 'Ambiguous'
        else
            VarianceStyle := 'Unfavorable';

        // Status style
        case Rec."Delivery Status" of
            Rec."Delivery Status"::"On Time":
                StatusStyle := 'Favorable';
            Rec."Delivery Status"::Early:
                StatusStyle := 'Ambiguous';
            Rec."Delivery Status"::Late:
                StatusStyle := 'Unfavorable';
            else
                StatusStyle := 'Subordinate';
        end;
    end;
}
