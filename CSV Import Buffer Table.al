table 50102 "CSV Import Buffer"
{
    TableType = Temporary;
    Caption = 'CSV Import Buffer';
    DataClassification = ToBeClassified;

    fields
    {
        field(1; "Line No."; Integer)
        {
            Caption = 'Line No.';
            DataClassification = ToBeClassified;
        }
        field(10; "Color"; Text[50])
        {
            Caption = 'Color';
            DataClassification = ToBeClassified;
        }
        field(20; "Size"; Text[50])
        {
            Caption = 'Size';
            DataClassification = ToBeClassified;
        }
        field(30; "Quantity"; Decimal)
        {
            Caption = 'Quantity';
            DataClassification = ToBeClassified;
        }
        field(40; "Item No."; Code[20])
        {
            Caption = 'Item No.';
            DataClassification = ToBeClassified;
        }
        field(50; "Validation Error"; Text[250])
        {
            Caption = 'Validation Error';
            DataClassification = ToBeClassified;
        }
    }

    keys
    {
        key(PK; "Line No.")
        {
            Clustered = true;
        }
    }
}
