page 50101 "Inventory Alert Log"
{
    PageType = List;
    ApplicationArea = All;
    UsageCategory = Lists;
    SourceTable = "Inventory Alert Log";
    Caption = 'Inventory Alert Log';
    Editable = false;

    layout
    {
        area(Content)
        {
            repeater(GroupName)
            {
                field("Entry No."; Rec."Entry No.")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the entry number.';
                }
                field("Item Ledger Entry No."; Rec."Item Ledger Entry No.")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the related item ledger entry number.';
                }
                field("Item No."; Rec."Item No.")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the item number.';
                }
                field("Location Code"; Rec."Location Code")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the location code.';
                }
                field("Current Inventory"; Rec."Current Inventory")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the current inventory level.';
                }
                field("Safety Stock"; Rec."Safety Stock")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the safety stock threshold.';
                }
                field("Alert Timestamp"; Rec."Alert Timestamp")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies when the alert was generated.';
                }
                field("Alert Status"; Rec."Alert Status")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies if the alert was sent successfully or failed.';
                }
                field("Error Message"; Rec."Error Message")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the error message if the alert failed.';
                }
            }
        }
    }

    actions
    {
        area(Processing)
        {
            action(DeleteAll)
            {
                ApplicationArea = All;
                Caption = 'Delete All Entries';
                Image = Delete;
                ToolTip = 'Delete all log entries.';

                trigger OnAction()
                begin
                    if Confirm('Are you sure you want to delete all log entries?') then begin
                        Rec.DeleteAll();
                        Message('All log entries deleted.');
                    end;
                end;
            }
        }
    }
}
