# Vendor Suggestion System
## Complete Technical and Functional Specification

**Document Version:** 3.0
**Last Updated:** February 7, 2026
**Extension Version:** 1.0.0.10
**Author:** Riley Bleeker
**Classification:** Internal Technical Documentation

---

## Table of Contents

1. [Executive Summary](#1-executive-summary)
2. [System Architecture](#2-system-architecture)
3. [Database Schema](#3-database-schema)
4. [Scoring Algorithm](#4-scoring-algorithm)
5. [User Interface Components](#5-user-interface-components)
6. [Vendor No. Lookup Integration](#6-vendor-no-lookup-integration)
7. [Business Logic](#7-business-logic)
8. [Data Flow Diagrams](#8-data-flow-diagrams)
9. [Configuration](#9-configuration)
10. [Test Scenarios](#10-test-scenarios)
11. [Troubleshooting](#11-troubleshooting)
12. [Object Reference](#12-object-reference)

---

## 1. Executive Summary

### 1.1 Purpose

The Vendor Suggestion System provides intelligent, data-driven vendor recommendations for purchasing decisions in Microsoft Dynamics 365 Business Central. It automatically analyzes all available vendors for each item, scores them across four weighted dimensions, and presents ranked recommendations directly within the standard BC workflow.

### 1.2 Key Features

| Feature | Description |
|---------|-------------|
| **Automatic Vendor Ranking** | Scores and ranks all vendors for an item based on quality, delivery, lead time, and price |
| **Vendor Comparison Page** | Side-by-side comparison of all available vendors with color-coded scores |
| **Worksheet Integration** | Seamless integration into Requisition Worksheet and Planning Worksheet |
| **Lookup Override** | Vendor No. field lookup shows ranked vendors instead of standard list |
| **Recommendation Columns** | New columns showing recommended vendor, score, and alternatives |
| **One-Click Application** | Apply recommended vendor to multiple lines at once |

### 1.3 Business Value

- **Consistent Decisions**: Eliminates subjective vendor selection
- **Time Savings**: Reduces time spent comparing vendors manually
- **Cost Optimization**: Automatically considers price in vendor ranking
- **Quality Focus**: Prioritizes vendors with proven quality track records
- **Risk Reduction**: Identifies vendors that can meet delivery requirements

### 1.4 Version History

| Version | Date | Changes |
|---------|------|---------|
| 1.0 | Feb 2026 | Initial release with Purchase Suggestion table and Vendor Comparison page |
| 2.0 | Feb 2026 | Added Requisition Worksheet integration with lookup override |
| 3.0 | Feb 7, 2026 | Added Planning Worksheet integration (Page Extension 50153) |

---

## 2. System Architecture

### 2.1 Component Overview

```
┌─────────────────────────────────────────────────────────────────────┐
│                         USER INTERFACE LAYER                         │
├─────────────────────────────────────────────────────────────────────┤
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────────┐  │
│  │ Req. Worksheet  │  │Planning Worksheet│  │ Vendor Comparison  │  │
│  │ Page Ext 50150  │  │ Page Ext 50153  │  │    Page 50152      │  │
│  └────────┬────────┘  └────────┬────────┘  └──────────┬──────────┘  │
│           │                    │                      │              │
│           └────────────────────┼──────────────────────┘              │
│                                │                                     │
├────────────────────────────────┼─────────────────────────────────────┤
│                         BUSINESS LOGIC LAYER                         │
├────────────────────────────────┼─────────────────────────────────────┤
│                                ▼                                     │
│  ┌─────────────────────────────────────────────────────────────┐    │
│  │              Vendor Selector Codeunit 50151                  │    │
│  │  ┌─────────────┐ ┌─────────────┐ ┌─────────────┐            │    │
│  │  │GetRanked    │ │ScoreVendor  │ │GetLeadTime  │            │    │
│  │  │Vendors()    │ │ForItem()    │ │Score()      │            │    │
│  │  └─────────────┘ └─────────────┘ └─────────────┘            │    │
│  │  ┌─────────────┐ ┌─────────────┐ ┌─────────────┐            │    │
│  │  │GetPrice     │ │GetVendor    │ │GetRecommend │            │    │
│  │  │Score()      │ │Scores()     │ │ationReason()│            │    │
│  │  └─────────────┘ └─────────────┘ └─────────────┘            │    │
│  └─────────────────────────────────────────────────────────────┘    │
│                                                                      │
│  ┌─────────────────────────────────────────────────────────────┐    │
│  │         Purchase Suggestion Manager Codeunit 50150           │    │
│  │  ┌─────────────┐ ┌─────────────┐ ┌─────────────┐            │    │
│  │  │Generate     │ │Approve      │ │CreatePO     │            │    │
│  │  │Suggestion() │ │Suggestion() │ │FromSugg()   │            │    │
│  │  └─────────────┘ └─────────────┘ └─────────────┘            │    │
│  └─────────────────────────────────────────────────────────────┘    │
│                                                                      │
├──────────────────────────────────────────────────────────────────────┤
│                           DATA LAYER                                 │
├──────────────────────────────────────────────────────────────────────┤
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────────┐  │
│  │Purchase Suggest.│  │ Vendor Ranking  │  │ Requisition Line   │  │
│  │  Table 50150   │  │  Table 50151    │  │   Table Ext        │  │
│  │  (Persistent)   │  │  (Temporary)    │  │   (Extended)       │  │
│  └─────────────────┘  └─────────────────┘  └─────────────────────┘  │
│                                                                      │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────────┐  │
│  │     Vendor      │  │   Item Vendor   │  │       Item          │  │
│  │  (BC Standard)  │  │  (BC Standard)  │  │   (BC Standard)     │  │
│  └─────────────────┘  └─────────────────┘  └─────────────────────┘  │
└──────────────────────────────────────────────────────────────────────┘
```

### 2.2 Integration Points

| BC Object | Integration Type | Purpose |
|-----------|-----------------|---------|
| Requisition Line | Table Extension | Store recommendation fields |
| Req. Worksheet | Page Extension | Vendor lookup override, recommendation columns |
| Planning Worksheet | Page Extension | Vendor lookup override, recommendation columns |
| Vendor | Table Extension | Store performance metrics |
| Item Vendor | Read-Only | Source of vendor-item relationships |
| Item | Read-Only | Default vendor, lead time, unit cost |

---

## 3. Database Schema

### 3.1 Purchase Suggestion Table (50150)

The main persistent table for storing purchase recommendations.

| Field No. | Field Name | Data Type | Description |
|-----------|------------|-----------|-------------|
| 1 | Entry No. | Integer | Primary key (AutoIncrement) |
| 2 | Item No. | Code[20] | Item being purchased |
| 3 | Variant Code | Code[10] | Item variant (optional) |
| 4 | Location Code | Code[10] | Inventory location |
| 5 | Required Quantity | Decimal | Quantity needed |
| 6 | Required Date | Date | When items are needed |
| 10 | Vendor No. 1 | Code[20] | Top-ranked vendor |
| 11 | Vendor Name 1 | Text[100] | Cached vendor name |
| 12 | Vendor Score 1 | Decimal | Overall score (0-100) |
| 13 | Unit Cost 1 | Decimal | Vendor's unit cost |
| 14 | Lead Time 1 | Integer | Lead time in days |
| 15 | Can Meet Date 1 | Boolean | Can meet required date |
| 20 | Vendor No. 2 | Code[20] | Second-ranked vendor |
| 21-25 | ... | ... | Same fields for Vendor 2 |
| 30 | Vendor No. 3 | Code[20] | Third-ranked vendor |
| 31-35 | ... | ... | Same fields for Vendor 3 |
| 50 | Status | Enum | New/Under Review/Approved/PO Created/Rejected/Cancelled |
| 51 | Created Date | Date | When suggestion was created |
| 52 | Created By | Code[50] | User who created |
| 53 | Approved Date | Date | When approved |
| 54 | Approved By | Code[50] | User who approved |
| 55 | Purchase Order No. | Code[20] | Resulting PO number |
| 60 | Selected Vendor | Code[20] | Which vendor was selected |
| 61 | Recommendation Reason | Text[500] | Why this vendor was recommended |
| 70 | Planning Suggestion Entry No. | Integer | Link to Planning Suggestion |

### 3.2 Vendor Ranking Table (50151)

Temporary table used for vendor comparison operations.

| Field No. | Field Name | Data Type | Description |
|-----------|------------|-----------|-------------|
| 1 | Rank No. | Integer | Primary key (1 = best) |
| 2 | Vendor No. | Code[20] | Vendor identifier |
| 3 | Vendor Name | Text[100] | Cached vendor name |
| 4 | Item No. | Code[20] | Item being evaluated |
| 10 | Overall Score | Decimal | Calculated overall score (0-100) |
| 11 | Quality Score | Decimal | Quality component score |
| 12 | Delivery Score | Decimal | Delivery component score |
| 13 | Lead Time Score | Decimal | Lead time component score |
| 14 | Price Score | Decimal | Price component score |
| 15 | Performance Score | Decimal | Vendor's overall performance score |
| 20 | Unit Cost | Decimal | Vendor's unit cost for item |
| 21 | Total Cost | Decimal | Unit Cost × Quantity |
| 22 | Lead Time Days | Integer | Lead time in days |
| 23 | Expected Date | Date | Calculated delivery date |
| 24 | Can Meet Date | Boolean | Expected Date <= Required Date |

**Important:** This table has `TableType = Temporary`. Records exist only during the vendor comparison operation and are not persisted to the database.

### 3.3 Requisition Line Table Extension

Extended fields added to the standard Requisition Line table.

| Field No. | Field Name | Data Type | Description |
|-----------|------------|-----------|-------------|
| 50150 | Recommended Vendor No. | Code[20] | System's top recommendation |
| 50151 | Recommended Vendor Name | Text[100] | Cached vendor name |
| 50152 | Recommended Vendor Score | Decimal | Score of recommended vendor |
| 50153 | Recommended Unit Cost | Decimal | Cost from recommended vendor |
| 50154 | Recommended Lead Time | Integer | Lead time in days |
| 50155 | Alt Vendor Available | Boolean | True if >1 vendor exists |
| 50156 | Substitute Available | Boolean | True if substitute item available |
| 50157 | Substitute Item No. | Code[20] | Substitute item number |
| 50158 | Recommendation Enriched | Boolean | True if enrichment has run |

### 3.4 Vendor Table Extension (50120)

Extended fields for vendor performance metrics.

| Field No. | Field Name | Data Type | Description |
|-----------|------------|-----------|-------------|
| 50120 | Performance Score | Decimal | Overall performance (0-100) |
| 50121 | Performance Risk Level | Enum | Low/Medium/High/Critical |
| 50122 | On-Time Delivery % | Decimal | Percentage of on-time deliveries |
| 50123 | Quality Accept Rate % | Decimal | Percentage of accepted deliveries |
| 50124 | Lead Time Variance Days | Decimal | Average variance from promised |
| 50125 | Score Trend | Enum | Improving/Stable/Declining |
| 50126 | Last Performance Calc | DateTime | When metrics were last calculated |

---

## 4. Scoring Algorithm

### 4.1 Overall Score Formula

The overall vendor score is calculated using a weighted average of four component scores:

```
Overall Score = (Quality × 0.30) + (Delivery × 0.30) + (LeadTime × 0.25) + (Price × 0.15)
```

### 4.2 Component Score Calculations

#### 4.2.1 Quality Score (30% Weight)

**Source:** `Vendor."Quality Accept Rate %"`

**Calculation:**
```al
if Vendor."Quality Accept Rate %" > 0 then
    QualityScore := Vendor."Quality Accept Rate %"
else
    QualityScore := 50;  // No data = neutral score
```

**Interpretation:**
- 100 = Perfect quality (100% acceptance rate)
- 50 = No quality data available (neutral)
- 0 = All deliveries rejected

#### 4.2.2 Delivery Score (30% Weight)

**Source:** `Vendor."On-Time Delivery %"`

**Calculation:**
```al
if Vendor."On-Time Delivery %" > 0 then
    DeliveryScore := Vendor."On-Time Delivery %"
else
    DeliveryScore := 50;  // No data = neutral score
```

**Interpretation:**
- 100 = Perfect delivery (100% on-time)
- 50 = No delivery data available (neutral)
- 0 = All deliveries late

#### 4.2.3 Lead Time Score (25% Weight)

**Source:** Calculated from Item Vendor, SKU, or Item lead time vs. required date

**Data Priority:**
1. Stockkeeping Unit.Lead Time Calculation
2. Item Vendor.Lead Time Calculation
3. Item.Lead Time Calculation
4. Default: 7 days

**Calculation:**
```al
LeadTimeDays := GetVendorLeadTimeDays(VendorNo, ItemNo, LocationCode);
DaysUntilRequired := RequiredDate - Today;

if DaysUntilRequired <= 0 then
    DaysUntilRequired := 1;

if LeadTimeDays <= DaysUntilRequired then
    Score := 100  // Can meet the date
else begin
    // Penalize 5 points per day late
    Score := 100 - ((LeadTimeDays - DaysUntilRequired) * 5);
    if Score < 0 then
        Score := 0;
end;
```

**Interpretation:**
- 100 = Can deliver before or on required date
- 95 = 1 day late
- 90 = 2 days late
- 0 = 20+ days late

#### 4.2.4 Price Score (15% Weight)

**Source:** Calculated from vendor cost vs. item's unit cost

**Calculation:**
```al
VendorCost := GetVendorUnitCost(VendorNo, ItemNo, RequiredQty);

// Get baseline (best known cost)
if Item."Last Direct Cost" > 0 then
    BestCost := Item."Last Direct Cost"
else
    BestCost := Item."Unit Cost";

if BestCost = 0 then
    BestCost := VendorCost;

if (VendorCost = 0) or (BestCost = 0) then
    Score := 50  // No price data, neutral score
else if VendorCost <= BestCost then
    Score := 100  // Best or better price
else begin
    // Penalize based on price premium percentage
    PremiumPct := (VendorCost - BestCost) / BestCost * 100;
    Score := 100 - PremiumPct;
    if Score < 0 then
        Score := 0;
end;
```

**Interpretation:**
- 100 = Best price or better
- 90 = 10% above best price
- 50 = No price data (neutral)
- 0 = 100%+ above best price

### 4.3 Score Weighting Rationale

| Factor | Weight | Rationale |
|--------|--------|-----------|
| Quality | 30% | Quality issues are costly (returns, rework, customer impact) |
| Delivery | 30% | Late deliveries disrupt production and customer commitments |
| Lead Time | 25% | Ability to meet required dates is critical for planning |
| Price | 15% | Important but secondary to quality and reliability |

### 4.4 Worked Example

**Scenario:** Item WIDGET-100, Required Date = Feb 21 (14 days from today), Qty = 100

**Vendor A:**
- Quality Accept Rate: 98%
- On-Time Delivery: 95%
- Lead Time: 10 days (can meet date)
- Unit Cost: $10.00 (same as best)

**Calculation:**
```
Quality Score = 98
Delivery Score = 95
Lead Time Score = 100 (10 days < 14 days required)
Price Score = 100 (matches best price)

Overall = (98 × 0.30) + (95 × 0.30) + (100 × 0.25) + (100 × 0.15)
        = 29.4 + 28.5 + 25.0 + 15.0
        = 97.9
```

**Vendor B:**
- Quality Accept Rate: 85%
- On-Time Delivery: 80%
- Lead Time: 18 days (4 days late)
- Unit Cost: $9.00 (10% cheaper)

**Calculation:**
```
Quality Score = 85
Delivery Score = 80
Lead Time Score = 100 - (4 × 5) = 80
Price Score = 100 (better than baseline)

Overall = (85 × 0.30) + (80 × 0.30) + (80 × 0.25) + (100 × 0.15)
        = 25.5 + 24.0 + 20.0 + 15.0
        = 84.5
```

**Result:** Vendor A (97.9) is recommended over Vendor B (84.5) despite Vendor B's lower price.

---

## 5. User Interface Components

### 5.1 Vendor Comparison Page (50152)

**Purpose:** Display ranked vendors for selection in a modal dialog.

**Page Properties:**
| Property | Value |
|----------|-------|
| PageType | List |
| SourceTable | Vendor Ranking (Temporary) |
| Caption | Vendor Comparison - Select a Vendor |
| Editable | false |
| UsageCategory | None |

**Layout:**

```
┌─────────────────────────────────────────────────────────────────────────┐
│ Vendor Comparison - Select a Vendor                              [X]   │
├─────────────────────────────────────────────────────────────────────────┤
│ Item Information                                                        │
│ ┌─────────────────────────────────────────────────────────────────────┐ │
│ │ Item No.: WIDGET-100    Required Qty: 100    Required Date: 02/21  │ │
│ └─────────────────────────────────────────────────────────────────────┘ │
├─────────────────────────────────────────────────────────────────────────┤
│ Rank │ Vendor No. │ Name           │ Score │ Perf │ Cost  │ Lead │ Meet│
│──────┼────────────┼────────────────┼───────┼──────┼───────┼──────┼─────│
│  1   │ V10000     │ Acme Supplies  │  97.9 │ 96.5 │$10.00 │  10  │ Yes │
│  2   │ V20000     │ Best Parts Co  │  84.5 │ 82.5 │$ 9.00 │  18  │ No  │
│  3   │ V30000     │ Quick Ship LLC │  78.2 │ 75.0 │$11.50 │   7  │ Yes │
├─────────────────────────────────────────────────────────────────────────┤
│ [Select This Vendor]  [View Vendor Card]  [View Performance]     [OK]  │
└─────────────────────────────────────────────────────────────────────────┘
```

**Column Details:**

| Column | Field | StyleExpr | Description |
|--------|-------|-----------|-------------|
| Rank | Rank No. | - | 1 = highest score |
| Vendor No. | Vendor No. | - | Vendor identifier |
| Name | Vendor Name | - | Cached vendor name |
| Score | Overall Score | ScoreStyle | Color-coded overall score |
| Perf | Performance Score | - | From Vendor table |
| Cost | Unit Cost | - | Vendor's unit cost |
| Total | Total Cost | - | Unit Cost × Quantity |
| Lead | Lead Time Days | - | Lead time in days |
| Expected | Expected Date | - | Today + Lead Time |
| Meet | Can Meet Date | CanMeetStyle | Yes/No indicator |

**Score Style Logic:**
```al
if Rec."Overall Score" >= 80 then
    ScoreStyle := 'Favorable'      // Green
else if Rec."Overall Score" >= 60 then
    ScoreStyle := 'Ambiguous'      // Yellow
else
    ScoreStyle := 'Attention';     // Red
```

**Can Meet Style Logic:**
```al
if Rec."Can Meet Date" then
    CanMeetStyle := 'Favorable'    // Green
else
    CanMeetStyle := 'Unfavorable'; // Red
```

**Actions:**

| Action | Shortcut | Description |
|--------|----------|-------------|
| Select This Vendor | Enter | Set SelectedVendorNo and close page |
| View Vendor Card | - | Open Vendor Card for selected row |
| View Performance | - | Open Vendor Performance Card |

**Selection Mechanism:**
```al
// SelectVendor action
trigger OnAction()
begin
    SelectedVendorNo := Rec."Vendor No.";
    VendorSelected := true;
    CurrPage.Close();
end;

// GetSelectedVendor procedure (called by parent page)
procedure GetSelectedVendor(): Code[20]
begin
    exit(SelectedVendorNo);
end;

// OnQueryClosePage (handles OK button)
trigger OnQueryClosePage(CloseAction: Action): Boolean
begin
    if VendorSelected then
        exit(true);
    if CloseAction = Action::LookupOK then begin
        SelectedVendorNo := Rec."Vendor No.";
        exit(true);
    end;
    exit(true);
end;
```

### 5.2 Requisition Worksheet Page Extension (50150)

**Extends:** Req. Worksheet (standard BC page)

**Added Fields:**

| Field | Source | Visible | StyleExpr |
|-------|--------|---------|-----------|
| Recommended Vendor No. | Rec."Recommended Vendor No." | ShowVendorRecommendations | RecommendedVendorStyle |
| Recommended Vendor Score | Rec."Recommended Vendor Score" | ShowVendorRecommendations | ScoreStyle |
| Alt Vendor Available | Rec."Alt Vendor Available" | ShowVendorRecommendations | - |
| Substitute Available | Rec."Substitute Available" | ShowVendorRecommendations | - |
| Recommended Lead Time | Rec."Recommended Lead Time" | ShowVendorRecommendations | - |

**Added Actions:**

| Action | Caption | Image | Description |
|--------|---------|-------|-------------|
| EnrichSelectedLines | Enrich Selected Lines | Suggest | Populate recommendation fields |
| EnrichAllLines | Enrich All Lines | AllLines | Enrich all lines in worksheet |
| ApplyRecommendedVendor | Apply Recommended Vendor | Apply | Set Vendor No. to recommended |
| ViewVendorComparison | View Vendor Comparison | Vendor | Open comparison page |
| CreatePurchaseSuggestion | Create Purchase Suggestion | Suggest | Create Purchase Suggestion record |
| ToggleRecommendations | Show/Hide Recommendations | ShowSelected | Toggle column visibility |
| PurchaseSuggestions | Purchase Suggestions | OrderList | Navigate to Purchase Suggestion List |
| VendorPerformance | Vendor Performance | Statistics | Navigate to Vendor Performance List |

### 5.3 Planning Worksheet Page Extension (50153)

**Extends:** Planning Worksheet (standard BC page)

**Identical functionality to Requisition Worksheet extension with same:**
- Added fields
- Added actions
- Vendor lookup override
- Enrichment procedures

---

## 6. Vendor No. Lookup Integration

### 6.1 Overview

When users click the lookup button on the Vendor No. field in Requisition Worksheet or Planning Worksheet, the system intercepts the standard BC vendor lookup and displays the Vendor Comparison page instead.

### 6.2 Technical Implementation

**OnLookup Trigger Override:**
```al
modify("Vendor No.")
{
    trigger OnLookup(var Text: Text): Boolean
    var
        SelectedVendor: Code[20];
    begin
        // Only for Item lines
        if Rec.Type <> Rec.Type::Item then
            exit(false);

        // Show vendor comparison and get selection
        SelectedVendor := ShowVendorSelectionLookup();

        // If vendor selected, update the field
        if SelectedVendor <> '' then begin
            Text := SelectedVendor;
            exit(true);  // Handled
        end;

        exit(false);  // Fall back to standard lookup
    end;
}
```

**ShowVendorSelectionLookup Procedure:**
```al
local procedure ShowVendorSelectionLookup(): Code[20]
var
    TempVendorRanking: Record "Vendor Ranking" temporary;
    VendorSelector: Codeunit "Vendor Selector";
    VendorComparisonPage: Page "Vendor Comparison";
    RequiredDate: Date;
    RequiredQty: Decimal;
begin
    // Default required date to 2 weeks if not specified
    if Rec."Due Date" <> 0D then
        RequiredDate := Rec."Due Date"
    else
        RequiredDate := CalcDate('<2W>', Today);

    // Default quantity to 1 if not specified
    if Rec.Quantity > 0 then
        RequiredQty := Rec.Quantity
    else
        RequiredQty := 1;

    // Get ranked vendors for this item
    VendorSelector.GetRankedVendors(
        Rec."No.",           // Item No.
        Rec."Location Code",
        RequiredQty,
        RequiredDate,
        TempVendorRanking
    );

    // If no vendors found, fall back to standard lookup
    if TempVendorRanking.IsEmpty then
        exit('');

    // Show comparison page
    VendorComparisonPage.SetData(TempVendorRanking, Rec."No.", RequiredQty, RequiredDate);

    // Check if user made a selection
    if VendorComparisonPage.RunModal() = Action::LookupOK then
        exit(VendorComparisonPage.GetSelectedVendor());

    exit('');
end;
```

### 6.3 User Experience Flow

```
┌─────────────────────────────────────────────────────────────────────┐
│ 1. User opens Requisition Worksheet or Planning Worksheet           │
└───────────────────────────────┬─────────────────────────────────────┘
                                │
                                ▼
┌─────────────────────────────────────────────────────────────────────┐
│ 2. User creates/selects a line with Type = Item                     │
└───────────────────────────────┬─────────────────────────────────────┘
                                │
                                ▼
┌─────────────────────────────────────────────────────────────────────┐
│ 3. User clicks lookup (dropdown arrow or F4) on Vendor No. field    │
└───────────────────────────────┬─────────────────────────────────────┘
                                │
                                ▼
┌─────────────────────────────────────────────────────────────────────┐
│ 4. System calls VendorSelector.GetRankedVendors()                   │
│    - Retrieves all Item Vendor records for this item                │
│    - Adds Item's default vendor if not already included             │
│    - Scores each vendor using the algorithm                         │
│    - Returns sorted temporary table (highest score first)           │
└───────────────────────────────┬─────────────────────────────────────┘
                                │
                    ┌───────────┴───────────┐
                    │   Vendors Found?      │
                    └───────────┬───────────┘
              No    │           │ Yes
                    ▼           ▼
┌─────────────────────┐   ┌─────────────────────────────────────────┐
│ Standard BC lookup  │   │ Vendor Comparison page opens:           │
│ appears             │   │ - Shows all vendors ranked by score     │
└─────────────────────┘   │ - Color-coded scores                    │
                          │ - Lead times, costs, can-meet indicators│
                          └────────────────────┬────────────────────┘
                                               │
                                               ▼
                          ┌─────────────────────────────────────────┐
                          │ User selects vendor:                    │
                          │ - Click "Select This Vendor" action     │
                          │ - Press Enter on desired row            │
                          │ - Click OK button                       │
                          └────────────────────┬────────────────────┘
                                               │
                                               ▼
                          ┌─────────────────────────────────────────┐
                          │ Vendor No. field is populated with      │
                          │ selected vendor. Standard BC validation │
                          │ runs (pricing, lead time updates).      │
                          └─────────────────────────────────────────┘
```

### 6.4 Fallback Behavior

If no vendors are found for the item, the lookup returns empty (`exit('')`). This causes BC to fall back to the standard vendor lookup behavior, allowing users to:

1. See the standard vendor list
2. Manually enter any vendor number
3. Search for vendors not linked to the item

**When Fallback Occurs:**
- Item has no Item Vendor records
- Item has no default Vendor No.
- All vendor scores are ≤ 0

---

## 7. Business Logic

### 7.1 Vendor Selector Codeunit (50151)

**Primary Procedures:**

#### GetRecommendedVendor
```al
procedure GetRecommendedVendor(
    ItemNo: Code[20];
    LocationCode: Code[10];
    RequiredQty: Decimal;
    RequiredDate: Date
): Code[20]
```
Returns the top-ranked vendor number for an item.

#### GetRankedVendors
```al
procedure GetRankedVendors(
    ItemNo: Code[20];
    LocationCode: Code[10];
    RequiredQty: Decimal;
    RequiredDate: Date;
    var TempVendorRanking: Record "Vendor Ranking" temporary
)
```
Populates a temporary table with all vendors ranked by score.

**Internal Logic:**
```al
procedure GetRankedVendors(...)
var
    ItemVendor: Record "Item Vendor";
    Item: Record Item;
    RankNo: Integer;
begin
    TempVendorRanking.DeleteAll();
    RankNo := 0;

    // Get all vendors from Item Vendor table
    ItemVendor.SetRange("Item No.", ItemNo);
    if ItemVendor.FindSet() then
        repeat
            if TryAddVendorRanking(TempVendorRanking, ItemVendor."Vendor No.",
                ItemNo, LocationCode, RequiredQty, RequiredDate, RankNo) then
                RankNo += 1;
        until ItemVendor.Next() = 0;

    // Also check item's default vendor
    if Item.Get(ItemNo) and (Item."Vendor No." <> '') then begin
        TempVendorRanking.SetRange("Vendor No.", Item."Vendor No.");
        if TempVendorRanking.IsEmpty then
            if TryAddVendorRanking(TempVendorRanking, Item."Vendor No.",
                ItemNo, LocationCode, RequiredQty, RequiredDate, RankNo) then
                RankNo += 1;
        TempVendorRanking.Reset();
    end;

    // Sort by score descending
    TempVendorRanking.SetCurrentKey("Overall Score");
    TempVendorRanking.SetAscending("Overall Score", false);
end;
```

#### ScoreVendorForItem
```al
procedure ScoreVendorForItem(
    VendorNo: Code[20];
    ItemNo: Code[20];
    LocationCode: Code[10];
    RequiredQty: Decimal;
    RequiredDate: Date
): Decimal
```
Calculates the overall weighted score for a specific vendor-item combination.

#### GetVendorScores (Optimized)
```al
procedure GetVendorScores(
    VendorNo: Code[20];
    var QualityScore: Decimal;
    var DeliveryScore: Decimal;
    var PerformanceScore: Decimal
)
```
Single database call to retrieve all vendor scores (optimization).

#### GetVendorLeadTimeDays
```al
procedure GetVendorLeadTimeDays(
    VendorNo: Code[20];
    ItemNo: Code[20];
    LocationCode: Code[10]
): Integer
```
Returns lead time in days with priority: SKU > Item Vendor > Item > Default (7 days).

#### GetRecommendationReason
```al
procedure GetRecommendationReason(
    VendorNo: Code[20];
    ItemNo: Code[20];
    LocationCode: Code[10];
    RequiredQty: Decimal;
    RequiredDate: Date
): Text[500]
```
Generates human-readable explanation for the recommendation.

### 7.2 Line Enrichment Logic

**EnrichRequisitionLines Procedure:**
```al
local procedure EnrichRequisitionLines(var ReqLine: Record "Requisition Line"): Integer
var
    VendorSelector: Codeunit "Vendor Selector";
    TempVendorRanking: Record "Vendor Ranking" temporary;
    ItemSubstitution: Record "Item Substitution";
    EnrichCount: Integer;
begin
    if ReqLine.FindSet() then
        repeat
            if ReqLine.Type = ReqLine.Type::Item then begin
                // Get vendor recommendations
                VendorSelector.GetRankedVendors(
                    ReqLine."No.",
                    ReqLine."Location Code",
                    ReqLine.Quantity,
                    ReqLine."Due Date",
                    TempVendorRanking
                );

                if TempVendorRanking.FindFirst() then begin
                    // Populate recommendation fields
                    ReqLine."Recommended Vendor No." := TempVendorRanking."Vendor No.";
                    ReqLine."Recommended Vendor Name" := TempVendorRanking."Vendor Name";
                    ReqLine."Recommended Vendor Score" := TempVendorRanking."Overall Score";
                    ReqLine."Recommended Unit Cost" := TempVendorRanking."Unit Cost";
                    ReqLine."Recommended Lead Time" := TempVendorRanking."Lead Time Days";
                    ReqLine."Alt Vendor Available" := TempVendorRanking.Count() > 1;

                    // Check for substitutes
                    ItemSubstitution.SetRange(Type, ItemSubstitution.Type::Item);
                    ItemSubstitution.SetRange("No.", ReqLine."No.");
                    if ItemSubstitution.FindFirst() then begin
                        ReqLine."Substitute Available" := true;
                        ReqLine."Substitute Item No." := ItemSubstitution."Substitute No.";
                    end;

                    ReqLine."Recommendation Enriched" := true;
                    ReqLine.Modify();
                    EnrichCount += 1;
                end;
            end;
        until ReqLine.Next() = 0;

    exit(EnrichCount);
end;
```

### 7.3 Apply Recommended Vendor Logic

```al
local procedure ApplyRecommendedVendors(var ReqLine: Record "Requisition Line"): Integer
var
    ApplyCount: Integer;
begin
    if ReqLine.FindSet() then
        repeat
            if (ReqLine."Recommended Vendor No." <> '') and
               (ReqLine."Vendor No." <> ReqLine."Recommended Vendor No.") then begin
                ReqLine.Validate("Vendor No.", ReqLine."Recommended Vendor No.");
                ReqLine.Modify(true);
                ApplyCount += 1;
            end;
        until ReqLine.Next() = 0;

    exit(ApplyCount);
end;
```

---

## 8. Data Flow Diagrams

### 8.1 Vendor Lookup Flow

```
                                    USER
                                      │
                                      │ Clicks Vendor No. lookup
                                      ▼
┌─────────────────────────────────────────────────────────────────────┐
│                   Requisition/Planning Worksheet                     │
│                   Page Extension (50150/50153)                       │
│─────────────────────────────────────────────────────────────────────│
│   OnLookup Trigger                                                   │
│   ├── Check Rec.Type = Item                                         │
│   └── Call ShowVendorSelectionLookup()                              │
└───────────────────────────────────┬─────────────────────────────────┘
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────────────┐
│                   Vendor Selector (Codeunit 50151)                   │
│─────────────────────────────────────────────────────────────────────│
│   GetRankedVendors()                                                 │
│   ├── Query Item Vendor WHERE Item No. = X                          │
│   ├── Query Item.Vendor No. (default vendor)                        │
│   ├── For Each Vendor:                                              │
│   │   ├── GetVendorScores() → Quality, Delivery, Performance        │
│   │   ├── GetLeadTimeScore() → Lead Time Score                      │
│   │   ├── GetPriceScore() → Price Score                             │
│   │   └── Calculate Overall Score                                   │
│   └── Sort by Overall Score DESC                                    │
└───────────────────────────────────┬─────────────────────────────────┘
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────────────┐
│                   Vendor Comparison Page (50152)                     │
│─────────────────────────────────────────────────────────────────────│
│   SetData(TempVendorRanking, ItemNo, Qty, Date)                     │
│   ├── Display ranked vendors                                        │
│   ├── User selects vendor                                           │
│   └── Return SelectedVendorNo                                       │
└───────────────────────────────────┬─────────────────────────────────┘
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────────────┐
│                   Requisition/Planning Worksheet                     │
│─────────────────────────────────────────────────────────────────────│
│   Text := SelectedVendor                                            │
│   exit(true) → Field is updated                                     │
│   ├── BC Validate("Vendor No.") runs                                │
│   └── Pricing, lead time updates applied                            │
└─────────────────────────────────────────────────────────────────────┘
```

### 8.2 Enrichment Flow

```
                                    USER
                                      │
                                      │ Clicks "Enrich Selected Lines"
                                      ▼
┌─────────────────────────────────────────────────────────────────────┐
│                   Requisition Worksheet Page Extension               │
│─────────────────────────────────────────────────────────────────────│
│   EnrichSelectedLines Action                                         │
│   ├── CurrPage.SetSelectionFilter(ReqLine)                          │
│   └── EnrichRequisitionLines(ReqLine)                               │
└───────────────────────────────────┬─────────────────────────────────┘
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────────────┐
│               For Each Selected Line (Type = Item)                   │
│─────────────────────────────────────────────────────────────────────│
│   1. VendorSelector.GetRankedVendors()                              │
│      ├── Returns TempVendorRanking (sorted by score)                │
│      └── TempVendorRanking.FindFirst() → Top vendor                 │
│                                                                      │
│   2. Update ReqLine Fields:                                          │
│      ├── Recommended Vendor No. := Top.Vendor No.                   │
│      ├── Recommended Vendor Name := Top.Vendor Name                 │
│      ├── Recommended Vendor Score := Top.Overall Score              │
│      ├── Recommended Unit Cost := Top.Unit Cost                     │
│      ├── Recommended Lead Time := Top.Lead Time Days                │
│      └── Alt Vendor Available := Count() > 1                        │
│                                                                      │
│   3. Check Item Substitution:                                        │
│      ├── Query Item Substitution WHERE No. = Item No.               │
│      ├── Substitute Available := true/false                         │
│      └── Substitute Item No. := Substitution.Substitute No.         │
│                                                                      │
│   4. ReqLine.Modify()                                                │
└───────────────────────────────────┬─────────────────────────────────┘
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────────────┐
│   Message('%1 lines enriched with vendor recommendations.')         │
│   CurrPage.Update(false)                                            │
└─────────────────────────────────────────────────────────────────────┘
```

---

## 9. Configuration

### 9.1 Prerequisites

Before using the Vendor Suggestion System:

1. **Vendor Performance Data**
   - Vendors must have `Quality Accept Rate %` and `On-Time Delivery %` populated
   - Run Vendor Performance Calculator to calculate metrics from transaction history
   - Or manually enter performance data on Vendor Card

2. **Item Vendor Records**
   - Create Item Vendor records to link items to their suppliers
   - Set Lead Time Calculation on Item Vendor records

3. **Item Setup**
   - Set default Vendor No. on items (optional fallback)
   - Set Lead Time Calculation on items (used if no Item Vendor lead time)
   - Ensure Unit Cost is populated for price scoring

### 9.2 Optional Configuration

**Stockkeeping Unit Lead Times:**
- Create SKUs for location-specific lead times
- SKU lead time takes priority over Item Vendor lead time

**Item Substitutions:**
- Create Item Substitution records to enable substitute suggestions
- System flags when faster substitutes are available

### 9.3 No Manufacturing Setup Required

The Vendor Suggestion System does not require any configuration in Manufacturing Setup. All behavior is automatic based on:
- Existing Item Vendor records
- Existing vendor performance data
- Standard BC lead time hierarchy

---

## 10. Test Scenarios

### Test 1: Vendor No. Lookup Shows Vendor Comparison

**Objective:** Verify the Vendor No. lookup intercepts and shows Vendor Comparison page.

**Prerequisites:**
- Item "TEST-ITEM" exists
- Three vendors (V10000, V20000, V30000) linked via Item Vendor
- Each vendor has Quality Accept Rate % and On-Time Delivery % populated

**Steps:**
1. Open Requisition Worksheet
2. Create new line: Type = Item, No. = TEST-ITEM, Quantity = 100, Due Date = TODAY + 14
3. Click the lookup button on Vendor No. field

**Expected Results:**
- Vendor Comparison page opens (NOT standard vendor list)
- Page title shows "Vendor Comparison - Select a Vendor"
- All 3 vendors are displayed with scores
- Vendors are sorted by Overall Score (highest first)
- Scores are color-coded (Green/Yellow/Red)

**Steps (continued):**
4. Click on second vendor in list
5. Click "Select This Vendor" button

**Expected Results:**
- Page closes
- Vendor No. field contains selected vendor
- BC's standard vendor validation runs

---

### Test 2: Vendor Lookup Fallback

**Objective:** Verify fallback to standard lookup when no vendors exist.

**Prerequisites:**
- Item "NO-VENDOR-ITEM" exists
- Item has NO Item Vendor records
- Item has NO default Vendor No.

**Steps:**
1. Open Requisition Worksheet
2. Create new line: Type = Item, No. = NO-VENDOR-ITEM
3. Click lookup on Vendor No. field

**Expected Results:**
- Vendor Comparison page does NOT appear
- Standard BC vendor lookup appears (or field accepts manual entry)

---

### Test 3: Score Calculation Verification

**Objective:** Verify scores are calculated correctly.

**Prerequisites:**
- Item "SCORE-TEST" exists
- Vendor V10000:
  - Quality Accept Rate = 90%
  - On-Time Delivery = 85%
  - Item Vendor Lead Time = 10 days
  - Item Unit Cost = $100

**Steps:**
1. Open Requisition Worksheet
2. Create line: Type = Item, No. = SCORE-TEST, Qty = 1, Due Date = TODAY + 14
3. Click Vendor No. lookup or run "Compare Vendors" action
4. Note the Overall Score for V10000

**Expected Calculation:**
```
Quality Score = 90
Delivery Score = 85
Lead Time Score = 100 (10 days < 14 days available)
Price Score = 100 (using item's unit cost)

Overall = (90 × 0.30) + (85 × 0.30) + (100 × 0.25) + (100 × 0.15)
        = 27.0 + 25.5 + 25.0 + 15.0
        = 92.5
```

**Expected Result:** Overall Score should be approximately 92.5

---

### Test 4: Enrich Selected Lines

**Objective:** Verify enrichment populates recommendation fields.

**Prerequisites:**
- Item "ENRICH-TEST" with 2 vendors linked
- Vendors have performance data

**Steps:**
1. Open Requisition Worksheet
2. Create 3 lines for ENRICH-TEST with different quantities
3. Select all 3 lines
4. Click "Enrich Selected Lines" action

**Expected Results:**
- Message: "3 lines enriched with vendor recommendations."
- All lines now have:
  - Recommended Vendor No. populated
  - Recommended Vendor Score populated
  - Alt Vendor Available = Yes (since 2 vendors exist)
- Highest-scored vendor is recommended on each line

---

### Test 5: Apply Recommended Vendor

**Objective:** Verify applying recommended vendor updates Vendor No. field.

**Prerequisites:**
- Enriched lines from Test 4

**Steps:**
1. Verify Vendor No. is empty on enriched lines
2. Select all 3 lines
3. Click "Apply Recommended Vendor" action

**Expected Results:**
- Message: "Recommended vendor applied to 3 lines."
- Vendor No. field now equals Recommended Vendor No. on each line
- BC's standard vendor validation has run (pricing updated)

---

### Test 6: Planning Worksheet Integration

**Objective:** Verify Planning Worksheet has same functionality.

**Steps:**
1. Open Planning Worksheet
2. Create line for an item with multiple vendors
3. Click Vendor No. lookup

**Expected Results:**
- Vendor Comparison page appears
- All actions available (Enrich, Apply, Compare)
- Selection updates Vendor No. field

---

### Test 7: Keyboard Selection

**Objective:** Verify Enter key selects vendor.

**Steps:**
1. Open Vendor Comparison page via lookup
2. Arrow down to second vendor
3. Press Enter

**Expected Results:**
- Page closes
- Second vendor is selected
- Vendor No. field is populated

---

### Test 8: Late Vendor Penalty

**Objective:** Verify vendors with late lead times are penalized.

**Prerequisites:**
- Item with 2 vendors:
  - V10000: Lead time 5 days, Quality 80%, Delivery 80%
  - V20000: Lead time 30 days, Quality 95%, Delivery 95%
- Required Date = TODAY + 7

**Steps:**
1. Create Req. Worksheet line with Due Date = TODAY + 7
2. Open Vendor Comparison

**Expected Results:**
- V10000 has Lead Time Score = 100 (can meet date)
- V20000 has Lead Time Score = 100 - ((30-7) × 5) = 100 - 115 = 0
- Despite better quality/delivery, V20000's overall score is lower
- V10000 ranks higher due to ability to meet date

---

## 11. Troubleshooting

### 11.1 Vendor Comparison Page Doesn't Appear

**Symptom:** Clicking Vendor No. lookup shows standard vendor list instead of Vendor Comparison.

**Causes and Solutions:**

| Cause | Solution |
|-------|----------|
| Line Type is not Item | Change Type to Item |
| Item has no vendors linked | Create Item Vendor records |
| Item has no default Vendor No. | Set Vendor No. on Item card |
| Extension not published | Publish extension from VS Code |

### 11.2 All Vendors Show Score of 50

**Symptom:** All vendors display Overall Score around 50.

**Cause:** Vendors don't have performance data populated.

**Solution:**
1. Run Vendor Performance Calculator to calculate metrics from history
2. Or manually set Quality Accept Rate % and On-Time Delivery % on Vendor card

### 11.3 Wrong Vendor Recommended

**Symptom:** System recommends vendor that doesn't seem optimal.

**Investigation:**
1. Open Vendor Comparison to see detailed scores
2. Check each component score:
   - Quality Score = Vendor.Quality Accept Rate %
   - Delivery Score = Vendor.On-Time Delivery %
   - Lead Time Score = Based on lead time vs. required date
   - Price Score = Based on vendor cost vs. item cost

**Common Causes:**
- Lead time data is incorrect → Update Item Vendor lead times
- Price data is incorrect → Update Item unit cost
- Performance data is stale → Recalculate vendor performance

### 11.4 Enrichment Doesn't Update Lines

**Symptom:** "Enrich Selected Lines" runs but lines aren't updated.

**Causes:**
1. Lines have Type ≠ Item
2. No vendors found for item
3. Vendor scores are ≤ 0

**Solution:** Verify Item Vendor records exist and vendors have valid data.

### 11.5 Apply Recommended Vendor Shows 0 Lines Updated

**Symptom:** "Apply Recommended Vendor" reports 0 lines updated.

**Causes:**
1. Recommended Vendor No. is empty (run Enrich first)
2. Vendor No. already equals Recommended Vendor No.

**Solution:** Run "Enrich Selected Lines" before applying.

---

## 12. Object Reference

### 12.1 Complete Object List

| Object Type | ID | Name | Purpose |
|-------------|-----|------|---------|
| **Tables** ||||
| Table | 50150 | Purchase Suggestion | Persistent suggestion records |
| Table | 50151 | Vendor Ranking | Temporary comparison data |
| Table Extension | 50120 | Vendor Performance Ext | Vendor performance fields |
| Table Extension | 50152 | Requisition Line Ext | Recommendation fields |
| **Pages** ||||
| Page | 50150 | Purchase Suggestion List | List of suggestions |
| Page | 50151 | Purchase Suggestion Card | Suggestion details |
| Page | 50152 | Vendor Comparison | Vendor selection UI |
| Page Extension | 50150 | Req Worksheet Vendor Ext | Req. Worksheet integration |
| Page Extension | 50151 | Planning Sugg Card Purch Ext | Planning Suggestion integration |
| Page Extension | 50153 | Planning Worksheet Vendor Ext | Planning Worksheet integration |
| **Codeunits** ||||
| Codeunit | 50150 | Purchase Suggestion Manager | Workflow management |
| Codeunit | 50151 | Vendor Selector | Scoring and ranking |
| **Enums** ||||
| Enum | 50150 | Purchase Suggestion Status | Suggestion workflow states |
| Enum | 50120 | Vendor Score Trend | Improving/Stable/Declining |
| Enum | 50121 | Vendor Risk Level | Low/Medium/High/Critical |

### 12.2 Dependencies

```
Vendor Comparison Page (50152)
├── Uses: Vendor Ranking Table (50151) [Temporary]
├── Uses: Item Table (BC Standard)
└── Uses: Vendor Table (BC Standard)

Req Worksheet Page Ext (50150)
├── Extends: Req. Worksheet (BC Standard)
├── Uses: Requisition Line Table Ext (50152)
├── Uses: Vendor Selector Codeunit (50151)
├── Uses: Vendor Comparison Page (50152)
└── Uses: Item Substitution Table (BC Standard)

Planning Worksheet Page Ext (50153)
├── Extends: Planning Worksheet (BC Standard)
├── Uses: Requisition Line Table Ext (50152)
├── Uses: Vendor Selector Codeunit (50151)
├── Uses: Vendor Comparison Page (50152)
└── Uses: Item Substitution Table (BC Standard)

Vendor Selector Codeunit (50151)
├── Uses: Item Vendor Table (BC Standard)
├── Uses: Item Table (BC Standard)
├── Uses: Vendor Table + Extension (50120)
├── Uses: Stockkeeping Unit Table (BC Standard)
└── Uses: Vendor Ranking Table (50151)
```

---

## Document Control

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0 | Feb 2026 | Riley Bleeker | Initial document |
| 2.0 | Feb 2026 | Riley Bleeker | Added Requisition Worksheet integration |
| 3.0 | Feb 7, 2026 | Riley Bleeker | Added Planning Worksheet integration, comprehensive detail |

---

**End of Document**
