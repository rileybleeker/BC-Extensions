enum 50110 "Planning Suggestion Status"
{
    Extensible = true;
    Caption = 'Planning Suggestion Status';

    value(0; Pending)
    {
        Caption = 'Pending Review';
    }
    value(1; Approved)
    {
        Caption = 'Approved';
    }
    value(2; Rejected)
    {
        Caption = 'Rejected';
    }
    value(3; Applied)
    {
        Caption = 'Applied to Item';
    }
    value(4; Failed)
    {
        Caption = 'Processing Failed';
    }
    value(5; Expired)
    {
        Caption = 'Expired (Not Reviewed)';
    }
}
