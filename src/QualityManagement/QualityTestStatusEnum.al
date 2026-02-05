enum 50100 "Quality Test Status"
{
    Extensible = true;
    
    value(0; Pending)
    {
        Caption = 'Pending';
    }
    value(1; Passed)
    {
        Caption = 'Passed';
    }
    value(2; Failed)
    {
        Caption = 'Failed';
    }
}
