# SKU-Level Planning Parameter Suggestions - Design Addendum

This document describes the enhancements to support Item/Location-level (Stockkeeping Unit) planning parameters.

---

## Overview: How SKUs Work in Business Central

### Planning Parameter Hierarchy

```
┌─────────────────────────────────────────────────────────────┐
│                     Planning System                          │
├─────────────────────────────────────────────────────────────┤
│  When calculating requirements for Item X at Location Y:     │
│                                                              │
│  1. Check: Does SKU exist for (Item X, Location Y)?          │
│     └── YES → Use SKU planning parameters                    │
│     └── NO  → Use Item planning parameters (fallback)        │
│                                                              │
│  This allows different safety stock, reorder points, etc.    │
│  for the same item at different warehouses.                  │
└─────────────────────────────────────────────────────────────┘
```

### Why SKU-Level Planning?

| Scenario | Item-Level Only | With SKUs |
|----------|----------------|-----------|
| Main warehouse vs satellite | Same parameters everywhere | Optimized per location |
| Fast-moving vs slow-moving locations | Over/under stock at some | Right-sized everywhere |
| Different suppliers per region | One lead time fits all | Location-specific lead times |
| Seasonal regional demand | Miss regional patterns | Capture local seasonality |

---

## Schema Changes

### Table 50110: Planning Parameter Suggestion (Updated)

New fields added:

| Field No. | Field Name | Type | Description |
|-----------|------------|------|-------------|
| 13 | Target Level | Option | `Item` or `SKU` - where to apply suggestion |
| 14 | SKU Exists | Boolean | Whether SKU already exists |
| 15 | Create SKU If Missing | Boolean | Auto-create SKU when applying (default: true) |

New indexes added:

| Index Fields | Purpose |
|--------------|---------|
| (Item No., Location Code, Variant Code, Suggestion Date) | SKU-level lookups |
| (Target Level, Status) | Filter by Item vs SKU suggestions |

### Business Logic Changes

#### Target Level Determination

```
IF Location Code is specified THEN
    Target Level := SKU
    Current values loaded from SKU (if exists) or Item (as baseline)
ELSE
    Target Level := Item
    Current values loaded from Item
END
```

#### Lead Time Resolution

```
IF Target Level = SKU AND SKU exists THEN
    Use SKU."Lead Time Calculation"
    IF blank THEN fallback to Item."Lead Time Calculation"
ELSE
    Use Item."Lead Time Calculation"
END

IF still blank THEN
    Use Setup."Lead Time Days Default"
END
```

---

## New Codeunit: Planning SKU Management (50114)

### Purpose
Manages Stockkeeping Unit operations for the planning suggestion system.

### Key Procedures

#### EnsureSKUExists
```
procedure EnsureSKUExists(ItemNo, LocationCode, VariantCode): Boolean
```
- Checks if SKU exists
- Creates new SKU if missing
- Copies planning parameters from Item as baseline
- Returns true on success

#### ApplySuggestionToSKU
```
procedure ApplySuggestionToSKU(Suggestion, ApplyFlags...): Boolean
```
- Creates SKU if `Create SKU If Missing` is enabled
- Applies selected parameters to SKU
- Transaction-protected with rollback on failure

#### GetLocationsWithDemand
```
procedure GetLocationsWithDemand(ItemNo, StartDate, EndDate, var TempLocation)
```
- Scans Item Ledger Entries for unique locations
- Returns locations that have had demand (sales, consumption, etc.)
- Used for batch SKU creation/suggestion generation

#### BatchCreateSKUsForItem
```
procedure BatchCreateSKUsForItem(ItemNo)
```
- Creates SKUs for all locations with historical demand
- Useful for setting up location-specific planning

---

## Updated User Interface

### Planning Parameter Suggestions Page

New columns:
- **Target Level**: Shows "Item" or "Stockkeeping Unit"
- **SKU Exists**: Indicates if SKU already exists (for SKU-level suggestions)

New actions:
- **View Stockkeeping Unit**: Opens SKU card (enabled for SKU-level suggestions)
- **Generate for All Locations**: Creates SKU-level suggestions for all locations with demand

### Item Card (Extended)

New actions:
- **Generate Item-Level Suggestion**: Creates suggestion for Item (location-agnostic)
- **Generate SKU Suggestions (All Locations)**: Creates suggestions for each location with demand
- **Create SKUs for All Locations**: Batch creates SKUs based on demand history
- **Stockkeeping Units**: Quick access to SKU list for item

---

## Workflow Examples

### Example 1: New Item with Multi-Location Demand

1. Item "WIDGET-100" is sold at locations MAIN, EAST, WEST
2. User opens Item Card → "Generate SKU Suggestions (All Locations)"
3. System:
   - Finds all locations with demand history
   - Generates 3 SKU-level suggestions (one per location)
   - Each analyzed with location-specific demand data
4. User reviews each suggestion in Planning Parameter Suggestions page
5. For MAIN warehouse (high volume): Approves higher safety stock
6. For EAST/WEST (lower volume): Approves lower safety stock
7. User clicks "Apply Suggestion" → System creates/updates SKUs

### Example 2: Existing Item, Add New Location

1. New warehouse SOUTH opens, starts selling existing items
2. After 3 months of demand history:
3. User selects item → "Generate SKU Suggestions (All Locations)"
4. System creates suggestion for SOUTH location
5. Since no SKU exists, `SKU Exists = false`, `Create SKU If Missing = true`
6. User approves → System creates SKU with optimized parameters

### Example 3: Company-Wide Batch Processing

1. Administrator runs batch job for all items with `Planning Suggestion Enabled = true`
2. For each item:
   - If Location Code filter is blank → Item-level suggestion
   - If Location Code filter is set → SKU-level suggestion
3. Or use "Generate for All Locations" to create per-location suggestions

---

## Data Collection Behavior

### Item-Level (Location Code = blank)

```sql
-- Collects demand from ALL locations
SELECT Posting Date, SUM(ABS(Quantity))
FROM Item Ledger Entry
WHERE Item No. = 'WIDGET-100'
  AND Entry Type IN ('Sale', 'Consumption', 'Negative Adjmt.')
  AND Posting Date BETWEEN @StartDate AND @EndDate
GROUP BY Posting Date
```

### SKU-Level (Location Code = 'MAIN')

```sql
-- Collects demand from SPECIFIC location only
SELECT Posting Date, SUM(ABS(Quantity))
FROM Item Ledger Entry
WHERE Item No. = 'WIDGET-100'
  AND Location Code = 'MAIN'  -- Location filter applied
  AND Entry Type IN ('Sale', 'Consumption', 'Negative Adjmt.')
  AND Posting Date BETWEEN @StartDate AND @EndDate
GROUP BY Posting Date
```

This means SKU-level suggestions are based on location-specific demand patterns, which may differ significantly from the aggregate.

---

## Prophet ML Considerations

### Request Differences

Item-level request (aggregated demand):
```json
{
  "itemNo": "WIDGET-100",
  "locationCode": null,
  "dataPoints": [...]  // All locations combined
}
```

SKU-level request (location-specific demand):
```json
{
  "itemNo": "WIDGET-100",
  "locationCode": "MAIN",
  "dataPoints": [...]  // Only MAIN warehouse
}
```

### Impact on Forecasts

| Metric | Item-Level | SKU-Level |
|--------|-----------|-----------|
| Data points | More (aggregated) | Fewer (single location) |
| Patterns detected | Overall company trends | Location-specific patterns |
| Seasonality | Company-wide peaks | Regional peaks |
| Confidence | Often higher (more data) | May be lower (less data) |

---

## Permission Sets

### Updated Permissions

The existing permission sets now include:

**Planning Suggest View (50110)**:
- Read access to Stockkeeping Unit table (for viewing)

**Planning Suggest Admin (50111)**:
- Full access to Stockkeeping Unit table (for creating/modifying)

---

## Test Scenarios (Additions)

### SKU-Specific Tests

| Test ID | Scenario | Expected Result |
|---------|----------|-----------------|
| SKU-001 | Generate SKU suggestion, SKU doesn't exist | `SKU Exists = false`, suggestion created |
| SKU-002 | Apply suggestion when `Create SKU If Missing = true` | SKU created, parameters applied |
| SKU-003 | Apply suggestion when `Create SKU If Missing = false`, no SKU | Error: "SKU does not exist" |
| SKU-004 | Generate for all locations | One suggestion per location with demand |
| SKU-005 | SKU has different lead time than Item | Suggestion uses SKU lead time |
| SKU-006 | Location with no demand history | Skipped (minimum data points not met) |
| SKU-007 | Apply to SKU, then generate new Item-level | Both coexist, Item-level unaffected |

---

## Migration Considerations

### For Existing Implementations

1. **No breaking changes**: Existing Item-level suggestions continue to work
2. **Default behavior**: If `Location Code` is blank, operates as before
3. **Gradual adoption**: Users can start using SKU features when ready

### Recommended Rollout

1. **Phase 1**: Continue Item-level suggestions
2. **Phase 2**: Identify high-volume/multi-location items
3. **Phase 3**: Generate SKU-level suggestions for key items
4. **Phase 4**: Enable batch SKU suggestion generation
