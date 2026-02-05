# Planning Parameter Suggestion System - Technical Design Document

## Executive Summary

This document outlines the complete technical design for a **Planning Parameter Suggestion System** that analyzes historical Business Central data and uses Facebook Prophet ML to generate intelligent recommendations for inventory planning parameters.

---

## 1. System Architecture Overview

```
+------------------+     +-------------------+     +------------------+
|  Business        |     |   Azure Logic     |     |   Prophet ML     |
|  Central         |---->|   Apps            |---->|   Platform       |
|  (AL Extension)  |     |   (Orchestrator)  |     |   (Azure ML/     |
+------------------+     +-------------------+     |   Functions)     |
        |                        |                 +------------------+
        v                        v                         |
+------------------+     +-------------------+              |
| Planning         |     | Forecast          |<-------------+
| Parameter        |<----|  Response         |
| Suggestion Table |     | (JSON)            |
+------------------+     +-------------------+
```

### Data Flow:
1. **Collect**: Aggregate historical data (Sales, Consumption, Item Ledger Entries)
2. **Transform**: Convert to Prophet-compatible format (ds, y columns)
3. **Send**: POST to Azure Logic Apps endpoint
4. **Process**: Logic Apps forwards to Prophet ML service
5. **Receive**: Prophet returns forecasts with trend/seasonality
6. **Calculate**: Apply algorithms to derive planning parameters
7. **Store**: Save suggestions for user review/approval

---

## 2. Database Schema Design

### 2.1 New Tables

#### Table 50110: Planning Parameter Suggestion
```
Purpose: Stores ML-generated parameter suggestions for items
Primary Key: Entry No. (AutoIncrement)
Indexes:
  - (Item No., Suggestion Date) - for lookups by item and date
  - (Status, Created DateTime) - for processing queue
  - (Item No., Status) - for finding pending suggestions per item

Field No. | Field Name                  | Type           | Description
----------|----------------------------|----------------|------------------------------------------
1         | Entry No.                  | Integer        | Primary key, AutoIncrement
10        | Item No.                   | Code[20]       | FK to Item table
11        | Variant Code               | Code[10]       | Optional item variant
12        | Location Code              | Code[10]       | Optional location filter
20        | Suggestion Date            | Date           | Date suggestion was generated
21        | Created DateTime           | DateTime       | Timestamp of record creation
30        | Status                     | Enum 50110     | Pending/Approved/Rejected/Applied
31        | Reviewed By                | Code[50]       | UserId who reviewed
32        | Reviewed DateTime          | DateTime       | When reviewed
40        | Current Reordering Policy  | Enum           | Current value from Item
41        | Suggested Reordering Policy| Enum           | ML-suggested value
50        | Current Reorder Point      | Decimal        | Current value from Item
51        | Suggested Reorder Point    | Decimal        | ML-suggested value
60        | Current Reorder Quantity   | Decimal        | Current value from Item
61        | Suggested Reorder Quantity | Decimal        | ML-suggested value
70        | Current Safety Stock       | Decimal        | Current value from Item
71        | Suggested Safety Stock     | Decimal        | ML-suggested value
80        | Current Maximum Inventory  | Decimal        | Current value from Item
81        | Suggested Maximum Inventory| Decimal        | ML-suggested value
90        | Suggested Lot Accum Period | DateFormula    | ML-suggested value
91        | Current Lot Accum Period   | DateFormula    | Current value from Item
100       | Confidence Score           | Decimal        | 0-100 confidence from ML
101       | Forecast Accuracy MAE      | Decimal        | Mean Absolute Error
102       | Forecast Accuracy MAPE     | Decimal        | Mean Absolute Percentage Error
110       | Data Points Analyzed       | Integer        | Number of historical records
111       | Analysis Period Start      | Date           | Start of analysis window
112       | Analysis Period End        | Date           | End of analysis window
120       | Prophet Forecast JSON      | Blob           | Raw Prophet response (SubType JSON)
121       | Calculation Notes          | Text[2048]     | Explanation of suggestions
130       | Error Message              | Text[500]      | If status = Failed
```

#### Table 50111: Demand History Staging
```
Purpose: Temporary staging for demand data before ML processing
TableType: Temporary (memory only during processing)
Primary Key: (Item No., Demand Date, Source Type, Source No.)

Field No. | Field Name      | Type        | Description
----------|-----------------|-------------|------------------------------------------
1         | Item No.        | Code[20]    | Item being analyzed
2         | Demand Date     | Date        | Date of demand event (ds column for Prophet)
3         | Source Type     | Option      | Sales/Consumption/Transfer/Adjustment
4         | Source No.      | Code[20]    | Source document number
10        | Quantity        | Decimal     | Demand quantity (y column for Prophet)
11        | Location Code   | Code[10]    | Location of demand
12        | Variant Code    | Code[10]    | Item variant
20        | Unit Cost       | Decimal     | Cost at time of demand
21        | Unit Price      | Decimal     | Price at time of demand
```

#### Table 50112: Prophet API Log
```
Purpose: Audit trail for all Prophet API communications
Primary Key: Entry No. (AutoIncrement)
Index: (Item No., Request DateTime) - for tracing item requests

Field No. | Field Name        | Type        | Description
----------|-------------------|-------------|------------------------------------------
1         | Entry No.         | Integer     | Primary key, AutoIncrement
10        | Item No.          | Code[20]    | Item analyzed
11        | Location Code     | Code[10]    | Location filter used
20        | Request DateTime  | DateTime    | When request was sent
21        | Response DateTime | DateTime    | When response received
22        | Duration Ms       | Integer     | Processing time in milliseconds
30        | Request Payload   | Blob        | JSON sent to Prophet (SubType JSON)
31        | Response Payload  | Blob        | JSON received from Prophet (SubType JSON)
40        | HTTP Status Code  | Integer     | Response status (200, 400, 500, etc.)
41        | Success           | Boolean     | True if successful
42        | Error Message     | Text[500]   | Error details if failed
50        | Data Points Sent  | Integer     | Number of ds/y pairs sent
51        | Forecast Periods  | Integer     | Number of future periods requested
```

#### Table 50113: Planning Analysis Setup
```
Purpose: Configuration for the planning suggestion system
Primary Key: Primary Key (Code[10], single record)

Field No. | Field Name                    | Type        | Description
----------|-------------------------------|-------------|------------------------------------------
1         | Primary Key                   | Code[10]    | Always blank (singleton pattern)
10        | Prophet Endpoint URL          | Text[500]   | Azure Logic Apps trigger URL
11        | Prophet API Key               | Text[100]   | API authentication key
12        | Enable Prophet Integration    | Boolean     | Master switch for ML features
20        | Default Analysis Months       | Integer     | Months of history to analyze (default 24)
21        | Minimum Data Points           | Integer     | Min records required (default 30)
22        | Forecast Periods Days         | Integer     | Days to forecast ahead (default 90)
30        | Safety Stock Multiplier       | Decimal     | Standard deviations for safety stock (default 1.65)
31        | Service Level Target          | Decimal     | Target service level % (default 95.0)
32        | Lead Time Days Default        | Integer     | Default lead time if not on item (default 7)
40        | Auto Apply Threshold          | Decimal     | Confidence % to auto-approve (default 90.0)
50        | Batch Size                    | Integer     | Items per batch for processing (default 50)
51        | Max Concurrent Requests       | Integer     | Parallel API calls (default 5)
60        | Last Full Run DateTime        | DateTime    | When last batch run completed
61        | Last Full Run Items           | Integer     | Items processed in last run
```

### 2.2 Table Extension

#### Table Extension 50110: Item Planning Extension
```
Extends: Item (Table 27)
Purpose: Track suggestion history and enable/disable per item

Field No. | Field Name                     | Type        | Description
----------|--------------------------------|-------------|------------------------------------------
50110     | Planning Suggestion Enabled    | Boolean     | Enable ML suggestions for this item
50111     | Last Suggestion Date           | Date        | When last suggestion generated
50112     | Last Applied Date              | Date        | When last suggestion was applied
50113     | Suggestion Override Reason     | Text[250]   | Why user overrode suggestion
50114     | Demand Pattern                 | Option      | Detected pattern: Stable/Seasonal/Trending/Erratic
50115     | Forecast Reliability Score     | Decimal     | Historical accuracy 0-100
```

### 2.3 Enumerations

#### Enum 50110: Planning Suggestion Status
```al
enum 50110 "Planning Suggestion Status"
{
    Extensible = true;

    value(0; Pending) { Caption = 'Pending Review'; }
    value(1; Approved) { Caption = 'Approved'; }
    value(2; Rejected) { Caption = 'Rejected'; }
    value(3; Applied) { Caption = 'Applied to Item'; }
    value(4; Failed) { Caption = 'Processing Failed'; }
    value(5; Expired) { Caption = 'Expired (Not Reviewed)'; }
}
```

#### Enum 50111: Demand Source Type
```al
enum 50111 "Demand Source Type"
{
    Extensible = true;

    value(0; Sales) { Caption = 'Sales'; }
    value(1; Consumption) { Caption = 'Production Consumption'; }
    value(2; Transfer) { Caption = 'Transfer Out'; }
    value(3; Adjustment) { Caption = 'Negative Adjustment'; }
    value(4; Assembly) { Caption = 'Assembly Consumption'; }
}
```

#### Enum 50112: Item Demand Pattern
```al
enum 50112 "Item Demand Pattern"
{
    Extensible = true;

    value(0; Unknown) { Caption = 'Not Analyzed'; }
    value(1; Stable) { Caption = 'Stable Demand'; }
    value(2; Seasonal) { Caption = 'Seasonal Pattern'; }
    value(3; Trending) { Caption = 'Trending (Up/Down)'; }
    value(4; Erratic) { Caption = 'Erratic/Unpredictable'; }
    value(5; Intermittent) { Caption = 'Intermittent/Lumpy'; }
}
```

### 2.4 Index Strategy

| Table | Index Fields | Purpose |
|-------|-------------|---------|
| Planning Parameter Suggestion | (Item No., Suggestion Date) DESC | Quick lookup of latest suggestion per item |
| Planning Parameter Suggestion | (Status, Created DateTime) | Process pending suggestions in order |
| Planning Parameter Suggestion | (Item No., Status) | Find all pending for specific item |
| Prophet API Log | (Item No., Request DateTime) DESC | Audit trail queries |
| Prophet API Log | (Request DateTime) DESC | Recent activity monitoring |
| Demand History Staging | (Item No., Demand Date) | Prophet data preparation |

---

## 3. Step-by-Step Logic & API Mapping

### 3.1 Data Collection Process

```
PROCEDURE: CollectDemandHistory(ItemNo, StartDate, EndDate)
===========================================================

Step 1: Initialize Staging Table
  - Clear TempDemandHistory for ItemNo
  - Validate date range (minimum 30 days, maximum 36 months)

Step 2: Collect Sales Demand
  API: Item Ledger Entry table
  Filter:
    - Item No. = ItemNo
    - Entry Type = Sale
    - Posting Date IN [StartDate..EndDate]
  Transform:
    - Demand Date = Posting Date
    - Quantity = ABS(Quantity) [sales are negative in ILE]
    - Source Type = Sales
    - Source No. = Document No.

Step 3: Collect Production Consumption
  API: Item Ledger Entry table
  Filter:
    - Item No. = ItemNo
    - Entry Type = Consumption
    - Posting Date IN [StartDate..EndDate]
  Transform:
    - Demand Date = Posting Date
    - Quantity = ABS(Quantity)
    - Source Type = Consumption
    - Source No. = Document No.

Step 4: Collect Transfer Outbound
  API: Item Ledger Entry table
  Filter:
    - Item No. = ItemNo
    - Entry Type = Transfer
    - Quantity < 0 (outbound only)
    - Posting Date IN [StartDate..EndDate]
  Transform:
    - Demand Date = Posting Date
    - Quantity = ABS(Quantity)
    - Source Type = Transfer

Step 5: Collect Negative Adjustments
  API: Item Ledger Entry table
  Filter:
    - Item No. = ItemNo
    - Entry Type = Negative Adjmt.
    - Posting Date IN [StartDate..EndDate]
  Transform:
    - Demand Date = Posting Date
    - Quantity = ABS(Quantity)
    - Source Type = Adjustment

Step 6: Aggregate by Date
  - GROUP BY Demand Date
  - SUM(Quantity) for each date
  - Fill gaps with zero demand (important for Prophet)

Step 7: Validate Data Quality
  - Check: Count >= MinimumDataPoints (from Setup)
  - Check: No more than 30% zero-demand days
  - Check: Standard deviation > 0 (not constant demand)

RETURN: TempDemandHistory records, DataQualityScore
```

### 3.2 Prophet API Request Flow

```
PROCEDURE: SendToProphetML(ItemNo, TempDemandHistory)
=====================================================

Step 1: Build Prophet Request Payload
  JSON Structure:
  {
    "itemNo": "1000",
    "locationCode": "MAIN",
    "dataPoints": [
      {"ds": "2024-01-01", "y": 150.0},
      {"ds": "2024-01-02", "y": 125.0},
      ...
    ],
    "forecastPeriods": 90,
    "includeHolidays": true,
    "holidayCountry": "US",
    "seasonalityMode": "multiplicative",
    "changePointPriorScale": 0.05,
    "requestId": "GUID-HERE"
  }

Step 2: Log Outbound Request
  API: Prophet API Log table
  - Insert new record with Request Payload
  - Set Request DateTime = CurrentDateTime

Step 3: Send HTTP POST
  Endpoint: Planning Analysis Setup."Prophet Endpoint URL"
  Headers:
    - Content-Type: application/json
    - x-api-key: {API Key from Setup}
    - x-request-id: {GUID}
  Timeout: 120000ms (2 minutes)

Step 4: Handle Response
  Success (200-299):
    - Parse JSON response
    - Update API Log with Response Payload
    - Calculate Duration Ms
    - Set Success = true

  Failure (400-599):
    - Log error message
    - Set Success = false
    - Raise appropriate error or continue based on config

Step 5: Parse Prophet Response
  Expected Response:
  {
    "itemNo": "1000",
    "forecast": [
      {"ds": "2024-04-01", "yhat": 145.2, "yhat_lower": 120.5, "yhat_upper": 169.9},
      ...
    ],
    "trend": {...},
    "seasonality": {
      "weekly": {...},
      "yearly": {...}
    },
    "metrics": {
      "mae": 12.5,
      "mape": 8.2,
      "rmse": 15.3
    },
    "changePoints": ["2024-02-15", "2024-03-01"],
    "demandPattern": "Seasonal"
  }

RETURN: ProphetResponse record
```

### 3.3 Parameter Calculation Algorithm

```
PROCEDURE: CalculatePlanningParameters(ItemNo, ProphetResponse, TempDemandHistory)
==================================================================================

Step 1: Determine Reordering Policy
  Based on Demand Pattern from Prophet:

  IF demandPattern = "Stable" THEN
    SuggestedPolicy := "Fixed Reorder Qty."
    Reasoning := "Stable demand supports fixed reorder approach"

  ELSE IF demandPattern = "Seasonal" THEN
    SuggestedPolicy := "Lot-for-Lot"
    Reasoning := "Seasonal patterns require dynamic lot sizing"

  ELSE IF demandPattern = "Trending" THEN
    SuggestedPolicy := "Maximum Qty."
    Reasoning := "Trending demand benefits from inventory ceiling"

  ELSE IF demandPattern IN ["Erratic", "Intermittent"] THEN
    SuggestedPolicy := "Order"
    Reasoning := "Unpredictable demand - order per demand event"

Step 2: Calculate Safety Stock
  Formula: Safety Stock = Z * σ * √(L + R)

  Where:
    Z = Service level factor (1.65 for 95%, 2.33 for 99%)
    σ = Standard deviation of daily demand
    L = Lead time in days
    R = Review period in days

  Implementation:
    DailyDemandStdDev := CalculateStdDev(TempDemandHistory)
    LeadTimeDays := Item."Lead Time Calculation" OR Setup."Lead Time Days Default"
    ReviewPeriod := 7 (weekly review assumption)
    ServiceLevelZ := GetZScoreForServiceLevel(Setup."Service Level Target")

    SuggestedSafetyStock := ROUND(ServiceLevelZ * DailyDemandStdDev * SQRT(LeadTimeDays + ReviewPeriod), 1)

  Adjustment for Forecast Uncertainty:
    ForecastError := ProphetResponse.metrics.mae
    UncertaintyBuffer := ForecastError * ServiceLevelZ
    SuggestedSafetyStock += ROUND(UncertaintyBuffer, 1)

Step 3: Calculate Reorder Point
  Formula: Reorder Point = (Average Daily Demand * Lead Time) + Safety Stock

  Implementation:
    AvgDailyDemand := SUM(TempDemandHistory.Quantity) / COUNT(DISTINCT Demand Date)
    LeadTimeDays := Item."Lead Time Calculation" OR Setup."Lead Time Days Default"

    LeadTimeDemand := AvgDailyDemand * LeadTimeDays
    SuggestedReorderPoint := ROUND(LeadTimeDemand + SuggestedSafetyStock, 1)

Step 4: Calculate Reorder Quantity (EOQ Model)
  Formula: EOQ = √((2 * D * S) / H)

  Where:
    D = Annual demand
    S = Order/Setup cost (estimated or from Item card)
    H = Holding cost per unit per year

  Implementation:
    AnnualDemand := SUM(TempDemandHistory.Quantity) * (365 / AnalysisDays)
    OrderCost := Item."Overhead Rate" OR 50.00 (default)
    HoldingCostRate := 0.25 (25% of unit cost annually)
    UnitCost := Item."Unit Cost"
    HoldingCost := UnitCost * HoldingCostRate

    IF HoldingCost > 0 THEN
      EOQ := SQRT((2 * AnnualDemand * OrderCost) / HoldingCost)
      SuggestedReorderQty := ROUND(EOQ, Item."Rounding Precision")
    ELSE
      SuggestedReorderQty := ROUND(AnnualDemand / 12, 1)  // Monthly quantity fallback

Step 5: Calculate Maximum Inventory
  Formula: Max Inventory = Reorder Point + Reorder Quantity

  With Seasonal Adjustment:
    PeakSeasonMultiplier := MAX(ProphetResponse.seasonality.yearly) / AVG(ProphetResponse.seasonality.yearly)

    IF PeakSeasonMultiplier > 1.3 THEN
      SuggestedMaxInventory := ROUND((SuggestedReorderPoint + SuggestedReorderQty) * PeakSeasonMultiplier, 1)
    ELSE
      SuggestedMaxInventory := ROUND(SuggestedReorderPoint + SuggestedReorderQty, 1)

Step 6: Calculate Lot Accumulation Period
  Based on Order Frequency and Demand Pattern:

  OrdersPerYear := AnnualDemand / SuggestedReorderQty
  AvgDaysBetweenOrders := 365 / OrdersPerYear

  IF AvgDaysBetweenOrders <= 7 THEN
    SuggestedLotAccumPeriod := '1W'  // Weekly
  ELSE IF AvgDaysBetweenOrders <= 14 THEN
    SuggestedLotAccumPeriod := '2W'  // Bi-weekly
  ELSE IF AvgDaysBetweenOrders <= 30 THEN
    SuggestedLotAccumPeriod := '1M'  // Monthly
  ELSE
    SuggestedLotAccumPeriod := '2M'  // Bi-monthly

Step 7: Calculate Confidence Score
  Factors:
    DataQuality := (ActualDataPoints / OptimalDataPoints) * 25  // Max 25 points
    ForecastAccuracy := (1 - (MAPE / 100)) * 40                  // Max 40 points
    PatternClarity := IF demandPattern <> "Erratic" THEN 20 ELSE 5  // Max 20 points
    HistoricalStability := (1 - CoefficientOfVariation) * 15    // Max 15 points

    ConfidenceScore := ROUND(DataQuality + ForecastAccuracy + PatternClarity + HistoricalStability, 0)
    ConfidenceScore := MIN(MAX(ConfidenceScore, 0), 100)  // Clamp to 0-100

RETURN: PlanningParameterSuggestion record
```

### 3.4 Suggestion Application Flow

```
PROCEDURE: ApplySuggestionToItem(SuggestionEntryNo, ApplyFields)
================================================================

Step 1: Validate Suggestion
  - Get Planning Parameter Suggestion record
  - Check Status = Approved OR ConfidenceScore >= AutoApplyThreshold
  - Check Item exists and is not blocked

Step 2: Backup Current Values
  - Store current Item planning fields in Suggestion record
  - This enables rollback if needed

Step 3: Apply Approved Parameters
  API: Item table (Table 27)

  IF ApplyFields.ReorderingPolicy THEN
    Item.VALIDATE("Reordering Policy", Suggestion."Suggested Reordering Policy")

  IF ApplyFields.ReorderPoint THEN
    Item.VALIDATE("Reorder Point", Suggestion."Suggested Reorder Point")

  IF ApplyFields.ReorderQuantity THEN
    Item.VALIDATE("Reorder Quantity", Suggestion."Suggested Reorder Quantity")

  IF ApplyFields.SafetyStock THEN
    Item.VALIDATE("Safety Stock Quantity", Suggestion."Suggested Safety Stock")

  IF ApplyFields.MaxInventory THEN
    Item.VALIDATE("Maximum Inventory", Suggestion."Suggested Maximum Inventory")

  IF ApplyFields.LotAccumPeriod THEN
    Item.VALIDATE("Lot Accumulation Period", Suggestion."Suggested Lot Accum Period")

Step 4: Update Records
  Item.MODIFY(true)  // Run triggers

  Suggestion.Status := Applied
  Suggestion."Reviewed By" := UserId
  Suggestion."Reviewed DateTime" := CurrentDateTime
  Suggestion.MODIFY()

  // Update Item extension fields
  ItemPlanningExt."Last Applied Date" := Today
  ItemPlanningExt.MODIFY()

Step 5: Log Application
  - Create audit entry for compliance
  - Include before/after values

RETURN: Success/Failure with message
```

### 3.5 Data Validation Points

| Step | Validation | Action on Failure |
|------|-----------|-------------------|
| Data Collection | Minimum 30 data points | Error: "Insufficient history" |
| Data Collection | Date range valid | Error: "Invalid date range" |
| API Request | Endpoint URL configured | Error: "Prophet not configured" |
| API Request | HTTP timeout | Log error, retry up to 3 times |
| API Response | Valid JSON structure | Error: "Invalid Prophet response" |
| API Response | Forecast array not empty | Error: "Empty forecast returned" |
| Calculation | Safety Stock >= 0 | Adjust to 0 minimum |
| Calculation | Reorder Qty > 0 | Use minimum order qty from Item |
| Application | Item not blocked | Error: "Item is blocked" |
| Application | User has permission | Error: "Insufficient permissions" |

---

## 4. Secure Coding & Guardrails

### 4.1 Security Requirements

#### Input Sanitization
```al
// All user inputs sanitized before use
local procedure SanitizeInput(InputText: Text): Text
var
    SanitizedText: Text;
begin
    // Remove potential injection characters
    SanitizedText := InputText;
    SanitizedText := SanitizedText.Replace('<', '');
    SanitizedText := SanitizedText.Replace('>', '');
    SanitizedText := SanitizedText.Replace('"', '');
    SanitizedText := SanitizedText.Replace('''', '');
    exit(SanitizedText);
end;

// Validate Item No. exists before processing
local procedure ValidateItemNo(ItemNo: Code[20]): Boolean
var
    Item: Record Item;
begin
    if ItemNo = '' then
        exit(false);
    exit(Item.Get(ItemNo));
end;
```

#### API Key Protection
```al
// API key stored with proper data classification
field(11; "Prophet API Key"; Text[100])
{
    Caption = 'Prophet API Key';
    DataClassification = EndUserIdentifiableInformation;
    ExtendedDatatype = Masked;  // Displayed as asterisks
}

// Never log API keys
local procedure LogRequest(RequestJson: Text)
var
    SanitizedJson: Text;
begin
    // Remove sensitive data before logging
    SanitizedJson := RequestJson;
    // API key is in header, not body, so safe to log body
    ProphetAPILog."Request Payload".WriteText(SanitizedJson);
end;
```

#### Permission Control
```al
// Define granular permissions
permissionset 50110 "Planning Suggest View"
{
    Assignable = true;
    Caption = 'View Planning Suggestions';

    Permissions =
        tabledata "Planning Parameter Suggestion" = R,
        tabledata "Prophet API Log" = R,
        tabledata "Planning Analysis Setup" = R;
}

permissionset 50111 "Planning Suggest Admin"
{
    Assignable = true;
    Caption = 'Manage Planning Suggestions';

    Permissions =
        tabledata "Planning Parameter Suggestion" = RIMD,
        tabledata "Prophet API Log" = RIMD,
        tabledata "Planning Analysis Setup" = RIMD,
        tabledata Item = RM;  // Modify for applying suggestions
}
```

### 4.2 Error Handling Strategy

```al
// Comprehensive error handling with retry logic
procedure SendToProphetWithRetry(var TempDemandHistory: Record "Demand History Staging" temporary): Boolean
var
    RetryCount: Integer;
    MaxRetries: Integer;
    LastError: Text;
begin
    MaxRetries := 3;
    RetryCount := 0;

    while RetryCount < MaxRetries do begin
        RetryCount += 1;
        ClearLastError();

        if TrySendToProphet(TempDemandHistory) then
            exit(true);

        LastError := GetLastErrorText();

        // Don't retry on validation errors (4xx)
        if LastError.Contains('400') or LastError.Contains('401') or LastError.Contains('403') then
            Error('Prophet API validation error: %1', LastError);

        // Wait before retry (exponential backoff)
        Sleep(1000 * RetryCount);  // 1s, 2s, 3s
    end;

    // All retries exhausted
    LogAPIError(LastError);
    Error('Prophet API unavailable after %1 attempts. Last error: %2', MaxRetries, LastError);
end;

[TryFunction]
local procedure TrySendToProphet(var TempDemandHistory: Record "Demand History Staging" temporary)
begin
    // Actual HTTP call that may fail
    SendHTTPRequest(TempDemandHistory);
end;
```

### 4.3 Performance Guardrails

```al
// Batch processing with size limits
procedure ProcessItemBatch(var ItemFilter: Record Item)
var
    Setup: Record "Planning Analysis Setup";
    ProcessedCount: Integer;
    BatchSize: Integer;
begin
    Setup.Get();
    BatchSize := Setup."Batch Size";
    if BatchSize <= 0 then
        BatchSize := 50;  // Default

    if ItemFilter.FindSet() then
        repeat
            ProcessedCount += 1;

            // Process single item
            ProcessSingleItem(ItemFilter."No.");

            // Commit every batch to prevent lock escalation
            if ProcessedCount mod BatchSize = 0 then begin
                Commit();
                // Optional: yield to other processes
                Sleep(100);
            end;

            // Safety limit for single run
            if ProcessedCount >= 1000 then begin
                Message('Processed %1 items. Run again to continue.', ProcessedCount);
                exit;
            end;

        until ItemFilter.Next() = 0;
end;

// Timeout protection for HTTP calls
local procedure CreateHttpClient(): HttpClient
var
    Client: HttpClient;
begin
    // Set reasonable timeout (2 minutes max)
    Client.SetTimeout(120000);
    exit(Client);
end;
```

### 4.4 Data Integrity Protection

```al
// Prevent corruption of existing Item records
procedure ApplySuggestionSafely(SuggestionEntryNo: Integer): Boolean
var
    Suggestion: Record "Planning Parameter Suggestion";
    Item: Record Item;
    xItem: Record Item;  // Backup copy
begin
    if not Suggestion.Get(SuggestionEntryNo) then
        Error('Suggestion %1 not found', SuggestionEntryNo);

    if Suggestion.Status <> Suggestion.Status::Approved then
        Error('Only approved suggestions can be applied');

    if not Item.Get(Suggestion."Item No.") then
        Error('Item %1 not found', Suggestion."Item No.");

    // Create backup before modification
    xItem := Item;

    // Use transaction to ensure atomicity
    if not TryApplySuggestion(Suggestion, Item) then begin
        // Rollback by restoring original values
        Item := xItem;
        Item.Modify(false);
        Error('Failed to apply suggestion: %1', GetLastErrorText());
    end;

    exit(true);
end;

[TryFunction]
local procedure TryApplySuggestion(Suggestion: Record "Planning Parameter Suggestion"; var Item: Record Item)
begin
    // All modifications in single transaction
    Item.Validate("Reordering Policy", Suggestion."Suggested Reordering Policy");
    Item.Validate("Reorder Point", Suggestion."Suggested Reorder Point");
    Item.Validate("Reorder Quantity", Suggestion."Suggested Reorder Quantity");
    Item.Validate("Safety Stock Quantity", Suggestion."Suggested Safety Stock");
    Item.Modify(true);
end;
```

### 4.5 Security Self-Critique

| Potential Vulnerability | Mitigation |
|------------------------|------------|
| API Key exposure in logs | Keys stored masked, never logged in payloads |
| SQL Injection | AL uses parameterized queries natively |
| Unauthorized data access | Permission sets restrict table access |
| Denial of Service | Batch size limits, timeout protection |
| Data corruption | Transaction wrapping, backup before modify |
| Man-in-the-middle | HTTPS required for Prophet endpoint |
| Excessive API calls | Rate limiting through batch processing |
| Stale suggestions applied | Expiry status after 30 days |

### 4.6 Performance Bottleneck Analysis

| Bottleneck | Impact | Mitigation |
|-----------|--------|------------|
| Large Item Ledger Entry queries | Slow data collection | Index on (Item No., Entry Type, Posting Date) |
| HTTP call latency | User wait time | Async processing with background sessions |
| JSON serialization | Memory usage | Stream-based JSON building |
| Bulk Item updates | Lock contention | Batch commits every 50 records |
| Prophet API rate limits | Failed requests | Exponential backoff retry |

---

## 5. Test Plan

### 5.1 Unit Tests - Backend Logic

#### Test Suite: Data Collection

| Test ID | Test Case | Input | Expected Output | Pass Criteria |
|---------|-----------|-------|-----------------|---------------|
| DC-001 | Collect sales demand | Item with 100 sales entries | TempDemandHistory with 100 records | Count = 100, all positive quantities |
| DC-002 | Collect consumption | Item with 50 consumption entries | TempDemandHistory with 50 records | Source Type = Consumption |
| DC-003 | Date aggregation | Multiple demands on same date | Single record per date with SUM | Grouped correctly |
| DC-004 | Empty history | Item with no transactions | Empty TempDemandHistory | Count = 0, validation fails |
| DC-005 | Minimum data points | 29 data points | Error raised | "Insufficient history" message |
| DC-006 | Date range validation | End date before start date | Error raised | "Invalid date range" message |
| DC-007 | Location filtering | Item with multi-location demand | Only filtered location data | Location Code matches filter |

#### Test Suite: Prophet API Integration

| Test ID | Test Case | Input | Expected Output | Pass Criteria |
|---------|-----------|-------|-----------------|---------------|
| PA-001 | Valid API request | 90+ data points | HTTP 200, valid JSON | Success = true |
| PA-002 | Missing API key | Empty API Key field | HTTP 401/403 | Proper error message |
| PA-003 | Invalid endpoint | Malformed URL | Connection error | Logged, retries attempted |
| PA-004 | Timeout handling | Slow/unresponsive endpoint | Timeout after 120s | Error logged, no hang |
| PA-005 | Retry logic | First 2 calls fail, 3rd succeeds | Success after retry | RetryCount = 3 |
| PA-006 | Max retries exceeded | All 3 calls fail | Error raised | "unavailable after 3 attempts" |
| PA-007 | Malformed response | Invalid JSON from API | Parse error | "Invalid Prophet response" |

#### Test Suite: Parameter Calculations

| Test ID | Test Case | Input | Expected Output | Pass Criteria |
|---------|-----------|-------|-----------------|---------------|
| PC-001 | Safety stock calculation | StdDev=10, LeadTime=7, Z=1.65 | ~43.7 units | Within 1% of expected |
| PC-002 | Reorder point calculation | AvgDaily=50, LeadTime=5, Safety=100 | 350 units | Math verified |
| PC-003 | EOQ calculation | Annual=10000, Order=$50, Hold=$2.50 | 632 units | EOQ formula correct |
| PC-004 | Zero holding cost | HoldingCost = 0 | Monthly demand fallback | No division by zero |
| PC-005 | Seasonal max inventory | PeakMultiplier = 1.5 | MaxInv * 1.5 | Adjustment applied |
| PC-006 | Confidence score bounds | Various inputs | 0-100 range | Never < 0 or > 100 |
| PC-007 | Policy from pattern | Each demand pattern | Correct policy | Mapping verified |

#### Test Suite: Suggestion Application

| Test ID | Test Case | Input | Expected Output | Pass Criteria |
|---------|-----------|-------|-----------------|---------------|
| SA-001 | Apply approved suggestion | Status = Approved | Item updated | All fields match suggestion |
| SA-002 | Reject pending suggestion | Status = Pending | Error raised | "Only approved" message |
| SA-003 | Blocked item | Item.Blocked = true | Error raised | "Item is blocked" message |
| SA-004 | Partial field application | Only SafetyStock selected | Only SafetyStock updated | Other fields unchanged |
| SA-005 | Rollback on error | VALIDATE fails | Original values restored | Item unchanged |
| SA-006 | Audit trail | Successful application | Suggestion.Status = Applied | Reviewed By/DateTime set |

### 5.2 Edge Case Tests

| Test ID | Test Case | Scenario | Expected Behavior |
|---------|-----------|----------|-------------------|
| EC-001 | Zero demand history | New item, no sales | Skip with "No history" message |
| EC-002 | 100% zero demand days | Item discontinued | Erratic pattern, low confidence |
| EC-003 | Single massive spike | One day = 90% of demand | Outlier detection, exclude from std dev |
| EC-004 | Negative values | Data error with negative qty | ABS() applied, warning logged |
| EC-005 | Unicode in Item No. | Special characters | Proper JSON encoding |
| EC-006 | Very long history | 10 years of data | Limit to configured months |
| EC-007 | Concurrent processing | Same item processed twice | Second request blocked/queued |
| EC-008 | Prophet returns NaN | Invalid forecast values | Error handled gracefully |

### 5.3 Integration Tests

| Test ID | Test Case | Components | Expected Behavior |
|---------|-----------|------------|-------------------|
| IT-001 | End-to-end happy path | All components | Suggestion created with Applied status |
| IT-002 | Logic Apps connectivity | BC -> Logic Apps | HTTP 200, request logged |
| IT-003 | Prophet ML roundtrip | Logic Apps -> Prophet -> BC | Valid forecast returned |
| IT-004 | Batch processing | 100 items | All processed, commits work |
| IT-005 | Permission enforcement | User without Admin | View only, no apply |
| IT-006 | Setup validation | Missing Prophet URL | Error before processing |

### 5.4 User Acceptance Test (UAT) Scenarios

#### UAT-001: Configure Planning Analysis
**Objective**: Administrator can configure the Prophet integration
**Preconditions**: User has Admin permissions
**Steps**:
1. Navigate to Planning Analysis Setup page
2. Enter Prophet Endpoint URL
3. Enter API Key
4. Set analysis parameters (months, data points, forecast periods)
5. Enable Prophet Integration
6. Save configuration

**Success Criteria**:
- [ ] All fields save correctly
- [ ] API Key displayed as masked (asterisks)
- [ ] Test Connection button returns success
- [ ] Settings persist after page close

#### UAT-002: Generate Suggestions for Single Item
**Objective**: User can generate planning suggestions for one item
**Preconditions**: Item has 12+ months sales history
**Steps**:
1. Open Item Card
2. Navigate to Planning Parameters section
3. Click "Generate Planning Suggestion"
4. Wait for processing (progress indicator shown)
5. View generated suggestion

**Success Criteria**:
- [ ] Progress indicator shows during processing
- [ ] Suggestion record created with Pending status
- [ ] All parameter fields populated
- [ ] Confidence score displayed
- [ ] Current vs Suggested comparison visible

#### UAT-003: Review and Approve Suggestion
**Objective**: User can review and approve parameter suggestions
**Preconditions**: Pending suggestion exists
**Steps**:
1. Open Planning Parameter Suggestions list
2. Filter to Pending status
3. Select a suggestion
4. Review Current vs Suggested values
5. View forecast chart (if available)
6. Click "Approve" action
7. Confirm approval

**Success Criteria**:
- [ ] Clear comparison of current vs suggested values
- [ ] Calculation notes explain reasoning
- [ ] Confidence score visible
- [ ] Approval updates status
- [ ] Reviewed By/DateTime populated

#### UAT-004: Apply Approved Suggestions
**Objective**: User can apply approved suggestions to items
**Preconditions**: Approved suggestion exists
**Steps**:
1. Select approved suggestion
2. Click "Apply to Item" action
3. Select which parameters to apply (checkbox for each)
4. Confirm application
5. Verify Item card updated

**Success Criteria**:
- [ ] Selective parameter application works
- [ ] Item planning parameters updated
- [ ] Suggestion status changes to Applied
- [ ] Audit trail created

#### UAT-005: Batch Process Multiple Items
**Objective**: User can generate suggestions for multiple items
**Preconditions**: Multiple items with history exist
**Steps**:
1. Open Item List
2. Select multiple items (or apply filter)
3. Run "Generate Planning Suggestions" batch action
4. Monitor progress
5. Review results

**Success Criteria**:
- [ ] Progress indicator shows items remaining
- [ ] Processing continues on individual item errors
- [ ] Summary displayed at completion
- [ ] Failed items listed with reasons

#### UAT-006: Handle Insufficient Data
**Objective**: System handles items with insufficient history gracefully
**Preconditions**: Item with < 30 transactions
**Steps**:
1. Open Item Card for low-history item
2. Attempt to generate suggestion
3. Observe error handling

**Success Criteria**:
- [ ] Clear message: "Insufficient history (X points, minimum 30)"
- [ ] No partial suggestion created
- [ ] User can see data points counted

#### UAT-007: Reject and Override Suggestion
**Objective**: User can reject suggestions and document reasons
**Preconditions**: Pending suggestion exists
**Steps**:
1. Select pending suggestion
2. Click "Reject" action
3. Enter override reason (required)
4. Confirm rejection
5. Verify item unchanged

**Success Criteria**:
- [ ] Reason field is required
- [ ] Status changes to Rejected
- [ ] Item parameters unchanged
- [ ] Override reason saved for audit

### 5.5 Performance Tests

| Test ID | Test Case | Target | Measurement |
|---------|-----------|--------|-------------|
| PT-001 | Single item processing | < 10 seconds | End-to-end time |
| PT-002 | Batch of 100 items | < 10 minutes | Total processing time |
| PT-003 | Data collection (1 year) | < 2 seconds | Query execution time |
| PT-004 | JSON payload build (5000 points) | < 500ms | Serialization time |
| PT-005 | Suggestion list page load | < 1 second | Page render time |
| PT-006 | Concurrent users (10) | No errors | System stability |

### 5.6 Test Data Requirements

**Minimum Test Data Set**:
- 10 Items with 24+ months sales history (varied patterns)
- 5 Items with seasonal patterns (holidays, summer peak)
- 5 Items with trending patterns (growth, decline)
- 5 Items with erratic demand
- 3 Items with insufficient history (< 30 points)
- 2 Items with zero demand
- Multiple locations with SKU-level safety stock

### 5.7 Validated Calculation Tests (Completed)

The following calculations have been validated against Business Central with real data.

#### Test Data Used
| Parameter | Value |
|-----------|-------|
| Item No. | 1896-S |
| Analysis Period | 60 months (1,827 calendar days) |
| Days with Demand | 66 |
| Total Demand | 611 units |

#### VT-001: Average Daily Demand
**Status**: ✓ PASSED

**Formula**:
```
AvgDailyDemand = TotalDemand / CalendarDays
```

**Calculation**:
```
AvgDailyDemand = 611 / 1,827 = 0.334
```

**Key Design Decision**: Uses calendar days (not demand-days) to calculate true daily average. This prevents inflated averages that would occur if only counting days with actual demand.

#### VT-002: Standard Deviation (Calendar-Days Method)
**Status**: ✓ PASSED

**Formula**:
```
StdDev = √(SumSquaredDiff / (CalendarDays - 1))

Where:
  SumSquaredDiff = Σ(Qᵢ - AvgDailyDemand)² for demand days
                 + (CalendarDays - DemandDays) × AvgDailyDemand² for zero-demand days
```

**Calculation**:
```
Step 1: Sum squared differences for 66 demand days
        = ΣQᵢ² - 2×0.334×611 + 66×(0.334)²
        = 7,513 - 408.6 + 7.4 = 7,112

Step 2: Add zero-demand days (1,761 days)
        = 1,761 × (0.334)² = 197

Step 3: Total and StdDev
        = √((7,112 + 197) / 1,826) = √4.00 = 2.00
```

**BC Result**: 2.00 ✓

**Key Design Decision**: Standard deviation includes zero-demand days to accurately capture intermittent demand variability. This is critical for proper Safety Stock calculation since lead time includes all calendar days, not just days with demand.

#### Comparison: Demand-Days vs Calendar-Days Approach

| Metric | Demand-Days (Old) | Calendar-Days (New) |
|--------|-------------------|---------------------|
| Days in calculation | 66 | 1,827 |
| Average Daily Demand | 9.26 | 0.334 |
| Standard Deviation | ~4.5 | 2.00 |
| Impact | Overstated demand | Accurate daily rate |

The calendar-days approach produces realistic planning parameters for intermittent demand items.

#### VT-003: Safety Stock Calculation
**Status**: ✓ PASSED

**Formula**:
```
Safety Stock = (Z × σ × √(L + R)) + (MAE × Z)
```

**BC Field Sources**:
| Variable | Description | BC Field |
|----------|-------------|----------|
| Z | Service Level Z-Score | `Planning Analysis Setup."Safety Stock Multiplier"` |
| σ | Standard Deviation | Calculated from `Item Ledger Entry` (calendar-days method) |
| L | Lead Time (days) | `Item."Lead Time Calculation"` or `SKU."Lead Time Calculation"` |
| R | Review Period (days) | `Item."Time Bucket"` or `SKU."Time Bucket"` |
| MAE | Mean Absolute Error | Estimated from σ (without Prophet) |

**Example Calculation**:
```
Given:
  Z = 1.65 (95% service level)
  σ = 2.00
  L = 7 days (Lead Time Calculation = <1W>)
  R = 7 days (Time Bucket = <1W>)
  MAE = 2.00

Safety Stock = (1.65 × 2.00 × √(7 + 7)) + (2.00 × 1.65)
             = (1.65 × 2.00 × 3.74) + 3.30
             = 12.34 + 3.30
             = 15.64 ≈ 16
```

**Key Design Decisions**:
- Review Period (R) sourced from BC's Time Bucket field, which represents the planning review cycle
- Falls back to 7 days (weekly) if Time Bucket is not configured
- SKU-level values take priority over Item-level values for location-specific suggestions
- Includes MAE buffer for forecast uncertainty

#### VT-004: Reorder Point Calculation
**Status**: ✓ PASSED

**Formula**:
```
Reorder Point = (AvgDailyDemand × L) + Safety Stock
```

**BC Field Sources**:
| Variable | Description | BC Field |
|----------|-------------|----------|
| AvgDailyDemand | Average Daily Demand | Calculated from `Item Ledger Entry` (TotalDemand / CalendarDays) |
| L | Lead Time (days) | `Item."Lead Time Calculation"` or `SKU."Lead Time Calculation"` |
| Safety Stock | Safety Stock | Calculated via VT-003 formula |

**Example Calculation**:
```
Given:
  AvgDailyDemand = 0.334 (from VT-001)
  L = 7 days (Lead Time Calculation = <1W>)
  Safety Stock = 16 (from VT-003)

Reorder Point = (0.334 × 7) + 16
              = 2.34 + 16
              = 18.34 ≈ 18
```

**Key Design Decisions**:
- Lead Time Demand represents expected consumption during replenishment
- Uses calendar-days Average Daily Demand (not demand-days) for consistency
- SKU-level Lead Time Calculation takes priority over Item-level for location-specific suggestions
- Converts DateFormula to integer days using CalcDate calculation

#### VT-005: Reorder Quantity (EOQ) Calculation
**Status**: ✓ PASSED

**Formula**:
```
EOQ = √((2 × D × S) / H)
```

**BC Field Sources**:
| Variable | Description | BC Field |
|----------|-------------|----------|
| D | Annual Demand | Calculated: `TotalDemand × (365 / CalendarDays)` from `Item Ledger Entry` |
| S | Order/Setup Cost | `Planning Analysis Setup."Default Order Cost"` |
| H | Holding Cost per unit/year | `Item."Unit Cost"` × `Planning Analysis Setup."Holding Cost Rate"` / 100 |

**Example Calculation**:
```
Given (using Item 1896-S):
  TotalDemand = 611 units over 1,827 calendar days
  AnnualDemand = 611 × (365 / 1827) = 122 units/year
  OrderCost = $50 (from Setup.Default Order Cost)
  UnitCost = $10 (from Item.Unit Cost)
  HoldingCostRate = 25% (from Setup.Holding Cost Rate)
  HoldingCost = $10 × 0.25 = $2.50/unit/year

EOQ = √((2 × 122 × 50) / 2.50)
    = √(12,200 / 2.50)
    = √4,880
    = 69.86 ≈ 70
```

**Key Design Decisions**:
- Uses classic Economic Order Quantity formula to balance ordering costs vs holding costs
- Annual Demand extrapolated from analysis period using calendar days
- Fallback to monthly quantity (AnnualDemand / 12) if Holding Cost ≤ 0 or EOQ < 1
- SKU-level Unit Cost takes priority over Item-level for location-specific suggestions

#### VT-006: Maximum Inventory Calculation
**Status**: ✓ PASSED

**Formula**:
```
Standard:
  Maximum Inventory = Reorder Point + Reorder Quantity

Seasonal Adjustment (when Demand Pattern = Seasonal):
  Maximum Inventory = (Reorder Point + Reorder Quantity) × Peak Season Multiplier
```

**BC Field Sources**:
| Variable | Description | BC Field |
|----------|-------------|----------|
| Reorder Point | Calculated Reorder Point | From VT-004 formula |
| Reorder Quantity | Calculated EOQ | From VT-005 formula |
| Peak Season Multiplier | Seasonal buffer (1.0-2.0) | `Planning Analysis Setup."Peak Season Multiplier"` |
| Demand Pattern | Detected pattern | Calculated from `Item Ledger Entry` statistics |

**Example Calculation**:
```
Given (using Item 1896-S, non-seasonal):
  Reorder Point = 18 (from VT-004)
  Reorder Quantity = 70 (from VT-005)
  Demand Pattern = Stable

Maximum Inventory = 18 + 70 = 88

If Seasonal (with Peak Season Multiplier = 1.3):
Maximum Inventory = (18 + 70) × 1.3 = 114.4 ≈ 114
```

**When Seasonal Adjustment is Applied**:
The system automatically detects seasonality by comparing demand in the first half vs second half of the analysis period. If the halves differ by more than 20%, the demand pattern is classified as "Seasonal" and the Peak Season Multiplier is applied.

**Key Design Decisions**:
- Maximum Inventory represents peak inventory level immediately after replenishment arrival
- Seasonal adjustment provides buffer for peak demand periods
- Peak Season Multiplier is configurable in Setup (default 1.3 = 30% increase)
- Seasonal detection compares first-half vs second-half average demand (>20% difference triggers seasonal classification)

#### VT-007: Lot Accumulation Period Calculation
**Status**: ✓ PASSED

**Formula**:
```
Step 1: Calculate Annual Demand
   AnnualDemand = TotalDemand × (365 / CalendarDays)

Step 2: Calculate Orders Per Year
   OrdersPerYear = AnnualDemand / ReorderQuantity

Step 3: Calculate Average Days Between Orders
   AvgDaysBetweenOrders = 365 / OrdersPerYear

Step 4: Map to DateFormula
   ≤7 days   → <1W> (1 Week)
   ≤14 days  → <2W> (2 Weeks)
   ≤30 days  → <1M> (1 Month)
   >30 days  → <2M> (2 Months)
```

**BC Field Sources**:
| Variable | Description | BC Field |
|----------|-------------|----------|
| TotalDemand | Total historical demand | Calculated from `Item Ledger Entry` |
| CalendarDays | Analysis period days | `Analysis Period End - Analysis Period Start + 1` |
| ReorderQuantity | Calculated EOQ | From VT-005 formula |

**Example Calculation**:
```
Given (using Item 1896-S):
  TotalDemand = 611 units over 1,827 calendar days
  AnnualDemand = 611 × (365 / 1827) = 122 units/year
  ReorderQuantity = 70 (from VT-005)

OrdersPerYear = 122 / 70 = 1.74 orders/year

AvgDaysBetweenOrders = 365 / 1.74 = 210 days

Since 210 > 30 days → Suggested Lot Accum Period = <2M>
```

**Key Design Decisions**:
- Lot Accumulation Period aligns with expected ordering frequency from EOQ
- Longer periods = fewer, larger planned orders
- Fallback to `<1M>` if ReorderQuantity ≤ 0
- Fallback to `<2M>` if OrdersPerYear ≤ 0
- Purpose: Tells BC's planning engine how long to accumulate demand before creating a single planned order

---

## 6. Implementation Roadmap

### Phase 1: Foundation (Tables & Setup)
1. Create all tables (50110-50113)
2. Create enumerations (50110-50112)
3. Create Item table extension
4. Create Planning Analysis Setup page
5. Create permission sets

### Phase 2: Data Collection
1. Implement demand history collection codeunit
2. Add data quality validation
3. Create data aggregation logic
4. Build Prophet-compatible JSON structure

### Phase 3: API Integration
1. Implement HTTP client for Prophet
2. Add retry logic and error handling
3. Create API logging
4. Build response parser

### Phase 4: Calculation Engine
1. Implement safety stock calculation
2. Implement reorder point calculation
3. Implement EOQ calculation
4. Implement policy determination
5. Add confidence scoring

### Phase 5: User Interface
1. Create Planning Suggestions list page
2. Create suggestion detail card
3. Add Item Card integration
4. Add batch processing actions
5. Create comparison views

### Phase 6: Testing & Deployment
1. Execute unit tests
2. Execute integration tests
3. Perform UAT
4. Performance testing
5. Documentation
6. Production deployment

---

## Appendix A: Prophet Request/Response JSON Schema

### Request Schema
```json
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "type": "object",
  "required": ["itemNo", "dataPoints", "forecastPeriods"],
  "properties": {
    "itemNo": { "type": "string", "maxLength": 20 },
    "locationCode": { "type": "string", "maxLength": 10 },
    "dataPoints": {
      "type": "array",
      "minItems": 30,
      "items": {
        "type": "object",
        "required": ["ds", "y"],
        "properties": {
          "ds": { "type": "string", "format": "date" },
          "y": { "type": "number", "minimum": 0 }
        }
      }
    },
    "forecastPeriods": { "type": "integer", "minimum": 1, "maximum": 365 },
    "includeHolidays": { "type": "boolean" },
    "holidayCountry": { "type": "string", "pattern": "^[A-Z]{2}$" },
    "seasonalityMode": { "enum": ["additive", "multiplicative"] },
    "changePointPriorScale": { "type": "number", "minimum": 0.001, "maximum": 0.5 },
    "requestId": { "type": "string", "format": "uuid" }
  }
}
```

### Response Schema
```json
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "type": "object",
  "required": ["itemNo", "forecast", "metrics"],
  "properties": {
    "itemNo": { "type": "string" },
    "forecast": {
      "type": "array",
      "items": {
        "type": "object",
        "required": ["ds", "yhat"],
        "properties": {
          "ds": { "type": "string", "format": "date" },
          "yhat": { "type": "number" },
          "yhat_lower": { "type": "number" },
          "yhat_upper": { "type": "number" }
        }
      }
    },
    "trend": { "type": "object" },
    "seasonality": {
      "type": "object",
      "properties": {
        "weekly": { "type": "object" },
        "yearly": { "type": "object" }
      }
    },
    "metrics": {
      "type": "object",
      "required": ["mae", "mape"],
      "properties": {
        "mae": { "type": "number", "minimum": 0 },
        "mape": { "type": "number", "minimum": 0, "maximum": 100 },
        "rmse": { "type": "number", "minimum": 0 }
      }
    },
    "changePoints": {
      "type": "array",
      "items": { "type": "string", "format": "date" }
    },
    "demandPattern": {
      "enum": ["Stable", "Seasonal", "Trending", "Erratic", "Intermittent"]
    }
  }
}
```

---

## Appendix B: Service Level Z-Scores

| Service Level | Z-Score |
|--------------|---------|
| 90.0% | 1.28 |
| 92.0% | 1.41 |
| 95.0% | 1.65 |
| 97.0% | 1.88 |
| 98.0% | 2.05 |
| 99.0% | 2.33 |
| 99.5% | 2.58 |
| 99.9% | 3.09 |
