table 50111 "Demand History Staging"
{
    Caption = 'Demand History Staging';
    DataClassification = CustomerContent;
    TableType = Temporary;

    fields
    {
        field(1; "Item No."; Code[20])
        {
            Caption = 'Item No.';
        }
        field(2; "Demand Date"; Date)
        {
            Caption = 'Demand Date';
        }
        field(3; "Source Type"; Enum "Demand Source Type")
        {
            Caption = 'Source Type';
        }
        field(4; "Source No."; Code[20])
        {
            Caption = 'Source No.';
        }
        field(10; Quantity; Decimal)
        {
            Caption = 'Quantity';
            DecimalPlaces = 0 : 5;
        }
        field(11; "Location Code"; Code[10])
        {
            Caption = 'Location Code';
        }
        field(12; "Variant Code"; Code[10])
        {
            Caption = 'Variant Code';
        }
        field(20; "Unit Cost"; Decimal)
        {
            Caption = 'Unit Cost';
            DecimalPlaces = 2 : 5;
        }
        field(21; "Unit Price"; Decimal)
        {
            Caption = 'Unit Price';
            DecimalPlaces = 2 : 5;
        }
    }

    keys
    {
        key(PK; "Item No.", "Demand Date", "Source Type", "Source No.")
        {
            Clustered = true;
        }
        key(DateSort; "Item No.", "Demand Date")
        {
            // For demand analysis data preparation
        }
    }
}
