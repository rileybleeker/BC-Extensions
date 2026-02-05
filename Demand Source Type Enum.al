enum 50111 "Demand Source Type"
{
    Extensible = true;
    Caption = 'Demand Source Type';

    value(0; Sales)
    {
        Caption = 'Sales';
    }
    value(1; Consumption)
    {
        Caption = 'Production Consumption';
    }
    value(2; Transfer)
    {
        Caption = 'Transfer Out';
    }
    value(3; Adjustment)
    {
        Caption = 'Negative Adjustment';
    }
    value(4; Assembly)
    {
        Caption = 'Assembly Consumption';
    }
}
