# New Feature Scaffolding

Create a new feature module for this Business Central extension.

## Instructions

When the user provides a feature name and description:

1. **Create the feature folder** under `src/{FeatureName}/`

2. **Determine required objects** based on the feature:
   - Enums for status/type fields
   - Main table(s) for data storage
   - List page for viewing records
   - Card page for editing individual records
   - Codeunit(s) for business logic
   - Extensions to existing BC objects if needed

3. **Allocate object IDs** from the available range:
   - Check CLAUDE.md for current ID usage
   - Allocate next available block of 10 IDs
   - Tables, Pages, Codeunits, Enums all share the same ID range

4. **Follow project patterns**:
   - Use naming conventions from CLAUDE.md
   - Include proper captions and tooltips
   - Set DataClassification = CustomerContent
   - Use Enums instead of Options
   - Group fields by 10s in tables

5. **Create files in this order**:
   ```
   src/{FeatureName}/
   ├── {Feature}StatusEnum.al      (if needed)
   ├── {Feature}Table.al           (main data table)
   ├── {Feature}ListPage.al        (list view)
   ├── {Feature}CardPage.al        (detail view)
   └── {Feature}Codeunit.al        (business logic)
   ```

6. **Update permissions** in `src/Permissions/` if needed

## Example Usage

User: "Create a feature for tracking machine maintenance schedules"

Response should include:
- Folder: `src/MachineMaintenance/`
- Objects with IDs 50150+ (or next available)
- Table for maintenance records
- Pages for viewing/editing
- Codeunit for scheduling logic

## Template: Basic Table

```al
table 50XXX "{Feature Name}"
{
    Caption = '{Feature Name}';
    DataClassification = CustomerContent;
    LookupPageId = "{Feature Name} List";
    DrillDownPageId = "{Feature Name} List";

    fields
    {
        field(1; "Entry No."; Integer)
        {
            Caption = 'Entry No.';
            AutoIncrement = true;
        }
        // Add feature-specific fields starting at 10
    }

    keys
    {
        key(PK; "Entry No.")
        {
            Clustered = true;
        }
    }

    trigger OnInsert()
    begin
        // Initialization logic
    end;
}
```

## Template: List Page

```al
page 50XXX "{Feature Name} List"
{
    PageType = List;
    ApplicationArea = All;
    UsageCategory = Lists;
    SourceTable = "{Feature Name}";
    Caption = '{Feature Name}';
    CardPageId = "{Feature Name} Card";
    Editable = false;

    layout
    {
        area(Content)
        {
            repeater(Group)
            {
                // Add fields here
            }
        }
    }

    actions
    {
        area(Processing)
        {
            // Add actions here
        }
    }
}
```
