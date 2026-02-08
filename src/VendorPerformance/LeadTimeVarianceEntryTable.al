table 50121 "Lead Time Variance Entry"
{
    Caption = 'Lead Time Variance Entry';
    DataClassification = CustomerContent;
    LookupPageId = "Lead Time Variance Entries";
    DrillDownPageId = "Lead Time Variance Entries";

    fields
    {
        field(1; "Entry No."; Integer)
        {
            Caption = 'Entry No.';
        }
        field(2; "Vendor No."; Code[20])
        {
            Caption = 'Vendor No.';
            TableRelation = Vendor;
            NotBlank = true;
        }
        field(3; "Item No."; Code[20])
        {
            Caption = 'Item No.';
            TableRelation = Item;
        }
        field(4; "Variant Code"; Code[10])
        {
            Caption = 'Variant Code';
            TableRelation = "Item Variant".Code where("Item No." = field("Item No."));
        }
        field(5; "Purchase Order No."; Code[20])
        {
            Caption = 'Purchase Order No.';
        }
        field(6; "Purchase Order Line No."; Integer)
        {
            Caption = 'Purchase Order Line No.';
        }
        field(7; "Posted Receipt No."; Code[20])
        {
            Caption = 'Posted Receipt No.';
        }
        field(10; "Order Date"; Date)
        {
            Caption = 'Order Date';
        }
        field(11; "Promised Receipt Date"; Date)
        {
            Caption = 'Promised Receipt Date';
        }
        field(12; "Actual Receipt Date"; Date)
        {
            Caption = 'Actual Receipt Date';
        }
        field(20; "Promised Lead Time Days"; Integer)
        {
            Caption = 'Promised Lead Time (Days)';
            Editable = false;
        }
        field(21; "Actual Lead Time Days"; Integer)
        {
            Caption = 'Actual Lead Time (Days)';
            Editable = false;
        }
        field(22; "Variance Days"; Integer)
        {
            Caption = 'Variance (Days)';
            Editable = false;
        }
        field(23; "On Time"; Boolean)
        {
            Caption = 'On Time';
            Editable = false;
        }
        field(24; "Delivery Status"; Enum "Delivery Status")
        {
            Caption = 'Delivery Status';
            Editable = false;
        }
        field(25; "Variance %"; Decimal)
        {
            Caption = 'Variance %';
            Editable = false;
            DecimalPlaces = 2 : 2;
        }
        field(26; "Within LT Tolerance"; Boolean)
        {
            Caption = 'Within LT Tolerance';
            Editable = false;
        }
        field(30; "Receipt Qty"; Decimal)
        {
            Caption = 'Receipt Qty';
            DecimalPlaces = 0 : 5;
        }
        field(31; "Unit of Measure Code"; Code[10])
        {
            Caption = 'Unit of Measure Code';
            TableRelation = "Item Unit of Measure".Code where("Item No." = field("Item No."));
        }
        field(40; "Location Code"; Code[10])
        {
            Caption = 'Location Code';
            TableRelation = Location;
        }
        field(50; "Created DateTime"; DateTime)
        {
            Caption = 'Created DateTime';
            Editable = false;
        }
    }

    keys
    {
        key(PK; "Entry No.")
        {
            Clustered = true;
        }
        key(ByVendor; "Vendor No.", "Actual Receipt Date")
        {
        }
        key(ByItem; "Item No.", "Vendor No.", "Actual Receipt Date")
        {
        }
        key(ByPO; "Purchase Order No.", "Purchase Order Line No.")
        {
        }
        key(ByReceiptDate; "Actual Receipt Date", "Vendor No.")
        {
        }
    }

    trigger OnInsert()
    begin
        "Created DateTime" := CurrentDateTime;
        CalculateVariance();
    end;

    local procedure CalculateVariance()
    var
        MfgSetup: Record "Manufacturing Setup";
        ToleranceDays: Integer;
    begin
        // Calculate lead times
        if ("Order Date" <> 0D) and ("Promised Receipt Date" <> 0D) then
            "Promised Lead Time Days" := "Promised Receipt Date" - "Order Date";

        if ("Order Date" <> 0D) and ("Actual Receipt Date" <> 0D) then
            "Actual Lead Time Days" := "Actual Receipt Date" - "Order Date";

        // Calculate variance (positive = late, negative = early)
        if ("Promised Receipt Date" <> 0D) and ("Actual Receipt Date" <> 0D) then
            "Variance Days" := "Actual Receipt Date" - "Promised Receipt Date";

        // Determine on-time status
        MfgSetup.Get();
        ToleranceDays := MfgSetup."On-Time Tolerance Days";
        "On Time" := Abs("Variance Days") <= ToleranceDays;

        // Set delivery status
        if "Variance Days" < -ToleranceDays then
            "Delivery Status" := "Delivery Status"::Early
        else if "Variance Days" > ToleranceDays then
            "Delivery Status" := "Delivery Status"::Late
        else
            "Delivery Status" := "Delivery Status"::"On Time";

        // Calculate Lead Time Reliability fields (percentage-based tolerance)
        // Treat 0 lead time as 1 day to avoid division by zero while keeping entries in calculation
        if "Promised Lead Time Days" > 0 then
            "Variance %" := Round(Abs("Variance Days") / "Promised Lead Time Days" * 100, 0.01)
        else
            "Variance %" := Round(Abs("Variance Days") / 1 * 100, 0.01); // Treat 0 as 1 day

        "Within LT Tolerance" := "Variance %" <= MfgSetup."Lead Time Variance Tolerance %";
    end;

    procedure GetVendorName(): Text[100]
    var
        Vendor: Record Vendor;
    begin
        if Vendor.Get("Vendor No.") then
            exit(Vendor.Name);
        exit('');
    end;

    procedure GetItemDescription(): Text[100]
    var
        Item: Record Item;
    begin
        if Item.Get("Item No.") then
            exit(Item.Description);
        exit('');
    end;
}
