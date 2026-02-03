xmlport 50100 "CSV Sales Order Import"
{
    Direction = Import;
    Format = VariableText;
    TextEncoding = UTF8;
    UseRequestPage = false;
    Caption = 'CSV Sales Order Import';
    FieldSeparator = ',';

    schema
    {
        textelement(Root)
        {
            textelement(ColorText) { }
            textelement(SizeText) { }
            textelement(QuantityText)
            {
                trigger OnAfterAssignVariable()
                begin
                    RecordCount += 1;

                    // Skip first row (header)
                    if RecordCount = 1 then begin
                        FirstRowProcessed := true;
                        exit;
                    end;

                    // Process data rows
                    TempCSVBuffer.Init();
                    TempCSVBuffer."Line No." := RecordCount - 1;
                    TempCSVBuffer.Color := ColorText;
                    TempCSVBuffer.Size := SizeText;
                    if not Evaluate(TempCSVBuffer.Quantity, QuantityText) then
                        TempCSVBuffer.Quantity := 0;
                    TempCSVBuffer."Item No." := ColorText + SizeText;
                    TempCSVBuffer.Insert();
                end;
            }
        }
    }

    trigger OnPreXmlPort()
    begin
        RecordCount := 0;
        FirstRowProcessed := false;
        TempCSVBuffer.DeleteAll();
    end;

    procedure GetBuffer(var TempBuffer: Record "CSV Import Buffer" temporary)
    begin
        if TempCSVBuffer.FindSet() then
            repeat
                TempBuffer := TempCSVBuffer;
                TempBuffer.Insert();
            until TempCSVBuffer.Next() = 0;
    end;

    var
        RecordCount: Integer;
        FirstRowProcessed: Boolean;
        TempCSVBuffer: Record "CSV Import Buffer" temporary;
}
