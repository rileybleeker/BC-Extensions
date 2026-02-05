codeunit 50101 "Reservation Date Sync"
{
    procedure SyncAllProdOrderLines()
    var
        ProdOrderLine: Record "Prod. Order Line";
    begin
        // Loop through all Prod. Order Lines
        if ProdOrderLine.FindSet() then
            repeat
                SyncShipmentDateFromProdOrder(ProdOrderLine);
            until ProdOrderLine.Next() = 0;
    end;

    procedure SyncShipmentDateFromProdOrder(ProdOrderLine: Record "Prod. Order Line")
    var
        ReservationEntry: Record "Reservation Entry";
        SalesLine: Record "Sales Line";
    begin
        // Find reservation entries for the production order line
        ReservationEntry.SetRange("Source Type", Database::"Prod. Order Line");
        ReservationEntry.SetRange("Source Subtype", ProdOrderLine.Status);
        ReservationEntry.SetRange("Source ID", ProdOrderLine."Prod. Order No.");
        ReservationEntry.SetRange("Source Prod. Order Line", ProdOrderLine."Line No.");

        if ReservationEntry.FindSet() then
            repeat
                // Find the linked sales line from reservation entry
                if FindLinkedSalesLine(ReservationEntry, SalesLine) then begin
                    // Update the Shipment Date on Sales Line with Ending Date-Time from Prod. Order Line
                    if SalesLine."Shipment Date" <> DT2Date(ProdOrderLine."Ending Date-Time") then begin
                        SalesLine.Validate("Shipment Date", DT2Date(ProdOrderLine."Ending Date-Time"));
                        SalesLine.Modify(true);
                    end;
                end;
            until ReservationEntry.Next() = 0;
    end;

    local procedure FindLinkedSalesLine(FromReservEntry: Record "Reservation Entry"; var SalesLine: Record "Sales Line"): Boolean
    var
        ToReservEntry: Record "Reservation Entry";
    begin
        // Find the corresponding reservation entry that links to the sales line
        ToReservEntry.SetRange("Entry No.", FromReservEntry."Entry No.");
        ToReservEntry.SetRange("Positive", not FromReservEntry."Positive");
        ToReservEntry.SetRange("Source Type", Database::"Sales Line");
        ToReservEntry.SetRange("Source Subtype", 1); // Sales Order

        if ToReservEntry.FindFirst() then begin
            SalesLine.SetRange("Document Type", SalesLine."Document Type"::Order);
            SalesLine.SetRange("Document No.", ToReservEntry."Source ID");
            SalesLine.SetRange("Line No.", ToReservEntry."Source Ref. No.");
            exit(SalesLine.FindFirst());
        end;
        exit(false);
    end;
}
