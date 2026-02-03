codeunit 50104 "CSV Sales Order Import"
{
    procedure ImportFromFile()
    var
        MfgSetup: Record "Manufacturing Setup";
        Customer: Record Customer;
        CSVBuffer: Record "CSV Import Buffer";
        InStr: InStream;
        FileName: Text;
        ValidationError: Text;
        OrderNo: Code[20];
    begin
        // Get and validate Manufacturing Setup
        if not MfgSetup.Get() then
            Error('Manufacturing Setup not found.');

        if MfgSetup."CSV Import Customer No." = '' then
            Error('CSV Import Customer No. is not configured in Manufacturing Setup. Please configure it before importing.');

        if not Customer.Get(MfgSetup."CSV Import Customer No.") then
            Error('Customer %1 not found. Please configure a valid customer in Manufacturing Setup.', MfgSetup."CSV Import Customer No.");

        // File upload dialog
        if not UploadIntoStream('Select CSV File', '', 'CSV Files (*.csv)|*.csv|All Files (*.*)|*.*', FileName, InStr) then
            exit;

        // Parse CSV file
        if not ParseCSV(InStr, CSVBuffer) then
            Error('Failed to parse CSV file. Please check the file format.');

        if CSVBuffer.Count = 0 then
            Error('No data rows found in CSV file. Please ensure the file contains data after the header row.');

        // Validate all data
        ValidationError := ValidateData(CSVBuffer);
        if ValidationError <> '' then
            Error('CSV validation failed:%1', ValidationError);

        // Create Sales Order with all lines
        OrderNo := CreateSalesOrder(CSVBuffer, MfgSetup."CSV Import Customer No.");

        // Ask if user wants to open the created Sales Order
        if Confirm('Sales Order %1 created successfully with %2 line(s).\\Do you want to open the Sales Order?', true, OrderNo, CSVBuffer.Count) then
            OpenSalesOrder(OrderNo);
    end;

    local procedure ParseCSV(InStr: InStream; var Buffer: Record "CSV Import Buffer"): Boolean
    var
        Line: Text;
        LineNo: Integer;
        Color: Text;
        Size: Text;
        QuantityText: Text;
        Quantity: Decimal;
        TotalLines: Integer;
        ParsedLines: Integer;
    begin
        Buffer.DeleteAll();
        LineNo := 0;
        TotalLines := 0;
        ParsedLines := 0;

        // Read file line by line
        while not InStr.EOS() do begin
            InStr.ReadText(Line);
            LineNo += 1;
            TotalLines += 1;

            // Skip header row
            if LineNo = 1 then
                continue;

            // Skip empty lines
            if Line = '' then
                continue;

            // Parse CSV line: Color,Size,Quantity
            if ParseCSVLine(Line, Color, Size, QuantityText) then begin
                ParsedLines += 1;

                // Convert quantity to decimal
                if not Evaluate(Quantity, QuantityText) then
                    Quantity := 0;

                // Add to buffer
                Buffer.Init();
                Buffer."Line No." := LineNo - 1;
                Buffer.Color := CopyStr(Color, 1, 50);
                Buffer.Size := CopyStr(Size, 1, 50);
                Buffer.Quantity := Quantity;
                Buffer."Item No." := CopyStr(Color + Size, 1, 20);
                Buffer.Insert();
            end;
        end;

        exit(true);
    end;

    local procedure ParseCSVLine(Line: Text; var Color: Text; var Size: Text; var Quantity: Text): Boolean
    var
        CommaPos1: Integer;
        CommaPos2: Integer;
    begin
        // Find first comma
        CommaPos1 := StrPos(Line, ',');
        if CommaPos1 = 0 then
            exit(false);

        // Find second comma
        CommaPos2 := StrPos(CopyStr(Line, CommaPos1 + 1), ',');
        if CommaPos2 = 0 then
            exit(false);
        CommaPos2 += CommaPos1;

        // Extract fields
        Color := CopyStr(Line, 1, CommaPos1 - 1);
        Size := CopyStr(Line, CommaPos1 + 1, CommaPos2 - CommaPos1 - 1);
        Quantity := CopyStr(Line, CommaPos2 + 1);

        exit(true);
    end;

    local procedure ValidateData(var Buffer: Record "CSV Import Buffer"): Text
    var
        ErrorText: Text;
        LineCount: Integer;
    begin
        ErrorText := '';
        LineCount := 0;

        if Buffer.FindSet() then
            repeat
                LineCount += 1;

                // Check Color is not empty
                if Buffer.Color = '' then
                    ErrorText += StrSubstNo('\Line %1: Color is empty.', LineCount);

                // Check Size is not empty
                if Buffer.Size = '' then
                    ErrorText += StrSubstNo('\Line %1: Size is empty.', LineCount);

                // Check Quantity > 0
                if Buffer.Quantity <= 0 then
                    ErrorText += StrSubstNo('\Line %1: Quantity must be greater than 0.', LineCount);

                // Check Item No. length (Color + Size concatenated)
                if StrLen(Buffer.Color + Buffer.Size) > 20 then
                    ErrorText += StrSubstNo('\Line %1: Item No. (%2) exceeds 20 characters.', LineCount, Buffer.Color + Buffer.Size);

            until Buffer.Next() = 0;

        exit(ErrorText);
    end;

    local procedure CreateSalesOrder(var Buffer: Record "CSV Import Buffer"; CustomerNo: Code[20]): Code[20]
    var
        SalesHeader: Record "Sales Header";
    begin
        // Create Sales Header
        SalesHeader.Init();
        SalesHeader."Document Type" := SalesHeader."Document Type"::Order;
        SalesHeader.Insert(true);
        SalesHeader.Validate("Sell-to Customer No.", CustomerNo);
        SalesHeader.Modify(true);

        // Create Sales Lines from buffer
        if Buffer.FindSet() then
            repeat
                CreateSalesLine(SalesHeader, Buffer);
            until Buffer.Next() = 0;

        Commit();
        exit(SalesHeader."No.");
    end;

    local procedure CreateSalesLine(var SalesHeader: Record "Sales Header"; BufferRec: Record "CSV Import Buffer")
    var
        SalesLine: Record "Sales Line";
        Item: Record Item;
        ItemNo: Code[20];
    begin
        ItemNo := CopyStr(BufferRec.Color + BufferRec.Size, 1, 20);

        // Create item if it doesn't exist
        if not ItemExists(ItemNo) then
            CreateBasicItem(ItemNo, BufferRec.Color, BufferRec.Size);

        // Get the Item to access its Base Unit of Measure
        Item.Get(ItemNo);

        // Create Sales Line
        SalesLine.Init();
        SalesLine."Document Type" := SalesHeader."Document Type";
        SalesLine."Document No." := SalesHeader."No.";
        SalesLine."Line No." := GetNextLineNo(SalesHeader);
        SalesLine.Insert(true);
        SalesLine.Validate(Type, SalesLine.Type::Item);
        SalesLine.Validate("No.", ItemNo);
        SalesLine.Validate("Unit of Measure Code", Item."Base Unit of Measure");
        SalesLine.Validate(Quantity, BufferRec.Quantity);
        SalesLine.Modify(true);
    end;

    local procedure CreateBasicItem(ItemNo: Code[20]; Color: Text[50]; Size: Text[50])
    var
        Item: Record Item;
        MfgSetup: Record "Manufacturing Setup";
        ConfigTemplateHeader: Record "Config. Template Header";
        ConfigTemplateMgt: Codeunit "Config. Template Management";
        ItemRecRef: RecordRef;
    begin
        // Check if Item Template is configured
        if not MfgSetup.Get() then
            Error('Manufacturing Setup not found.');

        if MfgSetup."CSV Item Template Code" = '' then
            Error('CSV Item Template Code must be configured in Manufacturing Setup to create new items. Please configure an Item Template first.');

        if not ConfigTemplateHeader.Get(MfgSetup."CSV Item Template Code") then
            Error('Item Template %1 not found.', MfgSetup."CSV Item Template Code");

        // Create basic Item with No. and Description
        Item.Init();
        Item.Validate("No.", ItemNo);
        Item.Validate(Description, CopyStr(Color + ' ' + Size, 1, MaxStrLen(Item.Description)));
        Item.Insert(true);

        // Commit the item so it exists in the database before applying template
        Commit();

        // Apply Item Template (this will set Base Unit of Measure and other fields)
        Item.Get(ItemNo);  // Re-get the item after commit
        ItemRecRef.GetTable(Item);
        ConfigTemplateMgt.UpdateRecord(ConfigTemplateHeader, ItemRecRef);
        ItemRecRef.SetTable(Item);
        Item.Modify(true);  // Save the template changes to the database
    end;

    local procedure ItemExists(ItemNo: Code[20]): Boolean
    var
        Item: Record Item;
    begin
        exit(Item.Get(ItemNo));
    end;

    local procedure GetNextLineNo(SalesHeader: Record "Sales Header"): Integer
    var
        SalesLine: Record "Sales Line";
    begin
        SalesLine.SetRange("Document Type", SalesHeader."Document Type");
        SalesLine.SetRange("Document No.", SalesHeader."No.");
        if SalesLine.FindLast() then
            exit(SalesLine."Line No." + 10000)
        else
            exit(10000);
    end;

    local procedure OpenSalesOrder(OrderNo: Code[20])
    var
        SalesHeader: Record "Sales Header";
    begin
        if SalesHeader.Get(SalesHeader."Document Type"::Order, OrderNo) then
            Page.Run(Page::"Sales Order", SalesHeader);
    end;
}
