enum 50131 "NCR Disposition"
{
    Caption = 'NCR Disposition';
    Extensible = true;

    value(0; "Pending")
    {
        Caption = 'Pending';
    }
    value(1; "Return to Vendor")
    {
        Caption = 'Return to Vendor';
    }
    value(2; "Use As-Is")
    {
        Caption = 'Use As-Is';
    }
    value(3; "Rework")
    {
        Caption = 'Rework';
    }
    value(4; "Scrap")
    {
        Caption = 'Scrap';
    }
}
