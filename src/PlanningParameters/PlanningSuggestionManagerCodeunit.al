codeunit 50113 "Planning Suggestion Manager"
{
    // Main orchestrator for planning parameter suggestion generation and application
    // Uses local statistical calculations (no external API required)

    procedure GenerateSuggestionForItem(ItemNo: Code[20]; LocationCode: Code[10]): Integer
    begin
        // Overload: defaults to Item level when no location, SKU level when location provided
        if LocationCode = '' then
            exit(GenerateSuggestion(ItemNo, LocationCode, '', false))
        else
            exit(GenerateSuggestion(ItemNo, LocationCode, '', true));
    end;

    procedure GenerateSuggestionForSKU(ItemNo: Code[20]; LocationCode: Code[10]; VariantCode: Code[10]): Integer
    begin
        if LocationCode = '' then
            Error('Location Code is required for SKU-level suggestions.');

        exit(GenerateSuggestion(ItemNo, LocationCode, VariantCode, true));
    end;

    procedure GenerateSuggestion(ItemNo: Code[20]; LocationCode: Code[10]; VariantCode: Code[10]; ForSKU: Boolean): Integer
    var
        Item: Record Item;
        Setup: Record "Planning Analysis Setup";
        Suggestion: Record "Planning Parameter Suggestion";
        TempDemandHistory: Record "Demand History Staging" temporary;
        DataCollector: Codeunit "Planning Data Collector";
        Calculator: Codeunit "Planning Parameter Calculator";
        StartDate: Date;
        EndDate: Date;
        AvgDailyDemand: Decimal;
        StdDevDemand: Decimal;
        TotalDemand: Decimal;
        MAE: Decimal;
        MAPE: Decimal;
        DemandPattern: Enum "Item Demand Pattern";
        TargetLevel: Option Item,SKU;
    begin
        // Validate item
        if not Item.Get(ItemNo) then
            Error('Item %1 not found.', ItemNo);

        if Item.Blocked then
            Error('Item %1 is blocked.', ItemNo);

        // Determine target level
        if ForSKU and (LocationCode <> '') then
            TargetLevel := TargetLevel::SKU
        else
            TargetLevel := TargetLevel::Item;

        Setup.GetSetup(Setup);

        // Calculate date range
        EndDate := Today();
        StartDate := CalcDate(StrSubstNo('<-%1M>', Setup."Default Analysis Months"), EndDate);

        // Collect demand history (location-filtered for SKU level)
        if not DataCollector.CollectDemandHistory(ItemNo, StartDate, EndDate, LocationCode, TempDemandHistory) then begin
            CreateFailedSuggestion(ItemNo, LocationCode, VariantCode, TargetLevel, 'Insufficient demand history for analysis.');
            Error('Insufficient demand history for item %1 at location %2. Minimum %3 data points required.', ItemNo, LocationCode, Setup."Minimum Data Points");
        end;

        // Calculate statistics locally (using calendar days for true daily average)
        DataCollector.CalculateStatistics(TempDemandHistory, StartDate, EndDate, AvgDailyDemand, StdDevDemand, TotalDemand);

        // Determine demand pattern from statistics
        DemandPattern := CalculateDemandPattern(AvgDailyDemand, StdDevDemand, TempDemandHistory);

        // Calculate MAE/MAPE from historical variability (no forecast comparison)
        CalculateAccuracyMetrics(AvgDailyDemand, StdDevDemand, MAE, MAPE);

        // Create suggestion record
        Suggestion.Init();
        Suggestion."Item No." := ItemNo;
        Suggestion."Location Code" := LocationCode;
        Suggestion."Variant Code" := VariantCode;
        Suggestion."Target Level" := TargetLevel;
        Suggestion."Analysis Period Start" := StartDate;
        Suggestion."Analysis Period End" := EndDate;

        // Load current values from appropriate source
        if TargetLevel = TargetLevel::SKU then begin
            Suggestion.UpdateSKUExists();
            if Suggestion."SKU Exists" then
                Suggestion.LoadCurrentValuesFromSKU()
            else
                Suggestion.LoadCurrentValuesFromItem(); // Use Item as baseline for new SKU
            Suggestion."Create SKU If Missing" := true;
        end else
            Suggestion.LoadCurrentValuesFromItem();

        Calculator.CalculateSuggestions(ItemNo, TempDemandHistory, MAE, MAPE, DemandPattern, Suggestion);

        // Set initial status based on confidence
        if Suggestion."Confidence Score" >= Setup."Auto Apply Threshold" then
            Suggestion.Status := Suggestion.Status::Approved
        else
            Suggestion.Status := Suggestion.Status::Pending;

        Suggestion.Insert(true);

        // Update Item extension fields
        UpdateItemPlanningExtension(ItemNo, DemandPattern, Suggestion."Confidence Score");

        exit(Suggestion."Entry No.");
    end;

    local procedure CalculateDemandPattern(AvgDailyDemand: Decimal; StdDevDemand: Decimal; var TempDemandHistory: Record "Demand History Staging" temporary): Enum "Item Demand Pattern"
    var
        CoefficientOfVariation: Decimal;
        ZeroCount: Integer;
        TotalCount: Integer;
        ZeroRatio: Decimal;
        TrendSlope: Decimal;
    begin
        if AvgDailyDemand <= 0 then
            exit("Item Demand Pattern"::Intermittent);

        CoefficientOfVariation := StdDevDemand / AvgDailyDemand;

        // Count zero-demand periods for intermittent detection
        TempDemandHistory.Reset();
        if TempDemandHistory.FindSet() then
            repeat
                TotalCount += 1;
                if TempDemandHistory.Quantity = 0 then
                    ZeroCount += 1;
            until TempDemandHistory.Next() = 0;

        if TotalCount > 0 then
            ZeroRatio := ZeroCount / TotalCount;

        // Classify demand pattern
        if ZeroRatio > 0.3 then
            exit("Item Demand Pattern"::Intermittent);

        if CoefficientOfVariation > 0.5 then
            exit("Item Demand Pattern"::Erratic);

        // Check for trend (simplified linear trend analysis)
        TrendSlope := CalculateTrendSlope(TempDemandHistory);
        if Abs(TrendSlope) > 0.1 then
            exit("Item Demand Pattern"::Trending);

        // Check for seasonality (simplified: compare first half vs second half variance)
        if HasSeasonalPattern(TempDemandHistory) then
            exit("Item Demand Pattern"::Seasonal);

        if CoefficientOfVariation < 0.2 then
            exit("Item Demand Pattern"::Stable);

        exit("Item Demand Pattern"::Stable);
    end;

    local procedure CalculateTrendSlope(var TempDemandHistory: Record "Demand History Staging" temporary): Decimal
    var
        SumX: Decimal;
        SumY: Decimal;
        SumXY: Decimal;
        SumX2: Decimal;
        n: Integer;
        i: Integer;
        Slope: Decimal;
        AvgY: Decimal;
    begin
        TempDemandHistory.Reset();
        if not TempDemandHistory.FindSet() then
            exit(0);

        // Simple linear regression
        repeat
            i += 1;
            SumX += i;
            SumY += TempDemandHistory.Quantity;
            SumXY += i * TempDemandHistory.Quantity;
            SumX2 += i * i;
            n += 1;
        until TempDemandHistory.Next() = 0;

        if n <= 1 then
            exit(0);

        AvgY := SumY / n;
        if AvgY = 0 then
            exit(0);

        // Slope = (n*SumXY - SumX*SumY) / (n*SumX2 - SumX^2)
        if (n * SumX2 - SumX * SumX) = 0 then
            exit(0);

        Slope := (n * SumXY - SumX * SumY) / (n * SumX2 - SumX * SumX);

        // Normalize slope relative to average
        exit(Slope / AvgY);
    end;

    local procedure HasSeasonalPattern(var TempDemandHistory: Record "Demand History Staging" temporary): Boolean
    var
        FirstHalfSum: Decimal;
        SecondHalfSum: Decimal;
        FirstHalfCount: Integer;
        SecondHalfCount: Integer;
        TotalCount: Integer;
        i: Integer;
        FirstHalfAvg: Decimal;
        SecondHalfAvg: Decimal;
        Ratio: Decimal;
    begin
        TempDemandHistory.Reset();
        TotalCount := TempDemandHistory.Count();
        if TotalCount < 10 then
            exit(false);

        if TempDemandHistory.FindSet() then
            repeat
                i += 1;
                if i <= TotalCount div 2 then begin
                    FirstHalfSum += TempDemandHistory.Quantity;
                    FirstHalfCount += 1;
                end else begin
                    SecondHalfSum += TempDemandHistory.Quantity;
                    SecondHalfCount += 1;
                end;
            until TempDemandHistory.Next() = 0;

        if (FirstHalfCount = 0) or (SecondHalfCount = 0) then
            exit(false);

        FirstHalfAvg := FirstHalfSum / FirstHalfCount;
        SecondHalfAvg := SecondHalfSum / SecondHalfCount;

        if FirstHalfAvg = 0 then
            exit(false);

        Ratio := SecondHalfAvg / FirstHalfAvg;

        // If halves differ by more than 20%, consider it seasonal
        exit((Ratio < 0.8) or (Ratio > 1.2));
    end;

    local procedure CalculateAccuracyMetrics(AvgDailyDemand: Decimal; StdDevDemand: Decimal; var MAE: Decimal; var MAPE: Decimal)
    begin
        // Without actual forecast comparison, estimate from historical variability
        MAE := StdDevDemand;

        if AvgDailyDemand > 0 then
            MAPE := (StdDevDemand / AvgDailyDemand) * 100
        else
            MAPE := 100;

        // Cap MAPE at 100
        if MAPE > 100 then
            MAPE := 100;
    end;

    procedure GenerateSuggestionsForAllLocations(ItemNo: Code[20]): Integer
    var
        SKUMgmt: Codeunit "Planning SKU Management";
        TempLocation: Record Location temporary;
        Setup: Record "Planning Analysis Setup";
        StartDate: Date;
        SuccessCount: Integer;
        FailedCount: Integer;
    begin
        // Get setup for date range
        Setup.GetSetup(Setup);
        StartDate := CalcDate(StrSubstNo('<-%1M>', Setup."Default Analysis Months"), Today());

        // Get all locations with demand for this item
        SKUMgmt.GetLocationsWithDemand(ItemNo, StartDate, Today(), TempLocation);

        if TempLocation.IsEmpty() then begin
            Message('No locations with demand history found for item %1.', ItemNo);
            exit(0);
        end;

        // Generate suggestion for each location (SKU level)
        if TempLocation.FindSet() then
            repeat
                if TryGenerateSuggestionForSKU(ItemNo, TempLocation.Code, '') then
                    SuccessCount += 1
                else
                    FailedCount += 1;
            until TempLocation.Next() = 0;

        Message('Generated %1 SKU-level suggestions for item %2 (%3 failed).', SuccessCount, ItemNo, FailedCount);
        exit(SuccessCount);
    end;

    [TryFunction]
    local procedure TryGenerateSuggestionForSKU(ItemNo: Code[20]; LocationCode: Code[10]; VariantCode: Code[10])
    begin
        GenerateSuggestionForSKU(ItemNo, LocationCode, VariantCode);
    end;

    procedure GenerateSuggestionsForBatch(var ItemFilter: Record Item; LocationCode: Code[10]): Integer
    var
        Setup: Record "Planning Analysis Setup";
        ProcessedCount: Integer;
        SuccessCount: Integer;
        FailedCount: Integer;
        BatchSize: Integer;
        ProgressDialog: Dialog;
        ProgressLbl: Label 'Processing items...\Item: #1################\Progress: #2### of #3###';
    begin
        Setup.GetSetup(Setup);
        BatchSize := Setup."Batch Size";

        ItemFilter.SetRange("Planning Suggestion Enabled", true);

        if not ItemFilter.FindSet() then begin
            Message('No items found with Planning Suggestion Enabled.');
            exit(0);
        end;

        ProgressDialog.Open(ProgressLbl);

        repeat
            ProcessedCount += 1;
            ProgressDialog.Update(1, ItemFilter."No.");
            ProgressDialog.Update(2, ProcessedCount);
            ProgressDialog.Update(3, ItemFilter.Count());

            if TryGenerateSuggestion(ItemFilter."No.", LocationCode) then
                SuccessCount += 1
            else
                FailedCount += 1;

            // Commit every batch to prevent lock escalation
            if ProcessedCount mod BatchSize = 0 then
                Commit();

            // Safety limit for single run
            if ProcessedCount >= 1000 then begin
                ProgressDialog.Close();
                Message('Processed %1 items (%2 successful, %3 failed). Run again to continue.', ProcessedCount, SuccessCount, FailedCount);
                UpdateLastRunStats(ProcessedCount);
                exit(SuccessCount);
            end;

        until ItemFilter.Next() = 0;

        ProgressDialog.Close();

        UpdateLastRunStats(ProcessedCount);
        Message('Batch processing complete.\Processed: %1\Successful: %2\Failed: %3', ProcessedCount, SuccessCount, FailedCount);

        exit(SuccessCount);
    end;

    [TryFunction]
    local procedure TryGenerateSuggestion(ItemNo: Code[20]; LocationCode: Code[10])
    begin
        GenerateSuggestionForItem(ItemNo, LocationCode);
    end;

    procedure ApproveSuggestion(EntryNo: Integer)
    var
        Suggestion: Record "Planning Parameter Suggestion";
    begin
        if not Suggestion.Get(EntryNo) then
            Error('Suggestion %1 not found.', EntryNo);

        if Suggestion.Status <> Suggestion.Status::Pending then
            Error('Only pending suggestions can be approved. Current status: %1', Suggestion.Status);

        Suggestion.Validate(Status, Suggestion.Status::Approved);
        Suggestion.Modify(true);
    end;

    procedure RejectSuggestion(EntryNo: Integer; RejectReason: Text[250])
    var
        Suggestion: Record "Planning Parameter Suggestion";
        Item: Record Item;
    begin
        if not Suggestion.Get(EntryNo) then
            Error('Suggestion %1 not found.', EntryNo);

        if Suggestion.Status <> Suggestion.Status::Pending then
            Error('Only pending suggestions can be rejected. Current status: %1', Suggestion.Status);

        if RejectReason = '' then
            Error('A rejection reason is required.');

        Suggestion.Validate(Status, Suggestion.Status::Rejected);
        Suggestion.Modify(true);

        // Update Item with override reason
        if Item.Get(Suggestion."Item No.") then begin
            Item."Suggestion Override Reason" := RejectReason;
            Item.Modify();
        end;
    end;

    procedure ApplySuggestion(EntryNo: Integer; ApplyReorderPolicy: Boolean; ApplyReorderPoint: Boolean; ApplyReorderQty: Boolean; ApplySafetyStock: Boolean; ApplyMaxInventory: Boolean; ApplyLotAccumPeriod: Boolean): Boolean
    var
        Suggestion: Record "Planning Parameter Suggestion";
    begin
        if not Suggestion.Get(EntryNo) then
            Error('Suggestion %1 not found.', EntryNo);

        if Suggestion.Status <> Suggestion.Status::Approved then
            Error('Only approved suggestions can be applied. Current status: %1', Suggestion.Status);

        // Route to appropriate apply method based on target level
        if Suggestion."Target Level" = Suggestion."Target Level"::SKU then
            exit(ApplySuggestionToSKU(EntryNo, ApplyReorderPolicy, ApplyReorderPoint, ApplyReorderQty, ApplySafetyStock, ApplyMaxInventory, ApplyLotAccumPeriod))
        else
            exit(ApplySuggestionToItem(EntryNo, ApplyReorderPolicy, ApplyReorderPoint, ApplyReorderQty, ApplySafetyStock, ApplyMaxInventory, ApplyLotAccumPeriod));
    end;

    procedure ApplySuggestionToItem(EntryNo: Integer; ApplyReorderPolicy: Boolean; ApplyReorderPoint: Boolean; ApplyReorderQty: Boolean; ApplySafetyStock: Boolean; ApplyMaxInventory: Boolean; ApplyLotAccumPeriod: Boolean): Boolean
    var
        Suggestion: Record "Planning Parameter Suggestion";
        Item: Record Item;
        xItem: Record Item;
    begin
        if not Suggestion.Get(EntryNo) then
            Error('Suggestion %1 not found.', EntryNo);

        if Suggestion.Status <> Suggestion.Status::Approved then
            Error('Only approved suggestions can be applied. Current status: %1', Suggestion.Status);

        if Suggestion."Target Level" = Suggestion."Target Level"::SKU then
            Error('This suggestion is for a Stockkeeping Unit, not an Item. Use ApplySuggestionToSKU instead.');

        if not Item.Get(Suggestion."Item No.") then
            Error('Item %1 not found.', Suggestion."Item No.");

        if Item.Blocked then
            Error('Item %1 is blocked.', Suggestion."Item No.");

        // Backup current values
        xItem := Item;

        // Apply selected parameters with transaction protection
        if not TryApplyParametersToItem(Suggestion, Item, ApplyReorderPolicy, ApplyReorderPoint, ApplyReorderQty, ApplySafetyStock, ApplyMaxInventory, ApplyLotAccumPeriod) then begin
            // Rollback
            Item := xItem;
            Item.Modify(false);
            Error('Failed to apply suggestion: %1', GetLastErrorText());
        end;

        // Update suggestion status
        Suggestion.Validate(Status, Suggestion.Status::Applied);
        Suggestion.Modify(true);

        // Update Item extension
        Item."Last Applied Date" := Today();
        Item.Modify();

        exit(true);
    end;

    procedure ApplySuggestionToSKU(EntryNo: Integer; ApplyReorderPolicy: Boolean; ApplyReorderPoint: Boolean; ApplyReorderQty: Boolean; ApplySafetyStock: Boolean; ApplyMaxInventory: Boolean; ApplyLotAccumPeriod: Boolean): Boolean
    var
        Suggestion: Record "Planning Parameter Suggestion";
        Item: Record Item;
        SKUMgmt: Codeunit "Planning SKU Management";
    begin
        if not Suggestion.Get(EntryNo) then
            Error('Suggestion %1 not found.', EntryNo);

        if Suggestion.Status <> Suggestion.Status::Approved then
            Error('Only approved suggestions can be applied. Current status: %1', Suggestion.Status);

        if Suggestion."Target Level" <> Suggestion."Target Level"::SKU then
            Error('This suggestion is for an Item, not a Stockkeeping Unit. Use ApplySuggestionToItem instead.');

        // Apply to SKU (creates SKU if needed)
        if not SKUMgmt.ApplySuggestionToSKU(Suggestion, ApplyReorderPolicy, ApplyReorderPoint, ApplyReorderQty, ApplySafetyStock, ApplyMaxInventory, ApplyLotAccumPeriod) then
            Error('Failed to apply suggestion to SKU.');

        // Update suggestion status
        Suggestion.Validate(Status, Suggestion.Status::Applied);
        Suggestion.Modify(true);

        // Update Item extension
        if Item.Get(Suggestion."Item No.") then begin
            Item."Last Applied Date" := Today();
            Item.Modify();
        end;

        exit(true);
    end;

    [TryFunction]
    local procedure TryApplyParametersToItem(Suggestion: Record "Planning Parameter Suggestion"; var Item: Record Item; ApplyReorderPolicy: Boolean; ApplyReorderPoint: Boolean; ApplyReorderQty: Boolean; ApplySafetyStock: Boolean; ApplyMaxInventory: Boolean; ApplyLotAccumPeriod: Boolean)
    begin
        if ApplyReorderPolicy then
            Item.Validate("Reordering Policy", Suggestion."Suggested Reordering Policy");

        if ApplyReorderPoint then
            Item.Validate("Reorder Point", Suggestion."Suggested Reorder Point");

        if ApplyReorderQty then
            Item.Validate("Reorder Quantity", Suggestion."Suggested Reorder Quantity");

        if ApplySafetyStock then
            Item.Validate("Safety Stock Quantity", Suggestion."Suggested Safety Stock");

        if ApplyMaxInventory then
            Item.Validate("Maximum Inventory", Suggestion."Suggested Maximum Inventory");

        if ApplyLotAccumPeriod then
            Item.Validate("Lot Accumulation Period", Suggestion."Suggested Lot Accum Period");

        Item.Modify(true);
    end;

    local procedure CreateFailedSuggestion(ItemNo: Code[20]; LocationCode: Code[10]; VariantCode: Code[10]; TargetLevel: Option Item,SKU; ErrorMessage: Text)
    var
        Suggestion: Record "Planning Parameter Suggestion";
    begin
        Suggestion.Init();
        Suggestion."Item No." := ItemNo;
        Suggestion."Location Code" := LocationCode;
        Suggestion."Variant Code" := VariantCode;
        Suggestion."Target Level" := TargetLevel;
        Suggestion.Status := Suggestion.Status::Failed;
        Suggestion."Error Message" := CopyStr(ErrorMessage, 1, 500);
        if TargetLevel = TargetLevel::SKU then
            Suggestion.UpdateSKUExists();
        Suggestion.Insert(true);
    end;

    local procedure UpdateItemPlanningExtension(ItemNo: Code[20]; DemandPattern: Enum "Item Demand Pattern"; ConfidenceScore: Decimal)
    var
        Item: Record Item;
    begin
        if Item.Get(ItemNo) then begin
            Item."Last Suggestion Date" := Today();
            Item."Demand Pattern" := DemandPattern;
            Item."Forecast Reliability Score" := ConfidenceScore;
            Item.Modify();
        end;
    end;

    local procedure UpdateLastRunStats(ItemsProcessed: Integer)
    var
        Setup: Record "Planning Analysis Setup";
    begin
        Setup.GetSetup(Setup);
        Setup."Last Full Run DateTime" := CurrentDateTime();
        Setup."Last Full Run Items" := ItemsProcessed;
        Setup.Modify();
    end;

    procedure ExpireOldSuggestions(DaysOld: Integer)
    var
        Suggestion: Record "Planning Parameter Suggestion";
        ExpiryDate: DateTime;
        ExpiredCount: Integer;
    begin
        if DaysOld <= 0 then
            DaysOld := 30;

        ExpiryDate := CreateDateTime(CalcDate(StrSubstNo('<-%1D>', DaysOld), Today()), 0T);

        Suggestion.SetRange(Status, Suggestion.Status::Pending);
        Suggestion.SetFilter("Created DateTime", '<%1', ExpiryDate);

        if Suggestion.FindSet() then
            repeat
                Suggestion.Status := Suggestion.Status::Expired;
                Suggestion.Modify();
                ExpiredCount += 1;
            until Suggestion.Next() = 0;

        if ExpiredCount > 0 then
            Message('%1 suggestions marked as expired.', ExpiredCount);
    end;
}
