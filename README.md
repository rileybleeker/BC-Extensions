# ALProject10 - Business Central Extensions

This repository contains custom Business Central AL extensions for quality management and inventory alerting.

## Features

### 1. Quality Management Enhancement
Validates lot quality status and prevents selection of non-passed lots during inventory transactions.

**Files:**
- `Quality Management Codeunit.al` - Event subscribers for lot validation

**Functionality:**
- Early validation when users enter lot numbers in Item Tracking Lines
- Prevents selection of Pending/Failed lots before posting
- Three-layer validation: Tracking Specification, Reservation Entry, and Item Ledger Entry

### 2. Low Inventory Alert Integration
Real-time integration with Azure Logic Apps and Google Sheets for inventory monitoring.

**Files:**
- `Low Inventory Alert Codeunit.al` - Main integration logic
- `Inventory Alert Log Table.al` - Audit table
- `Inventory Alert Log Page.al` - UI for viewing alert history
- `Manufacutring Setup Table.al` - Configuration fields
- `Manufacturing Setup Page.al` - Setup UI

**Functionality:**
- Monitors inventory levels in real-time
- Alerts when inventory crosses below safety stock threshold
- Location-specific safety stock support
- HTTP POST to Azure Logic Apps
- Integration with Google Sheets via Logic Apps
- Fire-and-forget pattern (doesn't block posting on HTTP failures)
- Comprehensive logging

**Architecture:**
```
Business Central (Client)     Azure Logic Apps (Server)     Google Sheets
==========================     =========================     =============
Item Posting Event
     |
     v
Threshold Detection ------HTTP POST------> HTTP Trigger
(Calculate Before/After)    (JSON)              |
                                                v
                                         Parse JSON
                                                |
                                                v
                                         Google Sheets ----> Append Row
                                         Connector
```

## Configuration

### Manufacturing Setup
Navigate to **Manufacturing Setup** and configure:

1. **Enable Inventory Alerts**: Toggle to enable/disable alerts
2. **Logic Apps Endpoint URL**: Azure Logic Apps HTTP trigger URL
3. **Logic Apps API Key**: Optional API key for authentication

### Safety Stock
Set safety stock thresholds at:
- **Item level**: Item Card → Planning tab → Safety Stock Quantity
- **Location level**: Stockkeeping Unit → Safety Stock Quantity (takes precedence)

## Azure Logic Apps Setup

1. Create Logic App in Azure Portal
2. Add HTTP Trigger (When an HTTP request is received)
3. Add Google Sheets action (Insert row)
4. Map JSON fields to columns:
   - ItemNo
   - Description
   - CurrentInventory
5. Copy HTTP POST URL to BC Manufacturing Setup

## Testing

Test threshold crossing:
1. Set Safety Stock = 100 for an item
2. Ensure Current Inventory = 105
3. Post negative adjustment of -10
4. Expected: Alert sent, row appears in Google Sheets
5. Verify: Check Inventory Alert Log in BC

## Known Limitations

- Currently sends 3 fields (ItemNo, Description, CurrentInventory)
- Can be expanded to include Location, Vendor, Timestamp, etc.
- Debug messages currently active in code

## Development Notes

### Threshold Detection Algorithm
Alerts only when inventory **crosses** from above to below safety stock:
```al
if (InventoryBeforePosting > SafetyStockQty) and (InventoryAfterPosting <= SafetyStockQty) then
    SendAlert();
```

This prevents duplicate alerts when inventory is already below threshold.

### Data Sources
- **ItemNo**: Item Ledger Entry (transaction record)
- **Description**: Item table (master data)
- **CurrentInventory**: Calculated by summing all Item Ledger Entries for Item+Location

## Object IDs

| Object Type | ID | Name |
|-------------|-----|------|
| Codeunit | 50100 | Quality Management |
| Codeunit | 50103 | Low Inventory Alert |
| Table | 50101 | Inventory Alert Log |
| Table Extension | 50102 | Manufacturing Setup Ext |
| Page | 50101 | Inventory Alert Log |
| Page Extension | 50103 | Manufacturing Setup Ext |

## Version History

### Version 1.0.0
- Initial release
- Quality Management lot validation
- Low Inventory Alert integration with Azure Logic Apps and Google Sheets

## License

Proprietary - Internal Use Only

## Author

Riley - 2026

## Support

For issues or questions, contact the development team.
