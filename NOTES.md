# Development Notes - ALProject10

## Project Overview
Personal notes and insights from building Business Central extensions for manufacturing operations, quality management, and inventory alerting.

## Development Journey

### Phase 0: Foundation - Upper Tolerance & Date Synchronization
**Goal**: Prevent over-production and eliminate reservation date conflicts

These were the foundational features built before the Quality Management and Low Inventory Alert systems.

#### Part A: Production Order Upper Tolerance Management

**Business Problem**: Production orders sometimes result in over-production, wasting materials and exceeding customer orders.

**Solution Design**:
1. Add configurable tolerance percentage in Manufacturing Setup
2. Auto-calculate upper tolerance on production order lines
3. Validate output posting against upper tolerance
4. Block posting if it would exceed the limit

**Implementation Details**:

**Table Extension** - Production Order Line (Tab-Ext50100.ProdOrderLine.al):
```al
field(50101; "Upper Tolerance"; Decimal)
{
    Caption = 'Upper Tolerance';
    Editable = false;
}

modify(Quantity)
{
    trigger OnAfterValidate()
    begin
        CalculateUpperTolerance();
    end;
}

local procedure CalculateUpperTolerance()
begin
    if MfgSetup.Get() then
        Rec."Upper Tolerance" := Rec.Quantity * MfgSetup."Upper Tolerance";
end;
```

**Key Design Decision**: Make Upper Tolerance read-only and auto-calculated. This ensures consistency and prevents manual errors.

**Validation Logic** - Upper Tolerance Validation Codeunit (Codeunit 50100):
- Two event subscribers for redundancy:
  1. `OnBeforeInsertCapLedgEntry` - Validates capacity ledger entry
  2. `OnAfterInitItemLedgEntry` - Validates item ledger entry
- Both check: `NewFinishedQty > UpperTolerance`
- Block posting with descriptive error message

**Example**:
- Order Quantity: 1000 units
- Manufacturing Setup Upper Tolerance: 0.05 (5%)
- Calculated Upper Tolerance: 1050 units
- If user tries to post output that would bring Finished Qty to 1051 → Error

**Technical Insight**: We validate at TWO different events because Business Central's posting routine can take different paths depending on how output is posted (Output Journal vs. Production Journal). This ensures comprehensive coverage.

**Lesson Learned**: Always include the Production Order No. and Line No. in error messages. Users need context to understand which order is affected.

---

#### Part B: Reservation Date Synchronization

**Business Problem**: Users frequently encountered this error when adjusting production schedules:
> "This change leads to a date conflict with existing reservations..."

**Root Cause Analysis**:
When a Production Order Line is linked to a Sales Line via Reservation Entry:
1. Sales Line has Shipment Date = Jan 1
2. Prod Order Line has Ending Date-Time = Jan 1
3. Reservation Entry stores both dates
4. User changes Prod Order Ending Date to Jan 5
5. BC validates and finds date mismatch → **Error**

The problem: BC doesn't automatically update the Sales Line Shipment Date to match.

**Solution Strategy**:
Before BC validates the date change, automatically update the linked Sales Line's Shipment Date to match. This keeps everything in sync and prevents the error.

**Implementation** - Reservation Date Sync Codeunit (Codeunit 50101):

**Core Logic Flow**:
```
1. Find Reservation Entries for Production Order Line
2. For each Reservation Entry:
   a. Find the linked Sales Line
   b. Update Sales Line Shipment Date = Prod Order Ending Date
   c. BC automatically updates Reservation Entry dates
3. Now when user's date change validates, everything matches
```

**Key Procedure** - `SyncShipmentDateFromProdOrder`:
```al
// Find reservation entries for the production order line
ReservationEntry.SetRange("Source Type", Database::"Prod. Order Line");
ReservationEntry.SetRange("Source ID", ProdOrderLine."Prod. Order No.");

if ReservationEntry.FindSet() then
    repeat
        // Find the linked sales line
        if FindLinkedSalesLine(ReservationEntry, SalesLine) then begin
            // Update the Shipment Date
            if SalesLine."Shipment Date" <> DT2Date(ProdOrderLine."Ending Date-Time") then begin
                SalesLine.Validate("Shipment Date", DT2Date(ProdOrderLine."Ending Date-Time"));
                SalesLine.Modify(true);
            end;
        end;
    until ReservationEntry.Next() = 0;
```

**Technical Challenge**: Reservation Entries have complex linking structure:
- One reservation entry for production order (Source Type = Prod. Order Line)
- One reservation entry for sales order (Source Type = Sales Line)
- They're linked by Entry No. and opposite Positive flags

**Finding the Linked Sales Line**:
```al
// Find the corresponding reservation entry with opposite Positive flag
ToReservEntry.SetRange("Entry No.", FromReservEntry."Entry No.");
ToReservEntry.SetRange("Positive", not FromReservEntry."Positive");
ToReservEntry.SetRange("Source Type", Database::"Sales Line");

if ToReservEntry.FindFirst() then begin
    // Now get the actual Sales Line record
    SalesLine.SetRange("Document Type", Order);
    SalesLine.SetRange("Document No.", ToReservEntry."Source ID");
    SalesLine.SetRange("Line No.", ToReservEntry."Source Ref. No.");
    exit(SalesLine.FindFirst());
end;
```

**Event Subscriber Integration** - Production Order Line Extension:

**Critical Discovery**: We need to run the sync **twice**:

1. **OnBeforeValidate** - Before BC validates the date change
   - Prevents the date conflict error

2. **OnAfterValidate** - After BC's validation completes
   - BC's validation mysteriously changes the date again (to one day earlier!)
   - We need to sync again to fix this

```al
modify("Ending Date-Time")
{
    trigger OnBeforeValidate()
    var
        ReservDateSync: Codeunit "Reservation Date Sync";
    begin
        ReservDateSync.SyncShipmentDateFromProdOrder(Rec);
    end;

    trigger OnAfterValidate()
    var
        ReservDateSync: Codeunit "Reservation Date Sync";
    begin
        ReservDateSync.SyncShipmentDateFromProdOrder(Rec);
    end;
}
```

**Why This Works**:
- Before validation: We sync dates, so BC's validation finds no conflict
- After validation: We sync again to handle BC's date adjustment quirk

**Lesson Learned**: Business Central's date/time handling in production orders has subtle behaviors. When users select a date in the UI, BC sometimes adjusts it during validation (related to working days, location calendar, etc.). Always test both before and after validation triggers.

**Business Impact**:
- Users can now freely adjust production schedules
- No more frustrating date conflict errors
- Sales and production dates stay synchronized automatically
- Eliminates need for manual reservation deletion and recreation

**Additional Feature** - Bulk Sync Procedure:
```al
procedure SyncAllProdOrderLines()
```
This allows administrators to sync all production orders at once (useful after implementation or data migration).

---

### Phase 1: Quality Management Enhancement
**Goal**: Prevent selection of non-passed lots before posting

**Challenge**: Initial implementation only validated at posting time, which was too late. Users could enter invalid lot numbers and only find out when posting failed.

**Solution**: Added three-layer validation:
1. **Tracking Specification event** - Validates immediately when user enters lot number
2. **Reservation Entry event** - Safety net for reservation-based flows
3. **Item Ledger Entry event** - Final validation before posting

**Key Learning**: The `xRec` parameter is critical! Without checking `(Rec."Lot No." <> xRec."Lot No.")`, validation fires every time the field is touched, even when just clicking into it. This caused annoying error popups.

**Code Pattern**:
```al
if (Rec."Lot No." <> '') and (Rec."Lot No." <> xRec."Lot No.") and (Rec."Quantity (Base)" < 0) then
    ValidateLotQualityStatus(Rec."Item No.", Rec."Lot No.");
```

---

### Phase 2: Low Inventory Alert Integration
**Goal**: Real-time alerts to Google Sheets when inventory drops below safety stock

**Architecture Decision**: Push model (BC → Azure → Google) vs. Pull model (Azure polls BC)
- Chose **push** because we need real-time alerts on threshold crossing
- Event-driven is better than polling for this use case
- BC as HTTP client, not server (no API needed in BC)

**Challenges & Solutions**:

#### Challenge 1: Threshold Detection
**Problem**: How to alert only when FIRST crossing below safety stock, not every time inventory is below?

**Solution**: Calculate inventory before AND after posting:
```al
InventoryBeforePosting := CalculateInventoryAtPoint(ItemNo, Location, EntryNo - 1);
InventoryAfterPosting := InventoryBeforePosting + ItemLedgerEntry.Quantity;

if (Before > SafetyStock) and (After <= SafetyStock) then
    SendAlert(); // Only fires when crossing the threshold
```

**Why this works**: We're detecting the transition, not the state.

#### Challenge 2: Content-Type Header Issues
**Problem**: Azure Logic Apps returned error: "The media type 'text/plain' is not supported"

**Root Cause**: HttpContent.GetHeaders() and Headers.Add() were conflicting, leaving default content type.

**Solution**: Remove existing Content-Type before adding new one:
```al
Content.GetHeaders(Headers);
if Headers.Contains('Content-Type') then
    Headers.Remove('Content-Type');
Headers.Add('Content-Type', 'application/json');
```

#### Challenge 3: URL Truncation
**Problem**: HTTP 401 authentication errors from Azure Logic Apps

**Root Cause**: Logic Apps URL was 320 characters, but BC field was Text[250]. URL was silently truncated!

**Solution**: Increased field size to Text[500] and re-entered complete URL

**Lesson**: Always validate field sizes against actual data. Business Central won't error on truncation—it just silently cuts the string.

#### Challenge 4: Location Code Not Populating in Log
**Problem**: Alert Log showed Item No. and alerts worked, but Location Code was blank

**Root Cause**: We were passing `ItemLedgerEntry."Entry No."` to logging functions but only storing the Entry No., not fetching the full record.

**Solution**: Query Item Ledger Entry table in logging procedures:
```al
if ItemLedgEntry.Get(EntryNo) then begin
    AlertLog."Item No." := ItemLedgEntry."Item No.";
    AlertLog."Location Code" := ItemLedgEntry."Location Code";
end;
```

**Lesson**: Never assume related data is available without explicitly fetching it.

---

## Technical Insights

### Location-Aware Safety Stock
Business Central supports safety stock at two levels:
1. **Item level**: Item."Safety Stock Quantity"
2. **Location level**: Stockkeeping Unit."Safety Stock Quantity"

Our implementation prioritizes location-specific over item-level:
```al
// Try location-specific first
if StockkeepingUnit.Get(ItemNo, LocationCode) then
    exit(StockkeepingUnit."Safety Stock Quantity");

// Fallback to item level
if Item.Get(ItemNo) then
    exit(Item."Safety Stock Quantity");
```

This allows different warehouses to have different thresholds for the same item.

### Fire-and-Forget HTTP Pattern
Critical design decision: HTTP failures should NOT block inventory posting.

**Implementation**:
```al
if Client.Send(RequestMessage, ResponseMessage) then begin
    if ResponseMessage.IsSuccessStatusCode() then
        LogAlertSuccess(...)
    else
        LogAlertError(...);
end else
    LogAlertError(...);
// No Error() call - just log and continue
```

**Why**: Inventory transactions are mission-critical. A temporary API outage shouldn't prevent business operations.

### Inventory Calculation Strategy
We calculate current inventory by summing Item Ledger Entries rather than using Item."Inventory":

**Why**:
- Item."Inventory" is a FlowField (calculated from ledger)
- May not reflect exact state at the moment of posting
- Summing ledger entries up to specific Entry No. gives us point-in-time accuracy

**Performance Consideration**: This approach requires reading multiple ledger entries. For high-volume items, consider caching or optimizing the query.

---

## Debugging Tips

### Debug Messages Strategy
We added extensive Message() calls throughout the alert flow:
- Event subscriber entry point
- Each validation check (setup, URL, quantity)
- Safety stock retrieval
- Before/after inventory calculation
- Threshold crossing logic
- Alert send result

**When to remove**: Before production deployment!

**How to toggle**: Consider adding a "Debug Mode" field to Manufacturing Setup for production troubleshooting.

### Testing Threshold Crossing
**Setup**:
1. Item with Safety Stock = 100
2. Current Inventory = 105 (just above threshold)
3. Post negative adjustment of -10

**Expected**:
- Before = 105, After = 95
- Alert sent (crossed from 105 → 95, crossing 100)

**Not Expected to Alert**:
- If current inventory = 85 (already below)
- Posting -5 more
- Before = 85, After = 80
- No alert (didn't cross, already below)

### Common Issues

**Issue**: Event subscriber not firing
- Check: Is the codeunit compiled and published?
- Check: Are you posting through Item Journal (not direct SQL)?
- Verify: Check Item Ledger Entry table after posting

**Issue**: No alert sent but no error
- Check Manufacturing Setup configuration
- Verify "Enable Inventory Alerts" is checked
- Verify URL is not empty
- Check debug messages to see where it exits

**Issue**: Alert sent but not in Google Sheets
- Test with Postman to isolate BC vs. Azure issue
- Check Azure Logic Apps run history
- Verify Google Sheets column headers match JSON keys (case-sensitive!)

---

## Future Enhancements

### Expand JSON Payload
Currently sending 3 fields. Original design included:
- LocationCode, LocationName
- Timestamp, UserID
- VendorNo, VendorName, VendorContact
- UnitOfMeasure, ItemCategory

**To implement**: Update BuildAlertPayload() and Azure Logic Apps mapping.

### Remove Debug Messages
Create a production-ready version without Message() calls:
```al
// Option 1: Remove all Message() calls
// Option 2: Add "Debug Mode" field and wrap messages:
if MfgSetup."Debug Mode" then
    Message('DEBUG: ...');
```

### Add Email Notifications
Alternative or supplement to Google Sheets:
- Replace Google Sheets action with Office 365 Outlook connector
- Send formatted email to warehouse manager
- Include Item No., Description, Current Level, Safety Stock

### Create Purchase Order Integration
Two-way integration:
1. Alert goes to Google Sheets (✓ done)
2. User reviews and marks "Approve"
3. Logic Apps polls for approved rows
4. Calls BC API to create Purchase Order
5. Updates Google Sheet with PO number

**Requires**: Building Custom API in BC for PO creation

---

## Performance Considerations

### Event Subscriber Performance
The OnAfterInsertItemLedgEntry event fires for EVERY item ledger entry insert:
- Sales shipments
- Purchase receipts
- Production consumption
- Inventory adjustments

**Impact**: Minimal when exits are early:
- Most entries are positive (purchases/production) → exit immediately
- Safety stock = 0 for many items → exit early
- Already below threshold → no HTTP call

**If performance issues**:
- Add item category filter (only monitor specific item types)
- Consider batch processing instead of real-time
- Cache safety stock values

### Inventory Calculation Performance
CalculateInventoryAtPoint() sums all ledger entries for an item+location.

**Current**: O(n) where n = number of entries for item+location
**Impact**: Usually minimal (BC is optimized for ledger queries)

**If issues arise**:
- Add index on (Item No., Location Code, Entry No.)
- Use Item."Inventory" FlowField instead (less accurate)
- Cache calculations with TTL

---

## Azure Logic Apps Configuration

### Current Setup
1. HTTP Trigger (When an HTTP request is received)
2. Google Sheets connector (Insert row)
3. Response (200 OK)

### Authentication
- No authentication currently required
- Optional: Add API key header in BC setup
- Logic Apps can validate: x-api-key header

### Error Handling
Logic Apps should be configured for retries:
- Retry policy: Exponential
- Maximum attempts: 4
- Interval: 5 seconds

**Why**: Google Sheets API has rate limits; retries handle temporary failures.

---

## Git & GitHub Workflow

### Branching Strategy
Recommended for future development:
```
main (production-ready)
  └─ dev (active development)
      ├─ feature/expand-payload
      ├─ feature/email-alerts
      └─ feature/po-integration
```

### Commit Messages
Follow conventional commits:
```
feat: Add email notification support
fix: Resolve location code not populating in alert log
docs: Update README with testing procedures
refactor: Extract safety stock logic to separate procedure
```

### Release Process
1. Develop in `feature/` branch
2. Merge to `dev` and test in Dev environment
3. Merge to `main` when stable
4. Create git tag: `git tag v1.0.0`
5. Publish to production BC environment
6. Update CHANGELOG.md

---

## Lessons Learned

### AL Development
1. **Event subscribers are powerful** but fire frequently—always optimize early exits
2. **xRec parameter** prevents validation from firing on every field touch
3. **HTTP in AL is straightforward** but header management requires care
4. **Text field truncation is silent** in BC—always validate field sizes
5. **FlowFields vs. calculations** have different accuracy guarantees

### Integration Patterns
1. **Push > Pull for real-time events** like threshold crossing
2. **Fire-and-forget prevents blocking** critical business transactions
3. **Logging is essential** for troubleshooting integrations
4. **Test with Postman first** to isolate BC from Azure issues

### Azure Logic Apps
1. **HTTP triggers are simple** but consider authentication
2. **Google Sheets connector** is case-sensitive for column names
3. **Run history is invaluable** for debugging
4. **Keep Logic Apps simple** - complex logic should be in BC

### Project Management
1. **Debug messages during development**, remove for production
2. **Document as you go** (like these notes!)
3. **Test edge cases**: already below threshold, safety stock = 0, etc.
4. **Version control from day one** - wish I'd started sooner!

---

## Contact & Collaboration

**Author**: Riley
**Email**: rileybleeklm@gmail.com
**Date Started**: January 2026
**Status**: Active Development

**With help from**: Claude Sonnet 4.5 (AI pair programmer extraordinaire!)

---

## Useful Resources

### Business Central Development
- [AL Language Reference](https://learn.microsoft.com/en-us/dynamics365/business-central/dev-itpro/developer/devenv-reference-overview)
- [Event Subscribers](https://learn.microsoft.com/en-us/dynamics365/business-central/dev-itpro/developer/devenv-events-in-al)
- [HTTP Client](https://learn.microsoft.com/en-us/dynamics365/business-central/dev-itpro/developer/devenv-httpclient)

### Azure Integration
- [Logic Apps Documentation](https://learn.microsoft.com/en-us/azure/logic-apps/)
- [Google Sheets Connector](https://learn.microsoft.com/en-us/connectors/googlesheet/)

### Git & GitHub
- [Git Cheat Sheet](https://education.github.com/git-cheat-sheet-education.pdf)
- [GitHub Flow](https://guides.github.com/introduction/flow/)
