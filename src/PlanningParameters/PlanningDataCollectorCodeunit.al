codeunit 50110 "Planning Data Collector"
{
    // Collects historical demand data from various sources for planning parameter analysis

    procedure CollectDemandHistory(ItemNo: Code[20]; StartDate: Date; EndDate: Date; LocationCode: Code[10]; var TempDemandHistory: Record "Demand History Staging" temporary): Boolean
    var
        Setup: Record "Planning Analysis Setup";
        DataQualityScore: Decimal;
    begin
        // Validate inputs
        if ItemNo = '' then
            Error('Item No. is required.');

        if EndDate < StartDate then
            Error('End Date must be greater than or equal to Start Date.');

        if (EndDate - StartDate) < 30 then
            Error('Analysis period must be at least 30 days.');

        // Clear staging table
        TempDemandHistory.Reset();
        TempDemandHistory.DeleteAll();

        // Collect from all sources
        CollectSalesDemand(ItemNo, StartDate, EndDate, LocationCode, TempDemandHistory);
        CollectConsumptionDemand(ItemNo, StartDate, EndDate, LocationCode, TempDemandHistory);
        CollectTransferDemand(ItemNo, StartDate, EndDate, LocationCode, TempDemandHistory);
        CollectNegativeAdjustments(ItemNo, StartDate, EndDate, LocationCode, TempDemandHistory);
        CollectAssemblyConsumption(ItemNo, StartDate, EndDate, LocationCode, TempDemandHistory);

        // Aggregate by date
        AggregateDemandByDate(ItemNo, TempDemandHistory);

        // Validate data quality
        Setup.GetSetup(Setup);
        if not ValidateDataQuality(TempDemandHistory, Setup."Minimum Data Points", DataQualityScore) then
            exit(false);

        exit(true);
    end;

    local procedure CollectSalesDemand(ItemNo: Code[20]; StartDate: Date; EndDate: Date; LocationCode: Code[10]; var TempDemandHistory: Record "Demand History Staging" temporary)
    var
        ItemLedgerEntry: Record "Item Ledger Entry";
    begin
        ItemLedgerEntry.SetRange("Item No.", ItemNo);
        ItemLedgerEntry.SetRange("Entry Type", ItemLedgerEntry."Entry Type"::Sale);
        ItemLedgerEntry.SetRange("Posting Date", StartDate, EndDate);
        if LocationCode <> '' then
            ItemLedgerEntry.SetRange("Location Code", LocationCode);

        if ItemLedgerEntry.FindSet() then
            repeat
                InsertDemandRecord(
                    TempDemandHistory,
                    ItemNo,
                    ItemLedgerEntry."Posting Date",
                    "Demand Source Type"::Sales,
                    ItemLedgerEntry."Document No.",
                    Abs(ItemLedgerEntry.Quantity),
                    ItemLedgerEntry."Location Code",
                    ItemLedgerEntry."Variant Code",
                    ItemLedgerEntry."Cost Amount (Actual)" / Abs(ItemLedgerEntry.Quantity),
                    ItemLedgerEntry."Sales Amount (Actual)" / Abs(ItemLedgerEntry.Quantity)
                );
            until ItemLedgerEntry.Next() = 0;
    end;

    local procedure CollectConsumptionDemand(ItemNo: Code[20]; StartDate: Date; EndDate: Date; LocationCode: Code[10]; var TempDemandHistory: Record "Demand History Staging" temporary)
    var
        ItemLedgerEntry: Record "Item Ledger Entry";
    begin
        ItemLedgerEntry.SetRange("Item No.", ItemNo);
        ItemLedgerEntry.SetRange("Entry Type", ItemLedgerEntry."Entry Type"::Consumption);
        ItemLedgerEntry.SetRange("Posting Date", StartDate, EndDate);
        if LocationCode <> '' then
            ItemLedgerEntry.SetRange("Location Code", LocationCode);

        if ItemLedgerEntry.FindSet() then
            repeat
                InsertDemandRecord(
                    TempDemandHistory,
                    ItemNo,
                    ItemLedgerEntry."Posting Date",
                    "Demand Source Type"::Consumption,
                    ItemLedgerEntry."Document No.",
                    Abs(ItemLedgerEntry.Quantity),
                    ItemLedgerEntry."Location Code",
                    ItemLedgerEntry."Variant Code",
                    Abs(ItemLedgerEntry."Cost Amount (Actual)" / ItemLedgerEntry.Quantity),
                    0
                );
            until ItemLedgerEntry.Next() = 0;
    end;

    local procedure CollectTransferDemand(ItemNo: Code[20]; StartDate: Date; EndDate: Date; LocationCode: Code[10]; var TempDemandHistory: Record "Demand History Staging" temporary)
    var
        ItemLedgerEntry: Record "Item Ledger Entry";
    begin
        ItemLedgerEntry.SetRange("Item No.", ItemNo);
        ItemLedgerEntry.SetRange("Entry Type", ItemLedgerEntry."Entry Type"::Transfer);
        ItemLedgerEntry.SetFilter(Quantity, '<0'); // Outbound transfers only
        ItemLedgerEntry.SetRange("Posting Date", StartDate, EndDate);
        if LocationCode <> '' then
            ItemLedgerEntry.SetRange("Location Code", LocationCode);

        if ItemLedgerEntry.FindSet() then
            repeat
                InsertDemandRecord(
                    TempDemandHistory,
                    ItemNo,
                    ItemLedgerEntry."Posting Date",
                    "Demand Source Type"::Transfer,
                    ItemLedgerEntry."Document No.",
                    Abs(ItemLedgerEntry.Quantity),
                    ItemLedgerEntry."Location Code",
                    ItemLedgerEntry."Variant Code",
                    0,
                    0
                );
            until ItemLedgerEntry.Next() = 0;
    end;

    local procedure CollectNegativeAdjustments(ItemNo: Code[20]; StartDate: Date; EndDate: Date; LocationCode: Code[10]; var TempDemandHistory: Record "Demand History Staging" temporary)
    var
        ItemLedgerEntry: Record "Item Ledger Entry";
    begin
        ItemLedgerEntry.SetRange("Item No.", ItemNo);
        ItemLedgerEntry.SetRange("Entry Type", ItemLedgerEntry."Entry Type"::"Negative Adjmt.");
        ItemLedgerEntry.SetRange("Posting Date", StartDate, EndDate);
        if LocationCode <> '' then
            ItemLedgerEntry.SetRange("Location Code", LocationCode);

        if ItemLedgerEntry.FindSet() then
            repeat
                InsertDemandRecord(
                    TempDemandHistory,
                    ItemNo,
                    ItemLedgerEntry."Posting Date",
                    "Demand Source Type"::Adjustment,
                    ItemLedgerEntry."Document No.",
                    Abs(ItemLedgerEntry.Quantity),
                    ItemLedgerEntry."Location Code",
                    ItemLedgerEntry."Variant Code",
                    0,
                    0
                );
            until ItemLedgerEntry.Next() = 0;
    end;

    local procedure CollectAssemblyConsumption(ItemNo: Code[20]; StartDate: Date; EndDate: Date; LocationCode: Code[10]; var TempDemandHistory: Record "Demand History Staging" temporary)
    var
        ItemLedgerEntry: Record "Item Ledger Entry";
    begin
        ItemLedgerEntry.SetRange("Item No.", ItemNo);
        ItemLedgerEntry.SetRange("Entry Type", ItemLedgerEntry."Entry Type"::"Assembly Consumption");
        ItemLedgerEntry.SetRange("Posting Date", StartDate, EndDate);
        if LocationCode <> '' then
            ItemLedgerEntry.SetRange("Location Code", LocationCode);

        if ItemLedgerEntry.FindSet() then
            repeat
                InsertDemandRecord(
                    TempDemandHistory,
                    ItemNo,
                    ItemLedgerEntry."Posting Date",
                    "Demand Source Type"::Assembly,
                    ItemLedgerEntry."Document No.",
                    Abs(ItemLedgerEntry.Quantity),
                    ItemLedgerEntry."Location Code",
                    ItemLedgerEntry."Variant Code",
                    0,
                    0
                );
            until ItemLedgerEntry.Next() = 0;
    end;

    local procedure InsertDemandRecord(var TempDemandHistory: Record "Demand History Staging" temporary; ItemNo: Code[20]; DemandDate: Date; SourceType: Enum "Demand Source Type"; SourceNo: Code[20]; Quantity: Decimal; LocationCode: Code[10]; VariantCode: Code[10]; UnitCost: Decimal; UnitPrice: Decimal)
    begin
        TempDemandHistory.Init();
        TempDemandHistory."Item No." := ItemNo;
        TempDemandHistory."Demand Date" := DemandDate;
        TempDemandHistory."Source Type" := SourceType;
        TempDemandHistory."Source No." := SourceNo;
        TempDemandHistory.Quantity := Quantity;
        TempDemandHistory."Location Code" := LocationCode;
        TempDemandHistory."Variant Code" := VariantCode;
        TempDemandHistory."Unit Cost" := UnitCost;
        TempDemandHistory."Unit Price" := UnitPrice;

        if not TempDemandHistory.Insert() then
            // If duplicate key, add to existing quantity
            if TempDemandHistory.Get(ItemNo, DemandDate, SourceType, SourceNo) then begin
                TempDemandHistory.Quantity += Quantity;
                TempDemandHistory.Modify();
            end;
    end;

    local procedure AggregateDemandByDate(ItemNo: Code[20]; var TempDemandHistory: Record "Demand History Staging" temporary)
    var
        TempAggregated: Record "Demand History Staging" temporary;
        CurrentDate: Date;
        TotalQty: Decimal;
    begin
        // Create aggregated version
        TempDemandHistory.Reset();
        TempDemandHistory.SetRange("Item No.", ItemNo);
        if not TempDemandHistory.FindSet() then
            exit;

        CurrentDate := 0D;
        TotalQty := 0;

        repeat
            if (CurrentDate <> 0D) and (TempDemandHistory."Demand Date" <> CurrentDate) then begin
                // Save previous date's total
                TempAggregated.Init();
                TempAggregated."Item No." := ItemNo;
                TempAggregated."Demand Date" := CurrentDate;
                TempAggregated."Source Type" := "Demand Source Type"::Sales; // Aggregated
                TempAggregated."Source No." := 'AGGREGATED';
                TempAggregated.Quantity := TotalQty;
                TempAggregated.Insert();
                TotalQty := 0;
            end;

            CurrentDate := TempDemandHistory."Demand Date";
            TotalQty += TempDemandHistory.Quantity;
        until TempDemandHistory.Next() = 0;

        // Don't forget the last date
        if CurrentDate <> 0D then begin
            TempAggregated.Init();
            TempAggregated."Item No." := ItemNo;
            TempAggregated."Demand Date" := CurrentDate;
            TempAggregated."Source Type" := "Demand Source Type"::Sales;
            TempAggregated."Source No." := 'AGGREGATED';
            TempAggregated.Quantity := TotalQty;
            TempAggregated.Insert();
        end;

        // Replace original with aggregated
        TempDemandHistory.Reset();
        TempDemandHistory.DeleteAll();

        if TempAggregated.FindSet() then
            repeat
                TempDemandHistory := TempAggregated;
                TempDemandHistory.Insert();
            until TempAggregated.Next() = 0;
    end;

    local procedure ValidateDataQuality(var TempDemandHistory: Record "Demand History Staging" temporary; MinDataPoints: Integer; var DataQualityScore: Decimal): Boolean
    var
        RecordCount: Integer;
        ZeroDemandCount: Integer;
        TotalQuantity: Decimal;
        AvgQuantity: Decimal;
    begin
        TempDemandHistory.Reset();
        RecordCount := TempDemandHistory.Count();

        if RecordCount < MinDataPoints then begin
            DataQualityScore := 0;
            exit(false);
        end;

        // Count zero demand days and calculate total
        if TempDemandHistory.FindSet() then
            repeat
                TotalQuantity += TempDemandHistory.Quantity;
                if TempDemandHistory.Quantity = 0 then
                    ZeroDemandCount += 1;
            until TempDemandHistory.Next() = 0;

        // Check for too many zero demand days (>30%)
        if (ZeroDemandCount / RecordCount) > 0.3 then begin
            DataQualityScore := 50; // Low quality but usable
        end else begin
            DataQualityScore := 100 - ((ZeroDemandCount / RecordCount) * 100);
        end;

        // Check for constant demand (std dev = 0)
        AvgQuantity := TotalQuantity / RecordCount;
        if AvgQuantity = 0 then begin
            DataQualityScore := 0;
            exit(false);
        end;

        exit(true);
    end;

    procedure GetDataPointCount(var TempDemandHistory: Record "Demand History Staging" temporary): Integer
    begin
        TempDemandHistory.Reset();
        exit(TempDemandHistory.Count());
    end;

    procedure CalculateStatistics(var TempDemandHistory: Record "Demand History Staging" temporary; StartDate: Date; EndDate: Date; var AvgDailyDemand: Decimal; var StdDevDemand: Decimal; var TotalDemand: Decimal)
    var
        CalendarDays: Integer;
        RecordCount: Integer;
        SumSquaredDiff: Decimal;
        Diff: Decimal;
    begin
        TempDemandHistory.Reset();
        RecordCount := TempDemandHistory.Count();
        TotalDemand := 0;
        AvgDailyDemand := 0;
        StdDevDemand := 0;

        // Calculate actual calendar days in the analysis period
        CalendarDays := EndDate - StartDate + 1;
        if CalendarDays <= 0 then
            CalendarDays := 1;

        if RecordCount = 0 then
            exit;

        // Calculate total demand
        if TempDemandHistory.FindSet() then
            repeat
                TotalDemand += TempDemandHistory.Quantity;
            until TempDemandHistory.Next() = 0;

        // Average daily demand uses calendar days (true daily average)
        AvgDailyDemand := TotalDemand / CalendarDays;

        // Standard deviation uses calendar days (includes zero-demand days for accurate safety stock)
        if CalendarDays > 1 then begin
            // Sum squared differences for days WITH demand
            TempDemandHistory.FindSet();
            repeat
                Diff := TempDemandHistory.Quantity - AvgDailyDemand;
                SumSquaredDiff += Diff * Diff;
            until TempDemandHistory.Next() = 0;

            // Add squared differences for days WITHOUT demand (quantity = 0)
            // Zero-demand days: (0 - AvgDailyDemand)² = AvgDailyDemand²
            SumSquaredDiff += (CalendarDays - RecordCount) * AvgDailyDemand * AvgDailyDemand;

            StdDevDemand := Power(SumSquaredDiff / (CalendarDays - 1), 0.5);
        end;
    end;
}
