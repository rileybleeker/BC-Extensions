codeunit 50102 "Quality Management"
{
    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Item Jnl.-Post Line", 'OnAfterInsertItemLedgEntry', '', false, false)]
    local procedure OnAfterInsertItemLedgEntry(var ItemLedgerEntry: Record "Item Ledger Entry"; ItemJournalLine: Record "Item Journal Line")
    var
        QualityOrder: Record "Quality Order";
    begin
        // Only create Quality Order for positive entries (receipts) with lot tracking
        if (ItemLedgerEntry.Quantity > 0) and (ItemLedgerEntry."Lot No." <> '') then begin
            QualityOrder.Init();
            QualityOrder."Item No." := ItemLedgerEntry."Item No.";
            QualityOrder."Lot No." := ItemLedgerEntry."Lot No.";
            QualityOrder."Test Status" := QualityOrder."Test Status"::Pending;
            QualityOrder."Item Ledger Entry No." := ItemLedgerEntry."Entry No.";
            if QualityOrder.Insert(true) then;
        end;
    end;

    procedure MarkQualityOrderAsPassed(var QualityOrder: Record "Quality Order")
    begin
        QualityOrder."Test Status" := QualityOrder."Test Status"::Passed;
        QualityOrder."Tested Date" := Today;
        QualityOrder."Tested By" := UserId;
        QualityOrder.Modify(true);

        Message('Quality Order %1 marked as Passed. Lot %2 is now available for sale.', QualityOrder."Entry No.", QualityOrder."Lot No.");
    end;

    procedure MarkQualityOrderAsFailed(var QualityOrder: Record "Quality Order")
    begin
        QualityOrder."Test Status" := QualityOrder."Test Status"::Failed;
        QualityOrder."Tested Date" := Today;
        QualityOrder."Tested By" := UserId;
        QualityOrder.Modify(true);

        Message('Quality Order %1 marked as Failed. Lot %2 cannot be sold.', QualityOrder."Entry No.", QualityOrder."Lot No.");
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Item Jnl.-Post Line", 'OnBeforeInsertItemLedgEntry', '', false, false)]
    local procedure OnBeforeInsertItemLedgEntry(var ItemLedgerEntry: Record "Item Ledger Entry"; ItemJournalLine: Record "Item Journal Line")
    begin
        // Only validate for negative entries (shipments) with lot tracking
        if (ItemLedgerEntry.Quantity < 0) and (ItemLedgerEntry."Lot No." <> '') then
            ValidateLotQualityStatus(ItemLedgerEntry."Item No.", ItemLedgerEntry."Lot No.");
    end;

    [EventSubscriber(ObjectType::Table, Database::"Tracking Specification", 'OnAfterValidateEvent', 'Lot No.', false, false)]
    local procedure OnValidateLotNoTrackingSpec(var Rec: Record "Tracking Specification"; var xRec: Record "Tracking Specification")
    begin
        // Only validate when:
        // 1. Lot No. is not empty (user has entered a value)
        // 2. Lot No. has changed (not just re-validating existing value)
        // 3. For outbound movements (negative quantity)
        if (Rec."Lot No." <> '') and (Rec."Lot No." <> xRec."Lot No.") and (Rec."Quantity (Base)" < 0) then
            ValidateLotQualityStatus(Rec."Item No.", Rec."Lot No.");
    end;

    [EventSubscriber(ObjectType::Table, Database::"Reservation Entry", 'OnBeforeInsertEvent', '', false, false)]
    local procedure OnBeforeInsertReservationEntry(var Rec: Record "Reservation Entry")
    begin
        // Only validate for outbound movements (Positive = false) with lot tracking
        if (not Rec.Positive) and (Rec."Lot No." <> '') then
            ValidateLotQualityStatus(Rec."Item No.", Rec."Lot No.");
    end;

    local procedure ValidateLotQualityStatus(ItemNo: Code[20]; LotNo: Code[50])
    var
        QualityOrder: Record "Quality Order";
    begin
        if LotNo = '' then
            exit;

        QualityOrder.SetRange("Item No.", ItemNo);
        QualityOrder.SetRange("Lot No.", LotNo);
        QualityOrder.SetFilter("Test Status", '%1|%2',
            QualityOrder."Test Status"::Pending,
            QualityOrder."Test Status"::Failed);

        if QualityOrder.FindFirst() then
            Error('Cannot select Lot No. %1 for Item %2. Status: %3. Only lots with Passed status can be used.',
                LotNo, ItemNo, QualityOrder."Test Status");
    end;
}
