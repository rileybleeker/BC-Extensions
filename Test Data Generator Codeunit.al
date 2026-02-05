codeunit 50115 "Test Data Generator"
{
    // TEMPORARY CODEUNIT - REMOVE AFTER TESTING
    // Generates sample inventory transactions and sales shipments
    // for testing the Planning Parameter Suggestion system

    procedure GenerateTestData()
    var
        ItemNo: Code[20];
        LocationCode: Code[10];
    begin
        // Get or create test item
        ItemNo := SetupTestItem();

        // Get default location
        LocationCode := GetDefaultLocation();

        // Add inventory
        AddInventory(ItemNo, LocationCode, 1000);

        // Create historical sales over past 6 months
        CreateHistoricalSales(ItemNo, LocationCode);

        Message('Test data generation complete.\Item: %1\Location: %2\Check Item Ledger Entries to verify transactions.', ItemNo, LocationCode);
    end;

    procedure GenerateTestDataWithParams(ItemNo: Code[20]; LocationCode: Code[10]; InitialQty: Decimal; MonthsOfHistory: Integer)
    begin
        if ItemNo = '' then
            ItemNo := SetupTestItem();

        if LocationCode = '' then
            LocationCode := GetDefaultLocation();

        AddInventory(ItemNo, LocationCode, InitialQty);
        CreateHistoricalSalesWithMonths(ItemNo, LocationCode, MonthsOfHistory);

        Message('Test data generation complete.\Item: %1\Location: %2\Months of history: %3', ItemNo, LocationCode, MonthsOfHistory);
    end;

    local procedure SetupTestItem(): Code[20]
    var
        Item: Record Item;
        ItemNo: Code[20];
    begin
        ItemNo := 'TEST-PLAN-001';

        if Item.Get(ItemNo) then
            exit(ItemNo);

        Item.Init();
        Item."No." := ItemNo;
        Item.Description := 'Test Item for Planning Suggestions';
        Item."Base Unit of Measure" := 'PCS';
        Item."Gen. Prod. Posting Group" := GetDefaultGenProdPostingGroup();
        Item."Inventory Posting Group" := GetDefaultInvPostingGroup();
        Item."Costing Method" := Item."Costing Method"::Average;
        Item."Unit Cost" := 10.00;
        Item."Unit Price" := 25.00;
        Item."Planning Suggestion Enabled" := true;
        Item.Insert(true);

        exit(ItemNo);
    end;

    local procedure GetDefaultLocation(): Code[10]
    var
        Location: Record Location;
    begin
        Location.SetRange("Use As In-Transit", false);
        if Location.FindFirst() then
            exit(Location.Code);

        // If no location, return blank (will use blank location)
        exit('');
    end;

    local procedure GetDefaultGenProdPostingGroup(): Code[20]
    var
        GenProdPostingGroup: Record "Gen. Product Posting Group";
    begin
        if GenProdPostingGroup.FindFirst() then
            exit(GenProdPostingGroup.Code);
        exit('');
    end;

    local procedure GetDefaultInvPostingGroup(): Code[20]
    var
        InventoryPostingGroup: Record "Inventory Posting Group";
    begin
        if InventoryPostingGroup.FindFirst() then
            exit(InventoryPostingGroup.Code);
        exit('');
    end;

    local procedure AddInventory(ItemNo: Code[20]; LocationCode: Code[10]; Qty: Decimal)
    var
        ItemJnlLine: Record "Item Journal Line";
        ItemJnlTemplate: Record "Item Journal Template";
        ItemJnlBatch: Record "Item Journal Batch";
        ItemJnlPostLine: Codeunit "Item Jnl.-Post Line";
        LineNo: Integer;
    begin
        // Find a journal template and batch
        ItemJnlTemplate.SetRange(Type, ItemJnlTemplate.Type::Item);
        if not ItemJnlTemplate.FindFirst() then
            Error('No Item Journal Template found. Please create one first.');

        ItemJnlBatch.SetRange("Journal Template Name", ItemJnlTemplate.Name);
        if not ItemJnlBatch.FindFirst() then
            Error('No Item Journal Batch found. Please create one first.');

        // Get next line number
        ItemJnlLine.SetRange("Journal Template Name", ItemJnlTemplate.Name);
        ItemJnlLine.SetRange("Journal Batch Name", ItemJnlBatch.Name);
        if ItemJnlLine.FindLast() then
            LineNo := ItemJnlLine."Line No." + 10000
        else
            LineNo := 10000;

        // Create positive adjustment
        ItemJnlLine.Init();
        ItemJnlLine."Journal Template Name" := ItemJnlTemplate.Name;
        ItemJnlLine."Journal Batch Name" := ItemJnlBatch.Name;
        ItemJnlLine."Line No." := LineNo;
        ItemJnlLine."Posting Date" := CalcDate('<-6M>', Today());
        ItemJnlLine."Document Date" := ItemJnlLine."Posting Date";
        ItemJnlLine."Document No." := 'TEST-INV-001';
        ItemJnlLine."Entry Type" := ItemJnlLine."Entry Type"::"Positive Adjmt.";
        ItemJnlLine.Validate("Item No.", ItemNo);
        if LocationCode <> '' then
            ItemJnlLine.Validate("Location Code", LocationCode);
        ItemJnlLine.Validate(Quantity, Qty);
        ItemJnlLine.Description := 'Initial inventory for planning test';
        ItemJnlLine."Source Code" := ItemJnlTemplate."Source Code";

        ItemJnlPostLine.RunWithCheck(ItemJnlLine);
    end;

    local procedure CreateHistoricalSales(ItemNo: Code[20]; LocationCode: Code[10])
    begin
        CreateHistoricalSalesWithMonths(ItemNo, LocationCode, 6);
    end;

    local procedure CreateHistoricalSalesWithMonths(ItemNo: Code[20]; LocationCode: Code[10]; MonthsOfHistory: Integer)
    var
        SalesHeader: Record "Sales Header";
        SalesLine: Record "Sales Line";
        SalesPost: Codeunit "Sales-Post";
        CustomerNo: Code[20];
        PostingDate: Date;
        BaseQty: Decimal;
        Variance: Decimal;
        i: Integer;
        j: Integer;
        OrdersPerMonth: Integer;
    begin
        CustomerNo := GetDefaultCustomer();
        OrdersPerMonth := 4; // Weekly orders approximately
        BaseQty := 15; // Base quantity per order

        for i := MonthsOfHistory downto 1 do begin
            for j := 1 to OrdersPerMonth do begin
                // Calculate posting date (spread throughout month)
                PostingDate := CalcDate(StrSubstNo('<-%1M+%2D>', i, (j - 1) * 7), Today());

                // Add some variance to quantities (70% to 130% of base)
                Variance := (Random(60) - 30) / 100;

                CreateAndPostSalesOrder(
                    CustomerNo,
                    ItemNo,
                    LocationCode,
                    Round(BaseQty * (1 + Variance), 1),
                    PostingDate
                );
            end;
        end;
    end;

    local procedure GetDefaultCustomer(): Code[20]
    var
        Customer: Record Customer;
        CustomerNo: Code[20];
    begin
        CustomerNo := 'TEST-CUST-001';

        if Customer.Get(CustomerNo) then
            exit(CustomerNo);

        // Try to find any existing customer
        if Customer.FindFirst() then
            exit(Customer."No.");

        // Create test customer
        Customer.Init();
        Customer."No." := CustomerNo;
        Customer.Name := 'Test Customer for Planning';
        Customer."Gen. Bus. Posting Group" := GetDefaultGenBusPostingGroup();
        Customer."Customer Posting Group" := GetDefaultCustPostingGroup();
        Customer.Insert(true);

        exit(CustomerNo);
    end;

    local procedure GetDefaultGenBusPostingGroup(): Code[20]
    var
        GenBusPostingGroup: Record "Gen. Business Posting Group";
    begin
        if GenBusPostingGroup.FindFirst() then
            exit(GenBusPostingGroup.Code);
        exit('');
    end;

    local procedure GetDefaultCustPostingGroup(): Code[20]
    var
        CustomerPostingGroup: Record "Customer Posting Group";
    begin
        if CustomerPostingGroup.FindFirst() then
            exit(CustomerPostingGroup.Code);
        exit('');
    end;

    local procedure CreateAndPostSalesOrder(CustomerNo: Code[20]; ItemNo: Code[20]; LocationCode: Code[10]; Qty: Decimal; PostingDate: Date)
    var
        SalesHeader: Record "Sales Header";
        SalesLine: Record "Sales Line";
        SalesPost: Codeunit "Sales-Post";
    begin
        // Create Sales Order Header
        SalesHeader.Init();
        SalesHeader."Document Type" := SalesHeader."Document Type"::Order;
        SalesHeader."No." := '';
        SalesHeader.Insert(true);

        SalesHeader.Validate("Sell-to Customer No.", CustomerNo);
        SalesHeader.Validate("Posting Date", PostingDate);
        SalesHeader.Validate("Document Date", PostingDate);
        SalesHeader.Validate("Order Date", PostingDate);
        SalesHeader.Validate("Shipment Date", PostingDate);
        if LocationCode <> '' then
            SalesHeader.Validate("Location Code", LocationCode);
        SalesHeader.Ship := true;
        SalesHeader.Invoice := true;
        SalesHeader.Modify(true);

        // Create Sales Line
        SalesLine.Init();
        SalesLine."Document Type" := SalesHeader."Document Type";
        SalesLine."Document No." := SalesHeader."No.";
        SalesLine."Line No." := 10000;
        SalesLine.Insert(true);

        SalesLine.Validate(Type, SalesLine.Type::Item);
        SalesLine.Validate("No.", ItemNo);
        if LocationCode <> '' then
            SalesLine.Validate("Location Code", LocationCode);
        SalesLine.Validate(Quantity, Qty);
        SalesLine.Validate("Unit Price", 25.00);
        SalesLine.Modify(true);

        // Re-read header for posting
        SalesHeader.Get(SalesHeader."Document Type", SalesHeader."No.");

        // Post the order (ship and invoice)
        SalesPost.Run(SalesHeader);
    end;

    procedure CleanupTestData()
    var
        Item: Record Item;
        Customer: Record Customer;
        Suggestion: Record "Planning Parameter Suggestion";
    begin
        // Delete test suggestions
        Suggestion.SetRange("Item No.", 'TEST-PLAN-001');
        Suggestion.DeleteAll();

        // Note: Item Ledger Entries cannot be deleted
        // The item and customer will remain but can be blocked

        if Item.Get('TEST-PLAN-001') then begin
            Item.Blocked := true;
            Item.Modify();
        end;

        if Customer.Get('TEST-CUST-001') then begin
            Customer.Blocked := Customer.Blocked::All;
            Customer.Modify();
        end;

        Message('Test data cleanup complete. Test item and customer have been blocked.\Note: Ledger entries cannot be deleted.');
    end;
}
