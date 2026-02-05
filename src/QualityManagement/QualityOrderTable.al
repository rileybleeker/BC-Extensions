table 50100 "Quality Order"
{
    DataClassification = ToBeClassified;
    Caption = 'Quality Order';

    fields
    {
        field(1; "Entry No."; Integer)
        {
            Caption = 'Entry No.';
            AutoIncrement = true;
            DataClassification = ToBeClassified;
        }
        field(10; "Item No."; Code[20])
        {
            Caption = 'Item No.';
            TableRelation = Item;
            DataClassification = ToBeClassified;
        }
        field(11; "Lot No."; Code[50])
        {
            Caption = 'Lot No.';
            DataClassification = ToBeClassified;
        }
        field(20; "Test Status"; Enum "Quality Test Status")
        {
            Caption = 'Test Status';
            DataClassification = ToBeClassified;
            InitValue = Pending;

            trigger OnValidate()
            var
                ItemLedgerEntry: Record "Item Ledger Entry";
            begin
                // Update Tested Date and Tested By when status changes from Pending
                if xRec."Test Status" = xRec."Test Status"::Pending then begin
                    Rec."Tested Date" := Today;
                    Rec."Tested By" := UserId;
                end;
            end;
        }
        field(30; "Item Ledger Entry No."; Integer)
        {
            Caption = 'Item Ledger Entry No.';
            TableRelation = "Item Ledger Entry";
            DataClassification = ToBeClassified;
        }
        field(51; "Created Date"; Date)
        {
            Caption = 'Created Date';
            DataClassification = ToBeClassified;
            Editable = false;
        }
        field(41; "Tested Date"; Date)
        {
            Caption = 'Tested Date';
            DataClassification = ToBeClassified;
            Editable = false;
        }
        field(50; "Tested By"; Code[50])
        {
            Caption = 'Tested By';
            DataClassification = ToBeClassified;
            Editable = false;
        }
    }

    keys
    {
        key(PK; "Entry No.")
        {
            Clustered = true;
        }
        key(LotKey; "Item No.", "Lot No.")
        {
        }
    }
}
