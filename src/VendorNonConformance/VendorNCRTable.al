table 50130 "Vendor NCR"
{
    Caption = 'Vendor Non-Conformance Report';
    DataClassification = CustomerContent;
    LookupPageId = "Vendor NCR List";
    DrillDownPageId = "Vendor NCR List";

    fields
    {
        field(1; "NCR No."; Code[20])
        {
            Caption = 'NCR No.';
            Editable = false;
        }
        field(2; "Vendor No."; Code[20])
        {
            Caption = 'Vendor No.';
            TableRelation = Vendor;
            NotBlank = true;

            trigger OnValidate()
            var
                Vendor: Record Vendor;
            begin
                if Vendor.Get("Vendor No.") then
                    "Vendor Name" := Vendor.Name;
            end;
        }
        field(3; "Vendor Name"; Text[100])
        {
            Caption = 'Vendor Name';
            Editable = false;
        }
        field(4; "Item No."; Code[20])
        {
            Caption = 'Item No.';
            TableRelation = Item;

            trigger OnValidate()
            var
                Item: Record Item;
            begin
                if Item.Get("Item No.") then
                    "Item Description" := Item.Description;
            end;
        }
        field(5; "Item Description"; Text[100])
        {
            Caption = 'Item Description';
            Editable = false;
        }
        field(6; "Variant Code"; Code[10])
        {
            Caption = 'Variant Code';
            TableRelation = "Item Variant".Code where("Item No." = field("Item No."));
        }
        field(10; "Purchase Order No."; Code[20])
        {
            Caption = 'Purchase Order No.';
        }
        field(11; "Purchase Order Line No."; Integer)
        {
            Caption = 'Purchase Order Line No.';
        }
        field(12; "Posted Receipt No."; Code[20])
        {
            Caption = 'Posted Receipt No.';
        }
        field(13; "Lot No."; Code[50])
        {
            Caption = 'Lot No.';
        }
        field(14; "Serial No."; Code[50])
        {
            Caption = 'Serial No.';
        }
        field(20; "NCR Date"; Date)
        {
            Caption = 'NCR Date';
            NotBlank = true;
        }
        field(21; "Category"; Enum "NCR Category")
        {
            Caption = 'Category';
        }
        field(22; "Description"; Text[250])
        {
            Caption = 'Description';
        }
        field(23; "Detailed Description"; Blob)
        {
            Caption = 'Detailed Description';
            Subtype = Memo;
        }
        field(30; "Affected Qty"; Decimal)
        {
            Caption = 'Affected Qty';
            DecimalPlaces = 0 : 5;
            MinValue = 0;
        }
        field(31; "Unit of Measure Code"; Code[10])
        {
            Caption = 'Unit of Measure Code';
            TableRelation = "Item Unit of Measure".Code where("Item No." = field("Item No."));
        }
        field(32; "Receipt Qty"; Decimal)
        {
            Caption = 'Receipt Qty';
            DecimalPlaces = 0 : 5;
            Editable = false;
        }
        field(40; "Disposition"; Enum "NCR Disposition")
        {
            Caption = 'Disposition';
        }
        field(41; "Cost Impact"; Decimal)
        {
            Caption = 'Cost Impact';
            DecimalPlaces = 2 : 2;
        }
        field(42; "Cost Impact Currency"; Code[10])
        {
            Caption = 'Cost Impact Currency';
            TableRelation = Currency;
        }
        field(50; "Root Cause"; Text[500])
        {
            Caption = 'Root Cause';
        }
        field(51; "Corrective Action"; Text[500])
        {
            Caption = 'Corrective Action';
        }
        field(52; "Preventive Action"; Text[500])
        {
            Caption = 'Preventive Action';
        }
        field(60; "Status"; Enum "NCR Status")
        {
            Caption = 'Status';

            trigger OnValidate()
            begin
                if "Status" = "Status"::Closed then begin
                    "Closed Date" := Today;
                    "Closed By" := CopyStr(UserId, 1, MaxStrLen("Closed By"));
                end else begin
                    "Closed Date" := 0D;
                    "Closed By" := '';
                end;
            end;
        }
        field(61; "Priority"; Option)
        {
            Caption = 'Priority';
            OptionMembers = "Low","Medium","High","Critical";
            OptionCaption = 'Low,Medium,High,Critical';
        }
        field(70; "Created By"; Code[50])
        {
            Caption = 'Created By';
            Editable = false;
        }
        field(71; "Created DateTime"; DateTime)
        {
            Caption = 'Created DateTime';
            Editable = false;
        }
        field(72; "Closed Date"; Date)
        {
            Caption = 'Closed Date';
            Editable = false;
        }
        field(73; "Closed By"; Code[50])
        {
            Caption = 'Closed By';
            Editable = false;
        }
        field(80; "Quality Order Entry No."; Integer)
        {
            Caption = 'Quality Order Entry No.';
            TableRelation = "Quality Order"."Entry No.";
        }
        field(81; "Item Ledger Entry No."; Integer)
        {
            Caption = 'Item Ledger Entry No.';
            TableRelation = "Item Ledger Entry"."Entry No.";
        }
        field(90; "Location Code"; Code[10])
        {
            Caption = 'Location Code';
            TableRelation = Location;
        }
    }

    keys
    {
        key(PK; "NCR No.")
        {
            Clustered = true;
        }
        key(ByVendor; "Vendor No.", "NCR Date")
        {
            SumIndexFields = "Cost Impact", "Affected Qty";
        }
        key(ByItem; "Item No.", "Vendor No.", "NCR Date")
        {
            SumIndexFields = "Affected Qty";
        }
        key(ByStatus; "Status", "NCR Date")
        {
        }
        key(ByPriority; "Priority", "Status", "NCR Date")
        {
        }
    }

    trigger OnInsert()
    var
        MfgSetup: Record "Manufacturing Setup";
        NoSeries: Codeunit "No. Series";
    begin
        if "NCR No." = '' then begin
            MfgSetup.Get();
            MfgSetup.TestField("NCR No. Series");
            "NCR No." := NoSeries.GetNextNo(MfgSetup."NCR No. Series");
        end;

        "Created By" := CopyStr(UserId, 1, MaxStrLen("Created By"));
        "Created DateTime" := CurrentDateTime;

        if "NCR Date" = 0D then
            "NCR Date" := Today;
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

    procedure SetDetailedDescription(NewDescription: Text)
    var
        OutStream: OutStream;
    begin
        Clear("Detailed Description");
        "Detailed Description".CreateOutStream(OutStream, TextEncoding::UTF8);
        OutStream.WriteText(NewDescription);
        Modify();
    end;

    procedure GetDetailedDescription(): Text
    var
        InStream: InStream;
        Description: Text;
    begin
        CalcFields("Detailed Description");
        if not "Detailed Description".HasValue then
            exit('');

        "Detailed Description".CreateInStream(InStream, TextEncoding::UTF8);
        InStream.ReadText(Description);
        exit(Description);
    end;
}
