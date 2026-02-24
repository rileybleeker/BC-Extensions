table 50160 "Visualizer Event Buffer"
{
    Caption = 'Visualizer Event Buffer';
    DataClassification = CustomerContent;
    TableType = Temporary;

    fields
    {
        field(1; "Entry No."; Integer)
        {
            Caption = 'Entry No.';
        }
        field(2; "Item No."; Code[20])
        {
            Caption = 'Item No.';
        }
        field(3; "Location Code"; Code[10])
        {
            Caption = 'Location Code';
        }
        field(4; "Variant Code"; Code[10])
        {
            Caption = 'Variant Code';
        }
        field(10; "Event Date"; Date)
        {
            Caption = 'Event Date';
        }
        field(11; "Event Type"; Enum "Inventory Event Type")
        {
            Caption = 'Event Type';
        }
        field(12; Quantity; Decimal)
        {
            Caption = 'Quantity';
            DecimalPlaces = 0 : 5;
        }
        field(13; "Running Total Before"; Decimal)
        {
            Caption = 'Running Total (Projected Available Balance)';
            DecimalPlaces = 0 : 5;
            Editable = false;
        }
        field(14; "Running Total After"; Decimal)
        {
            Caption = 'Running Total (Suggested Projected Inventory)';
            DecimalPlaces = 0 : 5;
            Editable = false;
        }
        field(15; "Is Suggestion"; Boolean)
        {
            Caption = 'Is Planning Suggestion';
        }
        field(16; "Running Total Forecasted"; Decimal)
        {
            Caption = 'Running Total (Forecasted Projected Inventory)';
            DecimalPlaces = 0 : 5;
            Editable = false;
        }
        field(20; "Source Document Type"; Integer)
        {
            Caption = 'Source Document Type';
        }
        field(21; "Source Document No."; Code[20])
        {
            Caption = 'Source Document No.';
        }
        field(22; "Source Line No."; Integer)
        {
            Caption = 'Source Line No.';
        }
        field(23; "Source Description"; Text[100])
        {
            Caption = 'Source Description';
        }
        field(24; "Source Page ID"; Integer)
        {
            Caption = 'Source Page ID';
        }
        field(30; "Is Supply"; Boolean)
        {
            Caption = 'Is Supply';
        }
        field(31; "Action Message"; Text[50])
        {
            Caption = 'Action Message';
        }
        field(32; "Original Qty"; Decimal)
        {
            Caption = 'Original Quantity';
            DecimalPlaces = 0 : 5;
        }
        field(33; "Original Date"; Date)
        {
            Caption = 'Original Date';
        }
        field(35; "Is Informational"; Boolean)
        {
            Caption = 'Is Informational';
        }
        field(40; "Tracking Entry No."; Integer)
        {
            Caption = 'Tracking Entry No.';
        }
        field(41; "Tracked Against Entry No."; Integer)
        {
            Caption = 'Tracked Against Entry No.';
        }
    }

    keys
    {
        key(PK; "Entry No.")
        {
            Clustered = true;
        }
        key(ByDate; "Event Date", "Entry No.") { }
    }
}
