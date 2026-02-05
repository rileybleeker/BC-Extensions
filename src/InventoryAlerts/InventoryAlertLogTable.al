table 50101 "Inventory Alert Log"
{
    DataClassification = SystemMetadata;
    Caption = 'Inventory Alert Log';

    fields
    {
        field(1; "Entry No."; Integer)
        {
            Caption = 'Entry No.';
            AutoIncrement = true;
            DataClassification = SystemMetadata;
        }
        field(10; "Item Ledger Entry No."; Integer)
        {
            Caption = 'Item Ledger Entry No.';
            TableRelation = "Item Ledger Entry";
            DataClassification = SystemMetadata;
        }
        field(20; "Item No."; Code[20])
        {
            Caption = 'Item No.';
            TableRelation = Item;
            DataClassification = SystemMetadata;
        }
        field(30; "Location Code"; Code[10])
        {
            Caption = 'Location Code';
            TableRelation = Location;
            DataClassification = SystemMetadata;
        }
        field(40; "Current Inventory"; Decimal)
        {
            Caption = 'Current Inventory';
            DataClassification = SystemMetadata;
        }
        field(50; "Safety Stock"; Decimal)
        {
            Caption = 'Safety Stock';
            DataClassification = SystemMetadata;
        }
        field(60; "Alert Timestamp"; DateTime)
        {
            Caption = 'Alert Timestamp';
            DataClassification = SystemMetadata;
        }
        field(70; "Alert Status"; Option)
        {
            Caption = 'Alert Status';
            OptionMembers = Success,Failed;
            OptionCaption = 'Success,Failed';
            DataClassification = SystemMetadata;
        }
        field(80; "Error Message"; Text[250])
        {
            Caption = 'Error Message';
            DataClassification = SystemMetadata;
        }
    }

    keys
    {
        key(PK; "Entry No.")
        {
            Clustered = true;
        }
        key(ItemLocation; "Item No.", "Location Code", "Alert Timestamp")
        {
        }
    }
}
