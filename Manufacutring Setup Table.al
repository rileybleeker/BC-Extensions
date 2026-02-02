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
    }
}