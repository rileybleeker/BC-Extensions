# Development Notes - ALProject10

## Project Overview
Personal notes and insights from building Business Central extensions for quality management and inventory alerting.

## Development Journey

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
