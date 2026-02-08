# Vendor Performance System
## Technical Documentation

**Document Version:** 1.0
**Last Updated:** February 2026
**Extension Version:** 1.0.0.11

---

## 1. Overview

The Vendor Performance System provides comprehensive tracking and scoring of vendor reliability across four dimensions: delivery, lead time, quality, and pricing. Performance data is calculated from actual transaction history and used for vendor selection recommendations.

---

## 2. Data Flow Architecture

```
Purchase Receipt Posted
        │
        ├──► Lead Time Variance Entry (created automatically)
        │         │
        │         ▼
        │    Delivery Performance
        │    (On-Time Delivery %)
        │         │
        │         ▼
        │    Lead Time Metrics
        │    (Lead Time Reliability %)
        │
        ├──► Vendor NCR (if quality failure)
        │         │
        │         ▼
        │    Quality Metrics
        │    (Quality Accept Rate %)
        │
        └──► Value Entry
                  │
                  ▼
             Pricing Metrics
             (Price Competitiveness Score)
                  │
                  ▼
        ══════════════════════
        │  Overall Score     │
        │  (Weighted Avg)    │
        ══════════════════════
                  │
                  ▼
        Vendor Risk Level
        Score Trend
```

---

## 3. Metric Calculations

### 3.1 On-Time Delivery % (Delivery Performance)

**Source Data:** Lead Time Variance Entry table

**Calculation:**

```
On-Time Delivery % = (On-Time Receipts / Total Receipts) × 100
```

**Delivery Status Determination:**

Each Lead Time Variance Entry is classified based on the **On-Time Tolerance Days** setting in Manufacturing Setup:

| Variance Days | Status | Counted As |
|---------------|--------|------------|
| < -ToleranceDays | Early | Early Receipt |
| -ToleranceDays to +ToleranceDays | On Time | On-Time Receipt |
| > +ToleranceDays | Late | Late Receipt |

**Example:**
- On-Time Tolerance Days = 2 (from Manufacturing Setup)
- Promised Date: Jan 15
- Actual Receipt: Jan 13 (2 days early) → **On Time** (within tolerance)
- Actual Receipt: Jan 12 (3 days early) → **Early**
- Actual Receipt: Jan 18 (3 days late) → **Late**

**Code Reference:** [VendorPerformanceCalculatorCodeunit.al](../src/VendorPerformance/VendorPerformanceCalculatorCodeunit.al) lines 100-133

```al
local procedure CalculateDeliveryPerformance(var VendorPerf: Record "Vendor Performance")
var
    LeadTimeVariance: Record "Lead Time Variance Entry";
    TotalReceipts: Integer;
    OnTimeReceipts: Integer;
begin
    LeadTimeVariance.SetRange("Vendor No.", VendorPerf."Vendor No.");
    LeadTimeVariance.SetRange("Actual Receipt Date", VendorPerf."Period Start Date", VendorPerf."Period End Date");

    if LeadTimeVariance.FindSet() then
        repeat
            TotalReceipts += 1;
            case LeadTimeVariance."Delivery Status" of
                LeadTimeVariance."Delivery Status"::"On Time":
                    OnTimeReceipts += 1;
                // ... Early and Late counted separately
            end;
        until LeadTimeVariance.Next() = 0;

    if TotalReceipts > 0 then
        VendorPerf."On-Time Delivery %" := Round((OnTimeReceipts / TotalReceipts) * 100, 0.01);
end;
```

---

### 3.2 Lead Time Reliability % (Variance Analysis)

**Source Data:** Lead Time Variance Entry table

**Calculation:**

```
Lead Time Reliability % = (Within Tolerance Count / Total Count) × 100
```

**Tolerance Check (Percentage-Based):**

Each entry is checked against the **Lead Time Variance Tolerance %** setting in Manufacturing Setup:

```
Variance Ratio = |Actual Variance Days| / Promised Lead Time Days × 100

IF Variance Ratio ≤ Lead Time Variance Tolerance % THEN
    Within Tolerance = TRUE
ELSE
    Within Tolerance = FALSE
```

**Important:** The calculation uses **absolute value** - both early AND late deliveries count against reliability.

**Rationale for penalizing early deliveries:**
- **Storage costs:** Early arrivals require warehouse space before needed
- **Cash flow impact:** Payment terms may start before materials are needed
- **Receiving capacity:** Unexpected arrivals can overwhelm receiving staff
- **Quality concerns:** Items may degrade if stored longer than planned

**Example:**
- Lead Time Variance Tolerance % = 20% (from Manufacturing Setup)
- Promised Lead Time: 10 days
- Tolerance threshold: 10 × 20% = 2 days variance allowed

| Scenario | Promised | Actual | Variance | Ratio | Within Tolerance? |
|----------|----------|--------|----------|-------|-------------------|
| Receipt A | 10 days | 11 days | +1 day | 10% | Yes |
| Receipt B | 10 days | 13 days | +3 days | 30% | No |
| Receipt C | 10 days | 8 days | -2 days | 20% | Yes (boundary) |

**Additional Metrics Calculated:**

| Metric | Formula |
|--------|---------|
| Avg Promised Lead Time Days | Sum(Promised Days) / Count |
| Avg Actual Lead Time Days | Sum(Actual Days) / Count |
| Lead Time Variance Days | Avg Actual - Avg Promised |
| Lead Time Std Dev | Standard deviation of variance days |

**Code Reference:** [VendorPerformanceCalculatorCodeunit.al](../src/VendorPerformance/VendorPerformanceCalculatorCodeunit.al) lines 135-201

```al
local procedure CalculateLeadTimeMetrics(var VendorPerf: Record "Vendor Performance")
var
    MfgSetup: Record "Manufacturing Setup";
    TolerancePct: Decimal;
    AvgPromised: Decimal;
    WithinToleranceCount: Integer;
begin
    MfgSetup.Get();
    TolerancePct := MfgSetup."Lead Time Variance Tolerance %";

    // For each Lead Time Variance Entry:
    if AvgPromised > 0 then begin
        // Check if variance is within tolerance percentage
        if Abs(TempLeadTimeData."Variance Days" / AvgPromised * 100) <= TolerancePct then
            WithinToleranceCount += 1;
    end;

    VendorPerf."Lead Time Reliability %" := Round((WithinToleranceCount / Count) * 100, 0.01);
end;
```

---

### 3.3 Quality Accept Rate %

**Source Data:** Purchase Receipt Lines + Vendor NCR records

**Calculation:**

```
Quality Accept Rate % = ((Total Qty Received - Qty Rejected) / Total Qty Received) × 100
```

**Important:** NCRs are matched by **receipt posting date**, not NCR creation date. This ensures rejected quantities are compared against the same period's receipts.

**Example:**
- Period: January 2026
- Total Qty Received: 265 units
- NCRs linked to January receipts: 5 units affected
- Quality Accept Rate = (265 - 5) / 265 × 100 = **98.11%**

**Code Reference:** [VendorPerformanceCalculatorCodeunit.al](../src/VendorPerformance/VendorPerformanceCalculatorCodeunit.al) lines 204-244

---

### 3.4 Price Competitiveness Score

**Source Data:** Posted Purchase Invoice Lines vs Item Standard Cost

**Calculation:**

```
For each invoice line:
    IF Actual Cost > Standard Cost THEN
        Price Variance % = (Actual Cost - Standard Cost) / Standard Cost × 100
    ELSE
        Price Variance % = 0  (lower prices are rewarded with no penalty)

Avg Price Variance % = Sum(Price Variance %) / Line Count

Price Competitiveness Score = 100 - Avg Price Variance %
                              (capped at 0 minimum)
```

**Key Difference from Previous "Price Stability":**
- Vendors are **rewarded** for lower prices (no penalty when Actual ≤ Standard)
- Only prices **above** the expected cost reduce the score

---

## 4. Overall Score Calculation

The Overall Score is a weighted average of all four metrics:

```
Overall Score = (On-Time Delivery % × OTD Weight / Total)
              + (Quality Accept Rate % × Quality Weight / Total)
              + (Lead Time Reliability % × LT Weight / Total)
              + (Price Competitiveness Score × Price Weight / Total)
```

**Default Weights (from Manufacturing Setup):**

| Metric | Weight | Rationale |
|--------|--------|-----------|
| On-Time Delivery % | 30% | Late deliveries disrupt production |
| Quality Accept Rate % | 30% | Quality issues cause rework/returns |
| Lead Time Reliability % | 25% | Predictable lead times enable planning |
| Price Competitiveness Score | 15% | Rewards vendors with competitive pricing |

**Example Calculation:**

| Metric | Value | Weight | Contribution |
|--------|-------|--------|--------------|
| On-Time Delivery % | 80% | 30% | 24.0 |
| Quality Accept Rate % | 95% | 30% | 28.5 |
| Lead Time Reliability % | 90% | 25% | 22.5 |
| Price Competitiveness Score | 85% | 15% | 12.75 |
| **Overall Score** | | | **87.75** |

**Code Reference:** [VendorPerformanceCalculatorCodeunit.al](../src/VendorPerformance/VendorPerformanceCalculatorCodeunit.al) lines 287-318

---

## 5. Lead Time Variance Entry

### 5.1 Automatic Creation

Lead Time Variance Entries are created automatically when purchase receipts are posted:

**Event Subscriber:** `OnAfterPurchRcptLineInsert` in Codeunit 50121 "Lead Time Variance Tracker"

**Data Captured:**

| Field | Source |
|-------|--------|
| Vendor No. | Purchase Receipt Line |
| Item No. | Purchase Receipt Line |
| Order Date | Purchase Header |
| Promised Receipt Date | Calculated (see priority below) |
| Actual Receipt Date | Posting Date |
| Variance Days | Actual - Promised |
| Delivery Status | Calculated from On-Time Tolerance Days |
| Variance % | \|Variance Days\| / Promised Lead Time Days × 100 |
| Within LT Tolerance | TRUE if Variance % ≤ Lead Time Variance Tolerance % |

**New Fields for Lead Time Reliability:**

The `Variance %` and `Within LT Tolerance` fields make it easy to see at a glance which entries count as "reliable" for the Lead Time Reliability % calculation:

- **Variance %**: Shows the variance as a percentage of the promised lead time
- **Within LT Tolerance**: Boolean indicating if this entry contributes positively to Lead Time Reliability %

### 5.2 Promised Receipt Date Priority

**For Real-Time Entries (new receipts):**

The promised date is determined in this order:
1. **Purchase Line "Promised Receipt Date"** - If explicitly set
2. **Purchase Line "Expected Receipt Date"** - If set
3. **Purchase Header "Expected Receipt Date"** - If set on header
4. **Order Date + Lead Time Calculation** - See Lead Time Priority below
5. **Order Date + 7 days** - Default fallback

**For Historical Entries (from Posted Receipt Lines):**

1. **Purch. Rcpt. Line "Promised Receipt Date"** - If explicitly set
2. **Purch. Rcpt. Line "Expected Receipt Date"** - If set
3. **Purch. Rcpt. Header "Expected Receipt Date"** - If set on header
4. **Order Date + Lead Time Calculation** - See Lead Time Priority below
5. **Order Date + 7 days** - Default fallback

### 5.3 Lead Time Calculation Priority

**Important:** This priority is ONLY used as a fallback when the document has no Promised/Expected Receipt Date fields populated. If dates exist on the document, they take precedence and this calculation is skipped.

When calculating Lead Time from master data, the following priority is used:

| Priority | Level | Description |
|----------|-------|-------------|
| 1 (Highest) | Item Vendor Catalog | Most specific; used when a specific item is bought from a specific vendor |
| 2 | Stockkeeping Unit (SKU) | Used if defined for a specific location/variant |
| 3 | Item Card | The default lead time for the item, regardless of the vendor |
| 4 (Lowest) | Vendor Card | The general lead time for that vendor, used if no item-specific lead time exists |

**Code Reference:** [LeadTimeVarianceTrackerCodeunit.al](../src/VendorPerformance/LeadTimeVarianceTrackerCodeunit.al) lines 75-103

```al
// Priority: Item Vendor > SKU > Item > Vendor
if ItemVendor.Get(VendorNo, ItemNo, VariantCode) then
    if Format(ItemVendor."Lead Time Calculation") <> '' then
        exit(ItemVendor."Lead Time Calculation");

if SKU.Get(LocationCode, ItemNo, VariantCode) then
    if Format(SKU."Lead Time Calculation") <> '' then
        exit(SKU."Lead Time Calculation");

if Item.Get(ItemNo) then
    if Format(Item."Lead Time Calculation") <> '' then
        exit(Item."Lead Time Calculation");

if Vendor.Get(VendorNo) then
    if Format(Vendor."Lead Time Calculation") <> '' then
        exit(Vendor."Lead Time Calculation");

// Default: 7 days
```

### 5.4 Variance Calculation (in Table OnInsert)

```al
trigger OnInsert()
begin
    // Calculate variance
    "Variance Days" := "Actual Receipt Date" - "Promised Receipt Date";

    // Determine on-time status using On-Time Tolerance Days
    MfgSetup.Get();
    ToleranceDays := MfgSetup."On-Time Tolerance Days";
    "On Time" := Abs("Variance Days") <= ToleranceDays;

    // Set delivery status
    if "Variance Days" < -ToleranceDays then
        "Delivery Status" := "Delivery Status"::Early
    else if "Variance Days" > ToleranceDays then
        "Delivery Status" := "Delivery Status"::Late
    else
        "Delivery Status" := "Delivery Status"::"On Time";
end;
```

---

## 6. Configuration Settings

### Manufacturing Setup Fields

| Field | Type | Description | Default |
|-------|------|-------------|---------|
| On-Time Tolerance Days | Integer | Fixed days variance allowed for On-Time status | 2 |
| Lead Time Variance Tolerance % | Decimal | Percentage variance allowed for reliability | 20% |
| On-Time Delivery Weight | Decimal | Weight for delivery score | 30 |
| Quality Weight | Decimal | Weight for quality score | 30 |
| Lead Time Reliability Weight | Decimal | Weight for lead time score | 25 |
| Price Competitiveness Weight | Decimal | Weight for price score | 15 |
| Perf Calc Period Months | Integer | Months of history for calculations | 12 |
| Low Risk Score Threshold | Decimal | Score >= this = Low Risk | 80 |
| Medium Risk Score Threshold | Decimal | Score >= this = Medium Risk | 60 |
| High Risk Score Threshold | Decimal | Score >= this = High Risk | 40 |
| Auto-Create NCR from Quality | Boolean | Auto-create NCR when Quality Order fails | false |

---

## 7. Two Tolerance Settings Explained

### On-Time Tolerance Days (Fixed Days)
- **Purpose:** Classifies each delivery as On Time/Early/Late
- **Used For:** Counting on-time receipts for On-Time Delivery %
- **Type:** Fixed number of days
- **Example:** 2 days tolerance means ±2 days from promised date is "On Time"

### Lead Time Variance Tolerance % (Percentage)
- **Purpose:** Determines if variance is acceptable relative to lead time
- **Used For:** Calculating Lead Time Reliability %
- **Type:** Percentage of promised lead time
- **Example:** 20% tolerance on 10-day lead time = ±2 days acceptable

**Why Two Settings?**
- On-Time Tolerance Days: Fair comparison regardless of lead time length
- Lead Time Variance Tolerance %: Proportional assessment (longer lead times get more slack)

---

## 8. Risk Level Determination

Based on Overall Score:

| Score Range | Risk Level | Color |
|-------------|------------|-------|
| ≥ 80 | Low | Green/Favorable |
| 60-79 | Medium | Yellow/Ambiguous |
| 40-59 | High | Orange/Attention |
| < 40 | Critical | Red/Unfavorable |

---

## 9. Score Trend Calculation

Compares rolling 3-month averages:

```
Recent Average = Average of last 3 months' scores
Previous Average = Average of months 4-6

If Recent - Previous > 5%: Trend = Improving
If Recent - Previous < -5%: Trend = Declining
Otherwise: Trend = Stable
```

---

## 10. Actions for Recalculation

### From Vendor Card

| Action | Description |
|--------|-------------|
| Recalculate Performance | Current month only |
| Calculate Historical (Monthly) | Month-by-month for configured period |
| Calculate Full Period | Entire period as one aggregated result |

### From Vendor Suggestion Test Data Page

| Action | Description |
|--------|-------------|
| Delete ALL Lead Time Variance Entries | Clear all entries (reset) |
| Delete ALL Vendor Performance Records | Clear all records |

---

## 11. Integration Points

### Vendor Card Extension
- Performance Score, Risk Level, Trend displayed
- On-Time Delivery %, Quality Accept Rate %, Lead Time Variance Days shown
- DrillDown on Performance Score opens history

### Purchase Suggestions
- Vendor Performance Score feeds into overall vendor ranking
- On-Time Delivery % and Quality Accept Rate % are weighted 30% each

### Quality Management
- Failed Quality Orders auto-create NCRs (if enabled)
- NCRs reduce Quality Accept Rate %

---

## 12. Object Reference

| Type | ID | Name |
|------|-----|------|
| Table | 50120 | Vendor Performance |
| Table | 50121 | Lead Time Variance Entry |
| Page | 50120 | Vendor Performance List |
| Page | 50121 | Vendor Performance Card |
| Page | 50122 | Vendor Score Factbox |
| Page | 50123 | Lead Time Variance Entries |
| Codeunit | 50120 | Vendor Performance Calculator |
| Codeunit | 50121 | Lead Time Variance Tracker |
| Page Ext | 50120 | Vendor Card Perf Ext |
| Table Ext | 50120 | Vendor Perf Ext |
| Enum | 50120 | Vendor Score Trend |
| Enum | 50121 | Vendor Risk Level |
| Enum | 50122 | Delivery Status |

---

*End of Document*
