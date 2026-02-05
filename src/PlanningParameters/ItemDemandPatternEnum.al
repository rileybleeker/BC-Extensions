enum 50112 "Item Demand Pattern"
{
    Extensible = true;
    Caption = 'Item Demand Pattern';

    value(0; Unknown)
    {
        Caption = 'Not Analyzed';
    }
    value(1; Stable)
    {
        Caption = 'Stable Demand';
    }
    value(2; Seasonal)
    {
        Caption = 'Seasonal Pattern';
    }
    value(3; Trending)
    {
        Caption = 'Trending (Up/Down)';
    }
    value(4; Erratic)
    {
        Caption = 'Erratic/Unpredictable';
    }
    value(5; Intermittent)
    {
        Caption = 'Intermittent/Lumpy';
    }
}
