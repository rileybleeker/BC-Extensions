table 50150 "Purchase Suggestion"
{
    Caption = 'Purchase Suggestion';
    DataClassification = CustomerContent;
    LookupPageId = "Purchase Suggestion List";
    DrillDownPageId = "Purchase Suggestion List";

    fields
    {
        field(1; "Entry No."; Integer)
        {
            Caption = 'Entry No.';
            AutoIncrement = true;
        }
        field(2; "Item No."; Code[20])
        {
            Caption = 'Item No.';
            TableRelation = Item;
            NotBlank = true;

            trigger OnValidate()
            var
                Item: Record Item;
            begin
                if Item.Get("Item No.") then begin
                    "Item Description" := Item.Description;
                    "Unit of Measure" := Item."Base Unit of Measure";
                end;
            end;
        }
        field(3; "Item Description"; Text[100])
        {
            Caption = 'Item Description';
            Editable = false;
        }
        field(4; "Variant Code"; Code[10])
        {
            Caption = 'Variant Code';
            TableRelation = "Item Variant".Code where("Item No." = field("Item No."));
        }
        field(5; "Location Code"; Code[10])
        {
            Caption = 'Location Code';
            TableRelation = Location;
        }
        field(6; "Suggestion Date"; Date)
        {
            Caption = 'Suggestion Date';
        }

        // What to buy
        field(10; "Suggested Qty"; Decimal)
        {
            Caption = 'Suggested Qty';
            DecimalPlaces = 0 : 5;
            MinValue = 0;
        }
        field(11; "Unit of Measure"; Code[10])
        {
            Caption = 'Unit of Measure';
            TableRelation = "Item Unit of Measure".Code where("Item No." = field("Item No."));
        }
        field(12; "Required Date"; Date)
        {
            Caption = 'Required Date';
        }

        // Vendor 1
        field(20; "Vendor 1 No."; Code[20])
        {
            Caption = 'Vendor 1 No.';
            TableRelation = Vendor;
        }
        field(21; "Vendor 1 Name"; Text[100])
        {
            Caption = 'Vendor 1 Name';
            Editable = false;
        }
        field(22; "Vendor 1 Unit Cost"; Decimal)
        {
            Caption = 'Vendor 1 Unit Cost';
            DecimalPlaces = 2 : 5;
            Editable = false;
        }
        field(23; "Vendor 1 Lead Time"; Integer)
        {
            Caption = 'Vendor 1 Lead Time (Days)';
            Editable = false;
        }
        field(24; "Vendor 1 Score"; Decimal)
        {
            Caption = 'Vendor 1 Score';
            DecimalPlaces = 0 : 2;
            Editable = false;
        }
        field(25; "Vendor 1 Expected Date"; Date)
        {
            Caption = 'Vendor 1 Expected Date';
            Editable = false;
        }

        // Vendor 2
        field(30; "Vendor 2 No."; Code[20])
        {
            Caption = 'Vendor 2 No.';
            TableRelation = Vendor;
        }
        field(31; "Vendor 2 Name"; Text[100])
        {
            Caption = 'Vendor 2 Name';
            Editable = false;
        }
        field(32; "Vendor 2 Unit Cost"; Decimal)
        {
            Caption = 'Vendor 2 Unit Cost';
            DecimalPlaces = 2 : 5;
            Editable = false;
        }
        field(33; "Vendor 2 Lead Time"; Integer)
        {
            Caption = 'Vendor 2 Lead Time (Days)';
            Editable = false;
        }
        field(34; "Vendor 2 Score"; Decimal)
        {
            Caption = 'Vendor 2 Score';
            DecimalPlaces = 0 : 2;
            Editable = false;
        }
        field(35; "Vendor 2 Expected Date"; Date)
        {
            Caption = 'Vendor 2 Expected Date';
            Editable = false;
        }

        // Vendor 3
        field(40; "Vendor 3 No."; Code[20])
        {
            Caption = 'Vendor 3 No.';
            TableRelation = Vendor;
        }
        field(41; "Vendor 3 Name"; Text[100])
        {
            Caption = 'Vendor 3 Name';
            Editable = false;
        }
        field(42; "Vendor 3 Unit Cost"; Decimal)
        {
            Caption = 'Vendor 3 Unit Cost';
            DecimalPlaces = 2 : 5;
            Editable = false;
        }
        field(43; "Vendor 3 Lead Time"; Integer)
        {
            Caption = 'Vendor 3 Lead Time (Days)';
            Editable = false;
        }
        field(44; "Vendor 3 Score"; Decimal)
        {
            Caption = 'Vendor 3 Score';
            DecimalPlaces = 0 : 2;
            Editable = false;
        }
        field(45; "Vendor 3 Expected Date"; Date)
        {
            Caption = 'Vendor 3 Expected Date';
            Editable = false;
        }

        // Recommendation
        field(50; "Recommended Vendor No."; Code[20])
        {
            Caption = 'Recommended Vendor No.';
            TableRelation = Vendor;
            Editable = false;
        }
        field(51; "Recommended Vendor Name"; Text[100])
        {
            Caption = 'Recommended Vendor Name';
            Editable = false;
        }
        field(52; "Recommendation Reason"; Text[500])
        {
            Caption = 'Recommendation Reason';
            Editable = false;
        }
        field(53; "Alternative Available"; Boolean)
        {
            Caption = 'Alternative Vendor Available';
            Editable = false;
        }

        // Substitution Option
        field(60; "Substitute Item Available"; Boolean)
        {
            Caption = 'Substitute Item Available';
            Editable = false;
        }
        field(61; "Substitute Item No."; Code[20])
        {
            Caption = 'Substitute Item No.';
            TableRelation = Item;
            Editable = false;
        }
        field(62; "Substitute Lead Time Savings"; Integer)
        {
            Caption = 'Substitute Lead Time Savings (Days)';
            Editable = false;
        }

        // Status & Actions
        field(70; "Status"; Enum "Purchase Suggestion Status")
        {
            Caption = 'Status';
        }
        field(71; "Selected Vendor No."; Code[20])
        {
            Caption = 'Selected Vendor No.';
            TableRelation = Vendor;

            trigger OnValidate()
            var
                Vendor: Record Vendor;
            begin
                if Vendor.Get("Selected Vendor No.") then
                    "Selected Vendor Name" := Vendor.Name;
            end;
        }
        field(72; "Selected Vendor Name"; Text[100])
        {
            Caption = 'Selected Vendor Name';
            Editable = false;
        }
        field(73; "Purchase Order No."; Code[20])
        {
            Caption = 'Purchase Order No.';
            Editable = false;
        }
        field(74; "Rejection Reason"; Text[250])
        {
            Caption = 'Rejection Reason';
        }

        // Audit
        field(80; "Created By"; Code[50])
        {
            Caption = 'Created By';
            Editable = false;
        }
        field(81; "Created DateTime"; DateTime)
        {
            Caption = 'Created DateTime';
            Editable = false;
        }
        field(82; "Approved By"; Code[50])
        {
            Caption = 'Approved By';
            Editable = false;
        }
        field(83; "Approved DateTime"; DateTime)
        {
            Caption = 'Approved DateTime';
            Editable = false;
        }

        // Source references
        field(90; "Planning Suggestion Entry No."; Integer)
        {
            Caption = 'Planning Suggestion Entry No.';
        }
        field(91; "Requisition Worksheet Template"; Code[10])
        {
            Caption = 'Requisition Worksheet Template';
        }
        field(92; "Requisition Worksheet Batch"; Code[10])
        {
            Caption = 'Requisition Worksheet Batch';
        }
        field(93; "Requisition Line No."; Integer)
        {
            Caption = 'Requisition Line No.';
        }

        // Consolidation
        field(95; "Consolidation Group"; Code[20])
        {
            Caption = 'Consolidation Group';
        }
    }

    keys
    {
        key(PK; "Entry No.")
        {
            Clustered = true;
        }
        key(ByItem; "Item No.", "Location Code", "Status")
        {
        }
        key(ByVendor; "Recommended Vendor No.", "Status")
        {
        }
        key(ByStatus; "Status", "Suggestion Date")
        {
        }
        key(ByRequiredDate; "Required Date", "Status")
        {
        }
        key(ByConsolidation; "Consolidation Group", "Selected Vendor No.")
        {
        }
    }

    trigger OnInsert()
    begin
        "Created By" := CopyStr(UserId, 1, MaxStrLen("Created By"));
        "Created DateTime" := CurrentDateTime;
        if "Suggestion Date" = 0D then
            "Suggestion Date" := Today;
    end;

    procedure GetTotalCost(): Decimal
    begin
        case true of
            "Selected Vendor No." = "Vendor 1 No.":
                exit("Vendor 1 Unit Cost" * "Suggested Qty");
            "Selected Vendor No." = "Vendor 2 No.":
                exit("Vendor 2 Unit Cost" * "Suggested Qty");
            "Selected Vendor No." = "Vendor 3 No.":
                exit("Vendor 3 Unit Cost" * "Suggested Qty");
            else
                exit("Vendor 1 Unit Cost" * "Suggested Qty");
        end;
    end;

    procedure GetExpectedDate(): Date
    begin
        case true of
            "Selected Vendor No." = "Vendor 1 No.":
                exit("Vendor 1 Expected Date");
            "Selected Vendor No." = "Vendor 2 No.":
                exit("Vendor 2 Expected Date");
            "Selected Vendor No." = "Vendor 3 No.":
                exit("Vendor 3 Expected Date");
            else
                exit("Vendor 1 Expected Date");
        end;
    end;
}
