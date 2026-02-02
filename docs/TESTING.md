# Testing Guide

Comprehensive testing procedures for ALProject10 features.

---

## Test Environment Setup

### Prerequisites
- Business Central test environment (separate from production)
- Azure Logic Apps (development subscription recommended)
- Test Google Sheets spreadsheet
- Test data: Items with various inventory levels

### Test Data Preparation

Create the following test items:

| Item No. | Description | Safety Stock | Initial Inventory | Location |
|----------|-------------|--------------|-------------------|----------|
| TEST-001 | Above Threshold Item | 100 | 150 | MAIN |
| TEST-002 | At Threshold Item | 100 | 100 | MAIN |
| TEST-003 | Below Threshold Item | 100 | 50 | MAIN |
| TEST-004 | No Safety Stock | 0 | 200 | MAIN |
| TEST-005 | Multi-Location Item | 100 (MAIN)<br>50 (EAST) | 120 (MAIN)<br>60 (EAST) | MAIN, EAST |

---

## Part 1: Quality Management Testing

### Test Case 1.1: Lot Validation - Tracking Specification

**Objective**: Verify users cannot enter Pending/Failed lots in Item Tracking Lines

**Prerequisites**:
- Item with lot tracking enabled
- Quality Order with Test Status = Pending
- Lot No. = LOT-FAIL-001

**Steps**:
1. Create Sales Order
2. Add line with lot-tracked item
3. Click **Item Tracking Lines**
4. Enter Lot No. = LOT-FAIL-001
5. Tab out of field or press Enter

**Expected Result**:
- Error message: "Cannot select Lot No. LOT-FAIL-001 for Item [ItemNo]. Status: Pending. Only lots with Passed status can be used."
- Lot number is cleared
- Cannot proceed with this lot

**Actual Result**: _____________

**Status**: ☐ Pass ☐ Fail

**Notes**: _____________

---

### Test Case 1.2: Lot Validation - Passed Status

**Objective**: Verify users CAN enter Passed lots

**Prerequisites**:
- Same item as Test 1.1
- Quality Order with Test Status = Passed
- Lot No. = LOT-PASS-001

**Steps**:
1. Create Sales Order
2. Add line with lot-tracked item
3. Click **Item Tracking Lines**
4. Enter Lot No. = LOT-PASS-001
5. Tab out of field

**Expected Result**:
- No error message
- Lot number accepted
- Can proceed with posting

**Actual Result**: _____________

**Status**: ☐ Pass ☐ Fail

---

### Test Case 1.3: Lot Validation - Field Touch

**Objective**: Verify validation doesn't fire when just clicking into field

**Prerequisites**:
- Item Tracking Lines page open
- Lot No. field empty

**Steps**:
1. Click into Lot No. field (don't type anything)
2. Click out of field

**Expected Result**:
- No error message
- No validation triggered (field is empty or unchanged)

**Actual Result**: _____________

**Status**: ☐ Pass ☐ Fail

**Notes**: This tests the xRec parameter check

---

### Test Case 1.4: Lot Validation - Change Lot

**Objective**: Verify validation fires when changing from one lot to another

**Prerequisites**:
- Item Tracking Lines with LOT-PASS-001 already entered
- Quality Order for LOT-FAIL-002 with Status = Failed

**Steps**:
1. Click in Lot No. field showing LOT-PASS-001
2. Change to LOT-FAIL-002
3. Tab out

**Expected Result**:
- Validation fires
- Error message about Failed status
- Lot reverts to LOT-PASS-001

**Actual Result**: _____________

**Status**: ☐ Pass ☐ Fail

---

### Test Case 1.5: Lot Validation - Posting

**Objective**: Verify final validation at posting (safety net)

**Prerequisites**:
- Sales Order with lot-tracked item
- Manually bypass tracking specification (if possible via API/SQL)
- Use Lot No. with Failed status

**Steps**:
1. Post Sales Order

**Expected Result**:
- Posting fails
- Error message about lot quality status
- No Item Ledger Entry created

**Actual Result**: _____________

**Status**: ☐ Pass ☐ Fail

**Notes**: This tests OnBeforeInsertItemLedgEntry

---

## Part 2: Low Inventory Alert Testing

### Test Case 2.1: Configuration - Enable/Disable

**Objective**: Verify enable/disable toggle works

**Steps**:
1. Open Manufacturing Setup
2. Uncheck "Enable Inventory Alerts"
3. Post inventory adjustment that would normally trigger alert
4. Verify no alert sent
5. Check "Enable Inventory Alerts"
6. Post similar adjustment
7. Verify alert IS sent

**Expected Result**:
- Step 3: No alert sent, no Alert Log entry
- Step 6: Alert sent, Alert Log entry created

**Actual Result**: _____________

**Status**: ☐ Pass ☐ Fail

---

### Test Case 2.2: Threshold Crossing - Above to Below

**Objective**: Verify alert when crossing FROM above TO below safety stock

**Test Data**: TEST-001 (Initial: 150, Safety: 100)

**Steps**:
1. Verify current inventory = 150
2. Post Item Journal: Negative Adjmt., Qty = -60
3. Check Google Sheets
4. Check Inventory Alert Log

**Expected Result**:
- Before = 150, After = 90
- Alert sent (crossed threshold of 100)
- Google Sheets: New row with ItemNo=TEST-001, CurrentInventory=90
- Alert Log: Status=Success, Current Inventory=90, Safety Stock=100

**Actual Result**: _____________

**Status**: ☐ Pass ☐ Fail

---

### Test Case 2.3: No Alert - Already Below

**Objective**: Verify NO alert when inventory already below safety stock

**Test Data**: TEST-003 (Initial: 50, Safety: 100)

**Steps**:
1. Verify current inventory = 50 (already below 100)
2. Post Item Journal: Negative Adjmt., Qty = -10
3. Check Google Sheets
4. Check Inventory Alert Log

**Expected Result**:
- Before = 50, After = 40
- NO alert sent (didn't cross, already below)
- Google Sheets: No new row
- Alert Log: No new entry

**Actual Result**: _____________

**Status**: ☐ Pass ☐ Fail

---

### Test Case 2.4: No Alert - At Threshold Exactly

**Objective**: Verify NO alert when ending exactly AT safety stock

**Test Data**: TEST-002 (Initial: 100, Safety: 100)

**Steps**:
1. Verify current inventory = 100 (exactly at safety stock)
2. Post Item Journal: Negative Adjmt., Qty = -10
3. Check for alert

**Expected Result**:
- Before = 100, After = 90
- Alert sent (100 is NOT > 100, so... actually this should NOT alert)
- Wait, let's think: (100 > 100) AND (90 <= 100) = FALSE AND TRUE = FALSE
- NO alert

**Actually Expected**:
- NO alert because Before is not > Safety Stock
- Before = 100 is AT threshold, not above

**Actual Result**: _____________

**Status**: ☐ Pass ☐ Fail

**Notes**: Edge case - at exactly safety stock is considered "not above"

---

### Test Case 2.5: No Alert - Positive Quantity

**Objective**: Verify NO alert for positive quantities (purchases/production)

**Test Data**: TEST-001

**Steps**:
1. Post Item Journal: Positive Adjmt., Qty = +100
2. Check for alert

**Expected Result**:
- NO alert (positive quantities don't trigger event processing)
- No Alert Log entry

**Actual Result**: _____________

**Status**: ☐ Pass ☐ Fail

---

### Test Case 2.6: No Alert - Zero Safety Stock

**Objective**: Verify NO alert for items with Safety Stock = 0

**Test Data**: TEST-004 (Safety Stock = 0)

**Steps**:
1. Post Item Journal: Negative Adjmt., Qty = -50
2. Check for alert

**Expected Result**:
- NO alert (item not monitored)
- No Alert Log entry
- Debug message: "Safety Stock is 0, exiting"

**Actual Result**: _____________

**Status**: ☐ Pass ☐ Fail

---

### Test Case 2.7: Location-Specific Safety Stock

**Objective**: Verify location-specific safety stock takes precedence

**Test Data**: TEST-005
- Stockkeeping Unit: MAIN location, Safety Stock = 100
- Stockkeeping Unit: EAST location, Safety Stock = 50
- Item level: Safety Stock = 75

**Substeps A - MAIN Location**:
1. Current inventory MAIN = 120
2. Post Item Journal: Negative Adjmt., Qty = -30, Location = MAIN
3. Check Alert Log

**Expected Result A**:
- Before = 120, After = 90
- Safety Stock used = 100 (from SKU, not item)
- Alert sent (crossed 100 threshold)

**Substeps B - EAST Location**:
1. Current inventory EAST = 60
2. Post Item Journal: Negative Adjmt., Qty = -15, Location = EAST
3. Check Alert Log

**Expected Result B**:
- Before = 60, After = 45
- Safety Stock used = 50 (from SKU)
- Alert sent (crossed 50 threshold)

**Actual Result**: _____________

**Status**: ☐ Pass ☐ Fail

**Notes**: Demonstrates location-aware alerting

---

### Test Case 2.8: Multiple Threshold Crossings

**Objective**: Verify alert on each new threshold crossing

**Test Data**: TEST-001

**Steps**:
1. Starting inventory = 150
2. Post -60 (150→90, crosses 100) → Should alert
3. Post +50 (90→140, back above 100) → No alert (positive)
4. Post -50 (140→90, crosses 100 again) → Should alert again

**Expected Result**:
- Step 2: Alert sent
- Step 3: No alert
- Step 4: Alert sent (new crossing event)
- Total: 2 alerts in Google Sheets

**Actual Result**: _____________

**Status**: ☐ Pass ☐ Fail

---

## Part 3: Integration Testing

### Test Case 3.1: End-to-End Happy Path

**Objective**: Verify complete integration flow

**Steps**:
1. Set up test item above threshold
2. Post negative adjustment to cross below
3. Check BC Alert Log
4. Check Azure Logic Apps Run History
5. Check Google Sheets

**Expected Result**:
- BC Alert Log: Success status
- Azure Run History: Succeeded (green checkmark)
- Google Sheets: New row with correct data
- All within 5 seconds

**Actual Result**: _____________

**Status**: ☐ Pass ☐ Fail

---

### Test Case 3.2: HTTP Failure Handling

**Objective**: Verify posting continues even if HTTP fails

**Steps**:
1. In Manufacturing Setup, change URL to invalid (e.g., add "INVALID" to end)
2. Post negative adjustment that would trigger alert
3. Check if posting completed successfully
4. Check Alert Log

**Expected Result**:
- Posting succeeds (doesn't fail/rollback)
- Alert Log: Status = Failed
- Error Message: "Failed to send HTTP request" or HTTP error code

**Actual Result**: _____________

**Status**: ☐ Pass ☐ Fail

**Notes**: Fire-and-forget pattern working correctly

---

### Test Case 3.3: Azure Logic Apps Error Handling

**Objective**: Verify BC handles Logic Apps errors gracefully

**Steps**:
1. In Logic Apps, temporarily disable or delete Google Sheets action
2. Post negative adjustment to trigger alert
3. Check BC Alert Log
4. Check Azure Run History

**Expected Result**:
- BC Alert Log: Status = Failed (if Logic Apps returns error)
  OR Status = Success (if Logic Apps returns 200 despite internal failure)
- Azure Run History: Failed with error details
- BC posting completed successfully

**Actual Result**: _____________

**Status**: ☐ Pass ☐ Fail

---

### Test Case 3.4: Google Sheets Column Mismatch

**Objective**: Verify error when column headers don't match

**Steps**:
1. In Google Sheets, rename header "ItemNo" to "Item_No" (with underscore)
2. Post negative adjustment to trigger alert
3. Check Azure Run History

**Expected Result**:
- Azure Run History: Failed
- Error about "ItemNo" column not found
- BC Alert Log: Status = Failed OR Success (depending on when error occurs)

**Actual Result**: _____________

**Status**: ☐ Pass ☐ Fail

**Fix**: Rename column back to exact match

---

### Test Case 3.5: JSON Payload Validation

**Objective**: Verify correct JSON structure is sent

**Steps**:
1. Use Postman or Azure Run History to inspect JSON payload
2. Trigger alert
3. View raw JSON in Azure Run History

**Expected Result**:
```json
{
  "ItemNo": "TEST-001",
  "Description": "Above Threshold Item",
  "CurrentInventory": 90.0
}
```

**Actual Result**: _____________

**Status**: ☐ Pass ☐ Fail

---

## Part 4: Performance Testing

### Test Case 4.1: High Volume Posting

**Objective**: Verify system handles multiple postings without performance degradation

**Steps**:
1. Create Item Journal with 100 lines (mix of positive/negative)
2. Post entire batch
3. Measure time
4. Check Alert Log count

**Expected Result**:
- Posting completes in reasonable time (< 2 minutes)
- Only negative quantities below safety stock trigger alerts
- No errors or timeouts

**Actual Result**: _____________

**Status**: ☐ Pass ☐ Fail

---

### Test Case 4.2: Inventory Calculation Performance

**Objective**: Verify CalculateInventoryAtPoint performance with many ledger entries

**Prerequisites**:
- Item with 1000+ ledger entries

**Steps**:
1. Post adjustment for high-volume item
2. Monitor posting time
3. Check if alert sent

**Expected Result**:
- Posting time acceptable (< 5 seconds)
- Calculation completes
- Alert sent if threshold crossed

**Actual Result**: _____________

**Status**: ☐ Pass ☐ Fail

**Notes**: If slow, consider optimization

---

## Part 5: Edge Cases & Boundary Testing

### Test Case 5.1: Empty Location Code

**Objective**: Verify handling of blank location

**Steps**:
1. Post adjustment with Location Code = blank
2. Check alert behavior

**Expected Result**:
- Should work if item has item-level safety stock
- Location Code in Alert Log = blank
- Google Sheets: (blank or empty string)

**Actual Result**: _____________

**Status**: ☐ Pass ☐ Fail

---

### Test Case 5.2: Very Large Quantities

**Objective**: Verify handling of large quantity values

**Steps**:
1. Post adjustment with Quantity = -999,999
2. Check if system handles correctly

**Expected Result**:
- Alert sent if crossing threshold
- CurrentInventory calculated correctly (may be negative)

**Actual Result**: _____________

**Status**: ☐ Pass ☐ Fail

---

### Test Case 5.3: Decimal Quantities

**Objective**: Verify handling of decimal quantities

**Steps**:
1. Post adjustment with Quantity = -10.5
2. Check CurrentInventory value in alert

**Expected Result**:
- CurrentInventory shows correct decimal value
- Threshold logic works with decimals

**Actual Result**: _____________

**Status**: ☐ Pass ☐ Fail

---

### Test Case 5.4: Concurrent Postings

**Objective**: Verify handling of simultaneous postings for same item

**Steps**:
1. Open two BC sessions
2. Post adjustments for same item simultaneously
3. Check for race conditions or errors

**Expected Result**:
- Both postings complete
- Alerts sent appropriately
- No lost updates or errors

**Actual Result**: _____________

**Status**: ☐ Pass ☐ Fail

---

### Test Case 5.5: Special Characters in Item Description

**Objective**: Verify JSON handles special characters

**Steps**:
1. Item with Description = `Widget "Special" & <Tag>`
2. Trigger alert
3. Check JSON payload and Google Sheets

**Expected Result**:
- JSON properly escapes special characters
- Google Sheets displays correctly
- No parsing errors

**Actual Result**: _____________

**Status**: ☐ Pass ☐ Fail

---

## Part 6: Regression Testing

Run after any code changes to verify existing functionality still works.

### Regression Test Checklist

- [ ] Test Case 2.2: Threshold crossing still triggers alert
- [ ] Test Case 2.3: Already below still doesn't alert
- [ ] Test Case 2.7: Location-specific safety stock
- [ ] Test Case 3.1: End-to-end integration
- [ ] Test Case 3.2: HTTP failure handling
- [ ] Test Case 1.1: Quality Management lot validation

---

## Test Results Summary

| Test Case | Status | Notes |
|-----------|--------|-------|
| 1.1 Lot Validation - Pending/Failed | ☐ Pass ☐ Fail | |
| 1.2 Lot Validation - Passed | ☐ Pass ☐ Fail | |
| 1.3 Lot Validation - Field Touch | ☐ Pass ☐ Fail | |
| 1.4 Lot Validation - Change Lot | ☐ Pass ☐ Fail | |
| 1.5 Lot Validation - Posting | ☐ Pass ☐ Fail | |
| 2.1 Enable/Disable | ☐ Pass ☐ Fail | |
| 2.2 Threshold Crossing | ☐ Pass ☐ Fail | |
| 2.3 No Alert - Already Below | ☐ Pass ☐ Fail | |
| 2.4 No Alert - At Threshold | ☐ Pass ☐ Fail | |
| 2.5 No Alert - Positive Qty | ☐ Pass ☐ Fail | |
| 2.6 No Alert - Zero Safety Stock | ☐ Pass ☐ Fail | |
| 2.7 Location-Specific | ☐ Pass ☐ Fail | |
| 2.8 Multiple Crossings | ☐ Pass ☐ Fail | |
| 3.1 End-to-End | ☐ Pass ☐ Fail | |
| 3.2 HTTP Failure | ☐ Pass ☐ Fail | |
| 3.3 Azure Error Handling | ☐ Pass ☐ Fail | |
| 3.4 Column Mismatch | ☐ Pass ☐ Fail | |
| 3.5 JSON Validation | ☐ Pass ☐ Fail | |
| 4.1 High Volume | ☐ Pass ☐ Fail | |
| 4.2 Calculation Performance | ☐ Pass ☐ Fail | |
| 5.1 Empty Location | ☐ Pass ☐ Fail | |
| 5.2 Large Quantities | ☐ Pass ☐ Fail | |
| 5.3 Decimal Quantities | ☐ Pass ☐ Fail | |
| 5.4 Concurrent Postings | ☐ Pass ☐ Fail | |
| 5.5 Special Characters | ☐ Pass ☐ Fail | |

**Overall Pass Rate**: _____ / 25 (____%)

**Tester**: _____________
**Date**: _____________
**Environment**: _____________
**Build Version**: _____________

---

## Automated Testing (Future)

Consider implementing automated tests using:
- AL Test Framework
- Test Codeunits with test functions
- Mock HTTP responses
- Automated regression suite

Example test structure:
```al
codeunit 50110 "Low Inventory Alert Test"
{
    Subtype = Test;

    [Test]
    procedure TestThresholdCrossing()
    begin
        // Arrange: Set up item above threshold
        // Act: Post negative adjustment
        // Assert: Verify alert sent
    end;
}
```

---

## Test Data Cleanup

After testing, clean up:
1. Delete test items (TEST-001 through TEST-005)
2. Clear Inventory Alert Log: Delete All action
3. Archive or delete test rows in Google Sheets
4. Reset Manufacturing Setup to production values
5. Remove test Quality Orders
