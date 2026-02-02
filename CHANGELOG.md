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
- **Quality Management Enhancement**
  - Lot quality validation at point of entry in Item Tracking Lines
  - Event subscriber on Tracking Specification table (OnAfterValidateEvent)
  - Event subscriber on Reservation Entry table (OnBeforeInsertEvent)
  - Shared `ValidateLotQualityStatus` procedure
  - Prevents selection of Pending/Failed lots before posting
  - Three-layer validation strategy for comprehensive coverage

- **Low Inventory Alert Integration**
  - Real-time inventory monitoring with threshold crossing detection
  - Event subscriber on Item Jnl.-Post Line (OnAfterInsertItemLedgEntry)
  - HTTP POST integration with Azure Logic Apps
  - Google Sheets integration via Logic Apps connector
  - Location-aware safety stock support (Stockkeeping Unit priority)
  - Fire-and-forget HTTP pattern (doesn't block posting on failures)
  - Comprehensive alert logging system

- **Manufacturing Setup Extensions**
  - Table extension with three new fields:
    - Enable Inventory Alerts (Boolean)
    - Logic Apps Endpoint URL (Text[500])
    - Logic Apps API Key (Text[100], Masked)
  - Page extension with configuration UI
  - Conditional field enabling based on master toggle

- **Inventory Alert Log**
  - New table (50101) for tracking alert history
  - Fields: Entry No., Item Ledger Entry No., Item No., Location Code, Current Inventory, Safety Stock, Alert Timestamp, Alert Status, Error Message
  - List page (50101) for viewing alert history
  - Delete All action for log maintenance

- **Documentation**
  - Comprehensive README.md with architecture diagrams
  - Development notes (NOTES.md) with lessons learned
  - This CHANGELOG
  - Testing procedures and troubleshooting guides

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
