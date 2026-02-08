table 50120 "Vendor Performance"
{
    Caption = 'Vendor Performance';
    DataClassification = CustomerContent;
    LookupPageId = "Vendor Performance List";
    DrillDownPageId = "Vendor Performance List";

    fields
    {
        field(1; "Vendor No."; Code[20])
        {
            Caption = 'Vendor No.';
            TableRelation = Vendor;
            NotBlank = true;
        }
        field(2; "Period Start Date"; Date)
        {
            Caption = 'Period Start Date';
            NotBlank = true;
        }
        field(3; "Period End Date"; Date)
        {
            Caption = 'Period End Date';
            NotBlank = true;
        }

        // Delivery Performance
        field(10; "Total Receipts"; Integer)
        {
            Caption = 'Total Receipts';
            Editable = false;
        }
        field(11; "On-Time Receipts"; Integer)
        {
            Caption = 'On-Time Receipts';
            Editable = false;
        }
        field(12; "Early Receipts"; Integer)
        {
            Caption = 'Early Receipts';
            Editable = false;
        }
        field(13; "Late Receipts"; Integer)
        {
            Caption = 'Late Receipts';
            Editable = false;
        }
        field(14; "On-Time Delivery %"; Decimal)
        {
            Caption = 'On-Time Delivery %';
            DecimalPlaces = 2 : 2;
            Editable = false;
            MinValue = 0;
            MaxValue = 100;
        }

        // Lead Time Performance
        field(20; "Avg Promised Lead Time Days"; Decimal)
        {
            Caption = 'Avg Promised Lead Time (Days)';
            DecimalPlaces = 1 : 1;
            Editable = false;
        }
        field(21; "Avg Actual Lead Time Days"; Decimal)
        {
            Caption = 'Avg Actual Lead Time (Days)';
            DecimalPlaces = 1 : 1;
            Editable = false;
        }
        field(22; "Lead Time Variance Days"; Decimal)
        {
            Caption = 'Lead Time Variance (Days)';
            DecimalPlaces = 1 : 1;
            Editable = false;
        }
        field(23; "Lead Time Std Dev"; Decimal)
        {
            Caption = 'Lead Time Std Dev';
            DecimalPlaces = 2 : 2;
            Editable = false;
        }
        field(24; "Lead Time Reliability %"; Decimal)
        {
            Caption = 'Lead Time Reliability %';
            DecimalPlaces = 2 : 2;
            Editable = false;
            MinValue = 0;
            MaxValue = 100;
        }

        // Quality Performance
        field(30; "Total Qty Received"; Decimal)
        {
            Caption = 'Total Qty Received';
            DecimalPlaces = 0 : 5;
            Editable = false;
        }
        field(31; "Qty Accepted"; Decimal)
        {
            Caption = 'Qty Accepted';
            DecimalPlaces = 0 : 5;
            Editable = false;
        }
        field(32; "Qty Rejected"; Decimal)
        {
            Caption = 'Qty Rejected';
            DecimalPlaces = 0 : 5;
            Editable = false;
        }
        field(33; "Quality Accept Rate %"; Decimal)
        {
            Caption = 'Quality Accept Rate %';
            DecimalPlaces = 2 : 2;
            Editable = false;
            MinValue = 0;
            MaxValue = 100;
        }
        field(34; "PPM Defect Rate"; Decimal)
        {
            Caption = 'PPM Defect Rate';
            DecimalPlaces = 0 : 0;
            Editable = false;
        }
        field(35; "NCR Count"; Integer)
        {
            Caption = 'NCR Count';
            Editable = false;
        }

        // Pricing Performance
        field(40; "Avg Price Variance %"; Decimal)
        {
            Caption = 'Avg Price Variance %';
            DecimalPlaces = 2 : 2;
            Editable = false;
        }
        field(41; "Price Competitiveness Score"; Decimal)
        {
            Caption = 'Price Competitiveness Score';
            DecimalPlaces = 2 : 2;
            Editable = false;
            MinValue = 0;
            MaxValue = 100;
        }

        // Composite Score
        field(50; "Overall Score"; Decimal)
        {
            Caption = 'Overall Score';
            DecimalPlaces = 2 : 2;
            Editable = false;
            MinValue = 0;
            MaxValue = 100;
        }
        field(51; "Score Trend"; Enum "Vendor Score Trend")
        {
            Caption = 'Score Trend';
            Editable = false;
        }
        field(52; "Risk Level"; Enum "Vendor Risk Level")
        {
            Caption = 'Risk Level';
            Editable = false;
        }

        // Metadata
        field(60; "Last Calculated"; DateTime)
        {
            Caption = 'Last Calculated';
            Editable = false;
        }
        field(61; "Calculation Notes"; Text[500])
        {
            Caption = 'Calculation Notes';
            Editable = false;
        }
    }

    keys
    {
        key(PK; "Vendor No.", "Period Start Date")
        {
            Clustered = true;
        }
        key(ByPeriod; "Period Start Date", "Vendor No.")
        {
        }
        key(ByScore; "Overall Score")
        {
        }
        key(ByRisk; "Risk Level", "Vendor No.")
        {
        }
    }

    trigger OnInsert()
    begin
        "Last Calculated" := CurrentDateTime;
    end;

    trigger OnModify()
    begin
        "Last Calculated" := CurrentDateTime;
    end;

    procedure GetVendorName(): Text[100]
    var
        Vendor: Record Vendor;
    begin
        if Vendor.Get("Vendor No.") then
            exit(Vendor.Name);
        exit('');
    end;

    procedure GetPeriodDescription(): Text[50]
    begin
        exit(Format("Period Start Date", 0, '<Month Text> <Year4>'));
    end;
}
