# Setup Guide

Complete setup instructions for ALProject10 - Quality Management and Low Inventory Alert system.

---

## Prerequisites

### Business Central
- Business Central Online (Cloud) or On-Premises version
- AL Development environment (VS Code + AL Extension)
- Permission Set: SUPER or equivalent with:
  - Table Data modify permissions
  - Extension publishing rights
  - Manufacturing Setup access

### Azure Subscription
- Active Azure subscription
- Permission to create Logic Apps
- Resource Group available

### Google Account
- Google account with Sheets access
- Permission to create and edit spreadsheets

---

## Part 1: Business Central Setup

### Step 1: Install Extension

#### Option A: From VS Code (Development)
1. Open project folder in VS Code
2. Press `F5` or `Ctrl+F5` to publish
3. Select your BC environment
4. Wait for "Published successfully" message

#### Option B: From .app File (Production)
1. Build .app file: `Alt+F6` in VS Code
2. Navigate to BC Administration
3. Go to **Extension Management**
4. Click **Upload Extension**
5. Select `ALProject10.app`
6. Click **Deploy** → **Install**

### Step 2: Configure Manufacturing Setup

1. In Business Central, search for **Manufacturing Setup**
2. Navigate to the **General** FastTab
3. Scroll to **Low Inventory Alert Integration** group

#### Configuration Fields:

**Enable Inventory Alerts**
- Type: Boolean
- Default: Unchecked
- Action: ☑ Check to enable alerts

**Logic Apps Endpoint URL**
- Type: Text (500 characters)
- Required: Yes (when alerts enabled)
- Value: (will be filled after Azure setup)
- Example: `https://prod-06.eastus.logic.azure.com/workflows/.../triggers/manual/paths/invoke`

**Logic Apps API Key**
- Type: Text (100 characters, masked)
- Required: No (optional security)
- Value: (will be filled if using API key authentication)

> **Note**: Leave URL and API Key empty for now. Complete Azure setup first, then return to fill these values.

### Step 3: Configure Safety Stock

Safety stock thresholds determine when alerts are sent.

#### Option A: Item-Level Safety Stock (Default)
1. Search for **Items** list
2. Open an item card
3. Navigate to **Planning** FastTab
4. Set **Safety Stock Quantity** (e.g., 100)
5. Repeat for items you want to monitor

#### Option B: Location-Level Safety Stock (Recommended)
1. Search for **Stockkeeping Units**
2. Create or open SKU for Item + Location combination
3. Set **Safety Stock Quantity** (e.g., 100 for MAIN, 50 for EAST)
4. Location-specific values take precedence over item-level

> **Best Practice**: Use location-level safety stock for multi-warehouse scenarios to set different thresholds per location.

### Step 4: Verify Quality Management

Quality Management is automatically active after extension installation.

**Test Validation**:
1. Create a Quality Order with Test Status = **Pending** or **Failed**
2. Try to create a sales order or inventory adjustment with that lot
3. Expected: Error message preventing selection
4. Change Quality Order status to **Passed**
5. Now lot should be selectable

---

## Part 2: Azure Logic Apps Setup

### Step 1: Create Logic App

1. Sign in to [Azure Portal](https://portal.azure.com)
2. Click **+ Create a resource**
3. Search for **Logic App**
4. Click **Create**

**Configuration**:
- **Subscription**: Select your subscription
- **Resource Group**: Select or create new
- **Logic App Name**: `BC-Inventory-Alerts` (or your preferred name)
- **Region**: Select region close to your BC instance
- **Plan Type**: **Consumption** (pay-per-use)
- **Zone redundancy**: Disable (optional for cost savings)

5. Click **Review + Create**
6. Click **Create**
7. Wait for deployment (1-2 minutes)
8. Click **Go to resource**

### Step 2: Configure HTTP Trigger

1. In Logic Apps Designer, click **+ New step** or **Blank Logic App**
2. Search for: `When an HTTP request is received`
3. Click on the trigger

**Configure Request**:
1. Click **Use sample payload to generate schema**
2. Paste this JSON sample:

```json
{
  "ItemNo": "1000",
  "Description": "Widget Assembly",
  "CurrentInventory": 95.0
}
```

3. Click **Done**
4. The schema will be auto-generated

### Step 3: Add Google Sheets Action

1. Click **+ New step**
2. Search for: `Google Sheets`
3. Select **Insert row** action

**Authentication** (first time only):
1. Click **Sign in**
2. Enter your Google account credentials
3. Grant permissions to Logic Apps

**Configure Action**:
1. **Location**: `MyDrive` (or select team drive)
2. **Document Library**: `Sheets`
3. **File**: Select existing or create new spreadsheet
   - Recommended name: `BC Inventory Alerts`
4. **Worksheet**: Select or create worksheet
   - Ensure Row 1 has headers: `ItemNo`, `Description`, `CurrentInventory`

**Map Fields** (Dynamic Content):
1. Click in first column field
2. Click **Dynamic content** lightning bolt
3. Select `ItemNo` from HTTP trigger
4. Repeat for `Description` and `CurrentInventory`

### Step 4: Add Response (Optional but Recommended)

1. Click **+ New step**
2. Search for: `Response`
3. Select **Response** action

**Configure**:
- **Status Code**: `200`
- **Body**:
```json
{
  "status": "success",
  "message": "Alert logged"
}
```

### Step 5: Save and Get URL

1. Click **Save** at the top
2. Expand the **When an HTTP request is received** trigger (click on it)
3. Copy the **HTTP POST URL**
   - It will look like: `https://prod-06.eastus.logic.azure.com:443/workflows/.../triggers/manual/paths/invoke?api-version=2016-10-01&sp=%2F...`
4. **Important**: Copy the ENTIRE URL (may be 320+ characters)

### Step 6: Configure Security (Optional)

#### Option A: No Authentication (IP Whitelist)
- Azure Logic Apps → Settings → Workflow settings
- Allowed inbound IP addresses: Add your BC server IP
- This is the default and simplest option

#### Option B: API Key Header
1. In Logic Apps Designer, click on **When an HTTP request is received**
2. Click **...** (three dots) → **Settings**
3. **Method**: `POST` (already set)
4. **Add** custom header validation:
   - Add condition action after trigger
   - Check if header `x-api-key` equals your secret value
   - If not, return 401 Unauthorized

> **Note**: For production, consider using Azure AD OAuth or Shared Access Signatures for stronger security.

---

## Part 3: Google Sheets Preparation

### Step 1: Create Spreadsheet (if new)

1. Go to [Google Sheets](https://sheets.google.com)
2. Click **+ Blank** to create new spreadsheet
3. Rename to: `BC Inventory Alerts`

### Step 2: Set Up Headers

**Row 1** must contain these exact headers (case-sensitive):
| A | B | C |
|---|---|---|
| ItemNo | Description | CurrentInventory |

**Optional additional columns** (for future expansion):
| D | E | F | G | H |
|---|---|---|---|---|
| SafetyStock | LocationCode | LocationName | Timestamp | VendorNo |

### Step 3: Format Columns (Recommended)

1. Select Column A (`ItemNo`):
   - Format → Number → Plain text
2. Select Column C (`CurrentInventory`):
   - Format → Number → Number (2 decimal places)
3. Freeze Row 1:
   - View → Freeze → 1 row

### Step 4: Share with Team (Optional)

1. Click **Share** button
2. Add team members with "Editor" or "Viewer" permissions
3. Get link to share: **Anyone with the link can view**

---

## Part 4: Connect BC to Azure

### Step 1: Return to BC Manufacturing Setup

1. Search for **Manufacturing Setup** in BC
2. Navigate to **Low Inventory Alert Integration** group

### Step 2: Paste Azure URL

1. Click in **Logic Apps Endpoint URL** field
2. **Paste** the FULL URL from Azure Logic Apps (Step 2.5 above)
3. **Verify**: URL should be 300-400 characters long
4. **Critical**: Make sure entire URL is pasted (text field supports 500 chars)

### Step 3: Add API Key (if configured)

1. If you configured API key in Azure (optional)
2. Enter the key in **Logic Apps API Key** field
3. Field is masked for security

### Step 4: Enable Alerts

1. Check **☑ Enable Inventory Alerts**
2. Click **OK** or close the page (auto-saves)

---

## Part 5: Testing

### Test 1: Configuration Verification

1. In BC, open **Manufacturing Setup**
2. Verify:
   - ☑ Enable Inventory Alerts is checked
   - Logic Apps Endpoint URL is filled (full URL)
   - All three fields are visible

### Test 2: Safety Stock Check

1. Search for **Items** or **Stockkeeping Units**
2. Verify at least one item has Safety Stock Quantity > 0
3. Note the Item No. and current inventory

### Test 3: Threshold Crossing Test

**Setup**:
- Item: Select item from Test 2
- Safety Stock: 100
- Current Inventory: 105 (must be above safety stock)

**Procedure**:
1. Search for **Item Journal**
2. Create new line:
   - **Item No.**: Your test item
   - **Entry Type**: Negative Adjmt.
   - **Quantity**: 10 (to reduce from 105 to 95)
   - **Location Code**: (your location)
3. Click **Post**
4. Confirm posting

**Expected Result** (with debug messages):
- Multiple debug messages showing:
  - Event fired
  - Alerts enabled
  - URL is not empty
  - Quantity is negative
  - Safety Stock = 100
  - Before=105, After=95, SafetyStock=100
  - Threshold crossed! Sending alert...

### Test 4: Verify in Google Sheets

1. Open your Google Sheets spreadsheet
2. New row should appear with:
   - ItemNo: (your item)
   - Description: (item description)
   - CurrentInventory: 95

### Test 5: Check Alert Log in BC

1. Search for **Inventory Alert Log** in BC
2. Find the most recent entry
3. Verify:
   - Alert Status = **Success**
   - Item No. is populated
   - Location Code is populated
   - Current Inventory = 95
   - Safety Stock = 100
   - Alert Timestamp shows current date/time

### Test 6: Verify No Alert When Already Below

**Setup**:
- Same item (now at 95)
- Safety Stock still 100

**Procedure**:
1. Post another negative adjustment of -5 (95 → 90)
2. Click **Post**

**Expected Result**:
- Debug messages show:
  - "No threshold crossing"
  - "Before>Safety? FALSE, After<=Safety? TRUE"
- **No new row in Google Sheets**
- **No new Alert Log entry**

**Why**: We didn't cross the threshold; we were already below.

---

## Part 6: Production Readiness

### Remove Debug Messages

Before going live in production:

1. Open **Low Inventory Alert Codeunit.al** in VS Code
2. Search for all `Message('DEBUG:` lines
3. Comment out or delete these lines:
   - Lines 9, 13, 18, 23, 29, 33 (in OnAfterInsertItemLedgEntry)
   - Lines 45, 50, 53, 67, 71, 74-76 (in CheckInventoryThresholdCrossing)
4. Republish extension

**Alternative**: Add "Debug Mode" flag to Manufacturing Setup to toggle messages.

### Update Version Number

1. Open `app.json`
2. Increment **version** field: `"1.0.0"` → `"1.0.1"` (or `"1.1.0"` for debug removal)
3. Save file
4. Republish

### Create Git Tag

```bash
git tag v1.0.1 -m "Production release - removed debug messages"
git push origin v1.0.1
```

### User Documentation

Provide users with:
1. Link to Inventory Alert Log page
2. Instructions for reviewing alert history
3. Contact for Azure Logic Apps issues
4. Safety stock configuration guidelines

---

## Troubleshooting Setup

### Issue: "Enable Inventory Alerts" field not visible

**Cause**: Extension not installed or not published
**Solution**:
1. Check Extension Management in BC
2. Verify ALProject10 is installed
3. Refresh browser / restart BC client

### Issue: No alert sent during test

**Check**:
1. Manufacturing Setup → Enable Inventory Alerts is checked
2. Logic Apps Endpoint URL is filled (complete URL)
3. Item has Safety Stock > 0
4. Current inventory is ABOVE safety stock before test
5. Posting quantity is negative
6. Check debug messages (if still active)

### Issue: Alert Log shows "Failed" status

**Check**:
1. Review Error Message field in Alert Log
2. Common errors:
   - "Failed to send HTTP request" → Check URL is complete
   - "HTTP 401" → Check API key or IP whitelist
   - "HTTP 404" → Check Logic Apps URL is correct
3. Test Logic Apps URL with Postman

### Issue: Logic Apps receives request but Google Sheets not updated

**Check**:
1. Azure Portal → Logic Apps → Run history
2. Find the failed run
3. Review error details
4. Common causes:
   - Google Sheets column headers don't match (case-sensitive!)
   - Google authentication expired → Re-authenticate
   - Worksheet deleted or renamed → Update Logic Apps action

### Issue: Too many alerts for same item

**Check**:
- Is inventory being adjusted multiple times?
- Review threshold logic: Alerts only when crossing from above to below
- Check Alert Log for pattern
- Verify `CalculateInventoryAtPoint` is working correctly

---

## Next Steps

After successful setup:

1. **Monitor** Alert Log for first few days
2. **Adjust** safety stock levels based on actual usage
3. **Expand** JSON payload to include additional fields (optional)
4. **Consider** additional integrations:
   - Email notifications instead of/in addition to Google Sheets
   - SMS alerts via Twilio
   - Power BI dashboard
5. **Document** your specific business processes
6. **Train** warehouse staff on new system

---

## Support

### Business Central Issues
- Check ALProject10 GitHub Issues
- Review TROUBLESHOOTING.md

### Azure Logic Apps Issues
- Azure Portal → Logic Apps → Run history
- Azure Support if needed

### Google Sheets Issues
- Verify permissions
- Check Google Workspace status

---

## Configuration Checklist

Use this checklist to verify complete setup:

- [ ] Extension installed in BC
- [ ] Manufacturing Setup opened
- [ ] At least one item has Safety Stock > 0
- [ ] Azure Logic App created
- [ ] HTTP trigger configured with JSON schema
- [ ] Google Sheets spreadsheet created
- [ ] Row 1 headers added: ItemNo, Description, CurrentInventory
- [ ] Google Sheets action configured in Logic Apps
- [ ] Logic Apps URL copied (complete)
- [ ] URL pasted in BC Manufacturing Setup
- [ ] Enable Inventory Alerts checked
- [ ] Test posting performed
- [ ] Alert appeared in Google Sheets
- [ ] Alert Log shows Success status
- [ ] Debug messages removed (production)
- [ ] Version number updated
- [ ] Git tag created
- [ ] User documentation provided

---

Congratulations! Your Low Inventory Alert system is now fully operational. 🎉
