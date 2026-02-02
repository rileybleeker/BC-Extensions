# Troubleshooting Guide

Common issues and solutions for ALProject10.

---

## Quick Diagnostics Checklist

Before diving into specific issues, run through this checklist:

- [ ] Extension is installed and published in BC
- [ ] Manufacturing Setup → Enable Inventory Alerts is checked
- [ ] Logic Apps Endpoint URL is filled (complete 300+ char URL)
- [ ] Item has Safety Stock Quantity > 0
- [ ] Current inventory is ABOVE safety stock (before test)
- [ ] Posting quantity is NEGATIVE
- [ ] Location Code matches (if using location-specific safety stock)
- [ ] Debug messages are visible (if still enabled)

---

## Part 1: Quality Management Issues

### Issue 1.1: Lot validation not firing

**Symptoms**:
- User can enter Pending/Failed lot without error
- No validation message appears

**Possible Causes**:
1. Extension not installed
2. Quality Order doesn't exist for that lot
3. Quality Order status is "Passed"
4. Item doesn't have lot tracking enabled

**Diagnosis**:
```al
// Check if Quality Order exists
SELECT * FROM "Quality Order"
WHERE "Lot No." = 'LOT-FAIL-001'
AND "Test Status" IN (0, 2); // 0=Pending, 2=Failed
```

**Solutions**:
1. Verify extension installed: Extension Management page
2. Create Quality Order with Pending/Failed status
3. Enable lot tracking on item: Item Card → Tracking → Lot Nos.

---

### Issue 1.2: Validation firing too often

**Symptoms**:
- Error message appears when clicking into field
- Error appears when not changing lot number

**Cause**:
- Missing or incorrect xRec parameter check

**Solution**:
Verify this line in Quality Management Codeunit.al:
```al
if (Rec."Lot No." <> '') and (Rec."Lot No." <> xRec."Lot No.") and (Rec."Quantity (Base)" < 0) then
```

The `<> xRec."Lot No."` check is critical.

---

### Issue 1.3: Can post despite validation

**Symptoms**:
- Validation error shows but posting still completes
- Item Ledger Entry created with Failed lot

**Cause**:
- Validation is using Message() instead of Error()

**Solution**:
Check ValidateLotQualityStatus procedure:
```al
if QualityOrder.FindFirst() then
    Error('Cannot select Lot No. %1...'); // Must be Error(), not Message()
```

---

## Part 2: Low Inventory Alert Issues

### Issue 2.1: No alerts sent (nothing happening)

**Symptoms**:
- Post negative adjustment below safety stock
- No Alert Log entry
- No row in Google Sheets
- No debug messages (if enabled)

**Diagnosis Steps**:

**Step 1: Check Configuration**
```
Manufacturing Setup → Low Inventory Alert Integration
- [ ] Enable Inventory Alerts is CHECKED
- [ ] Logic Apps Endpoint URL is filled
- [ ] URL length is 300+ characters (not truncated)
```

**Step 2: Check Item Setup**
```
Item Card or Stockkeeping Unit
- [ ] Safety Stock Quantity > 0
- [ ] Current inventory is ABOVE safety stock
```

**Step 3: Check Posting**
```
Item Journal Line
- [ ] Entry Type = Negative Adjmt. (or any outbound transaction)
- [ ] Quantity is NEGATIVE (e.g., -10, not +10)
```

**Step 4: Enable Debug Mode**
If debug messages removed, temporarily re-add to diagnose:
```al
Message('DEBUG: Event fired for Item %1, Qty %2', ItemLedgerEntry."Item No.", ItemLedgerEntry.Quantity);
```

**Step 5: Check Event Subscriber**
Verify codeunit is compiled and published:
```
In BC, search: Codeunit 50103 "Low Inventory Alert"
If not found: Extension not installed properly
```

**Solutions by Exit Point**:
- "DEBUG: Could not get Manufacturing Setup" → Setup record missing, recreate
- "DEBUG: Alerts not enabled" → Check the checkbox
- "DEBUG: URL is empty" → Paste complete URL from Azure
- "DEBUG: Quantity is not negative" → Use negative quantities
- "DEBUG: Safety Stock is 0" → Set safety stock on item/SKU
- "DEBUG: No threshold crossing" → Inventory wasn't above threshold

---

### Issue 2.2: Alert Log shows "Failed" status

**Symptoms**:
- Alert Log entry created
- Status = Failed
- Error Message field has details

**Common Error Messages**:

#### Error: "Failed to send HTTP request"

**Cause**: Network connectivity or URL issue

**Solutions**:
1. **Verify URL is complete**:
   - Copy URL from Manufacturing Setup
   - Paste in Notepad
   - Should be 300-400 characters
   - Should start with: `https://prod-` or `https://logic-`
   - Should end with: `&sp=...`

2. **Test with Postman**:
   - Copy URL
   - Create POST request in Postman
   - Headers: `Content-Type: application/json`
   - Body (raw JSON):
     ```json
     {
       "ItemNo": "TEST",
       "Description": "Test Item",
       "CurrentInventory": 50
     }
     ```
   - Send
   - Should return 200 OK

3. **Check firewall**:
   - BC server must allow outbound HTTPS (port 443)
   - Whitelist: `*.azure.com` and `*.logic.azure.com`

#### Error: "HTTP 401: Unauthorized"

**Cause**: Authentication failed

**Solutions**:
1. **If using API key**:
   - Verify API key in Manufacturing Setup matches Logic Apps expectation
   - Check if Logic Apps requires specific header name
   - Try removing API key entirely (test with no auth)

2. **If using IP whitelist**:
   - Get BC server's public IP
   - Add to Logic Apps → Settings → Workflow settings → Allowed inbound IP addresses

3. **URL truncation**:
   - Most common cause!
   - Logic Apps URLs contain authentication tokens in query string
   - If truncated, authentication fails
   - Solution: Ensure Text[500] field, re-paste complete URL

#### Error: "HTTP 404: Not Found"

**Cause**: Incorrect URL or Logic App deleted/disabled

**Solutions**:
1. Verify Logic App exists in Azure Portal
2. Check if Logic App is enabled (not disabled)
3. Get fresh URL from Logic Apps Designer → HTTP trigger → Copy URL
4. Paste NEW url into BC (don't edit existing)

#### Error: "HTTP 400: Bad Request"

**Cause**: JSON payload doesn't match Logic Apps schema

**Solutions**:
1. Check JSON schema in Logic Apps trigger matches:
   ```json
   {
     "ItemNo": "string",
     "Description": "string",
     "CurrentInventory": "number"
   }
   ```
2. Verify BuildAlertPayload procedure creates valid JSON
3. Test JSON with online validator: jsonlint.com

#### Error: "HTTP 500: Internal Server Error"

**Cause**: Logic Apps encountered error during execution

**Solutions**:
1. Azure Portal → Logic Apps → Run history
2. Find the failed run (red X)
3. Click to see details
4. Common causes:
   - Google Sheets action failed
   - Worksheet not found
   - Authentication expired
5. Fix issue in Logic Apps
6. Retry by posting another adjustment in BC

---

### Issue 2.3: Alert sent but not in Google Sheets

**Symptoms**:
- Alert Log shows Status = Success
- No row in Google Sheets

**Diagnosis**:
1. Azure Portal → Logic Apps → Run history
2. Find recent run corresponding to timestamp in Alert Log
3. Click on run to see details

**Common Causes**:

#### Cause 1: Google Sheets action failed

**Symptoms in Run History**:
- HTTP trigger: Succeeded (green)
- Google Sheets Insert row: Failed (red)

**Error**: "The specified column 'ItemNo' does not exist"

**Solution**:
- Google Sheets Row 1 headers must EXACTLY match:
  - `ItemNo` (not Item_No, not itemno, not Item No)
  - `Description`
  - `CurrentInventory`
- Case-sensitive!
- No spaces in column names

**Error**: "Unable to find worksheet"

**Solution**:
- Verify worksheet name in Logic Apps matches actual sheet
- Check if worksheet was deleted or renamed
- Update Logic Apps → Google Sheets action → Worksheet dropdown

#### Cause 2: Authentication expired

**Symptoms**:
- Error: "Unauthorized" or "Token expired"

**Solution**:
1. Logic Apps Designer → Google Sheets action
2. Click "⚠ Connection invalid"
3. Click "Add new connection"
4. Sign in with Google account
5. Grant permissions
6. Update action to use new connection
7. Save Logic Apps

#### Cause 3: Wrong file selected

**Symptoms**:
- No error, but data going to different spreadsheet

**Solution**:
1. Logic Apps Designer → Google Sheets action → File
2. Verify correct spreadsheet selected
3. Open Google Sheets and check "File → Version history" to see if updates are happening

---

### Issue 2.4: Duplicate alerts for same threshold crossing

**Symptoms**:
- Multiple Alert Log entries for same item+location+timestamp
- Multiple rows in Google Sheets

**Cause**:
- Event subscriber firing multiple times
- Item Ledger Entry posted multiple times (shouldn't happen)

**Diagnosis**:
```sql
SELECT "Entry No.", "Item No.", "Location Code", "Quantity", "Posting Date"
FROM "Item Ledger Entry"
WHERE "Item No." = 'TEST-001'
ORDER BY "Entry No." DESC;
```

Check for duplicate entries with same timestamp.

**Solution**:
- Review posting code to ensure single Item Ledger Entry
- Check if event subscriber has `SingleInstance = true` (shouldn't, but verify)
- Verify threshold logic is working: only alerts on crossing, not when already below

---

### Issue 2.5: No alert despite crossing threshold

**Symptoms**:
- Post -60 (from 105 to 45, crossing 100)
- No alert sent
- Debug shows "No threshold crossing"

**Cause**: Inventory was actually NOT above threshold before posting

**Diagnosis**:
1. Check debug message: "Before=%1, After=%2, SafetyStock=%3"
2. Example: "Before=85, After=25, SafetyStock=100"
   - Before (85) is NOT > SafetyStock (100)
   - Therefore: No alert

**Why inventory might be lower than expected**:
- Previous postings not accounted for
- Different location (check Location Code)
- Item Ledger Entries from other users/sessions

**Solution**:
1. Check actual inventory:
   ```
   Item Card → Navigate → Ledger Entries
   Filter by Location Code
   Sum Quantity column
   ```
2. Verify this matches "Before" value in debug
3. Adjust starting inventory to be above threshold
4. Try again

---

### Issue 2.6: Location Code not populating in Alert Log

**Symptoms**:
- Alert Log shows alert
- Item No. is filled
- Location Code is blank

**Cause**:
- Logging procedures not querying Item Ledger Entry for Location Code

**Solution**:
Verify LogAlertSuccess and LogAlertError procedures include:
```al
if ItemLedgEntry.Get(EntryNo) then begin
    AlertLog."Item No." := ItemLedgEntry."Item No.";
    AlertLog."Location Code" := ItemLedgEntry."Location Code."; // ← This line
end;
```

If missing, update codeunit and republish.

---

### Issue 2.7: Wrong safety stock value used

**Symptoms**:
- Expected location-specific safety stock (50)
- Used item-level safety stock (100) instead

**Cause**:
- Stockkeeping Unit not set up correctly
- SKU Location Code doesn't match posting location

**Diagnosis**:
```
Stockkeeping Units → Filters:
- Item No. = [your item]
- Location Code = [your location]

If no record found → Item-level safety stock used as fallback
```

**Solution**:
1. Create Stockkeeping Unit:
   - Item No.: [your item]
   - Location Code: [your location]
   - Safety Stock Quantity: [desired value]
2. Post adjustment again
3. Verify debug message shows correct safety stock

---

## Part 3: Azure Logic Apps Issues

### Issue 3.1: Logic Apps run not appearing

**Symptoms**:
- BC sends HTTP request (Alert Log says Success)
- No run history in Azure

**Cause**:
- Looking at wrong Logic App
- Logic App in different subscription/resource group
- Run history filtered

**Solution**:
1. Verify URL matches Logic App:
   - Copy URL from BC Manufacturing Setup
   - Extract workflow name from URL (between `/workflows/` and `/triggers/`)
   - Find that workflow in Azure Portal
2. Clear filters in Run history:
   - Click "All runs"
   - Select "All time"

---

### Issue 3.2: Logic Apps trigger not configured

**Symptoms**:
- Logic Apps exists but no runs
- Error: "Trigger not found"

**Solution**:
1. Logic Apps Designer
2. Verify first step is: "When an HTTP request is received"
3. Verify trigger has JSON schema configured
4. Save Logic Apps
5. Get fresh URL

---

### Issue 3.3: Google Sheets connector not working

**Symptoms**:
- Run history shows Google Sheets action failed
- Error: "Connector error"

**Solution**:
1. Check Google Sheets connector status:
   - Logic Apps → Connections (in left menu)
   - Find "Google Sheets" connection
   - Status should be "Connected"
2. If "Error" status:
   - Delete connection
   - Re-add in Logic Apps Designer
   - Re-authenticate
3. Check Google Sheets API status: status.cloud.google.com

---

## Part 4: Performance Issues

### Issue 4.1: Posting is slow

**Symptoms**:
- Item Journal posting takes > 10 seconds
- Users complain about performance

**Diagnosis**:
1. Disable Low Inventory Alerts temporarily:
   - Uncheck "Enable Inventory Alerts"
   - Post again
   - Still slow? Not our code.
2. Check Item Ledger Entry count:
   ```sql
   SELECT COUNT(*) FROM "Item Ledger Entry"
   WHERE "Item No." = 'TEST-001' AND "Location Code" = 'MAIN';
   ```
   - > 10,000 entries might cause slow CalculateInventoryAtPoint

**Solutions**:
1. **Optimize CalculateInventoryAtPoint**:
   - Add index on (Item No., Location Code, Entry No.)
   - Consider using Item."Inventory" FlowField instead (less accurate)

2. **Reduce event subscriber scope**:
   - Only monitor specific item categories
   - Add filter: `if Item."Item Category Code" <> 'MONITOR' then exit;`

3. **Async processing** (future enhancement):
   - Queue alert requests
   - Process in background job
   - Don't block posting

---

### Issue 4.2: HTTP timeout

**Symptoms**:
- Alert Log shows: "Failed to send HTTP request"
- Timeout error
- Takes > 30 seconds

**Cause**:
- Azure Logic Apps slow or unresponsive
- Google Sheets API slow
- Network latency

**Solutions**:
1. Check Azure Logic Apps performance:
   - Run history → View duration
   - Should be < 2 seconds
2. If slow:
   - Google Sheets might be rate limiting
   - Add "Response" action immediately after trigger (before Google Sheets)
   - Process Google Sheets asynchronously
3. BC timeout setting (if available):
   - Increase HttpClient timeout (default 100 seconds should be plenty)

---

## Part 5: Data Issues

### Issue 5.1: Wrong inventory value in alert

**Symptoms**:
- Alert shows CurrentInventory = 90
- Actual inventory in BC = 100

**Cause**:
- CalculateInventoryAtPoint calculation error
- Using wrong Entry No. range
- Different location

**Diagnosis**:
```al
// Check calculation manually
SELECT SUM(Quantity) FROM "Item Ledger Entry"
WHERE "Item No." = 'TEST-001'
AND "Location Code" = 'MAIN'
AND "Entry No." <= [EntryNo - 1];
```

Compare to "Before" value in debug message.

**Solution**:
- Verify CalculateInventoryAtPoint logic
- Ensure Entry No. filter is correct: `0..UpToEntryNo`
- Check Location Code matches

---

### Issue 5.2: Special characters in JSON

**Symptoms**:
- Item description has quotes or < > symbols
- JSON parsing error in Logic Apps

**Cause**:
- JSON not properly escaped

**Solution**:
The JsonObject.Add() method automatically escapes. If still issues:
```al
// Manual escaping (shouldn't be needed)
Description := Item.Description.Replace('"', '\"');
JsonObject.Add('Description', Description);
```

---

## Part 6: Debugging Tools

### Tool 1: Enable Debug Messages

If removed, temporarily re-add to diagnose:
```al
Message('DEBUG: Event fired for Item %1, Qty %2', ItemLedgerEntry."Item No.", ItemLedgerEntry.Quantity);
Message('DEBUG: Before=%1, After=%2, SafetyStock=%3', InventoryBeforePosting, InventoryAfterPosting, SafetyStockQty);
```

### Tool 2: Alert Log Analysis

```sql
-- Check recent alerts
SELECT TOP 10 * FROM "Inventory Alert Log"
ORDER BY "Alert Timestamp" DESC;

-- Check failure rate
SELECT "Alert Status", COUNT(*)
FROM "Inventory Alert Log"
GROUP BY "Alert Status";

-- Find items with most alerts
SELECT "Item No.", COUNT(*)
FROM "Inventory Alert Log"
WHERE "Alert Status" = 0 -- Success
GROUP BY "Item No."
ORDER BY COUNT(*) DESC;
```

### Tool 3: Azure Run History

1. Azure Portal → Logic Apps → Run history
2. Click on failed run
3. View each action's inputs and outputs
4. Identify where failure occurred

### Tool 4: Postman for HTTP Testing

Isolate BC from Azure by testing Logic Apps directly:

```
POST {{LogicAppsURL}}
Headers:
    Content-Type: application/json
Body:
    {
      "ItemNo": "TEST",
      "Description": "Test",
      "CurrentInventory": 50
    }
```

If this works → Issue is in BC
If this fails → Issue is in Azure/Google

### Tool 5: Google Sheets Activity

View → Show Version History → See all changes

Check if rows are being added (confirms data flow).

---

## Part 7: Emergency Procedures

### Emergency: Disable Alerts Immediately

If alerts causing issues in production:

1. **Quick disable**:
   - Manufacturing Setup
   - Uncheck "Enable Inventory Alerts"
   - Click OK

2. **Or** clear URL:
   - Manufacturing Setup
   - Clear "Logic Apps Endpoint URL"
   - Click OK

Posting will continue normally, alerts will stop.

### Emergency: Clear Alert Log

If Alert Log growing too large:

1. Inventory Alert Log page
2. Click "Delete All Entries"
3. Confirm

Or via SQL:
```sql
DELETE FROM "Inventory Alert Log";
```

### Emergency: Uninstall Extension

If extension causing critical issues:

1. Extension Management
2. Find "ALProject10"
3. Click "Uninstall"
4. Restart BC service

**Warning**: Uninstalling removes:
- Low Inventory Alert functionality
- Quality Management validations
- Manufacturing Setup fields (data preserved)
- Alert Log table (data lost if not backed up)

---

## Getting Help

### Before Contacting Support

Gather this information:
1. BC Version and build number
2. Extension version (from app.json)
3. Screenshots of:
   - Manufacturing Setup configuration
   - Alert Log error message
   - Azure Logic Apps run history (if applicable)
4. Steps to reproduce
5. Expected vs. actual behavior

### Support Channels

1. **GitHub Issues**: github.com/[your-repo]/issues
2. **Internal Team**: [contact info]
3. **Azure Support**: For Logic Apps issues
4. **BC Partner**: For BC platform issues

---

## Appendix: Common Error Codes

| Error Code | Meaning | Typical Cause |
|------------|---------|---------------|
| 400 | Bad Request | Invalid JSON or missing required fields |
| 401 | Unauthorized | API key wrong or URL truncated |
| 403 | Forbidden | IP not whitelisted or no permission |
| 404 | Not Found | Wrong URL or Logic App deleted |
| 429 | Too Many Requests | Rate limit exceeded (Google Sheets) |
| 500 | Internal Server Error | Logic Apps or Google Sheets error |
| 502 | Bad Gateway | Azure connectivity issue |
| 503 | Service Unavailable | Azure service down |
| 504 | Gateway Timeout | Request took too long |

---

## Prevention Checklist

Prevent issues before they happen:

- [ ] Test thoroughly in Dev before Production
- [ ] Set up Azure Monitor alerts for Logic Apps failures
- [ ] Document your specific setup and configuration
- [ ] Keep safety stock values reasonable
- [ ] Monitor Alert Log weekly for Failed entries
- [ ] Review Azure Logic Apps costs monthly
- [ ] Back up extension code in GitHub
- [ ] Version control app.json changes
- [ ] Test after any BC update/upgrade
- [ ] Create runbook for team members
