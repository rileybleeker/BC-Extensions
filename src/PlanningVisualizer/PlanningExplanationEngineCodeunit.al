codeunit 50162 "Planning Explanation Engine"
{
    // Generates plain-language explanations for each planning suggestion

    var
        NextEntryNo: Integer;

    procedure GenerateExplanations(
        WorksheetTemplateName: Code[10];
        JournalBatchName: Code[10];
        ItemNo: Code[20];
        LocationCode: Code[10];
        VariantCode: Code[10];
        var TempEventBuffer: Record "Inventory Event Buffer" temporary;
        var TempExplanation: Record "Planning Explanation" temporary
    )
    var
        ReqLine: Record "Requisition Line";
        Item: Record Item;
        ReorderPoint: Decimal;
        SafetyStock: Decimal;
        MaxInventory: Decimal;
        ReorderingPolicyText: Text[50];
        ReorderQty: Decimal;
        LeadTimeDays: Integer;
        DampenerPeriodText: Text[20];
        DampenerQty: Decimal;
        TimeBucketText: Text[20];
        LotAccumPeriodText: Text[20];
        ProjectionEngine: Codeunit "Inventory Projection Engine";
    begin
        TempExplanation.Reset();
        TempExplanation.DeleteAll();
        NextEntryNo := 0;

        if not Item.Get(ItemNo) then
            exit;

        ProjectionEngine.GetPlanningParameters(
            ItemNo, LocationCode, VariantCode,
            ReorderPoint, SafetyStock, MaxInventory,
            ReorderingPolicyText, ReorderQty, LeadTimeDays,
            DampenerPeriodText, DampenerQty,
            TimeBucketText, LotAccumPeriodText
        );

        ReqLine.SetRange("Worksheet Template Name", WorksheetTemplateName);
        ReqLine.SetRange("Journal Batch Name", JournalBatchName);
        ReqLine.SetRange(Type, ReqLine.Type::Item);
        ReqLine.SetRange("No.", ItemNo);
        if LocationCode <> '' then
            ReqLine.SetRange("Location Code", LocationCode);
        if VariantCode <> '' then
            ReqLine.SetRange("Variant Code", VariantCode);

        if ReqLine.FindSet() then
            repeat
                GenerateSingleExplanation(
                    ReqLine, Item, TempEventBuffer, TempExplanation,
                    ReorderPoint, SafetyStock, MaxInventory,
                    ReorderingPolicyText, ReorderQty, LeadTimeDays
                );
            until ReqLine.Next() = 0;
    end;

    local procedure GenerateSingleExplanation(
        ReqLine: Record "Requisition Line";
        Item: Record Item;
        var TempEventBuffer: Record "Inventory Event Buffer" temporary;
        var TempExplanation: Record "Planning Explanation" temporary;
        ReorderPoint: Decimal;
        SafetyStock: Decimal;
        MaxInventory: Decimal;
        ReorderingPolicyText: Text[50];
        ReorderQty: Decimal;
        LeadTimeDays: Integer
    )
    var
        LowestBefore: Decimal;
        LowestBeforeDate: Date;
        LowestAfter: Decimal;
        SeverityLevel: Integer;
    begin
        // Find the lowest projected inventory around this suggestion's date
        FindLowestProjection(
            TempEventBuffer, ReqLine."Due Date",
            LowestBefore, LowestBeforeDate, LowestAfter
        );

        // Determine severity
        if LowestBefore < 0 then
            SeverityLevel := 3 // Critical: stockout
        else if LowestBefore < SafetyStock then
            SeverityLevel := 2 // Warning: below safety stock
        else
            SeverityLevel := 1; // Info: normal replenishment

        NextEntryNo += 1;
        TempExplanation.Init();
        TempExplanation."Entry No." := NextEntryNo;
        TempExplanation."Req. Line No." := ReqLine."Line No.";
        TempExplanation."Item No." := ReqLine."No.";
        TempExplanation."Action Message" := Format(ReqLine."Action Message");
        TempExplanation."Due Date" := ReqLine."Due Date";
        TempExplanation.Quantity := ReqLine.Quantity;
        TempExplanation."Reordering Policy" := ReorderingPolicyText;
        TempExplanation.Severity := SeverityLevel;

        case ReqLine."Action Message" of
            ReqLine."Action Message"::New:
                GenerateNewExplanation(
                    TempExplanation, ReqLine, Item,
                    ReorderPoint, SafetyStock, MaxInventory,
                    ReorderingPolicyText, ReorderQty, LeadTimeDays,
                    LowestBefore, LowestBeforeDate, LowestAfter
                );
            ReqLine."Action Message"::"Change Qty.":
                GenerateChangeQtyExplanation(
                    TempExplanation, ReqLine, Item,
                    ReorderPoint, SafetyStock,
                    LowestBefore, LowestBeforeDate
                );
            ReqLine."Action Message"::Reschedule:
                GenerateRescheduleExplanation(
                    TempExplanation, ReqLine, Item,
                    ReorderPoint, SafetyStock,
                    LowestBefore, LowestBeforeDate
                );
            ReqLine."Action Message"::"Resched. & Chg. Qty.":
                GenerateReschedChgQtyExplanation(
                    TempExplanation, ReqLine, Item,
                    ReorderPoint, SafetyStock,
                    LowestBefore, LowestBeforeDate
                );
            ReqLine."Action Message"::Cancel:
                GenerateCancelExplanation(
                    TempExplanation, ReqLine, Item
                );
        end;

        TempExplanation.Insert();
    end;

    local procedure GenerateNewExplanation(
        var TempExplanation: Record "Planning Explanation" temporary;
        ReqLine: Record "Requisition Line";
        Item: Record Item;
        ReorderPoint: Decimal;
        SafetyStock: Decimal;
        MaxInventory: Decimal;
        ReorderingPolicyText: Text[50];
        ReorderQty: Decimal;
        LeadTimeDays: Integer;
        LowestBefore: Decimal;
        LowestBeforeDate: Date;
        LowestAfter: Decimal
    )
    var
        ReplenishmentText: Text[50];
    begin
        ReplenishmentText := Format(ReqLine."Replenishment System");

        TempExplanation."Summary Text" := CopyStr(
            StrSubstNo('%1 %2 units of %3 by %4.',
                ReplenishmentText, ReqLine.Quantity, Item.Description, ReqLine."Due Date"),
            1, 250);

        case ReorderingPolicyText of
            'Fixed Reorder Qty.':
                begin
                    TempExplanation."Why Text" := CopyStr(
                        StrSubstNo('Projected inventory drops to %1 units on %2, which is below the Reorder Point (%3). ' +
                            'The Fixed Reorder Qty. policy orders exactly %4 units each time inventory reaches the reorder point.',
                            LowestBefore, LowestBeforeDate, ReorderPoint, ReorderQty),
                        1, 500);
                    TempExplanation."Impact Text" := CopyStr(
                        StrSubstNo('With this order, inventory recovers to approximately %1 units after receipt. ' +
                            'Without it, inventory would remain at %2, risking %3.',
                            LowestBefore + ReqLine.Quantity, LowestBefore,
                            GetRiskDescription(LowestBefore, SafetyStock)),
                        1, 500);
                end;
            'Lot-for-Lot':
                begin
                    TempExplanation."Why Text" := CopyStr(
                        StrSubstNo('Lot-for-Lot policy matches supply exactly to demand. ' +
                            'Projected inventory drops to %1 units on %2. ' +
                            'This order of %3 units covers all demand within the lot accumulation period.',
                            LowestBefore, LowestBeforeDate, ReqLine.Quantity),
                        1, 500);
                    TempExplanation."Impact Text" := CopyStr(
                        StrSubstNo('This order precisely covers upcoming demand, keeping inventory lean. ' +
                            'Without it, projected inventory would be %1 units.',
                            LowestBefore),
                        1, 500);
                end;
            'Maximum Qty.':
                begin
                    TempExplanation."Why Text" := CopyStr(
                        StrSubstNo('Projected inventory drops to %1 units on %2, below the Reorder Point (%3). ' +
                            'The Maximum Qty. policy orders enough to bring inventory up to the Maximum Inventory level (%4).',
                            LowestBefore, LowestBeforeDate, ReorderPoint, MaxInventory),
                        1, 500);
                    TempExplanation."Impact Text" := CopyStr(
                        StrSubstNo('After receipt, inventory will reach approximately %1 units (target: %2). ' +
                            'Without this order, inventory stays at %3.',
                            LowestAfter, MaxInventory, LowestBefore),
                        1, 500);
                end;
            'Order':
                begin
                    TempExplanation."Why Text" := CopyStr(
                        StrSubstNo('The Order policy creates a one-to-one supply for each demand. ' +
                            'A specific demand of %1 units requires a dedicated %2 order by %3.',
                            ReqLine.Quantity, ReplenishmentText, ReqLine."Due Date"),
                        1, 500);
                    TempExplanation."Impact Text" := CopyStr(
                        StrSubstNo('This order is directly linked to its demand source. ' +
                            'Without it, the demand of %1 units would not be fulfilled.',
                            ReqLine.Quantity),
                        1, 500);
                end;
            else begin
                TempExplanation."Why Text" := CopyStr(
                    StrSubstNo('Projected inventory drops to %1 units on %2. ' +
                        'A new supply of %3 units is needed by %4 to maintain adequate stock levels.',
                        LowestBefore, LowestBeforeDate, ReqLine.Quantity, ReqLine."Due Date"),
                    1, 500);
                TempExplanation."Impact Text" := CopyStr(
                    StrSubstNo('With this order, inventory recovers to approximately %1 units. ' +
                        'Without it, inventory remains at %2.',
                        LowestBefore + ReqLine.Quantity, LowestBefore),
                    1, 500);
            end;
        end;

        BuildDetailText(TempExplanation, ReqLine, LeadTimeDays);
    end;

    local procedure GenerateChangeQtyExplanation(
        var TempExplanation: Record "Planning Explanation" temporary;
        ReqLine: Record "Requisition Line";
        Item: Record Item;
        ReorderPoint: Decimal;
        SafetyStock: Decimal;
        LowestBefore: Decimal;
        LowestBeforeDate: Date
    )
    var
        QtyDifference: Decimal;
        Direction: Text[20];
    begin
        QtyDifference := ReqLine.Quantity - ReqLine."Original Quantity";
        if QtyDifference > 0 then
            Direction := 'Increase'
        else
            Direction := 'Decrease';

        TempExplanation."Summary Text" := CopyStr(
            StrSubstNo('%1 %2 %3 from %4 to %5 units.',
                Direction, Format(ReqLine."Ref. Order Type"), ReqLine."Ref. Order No.",
                ReqLine."Original Quantity", ReqLine.Quantity),
            1, 250);

        TempExplanation."Why Text" := CopyStr(
            StrSubstNo('Demand has changed since the original order was created. ' +
                'The existing %1 %2 has quantity %3, but current demand requires %4 units (difference: %5). ' +
                'Projected inventory on %6 would be %7 without this adjustment.',
                Format(ReqLine."Ref. Order Type"), ReqLine."Ref. Order No.",
                ReqLine."Original Quantity", ReqLine.Quantity, QtyDifference,
                LowestBeforeDate, LowestBefore),
            1, 500);

        TempExplanation."Impact Text" := CopyStr(
            StrSubstNo('Adjusting the quantity %1 the order by %2 units to align supply with current demand. ' +
                '%3',
                LowerCase(Direction), Abs(QtyDifference),
                GetRiskStatement(LowestBefore, SafetyStock, ReorderPoint)),
            1, 500);

        BuildDetailText(TempExplanation, ReqLine, 0);
    end;

    local procedure GenerateRescheduleExplanation(
        var TempExplanation: Record "Planning Explanation" temporary;
        ReqLine: Record "Requisition Line";
        Item: Record Item;
        ReorderPoint: Decimal;
        SafetyStock: Decimal;
        LowestBefore: Decimal;
        LowestBeforeDate: Date
    )
    var
        DaysDiff: Integer;
        Direction: Text[20];
    begin
        DaysDiff := ReqLine."Due Date" - ReqLine."Original Due Date";
        if DaysDiff > 0 then
            Direction := 'later'
        else
            Direction := 'earlier';

        TempExplanation."Summary Text" := CopyStr(
            StrSubstNo('Reschedule %1 %2 from %3 to %4 (%5 days %6).',
                Format(ReqLine."Ref. Order Type"), ReqLine."Ref. Order No.",
                ReqLine."Original Due Date", ReqLine."Due Date",
                Abs(DaysDiff), Direction),
            1, 250);

        TempExplanation."Why Text" := CopyStr(
            StrSubstNo('The demand timing has shifted. %1 %2 is currently due on %3, ' +
                'but the demand it covers now needs supply by %4. ' +
                'Rescheduling %5 days %6 aligns supply with the updated demand schedule.',
                Format(ReqLine."Ref. Order Type"), ReqLine."Ref. Order No.",
                ReqLine."Original Due Date", ReqLine."Due Date",
                Abs(DaysDiff), Direction),
            1, 500);

        TempExplanation."Impact Text" := CopyStr(
            StrSubstNo('Without rescheduling, supply arrives %1 relative to when it''s needed, ' +
                'potentially causing %2.',
                GetTimingImpact(DaysDiff),
                GetTimingConsequence(DaysDiff, LowestBefore, SafetyStock)),
            1, 500);

        BuildDetailText(TempExplanation, ReqLine, 0);
    end;

    local procedure GenerateReschedChgQtyExplanation(
        var TempExplanation: Record "Planning Explanation" temporary;
        ReqLine: Record "Requisition Line";
        Item: Record Item;
        ReorderPoint: Decimal;
        SafetyStock: Decimal;
        LowestBefore: Decimal;
        LowestBeforeDate: Date
    )
    var
        DaysDiff: Integer;
        QtyDiff: Decimal;
    begin
        DaysDiff := ReqLine."Due Date" - ReqLine."Original Due Date";
        QtyDiff := ReqLine.Quantity - ReqLine."Original Quantity";

        TempExplanation."Summary Text" := CopyStr(
            StrSubstNo('Reschedule %1 %2 from %3 to %4 and change qty from %5 to %6.',
                Format(ReqLine."Ref. Order Type"), ReqLine."Ref. Order No.",
                ReqLine."Original Due Date", ReqLine."Due Date",
                ReqLine."Original Quantity", ReqLine.Quantity),
            1, 250);

        TempExplanation."Why Text" := CopyStr(
            StrSubstNo('Both the timing and quantity of demand have changed. ' +
                '%1 %2 was due %3 for %4 units, but current requirements call for %5 units by %6. ' +
                'Date shift: %7 days. Quantity change: %8.',
                Format(ReqLine."Ref. Order Type"), ReqLine."Ref. Order No.",
                ReqLine."Original Due Date", ReqLine."Original Quantity",
                ReqLine.Quantity, ReqLine."Due Date",
                DaysDiff, QtyDiff),
            1, 500);

        TempExplanation."Impact Text" := CopyStr(
            StrSubstNo('This combined adjustment ensures supply matches the updated demand profile. ' +
                'Projected inventory near this date: %1 units. %2',
                LowestBefore,
                GetRiskStatement(LowestBefore, SafetyStock, ReorderPoint)),
            1, 500);

        BuildDetailText(TempExplanation, ReqLine, 0);
    end;

    local procedure GenerateCancelExplanation(
        var TempExplanation: Record "Planning Explanation" temporary;
        ReqLine: Record "Requisition Line";
        Item: Record Item
    )
    begin
        TempExplanation."Summary Text" := CopyStr(
            StrSubstNo('Cancel %1 %2 for %3 units due %4.',
                Format(ReqLine."Ref. Order Type"), ReqLine."Ref. Order No.",
                ReqLine.Quantity, ReqLine."Due Date"),
            1, 250);

        TempExplanation."Why Text" := CopyStr(
            StrSubstNo('%1 %2 for %3 units is no longer needed. ' +
                'The demand it was originally covering has been removed, fulfilled by other supply, or otherwise resolved.',
                Format(ReqLine."Ref. Order Type"), ReqLine."Ref. Order No.", ReqLine.Quantity),
            1, 500);

        TempExplanation."Impact Text" := CopyStr(
            StrSubstNo('Cancelling this order removes %1 units of excess supply. ' +
                'Keeping it would result in unnecessary inventory buildup.',
                ReqLine.Quantity),
            1, 500);

        BuildDetailText(TempExplanation, ReqLine, 0);
    end;

    local procedure FindLowestProjection(
        var TempEventBuffer: Record "Inventory Event Buffer" temporary;
        NearDate: Date;
        var LowestBefore: Decimal;
        var LowestBeforeDate: Date;
        var LowestAfter: Decimal
    )
    var
        SearchStart: Date;
        SearchEnd: Date;
        IsFirst: Boolean;
    begin
        SearchStart := CalcDate('<-14D>', NearDate);
        SearchEnd := CalcDate('<+14D>', NearDate);
        LowestBefore := 999999999;
        LowestAfter := 999999999;
        LowestBeforeDate := NearDate;
        IsFirst := true;

        TempEventBuffer.Reset();
        TempEventBuffer.SetCurrentKey("Event Date", "Entry No.");
        TempEventBuffer.SetRange("Event Date", SearchStart, SearchEnd);

        if TempEventBuffer.FindSet() then
            repeat
                if TempEventBuffer."Running Total Before" < LowestBefore then begin
                    LowestBefore := TempEventBuffer."Running Total Before";
                    LowestBeforeDate := TempEventBuffer."Event Date";
                end;
                if TempEventBuffer."Running Total After" < LowestAfter then
                    LowestAfter := TempEventBuffer."Running Total After";
            until TempEventBuffer.Next() = 0;

        // If no events found in range, check the last event before the range
        if LowestBefore = 999999999 then begin
            TempEventBuffer.Reset();
            TempEventBuffer.SetCurrentKey("Event Date", "Entry No.");
            TempEventBuffer.SetFilter("Event Date", '<%1', SearchStart);
            if TempEventBuffer.FindLast() then begin
                LowestBefore := TempEventBuffer."Running Total Before";
                LowestBeforeDate := TempEventBuffer."Event Date";
                LowestAfter := TempEventBuffer."Running Total After";
            end else begin
                LowestBefore := 0;
                LowestAfter := 0;
            end;
        end;

        TempEventBuffer.Reset();
    end;

    local procedure BuildDetailText(
        var TempExplanation: Record "Planning Explanation" temporary;
        ReqLine: Record "Requisition Line";
        LeadTimeDays: Integer
    )
    var
        Details: TextBuilder;
    begin
        Details.AppendLine(StrSubstNo('Action: %1', Format(ReqLine."Action Message")));
        Details.AppendLine(StrSubstNo('Item: %1', ReqLine."No."));
        Details.AppendLine(StrSubstNo('Quantity: %1', ReqLine.Quantity));
        Details.AppendLine(StrSubstNo('Due Date: %1', ReqLine."Due Date"));
        Details.AppendLine(StrSubstNo('Replenishment: %1', Format(ReqLine."Replenishment System")));

        if ReqLine."Ref. Order No." <> '' then
            Details.AppendLine(StrSubstNo('Related Order: %1 %2',
                Format(ReqLine."Ref. Order Type"), ReqLine."Ref. Order No."));

        if ReqLine."Original Due Date" <> 0D then
            Details.AppendLine(StrSubstNo('Original Due Date: %1', ReqLine."Original Due Date"));

        if ReqLine."Original Quantity" <> 0 then
            Details.AppendLine(StrSubstNo('Original Quantity: %1', ReqLine."Original Quantity"));

        if LeadTimeDays > 0 then
            Details.AppendLine(StrSubstNo('Lead Time: %1 days', LeadTimeDays));

        if ReqLine."Vendor No." <> '' then
            Details.AppendLine(StrSubstNo('Vendor: %1', ReqLine."Vendor No."));

        Details.AppendLine('');
        Details.AppendLine(StrSubstNo('Reason: %1', TempExplanation."Why Text"));
        Details.AppendLine('');
        Details.AppendLine(StrSubstNo('Impact: %1', TempExplanation."Impact Text"));

        TempExplanation."Detail Text" := CopyStr(Details.ToText(), 1, 2048);
    end;

    local procedure GetRiskDescription(ProjectedQty: Decimal; SafetyStock: Decimal): Text[100]
    begin
        if ProjectedQty < 0 then
            exit('a stockout condition')
        else if ProjectedQty < SafetyStock then
            exit('falling below Safety Stock')
        else
            exit('reduced buffer against demand variability');
    end;

    local procedure GetRiskStatement(ProjectedQty: Decimal; SafetyStock: Decimal; ReorderPoint: Decimal): Text[200]
    begin
        if ProjectedQty < 0 then
            exit('This is critical: a stockout is projected without action.')
        else if ProjectedQty < SafetyStock then
            exit(StrSubstNo('Inventory would be below Safety Stock (%1), increasing stockout risk.', SafetyStock))
        else if ProjectedQty < ReorderPoint then
            exit(StrSubstNo('Inventory would be below Reorder Point (%1).', ReorderPoint))
        else
            exit('Inventory levels are within acceptable range.');
    end;

    local procedure GetTimingImpact(DaysDiff: Integer): Text[50]
    begin
        if DaysDiff > 0 then
            exit(StrSubstNo('too early (by %1 days)', Abs(DaysDiff)))
        else
            exit(StrSubstNo('too late (by %1 days)', Abs(DaysDiff)));
    end;

    local procedure GetTimingConsequence(DaysDiff: Integer; ProjectedQty: Decimal; SafetyStock: Decimal): Text[100]
    begin
        if DaysDiff > 0 then
            exit('excess inventory tying up capital')
        else begin
            if ProjectedQty < SafetyStock then
                exit('a temporary stockout risk before the delayed supply arrives')
            else
                exit('a gap between demand and supply timing');
        end;
    end;

    local procedure LowerCase(InputText: Text): Text
    begin
        exit(InputText.ToLower());
    end;
}
