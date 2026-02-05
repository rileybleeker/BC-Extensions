pageextension 50102 "Prod. Order Line Sub Ext" extends "Prod. Order Line List"
{
    layout
    {
        addafter(Status)
        {
            field("Sync with DB"; Rec."Sync with DB")
            {
                ApplicationArea = All;
                ToolTip = 'Specifies whether to sync with database.';
            }
            field("Upper Tolerance"; Rec."Upper Tolerance")
            {
                ApplicationArea = All;
                ToolTip = 'Specifies the upper tolerance value.';
            }
        }
    }
}
pageextension 50104 "Released Prod. Order Ext" extends "Released Prod. Order Lines"
{
    layout
    {
        addafter("Item No.")
        {
            field("Upper Tolerance"; Rec."Upper Tolerance")
            {
                ApplicationArea = All;
                ToolTip = 'Specifies the upper tolerance value.';
            }
        }
    }
}