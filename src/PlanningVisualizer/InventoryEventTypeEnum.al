enum 50160 "Inventory Event Type"
{
    Extensible = true;
    Caption = 'Inventory Event Type';

    value(0; "Initial Inventory")
    {
        Caption = 'Initial Inventory';
    }
    value(1; "Sales Order")
    {
        Caption = 'Sales Order';
    }
    value(2; "Sales Return")
    {
        Caption = 'Sales Return Order';
    }
    value(3; "Purchase Order")
    {
        Caption = 'Purchase Order';
    }
    value(4; "Purchase Return")
    {
        Caption = 'Purchase Return Order';
    }
    value(5; "Prod Order Output")
    {
        Caption = 'Prod. Order Output';
    }
    value(6; "Prod Order Comp")
    {
        Caption = 'Prod. Order Component';
    }
    value(7; "Assembly Output")
    {
        Caption = 'Assembly Output';
    }
    value(8; "Assembly Comp")
    {
        Caption = 'Assembly Component';
    }
    value(9; "Transfer In")
    {
        Caption = 'Transfer In';
    }
    value(10; "Transfer Out")
    {
        Caption = 'Transfer Out';
    }
    value(11; "Service Order")
    {
        Caption = 'Service Order';
    }
    value(12; "Job Planning")
    {
        Caption = 'Job Planning Line';
    }
    value(13; "Planning Suggestion")
    {
        Caption = 'Planning Suggestion';
    }
    value(14; "Planning Component")
    {
        Caption = 'Planning Component';
    }
    value(16; "Blanket Sales Order")
    {
        Caption = 'Blanket Sales Order';
    }
    value(15; "Pending Req. Line")
    {
        Caption = 'Pending Requisition Line';
    }
}
