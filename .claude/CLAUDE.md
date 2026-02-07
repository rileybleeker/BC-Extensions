# D365 Business Central AL Extension Project

## Project Overview
This is a Business Central extension providing manufacturing, quality management, vendor performance, and planning optimization features.

- **App ID**: 8d64751e-59a6-4001-ace2-04c6530c0e86
- **Publisher**: RB
- **Runtime**: 16.0 (BC 27.x)
- **ID Range**: 50100-50199

## Project Structure
```
src/
├── Configuration/       # Setup tables and pages
├── CSVImport/          # CSV import functionality
├── InventoryAlerts/    # Low inventory alerts
├── Permissions/        # Permission sets
├── PlanningParameters/ # Planning parameter suggestions
├── ProductionOrder/    # Production order extensions
├── PurchaseSuggestion/ # Purchase suggestion workflow
├── QualityManagement/  # Quality orders and testing
├── Testing/            # Test data generators
├── VendorNonConformance/ # NCR management
└── VendorPerformance/  # Vendor scoring and tracking
```

## AL Coding Patterns

### Object Naming
- Tables: `{Feature}{Purpose}Table.al` → e.g., `VendorPerformanceTable.al`
- Pages: `{Feature}{Purpose}Page.al` → e.g., `VendorPerformanceListPage.al`
- Codeunits: `{Feature}{Purpose}Codeunit.al` → e.g., `VendorPerformanceCalculatorCodeunit.al`
- Enums: `{Feature}{Purpose}Enum.al` → e.g., `VendorRiskLevelEnum.al`
- Extensions: `{BaseObject}{Purpose}Ext.al` → e.g., `VendorTableExt.al`

### Table Patterns
```al
table 50XXX "Feature Name"
{
    Caption = 'Feature Name';
    DataClassification = CustomerContent;
    LookupPageId = "Feature Name List";
    DrillDownPageId = "Feature Name List";

    fields
    {
        field(1; "Primary Key"; Code[20])  // PKs start at 1
        field(10; "Group 1 Field"; Type)   // Group fields by 10s
        field(20; "Group 2 Field"; Type)
    }

    keys
    {
        key(PK; "Primary Key") { Clustered = true; }
    }
}
```

### Field Numbering Convention
- 1-9: Primary key fields
- 10-19: First logical group (e.g., delivery metrics)
- 20-29: Second logical group (e.g., lead time metrics)
- 30-39: Third logical group (e.g., quality metrics)
- Continue in groups of 10

### Required Field Properties
- All fields must have `Caption`
- Non-editable calculated fields: `Editable = false`
- Percentage fields: `MinValue = 0; MaxValue = 100; DecimalPlaces = 2 : 2`
- Quantity fields: `DecimalPlaces = 0 : 5`

### Enum Usage
Always use Enums instead of Options for new fields:
```al
field(30; Status; Enum "Planning Suggestion Status")
```

## Deployment

### Environment
- Environment Type: Sandbox
- Environment Name: DEVRB
- Tenant: Configured in launch.json (not committed)

### Deploy Commands
```powershell
# Build and deploy
.\scripts\deploy.ps1

# Run tests
.\scripts\run-tests.ps1

# Full publish
.\scripts\publish.ps1
```

## Feature Development Workflow

1. **Create feature folder**: `src/{FeatureName}/`
2. **Create objects in order**:
   - Enums (if needed)
   - Tables
   - Pages (List, Card, Factbox)
   - Codeunits
   - Extensions (to base objects)
3. **Add permissions**: Update permission sets in `src/Permissions/`
4. **Deploy and test**: Use `/deploy` command

## Common Tasks for Claude

### Adding a New Feature
Use `/new-feature` command or manually:
1. Create folder under `src/`
2. Allocate object IDs from available range
3. Follow naming conventions above
4. Add appropriate permissions

### Extending Base Objects
- Use `tableextension` / `pageextension` with ID in 50100-50199 range
- Name files with `Ext` suffix
- Keep extensions minimal and focused

### ID Allocation (Current Usage)
- 50100-50109: Planning Parameters
- 50110-50119: Planning Suggestions
- 50120-50129: Vendor Performance
- 50130-50139: Vendor NCR
- 50140-50149: Purchase Suggestions
- 50150+: Available for new features

## Testing
- Test codeunits go in `src/Testing/` or within feature folders
- Use `TestDataGeneratorCodeunit.al` for test data setup
- Run tests via AL Test Runner or `/test` command
