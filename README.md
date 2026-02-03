# ALProject10 - Business Central Manufacturing & Quality Extensions

Comprehensive Business Central AL extensions for manufacturing operations, quality management, and inventory monitoring.

## Features Overview

### 1. Production Order Upper Tolerance Management
Prevents over-production by enforcing upper tolerance limits on production orders.

**Files:**
- `Tab-Ext50100.ProdOrderLine.al` - Production Order Line extension
- `Upper Tolerance Validation Codeunit.al` - Output posting validation
- `Prod Order Line Sub Page.al` - UI extensions for production order pages
- `Manufacutring Setup Table.al` - Configuration storage

**Functionality:**
- Automatically calculates upper tolerance based on order quantity and percentage from Manufacturing Setup
- Validates output posting against upper tolerance before allowing post
- Prevents accidental over-production
- Displays upper tolerance on production order pages for visibility

**Business Value:**
- Reduces material waste from over-production
- Ensures compliance with customer order quantities
- Provides clear visibility of acceptable production limits

---

### 2. Reservation Date Synchronization
Automatically synchronizes dates between Production Orders and Sales Orders to prevent reservation date conflicts.

**Files:**
- `Reservation Date Sync Codeunit.al` - Date synchronization logic
- `Tab-Ext50100.ProdOrderLine.al` - Event triggers on Ending Date-Time changes

**Functionality:**
- Monitors changes to Production Order Line Ending Date-Time
- Automatically updates linked Sales Line Shipment Date
- Updates Reservation Entry dates to maintain consistency
- Prevents "date conflict with existing reservations" errors
- Runs on both OnBeforeValidate and OnAfterValidate to handle BC's date recalculation

**Business Value:**
- Eliminates manual date synchronization
- Prevents user frustration from reservation errors
- Maintains data integrity between production and sales
- Enables smooth production schedule adjustments

---

### 3. Quality Management System
Complete quality testing workflow for lot-tracked inventory with validation to prevent shipment of non-passed lots.

**Files:**
- `Quality Order Table.al` - Quality test records
- `Quality Orders Page.al` - Quality testing UI
- `Quality Test Status Enum.al` - Status enumeration (Pending/Passed/Failed)
- `Quality Management Codeunit.al` - Validation logic and helper procedures

**Functionality:**
- Create quality orders for incoming lot-tracked inventory
- Track test status: Pending, Passed, or Failed
- Record tested date and tested by user automatically
- **Multi-layer validation** prevents selection of non-passed lots:
  - **Immediate validation** when entering lot number in Item Tracking Lines
  - **Reservation validation** when creating reservations
  - **Posting validation** as final safety net before creating Item Ledger Entry
- Mark as Passed/Failed actions on Quality Orders page

**Business Value:**
- Ensures only quality-approved inventory is shipped
- Provides audit trail of quality testing
- Prevents costly mistakes from shipping defective products
- Improves customer satisfaction through quality control

---

### 4. CSV Sales Order Import
Streamlined import of CSV files to create Sales Orders with automatic Item creation.

**Files:**
- `CSV Import Buffer Table.al` - Temporary staging table
- `CSV Sales Order Import Codeunit.al` - Import logic and validation
- `CSV Sales Order Import Page.al` - User interface
- `CSV Sales Order Import XMLport.al` - CSV parsing (legacy, not used)
- `Manufacutring Setup Table.al` - Configuration fields
- `Manufacturing Setup Page.al` - Setup UI

**Functionality:**
- Upload CSV files with Color, Size, Quantity columns (with headers)
- Manual CSV parsing using InStream for reliable line-by-line processing
- All-or-nothing validation before creating any records
- Automatic Item creation using configured Item Template
- Item No. = Color + Size (e.g., "REDM" for Red + M)
- Sales Order creation with configured default customer
- Proper Unit of Measure validation from Item's Base Unit of Measure
- Option to open created Sales Order immediately after import

**Business Value:**
- Eliminates manual data entry for bulk orders
- Reduces errors from manual order creation
- Ensures consistent Item creation using templates
- Speeds up order processing workflow
- Provides immediate visibility into created orders

---

### 5. Low Inventory Alert Integration
Real-time inventory monitoring with threshold crossing detection, integrated with Azure Logic Apps and Google Sheets.

**Files:**
- `Low Inventory Alert Codeunit.al` - Main integration logic
- `Inventory Alert Log Table.al` - Alert audit trail
- `Inventory Alert Log Page.al` - Alert history UI
- `Manufacutring Setup Table.al` - Integration configuration
- `Manufacturing Setup Page.al` - Setup UI

**Functionality:**
- Monitors inventory levels in real-time during posting
- Detects threshold crossing (when inventory drops from ABOVE to BELOW safety stock)
- Location-aware: Uses Stockkeeping Unit safety stock if available, falls back to item level
- Sends HTTP POST to Azure Logic Apps with JSON payload
- Azure Logic Apps writes to Google Sheets for visibility
- **Fire-and-forget pattern**: HTTP failures don't block inventory posting
- Comprehensive logging of success/failure for troubleshooting

**Architecture:**
```
Business Central (Client)     Azure Logic Apps (Server)     Google Sheets
========================       =========================     =============
Item Posting Event
     |
     v
Threshold Detection ------HTTP POST------> HTTP Trigger
(Before/After calc)       (JSON)                |
                                                v
                                         Parse JSON
                                                |
                                                v
                                         Google Sheets ---------> Append Row
                                         Connector
```

**Business Value:**
- Real-time awareness of low inventory situations
- Proactive reordering reduces stockouts
- Centralized visibility in Google Sheets for team collaboration
- Prevents disruption to production from material shortages

---

## Configuration

### Manufacturing Setup
Navigate to **Manufacturing Setup** in Business Central:

#### Upper Tolerance
- **Field**: Upper Tolerance (Decimal)
- **Purpose**: Percentage to calculate acceptable over-production
- **Example**: Set to 0.05 for 5% over-production allowance

#### CSV Sales Order Import
- **CSV Import Customer No.**: Default customer for all imported orders (required)
- **CSV Item Template Code**: Item Template to apply when creating new items (required)

#### Low Inventory Alert Integration
- **Enable Inventory Alerts**: Toggle to enable/disable real-time alerts
- **Logic Apps Endpoint URL**: Azure Logic Apps HTTP trigger URL (500 chars)
- **Logic Apps API Key**: Optional API key for authentication (masked field)

### Safety Stock Configuration
Set thresholds for low inventory alerts:
- **Item level**: Item Card → Planning → Safety Stock Quantity
- **Location level**: Stockkeeping Unit → Safety Stock Quantity (takes precedence)

### Quality Management
No configuration required - automatically active after extension installation.

---

## Azure Logic Apps Setup

### Prerequisites
- Azure subscription
- Google account with Sheets access

### Setup Steps
1. Create Logic App in Azure Portal
2. Add **HTTP Trigger**: When an HTTP request is received
3. Configure JSON schema:
```json
{
  "ItemNo": "string",
  "Description": "string",
  "CurrentInventory": "number"
}
```
4. Add **Google Sheets** action: Insert row
5. Map fields to columns
6. Copy HTTP POST URL
7. Paste into BC Manufacturing Setup

For detailed setup instructions, see [docs/SETUP.md](docs/SETUP.md).

---

## Object IDs Reference

| Object Type | ID | Name | Purpose |
|-------------|-----|------|---------|
| **Enumerations** ||||
| Enum | 50100 | Quality Test Status | Pending/Passed/Failed statuses |
| **Tables** ||||
| Table | 50100 | Quality Order | Quality test records |
| Table | 50101 | Inventory Alert Log | Alert history tracking |
| Table | 50102 | CSV Import Buffer | Temporary CSV staging |
| **Table Extensions** ||||
| Table Extension | 50101 | Prod. Order Line Ext | Upper Tolerance, Sync with DB, date sync |
| Table Extension | 50102 | Manufacturing Setup Ext | Upper Tolerance %, Alert config |
| **Pages** ||||
| Page | 50100 | Quality Orders | Quality testing UI |
| Page | 50101 | Inventory Alert Log | Alert history view |
| Page | 50102 | CSV Sales Order Import | CSV import interface |
| **Page Extensions** ||||
| Page Extension | 50102 | Prod. Order Line Sub Ext | Shows Upper Tolerance field |
| Page Extension | 50103 | Manufacturing Setup Ext | Alert configuration UI |
| Page Extension | 50104 | Released Prod. Order Ext | Upper Tolerance on released orders |
| **Codeunits** ||||
| Codeunit | 50100 | Upper Tolerance Validation | Validates output posting |
| Codeunit | 50101 | Reservation Date Sync | Syncs prod/sales dates |
| Codeunit | 50102 | Quality Management | Lot validation logic |
| Codeunit | 50103 | Low Inventory Alert | Inventory monitoring & alerting |
| Codeunit | 50104 | CSV Sales Order Import | CSV parsing & order creation |
| **XMLports** ||||
| XMLport | 50100 | CSV Sales Order Import | Legacy CSV parser (not used) |

---

## Key Algorithms

### Upper Tolerance Calculation
```al
UpperTolerance := Quantity * MfgSetup."Upper Tolerance"
// Example: Order Qty 1000 * 5% = 1050 max allowed
```

### Threshold Crossing Detection
```al
InventoryBefore := SumLedgerEntries(UpToEntryNo - 1);
InventoryAfter := InventoryBefore + CurrentQuantity;

if (InventoryBefore > SafetyStock) and (InventoryAfter <= SafetyStock) then
    SendAlert(); // Only fires when crossing threshold
```

### Reservation Date Synchronization
```al
// Find Production Order → Reservation Entry → Sales Line
// Update Sales Line Shipment Date = Prod Order Ending Date
// Reservation Entry dates automatically update
```

---

## Testing

Basic smoke tests for each feature:

### Test 1: Upper Tolerance
1. Set Manufacturing Setup → Upper Tolerance = 0.05 (5%)
2. Create Prod. Order with Quantity = 100 (Upper Tolerance = 105)
3. Post Output of 106
4. Expected: Error preventing over-production

### Test 2: Reservation Date Sync
1. Create Sales Order with Shipment Date = Jan 1
2. Create Prod. Order linked to Sales Order with Ending Date = Jan 1
3. Change Prod. Order Ending Date to Jan 5
4. Expected: Sales Line Shipment Date automatically updates to Jan 5 (no error)

### Test 3: Quality Management
1. Create Quality Order with Lot = LOT-001, Status = Pending
2. Try to create Sales Order with LOT-001
3. Expected: Error preventing selection
4. Mark Quality Order as Passed
5. Now LOT-001 should be selectable

### Test 4: CSV Sales Order Import
1. Configure Manufacturing Setup → CSV Import Customer No. = 10000
2. Configure Manufacturing Setup → CSV Item Template Code = ITEM-TEMPLATE
3. Create CSV file in Excel:
   ```
   Color,Size,Quantity
   Red,M,10
   Blue,L,5
   ```
4. Open CSV Sales Order Import page → Select CSV File and Import
5. Expected: Sales Order created with 2 lines, Items REDM and BLUEL created

### Test 5: Low Inventory Alert
1. Item with Safety Stock = 100, Current Inventory = 105
2. Post negative adjustment of -10 (105 → 95)
3. Expected: Alert in Google Sheets, entry in Inventory Alert Log

For comprehensive test cases, see [docs/TESTING.md](docs/TESTING.md).

---

## Documentation

- **[NOTES.md](NOTES.md)** - Development notes, lessons learned, technical insights
- **[CHANGELOG.md](CHANGELOG.md)** - Version history and release notes
- **[docs/ARCHITECTURE.md](docs/ARCHITECTURE.md)** - Detailed technical architecture
- **[docs/SETUP.md](docs/SETUP.md)** - Complete setup instructions
- **[docs/TESTING.md](docs/TESTING.md)** - Test cases and procedures
- **[docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md)** - Common issues and solutions

---

## Version History

### Version 1.1.0 (2026-02-02)
- Added CSV Sales Order Import feature
- Automatic Item creation from CSV with Item Templates
- Manual CSV parsing for reliability
- All-or-nothing validation
- Option to open created order immediately

### Version 1.0.0 (2026-02-01)
- Initial release with four major features
- Production Order Upper Tolerance Management
- Reservation Date Synchronization
- Quality Management System with multi-layer validation
- Low Inventory Alert Integration with Azure Logic Apps

---

## Installation

### From VS Code (Development)
1. Open project in VS Code
2. Press `F5` to publish
3. Select BC environment

### From .app File (Production)
1. Build: `Alt+F6` in VS Code
2. BC → Extension Management → Upload Extension
3. Select `ALProject10.app`
4. Deploy → Install

### Post-Installation Configuration
1. Manufacturing Setup → Set Upper Tolerance percentage
2. Manufacturing Setup → Configure CSV Import Customer No. and Item Template
3. Manufacturing Setup → Configure Low Inventory Alert integration
4. Set Safety Stock on Items or Stockkeeping Units
5. Create Quality Orders for incoming inventory

---

## Business Impact

### Efficiency Gains
- Eliminates manual date synchronization between prod orders and sales orders
- Reduces time spent troubleshooting reservation date conflicts
- Automated quality validation prevents manual checking

### Cost Savings
- Reduces material waste from over-production (Upper Tolerance)
- Prevents costly errors from shipping defective products (Quality Management)
- Minimizes stockouts through proactive alerting (Low Inventory Alerts)

### Compliance & Quality
- Enforces quality control processes
- Provides audit trail of quality testing
- Ensures production stays within acceptable limits

### Visibility & Collaboration
- Google Sheets integration provides centralized inventory visibility
- Alert Log enables troubleshooting and analysis
- Quality Orders page gives clear status of lot testing

---

## Known Limitations

- CSV Import requires proper CRLF line endings (create CSV files in Excel, not Notepad)
- CSV Import Item No. limited to 20 characters (Color + Size combined)
- XMLport for CSV parsing exists but not used (manual parsing more reliable)
- JSON payload simplified to 3 fields in Low Inventory Alert (can be expanded to 13 fields)
- Sales Line Ext.al is commented out (legacy test code)
- No retry logic in BC for failed HTTP calls (handled by Azure Logic Apps)

---

## Future Enhancements

### Version 1.1.0 (Planned)
- Remove debug messages from production code
- Expand Low Inventory Alert JSON payload to include:
  - Location details
  - Vendor information
  - Timestamp and User ID
  - Unit of measure
  - Item category
- Add debug mode configuration option

### Version 2.0.0 (Future)
- Pull integration: BC Custom API for external systems to query inventory
- Two-way integration: Purchase order creation from alerts
- Predictive analytics: Forecast when inventory will hit safety stock
- SMS alerts via Twilio
- Power BI dashboard integration

---

## License

Proprietary - Internal Use Only

---

## Contributors

**Riley** - Primary Developer
Email: rileybleeklm@gmail.com

**With assistance from**: Claude Sonnet 4.5 (AI pair programmer)

---

## Support

- **GitHub Issues**: [Repository URL]
- **Documentation**: See `/docs` folder
- **Troubleshooting**: [docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md)

---

## Quick Start

1. **Install extension** in BC environment
2. **Configure Manufacturing Setup**:
   - Upper Tolerance: `0.05` (5%)
   - CSV Import Customer No.: `10000` (or your default customer)
   - CSV Item Template Code: `ITEM-TEMPLATE` (configure template first)
   - Enable Inventory Alerts: `☑`
   - Logic Apps URL: (from Azure)
3. **Set Safety Stock** on monitored items
4. **Create Quality Orders** for incoming lots
5. **Test each feature** using test cases above

For detailed instructions, see [docs/SETUP.md](docs/SETUP.md).

---

🎉 **You now have a complete manufacturing operations suite in Business Central!**
