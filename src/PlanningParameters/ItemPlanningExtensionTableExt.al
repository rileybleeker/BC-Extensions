tableextension 50110 "Item Planning Extension" extends Item
{
    fields
    {
        field(50110; "Planning Suggestion Enabled"; Boolean)
        {
            Caption = 'Planning Suggestion Enabled';
            DataClassification = CustomerContent;
        }
        field(50111; "Last Suggestion Date"; Date)
        {
            Caption = 'Last Suggestion Date';
            DataClassification = CustomerContent;
            Editable = false;
        }
        field(50112; "Last Applied Date"; Date)
        {
            Caption = 'Last Applied Date';
            DataClassification = CustomerContent;
            Editable = false;
        }
        field(50113; "Suggestion Override Reason"; Text[250])
        {
            Caption = 'Suggestion Override Reason';
            DataClassification = CustomerContent;
        }
        field(50114; "Demand Pattern"; Enum "Item Demand Pattern")
        {
            Caption = 'Detected Demand Pattern';
            DataClassification = CustomerContent;
            Editable = false;
        }
        field(50115; "Forecast Reliability Score"; Decimal)
        {
            Caption = 'Forecast Reliability Score';
            DataClassification = CustomerContent;
            DecimalPlaces = 0 : 2;
            MinValue = 0;
            MaxValue = 100;
            Editable = false;
        }
    }
}
