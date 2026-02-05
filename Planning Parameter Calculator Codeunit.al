codeunit 50112 "Planning Parameter Calculator"
{
    // Calculates suggested planning parameters based on demand history and statistical analysis

    procedure CalculateSuggestions(ItemNo: Code[20]; var TempDemandHistory: Record "Demand History Staging" temporary; MAE: Decimal; MAPE: Decimal; DemandPattern: Enum "Item Demand Pattern"; var Suggestion: Record "Planning Parameter Suggestion")
    var
        Item: Record Item;
        Setup: Record "Planning Analysis Setup";
        DataCollector: Codeunit "Planning Data Collector";
        AvgDailyDemand: Decimal;
        StdDevDemand: Decimal;
        TotalDemand: Decimal;
        LeadTimeDays: Integer;
        ReviewPeriodDays: Integer;
        AnalysisDays: Integer;
        UnitCost: Decimal;
    begin
        if not Item.Get(ItemNo) then
            Error('Item %1 not found.', ItemNo);

        Setup.GetSetup(Setup);

        // Get statistics from demand history (using calendar days for true daily average)
        DataCollector.CalculateStatistics(TempDemandHistory, Suggestion."Analysis Period Start", Suggestion."Analysis Period End", AvgDailyDemand, StdDevDemand, TotalDemand);

        // Determine lead time (SKU-specific if available)
        LeadTimeDays := GetLeadTimeDaysForSuggestion(Suggestion, Item, Setup);

        // Get review period from Time Bucket (SKU-specific if available)
        ReviewPeriodDays := GetReviewPeriodDaysForSuggestion(Suggestion, Item);

        // Get unit cost (SKU-specific if available)
        UnitCost := GetUnitCostForSuggestion(Suggestion, Item);

        // Calculate analysis period (calendar days, not just days with demand)
        AnalysisDays := Suggestion."Analysis Period End" - Suggestion."Analysis Period Start" + 1;
        if AnalysisDays <= 0 then
            AnalysisDays := 1;

        // Note: Current values should already be loaded by the caller (from Item or SKU)
        // Only set if not already set
        if Suggestion."Item No." = '' then
            Suggestion."Item No." := ItemNo;

        Suggestion."Demand Pattern" := DemandPattern;
        Suggestion."Forecast Accuracy MAE" := MAE;
        Suggestion."Forecast Accuracy MAPE" := MAPE;
        TempDemandHistory.Reset();
        Suggestion."Data Points Analyzed" := TempDemandHistory.Count(); // Actual days with demand

        // Calculate suggested values
        Suggestion."Suggested Reordering Policy" := CalculateReorderingPolicy(DemandPattern);
        Suggestion."Suggested Safety Stock" := CalculateSafetyStock(StdDevDemand, LeadTimeDays, ReviewPeriodDays, Setup."Safety Stock Multiplier", MAE);
        Suggestion."Suggested Reorder Point" := CalculateReorderPoint(AvgDailyDemand, LeadTimeDays, Suggestion."Suggested Safety Stock");
        Suggestion."Suggested Reorder Quantity" := CalculateEOQ(TotalDemand, AnalysisDays, UnitCost, Setup);
        Suggestion."Suggested Maximum Inventory" := CalculateMaximumInventory(Suggestion."Suggested Reorder Point", Suggestion."Suggested Reorder Quantity", DemandPattern, Setup);
        Suggestion."Suggested Lot Accum Period" := CalculateLotAccumPeriod(TotalDemand, AnalysisDays, Suggestion."Suggested Reorder Quantity");

        // Calculate confidence score
        Suggestion."Confidence Score" := CalculateConfidenceScore(AnalysisDays, Setup."Minimum Data Points", MAPE, DemandPattern, StdDevDemand, AvgDailyDemand);

        // Build calculation notes
        Suggestion."Calculation Notes" := BuildCalculationNotes(AvgDailyDemand, StdDevDemand, LeadTimeDays, ReviewPeriodDays, DemandPattern, Suggestion);
    end;

    local procedure GetLeadTimeDaysForSuggestion(Suggestion: Record "Planning Parameter Suggestion"; Item: Record Item; Setup: Record "Planning Analysis Setup"): Integer
    var
        SKU: Record "Stockkeeping Unit";
        LeadTimeFormula: DateFormula;
        BaseDate: Date;
        LeadDate: Date;
    begin
        // Try SKU first if this is a SKU-level suggestion
        if (Suggestion."Target Level" = Suggestion."Target Level"::SKU) and
           (Suggestion."Location Code" <> '') then begin
            if SKU.Get(Suggestion."Location Code", Suggestion."Item No.", Suggestion."Variant Code") then begin
                LeadTimeFormula := SKU."Lead Time Calculation";
                if Format(LeadTimeFormula) <> '' then begin
                    BaseDate := Today();
                    LeadDate := CalcDate(LeadTimeFormula, BaseDate);
                    exit(LeadDate - BaseDate);
                end;
            end;
        end;

        // Fall back to Item lead time
        LeadTimeFormula := Item."Lead Time Calculation";
        if Format(LeadTimeFormula) = '' then
            exit(Setup."Lead Time Days Default");

        BaseDate := Today();
        LeadDate := CalcDate(LeadTimeFormula, BaseDate);
        exit(LeadDate - BaseDate);
    end;

    local procedure GetUnitCostForSuggestion(Suggestion: Record "Planning Parameter Suggestion"; Item: Record Item): Decimal
    var
        SKU: Record "Stockkeeping Unit";
    begin
        // Try SKU first if this is a SKU-level suggestion
        if (Suggestion."Target Level" = Suggestion."Target Level"::SKU) and
           (Suggestion."Location Code" <> '') then begin
            if SKU.Get(Suggestion."Location Code", Suggestion."Item No.", Suggestion."Variant Code") then
                if SKU."Unit Cost" > 0 then
                    exit(SKU."Unit Cost");
        end;

        // Fall back to Item unit cost
        exit(Item."Unit Cost");
    end;

    local procedure GetReviewPeriodDaysForSuggestion(Suggestion: Record "Planning Parameter Suggestion"; Item: Record Item): Integer
    var
        SKU: Record "Stockkeeping Unit";
        TimeBucketFormula: DateFormula;
        BaseDate: Date;
        EndDate: Date;
    begin
        // Try SKU first if this is a SKU-level suggestion
        if (Suggestion."Target Level" = Suggestion."Target Level"::SKU) and
           (Suggestion."Location Code" <> '') then begin
            if SKU.Get(Suggestion."Location Code", Suggestion."Item No.", Suggestion."Variant Code") then begin
                TimeBucketFormula := SKU."Time Bucket";
                if Format(TimeBucketFormula) <> '' then begin
                    BaseDate := Today();
                    EndDate := CalcDate(TimeBucketFormula, BaseDate);
                    exit(EndDate - BaseDate);
                end;
            end;
        end;

        // Fall back to Item Time Bucket
        TimeBucketFormula := Item."Time Bucket";
        if Format(TimeBucketFormula) = '' then
            exit(7); // Default to weekly (7 days) if not specified

        BaseDate := Today();
        EndDate := CalcDate(TimeBucketFormula, BaseDate);
        exit(EndDate - BaseDate);
    end;

    local procedure GetLeadTimeDays(Item: Record Item; Setup: Record "Planning Analysis Setup"): Integer
    var
        LeadTimeFormula: DateFormula;
        BaseDate: Date;
        LeadDate: Date;
    begin
        LeadTimeFormula := Item."Lead Time Calculation";

        if Format(LeadTimeFormula) = '' then
            exit(Setup."Lead Time Days Default");

        BaseDate := Today();
        LeadDate := CalcDate(LeadTimeFormula, BaseDate);

        exit(LeadDate - BaseDate);
    end;

    local procedure CalculateReorderingPolicy(DemandPattern: Enum "Item Demand Pattern"): Enum "Reordering Policy"
    begin
        case DemandPattern of
            "Item Demand Pattern"::Stable:
                exit("Reordering Policy"::"Fixed Reorder Qty.");
            "Item Demand Pattern"::Seasonal:
                exit("Reordering Policy"::"Lot-for-Lot");
            "Item Demand Pattern"::Trending:
                exit("Reordering Policy"::"Maximum Qty.");
            "Item Demand Pattern"::Erratic, "Item Demand Pattern"::Intermittent:
                exit("Reordering Policy"::Order);
            else
                exit("Reordering Policy"::"Fixed Reorder Qty.");
        end;
    end;

    local procedure CalculateSafetyStock(StdDevDemand: Decimal; LeadTimeDays: Integer; ReviewPeriodDays: Integer; ZScore: Decimal; MAE: Decimal): Decimal
    var
        SafetyStock: Decimal;
        UncertaintyBuffer: Decimal;
    begin
        // Safety Stock = Z * σ * √(L + R)
        // R = Review Period (Time Bucket from Item/SKU)
        if ReviewPeriodDays <= 0 then
            ReviewPeriodDays := 7; // Default to weekly if not specified

        SafetyStock := ZScore * StdDevDemand * Power(LeadTimeDays + ReviewPeriodDays, 0.5);

        // Add buffer for forecast uncertainty
        UncertaintyBuffer := MAE * ZScore;
        SafetyStock += UncertaintyBuffer;

        // Ensure non-negative
        if SafetyStock < 0 then
            SafetyStock := 0;

        exit(Round(SafetyStock, 1));
    end;

    local procedure CalculateReorderPoint(AvgDailyDemand: Decimal; LeadTimeDays: Integer; SafetyStock: Decimal): Decimal
    var
        LeadTimeDemand: Decimal;
    begin
        // Reorder Point = (Average Daily Demand * Lead Time) + Safety Stock
        LeadTimeDemand := AvgDailyDemand * LeadTimeDays;

        exit(Round(LeadTimeDemand + SafetyStock, 1));
    end;

    local procedure CalculateEOQ(TotalDemand: Decimal; AnalysisDays: Integer; UnitCost: Decimal; Setup: Record "Planning Analysis Setup"): Decimal
    var
        AnnualDemand: Decimal;
        OrderCost: Decimal;
        HoldingCostRate: Decimal;
        HoldingCost: Decimal;
        EOQ: Decimal;
    begin
        // EOQ = √((2 * D * S) / H)
        if AnalysisDays <= 0 then
            AnalysisDays := 1;

        AnnualDemand := TotalDemand * (365 / AnalysisDays);
        OrderCost := Setup."Default Order Cost";
        HoldingCostRate := Setup."Holding Cost Rate" / 100;
        HoldingCost := UnitCost * HoldingCostRate;

        if HoldingCost <= 0 then begin
            // Fallback to monthly quantity
            exit(Round(AnnualDemand / 12, 1));
        end;

        EOQ := Power((2 * AnnualDemand * OrderCost) / HoldingCost, 0.5);

        // Ensure minimum reasonable quantity
        if EOQ < 1 then
            EOQ := Round(AnnualDemand / 12, 1);

        exit(Round(EOQ, 1));
    end;

    local procedure CalculateMaximumInventory(ReorderPoint: Decimal; ReorderQuantity: Decimal; DemandPattern: Enum "Item Demand Pattern"; Setup: Record "Planning Analysis Setup"): Decimal
    var
        MaxInventory: Decimal;
        PeakSeasonMultiplier: Decimal;
    begin
        MaxInventory := ReorderPoint + ReorderQuantity;

        // Apply seasonal adjustment if pattern is seasonal
        if DemandPattern = "Item Demand Pattern"::Seasonal then begin
            PeakSeasonMultiplier := Setup."Peak Season Multiplier";
            if PeakSeasonMultiplier <= 0 then
                PeakSeasonMultiplier := 1.3; // Fallback default
            MaxInventory := MaxInventory * PeakSeasonMultiplier;
        end;

        exit(Round(MaxInventory, 1));
    end;

    local procedure CalculateLotAccumPeriod(TotalDemand: Decimal; AnalysisDays: Integer; ReorderQuantity: Decimal): DateFormula
    var
        AnnualDemand: Decimal;
        OrdersPerYear: Decimal;
        AvgDaysBetweenOrders: Decimal;
        LotAccumPeriod: DateFormula;
    begin
        if AnalysisDays <= 0 then
            AnalysisDays := 1;

        AnnualDemand := TotalDemand * (365 / AnalysisDays);

        if ReorderQuantity <= 0 then begin
            Evaluate(LotAccumPeriod, '1M');
            exit(LotAccumPeriod);
        end;

        OrdersPerYear := AnnualDemand / ReorderQuantity;

        if OrdersPerYear <= 0 then begin
            Evaluate(LotAccumPeriod, '2M');
            exit(LotAccumPeriod);
        end;

        AvgDaysBetweenOrders := 365 / OrdersPerYear;

        case true of
            AvgDaysBetweenOrders <= 7:
                Evaluate(LotAccumPeriod, '1W');
            AvgDaysBetweenOrders <= 14:
                Evaluate(LotAccumPeriod, '2W');
            AvgDaysBetweenOrders <= 30:
                Evaluate(LotAccumPeriod, '1M');
            else
                Evaluate(LotAccumPeriod, '2M');
        end;

        exit(LotAccumPeriod);
    end;

    local procedure CalculateConfidenceScore(DataPoints: Integer; MinDataPoints: Integer; MAPE: Decimal; DemandPattern: Enum "Item Demand Pattern"; StdDev: Decimal; AvgDemand: Decimal): Decimal
    var
        DataQualityScore: Decimal;
        ForecastAccuracyScore: Decimal;
        PatternClarityScore: Decimal;
        StabilityScore: Decimal;
        CoefficientOfVariation: Decimal;
        TotalScore: Decimal;
    begin
        // Data Quality (max 25 points)
        if DataPoints >= MinDataPoints * 3 then
            DataQualityScore := 25
        else
            DataQualityScore := (DataPoints / (MinDataPoints * 3)) * 25;

        // Forecast Accuracy (max 40 points)
        if MAPE >= 100 then
            ForecastAccuracyScore := 0
        else
            ForecastAccuracyScore := (1 - (MAPE / 100)) * 40;

        // Pattern Clarity (max 20 points)
        case DemandPattern of
            "Item Demand Pattern"::Stable:
                PatternClarityScore := 20;
            "Item Demand Pattern"::Seasonal, "Item Demand Pattern"::Trending:
                PatternClarityScore := 15;
            "Item Demand Pattern"::Intermittent:
                PatternClarityScore := 10;
            "Item Demand Pattern"::Erratic:
                PatternClarityScore := 5;
            else
                PatternClarityScore := 10;
        end;

        // Historical Stability (max 15 points)
        if AvgDemand > 0 then begin
            CoefficientOfVariation := StdDev / AvgDemand;
            if CoefficientOfVariation > 1 then
                CoefficientOfVariation := 1;
            StabilityScore := (1 - CoefficientOfVariation) * 15;
        end else
            StabilityScore := 0;

        TotalScore := DataQualityScore + ForecastAccuracyScore + PatternClarityScore + StabilityScore;

        // Clamp to 0-100
        if TotalScore < 0 then
            TotalScore := 0;
        if TotalScore > 100 then
            TotalScore := 100;

        exit(Round(TotalScore, 1));
    end;

    local procedure BuildCalculationNotes(AvgDailyDemand: Decimal; StdDevDemand: Decimal; LeadTimeDays: Integer; ReviewPeriodDays: Integer; DemandPattern: Enum "Item Demand Pattern"; Suggestion: Record "Planning Parameter Suggestion"): Text[2048]
    var
        Notes: TextBuilder;
    begin
        Notes.AppendLine('=== Planning Parameter Analysis ===');
        Notes.AppendLine('');
        Notes.AppendLine('--- Input Values ---');
        Notes.AppendLine(StrSubstNo('Average Daily Demand: %1', Round(AvgDailyDemand, 0.01)));
        Notes.AppendLine(StrSubstNo('Demand Std Deviation (σ): %1', Round(StdDevDemand, 0.01)));
        Notes.AppendLine(StrSubstNo('Lead Time (L): %1 days [from Item/SKU Lead Time Calculation]', LeadTimeDays));
        Notes.AppendLine(StrSubstNo('Review Period (R): %1 days [from Item/SKU Time Bucket]', ReviewPeriodDays));
        Notes.AppendLine(StrSubstNo('Detected Pattern: %1', DemandPattern));
        Notes.AppendLine('');
        Notes.AppendLine('--- Safety Stock Formula ---');
        Notes.AppendLine('Safety Stock = (Z × σ × √(L + R)) + (MAE × Z)');
        Notes.AppendLine('Where:');
        Notes.AppendLine('  Z = Service Level Z-Score [from Setup.Safety Stock Multiplier]');
        Notes.AppendLine('  σ = Std Deviation [from Item Ledger Entries, calendar-days method]');
        Notes.AppendLine('  L = Lead Time [from Item/SKU.Lead Time Calculation]');
        Notes.AppendLine('  R = Review Period [from Item/SKU.Time Bucket]');
        Notes.AppendLine('  MAE = Mean Absolute Error [estimated from σ]');
        Notes.AppendLine('');
        Notes.AppendLine('--- Reorder Point Formula ---');
        Notes.AppendLine('Reorder Point = (AvgDailyDemand × L) + Safety Stock');
        Notes.AppendLine('Where:');
        Notes.AppendLine('  AvgDailyDemand = TotalDemand / CalendarDays [from Item Ledger Entries]');
        Notes.AppendLine('  L = Lead Time [from Item/SKU.Lead Time Calculation]');
        Notes.AppendLine('  Safety Stock = Calculated above');
        Notes.AppendLine('');
        Notes.AppendLine('--- Reorder Quantity (EOQ) Formula ---');
        Notes.AppendLine('EOQ = √((2 × D × S) / H)');
        Notes.AppendLine('Where:');
        Notes.AppendLine('  D = Annual Demand [TotalDemand × (365 / CalendarDays) from Item Ledger Entries]');
        Notes.AppendLine('  S = Order Cost [from Setup.Default Order Cost]');
        Notes.AppendLine('  H = Holding Cost [Item.Unit Cost × Setup.Holding Cost Rate / 100]');
        Notes.AppendLine('');
        Notes.AppendLine('--- Maximum Inventory Formula ---');
        Notes.AppendLine('Maximum Inventory = Reorder Point + Reorder Quantity');
        Notes.AppendLine('Seasonal Adjustment (when Demand Pattern = Seasonal):');
        Notes.AppendLine('  Maximum Inventory = (Reorder Point + Reorder Quantity) × Peak Season Multiplier');
        Notes.AppendLine('Where:');
        Notes.AppendLine('  Reorder Point = Calculated above');
        Notes.AppendLine('  Reorder Quantity = Calculated above (EOQ)');
        Notes.AppendLine('  Peak Season Multiplier [from Setup.Peak Season Multiplier, default 1.3]');
        Notes.AppendLine('');
        Notes.AppendLine('--- Lot Accumulation Period Formula ---');
        Notes.AppendLine('AvgDaysBetweenOrders = 365 / (AnnualDemand / ReorderQuantity)');
        Notes.AppendLine('Mapping:');
        Notes.AppendLine('  ≤7 days → 1W | ≤14 days → 2W | ≤30 days → 1M | >30 days → 2M');
        Notes.AppendLine('Where:');
        Notes.AppendLine('  AnnualDemand [from Item Ledger Entries × (365 / CalendarDays)]');
        Notes.AppendLine('  ReorderQuantity = Calculated above (EOQ)');
        Notes.AppendLine('');
        Notes.AppendLine('--- Recommendations ---');
        Notes.AppendLine('');

        case DemandPattern of
            "Item Demand Pattern"::Stable:
                Notes.AppendLine('Stable demand supports fixed reorder quantities with predictable safety stock levels.');
            "Item Demand Pattern"::Seasonal:
                Notes.AppendLine('Seasonal patterns require dynamic lot sizing. Consider reviewing parameters before peak seasons.');
            "Item Demand Pattern"::Trending:
                Notes.AppendLine('Trending demand benefits from maximum inventory ceilings to accommodate growth/decline.');
            "Item Demand Pattern"::Erratic, "Item Demand Pattern"::Intermittent:
                Notes.AppendLine('Unpredictable demand suggests order-based policy. Higher safety stock recommended.');
        end;

        Notes.AppendLine('');
        Notes.AppendLine(StrSubstNo('Confidence Score: %1%', Suggestion."Confidence Score"));

        if Suggestion."Confidence Score" < 75 then
            Notes.AppendLine('LOW CONFIDENCE: Review suggestions carefully before applying.');

        exit(CopyStr(Notes.ToText(), 1, 2048));
    end;
}
