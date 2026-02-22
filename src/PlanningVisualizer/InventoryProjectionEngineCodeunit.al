codeunit 50161 "Inventory Projection Engine"
{
    // Calculates running inventory totals (before/after suggestions) and reads planning parameters

    procedure CalculateProjections(
        var TempEventBuffer: Record "Visualizer Event Buffer" temporary
    )
    var
        RunningBefore: Decimal;
        RunningAfter: Decimal;
    begin
        RunningBefore := 0;
        RunningAfter := 0;

        TempEventBuffer.Reset();
        TempEventBuffer.SetCurrentKey("Event Date", "Entry No.");

        // Single pass: calculate both projections
        if TempEventBuffer.FindSet() then
            repeat
                // Informational events (e.g. demand forecast) are displayed but
                // excluded from running totals to avoid double-counting
                if not TempEventBuffer."Is Informational" then begin
                    // "After" includes all non-informational events
                    RunningAfter += TempEventBuffer.Quantity;

                    // "Before" also excludes planning suggestions
                    if not TempEventBuffer."Is Suggestion" then
                        RunningBefore += TempEventBuffer.Quantity;
                end;

                TempEventBuffer."Running Total Before" := RunningBefore;
                TempEventBuffer."Running Total After" := RunningAfter;
                TempEventBuffer.Modify();
            until TempEventBuffer.Next() = 0;
    end;

    procedure GetPlanningParameters(
        ItemNo: Code[20];
        LocationCode: Code[10];
        VariantCode: Code[10];
        var ReorderPoint: Decimal;
        var SafetyStock: Decimal;
        var MaxInventory: Decimal;
        var ReorderingPolicyText: Text[50];
        var ReorderQty: Decimal;
        var LeadTimeDays: Integer;
        var DampenerPeriodText: Text[20];
        var DampenerQty: Decimal;
        var TimeBucketText: Text[20];
        var LotAccumPeriodText: Text[20]
    )
    var
        Item: Record Item;
        SKU: Record "Stockkeeping Unit";
        LeadTimeFormula: DateFormula;
        BaseDate: Date;
    begin
        if not Item.Get(ItemNo) then
            exit;

        // Try SKU first, fall back to Item
        if (LocationCode <> '') and SKU.Get(LocationCode, ItemNo, VariantCode) then begin
            ReorderPoint := SKU."Reorder Point";
            SafetyStock := SKU."Safety Stock Quantity";
            MaxInventory := SKU."Maximum Inventory";
            ReorderingPolicyText := Format(SKU."Reordering Policy");
            ReorderQty := SKU."Reorder Quantity";
            DampenerQty := SKU."Dampener Quantity";
            DampenerPeriodText := Format(SKU."Dampener Period");
            TimeBucketText := Format(SKU."Time Bucket");
            LotAccumPeriodText := Format(SKU."Lot Accumulation Period");

            LeadTimeFormula := SKU."Lead Time Calculation";
            if Format(LeadTimeFormula) <> '' then begin
                BaseDate := Today();
                LeadTimeDays := CalcDate(LeadTimeFormula, BaseDate) - BaseDate;
            end else begin
                LeadTimeFormula := Item."Lead Time Calculation";
                if Format(LeadTimeFormula) <> '' then begin
                    BaseDate := Today();
                    LeadTimeDays := CalcDate(LeadTimeFormula, BaseDate) - BaseDate;
                end;
            end;
        end else begin
            ReorderPoint := Item."Reorder Point";
            SafetyStock := Item."Safety Stock Quantity";
            MaxInventory := Item."Maximum Inventory";
            ReorderingPolicyText := Format(Item."Reordering Policy");
            ReorderQty := Item."Reorder Quantity";
            DampenerQty := Item."Dampener Quantity";
            DampenerPeriodText := Format(Item."Dampener Period");
            TimeBucketText := Format(Item."Time Bucket");
            LotAccumPeriodText := Format(Item."Lot Accumulation Period");

            LeadTimeFormula := Item."Lead Time Calculation";
            if Format(LeadTimeFormula) <> '' then begin
                BaseDate := Today();
                LeadTimeDays := CalcDate(LeadTimeFormula, BaseDate) - BaseDate;
            end;
        end;
    end;
}
