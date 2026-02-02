# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### To Do
- Remove debug messages from Low Inventory Alert Codeunit
- Expand JSON payload to include all 13 fields (Location, Vendor, Timestamp, etc.)
- Add configuration option for debug mode
- Create production-ready branch

## [1.0.0] - 2026-02-01

### Added

#### Feature 1: Production Order Upper Tolerance Management
- **Purpose**: Prevents over-production by enforcing configurable tolerance limits
- **Table Extension** (50101): Prod. Order Line Ext
  - New field: Upper Tolerance (Decimal, auto-calculated)
  - New field: Sync with DB (Boolean)
  - Quantity OnAfterValidate trigger to recalculate tolerance
  - Ending Date-Time modification triggers for date synchronization
- **Codeunit** (50100): Upper Tolerance Validation
  - Event subscriber: OnBeforeInsertCapLedgEntry
  - Event subscriber: OnAfterInitItemLedgEntry
  - Validates output posting against upper tolerance
  - Blocks posting with descriptive error if exceeded
- **Page Extensions** (50102, 50104): Prod. Order Line pages
  - Display Upper Tolerance field
  - Display Sync with DB field
- **Manufacturing Setup Extension**:
  - New field: Upper Tolerance (Decimal) - percentage for calculation
- **Formula**: `UpperTolerance = Quantity × MfgSetup."Upper Tolerance"`
- **Example**: Order Qty 1000 × 5% = 1050 max allowed
- **Business Value**: Reduces material waste, ensures order compliance

#### Feature 2: Reservation Date Synchronization
- **Purpose**: Eliminates "date conflict with existing reservations" errors
- **Codeunit** (50101): Reservation Date Sync
  - `SyncShipmentDateFromProdOrder` - Main synchronization procedure
  - `FindLinkedSalesLine` - Navigates Reservation Entry structure
  - `SyncAllProdOrderLines` - Bulk sync for all orders
- **Integration Points**:
  - Production Order Line Ending Date-Time OnBeforeValidate
  - Production Order Line Ending Date-Time OnAfterValidate
- **Logic Flow**:
  1. Find Reservation Entries for Production Order Line
  2. Navigate to linked Sales Line via Reservation Entry
  3. Update Sales Line Shipment Date to match Prod Order Ending Date
  4. Reservation Entry dates automatically update
- **Technical Innovation**: Runs sync twice (before & after validation) to handle BC's date recalculation quirk
- **Business Value**: Eliminates manual date maintenance, enables agile schedule adjustments

#### Feature 3: Quality Management System
- **Purpose**: Complete quality testing workflow with multi-layer lot validation
- **Table** (50100): Quality Order
  - Fields: Entry No., Item No., Lot No., Test Status (Enum), Item Ledger Entry No.
  - Tracking fields: Created Date, Tested Date, Tested By
  - OnValidate trigger: Auto-updates Tested Date/By when status changes
  - Keys: Primary (Entry No.), Secondary (Item No., Lot No.)
- **Enum** (50100): Quality Test Status
  - Values: Pending (0), Passed (1), Failed (2)
- **Page** (50100): Quality Orders
  - List view of all quality tests
  - Actions: Mark as Passed, Mark as Failed
  - Calls Quality Management codeunit procedures
- **Codeunit** (50100): Quality Management
  - `ValidateLotQualityStatus` - Shared validation logic
  - `MarkQualityOrderAsPassed` - Helper procedure
  - `MarkQualityOrderAsFailed` - Helper procedure
- **Multi-Layer Validation**:
  - Layer 1: Tracking Specification OnAfterValidateEvent (immediate validation)
  - Layer 2: Reservation Entry OnBeforeInsertEvent (reservation validation)
  - Layer 3: Item Ledger Entry OnBeforeInsertEvent (final posting validation)
- **Key Pattern**: xRec parameter check prevents validation on field touch
- **Business Value**: Prevents shipping defective products, provides audit trail

#### Feature 4: Low Inventory Alert Integration
- **Purpose**: Real-time inventory monitoring with Azure Logic Apps + Google Sheets
- **Table** (50101): Inventory Alert Log
  - Audit trail of all alert attempts
  - Fields: Entry No., Item Ledger Entry No., Item No., Location Code
  - Alert data: Current Inventory, Safety Stock, Alert Timestamp
  - Status tracking: Alert Status (Success/Failed), Error Message
  - Keys: Primary (Entry No.), Secondary (Item No., Location Code, Alert Timestamp)
- **Page** (50101): Inventory Alert Log
  - List view of alert history
  - Read-only display
  - Delete All action for maintenance
- **Codeunit** (50103): Low Inventory Alert
  - Event subscriber: OnAfterInsertItemLedgEntry
  - `CheckInventoryThresholdCrossing` - Threshold detection algorithm
  - `GetSafetyStockForLocation` - Location-aware safety stock retrieval
  - `CalculateInventoryAtPoint` - Point-in-time inventory calculation
  - `SendInventoryAlert` - HTTP POST to Azure Logic Apps
  - `BuildAlertPayload` - JSON payload construction
  - `LogAlertSuccess` / `LogAlertError` - Audit logging
- **Threshold Detection**: Only alerts when crossing from ABOVE to BELOW safety stock
- **Formula**: `(InventoryBefore > SafetyStock) AND (InventoryAfter ≤ SafetyStock)`
- **HTTP Integration**:
  - Fire-and-forget pattern (doesn't block posting)
  - Proper Content-Type header management
  - Optional API key authentication
- **Manufacturing Setup Extensions**:
  - Enable Inventory Alerts (Boolean)
  - Logic Apps Endpoint URL (Text[500])
  - Logic Apps API Key (Text[100], Masked)
- **Business Value**: Proactive reordering, prevents stockouts, centralized visibility

### Documentation Added
- **README.md**: Comprehensive overview of all 4 features with business value
- **NOTES.md**: Development notes, technical insights, lessons learned
- **CHANGELOG.md**: This version history
- **docs/ARCHITECTURE.md**: Detailed technical architecture and design decisions
- **docs/SETUP.md**: Complete setup guide for BC, Azure, and Google Sheets
- **docs/TESTING.md**: Test cases and procedures for all features
- **docs/TROUBLESHOOTING.md**: Common issues and solutions
- **.gitignore**: Proper exclusions for AL projects

### Technical Implementation
- Threshold crossing algorithm: Compares inventory before/after posting
- Inventory calculation: Sums Item Ledger Entries for point-in-time accuracy
- JSON payload builder: Currently 3 fields (ItemNo, Description, CurrentInventory)
- HTTP client with proper Content-Type header management
- Location-specific vs. item-level safety stock fallback logic

### Fixed
- Lot validation firing on field entry (added xRec parameter check)
- HTTP Content-Type header conflict (remove before adding)
- URL truncation in Manufacturing Setup (increased field size to Text[500])
- Location Code not populating in Alert Log (query Item Ledger Entry in logging procedures)

### Known Issues
- Debug messages still active (intended for development/testing phase)
- Simplified JSON payload (3 fields instead of planned 13)
- No retry logic in BC for failed HTTP calls (handled by Azure Logic Apps)

## [0.9.0] - 2026-01-30

### Added
- Initial project structure
- Basic codeunits and table extensions
- Quality Order table and page
- Upper Tolerance validation
- Production Order Line extensions

### Changed
- Migrated from legacy validation patterns to event-driven architecture

## Version History Summary

| Version | Date | Description |
|---------|------|-------------|
| 1.0.0 | 2026-02-01 | Initial release with Quality Management and Low Inventory Alert features |
| 0.9.0 | 2026-01-30 | Project foundation and initial objects |

---

## How to Update This File

When making changes to the project:

1. Add entries under `[Unreleased]` section as you develop
2. Use these categories:
   - `Added` for new features
   - `Changed` for changes in existing functionality
   - `Deprecated` for soon-to-be removed features
   - `Removed` for now removed features
   - `Fixed` for any bug fixes
   - `Security` for vulnerability fixes

3. When releasing a version:
   - Create a new version header (e.g., `## [1.1.0] - 2026-03-15`)
   - Move items from `[Unreleased]` to the new version
   - Update version number in `app.json`
   - Create git tag: `git tag v1.1.0`
   - Push tag to GitHub: `git push origin v1.1.0`

### Example Entry Format
```markdown
### Added
- Feature description with context
  - Implementation detail 1
  - Implementation detail 2
- Another feature

### Fixed
- Bug description and how it was resolved
```

---

## Next Version Planning

### v1.1.0 (Planned)
- Remove debug messages
- Expand JSON payload to 13 fields
- Add debug mode configuration option
- Performance optimization for high-volume items
- Email notification option

### v1.2.0 (Planned)
- Custom API for pull integration
- Power BI integration
- Enhanced logging with retention policies
- Batch alert processing option

### v2.0.0 (Future)
- Two-way integration (purchase order creation)
- SMS alert support via Twilio
- Predictive analytics (forecasting when inventory will hit safety stock)
- Multi-language support
