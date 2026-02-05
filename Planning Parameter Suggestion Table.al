table 50110 "Planning Parameter Suggestion"
{
    Caption = 'Planning Parameter Suggestion';
    DataClassification = CustomerContent;
    LookupPageId = "Planning Parameter Suggestions";
    DrillDownPageId = "Planning Parameter Suggestions";

    fields
    {
        field(1; "Entry No."; Integer)
        {
            Caption = 'Entry No.';
            AutoIncrement = true;
        }
        field(10; "Item No."; Code[20])
        {
            Caption = 'Item No.';
            TableRelation = Item."No.";
            NotBlank = true;
        }
        field(11; "Variant Code"; Code[10])
        {
            Caption = 'Variant Code';
            TableRelation = "Item Variant".Code where("Item No." = field("Item No."));
        }
        field(12; "Location Code"; Code[10])
        {
            Caption = 'Location Code';
            TableRelation = Location.Code;

            trigger OnValidate()
            begin
                if "Location Code" <> '' then
                    "Target Level" := "Target Level"::SKU
                else
                    "Target Level" := "Target Level"::Item;

                UpdateSKUExists();
            end;
        }
        field(13; "Target Level"; Option)
        {
            Caption = 'Target Level';
            OptionMembers = Item,SKU;
            OptionCaption = 'Item,Stockkeeping Unit';

            trigger OnValidate()
            begin
                if "Target Level" = "Target Level"::SKU then begin
                    if "Location Code" = '' then
                        Error('Location Code is required when Target Level is Stockkeeping Unit.');
                end;
            end;
        }
        field(14; "SKU Exists"; Boolean)
        {
            Caption = 'SKU Exists';
            Editable = false;
        }
        field(15; "Create SKU If Missing"; Boolean)
        {
            Caption = 'Create SKU If Missing';
            InitValue = true;
        }
        field(20; "Suggestion Date"; Date)
        {
            Caption = 'Suggestion Date';
        }
        field(21; "Created DateTime"; DateTime)
        {
            Caption = 'Created DateTime';
        }
        field(30; Status; Enum "Planning Suggestion Status")
        {
            Caption = 'Status';

            trigger OnValidate()
            begin
                if Status in [Status::Approved, Status::Rejected, Status::Applied] then begin
                    "Reviewed By" := CopyStr(UserId(), 1, MaxStrLen("Reviewed By"));
                    "Reviewed DateTime" := CurrentDateTime();
                end;
            end;
        }
        field(31; "Reviewed By"; Code[50])
        {
            Caption = 'Reviewed By';
            Editable = false;
        }
        field(32; "Reviewed DateTime"; DateTime)
        {
            Caption = 'Reviewed DateTime';
            Editable = false;
        }
        field(40; "Current Reordering Policy"; Enum "Reordering Policy")
        {
            Caption = 'Current Reordering Policy';
            Editable = false;
        }
        field(41; "Suggested Reordering Policy"; Enum "Reordering Policy")
        {
            Caption = 'Suggested Reordering Policy';
        }
        field(50; "Current Reorder Point"; Decimal)
        {
            Caption = 'Current Reorder Point';
            DecimalPlaces = 0 : 5;
            Editable = false;
        }
        field(51; "Suggested Reorder Point"; Decimal)
        {
            Caption = 'Suggested Reorder Point';
            DecimalPlaces = 0 : 5;
            MinValue = 0;
        }
        field(60; "Current Reorder Quantity"; Decimal)
        {
            Caption = 'Current Reorder Quantity';
            DecimalPlaces = 0 : 5;
            Editable = false;
        }
        field(61; "Suggested Reorder Quantity"; Decimal)
        {
            Caption = 'Suggested Reorder Quantity';
            DecimalPlaces = 0 : 5;
            MinValue = 0;
        }
        field(70; "Current Safety Stock"; Decimal)
        {
            Caption = 'Current Safety Stock';
            DecimalPlaces = 0 : 5;
            Editable = false;
        }
        field(71; "Suggested Safety Stock"; Decimal)
        {
            Caption = 'Suggested Safety Stock';
            DecimalPlaces = 0 : 5;
            MinValue = 0;
        }
        field(80; "Current Maximum Inventory"; Decimal)
        {
            Caption = 'Current Maximum Inventory';
            DecimalPlaces = 0 : 5;
            Editable = false;
        }
        field(81; "Suggested Maximum Inventory"; Decimal)
        {
            Caption = 'Suggested Maximum Inventory';
            DecimalPlaces = 0 : 5;
            MinValue = 0;
        }
        field(90; "Suggested Lot Accum Period"; DateFormula)
        {
            Caption = 'Suggested Lot Accumulation Period';
        }
        field(91; "Current Lot Accum Period"; DateFormula)
        {
            Caption = 'Current Lot Accumulation Period';
            Editable = false;
        }
        field(100; "Confidence Score"; Decimal)
        {
            Caption = 'Confidence Score';
            DecimalPlaces = 0 : 2;
            MinValue = 0;
            MaxValue = 100;
        }
        field(101; "Demand Variability"; Decimal)
        {
            Caption = 'Demand Variability (StdDev)';
            DecimalPlaces = 0 : 2;
        }
        field(102; "Demand CV Pct"; Decimal)
        {
            Caption = 'Demand CV %';
            DecimalPlaces = 0 : 2;
        }
        field(110; "Data Points Analyzed"; Integer)
        {
            Caption = 'Data Points Analyzed';
        }
        field(111; "Analysis Period Start"; Date)
        {
            Caption = 'Analysis Period Start';
        }
        field(112; "Analysis Period End"; Date)
        {
            Caption = 'Analysis Period End';
        }
        field(121; "Calculation Notes"; Text[2048])
        {
            Caption = 'Calculation Notes';
        }
        field(130; "Error Message"; Text[500])
        {
            Caption = 'Error Message';
        }
        field(140; "Demand Pattern"; Enum "Item Demand Pattern")
        {
            Caption = 'Detected Demand Pattern';
        }
    }

    keys
    {
        key(PK; "Entry No.")
        {
            Clustered = true;
        }
        key(ItemDate; "Item No.", "Suggestion Date")
        {
            // For lookups by item and date
        }
        key(StatusDate; Status, "Created DateTime")
        {
            // For processing queue
        }
        key(ItemStatus; "Item No.", Status)
        {
            // For finding pending suggestions per item
        }
        key(SKUKey; "Item No.", "Location Code", "Variant Code", "Suggestion Date")
        {
            // For SKU-level lookups
        }
        key(TargetLevel; "Target Level", Status)
        {
            // For filtering by Item vs SKU suggestions
        }
    }

    trigger OnInsert()
    begin
        "Created DateTime" := CurrentDateTime();
        "Suggestion Date" := Today();
    end;

    procedure UpdateSKUExists()
    var
        SKU: Record "Stockkeeping Unit";
    begin
        "SKU Exists" := SKU.Get("Location Code", "Item No.", "Variant Code");
    end;

    procedure GetTargetDescription(): Text
    begin
        if "Target Level" = "Target Level"::SKU then
            exit(StrSubstNo('SKU: %1 @ %2', "Item No.", "Location Code"))
        else
            exit(StrSubstNo('Item: %1', "Item No."));
    end;

    procedure LoadCurrentValuesFromSKU()
    var
        SKU: Record "Stockkeeping Unit";
    begin
        if "Target Level" <> "Target Level"::SKU then
            exit;

        if not SKU.Get("Location Code", "Item No.", "Variant Code") then
            exit;

        "Current Reordering Policy" := SKU."Reordering Policy";
        "Current Reorder Point" := SKU."Reorder Point";
        "Current Reorder Quantity" := SKU."Reorder Quantity";
        "Current Safety Stock" := SKU."Safety Stock Quantity";
        "Current Maximum Inventory" := SKU."Maximum Inventory";
        "Current Lot Accum Period" := SKU."Lot Accumulation Period";
    end;

    procedure LoadCurrentValuesFromItem()
    var
        Item: Record Item;
    begin
        if not Item.Get("Item No.") then
            exit;

        "Current Reordering Policy" := Item."Reordering Policy";
        "Current Reorder Point" := Item."Reorder Point";
        "Current Reorder Quantity" := Item."Reorder Quantity";
        "Current Safety Stock" := Item."Safety Stock Quantity";
        "Current Maximum Inventory" := Item."Maximum Inventory";
        "Current Lot Accum Period" := Item."Lot Accumulation Period";
    end;
}
