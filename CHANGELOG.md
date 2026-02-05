# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### To Do
- Expand JSON payload to include all 13 fields (Location, Vendor, Timestamp, etc.)
- Add configuration option for debug mode
- Create production-ready branch
- Test Reordering Policy mapping (VT-008)

## [1.2.0] - 2026-02-04

### Added

#### Feature 6: Planning Parameter Suggestions
- **Purpose**: Automated demand analysis and planning parameter optimization for Items and SKUs
- **Tables**:
  - Table (50110): Planning Parameter Suggestion - stores calculated suggestions with status tracking
  - Table (50111): Demand History Staging - temporary table for demand data analysis
  - Table (50112): Item Planning Extension - extends Item table for planning features
  - Table (50113): Planning Analysis Setup - configuration for analysis parameters and thresholds
- **Pages**:
  - Page (50110): Planning Analysis Setup - configure analysis settings, service levels, costs
  - Page (50111): Planning Parameter Suggestions - list view with approve/reject/apply actions
  - Page (50112): Planning Suggestion Card - detailed view with calculation notes
  - Page (50113): Item Card Planning Extension - planning actions on Item Card
  - Page (50114): Reject Reason Dialog - capture rejection reasons
  - Page (50115): Test Data Generator - development/testing utility
- **Codeunits**:
  - Codeunit (50110): Planning Suggestion Manager
    - `GenerateSuggestionForItem` - creates suggestion for single item
    - `GenerateSuggestionsForAllLocations` - SKU-level suggestions for all locations
    - `ApproveSuggestion` / `RejectSuggestion` - workflow management
    - `ApplySuggestion` - applies parameters to Item or SKU
    - `ExpireOldSuggestions` - maintenance procedure
  - Codeunit (50111): Planning Parameter Calculator
    - `CalculateSuggestion` - main calculation orchestrator
    - `CalculateSafetyStock` - Z-score formula with MAE buffer
    - `CalculateReorderPoint` - lead time demand + safety stock
    - `CalculateEOQ` - Economic Order Quantity formula
    - `CalculateMaximumInventory` - with seasonal adjustment
    - `CalculateLotAccumPeriod` - based on ordering frequency
    - `BuildCalculationNotes` - audit trail with formulas
  - Codeunit (50112): Planning Data Collector
    - `CollectDemandHistory` - gathers Item Ledger Entry data
    - `CalculateStatistics` - calendar-day average and standard deviation
  - Codeunit (50113): Planning SKU Management
    - `CreateOrUpdateSKU` - automatic SKU creation when applying suggestions
- **Enumerations**:
  - Enum (50110): Item Demand Pattern - Stable, Seasonal, Intermittent, New
  - Enum (50111): Planning Suggestion Status - Pending, Approved, Rejected, Applied, Expired, Failed
  - Enum (50112): Demand Source Type - Sale, Transfer, Production Consumption, Other
- **Permission Sets**:
  - PermissionSet (50110): Planning Suggest Admin - full access
  - PermissionSet (50111): Planning Suggest View - read-only access

### Validated Calculations (VT-001 through VT-007)
All core calculations have been validated against live Business Central data:

- **VT-001: Average Daily Demand** ✓
  - Formula: `TotalDemand / CalendarDays`
  - Uses actual calendar days, not demand-days, for accurate intermittent demand handling

- **VT-002: Standard Deviation** ✓
  - Calendar-day method including zero-demand days
  - Critical for accurate safety stock with intermittent demand

- **VT-003: Safety Stock** ✓
  - Formula: `(Z × σ × √(L + R)) + (MAE × Z)`
  - Z-score from service level (95% → 1.65)
  - Includes forecast error buffer (MAE)

- **VT-004: Reorder Point** ✓
  - Formula: `(AvgDailyDemand × LeadTime) + SafetyStock`
  - Lead time from Item/SKU Lead Time Calculation field

- **VT-005: Reorder Quantity (EOQ)** ✓
  - Formula: `√((2 × D × S) / H)`
  - Uses Setup.Default Order Cost and Setup.Holding Cost Rate

- **VT-006: Maximum Inventory** ✓
  - Formula: `ReorderPoint + ReorderQuantity`
  - Seasonal adjustment: `× PeakSeasonMultiplier` when pattern is Seasonal

- **VT-007: Lot Accumulation Period** ✓
  - Based on: `365 / OrdersPerYear`
  - Maps to DateFormula: ≤7d→1W, ≤14d→2W, ≤30d→1M, >30d→2M

### Configuration Options
- **Planning Analysis Setup** page includes:
  - Default Analysis Months (3-60)
  - Minimum Data Points (10-365)
  - Service Level Target (80-99.9%)
  - Safety Stock Multiplier (auto-calculated Z-score)
  - Lead Time Days Default
  - Holding Cost Rate
  - Default Order Cost
  - Peak Season Multiplier (1.0-2.0)
  - Auto-Apply Threshold
  - Require Approval Below threshold
  - Batch Size for processing

### SKU-Level Support
- Suggestions can target Item or Stockkeeping Unit level
- Location-specific demand history analysis
- Automatic SKU creation when applying suggestions
- SKU values override Item values when both exist

### Business Value
- Eliminates manual planning parameter calculations
- Data-driven inventory optimization
- Supports location-specific inventory policies
- Audit trail with detailed calculation notes
- Confidence scoring for approval workflow

## [1.1.0] - 2026-02-02

### Added

#### Feature 5: CSV Sales Order Import
- **Purpose**: Streamlined bulk order creation from CSV files with automatic Item creation
- **Table** (50102): CSV Import Buffer
  - Temporary table for staging CSV data
  - Fields: Line No., Color (Text[50]), Size (Text[50]), Quantity (Decimal), Item No. (Code[20]), Validation Error (Text[250])
  - Used for all-or-nothing validation before creating records
- **Page** (50102): CSV Sales Order Import
  - Card page with instructions and file upload action
  - "Select CSV File and Import" action triggers import process
  - "Manufacturing Setup" action for quick access to configuration
  - Multi-line instruction label explaining CSV format
- **Codeunit** (50104): CSV Sales Order Import
  - `ImportFromFile` - Main entry point, orchestrates the import process
  - `ParseCSV` - Manual line-by-line CSV parsing using InStream.ReadText
  - `ParseCSVLine` - Extracts Color, Size, Quantity from individual CSV lines
  - `ValidateData` - Pre-validates all buffer records before creating anything
  - `CreateSalesOrder` - Creates Sales Header and loops through buffer
  - `CreateSalesLine` - Creates individual Sales Lines with proper validation
  - `CreateBasicItem` - Creates Items with No. and Description, applies Item Template
  - `OpenSalesOrder` - Opens created Sales Order in UI
  - All-or-nothing transaction safety with rollback on error
- **XMLport** (50100): CSV Sales Order Import
  - VariableText format with FieldSeparator = ','
  - Legacy parser - not used in production (manual parsing more reliable)
  - Kept for reference and potential future use
- **Manufacturing Setup Extensions**:
  - Field (50106): CSV Import Customer No. (Code[20], TableRelation = Customer)
  - Field (50107): CSV Item Template Code (Code[20], TableRelation = Config. Template Header)
  - UI fields added to Manufacturing Setup Page in "CSV Sales Order Import Settings" group
- **CSV Format**:
  - Header row required: Color,Size,Quantity
  - Example: Red,M,10
  - Must have proper CRLF line endings (create in Excel, not Notepad)
  - UTF-8 encoding supported
- **Item Creation Logic**:
  - Item No. = Color + Size (e.g., "REDM" for Red + M)
  - Description = "Color Size" (e.g., "Red M")
  - Applies configured Item Template for required fields (Gen. Prod. Posting Group, Base Unit of Measure, etc.)
  - Commit after Item.Insert before applying template (ensures Item exists for template's related records)
  - Item.Modify after template application to save template changes
- **Sales Order Creation**:
  - Uses default customer from Manufacturing Setup
  - Creates Sales Header with Document Type = Order
  - Creates Sales Lines for each CSV row
  - Explicit validation of Unit of Measure Code from Item's Base Unit of Measure
  - Validation sequence: Type → No. → Unit of Measure Code → Quantity
- **User Experience**:
  - Confirmation dialog after successful import
  - Option to immediately open created Sales Order
  - Clear error messages for validation failures
  - No partial imports - all-or-nothing validation
- **Business Value**: Eliminates manual data entry, reduces errors, speeds up bulk order processing

### Changed
- Updated Manufacturing Setup Page to include CSV import configuration fields
- Updated Manufacturing Setup Table Extension with two new fields for CSV import

### Fixed
- CSV parsing now uses manual InStream.ReadText instead of XMLport for reliability
- Item Unit of Measure validation error fixed with Commit() before template application
- Unit of Measure Code explicitly validated to ensure proper population on Sales Lines
- Item Template changes properly saved with Item.Modify(true) after template application

### Technical Implementation
- **Manual CSV Parsing**: Abandoned XMLport approach due to UTF-8 BOM and line ending issues
- **Validation Pattern**: All data validated before any database changes
- **Item Template Application**: Uses ConfigTemplateMgt.UpdateRecord with RecordRef pattern
- **Transaction Safety**: Commit() strategically placed to handle template's related record creation
- **Error Handling**: Clear validation messages with line numbers for CSV errors

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
| 1.2.0 | 2026-02-04 | Added Planning Parameter Suggestions with validated calculations |
| 1.1.0 | 2026-02-02 | Added CSV Sales Order Import feature with automatic Item creation |
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
