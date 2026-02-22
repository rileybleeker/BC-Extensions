page 50160 "Planning Worksheet Visualizer"
{
    PageType = Card;
    ApplicationArea = All;
    Caption = 'Planning Worksheet Visualizer';
    UsageCategory = None;
    Editable = false;

    layout
    {
        area(Content)
        {
            group(Header)
            {
                Caption = 'Item';

                field(ItemNoField; ItemNo)
                {
                    ApplicationArea = All;
                    Caption = 'Item No.';
                    Editable = false;
                    ToolTip = 'The item being visualized.';
                }
                field(ItemDescField; ItemDescription)
                {
                    ApplicationArea = All;
                    Caption = 'Description';
                    Editable = false;
                    ToolTip = 'The item description.';
                }
                field(LocationField; LocationCode)
                {
                    ApplicationArea = All;
                    Caption = 'Location Code';
                    Editable = false;
                    ToolTip = 'The location filter applied.';
                }
                field(VariantField; VariantCode)
                {
                    ApplicationArea = All;
                    Caption = 'Variant Code';
                    Editable = false;
                    ToolTip = 'The variant filter applied.';
                }
            }
            group(PlanningParams)
            {
                Caption = 'Planning Parameters';

                field(PolicyField; ReorderingPolicyText)
                {
                    ApplicationArea = All;
                    Caption = 'Reordering Policy';
                    Editable = false;
                    ToolTip = 'The reordering policy for this item.';
                }
                field(ReorderPointField; ReorderPoint)
                {
                    ApplicationArea = All;
                    Caption = 'Reorder Point';
                    Editable = false;
                    ToolTip = 'The reorder point level.';
                }
                field(SafetyStockField; SafetyStockQty)
                {
                    ApplicationArea = All;
                    Caption = 'Safety Stock';
                    Editable = false;
                    ToolTip = 'The safety stock quantity.';
                }
                field(MaxInventoryField; MaxInventory)
                {
                    ApplicationArea = All;
                    Caption = 'Maximum Inventory';
                    Editable = false;
                    ToolTip = 'The maximum inventory level.';
                }
                field(ReorderQtyField; ReorderQty)
                {
                    ApplicationArea = All;
                    Caption = 'Reorder Quantity';
                    Editable = false;
                    ToolTip = 'The reorder quantity.';
                }
                field(LeadTimeField; LeadTimeDays)
                {
                    ApplicationArea = All;
                    Caption = 'Lead Time (Days)';
                    Editable = false;
                    ToolTip = 'The lead time in days.';
                }
            }
            usercontrol(ChartAddin; "Planning Visualizer Chart")
            {
                ApplicationArea = All;

                trigger OnAddinReady()
                begin
                    AddinReady := true;
                    LoadVisualizerData();
                end;

                trigger OnEventClicked(EntryNo: Integer; SourcePageId: Integer; SourceDocNo: Text; SourceLineNo: Integer)
                begin
                    DrillDownToSource(SourcePageId, SourceDocNo);
                end;

                trigger OnExplanationClicked(ReqLineNo: Integer)
                begin
                    DrillDownToReqLine(ReqLineNo);
                end;

                trigger OnHorizonChanged(Days: Integer)
                begin
                    PlanningHorizonDays := Days;
                    LoadVisualizerData();
                end;
            }
        }
    }

    var
        ItemNo: Code[20];
        ItemDescription: Text[100];
        LocationCode: Code[10];
        VariantCode: Code[10];
        WorksheetTemplateName: Code[10];
        JournalBatchName: Code[10];
        ReorderingPolicyText: Text[50];
        ReorderPoint: Decimal;
        SafetyStockQty: Decimal;
        MaxInventory: Decimal;
        ReorderQty: Decimal;
        LeadTimeDays: Integer;
        PlanningHorizonDays: Integer;
        AddinReady: Boolean;

    procedure SetData(
        NewItemNo: Code[20];
        NewLocationCode: Code[10];
        NewVariantCode: Code[10];
        NewTemplateName: Code[10];
        NewBatchName: Code[10]
    )
    var
        Item: Record Item;
    begin
        ItemNo := NewItemNo;
        LocationCode := NewLocationCode;
        VariantCode := NewVariantCode;
        WorksheetTemplateName := NewTemplateName;
        JournalBatchName := NewBatchName;
        PlanningHorizonDays := 90;

        if Item.Get(ItemNo) then
            ItemDescription := Item.Description;
    end;

    local procedure LoadVisualizerData()
    var
        TempEventBuffer: Record "Visualizer Event Buffer" temporary;
        TempExplanation: Record "Planning Explanation" temporary;
        EventCollector: Codeunit "Inventory Event Collector";
        ProjectionEngine: Codeunit "Inventory Projection Engine";
        ExplanationEngine: Codeunit "Planning Explanation Engine";
        Marshaller: Codeunit "Visualizer Data Marshaller";
        DampenerPeriodText: Text[20];
        DampenerQty: Decimal;
        TimeBucketText: Text[20];
        LotAccumPeriodText: Text[20];
        EndDate: Date;
        ChartJson: Text;
        ExplanationsJson: Text;
    begin
        if not AddinReady then
            exit;

        EndDate := CalcDate(StrSubstNo('<%1D>', PlanningHorizonDays), Today);

        // Step 1: Collect all supply/demand events
        EventCollector.CollectEvents(
            ItemNo, LocationCode, VariantCode,
            Today, EndDate,
            true, WorksheetTemplateName, JournalBatchName,
            TempEventBuffer
        );

        // Step 2: Calculate projections (running totals)
        ProjectionEngine.CalculateProjections(TempEventBuffer);

        // Step 3: Get planning parameters for display and chart thresholds
        ProjectionEngine.GetPlanningParameters(
            ItemNo, LocationCode, VariantCode,
            ReorderPoint, SafetyStockQty, MaxInventory,
            ReorderingPolicyText, ReorderQty, LeadTimeDays,
            DampenerPeriodText, DampenerQty,
            TimeBucketText, LotAccumPeriodText
        );

        // Step 4: Generate explanations
        ExplanationEngine.GenerateExplanations(
            WorksheetTemplateName, JournalBatchName,
            ItemNo, LocationCode, VariantCode,
            TempEventBuffer, TempExplanation
        );

        // Step 5: Marshal to JSON
        ChartJson := Marshaller.BuildChartDataJSON(
            TempEventBuffer,
            ReorderPoint, SafetyStockQty, MaxInventory,
            ReorderQty, LeadTimeDays, ReorderingPolicyText
        );
        ExplanationsJson := Marshaller.BuildExplanationsJSON(TempExplanation);

        // Step 6: Push to ControlAddin
        CurrPage.ChartAddin.LoadChartData(ChartJson);
        CurrPage.ChartAddin.LoadExplanations(ExplanationsJson);
    end;

    local procedure DrillDownToSource(PageId: Integer; DocNo: Text)
    var
        SalesHeader: Record "Sales Header";
        PurchHeader: Record "Purchase Header";
        ProdOrder: Record "Production Order";
        AssemblyHeader: Record "Assembly Header";
        TransferHeader: Record "Transfer Header";
        ServiceHeader: Record "Service Header";
    begin
        if PageId = 0 then
            exit;

        case PageId of
            Page::"Sales Order":
                begin
                    SalesHeader.SetRange("Document Type", SalesHeader."Document Type"::Order);
                    SalesHeader.SetRange("No.", CopyStr(DocNo, 1, 20));
                    if SalesHeader.FindFirst() then
                        Page.Run(Page::"Sales Order", SalesHeader);
                end;
            Page::"Purchase Order":
                begin
                    PurchHeader.SetRange("Document Type", PurchHeader."Document Type"::Order);
                    PurchHeader.SetRange("No.", CopyStr(DocNo, 1, 20));
                    if PurchHeader.FindFirst() then
                        Page.Run(Page::"Purchase Order", PurchHeader);
                end;
            Page::"Released Production Order":
                begin
                    ProdOrder.SetRange(Status, ProdOrder.Status::Released);
                    ProdOrder.SetRange("No.", CopyStr(DocNo, 1, 20));
                    if ProdOrder.FindFirst() then
                        Page.Run(Page::"Released Production Order", ProdOrder);
                end;
            Page::"Firm Planned Prod. Order":
                begin
                    ProdOrder.SetRange(Status, ProdOrder.Status::"Firm Planned");
                    ProdOrder.SetRange("No.", CopyStr(DocNo, 1, 20));
                    if ProdOrder.FindFirst() then
                        Page.Run(Page::"Firm Planned Prod. Order", ProdOrder);
                end;
            Page::"Planned Production Order":
                begin
                    ProdOrder.SetRange(Status, ProdOrder.Status::Planned);
                    ProdOrder.SetRange("No.", CopyStr(DocNo, 1, 20));
                    if ProdOrder.FindFirst() then
                        Page.Run(Page::"Planned Production Order", ProdOrder);
                end;
            Page::"Assembly Order":
                begin
                    AssemblyHeader.SetRange("Document Type", AssemblyHeader."Document Type"::Order);
                    AssemblyHeader.SetRange("No.", CopyStr(DocNo, 1, 20));
                    if AssemblyHeader.FindFirst() then
                        Page.Run(Page::"Assembly Order", AssemblyHeader);
                end;
            Page::"Transfer Order":
                begin
                    TransferHeader.SetRange("No.", CopyStr(DocNo, 1, 20));
                    if TransferHeader.FindFirst() then
                        Page.Run(Page::"Transfer Order", TransferHeader);
                end;
            Page::"Service Order":
                begin
                    ServiceHeader.SetRange("Document Type", ServiceHeader."Document Type"::Order);
                    ServiceHeader.SetRange("No.", CopyStr(DocNo, 1, 20));
                    if ServiceHeader.FindFirst() then
                        Page.Run(Page::"Service Order", ServiceHeader);
                end;
            Page::"Blanket Sales Order":
                begin
                    SalesHeader.SetRange("Document Type", SalesHeader."Document Type"::"Blanket Order");
                    SalesHeader.SetRange("No.", CopyStr(DocNo, 1, 20));
                    if SalesHeader.FindFirst() then
                        Page.Run(Page::"Blanket Sales Order", SalesHeader);
                end;
            Page::"Item Card":
                begin
                    Page.Run(Page::"Item Card");
                end;
        end;
    end;

    local procedure DrillDownToReqLine(ReqLineNo: Integer)
    var
        ReqLine: Record "Requisition Line";
    begin
        ReqLine.SetRange("Worksheet Template Name", WorksheetTemplateName);
        ReqLine.SetRange("Journal Batch Name", JournalBatchName);
        ReqLine.SetRange("Line No.", ReqLineNo);
        if ReqLine.FindFirst() then
            Page.Run(0, ReqLine);
    end;
}
