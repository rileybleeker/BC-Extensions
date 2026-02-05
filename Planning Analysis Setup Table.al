table 50113 "Planning Analysis Setup"
{
    Caption = 'Planning Analysis Setup';
    DataClassification = CustomerContent;

    fields
    {
        field(1; "Primary Key"; Code[10])
        {
            Caption = 'Primary Key';
        }
        field(20; "Default Analysis Months"; Integer)
        {
            Caption = 'Default Analysis Months';
            InitValue = 24;
            MinValue = 3;
            MaxValue = 60;
        }
        field(21; "Minimum Data Points"; Integer)
        {
            Caption = 'Minimum Data Points';
            InitValue = 30;
            MinValue = 10;
            MaxValue = 365;
        }
        field(22; "Forecast Periods Days"; Integer)
        {
            Caption = 'Forecast Periods (Days)';
            InitValue = 90;
            MinValue = 7;
            MaxValue = 365;
        }
        field(30; "Safety Stock Multiplier"; Decimal)
        {
            Caption = 'Safety Stock Z-Score';
            InitValue = 1.65;
            MinValue = 1;
            MaxValue = 4;
            DecimalPlaces = 2 : 2;
        }
        field(31; "Service Level Target"; Decimal)
        {
            Caption = 'Service Level Target %';
            InitValue = 95;
            MinValue = 80;
            MaxValue = 99.9;
            DecimalPlaces = 1 : 1;

            trigger OnValidate()
            begin
                "Safety Stock Multiplier" := GetZScoreForServiceLevel("Service Level Target");
            end;
        }
        field(32; "Lead Time Days Default"; Integer)
        {
            Caption = 'Default Lead Time (Days)';
            InitValue = 7;
            MinValue = 1;
            MaxValue = 365;
        }
        field(40; "Auto Apply Threshold"; Decimal)
        {
            Caption = 'Auto-Apply Confidence Threshold %';
            InitValue = 90;
            MinValue = 0;
            MaxValue = 100;
            DecimalPlaces = 0 : 0;
        }
        field(41; "Require Approval Below"; Decimal)
        {
            Caption = 'Require Approval Below %';
            InitValue = 75;
            MinValue = 0;
            MaxValue = 100;
            DecimalPlaces = 0 : 0;
        }
        field(50; "Batch Size"; Integer)
        {
            Caption = 'Batch Processing Size';
            InitValue = 50;
            MinValue = 1;
            MaxValue = 500;
        }
        field(60; "Last Full Run DateTime"; DateTime)
        {
            Caption = 'Last Full Run';
            Editable = false;
        }
        field(61; "Last Full Run Items"; Integer)
        {
            Caption = 'Items Processed in Last Run';
            Editable = false;
        }
        field(70; "Holding Cost Rate"; Decimal)
        {
            Caption = 'Annual Holding Cost Rate %';
            InitValue = 25;
            MinValue = 1;
            MaxValue = 100;
            DecimalPlaces = 0 : 2;
        }
        field(71; "Default Order Cost"; Decimal)
        {
            Caption = 'Default Order/Setup Cost';
            InitValue = 50;
            MinValue = 0;
            DecimalPlaces = 2 : 2;
        }
        field(72; "Peak Season Multiplier"; Decimal)
        {
            Caption = 'Peak Season Multiplier';
            InitValue = 1.3;
            MinValue = 1;
            MaxValue = 2;
            DecimalPlaces = 1 : 2;
        }
    }

    keys
    {
        key(PK; "Primary Key")
        {
            Clustered = true;
        }
    }

    trigger OnInsert()
    begin
        InitDefaults();
    end;

    local procedure InitDefaults()
    begin
        if "Default Analysis Months" = 0 then
            "Default Analysis Months" := 24;
        if "Minimum Data Points" = 0 then
            "Minimum Data Points" := 30;
        if "Forecast Periods Days" = 0 then
            "Forecast Periods Days" := 90;
        if "Safety Stock Multiplier" = 0 then
            "Safety Stock Multiplier" := 1.65;
        if "Service Level Target" = 0 then
            "Service Level Target" := 95;
        if "Lead Time Days Default" = 0 then
            "Lead Time Days Default" := 7;
        if "Batch Size" = 0 then
            "Batch Size" := 50;
        if "Holding Cost Rate" = 0 then
            "Holding Cost Rate" := 25;
        if "Default Order Cost" = 0 then
            "Default Order Cost" := 50;
        if "Peak Season Multiplier" = 0 then
            "Peak Season Multiplier" := 1.3;
    end;

    local procedure GetZScoreForServiceLevel(ServiceLevel: Decimal): Decimal
    begin
        // Standard Z-scores for common service levels
        case true of
            ServiceLevel >= 99.9:
                exit(3.09);
            ServiceLevel >= 99.5:
                exit(2.58);
            ServiceLevel >= 99:
                exit(2.33);
            ServiceLevel >= 98:
                exit(2.05);
            ServiceLevel >= 97:
                exit(1.88);
            ServiceLevel >= 95:
                exit(1.65);
            ServiceLevel >= 92:
                exit(1.41);
            ServiceLevel >= 90:
                exit(1.28);
            else
                exit(1.28);
        end;
    end;

    procedure GetSetup(var PlanningSetup: Record "Planning Analysis Setup")
    begin
        if not PlanningSetup.Get() then begin
            PlanningSetup.Init();
            PlanningSetup.Insert(true);
        end;
    end;
}
