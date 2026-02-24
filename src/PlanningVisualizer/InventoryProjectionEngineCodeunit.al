codeunit 50161 "Inventory Projection Engine"
{
    // Calculates three running inventory totals and reads planning parameters
    //   PAB (Before)     = actual supply/demand only (excludes forecast + suggestions)
    //   Forecasted        = actual + forecast (excludes suggestions)
    //   Suggested (After) = actual + forecast + suggestions (everything)

    procedure CalculateProjections(
        var TempEventBuffer: Record "Visualizer Event Buffer" temporary
    )
    var
        RunningPAB: Decimal;
        RunningForecasted: Decimal;
        RunningSuggested: Decimal;
    begin
        RunningPAB := 0;
        RunningForecasted := 0;
        RunningSuggested := 0;

        TempEventBuffer.Reset();
        TempEventBuffer.SetCurrentKey("Event Date", "Entry No.");

        // Single pass: calculate all three projections
        if TempEventBuffer.FindSet() then
            repeat
                // Suggested Projected Inventory = everything (actual + forecast + suggestions)
                RunningSuggested += TempEventBuffer.Quantity;

                // Forecasted Projected Inventory = actual + forecast (excludes suggestions)
                if not TempEventBuffer."Is Suggestion" then
                    RunningForecasted += TempEventBuffer.Quantity;

                // Projected Available Balance = actual only (excludes forecast + suggestions)
                if (not TempEventBuffer."Is Informational") and
                   (not TempEventBuffer."Is Suggestion") then
                    RunningPAB += TempEventBuffer.Quantity;

                TempEventBuffer."Running Total Before" := RunningPAB;
                TempEventBuffer."Running Total Forecasted" := RunningForecasted;
                TempEventBuffer."Running Total After" := RunningSuggested;
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
