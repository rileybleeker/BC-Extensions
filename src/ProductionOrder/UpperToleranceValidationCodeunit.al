codeunit 50100 "Upper Tolerance Validation"
{
    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Item Jnl.-Post Line", 'OnBeforeInsertCapLedgEntry', '', false, false)]
    local procedure OnBeforeInsertCapLedgEntry(var CapLedgEntry: Record "Capacity Ledger Entry"; ItemJournalLine: Record "Item Journal Line")
    var
        ProdOrderLine: Record "Prod. Order Line";
        NewFinishedQty: Decimal;
    begin
        // Only validate for output entries
        if ItemJournalLine."Entry Type" <> ItemJournalLine."Entry Type"::Output then exit;
        // Get the production order line
        if not ProdOrderLine.Get(ProdOrderLine.Status::Released, ItemJournalLine."Order No.", ItemJournalLine."Order Line No.") then if not ProdOrderLine.Get(ProdOrderLine.Status::"Firm Planned", ItemJournalLine."Order No.", ItemJournalLine."Order Line No.") then exit;
        // Calculate what the finished quantity will be after posting
        NewFinishedQty := ProdOrderLine."Finished Quantity" + ItemJournalLine."Output Quantity";
        // Check if upper tolerance is configured
        if ProdOrderLine."Upper Tolerance" = 0 then exit;
        // Validate against upper tolerance
        if NewFinishedQty > ProdOrderLine."Upper Tolerance" then Error('Cannot post output. Finished Quantity (%1) would exceed Upper Tolerance (%2) for Production Order %3, Line %4.', NewFinishedQty, ProdOrderLine."Upper Tolerance", ProdOrderLine."Prod. Order No.", ProdOrderLine."Line No.");
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Item Jnl.-Post Line", 'OnAfterInitItemLedgEntry', '', false, false)]
    local procedure OnAfterInitItemLedgEntry(var NewItemLedgEntry: Record "Item Ledger Entry"; ItemJournalLine: Record "Item Journal Line")
    var
        ProdOrderLine: Record "Prod. Order Line";
        NewFinishedQty: Decimal;
    begin
        // Only validate for output entries
        if ItemJournalLine."Entry Type" <> ItemJournalLine."Entry Type"::Output then exit;
        // Skip if not a production order
        if ItemJournalLine."Order Type" <> ItemJournalLine."Order Type"::Production then exit;
        // Get the production order line
        if not ProdOrderLine.Get(ProdOrderLine.Status::Released, ItemJournalLine."Order No.", ItemJournalLine."Order Line No.") then if not ProdOrderLine.Get(ProdOrderLine.Status::"Firm Planned", ItemJournalLine."Order No.", ItemJournalLine."Order Line No.") then exit;
        // Calculate what the finished quantity will be after posting
        NewFinishedQty := ProdOrderLine."Finished Quantity" + ItemJournalLine."Output Quantity";
        // Check if upper tolerance is configured
        if ProdOrderLine."Upper Tolerance" = 0 then exit;
        // Validate against upper tolerance
        if NewFinishedQty > ProdOrderLine."Upper Tolerance" then Error('Cannot post output. Finished Quantity (%1) would exceed Upper Tolerance (%2) for Production Order %3, Line %4.', NewFinishedQty, ProdOrderLine."Upper Tolerance", ProdOrderLine."Prod. Order No.", ProdOrderLine."Line No.");
    end;
}
