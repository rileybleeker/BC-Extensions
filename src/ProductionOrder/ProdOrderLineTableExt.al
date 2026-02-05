tableextension 50101 "Prod. Order Line Ext" extends "Prod. Order Line"
{
    fields
    {
        field(50100; "Sync with DB"; Boolean)
        {
            Caption = 'Sync with DB';
            DataClassification = ToBeClassified;
            InitValue = false;
        }
        field(50101; "Upper Tolerance"; Decimal)
        {
            Caption = 'Upper Tolerance';
            DataClassification = ToBeClassified;
            Editable = false;
        }
        modify(Quantity)
        {
            trigger OnAfterValidate()
            begin
                CalculateUpperTolerance();
            end;
        }
        //When users attempt to change the Ending Date-Time on a Prod. Order Line that has Item Tracking Entries (Reservation Entries) to a date later than the Reservation Entry, this error is returned "This change leads to a date conflict with existing reservations...". This code resolves this by updating the Shipment Date on the Sales Line, which updates the date on the Reservation Entries. You can then change the Ending Date-Time, which will then st the Shipment Date to the following working day at the Location.
        modify("Ending Date-Time")
        {
            //needs to be OnBeforeValidate to avoid the date conflict error
            trigger OnBeforeValidate()
            var
                ReservDateSync: Codeunit "Reservation Date Sync";
            begin
                ReservDateSync.SyncShipmentDateFromProdOrder(Rec);
            end;
            //run this again after the validation occurs which strangely sets the Ending Date-Time again to a day before what the user selects though UI.
            trigger OnAfterValidate()
            var
                ReservDateSync: Codeunit "Reservation Date Sync";
            begin
                ReservDateSync.SyncShipmentDateFromProdOrder(Rec);
            end;
        }
    }
    local procedure CalculateUpperTolerance()
    var
        MfgSetup: Record "Manufacturing Setup";
    begin
        if MfgSetup.Get() then Rec."Upper Tolerance" := Rec.Quantity * MfgSetup."Upper Tolerance";
    end;
}