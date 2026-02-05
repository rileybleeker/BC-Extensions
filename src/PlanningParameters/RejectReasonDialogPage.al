page 50114 "Reject Reason Dialog"
{
    PageType = StandardDialog;
    Caption = 'Reject Reason';
    ApplicationArea = All;

    layout
    {
        area(Content)
        {
            group(General)
            {
                Caption = 'Enter Rejection Reason';

                field(RejectReasonField; RejectReason)
                {
                    ApplicationArea = All;
                    Caption = 'Reason';
                    ToolTip = 'Enter the reason for rejecting this suggestion.';
                    MultiLine = true;
                    ShowMandatory = true;
                }
            }
        }
    }

    var
        RejectReason: Text[250];

    procedure GetRejectReason(): Text[250]
    begin
        exit(RejectReason);
    end;

    procedure SetRejectReason(NewReason: Text[250])
    begin
        RejectReason := NewReason;
    end;

    trigger OnQueryClosePage(CloseAction: Action): Boolean
    begin
        if CloseAction in [Action::OK, Action::LookupOK] then
            if RejectReason = '' then
                Error('A rejection reason is required.');
        exit(true);
    end;
}
