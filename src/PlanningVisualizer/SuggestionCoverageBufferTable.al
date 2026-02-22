table 50162 "Suggestion Coverage Buffer"
{
    Caption = 'Suggestion Coverage Buffer';
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
        field(10; "Supply Date"; Date)
        {
            Caption = 'Supply Date';
        }
        field(11; "Supply Qty"; Decimal)
        {
            Caption = 'Supply Quantity';
            DecimalPlaces = 0 : 5;
        }
        field(12; "Action Message"; Text[50])
        {
            Caption = 'Action Message';
        }
        field(13; "Order Starting Date"; Date)
        {
            Caption = 'Order Starting Date';
        }
        field(14; "Order Ending Date"; Date)
        {
            Caption = 'Order Ending Date';
        }
        field(20; "Demand Date"; Date)
        {
            Caption = 'Demand Date';
        }
        field(21; "Demand Qty"; Decimal)
        {
            Caption = 'Demand Quantity';
            DecimalPlaces = 0 : 5;
        }
        field(22; "Demand Source"; Text[100])
        {
            Caption = 'Demand Source';
        }
        field(23; "Is Untracked"; Boolean)
        {
            Caption = 'Is Untracked Element';
        }
        field(24; "Untracked Source"; Text[100])
        {
            Caption = 'Untracked Source';
        }
    }

    keys
    {
        key(PK; "Entry No.")
        {
            Clustered = true;
        }
        key(ByReqLine; "Req. Line No.", "Demand Date") { }
    }
}
