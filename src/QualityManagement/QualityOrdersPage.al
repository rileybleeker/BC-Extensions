page 50100 "Quality Orders"
{
    PageType = List;
    ApplicationArea = All;
    UsageCategory = Lists;
    SourceTable = "Quality Order";
    Caption = 'Quality Orders';

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
                field("Item No."; Rec."Item No.")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the item number.';
                }
                field("Lot No."; Rec."Lot No.")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the lot number.';
                }
                field("Test Status"; Rec."Test Status")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the quality test status.';
                }
                field("Item Ledger Entry No."; Rec."Item Ledger Entry No.")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the related item ledger entry.';
                }
                field("Created Date"; Rec."Created Date")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies when the quality order was created.';
                }
                field("Tested Date"; Rec."Tested Date")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies when the test was completed.';
                }
                field("Tested By"; Rec."Tested By")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies who performed the test.';
                }
            }
        }
    }

    actions
    {
        area(Processing)
        {
            action(MarkAsPassed)
            {
                ApplicationArea = All;
                Caption = 'Mark as Passed';
                Image = Approve;
                ToolTip = 'Mark the quality test as passed.';
                
                trigger OnAction()
                var
                    QualityMgt: Codeunit "Quality Management";
                begin
                    QualityMgt.MarkQualityOrderAsPassed(Rec);
                    CurrPage.Update(false);
                end;
            }
            action(MarkAsFailed)
            {
                ApplicationArea = All;
                Caption = 'Mark as Failed';
                Image = Reject;
                ToolTip = 'Mark the quality test as failed.';
                
                trigger OnAction()
                var
                    QualityMgt: Codeunit "Quality Management";
                begin
                    QualityMgt.MarkQualityOrderAsFailed(Rec);
                    CurrPage.Update(false);
                end;
            }
        }
    }
}
