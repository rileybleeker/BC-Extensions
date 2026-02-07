tableextension 50120 "Vendor Performance Ext" extends Vendor
{
    fields
    {
        field(50120; "Performance Score"; Decimal)
        {
            Caption = 'Performance Score';
            DataClassification = CustomerContent;
            Editable = false;
            DecimalPlaces = 0 : 2;
            MinValue = 0;
            MaxValue = 100;
        }
        field(50121; "Performance Risk Level"; Enum "Vendor Risk Level")
        {
            Caption = 'Risk Level';
            DataClassification = CustomerContent;
            Editable = false;
        }
        field(50122; "On-Time Delivery %"; Decimal)
        {
            Caption = 'On-Time Delivery %';
            DataClassification = CustomerContent;
            Editable = false;
            DecimalPlaces = 0 : 2;
            MinValue = 0;
            MaxValue = 100;
        }
        field(50123; "Quality Accept Rate %"; Decimal)
        {
            Caption = 'Quality Accept Rate %';
            DataClassification = CustomerContent;
            Editable = false;
            DecimalPlaces = 0 : 2;
            MinValue = 0;
            MaxValue = 100;
        }
        field(50124; "Lead Time Variance Days"; Decimal)
        {
            Caption = 'Lead Time Variance (Days)';
            DataClassification = CustomerContent;
            Editable = false;
            DecimalPlaces = 0 : 1;
        }
        field(50125; "Score Trend"; Enum "Vendor Score Trend")
        {
            Caption = 'Score Trend';
            DataClassification = CustomerContent;
            Editable = false;
        }
        field(50126; "Last Performance Calc"; DateTime)
        {
            Caption = 'Last Performance Calculation';
            DataClassification = CustomerContent;
            Editable = false;
        }
    }
}
