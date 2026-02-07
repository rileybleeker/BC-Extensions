# Purchase Suggestions with Vendor Ranking
## Detailed Functional Specification

**Document Version:** 2.0
**Last Updated:** February 2026
**Extension Version:** 1.0.0.10

---

## 1. Executive Summary

The Purchase Suggestions with Vendor Ranking module provides intelligent vendor recommendations for purchasing decisions. It automatically analyzes multiple vendors for each item, scores them across four weighted dimensions (quality, delivery, lead time, and price), and generates actionable purchase suggestions with side-by-side vendor comparisons.

**NEW in Version 2.0:** The Vendor No. lookup field in the Requisition Worksheet and Planning Worksheet now displays the Vendor Comparison page instead of the standard vendor list. This enables users to see ranked vendors with scores, lead times, and costs directly when selecting a vendor.

---

## 2. Tables and Fields

### 2.1 Purchase Suggestion Table (50150)

The main record storing purchase recommendations.

| Field ID | Field Name | Type | Description |
|----------|------------|------|-------------|
| 1 | Entry No. | Integer | Auto-incremented primary key |
| 2 | Item No. | Code[20] | Item being purchased |
| 3 | Item Description | Text[100] | Cached item description |
| 4 | Variant Code | Code[10] | Item variant (optional) |
| 5 | Location Code | Code[10] | Target location |
| 6 | Suggestion Date | Date | Date suggestion was created |
| 10 | Suggested Qty | Decimal | Quantity to purchase |
| 11 | Unit of Measure | Code[10] | Unit of measure |
| 12 | Required Date | Date | When the items are needed |
| **Vendor 1 Fields** |||
| 20 | Vendor 1 No. | Code[20] | Highest-ranked vendor |
| 21 | Vendor 1 Name | Text[100] | Vendor name |
| 22 | Vendor 1 Unit Cost | Decimal | Unit cost |
| 23 | Vendor 1 Lead Time | Integer | Lead time in days |
| 24 | Vendor 1 Score | Decimal | Overall score (0-100) |
| 25 | Vendor 1 Expected Date | Date | Expected delivery date |
| **Vendor 2 Fields** |||
| 30-35 | Vendor 2 * | Various | Second-ranked vendor |
| **Vendor 3 Fields** |||
| 40-45 | Vendor 3 * | Various | Third-ranked vendor |
| **Recommendation** |||
| 50 | Recommended Vendor No. | Code[20] | System-recommended vendor |
| 51 | Recommended Vendor Name | Text[100] | Vendor name |
| 52 | Recommendation Reason | Text[500] | Why this vendor is recommended |
| 53 | Alternative Available | Boolean | True if other vendors exist |
| **Substitution** |||
| 60 | Substitute Item Available | Boolean | Substitute with shorter lead time |
| 61 | Substitute Item No. | Code[20] | Substitute item number |
| 62 | Substitute Lead Time Savings | Integer | Days saved with substitute |
| **Status & Workflow** |||
| 70 | Status | Enum | New/Under Review/Approved/PO Created/Rejected/Cancelled |
| 71 | Selected Vendor No. | Code[20] | User's vendor selection |
| 72 | Selected Vendor Name | Text[100] | Selected vendor name |
| 73 | Purchase Order No. | Code[20] | Created PO number |
| 74 | Rejection Reason | Text[250] | Why suggestion was rejected |
| **Audit** |||
| 80 | Created By | Code[50] | User who created |
| 81 | Created DateTime | DateTime | Creation timestamp |
| 82 | Approved By | Code[50] | User who approved |
| 83 | Approved DateTime | DateTime | Approval timestamp |

---

### 2.2 Vendor Ranking Table (50151)

Temporary table used for vendor comparison calculations.

| Field ID | Field Name | Type | Description |
|----------|------------|------|-------------|
| 1 | Rank No. | Integer | Position in ranking (1 = best) |
| 2 | Vendor No. | Code[20] | Vendor number |
| 3 | Item No. | Code[20] | Item being ranked |
| 10 | Overall Score | Decimal | Weighted total score |
| 11 | Performance Score | Decimal | From Vendor table |
| 12 | Lead Time Score | Decimal | Calculated lead time score |
| 13 | Price Score | Decimal | Calculated price score |
| 20 | Unit Cost | Decimal | Vendor's unit cost |
| 21 | Lead Time Days | Integer | Lead time in days |
| 22 | Expected Date | Date | Calculated delivery date |
| 23 | Can Meet Date | Boolean | True if expected <= required |
| 24 | Vendor Name | Text[100] | Cached vendor name |

---

### 2.3 Vendor Table Extension (50120)

Fields added to standard Vendor table for performance tracking.

| Field ID | Field Name | Type | Description |
|----------|------------|------|-------------|
| 50120 | Performance Score | Decimal | Overall performance (0-100) |
| 50121 | Performance Risk Level | Enum | Low/Medium/High/Critical |
| 50122 | On-Time Delivery % | Decimal | Percentage on-time deliveries |
| 50123 | Quality Accept Rate % | Decimal | Percentage accepted quality |
| 50124 | Lead Time Variance Days | Decimal | Avg deviation from promised |
| 50125 | Score Trend | Enum | Improving/Stable/Declining |
| 50126 | Last Performance Calc | DateTime | Last calculation timestamp |

---

### 2.4 Purchase Suggestion Status Enum (50150)

| Value | Name | Description |
|-------|------|-------------|
| 0 | New | Newly created suggestion |
| 1 | Under Review | Being reviewed by purchasing |
| 2 | Approved | Approved, ready for PO creation |
| 3 | PO Created | Purchase order has been created |
| 4 | Rejected | Suggestion was rejected |
| 5 | Cancelled | Suggestion was cancelled |

---

## 3. Scoring Formulas

### 3.1 Overall Score Calculation

The overall vendor score is a weighted average of four components:

```
Overall Score = (Quality Score × 0.30) + (Delivery Score × 0.30) +
                (Lead Time Score × 0.25) + (Price Score × 0.15)
```

**Weighting Rationale:**
| Factor | Weight | Justification |
|--------|--------|---------------|
| Quality (Accept Rate) | 30% | Quality issues cause production delays, rework, returns |
| Delivery (On-Time %) | 30% | Late deliveries disrupt production schedules |
| Lead Time | 25% | Important for meeting required dates |
| Price | 15% | Cost matters but less than reliability |

---

### 3.2 Lead Time Score

```
IF LeadTimeDays <= DaysUntilRequired THEN
    Score := 100
ELSE
    Score := 100 - ((LeadTimeDays - DaysUntilRequired) × 5)
    IF Score < 0 THEN Score := 0
```

**Example:**
- Required Date: 14 days from today
- Vendor A Lead Time: 10 days → Score = 100 (can meet date)
- Vendor B Lead Time: 18 days → Score = 100 - (4 × 5) = 80
- Vendor C Lead Time: 35 days → Score = 100 - (21 × 5) = 0 (capped)

---

### 3.3 Price Score

```
VendorCost := Item."Last Direct Cost" OR Item."Unit Cost"
BestCost := MIN(VendorCost, Item."Unit Cost")

IF VendorCost = 0 OR BestCost = 0 THEN
    Score := 50  // Neutral - no data
ELSE IF VendorCost <= BestCost THEN
    Score := 100
ELSE
    Score := 100 - ((VendorCost - BestCost) / BestCost × 100)
    IF Score < 0 THEN Score := 0
```

**Example:**
- Item Unit Cost (baseline): $10.00
- Vendor A Cost: $10.00 → Score = 100
- Vendor B Cost: $11.00 → Score = 100 - (10% premium) = 90
- Vendor C Cost: $12.50 → Score = 100 - (25% premium) = 75

---

### 3.4 Quality Score

```
IF Vendor."Quality Accept Rate %" > 0 THEN
    Score := Vendor."Quality Accept Rate %"
ELSE
    Score := 50  // Neutral - no data
```

Pulled directly from the Vendor record's Quality Accept Rate %.

---

### 3.5 Delivery Score

```
IF Vendor."On-Time Delivery %" > 0 THEN
    Score := Vendor."On-Time Delivery %"
ELSE
    Score := 50  // Neutral - no data
```

Pulled directly from the Vendor record's On-Time Delivery %.

---

### 3.6 Lead Time Determination Priority

Lead time is sourced in this priority order:

1. **Stockkeeping Unit (SKU)** - `SKU."Lead Time Calculation"` for Location + Item
2. **Item Vendor** - `Item Vendor."Lead Time Calculation"` for Vendor + Item
3. **Item** - `Item."Lead Time Calculation"`
4. **Default** - 7 days if no data found

---

### 3.7 Expected Delivery Date

```
Expected Date := TODAY + Lead Time Days
Can Meet Date := (Expected Date <= Required Date)
```

---

## 4. Workflow Process

### 4.1 Suggestion Generation

1. User triggers suggestion from Planning Suggestion Card or Requisition Worksheet
2. System calls `VendorSelector.GetRankedVendors()`
3. Vendors sourced from:
   - Item Vendor records for the item
   - Item's default Vendor No.
4. Each vendor is scored using the weighted formula
5. Top 3 vendors populate the Purchase Suggestion record
6. Highest-scoring vendor is pre-selected as recommended
7. System checks for substitute items with shorter lead times
8. Suggestion is saved with Status = New

### 4.2 Review and Approval

1. Purchasing reviews suggestion on Purchase Suggestion Card
2. Can compare vendors using "Compare Vendors" action
3. Can change selected vendor from recommendation
4. Approve: Status → Approved, captures Approved By/DateTime
5. Reject: Status → Rejected, requires Rejection Reason

### 4.3 Purchase Order Creation

1. User clicks "Create Purchase Order" on approved suggestion
2. Option to consolidate with existing open PO for same vendor
3. System creates:
   - New Purchase Header (or uses existing if consolidating)
   - Purchase Line with Item, Quantity, Location, Expected Receipt Date
4. Status → PO Created
5. Purchase Order No. is captured on suggestion

---

## 5. Vendor No. Lookup Integration

### 5.1 Overview

When users click the lookup button (dropdown arrow or F4) on the **Vendor No.** field in the Requisition Worksheet or Planning Worksheet, the system displays the **Vendor Comparison** page instead of the standard vendor list.

### 5.2 Pages Extended

| Page ID | Page Name | Extension ID |
|---------|-----------|--------------|
| "Req. Worksheet" | Requisition Worksheet | 50150 |
| "Planning Worksheet" | Planning Worksheet | 50151 |

### 5.3 User Experience Flow

1. User opens Requisition Worksheet or Planning Worksheet
2. User creates or selects a line for an Item
3. User clicks the lookup (dropdown) on **Vendor No.** field
4. **Vendor Comparison** page opens showing:
   - All vendors ranked by overall score
   - Columns: Rank, Vendor No., Name, Overall Score, Performance Score, Unit Cost, Total Cost, Lead Time Days, Expected Date, Can Meet Date
   - Color coding: Green (>=80 score), Yellow (60-79), Red (<60)
5. User selects a vendor by:
   - Clicking **Select This Vendor** action, OR
   - Pressing Enter on the desired row, OR
   - Clicking OK button
6. Selected vendor populates the **Vendor No.** field
7. If user cancels, the field remains unchanged

### 5.4 Fallback Behavior

If **no vendors** are found for the item (no Item Vendor records and no default vendor), the lookup returns empty and the standard BC vendor lookup may be used as fallback.

### 5.5 Technical Implementation

```al
modify("Vendor No.")
{
    trigger OnLookup(var Text: Text): Boolean
    var
        SelectedVendor: Code[20];
    begin
        if Rec.Type <> Rec.Type::Item then
            exit(false);  // Only applies to Item lines

        SelectedVendor := ShowVendorSelectionLookup();
        if SelectedVendor <> '' then begin
            Text := SelectedVendor;
            exit(true);  // Field will be set to selected vendor
        end;
        exit(false);  // Allow standard lookup as fallback
    end;
}
```

### 5.6 Additional Worksheet Features

Both worksheets also include:

| Action | Description |
|--------|-------------|
| Enrich Selected Lines | Populate recommendation fields for selected lines |
| Apply Recommended Vendor | Set Vendor No. to recommended vendor for selected lines |
| Compare Vendors | Open Vendor Comparison page for current line |
| Show/Hide Recommendations | Toggle visibility of recommendation columns |

### 5.7 Added Columns on Worksheet

| Field | Description |
|-------|-------------|
| Recommended Vendor No. | System's top-ranked vendor |
| Recommended Vendor Score | Score of recommended vendor |
| Alt Vendor Available | Yes if multiple vendors exist |
| Substitute Available | Yes if substitute item has faster delivery |
| Recommended Lead Time | Lead time in days for recommended vendor |

---

## 6. Test Scenarios

### Test 1: Vendor No. Lookup in Requisition Worksheet

**Objective:** Verify the Vendor No. lookup shows the Vendor Comparison page.

**Prerequisites:**
- Item "ITEM-LOOKUP" exists with Item Vendor records for 3 vendors
- Vendors have performance data (Quality %, Delivery %)

**Steps:**
1. Open Requisition Worksheet
2. Create a new line: Type = Item, No. = ITEM-LOOKUP, Quantity = 100, Due Date = TODAY + 14
3. Click the lookup button (dropdown arrow or F4) on the **Vendor No.** field

**Expected Result:**
- Vendor Comparison page opens (NOT standard vendor list)
- Page title shows "Vendor Comparison - Select a Vendor"
- All 3 vendors are displayed with scores
- Vendors are ranked by Overall Score (highest first)

**Steps (continued):**
4. Click on Vendor #2 in the list
5. Click **Select This Vendor** button

**Expected Result:**
- Page closes
- **Vendor No.** field is populated with selected vendor
- Standard vendor validation runs (no errors)

---

### Test 2: Vendor No. Lookup with No Vendors

**Objective:** Verify graceful handling when no vendors exist for an item.

**Prerequisites:**
- Item "ITEM-NOVENDOR" exists with NO Item Vendor records
- Item has no default Vendor No.

**Steps:**
1. Open Requisition Worksheet
2. Create line for ITEM-NOVENDOR
3. Click lookup on **Vendor No.** field

**Expected Result:**
- No Vendor Comparison page appears (returns empty)
- Standard BC behavior occurs (may show standard vendor list or allow manual entry)

---

### Test 3: Basic Vendor Ranking

**Objective:** Verify vendors are ranked correctly by overall score.

**Prerequisites:**
- Item "ITEM-TEST" exists
- Three vendors set up in Item Vendor for this item:
  - V10000: Quality 95%, On-Time 90%
  - V20000: Quality 80%, On-Time 85%
  - V30000: Quality 99%, On-Time 98%
- All vendors have same lead time (7 days) and cost ($10.00)

**Steps:**
1. Open Planning Parameter Suggestions
2. Generate a suggestion for ITEM-TEST
3. Click "Generate Purchase Suggestion"

**Expected Result:**
- V30000 ranked #1 (highest quality + delivery)
- V10000 ranked #2
- V20000 ranked #3

**Verification:**
```
V30000 Score = (99 × 0.30) + (98 × 0.30) + (100 × 0.25) + (100 × 0.15) = 29.7 + 29.4 + 25 + 15 = 99.1
V10000 Score = (95 × 0.30) + (90 × 0.30) + (100 × 0.25) + (100 × 0.15) = 28.5 + 27 + 25 + 15 = 95.5
V20000 Score = (80 × 0.30) + (85 × 0.30) + (100 × 0.25) + (100 × 0.15) = 24 + 25.5 + 25 + 15 = 89.5
```

---

### Test 2: Lead Time Impact on Scoring

**Objective:** Verify lead time score penalizes vendors who cannot meet required date.

**Prerequisites:**
- Item "ITEM-URGENT" with required date = TODAY + 10 days
- V10000: Lead Time = 7 days (can meet)
- V20000: Lead Time = 14 days (4 days late)
- V30000: Lead Time = 30 days (20 days late)
- All have same Quality (90%) and Delivery (90%)

**Steps:**
1. Generate purchase suggestion for ITEM-URGENT with Required Date = TODAY + 10 days

**Expected Result:**
```
V10000 Lead Time Score = 100 (7 <= 10)
V20000 Lead Time Score = 100 - (4 × 5) = 80
V30000 Lead Time Score = 100 - (20 × 5) = 0

V10000 Overall = (90 × 0.30) + (90 × 0.30) + (100 × 0.25) + (50 × 0.15) = 86.5
V20000 Overall = (90 × 0.30) + (90 × 0.30) + (80 × 0.25) + (50 × 0.15) = 81.5
V30000 Overall = (90 × 0.30) + (90 × 0.30) + (0 × 0.25) + (50 × 0.15) = 61.5
```

Ranking: V10000 > V20000 > V30000

---

### Test 3: Price Impact on Scoring

**Objective:** Verify price score penalizes higher-cost vendors.

**Prerequisites:**
- Item "ITEM-COST" with Unit Cost = $100.00
- V10000: Last Direct Cost = $100.00 (matches baseline)
- V20000: Last Direct Cost = $120.00 (20% premium)
- V30000: Last Direct Cost = $150.00 (50% premium)
- All have same Quality (90%), Delivery (90%), Lead Time (7 days meeting date)

**Steps:**
1. Generate purchase suggestion for ITEM-COST

**Expected Result:**
```
V10000 Price Score = 100
V20000 Price Score = 100 - 20 = 80
V30000 Price Score = 100 - 50 = 50

V10000 Overall = (90 × 0.30) + (90 × 0.30) + (100 × 0.25) + (100 × 0.15) = 94.0
V20000 Overall = (90 × 0.30) + (90 × 0.30) + (100 × 0.25) + (80 × 0.15) = 91.0
V30000 Overall = (90 × 0.30) + (90 × 0.30) + (100 × 0.25) + (50 × 0.15) = 86.5
```

---

### Test 4: Approval Workflow

**Objective:** Verify the approval workflow enforces business rules.

**Steps:**
1. Generate a new purchase suggestion
2. Verify Status = "New"
3. Try to create PO without approving → **Expected:** Error "Suggestion must be approved"
4. Clear Selected Vendor and try to Approve → **Expected:** Error "Please select a vendor"
5. Select a vendor and click Approve
6. Verify Status = "Approved", Approved By = current user, Approved DateTime = now
7. Click "Create Purchase Order"
8. Verify Status = "PO Created", Purchase Order No. is populated

---

### Test 5: Vendor Comparison Page

**Objective:** Verify the comparison page displays all vendor data correctly.

**Steps:**
1. Generate purchase suggestion with 3 vendors
2. Click "Compare Vendors"
3. Verify:
   - All 3 vendors are displayed
   - Rank column shows 1, 2, 3 in score order
   - Overall Score, Unit Cost, Lead Time Days, Expected Date are shown
   - "Can Meet Date" shows Yes/No correctly
   - Score style: >= 80 green, 60-79 yellow, < 60 red
4. Click "Select This Vendor" on vendor #2
5. Verify selected vendor changes to #2

---

### Test 6: PO Consolidation

**Objective:** Verify suggestions can consolidate into existing open POs.

**Prerequisites:**
- Open Purchase Order P-1000 exists for Vendor V10000

**Steps:**
1. Create and approve two suggestions for V10000
2. On first suggestion, create PO with Consolidate = false
3. Verify new PO is created (e.g., P-1001)
4. On second suggestion, create PO with Consolidate = true
5. Verify line is added to P-1001 (not a new PO)

---

### Test 7: Substitute Item Detection

**Objective:** Verify the system identifies substitute items with shorter lead times.

**Prerequisites:**
- Item "ITEM-MAIN" with recommended vendor lead time = 21 days
- Item Substitution record: ITEM-MAIN → ITEM-SUB
- Item "ITEM-SUB" with recommended vendor lead time = 7 days

**Steps:**
1. Generate purchase suggestion for ITEM-MAIN

**Expected Result:**
- Substitute Item Available = Yes
- Substitute Item No. = ITEM-SUB
- Substitute Lead Time Savings = 14 days

---

### Test 8: No Vendor Data Handling

**Objective:** Verify system handles vendors with no performance data.

**Prerequisites:**
- New vendor V99999 with no performance history
- Set as Item Vendor for ITEM-NEW

**Steps:**
1. Generate purchase suggestion for ITEM-NEW

**Expected Result:**
- V99999 appears with neutral scores:
  - Quality Score = 50 (no data)
  - Delivery Score = 50 (no data)
  - Price Score = 50 (if no cost data)
  - Lead Time = 7 days (default)

---

### Test 9: Rejection Workflow

**Objective:** Verify rejection captures reason and prevents further actions.

**Steps:**
1. Generate and leave suggestion in "New" status
2. Click Reject → Enter reason "Vendor on hold"
3. Verify:
   - Status = "Rejected"
   - Rejection Reason = "Vendor on hold"
4. Try to Approve → **Expected:** Error (already rejected)
5. Try to Create PO → **Expected:** Error

---

### Test 10: Integration with Requisition Worksheet

**Objective:** Verify suggestions can be generated from requisition lines.

**Steps:**
1. Open Requisition Worksheet
2. Create a line for Item ITEM-TEST, Qty 100, Due Date = TODAY + 14
3. Click "Generate Vendor Suggestion"
4. Verify:
   - Purchase Suggestion created
   - Requisition Worksheet Template/Batch/Line No. are captured
   - Item, Qty, Required Date match requisition line

---

## 6. Related Tables (Data Sources)

| Table | Purpose in Vendor Ranking |
|-------|---------------------------|
| Vendor | Performance Score, Quality %, Delivery % |
| Item | Default vendor, Unit Cost, Lead Time Calculation |
| Item Vendor | Vendor-specific lead time per item |
| Stockkeeping Unit | Location-specific lead time |
| Item Substitution | Substitute items for lead time comparison |
| Requisition Line | Source for batch suggestion generation |
| Purchase Header | Created PO header |
| Purchase Line | Created PO line |

---

## 7. Codeunits

| ID | Name | Purpose |
|----|------|---------|
| 50150 | Purchase Suggestion Manager | Workflow: generate, approve, reject, create PO |
| 50151 | Vendor Selector | Scoring calculations, vendor ranking |

---

## 8. Pages

| ID | Name | Type | Purpose |
|----|------|------|---------|
| 50150 | Purchase Suggestion List | List | Overview of all suggestions |
| 50151 | Purchase Suggestion Card | Card | Detail view, actions |
| 50152 | Vendor Comparison | List | Side-by-side vendor comparison |

---

## 9. Troubleshooting

### Issue: No vendors appear in suggestion

**Causes:**
- No Item Vendor records exist for the item
- Item has no default Vendor No.

**Resolution:**
- Add Item Vendor records or set Item."Vendor No."

### Issue: All vendors have score of 50

**Cause:** No performance data (Quality %, Delivery %) on vendor records

**Resolution:**
- Run Vendor Performance Calculator to populate metrics
- Or manually enter Quality Accept Rate % and On-Time Delivery %

### Issue: Lead time shows 7 days for all vendors

**Cause:** No lead time data in SKU, Item Vendor, or Item

**Resolution:**
- Set Lead Time Calculation on Item Vendor or Item record

---

## 10. Configuration Checklist

Before using Purchase Suggestions:

- [ ] Item Vendor records created for items with multiple vendors
- [ ] Lead Time Calculation set on Item Vendor or Item records
- [ ] Vendor Performance Calculator has run to populate vendor metrics
- [ ] Item costs are populated (Last Direct Cost or Unit Cost)
- [ ] Item Substitutions configured (optional, for substitute detection)

---

*End of Document*
