codeunit 50160 "Inventory Event Collector"
{
    // Collects supply and demand events from all BC source tables into a unified timeline buffer

    var
        NextEntryNo: Integer;

    procedure CollectEvents(
        ItemNo: Code[20];
        LocationCode: Code[10];
        VariantCode: Code[10];
        StartDate: Date;
        EndDate: Date;
        IncludeSuggestions: Boolean;
        WorksheetTemplateName: Code[10];
        JournalBatchName: Code[10];
        var TempEventBuffer: Record "Visualizer Event Buffer" temporary
    )
    begin
        if ItemNo = '' then
            Error('Item No. is required.');
        if EndDate < StartDate then
            Error('End Date must be after Start Date.');

        TempEventBuffer.Reset();
        TempEventBuffer.DeleteAll();
        NextEntryNo := 0;

        CollectInitialInventory(ItemNo, LocationCode, VariantCode, StartDate, TempEventBuffer);

        // Demand sources
        CollectSalesOrders(ItemNo, LocationCode, VariantCode, StartDate, EndDate, TempEventBuffer);
        CollectProdOrderComponents(ItemNo, LocationCode, VariantCode, StartDate, EndDate, TempEventBuffer);
        CollectAssemblyComponents(ItemNo, LocationCode, VariantCode, StartDate, EndDate, TempEventBuffer);
        CollectTransferOut(ItemNo, LocationCode, VariantCode, StartDate, EndDate, TempEventBuffer);
        CollectServiceOrders(ItemNo, LocationCode, VariantCode, StartDate, EndDate, TempEventBuffer);
        CollectJobPlanningLines(ItemNo, LocationCode, VariantCode, StartDate, EndDate, TempEventBuffer);
        CollectPlanningComponents(ItemNo, LocationCode, VariantCode, StartDate, EndDate, TempEventBuffer);
        CollectBlanketSalesOrders(ItemNo, LocationCode, VariantCode, StartDate, EndDate, TempEventBuffer);

        // Informational demand sources (not included in running totals)
        CollectDemandForecast(ItemNo, LocationCode, VariantCode, StartDate, EndDate, TempEventBuffer);

        // Supply sources
        CollectPurchaseOrders(ItemNo, LocationCode, VariantCode, StartDate, EndDate, TempEventBuffer);
        CollectProdOrderOutput(ItemNo, LocationCode, VariantCode, StartDate, EndDate, TempEventBuffer);
        CollectAssemblyOutput(ItemNo, LocationCode, VariantCode, StartDate, EndDate, TempEventBuffer);
        CollectTransferIn(ItemNo, LocationCode, VariantCode, StartDate, EndDate, TempEventBuffer);

        // Pending requisition lines from other worksheets (not-yet-carried-out supply)
        CollectPendingReqLines(ItemNo, LocationCode, VariantCode, StartDate, EndDate,
            WorksheetTemplateName, JournalBatchName, TempEventBuffer);

        // Planning suggestions from the current worksheet
        if IncludeSuggestions then
            CollectPlanningSuggestions(ItemNo, LocationCode, VariantCode, StartDate, EndDate,
                WorksheetTemplateName, JournalBatchName, TempEventBuffer);

        // Order tracking links
        CollectOrderTracking(ItemNo, LocationCode, VariantCode, TempEventBuffer);
    end;

    local procedure CollectInitialInventory(
        ItemNo: Code[20];
        LocationCode: Code[10];
        VariantCode: Code[10];
        StartDate: Date;
        var TempEventBuffer: Record "Visualizer Event Buffer" temporary
    )
    var
        Item: Record Item;
    begin
        Item.Get(ItemNo);
        if LocationCode <> '' then
            Item.SetRange("Location Filter", LocationCode);
        if VariantCode <> '' then
            Item.SetRange("Variant Filter", VariantCode);
        Item.CalcFields(Inventory);

        InsertEvent(
            TempEventBuffer,
            ItemNo, LocationCode, VariantCode,
            StartDate,
            "Inventory Event Type"::"Initial Inventory",
            Item.Inventory,
            true, // is supply
            false, // not suggestion
            StrSubstNo('On-hand inventory: %1', Item.Inventory),
            0, '', 0, Page::"Item Card"
        );
    end;

    local procedure CollectSalesOrders(
        ItemNo: Code[20];
        LocationCode: Code[10];
        VariantCode: Code[10];
        StartDate: Date;
        EndDate: Date;
        var TempEventBuffer: Record "Visualizer Event Buffer" temporary
    )
    var
        SalesLine: Record "Sales Line";
    begin
        SalesLine.SetRange("Document Type", SalesLine."Document Type"::Order);
        SalesLine.SetRange(Type, SalesLine.Type::Item);
        SalesLine.SetRange("No.", ItemNo);
        SalesLine.SetFilter("Outstanding Qty. (Base)", '>0');
        SalesLine.SetRange("Shipment Date", StartDate, EndDate);
        if LocationCode <> '' then
            SalesLine.SetRange("Location Code", LocationCode);
        if VariantCode <> '' then
            SalesLine.SetRange("Variant Code", VariantCode);

        if SalesLine.FindSet() then
            repeat
                InsertEvent(
                    TempEventBuffer,
                    ItemNo, SalesLine."Location Code", SalesLine."Variant Code",
                    SalesLine."Shipment Date",
                    "Inventory Event Type"::"Sales Order",
                    -SalesLine."Outstanding Qty. (Base)",
                    false,
                    false,
                    StrSubstNo('Sales Order %1, Line %2', SalesLine."Document No.", SalesLine."Line No."),
                    37, SalesLine."Document No.", SalesLine."Line No.",
                    Page::"Sales Order"
                );
            until SalesLine.Next() = 0;
    end;

    local procedure CollectProdOrderComponents(
        ItemNo: Code[20];
        LocationCode: Code[10];
        VariantCode: Code[10];
        StartDate: Date;
        EndDate: Date;
        var TempEventBuffer: Record "Visualizer Event Buffer" temporary
    )
    var
        ProdOrderComp: Record "Prod. Order Component";
    begin
        ProdOrderComp.SetRange("Item No.", ItemNo);
        ProdOrderComp.SetFilter(Status, '%1|%2|%3',
            ProdOrderComp.Status::Planned,
            ProdOrderComp.Status::"Firm Planned",
            ProdOrderComp.Status::Released);
        ProdOrderComp.SetFilter("Remaining Qty. (Base)", '>0');
        ProdOrderComp.SetRange("Due Date", StartDate, EndDate);
        if LocationCode <> '' then
            ProdOrderComp.SetRange("Location Code", LocationCode);
        if VariantCode <> '' then
            ProdOrderComp.SetRange("Variant Code", VariantCode);

        if ProdOrderComp.FindSet() then
            repeat
                InsertEvent(
                    TempEventBuffer,
                    ItemNo, ProdOrderComp."Location Code", ProdOrderComp."Variant Code",
                    ProdOrderComp."Due Date",
                    "Inventory Event Type"::"Prod Order Comp",
                    -ProdOrderComp."Remaining Qty. (Base)",
                    false,
                    false,
                    StrSubstNo('Prod. Order Comp %1, Line %2', ProdOrderComp."Prod. Order No.", ProdOrderComp."Line No."),
                    5407, ProdOrderComp."Prod. Order No.", ProdOrderComp."Line No.",
                    GetProdOrderPageId(ProdOrderComp.Status)
                );
            until ProdOrderComp.Next() = 0;
    end;

    local procedure CollectAssemblyComponents(
        ItemNo: Code[20];
        LocationCode: Code[10];
        VariantCode: Code[10];
        StartDate: Date;
        EndDate: Date;
        var TempEventBuffer: Record "Visualizer Event Buffer" temporary
    )
    var
        AssemblyLine: Record "Assembly Line";
    begin
        AssemblyLine.SetRange("Document Type", AssemblyLine."Document Type"::Order);
        AssemblyLine.SetRange(Type, AssemblyLine.Type::Item);
        AssemblyLine.SetRange("No.", ItemNo);
        AssemblyLine.SetFilter("Remaining Quantity (Base)", '>0');
        AssemblyLine.SetRange("Due Date", StartDate, EndDate);
        if LocationCode <> '' then
            AssemblyLine.SetRange("Location Code", LocationCode);
        if VariantCode <> '' then
            AssemblyLine.SetRange("Variant Code", VariantCode);

        if AssemblyLine.FindSet() then
            repeat
                InsertEvent(
                    TempEventBuffer,
                    ItemNo, AssemblyLine."Location Code", AssemblyLine."Variant Code",
                    AssemblyLine."Due Date",
                    "Inventory Event Type"::"Assembly Comp",
                    -AssemblyLine."Remaining Quantity (Base)",
                    false,
                    false,
                    StrSubstNo('Assembly Comp %1, Line %2', AssemblyLine."Document No.", AssemblyLine."Line No."),
                    901, AssemblyLine."Document No.", AssemblyLine."Line No.",
                    Page::"Assembly Order"
                );
            until AssemblyLine.Next() = 0;
    end;

    local procedure CollectTransferOut(
        ItemNo: Code[20];
        LocationCode: Code[10];
        VariantCode: Code[10];
        StartDate: Date;
        EndDate: Date;
        var TempEventBuffer: Record "Visualizer Event Buffer" temporary
    )
    var
        TransferLine: Record "Transfer Line";
    begin
        TransferLine.SetRange("Item No.", ItemNo);
        TransferLine.SetFilter("Outstanding Qty. (Base)", '>0');
        TransferLine.SetRange("Shipment Date", StartDate, EndDate);
        if LocationCode <> '' then
            TransferLine.SetRange("Transfer-from Code", LocationCode);
        if VariantCode <> '' then
            TransferLine.SetRange("Variant Code", VariantCode);

        if TransferLine.FindSet() then
            repeat
                InsertEvent(
                    TempEventBuffer,
                    ItemNo, TransferLine."Transfer-from Code", TransferLine."Variant Code",
                    TransferLine."Shipment Date",
                    "Inventory Event Type"::"Transfer Out",
                    -TransferLine."Outstanding Qty. (Base)",
                    false,
                    false,
                    StrSubstNo('Transfer Out %1 to %2', TransferLine."Document No.", TransferLine."Transfer-to Code"),
                    5741, TransferLine."Document No.", TransferLine."Line No.",
                    Page::"Transfer Order"
                );
            until TransferLine.Next() = 0;
    end;

    local procedure CollectServiceOrders(
        ItemNo: Code[20];
        LocationCode: Code[10];
        VariantCode: Code[10];
        StartDate: Date;
        EndDate: Date;
        var TempEventBuffer: Record "Visualizer Event Buffer" temporary
    )
    var
        ServiceLine: Record "Service Line";
    begin
        ServiceLine.SetRange("Document Type", ServiceLine."Document Type"::Order);
        ServiceLine.SetRange(Type, ServiceLine.Type::Item);
        ServiceLine.SetRange("No.", ItemNo);
        ServiceLine.SetFilter("Outstanding Qty. (Base)", '>0');
        ServiceLine.SetRange("Needed by Date", StartDate, EndDate);
        if LocationCode <> '' then
            ServiceLine.SetRange("Location Code", LocationCode);
        if VariantCode <> '' then
            ServiceLine.SetRange("Variant Code", VariantCode);

        if ServiceLine.FindSet() then
            repeat
                InsertEvent(
                    TempEventBuffer,
                    ItemNo, ServiceLine."Location Code", ServiceLine."Variant Code",
                    ServiceLine."Needed by Date",
                    "Inventory Event Type"::"Service Order",
                    -ServiceLine."Outstanding Qty. (Base)",
                    false,
                    false,
                    StrSubstNo('Service Order %1, Line %2', ServiceLine."Document No.", ServiceLine."Line No."),
                    5902, ServiceLine."Document No.", ServiceLine."Line No.",
                    Page::"Service Order"
                );
            until ServiceLine.Next() = 0;
    end;

    local procedure CollectJobPlanningLines(
        ItemNo: Code[20];
        LocationCode: Code[10];
        VariantCode: Code[10];
        StartDate: Date;
        EndDate: Date;
        var TempEventBuffer: Record "Visualizer Event Buffer" temporary
    )
    var
        JobPlanningLine: Record "Job Planning Line";
    begin
        JobPlanningLine.SetRange(Type, JobPlanningLine.Type::Item);
        JobPlanningLine.SetRange("No.", ItemNo);
        JobPlanningLine.SetFilter("Remaining Qty. (Base)", '>0');
        JobPlanningLine.SetRange("Planning Date", StartDate, EndDate);
        if LocationCode <> '' then
            JobPlanningLine.SetRange("Location Code", LocationCode);
        if VariantCode <> '' then
            JobPlanningLine.SetRange("Variant Code", VariantCode);

        if JobPlanningLine.FindSet() then
            repeat
                InsertEvent(
                    TempEventBuffer,
                    ItemNo, JobPlanningLine."Location Code", JobPlanningLine."Variant Code",
                    JobPlanningLine."Planning Date",
                    "Inventory Event Type"::"Job Planning",
                    -JobPlanningLine."Remaining Qty. (Base)",
                    false,
                    false,
                    StrSubstNo('Job %1, Task %2', JobPlanningLine."Job No.", JobPlanningLine."Job Task No."),
                    1003, JobPlanningLine."Job No.", JobPlanningLine."Line No.",
                    Page::"Job Planning Lines"
                );
            until JobPlanningLine.Next() = 0;
    end;

    local procedure CollectPlanningComponents(
        ItemNo: Code[20];
        LocationCode: Code[10];
        VariantCode: Code[10];
        StartDate: Date;
        EndDate: Date;
        var TempEventBuffer: Record "Visualizer Event Buffer" temporary
    )
    var
        PlanningComponent: Record "Planning Component";
    begin
        // Planning Components represent dependent demand from requisition lines
        // that suggest new production orders. If this item is a component,
        // these show demand that only exists because of planning suggestions.
        PlanningComponent.SetRange("Item No.", ItemNo);
        PlanningComponent.SetFilter("Expected Quantity (Base)", '>0');
        PlanningComponent.SetRange("Due Date", StartDate, EndDate);
        if LocationCode <> '' then
            PlanningComponent.SetRange("Location Code", LocationCode);
        if VariantCode <> '' then
            PlanningComponent.SetRange("Variant Code", VariantCode);

        if PlanningComponent.FindSet() then
            repeat
                InsertEvent(
                    TempEventBuffer,
                    ItemNo, PlanningComponent."Location Code", PlanningComponent."Variant Code",
                    PlanningComponent."Due Date",
                    "Inventory Event Type"::"Planning Component",
                    -PlanningComponent."Expected Quantity (Base)",
                    false,
                    true, // treat as suggestion since it depends on req. line being carried out
                    StrSubstNo('Planning Comp for %1 Line %2',
                        PlanningComponent."Worksheet Template Name", PlanningComponent."Line No."),
                    0, '', PlanningComponent."Line No.",
                    0
                );
            until PlanningComponent.Next() = 0;
    end;

    local procedure CollectBlanketSalesOrders(
        ItemNo: Code[20];
        LocationCode: Code[10];
        VariantCode: Code[10];
        StartDate: Date;
        EndDate: Date;
        var TempEventBuffer: Record "Visualizer Event Buffer" temporary
    )
    var
        SalesLine: Record "Sales Line";
    begin
        SalesLine.SetRange("Document Type", SalesLine."Document Type"::"Blanket Order");
        SalesLine.SetRange(Type, SalesLine.Type::Item);
        SalesLine.SetRange("No.", ItemNo);
        SalesLine.SetFilter("Outstanding Qty. (Base)", '>0');
        SalesLine.SetRange("Shipment Date", StartDate, EndDate);
        if LocationCode <> '' then
            SalesLine.SetRange("Location Code", LocationCode);
        if VariantCode <> '' then
            SalesLine.SetRange("Variant Code", VariantCode);

        if SalesLine.FindSet() then
            repeat
                InsertEvent(
                    TempEventBuffer,
                    ItemNo, SalesLine."Location Code", SalesLine."Variant Code",
                    SalesLine."Shipment Date",
                    "Inventory Event Type"::"Blanket Sales Order",
                    -SalesLine."Outstanding Qty. (Base)",
                    false,
                    false,
                    StrSubstNo('Blanket Sales Order %1, Line %2', SalesLine."Document No.", SalesLine."Line No."),
                    37, SalesLine."Document No.", SalesLine."Line No.",
                    Page::"Blanket Sales Order"
                );
            until SalesLine.Next() = 0;
    end;

    local procedure CollectDemandForecast(
        ItemNo: Code[20];
        LocationCode: Code[10];
        VariantCode: Code[10];
        StartDate: Date;
        EndDate: Date;
        var TempEventBuffer: Record "Visualizer Event Buffer" temporary
    )
    var
        ProdForecastEntry: Record "Production Forecast Entry";
    begin
        ProdForecastEntry.SetRange("Item No.", ItemNo);
        ProdForecastEntry.SetRange("Forecast Date", StartDate, EndDate);
        ProdForecastEntry.SetFilter("Forecast Quantity (Base)", '>0');
        if LocationCode <> '' then
            ProdForecastEntry.SetRange("Location Code", LocationCode);
        if VariantCode <> '' then
            ProdForecastEntry.SetRange("Variant Code", VariantCode);

        if ProdForecastEntry.FindSet() then
            repeat
                InsertEvent(
                    TempEventBuffer,
                    ItemNo, ProdForecastEntry."Location Code", ProdForecastEntry."Variant Code",
                    ProdForecastEntry."Forecast Date",
                    "Inventory Event Type"::"Demand Forecast",
                    -ProdForecastEntry."Forecast Quantity (Base)",
                    false,
                    false,
                    StrSubstNo('Demand Forecast: %1 (%2)',
                        ProdForecastEntry."Production Forecast Name", ProdForecastEntry.Description),
                    0, '', 0,
                    Page::"Demand Forecast Names"
                );
                // Mark as informational so it's excluded from running totals
                TempEventBuffer.Get(NextEntryNo);
                TempEventBuffer."Is Informational" := true;
                TempEventBuffer.Modify();
            until ProdForecastEntry.Next() = 0;
    end;

    local procedure CollectPendingReqLines(
        ItemNo: Code[20];
        LocationCode: Code[10];
        VariantCode: Code[10];
        StartDate: Date;
        EndDate: Date;
        ExcludeTemplateName: Code[10];
        ExcludeBatchName: Code[10];
        var TempEventBuffer: Record "Visualizer Event Buffer" temporary
    )
    var
        ReqLine: Record "Requisition Line";
    begin
        // Collect requisition lines from OTHER worksheets/batches that haven't
        // been carried out yet. These represent pending planned supply.
        ReqLine.SetRange(Type, ReqLine.Type::Item);
        ReqLine.SetRange("No.", ItemNo);
        ReqLine.SetRange("Due Date", StartDate, EndDate);
        ReqLine.SetFilter("Action Message", '%1', ReqLine."Action Message"::New);
        if LocationCode <> '' then
            ReqLine.SetRange("Location Code", LocationCode);
        if VariantCode <> '' then
            ReqLine.SetRange("Variant Code", VariantCode);

        if ReqLine.FindSet() then
            repeat
                // Skip lines from the current worksheet being visualized
                if (ReqLine."Worksheet Template Name" <> ExcludeTemplateName) or
                   (ReqLine."Journal Batch Name" <> ExcludeBatchName) then
                    InsertEvent(
                        TempEventBuffer,
                        ItemNo, ReqLine."Location Code", ReqLine."Variant Code",
                        ReqLine."Due Date",
                        "Inventory Event Type"::"Pending Req. Line",
                        ReqLine.Quantity,
                        true,
                        true, // treat as suggestion since not yet carried out
                        StrSubstNo('Pending %1 %2 (Wksh: %3/%4)',
                            Format(ReqLine."Replenishment System"), ReqLine."Ref. Order No.",
                            ReqLine."Worksheet Template Name", ReqLine."Journal Batch Name"),
                        246, ReqLine."Ref. Order No.", ReqLine."Line No.",
                        0
                    );
            until ReqLine.Next() = 0;
    end;

    local procedure CollectPurchaseOrders(
        ItemNo: Code[20];
        LocationCode: Code[10];
        VariantCode: Code[10];
        StartDate: Date;
        EndDate: Date;
        var TempEventBuffer: Record "Visualizer Event Buffer" temporary
    )
    var
        PurchaseLine: Record "Purchase Line";
    begin
        PurchaseLine.SetRange("Document Type", PurchaseLine."Document Type"::Order);
        PurchaseLine.SetRange(Type, PurchaseLine.Type::Item);
        PurchaseLine.SetRange("No.", ItemNo);
        PurchaseLine.SetFilter("Outstanding Qty. (Base)", '>0');
        PurchaseLine.SetRange("Expected Receipt Date", StartDate, EndDate);
        if LocationCode <> '' then
            PurchaseLine.SetRange("Location Code", LocationCode);
        if VariantCode <> '' then
            PurchaseLine.SetRange("Variant Code", VariantCode);

        if PurchaseLine.FindSet() then
            repeat
                InsertEvent(
                    TempEventBuffer,
                    ItemNo, PurchaseLine."Location Code", PurchaseLine."Variant Code",
                    PurchaseLine."Expected Receipt Date",
                    "Inventory Event Type"::"Purchase Order",
                    PurchaseLine."Outstanding Qty. (Base)",
                    true,
                    false,
                    StrSubstNo('Purchase Order %1, Line %2', PurchaseLine."Document No.", PurchaseLine."Line No."),
                    39, PurchaseLine."Document No.", PurchaseLine."Line No.",
                    Page::"Purchase Order"
                );
            until PurchaseLine.Next() = 0;
    end;

    local procedure CollectProdOrderOutput(
        ItemNo: Code[20];
        LocationCode: Code[10];
        VariantCode: Code[10];
        StartDate: Date;
        EndDate: Date;
        var TempEventBuffer: Record "Visualizer Event Buffer" temporary
    )
    var
        ProdOrderLine: Record "Prod. Order Line";
    begin
        ProdOrderLine.SetRange("Item No.", ItemNo);
        ProdOrderLine.SetFilter(Status, '%1|%2|%3',
            ProdOrderLine.Status::Planned,
            ProdOrderLine.Status::"Firm Planned",
            ProdOrderLine.Status::Released);
        ProdOrderLine.SetFilter("Remaining Qty. (Base)", '>0');
        ProdOrderLine.SetRange("Due Date", StartDate, EndDate);
        if LocationCode <> '' then
            ProdOrderLine.SetRange("Location Code", LocationCode);
        if VariantCode <> '' then
            ProdOrderLine.SetRange("Variant Code", VariantCode);

        if ProdOrderLine.FindSet() then
            repeat
                InsertEvent(
                    TempEventBuffer,
                    ItemNo, ProdOrderLine."Location Code", ProdOrderLine."Variant Code",
                    ProdOrderLine."Due Date",
                    "Inventory Event Type"::"Prod Order Output",
                    ProdOrderLine."Remaining Qty. (Base)",
                    true,
                    false,
                    StrSubstNo('Prod. Order %1, Line %2', ProdOrderLine."Prod. Order No.", ProdOrderLine."Line No."),
                    5406, ProdOrderLine."Prod. Order No.", ProdOrderLine."Line No.",
                    GetProdOrderPageId(ProdOrderLine.Status)
                );
            until ProdOrderLine.Next() = 0;
    end;

    local procedure CollectAssemblyOutput(
        ItemNo: Code[20];
        LocationCode: Code[10];
        VariantCode: Code[10];
        StartDate: Date;
        EndDate: Date;
        var TempEventBuffer: Record "Visualizer Event Buffer" temporary
    )
    var
        AssemblyHeader: Record "Assembly Header";
    begin
        AssemblyHeader.SetRange("Document Type", AssemblyHeader."Document Type"::Order);
        AssemblyHeader.SetRange("Item No.", ItemNo);
        AssemblyHeader.SetFilter("Remaining Quantity (Base)", '>0');
        AssemblyHeader.SetRange("Due Date", StartDate, EndDate);
        if LocationCode <> '' then
            AssemblyHeader.SetRange("Location Code", LocationCode);
        if VariantCode <> '' then
            AssemblyHeader.SetRange("Variant Code", VariantCode);

        if AssemblyHeader.FindSet() then
            repeat
                InsertEvent(
                    TempEventBuffer,
                    ItemNo, AssemblyHeader."Location Code", AssemblyHeader."Variant Code",
                    AssemblyHeader."Due Date",
                    "Inventory Event Type"::"Assembly Output",
                    AssemblyHeader."Remaining Quantity (Base)",
                    true,
                    false,
                    StrSubstNo('Assembly Order %1', AssemblyHeader."No."),
                    900, AssemblyHeader."No.", 0,
                    Page::"Assembly Order"
                );
            until AssemblyHeader.Next() = 0;
    end;

    local procedure CollectTransferIn(
        ItemNo: Code[20];
        LocationCode: Code[10];
        VariantCode: Code[10];
        StartDate: Date;
        EndDate: Date;
        var TempEventBuffer: Record "Visualizer Event Buffer" temporary
    )
    var
        TransferLine: Record "Transfer Line";
    begin
        TransferLine.SetRange("Item No.", ItemNo);
        TransferLine.SetFilter("Outstanding Qty. (Base)", '>0');
        TransferLine.SetRange("Receipt Date", StartDate, EndDate);
        if LocationCode <> '' then
            TransferLine.SetRange("Transfer-to Code", LocationCode);
        if VariantCode <> '' then
            TransferLine.SetRange("Variant Code", VariantCode);

        if TransferLine.FindSet() then
            repeat
                InsertEvent(
                    TempEventBuffer,
                    ItemNo, TransferLine."Transfer-to Code", TransferLine."Variant Code",
                    TransferLine."Receipt Date",
                    "Inventory Event Type"::"Transfer In",
                    TransferLine."Outstanding Qty. (Base)",
                    true,
                    false,
                    StrSubstNo('Transfer In %1 from %2', TransferLine."Document No.", TransferLine."Transfer-from Code"),
                    5741, TransferLine."Document No.", TransferLine."Line No.",
                    Page::"Transfer Order"
                );
            until TransferLine.Next() = 0;
    end;

    local procedure CollectPlanningSuggestions(
        ItemNo: Code[20];
        LocationCode: Code[10];
        VariantCode: Code[10];
        StartDate: Date;
        EndDate: Date;
        WorksheetTemplateName: Code[10];
        JournalBatchName: Code[10];
        var TempEventBuffer: Record "Visualizer Event Buffer" temporary
    )
    var
        ReqLine: Record "Requisition Line";
        ActionMsgText: Text[50];
    begin
        ReqLine.SetRange("Worksheet Template Name", WorksheetTemplateName);
        ReqLine.SetRange("Journal Batch Name", JournalBatchName);
        ReqLine.SetRange(Type, ReqLine.Type::Item);
        ReqLine.SetRange("No.", ItemNo);
        if LocationCode <> '' then
            ReqLine.SetRange("Location Code", LocationCode);
        if VariantCode <> '' then
            ReqLine.SetRange("Variant Code", VariantCode);

        if ReqLine.FindSet() then
            repeat
                ActionMsgText := Format(ReqLine."Action Message");

                case ReqLine."Action Message" of
                    ReqLine."Action Message"::New:
                        InsertSuggestionEvent(
                            TempEventBuffer, ItemNo, ReqLine,
                            ReqLine."Due Date",
                            ReqLine.Quantity,
                            true,
                            ActionMsgText
                        );
                    ReqLine."Action Message"::"Change Qty.":
                        InsertSuggestionEvent(
                            TempEventBuffer, ItemNo, ReqLine,
                            ReqLine."Due Date",
                            ReqLine.Quantity - ReqLine."Original Quantity",
                            ReqLine.Quantity > ReqLine."Original Quantity",
                            ActionMsgText
                        );
                    ReqLine."Action Message"::Reschedule:
                        begin
                            // Cancel at original date
                            InsertSuggestionEvent(
                                TempEventBuffer, ItemNo, ReqLine,
                                ReqLine."Original Due Date",
                                -ReqLine.Quantity,
                                false,
                                ActionMsgText + ' (Remove)'
                            );
                            // Add at new date
                            InsertSuggestionEvent(
                                TempEventBuffer, ItemNo, ReqLine,
                                ReqLine."Due Date",
                                ReqLine.Quantity,
                                true,
                                ActionMsgText + ' (Add)'
                            );
                        end;
                    ReqLine."Action Message"::"Resched. & Chg. Qty.":
                        begin
                            // Cancel original at original date
                            InsertSuggestionEvent(
                                TempEventBuffer, ItemNo, ReqLine,
                                ReqLine."Original Due Date",
                                -ReqLine."Original Quantity",
                                false,
                                ActionMsgText + ' (Remove)'
                            );
                            // Add new qty at new date
                            InsertSuggestionEvent(
                                TempEventBuffer, ItemNo, ReqLine,
                                ReqLine."Due Date",
                                ReqLine.Quantity,
                                true,
                                ActionMsgText + ' (Add)'
                            );
                        end;
                    ReqLine."Action Message"::Cancel:
                        InsertSuggestionEvent(
                            TempEventBuffer, ItemNo, ReqLine,
                            ReqLine."Due Date",
                            -ReqLine.Quantity,
                            false,
                            ActionMsgText
                        );
                end;
            until ReqLine.Next() = 0;
    end;

    local procedure InsertSuggestionEvent(
        var TempEventBuffer: Record "Visualizer Event Buffer" temporary;
        ItemNo: Code[20];
        ReqLine: Record "Requisition Line";
        EventDate: Date;
        Qty: Decimal;
        IsSupply: Boolean;
        ActionMsgText: Text[50]
    )
    begin
        NextEntryNo += 1;
        TempEventBuffer.Init();
        TempEventBuffer."Entry No." := NextEntryNo;
        TempEventBuffer."Item No." := ItemNo;
        TempEventBuffer."Location Code" := ReqLine."Location Code";
        TempEventBuffer."Variant Code" := ReqLine."Variant Code";
        TempEventBuffer."Event Date" := EventDate;
        TempEventBuffer."Event Type" := "Inventory Event Type"::"Planning Suggestion";
        TempEventBuffer.Quantity := Qty;
        TempEventBuffer."Is Suggestion" := true;
        TempEventBuffer."Is Supply" := IsSupply;
        TempEventBuffer."Action Message" := ActionMsgText;
        TempEventBuffer."Original Qty" := ReqLine."Original Quantity";
        TempEventBuffer."Original Date" := ReqLine."Original Due Date";
        TempEventBuffer."Source Document No." := ReqLine."Ref. Order No.";
        TempEventBuffer."Source Line No." := ReqLine."Line No.";
        TempEventBuffer."Source Description" := StrSubstNo('%1: %2 %3',
            ActionMsgText, Format(ReqLine."Ref. Order Type"), ReqLine."Ref. Order No.");
        TempEventBuffer."Source Document Type" := 246; // Requisition Line
        TempEventBuffer."Source Page ID" := 0;
        TempEventBuffer.Insert();
    end;

    local procedure CollectOrderTracking(
        ItemNo: Code[20];
        LocationCode: Code[10];
        VariantCode: Code[10];
        var TempEventBuffer: Record "Visualizer Event Buffer" temporary
    )
    var
        ReservEntry: Record "Reservation Entry";
        PairedEntry: Record "Reservation Entry";
        SupplyEntryNo: Integer;
        DemandEntryNo: Integer;
    begin
        ReservEntry.SetRange("Item No.", ItemNo);
        ReservEntry.SetRange("Reservation Status", ReservEntry."Reservation Status"::Tracking);
        ReservEntry.SetFilter("Quantity (Base)", '>0'); // Supply side entries
        if LocationCode <> '' then
            ReservEntry.SetRange("Location Code", LocationCode);
        if VariantCode <> '' then
            ReservEntry.SetRange("Variant Code", VariantCode);

        if ReservEntry.FindSet() then
            repeat
                // Find the paired demand entry
                PairedEntry.SetRange("Item No.", ItemNo);
                PairedEntry.SetRange("Reservation Status", PairedEntry."Reservation Status"::Tracking);
                PairedEntry.SetFilter("Quantity (Base)", '<0');
                PairedEntry.SetRange("Entry No.", ReservEntry."Entry No.");
                if not PairedEntry.FindFirst() then begin
                    // Try matching via Source fields
                    PairedEntry.Reset();
                    PairedEntry.SetRange("Item No.", ItemNo);
                    PairedEntry.SetRange("Reservation Status", PairedEntry."Reservation Status"::Tracking);
                    PairedEntry.SetFilter("Quantity (Base)", '<0');
                    // Reservation entries are paired: positive supply, negative demand
                    // They share the same Entry No. with opposite signs
                end;

                SupplyEntryNo := FindBufferEntryBySource(
                    TempEventBuffer,
                    ReservEntry."Source Type",
                    ReservEntry."Source ID",
                    ReservEntry."Source Ref. No."
                );

                if PairedEntry.FindFirst() then begin
                    DemandEntryNo := FindBufferEntryBySource(
                        TempEventBuffer,
                        PairedEntry."Source Type",
                        PairedEntry."Source ID",
                        PairedEntry."Source Ref. No."
                    );

                    if (SupplyEntryNo <> 0) and (DemandEntryNo <> 0) then begin
                        TempEventBuffer.Get(SupplyEntryNo);
                        TempEventBuffer."Tracked Against Entry No." := DemandEntryNo;
                        TempEventBuffer.Modify();

                        TempEventBuffer.Get(DemandEntryNo);
                        TempEventBuffer."Tracked Against Entry No." := SupplyEntryNo;
                        TempEventBuffer.Modify();
                    end;
                end;
            until ReservEntry.Next() = 0;
    end;

    local procedure FindBufferEntryBySource(
        var TempEventBuffer: Record "Visualizer Event Buffer" temporary;
        SourceType: Integer;
        SourceId: Code[20];
        SourceRefNo: Integer
    ): Integer
    var
        SavedPosition: Integer;
    begin
        SavedPosition := TempEventBuffer."Entry No.";

        TempEventBuffer.Reset();
        TempEventBuffer.SetRange("Source Document Type", SourceType);
        TempEventBuffer.SetRange("Source Document No.", SourceId);
        TempEventBuffer.SetRange("Source Line No.", SourceRefNo);
        if TempEventBuffer.FindFirst() then begin
            TempEventBuffer.Reset();
            exit(TempEventBuffer."Entry No.");
        end;

        TempEventBuffer.Reset();
        if SavedPosition <> 0 then
            if TempEventBuffer.Get(SavedPosition) then;
        exit(0);
    end;

    local procedure InsertEvent(
        var TempEventBuffer: Record "Visualizer Event Buffer" temporary;
        ItemNo: Code[20];
        LocationCode: Code[10];
        VariantCode: Code[10];
        EventDate: Date;
        EventType: Enum "Inventory Event Type";
        Qty: Decimal;
        IsSupply: Boolean;
        IsSuggestion: Boolean;
        Description: Text[100];
        SourceDocType: Integer;
        SourceDocNo: Code[20];
        SourceLineNo: Integer;
        SourcePageId: Integer
    )
    begin
        NextEntryNo += 1;
        TempEventBuffer.Init();
        TempEventBuffer."Entry No." := NextEntryNo;
        TempEventBuffer."Item No." := ItemNo;
        TempEventBuffer."Location Code" := LocationCode;
        TempEventBuffer."Variant Code" := VariantCode;
        TempEventBuffer."Event Date" := EventDate;
        TempEventBuffer."Event Type" := EventType;
        TempEventBuffer.Quantity := Qty;
        TempEventBuffer."Is Supply" := IsSupply;
        TempEventBuffer."Is Suggestion" := IsSuggestion;
        TempEventBuffer."Source Description" := Description;
        TempEventBuffer."Source Document Type" := SourceDocType;
        TempEventBuffer."Source Document No." := SourceDocNo;
        TempEventBuffer."Source Line No." := SourceLineNo;
        TempEventBuffer."Source Page ID" := SourcePageId;
        TempEventBuffer.Insert();
    end;

    local procedure GetProdOrderPageId(Status: Enum "Production Order Status"): Integer
    begin
        case Status of
            Status::Planned:
                exit(Page::"Planned Production Order");
            Status::"Firm Planned":
                exit(Page::"Firm Planned Prod. Order");
            Status::Released:
                exit(Page::"Released Production Order");
            else
                exit(Page::"Released Production Order");
        end;
    end;
}
