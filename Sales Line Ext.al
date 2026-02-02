/* tableextension 50103 "Sales Line Ext" extends "Sales Line"
{
    fields
    {
        modify(Quantity)
        {
            trigger OnAfterValidate()
            begin
                Message('You modified Sales Line: Document No. %1, Line No. %2', Rec."Document No.", Rec."Line No.");
            end;
        }
    }
} */
