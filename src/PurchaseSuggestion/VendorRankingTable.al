table 50151 "Vendor Ranking"
{
    Caption = 'Vendor Ranking';
    DataClassification = CustomerContent;
    TableType = Temporary;

    fields
    {
        field(1; "Rank No."; Integer)
        {
            Caption = 'Rank No.';
        }
        field(2; "Vendor No."; Code[20])
        {
            Caption = 'Vendor No.';
            TableRelation = Vendor;
        }
        field(3; "Item No."; Code[20])
        {
            Caption = 'Item No.';
            TableRelation = Item;
        }
        field(10; "Overall Score"; Decimal)
        {
            Caption = 'Overall Score';
            DecimalPlaces = 0 : 2;
        }
        field(11; "Performance Score"; Decimal)
        {
            Caption = 'Performance Score';
            DecimalPlaces = 0 : 2;
        }
        field(12; "Lead Time Score"; Decimal)
        {
            Caption = 'Lead Time Score';
            DecimalPlaces = 0 : 2;
        }
        field(13; "Price Score"; Decimal)
        {
            Caption = 'Price Score';
            DecimalPlaces = 0 : 2;
        }
        field(20; "Unit Cost"; Decimal)
        {
            Caption = 'Unit Cost';
            DecimalPlaces = 2 : 5;
        }
        field(21; "Lead Time Days"; Integer)
        {
            Caption = 'Lead Time (Days)';
        }
        field(22; "Expected Date"; Date)
        {
            Caption = 'Expected Date';
        }
        field(23; "Can Meet Date"; Boolean)
        {
            Caption = 'Can Meet Date';
        }
        field(24; "Vendor Name"; Text[100])
        {
            Caption = 'Vendor Name';
        }
    }

    keys
    {
        key(PK; "Rank No.")
        {
            Clustered = true;
        }
        key(ByScore; "Overall Score")
        {
        }
        key(ByVendor; "Vendor No.")
        {
        }
    }

    procedure GetVendorName(): Text[100]
    var
        Vendor: Record Vendor;
    begin
        if Vendor.Get("Vendor No.") then
            exit(Vendor.Name);
        exit('');
    end;
}
