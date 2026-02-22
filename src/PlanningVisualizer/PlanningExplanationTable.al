table 50161 "Planning Explanation"
{
    Caption = 'Planning Explanation';
    DataClassification = CustomerContent;
    TableType = Temporary;

    fields
    {
        field(1; "Entry No."; Integer)
        {
            Caption = 'Entry No.';
        }
        field(2; "Req. Line No."; Integer)
        {
            Caption = 'Requisition Line No.';
        }
        field(10; "Item No."; Code[20])
        {
            Caption = 'Item No.';
        }
        field(11; "Action Message"; Text[50])
        {
            Caption = 'Action Message';
        }
        field(12; "Summary Text"; Text[250])
        {
            Caption = 'Summary';
        }
        field(13; "Detail Text"; Text[2048])
        {
            Caption = 'Detail';
        }
        field(14; "Why Text"; Text[500])
        {
            Caption = 'Reason';
        }
        field(15; "Impact Text"; Text[500])
        {
            Caption = 'Impact';
        }
        field(20; "Due Date"; Date)
        {
            Caption = 'Due Date';
        }
        field(21; Quantity; Decimal)
        {
            Caption = 'Quantity';
            DecimalPlaces = 0 : 5;
        }
        field(22; "Reordering Policy"; Text[50])
        {
            Caption = 'Reordering Policy';
        }
        field(23; Severity; Integer)
        {
            Caption = 'Severity';
            MinValue = 1;
            MaxValue = 3;
        }
    }

    keys
    {
        key(PK; "Entry No.")
        {
            Clustered = true;
        }
    }
}
