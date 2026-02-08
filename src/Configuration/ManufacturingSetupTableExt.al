tableextension 50102 "Manufacturing Setup Ext" extends "Manufacturing Setup"
{
    fields
    {
        field(50100; "Upper Tolerance"; Decimal)
        {
            Caption = 'Upper Tolerance';
            DataClassification = ToBeClassified;
            DecimalPlaces = 0 : 5;
        }
        field(50103; "Enable Inventory Alerts"; Boolean)
        {
            Caption = 'Enable Inventory Alerts';
            DataClassification = SystemMetadata;
            InitValue = false;
        }
        field(50104; "Logic Apps Endpoint URL"; Text[500])
        {
            Caption = 'Logic Apps Endpoint URL';
            DataClassification = SystemMetadata;
        }
        field(50105; "Logic Apps API Key"; Text[100])
        {
            Caption = 'Logic Apps API Key';
            DataClassification = EndUserIdentifiableInformation;
            ExtendedDatatype = Masked;
        }
        field(50106; "CSV Import Customer No."; Code[20])
        {
            Caption = 'CSV Import Customer No.';
            TableRelation = Customer;
            DataClassification = ToBeClassified;
        }
        field(50107; "CSV Item Template Code"; Code[20])
        {
            Caption = 'CSV Item Template Code';
            TableRelation = "Config. Template Header".Code where("Table ID" = const(27));
            DataClassification = ToBeClassified;
        }

        // Vendor Performance Settings
        field(50120; "On-Time Delivery Weight"; Decimal)
        {
            Caption = 'On-Time Delivery Weight %';
            DataClassification = CustomerContent;
            InitValue = 30;
            MinValue = 0;
            MaxValue = 100;
            DecimalPlaces = 0 : 0;
        }
        field(50121; "Quality Weight"; Decimal)
        {
            Caption = 'Quality Weight %';
            DataClassification = CustomerContent;
            InitValue = 30;
            MinValue = 0;
            MaxValue = 100;
            DecimalPlaces = 0 : 0;
        }
        field(50122; "Lead Time Reliability Weight"; Decimal)
        {
            Caption = 'Lead Time Reliability Weight %';
            DataClassification = CustomerContent;
            InitValue = 25;
            MinValue = 0;
            MaxValue = 100;
            DecimalPlaces = 0 : 0;
        }
        field(50123; "Price Competitiveness Weight"; Decimal)
        {
            Caption = 'Price Competitiveness Weight %';
            DataClassification = CustomerContent;
            InitValue = 15;
            MinValue = 0;
            MaxValue = 100;
            DecimalPlaces = 0 : 0;
        }
        field(50130; "On-Time Tolerance Days"; Integer)
        {
            Caption = 'On-Time Tolerance Days';
            DataClassification = CustomerContent;
            InitValue = 2;
            MinValue = 0;
            MaxValue = 30;
        }
        field(50131; "Lead Time Variance Tolerance %"; Decimal)
        {
            Caption = 'Lead Time Variance Tolerance %';
            DataClassification = CustomerContent;
            InitValue = 10;
            MinValue = 0;
            MaxValue = 100;
            DecimalPlaces = 0 : 2;
        }
        field(50132; "Auto-Approve Score Threshold"; Decimal)
        {
            Caption = 'Auto-Approve Score Threshold';
            DataClassification = CustomerContent;
            InitValue = 80;
            MinValue = 0;
            MaxValue = 100;
            DecimalPlaces = 0 : 0;
        }
        field(50140; "Low Risk Score Threshold"; Decimal)
        {
            Caption = 'Low Risk Score Threshold';
            DataClassification = CustomerContent;
            InitValue = 80;
            MinValue = 0;
            MaxValue = 100;
            DecimalPlaces = 0 : 0;
        }
        field(50141; "Medium Risk Score Threshold"; Decimal)
        {
            Caption = 'Medium Risk Score Threshold';
            DataClassification = CustomerContent;
            InitValue = 60;
            MinValue = 0;
            MaxValue = 100;
            DecimalPlaces = 0 : 0;
        }
        field(50142; "High Risk Score Threshold"; Decimal)
        {
            Caption = 'High Risk Score Threshold';
            DataClassification = CustomerContent;
            InitValue = 40;
            MinValue = 0;
            MaxValue = 100;
            DecimalPlaces = 0 : 0;
        }
        field(50150; "Perf Calc Period Months"; Integer)
        {
            Caption = 'Performance Calc Period (Months)';
            DataClassification = CustomerContent;
            InitValue = 12;
            MinValue = 1;
            MaxValue = 60;
        }
        field(50151; "Auto-Recalc on Receipt"; Boolean)
        {
            Caption = 'Auto-Recalc on Receipt';
            DataClassification = CustomerContent;
            InitValue = false;
        }
        field(50160; "Auto-Create NCR from Quality"; Boolean)
        {
            Caption = 'Auto-Create NCR from Quality';
            DataClassification = CustomerContent;
            InitValue = true;
        }
        field(50161; "NCR No. Series"; Code[20])
        {
            Caption = 'NCR No. Series';
            DataClassification = CustomerContent;
            TableRelation = "No. Series";
        }
    }
}