# Technical Architecture

## System Overview

ALProject10 consists of four integrated subsystems:
1. **Production Order Upper Tolerance Management** - Prevents over-production
2. **Reservation Date Synchronization** - Eliminates reservation date conflicts
3. **Quality Management** - Lot validation and testing workflow
4. **Low Inventory Alert** - Real-time inventory monitoring and alerting

These systems work together to provide comprehensive manufacturing operations management, quality control, and inventory visibility in Business Central.

---

## Complete System Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                    Business Central (On-Premise/Cloud)           │
│                                                                   │
│  ┌─────────────────────┐      ┌──────────────────────────────┐ │
│  │  Quality Management │      │  Low Inventory Alert System  │ │
│  │                     │      │                              │ │
│  │  Event Subscribers: │      │  Event Subscriber:           │ │
│  │  - Tracking Spec    │      │  - Item Ledger Entry Insert  │ │
│  │  - Reservation Entry│      │                              │ │
│  │  - Item Ledger Entry│      │  Components:                 │ │
│  │                     │      │  - Threshold Detection       │ │
│  │  Validation:        │      │  - Inventory Calculation     │ │
│  │  - Quality Order    │      │  - HTTP Client              │ │
│  │  - Test Status      │      │  - Alert Logging            │ │
│  └─────────────────────┘      └───────────┬──────────────────┘ │
│                                            │                     │
│                                            │ HTTP POST           │
│                                            │ (JSON)              │
└────────────────────────────────────────────┼─────────────────────┘
                                             │
                                             ▼
                              ┌──────────────────────────┐
                              │   Azure Logic Apps       │
                              │                          │
                              │  Triggers:               │
                              │  - HTTP Request          │
                              │                          │
                              │  Actions:                │
                              │  - Parse JSON            │
                              │  - Google Sheets Insert  │
                              │  - Response (200 OK)     │
                              └───────────┬──────────────┘
                                          │
                                          │ REST API
                                          │
                                          ▼
                              ┌──────────────────────────┐
                              │    Google Sheets         │
                              │                          │
                              │  Sheet: BC Inventory     │
                              │         Alerts           │
                              │                          │
                              │  Columns:                │
                              │  - Item No.              │
                              │  - Description           │
                              │  - Current Inventory     │
                              └──────────────────────────┘
```

---

## Quality Management Architecture

### Component Overview

```
User Action                Event Flow                    Validation
===========               ===========                    ==========

User enters        ┌────────────────────────┐
Lot No. in    ───► │ Tracking Specification │
Item Tracking      │ OnAfterValidateEvent   │ ───► ValidateLotQualityStatus()
Lines              └────────────────────────┘           │
                                                         │
                   ┌────────────────────────┐           │
System creates ──► │  Reservation Entry     │           │
reservation        │  OnBeforeInsertEvent   │ ───► ────┤
                   └────────────────────────┘           │
                                                         │
                   ┌────────────────────────┐           │
Posting        ──► │   Item Ledger Entry    │           │
transaction        │  OnBeforeInsertEvent   │ ───► ────┤
                   └────────────────────────┘           │
                                                         ▼
                                                ┌────────────────┐
                                                │ Quality Order  │
                                                │     Table      │
                                                │                │
                                                │ Filter:        │
                                                │ Test Status IN │
                                                │ (Pending,      │
                                                │  Failed)       │
                                                │                │
                                                │ If Found:      │
                                                │ Error()        │
                                                └────────────────┘
```

### Data Model

```
┌──────────────────────┐         ┌─────────────────────┐
│   Quality Order      │         │   Item Ledger       │
│                      │         │   Entry             │
│ - Lot No. (PK)       │◄───────┤                     │
│ - Item No. (PK)      │  links │ - Lot No. (FK)      │
│ - Test Status        │         │ - Item No. (FK)     │
│   • Pending          │         │ - Quantity          │
│   • Passed           │         └─────────────────────┘
│   • Failed           │
└──────────────────────┘
         ▲
         │
         │ references
         │
┌────────┴─────────────┐
│ Tracking             │
│ Specification        │
│                      │
│ - Lot No. (FK)       │
│ - Item No. (FK)      │
│ - Quantity (Base)    │
└──────────────────────┘
```

### Validation Logic Flow

```al
procedure ValidateLotQualityStatus(ItemNo: Code[20]; LotNo: Code[50])
begin
    // Query Quality Order table
    QualityOrder.SetRange("Lot No.", LotNo);
    QualityOrder.SetRange("Item No.", ItemNo);
    QualityOrder.SetFilter("Test Status", '%1|%2', Pending, Failed);

    if QualityOrder.FindFirst() then
        Error('Cannot use lot with status: %1', QualityOrder."Test Status");

    // If no Pending/Failed records found, validation passes
end;
```

**Key Design Decisions**:
1. **Three validation points** ensure comprehensive coverage
2. **xRec parameter check** prevents validation on field touch
3. **Only validate negative quantities** (outbound movements)
4. **Shared validation procedure** ensures consistency

---

## Low Inventory Alert Architecture

### Event Flow

```
Inventory Transaction               Alert Processing                External Systems
====================               =================               =================

Item Journal      ┌─────────────────────────┐
Posting      ────►│ OnAfterInsertItemLedg   │
                  │ Entry Event             │
                  └──────────┬──────────────┘
                             │
                             ▼
                  ┌──────────────────────────┐
                  │ Configuration Validation │
                  │ - Setup exists?          │
                  │ - Alerts enabled?        │
                  │ - URL configured?        │
                  │ - Negative quantity?     │
                  └──────────┬───────────────┘
                             │
                             ▼
                  ┌──────────────────────────┐
                  │ Get Safety Stock         │
                  │ 1. Stockkeeping Unit     │
                  │    (Location-specific)   │
                  │ 2. Item (fallback)       │
                  └──────────┬───────────────┘
                             │
                             ▼
                  ┌──────────────────────────┐
                  │ Calculate Inventory      │
                  │ - Before: Sum entries    │
                  │   up to EntryNo - 1      │
                  │ - After: Before + Qty    │
                  └──────────┬───────────────┘
                             │
                             ▼
                  ┌──────────────────────────┐
                  │ Threshold Check          │
                  │ IF (Before > SafetyStock)│
                  │ AND (After <= SafetyStock│
                  │ THEN Alert               │
                  └──────────┬───────────────┘
                             │
                             ▼
                  ┌──────────────────────────┐
                  │ Build JSON Payload       │
                  │ - ItemNo                 │
                  │ - Description            │
                  │ - CurrentInventory       │
                  └──────────┬───────────────┘
                             │
                             ▼
                  ┌──────────────────────────┐
                  │ HTTP POST                │
                  │ - Set Content-Type       │
                  │ - Add API Key (optional) │
                  │ - Send Request           │────────►  Azure Logic Apps
                  └──────────┬───────────────┘                 │
                             │                                 │
                             ▼                                 ▼
                  ┌──────────────────────────┐      ┌──────────────────┐
                  │ Log Result               │      │ Parse JSON       │
                  │ - Success: Save alert    │      │ Insert to Sheets │
                  │ - Failure: Save error    │      └──────────────────┘
                  └──────────────────────────┘
```

### Data Model

```
┌────────────────────────┐         ┌─────────────────────────┐
│  Manufacturing Setup   │         │  Item Ledger Entry      │
│                        │         │                         │
│ - Enable Alerts (Bool) │         │ - Entry No. (PK)        │
│ - Endpoint URL (500)   │         │ - Item No. (FK)         │
│ - API Key (100)        │         │ - Location Code (FK)    │
└────────────────────────┘         │ - Quantity              │
                                   │ - Posting Date          │
                                   └──────────┬──────────────┘
                                              │
                                              │ triggers
                                              │
                                   ┌──────────▼──────────────┐
                                   │  Inventory Alert Log    │
                                   │                         │
                                   │ - Entry No. (PK)        │
                                   │ - Item Ledger Entry No. │
                                   │ - Item No.              │
                                   │ - Location Code         │
                                   │ - Current Inventory     │
                                   │ - Safety Stock          │
                                   │ - Alert Timestamp       │
                                   │ - Alert Status          │
                                   │   • Success             │
                                   │   • Failed              │
                                   │ - Error Message         │
                                   └─────────────────────────┘
                                              │
                                              │ references
                                              │
┌────────────────────────┐         ┌──────────▼──────────────┐
│  Item                  │         │  Stockkeeping Unit      │
│                        │         │                         │
│ - No. (PK)             │◄────────┤ - Item No. (PK)         │
│ - Description          │         │ - Location Code (PK)    │
│ - Safety Stock Qty     │         │ - Safety Stock Qty      │
│ - Vendor No.           │         └─────────────────────────┘
└────────────────────────┘
```

### Threshold Detection Algorithm

**Problem**: Alert only when crossing threshold, not when already below

**Solution**: Compare before and after states

```
Time        Inventory    Safety Stock    Action
====        =========    ============    ======
T0          110          100             (normal state)
T1          105          100             (still above)
T2          95           100             ◄── ALERT! (crossed from 105→95)
T3          90           100             (no alert, already below)
T4          85           100             (no alert, already below)
```

**Implementation**:
```al
InventoryBefore := SumLedgerEntries(ItemNo, Location, 0, EntryNo - 1);
InventoryAfter := InventoryBefore + CurrentEntry.Quantity;

if (InventoryBefore > SafetyStock) and (InventoryAfter <= SafetyStock) then
    SendAlert(); // Only fires on crossing
```

**Why this works**:
- Uses boolean AND logic
- `Before > Safety` = was OK
- `After <= Safety` = now problematic
- Both true = transition occurred

### Inventory Calculation

**Query Pattern**:
```al
ItemLedgerEntry.SetRange("Item No.", ItemNo);
ItemLedgerEntry.SetRange("Location Code", LocationCode);
ItemLedgerEntry.SetRange("Entry No.", 0, UpToEntryNo);

TotalQty := 0;
if ItemLedgerEntry.FindSet() then
    repeat
        TotalQty += ItemLedgerEntry.Quantity;
    until ItemLedgerEntry.Next() = 0;
```

**Performance**: O(n) where n = ledger entries for item+location
**Optimization**: Filtered by Entry No. range reduces dataset

### HTTP Communication

**Request Structure**:
```
POST https://prod-06.eastus.logic.azure.com/workflows/.../triggers/manual/paths/invoke
Headers:
    Content-Type: application/json
    x-api-key: [optional]
Body:
    {
        "ItemNo": "1000",
        "Description": "Widget",
        "CurrentInventory": 95.0
    }
```

**Response Handling**:
```
Success (200-299):  ─► Log as Success
Client Error (400-499): ─► Log as Failed (with error details)
Server Error (500-599): ─► Log as Failed (with error details)
Network Failure: ─► Log as Failed ("Failed to send HTTP request")
```

**Fire-and-Forget Pattern**:
- No Error() call on HTTP failure
- Business transaction proceeds
- Failure logged for later investigation

---

## Security Architecture

### Data Classification

| Field | Classification | Rationale |
|-------|---------------|-----------|
| Enable Inventory Alerts | SystemMetadata | Configuration data |
| Logic Apps Endpoint URL | SystemMetadata | Technical config, not PII |
| Logic Apps API Key | EndUserIdentifiable | Security credential |
| Alert Log entries | SystemMetadata | Audit data, no PII |

### API Key Handling

```al
field(50105; "Logic Apps API Key"; Text[100])
{
    Caption = 'Logic Apps API Key';
    DataClassification = EndUserIdentifiableInformation;
    ExtendedDatatype = Masked;  // ◄── Hidden in UI
}
```

- Stored as masked field in BC
- Transmitted in HTTP header (not URL)
- Optional (can use IP whitelist instead)

### Network Security

**Outbound Connection**:
- BC → Azure Logic Apps
- HTTPS only (TLS 1.2+)
- No inbound firewall rules needed
- Azure private endpoints supported

**Authentication Options**:
1. **No auth** (IP whitelist in Azure)
2. **API Key** (x-api-key header)
3. **Azure AD OAuth** (future enhancement)

---

## Scalability Considerations

### Event Subscriber Performance

**Trigger Frequency**: Every Item Ledger Entry insert
**Typical Volume**:
- Small business: 100-500/day
- Medium business: 1,000-5,000/day
- Large business: 10,000+/day

**Optimization Strategy**:
```al
// Exit as early as possible
if Quantity >= 0 then exit;           // ~50% of entries
if SafetyStock = 0 then exit;         // ~70% of remaining items
if not (Before > SS and After <= SS)  // ~95% of remaining
    then exit;

// Only 2-3% reach HTTP call
```

### Database Performance

**Inventory Calculation Query**:
- Filtered by Item No., Location Code, Entry No. range
- Uses key: (Item No., Entry Type, Location Code, Posting Date)
- Typical result set: 10-1000 entries per item+location

**Alert Log Growth**:
- Estimated: 5-20 alerts/day
- Annual: 1,825-7,300 records
- Recommendation: Archive after 1 year

### Azure Logic Apps Scaling

**Throughput**:
- Consumption Plan: Auto-scales
- Typical latency: 100-500ms
- Max: 5,000 executions/5 minutes

**Cost**:
- $0.000025 per action execution
- Estimated monthly (20 alerts/day): $0.60

---

## Error Handling Strategy

### Business Central Layer

```
Error Type                  Handling
==========                  ========
Configuration missing   →   Exit silently (logged via debug)
Safety Stock = 0        →   Exit silently (not an error)
Item not found          →   Exit silently (defensive)
HTTP failure            →   Log error, continue posting
JSON build failure      →   Exit silently (defensive)
```

**Philosophy**: Never block inventory posting

### Azure Logic Apps Layer

```
Error Type                  Handling
==========                  ========
Invalid JSON            →   400 response, BC logs error
Google Sheets error     →   Retry 4x, then fail
Rate limit exceeded     →   Retry with backoff
```

### Monitoring & Alerting

**Business Central**:
- Check Inventory Alert Log page
- Filter by Alert Status = Failed
- Review Error Message field

**Azure**:
- Logic Apps Run History
- Failed runs trigger Azure Monitor alerts
- Email notification to admin

---

## Testing Strategy

### Unit Testing Scenarios

1. **Threshold Crossing**
   - Before = 105, After = 95, Safety = 100 → Alert
   - Before = 95, After = 85, Safety = 100 → No Alert

2. **Edge Cases**
   - Quantity = 0 → Exit (no change)
   - Safety Stock = 0 → Exit (not monitored)
   - Before = 100, After = 100, Safety = 100 → No Alert (exact match)

3. **Location Handling**
   - Stockkeeping Unit exists → Use location safety stock
   - SKU missing → Fall back to item safety stock
   - Both missing → Exit (safety stock = 0)

### Integration Testing

1. **End-to-End Happy Path**
   - Post adjustment in BC
   - Verify HTTP sent
   - Check Logic Apps run history
   - Verify row in Google Sheets
   - Verify alert log in BC

2. **Failure Scenarios**
   - Invalid URL → BC logs error, posting succeeds
   - Logic Apps down → BC logs error, posting succeeds
   - Google Sheets down → Retry in Logic Apps

---

## Deployment Architecture

### Development Environment
```
Developer Machine
    ├─ VS Code + AL Extension
    ├─ Business Central Docker (local)
    └─ Azure Logic Apps (Dev subscription)
         └─ Google Sheets (Test sheet)
```

### Production Environment
```
Business Central Cloud/On-Prem
    ├─ Published Extension (ALProject10.app)
    ├─ Manufacturing Setup (configured)
    └─ Azure Logic Apps (Prod subscription)
         └─ Google Sheets (Production sheet)
```

### Deployment Process
1. Develop in local BC Docker container
2. Test with Azure Logic Apps Dev environment
3. Create .app file
4. Publish to BC Dev environment
5. User acceptance testing
6. Publish to BC Production
7. Update Logic Apps to Production endpoint

---

## Future Architecture Enhancements

### Phase 2: Pull Integration
```
Azure Logic Apps (Scheduler)
    │
    └─► HTTP GET → BC Custom API
            │
            └─► Query: Item Inventory by Location
                    └─► Response: JSON array of all items
                            └─► Logic Apps → SQL Database
```

### Phase 3: Two-Way Integration
```
BC ──Push──► Google Sheets (Alerts)
     ▲           │
     │           │ (User Approves)
     │           ▼
     └──Pull─── Logic Apps → BC API (Create PO)
```

### Phase 4: Predictive Analytics
```
BC → Azure ML
     │
     └─► Analyze historical consumption
          └─► Predict low inventory date
               └─► Proactive alerts (5 days advance warning)
```

---

## References

- [AL Event Subscribers](https://learn.microsoft.com/en-us/dynamics365/business-central/dev-itpro/developer/devenv-events-in-al)
- [HTTP Client in AL](https://learn.microsoft.com/en-us/dynamics365/business-central/dev-itpro/developer/devenv-httpclient)
- [Azure Logic Apps](https://learn.microsoft.com/en-us/azure/logic-apps/)
- [Google Sheets API](https://developers.google.com/sheets/api)
