tableextension 50150 "Req Line Vendor Ext" extends "Requisition Line"
{
    fields
    {
        field(50150; "Recommended Vendor No."; Code[20])
        {
            Caption = 'Recommended Vendor No.';
            TableRelation = Vendor;
            Editable = false;
            DataClassification = CustomerContent;
        }
        field(50151; "Recommended Vendor Name"; Text[100])
        {
            Caption = 'Recommended Vendor Name';
            Editable = false;
            DataClassification = CustomerContent;
        }
        field(50152; "Recommended Vendor Score"; Decimal)
        {
            Caption = 'Recommended Vendor Score';
            Editable = false;
            DecimalPlaces = 0 : 2;
            DataClassification = CustomerContent;
        }
        field(50153; "Alt Vendor Available"; Boolean)
        {
            Caption = 'Alt Vendor Available';
            Editable = false;
            DataClassification = CustomerContent;
        }
        field(50154; "Substitute Available"; Boolean)
        {
            Caption = 'Substitute Available';
            Editable = false;
            DataClassification = CustomerContent;
        }
        field(50155; "Substitute Item No."; Code[20])
        {
            Caption = 'Substitute Item No.';
            TableRelation = Item;
            Editable = false;
            DataClassification = CustomerContent;
        }
        field(50156; "Substitute Lead Time Savings"; Integer)
        {
            Caption = 'Substitute Lead Time Savings (Days)';
            Editable = false;
            DataClassification = CustomerContent;
        }
        field(50157; "Recommended Unit Cost"; Decimal)
        {
            Caption = 'Recommended Unit Cost';
            Editable = false;
            DecimalPlaces = 2 : 5;
            DataClassification = CustomerContent;
        }
        field(50158; "Recommended Lead Time"; Integer)
        {
            Caption = 'Recommended Lead Time (Days)';
            Editable = false;
            DataClassification = CustomerContent;
        }
        field(50159; "Recommendation Enriched"; Boolean)
        {
            Caption = 'Recommendation Enriched';
            Editable = false;
            DataClassification = CustomerContent;
        }
    }
}
