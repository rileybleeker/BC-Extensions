# Run Tests in Business Central

Execute test codeunits against the deployed extension.

## Instructions

1. **Ensure extension is deployed** first (use `/deploy` if needed)

2. **Run the test script**:
   ```powershell
   .\scripts\run-tests.ps1
   ```

3. **Review test results** for:
   - Passed tests
   - Failed tests with error details
   - Code coverage (if enabled)

## Test Structure

Tests in this project are located in:
- `src/Testing/` - Shared test utilities and data generators
- Individual feature folders may contain feature-specific tests

### Test Data Generator
Use `TestDataGeneratorCodeunit.al` to create test data:
- Access via page "Test Data Generator"
- Generates sample items, vendors, orders for testing

## Writing New Tests

### Test Codeunit Template
```al
codeunit 50XXX "{Feature} Tests"
{
    Subtype = Test;
    TestPermissions = Disabled;

    [Test]
    procedure TestFeatureBehavior()
    var
        // Arrange
        FeatureRec: Record "{Feature}";
    begin
        // Act
        // ... perform action

        // Assert
        Assert.IsTrue(condition, 'Expected condition to be true');
    end;

    var
        Assert: Codeunit Assert;
        LibraryRandom: Codeunit "Library - Random";
}
```

### Test Naming Convention
- Test procedures: `Test{WhatIsBeingTested}`
- Example: `TestVendorScoreCalculation`
- Example: `TestPlanningParameterSuggestionCreation`

## Running Specific Tests

To run a specific test codeunit:
```powershell
.\scripts\run-tests.ps1 -CodeunitId 50XXX
```

To run tests matching a filter:
```powershell
.\scripts\run-tests.ps1 -TestFilter "Vendor*"
```

## Common Test Scenarios

### Testing Table Logic
1. Create record with test data
2. Call trigger or procedure
3. Verify field values

### Testing Codeunit Logic
1. Set up prerequisite data
2. Call the codeunit procedure
3. Verify outcomes and side effects

### Testing Page Actions
1. Open page with test record
2. Invoke action
3. Verify record changes

## Debugging Failed Tests

1. Check error message for specific failure
2. Add temporary Message() calls to trace execution
3. Use debugger with breakpoints if needed
4. Verify test data setup is correct

## Test Coverage

Aim for coverage of:
- [ ] All table triggers (OnInsert, OnModify, OnDelete)
- [ ] All public codeunit procedures
- [ ] Critical business logic paths
- [ ] Edge cases and error conditions
