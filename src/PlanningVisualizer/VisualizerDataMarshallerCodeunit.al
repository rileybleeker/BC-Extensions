codeunit 50163 "Visualizer Data Marshaller"
{
    // Serializes temp table data into JSON for the ControlAddin

    procedure BuildChartDataJSON(
        var TempEventBuffer: Record "Visualizer Event Buffer" temporary;
        var TempCoverageBuffer: Record "Suggestion Coverage Buffer" temporary;
        ReorderPoint: Decimal;
        SafetyStock: Decimal;
        MaxInventory: Decimal;
        ReorderQty: Decimal;
        LeadTimeDays: Integer;
        ReorderingPolicyText: Text[50]
    ): Text
    var
        RootObj: JsonObject;
        ThresholdsObj: JsonObject;
        PlanningParamsObj: JsonObject;
        EventsArr: JsonArray;
        ProjectionBeforeArr: JsonArray;
        ProjectionAfterArr: JsonArray;
        TrackingArr: JsonArray;
        EventObj: JsonObject;
        ProjectionObj: JsonObject;
        TrackingObj: JsonObject;
        LastBeforeDate: Date;
        LastAfterDate: Date;
        RunningBefore: Decimal;
        RunningAfter: Decimal;
        ResultText: Text;
    begin
        // Thresholds
        ThresholdsObj.Add('reorderPoint', ReorderPoint);
        ThresholdsObj.Add('safetyStock', SafetyStock);
        ThresholdsObj.Add('maxInventory', MaxInventory);
        RootObj.Add('thresholds', ThresholdsObj);

        // Planning parameters
        PlanningParamsObj.Add('reorderingPolicy', ReorderingPolicyText);
        PlanningParamsObj.Add('reorderQty', ReorderQty);
        PlanningParamsObj.Add('leadTimeDays', LeadTimeDays);
        RootObj.Add('planningParams', PlanningParamsObj);

        // Events and projections - compute running totals inline to avoid
        // dependency on pre-computed values from the projection engine
        TempEventBuffer.Reset();
        TempEventBuffer.SetCurrentKey("Event Date", "Entry No.");

        LastBeforeDate := 0D;
        LastAfterDate := 0D;
        RunningBefore := 0;
        RunningAfter := 0;

        if TempEventBuffer.FindSet() then
            repeat
                // Compute running totals inline
                if not TempEventBuffer."Is Informational" then begin
                    RunningAfter += TempEventBuffer.Quantity;
                    if not TempEventBuffer."Is Suggestion" then
                        RunningBefore += TempEventBuffer.Quantity;
                end;

                // Event data
                Clear(EventObj);
                EventObj.Add('entryNo', TempEventBuffer."Entry No.");
                EventObj.Add('date', Format(TempEventBuffer."Event Date", 0, '<Year4>-<Month,2>-<Day,2>'));
                EventObj.Add('type', Format(TempEventBuffer."Event Type"));
                EventObj.Add('qty', TempEventBuffer.Quantity);
                EventObj.Add('isSupply', TempEventBuffer."Is Supply");
                EventObj.Add('isSuggestion', TempEventBuffer."Is Suggestion");
                EventObj.Add('isInformational', TempEventBuffer."Is Informational");
                EventObj.Add('description', TempEventBuffer."Source Description");
                EventObj.Add('sourcePageId', TempEventBuffer."Source Page ID");
                EventObj.Add('sourceDocNo', TempEventBuffer."Source Document No.");
                EventObj.Add('sourceLineNo', TempEventBuffer."Source Line No.");
                EventObj.Add('actionMessage', TempEventBuffer."Action Message");
                EventObj.Add('balanceBefore', RunningBefore);
                EventObj.Add('balanceAfter', RunningAfter);
                if TempEventBuffer."Tracked Against Entry No." <> 0 then
                    EventObj.Add('trackedAgainst', TempEventBuffer."Tracked Against Entry No.");
                EventsArr.Add(EventObj);

                // Before projection points
                if TempEventBuffer."Event Date" <> LastBeforeDate then begin
                    Clear(ProjectionObj);
                    ProjectionObj.Add('date', Format(TempEventBuffer."Event Date", 0, '<Year4>-<Month,2>-<Day,2>'));
                    ProjectionObj.Add('balance', RunningBefore);
                    ProjectionBeforeArr.Add(ProjectionObj);
                    LastBeforeDate := TempEventBuffer."Event Date";
                end else begin
                    UpdateLastProjectionPoint(ProjectionBeforeArr, RunningBefore);
                end;

                // After projection points
                if TempEventBuffer."Event Date" <> LastAfterDate then begin
                    Clear(ProjectionObj);
                    ProjectionObj.Add('date', Format(TempEventBuffer."Event Date", 0, '<Year4>-<Month,2>-<Day,2>'));
                    ProjectionObj.Add('balance', RunningAfter);
                    ProjectionAfterArr.Add(ProjectionObj);
                    LastAfterDate := TempEventBuffer."Event Date";
                end else begin
                    UpdateLastProjectionPoint(ProjectionAfterArr, RunningAfter);
                end;

                // Tracking pairs
                if TempEventBuffer."Tracked Against Entry No." <> 0 then
                    if TempEventBuffer."Is Supply" then begin
                        Clear(TrackingObj);
                        TrackingObj.Add('supplyEntryNo', TempEventBuffer."Entry No.");
                        TrackingObj.Add('demandEntryNo', TempEventBuffer."Tracked Against Entry No.");
                        TrackingArr.Add(TrackingObj);
                    end;
            until TempEventBuffer.Next() = 0;

        RootObj.Add('events', EventsArr);
        RootObj.Add('projectionBefore', ProjectionBeforeArr);
        RootObj.Add('projectionAfter', ProjectionAfterArr);
        RootObj.Add('trackingPairs', TrackingArr);

        // Coverage bars
        RootObj.Add('coverageBars', BuildCoverageArray(TempCoverageBuffer));

        RootObj.WriteTo(ResultText);
        exit(ResultText);
    end;

    procedure BuildExplanationsJSON(
        var TempExplanation: Record "Planning Explanation" temporary
    ): Text
    var
        RootObj: JsonObject;
        ExplanationsArr: JsonArray;
        ExplObj: JsonObject;
        ResultText: Text;
    begin
        TempExplanation.Reset();
        if TempExplanation.FindSet() then
            repeat
                Clear(ExplObj);
                ExplObj.Add('entryNo', TempExplanation."Entry No.");
                ExplObj.Add('reqLineNo', TempExplanation."Req. Line No.");
                ExplObj.Add('itemNo', TempExplanation."Item No.");
                ExplObj.Add('action', TempExplanation."Action Message");
                ExplObj.Add('summary', TempExplanation."Summary Text");
                ExplObj.Add('detail', TempExplanation."Detail Text");
                ExplObj.Add('why', TempExplanation."Why Text");
                ExplObj.Add('impact', TempExplanation."Impact Text");
                ExplObj.Add('dueDate', Format(TempExplanation."Due Date", 0, '<Year4>-<Month,2>-<Day,2>'));
                ExplObj.Add('qty', TempExplanation.Quantity);
                ExplObj.Add('severity', TempExplanation.Severity);
                ExplObj.Add('reorderingPolicy', TempExplanation."Reordering Policy");
                ExplanationsArr.Add(ExplObj);
            until TempExplanation.Next() = 0;

        RootObj.Add('explanations', ExplanationsArr);
        RootObj.WriteTo(ResultText);
        exit(ResultText);
    end;

    local procedure BuildCoverageArray(
        var TempCoverageBuffer: Record "Suggestion Coverage Buffer" temporary
    ): JsonArray
    var
        CoverageArr: JsonArray;
        CoverageObj: JsonObject;
        TrackedArr: JsonArray;
        TrackedObj: JsonObject;
        UntrackedArr: JsonArray;
        UntrackedObj: JsonObject;
        CurrentReqLineNo: Integer;
        LatestDemandDate: Date;
        HasData: Boolean;
    begin
        CurrentReqLineNo := 0;
        HasData := false;

        TempCoverageBuffer.Reset();
        TempCoverageBuffer.SetCurrentKey("Req. Line No.", "Demand Date");

        if TempCoverageBuffer.FindSet() then
            repeat
                if TempCoverageBuffer."Req. Line No." <> CurrentReqLineNo then begin
                    // Flush previous group
                    if HasData then begin
                        CoverageObj.Add('trackedDemand', TrackedArr);
                        CoverageObj.Add('untrackedElements', UntrackedArr);
                        if LatestDemandDate <> 0D then
                            CoverageObj.Add('endDate', Format(LatestDemandDate, 0, '<Year4>-<Month,2>-<Day,2>'));
                        CoverageArr.Add(CoverageObj);
                    end;

                    // Start new group
                    HasData := true;
                    CurrentReqLineNo := TempCoverageBuffer."Req. Line No.";
                    LatestDemandDate := TempCoverageBuffer."Supply Date";
                    Clear(CoverageObj);
                    Clear(TrackedArr);
                    Clear(UntrackedArr);
                    CoverageObj.Add('reqLineNo', TempCoverageBuffer."Req. Line No.");
                    CoverageObj.Add('supplyDate',
                        Format(TempCoverageBuffer."Supply Date", 0, '<Year4>-<Month,2>-<Day,2>'));
                    CoverageObj.Add('supplyQty', TempCoverageBuffer."Supply Qty");
                    CoverageObj.Add('actionMessage', TempCoverageBuffer."Action Message");
                    if TempCoverageBuffer."Order Starting Date" <> 0D then
                        CoverageObj.Add('orderStartDate',
                            Format(TempCoverageBuffer."Order Starting Date", 0, '<Year4>-<Month,2>-<Day,2>'));
                    if TempCoverageBuffer."Order Ending Date" <> 0D then
                        CoverageObj.Add('orderEndDate',
                            Format(TempCoverageBuffer."Order Ending Date", 0, '<Year4>-<Month,2>-<Day,2>'));
                    CoverageObj.Add('startDate',
                        Format(TempCoverageBuffer."Supply Date", 0, '<Year4>-<Month,2>-<Day,2>'));
                end;

                if TempCoverageBuffer."Is Untracked" then begin
                    Clear(UntrackedObj);
                    UntrackedObj.Add('source', TempCoverageBuffer."Untracked Source");
                    UntrackedObj.Add('qty', TempCoverageBuffer."Demand Qty");
                    UntrackedArr.Add(UntrackedObj);
                end else begin
                    Clear(TrackedObj);
                    TrackedObj.Add('date',
                        Format(TempCoverageBuffer."Demand Date", 0, '<Year4>-<Month,2>-<Day,2>'));
                    TrackedObj.Add('qty', TempCoverageBuffer."Demand Qty");
                    TrackedObj.Add('source', TempCoverageBuffer."Demand Source");
                    TrackedArr.Add(TrackedObj);

                    if TempCoverageBuffer."Demand Date" > LatestDemandDate then
                        LatestDemandDate := TempCoverageBuffer."Demand Date";
                end;
            until TempCoverageBuffer.Next() = 0;

        // Flush last group
        if HasData then begin
            CoverageObj.Add('trackedDemand', TrackedArr);
            CoverageObj.Add('untrackedElements', UntrackedArr);
            if LatestDemandDate <> 0D then
                CoverageObj.Add('endDate', Format(LatestDemandDate, 0, '<Year4>-<Month,2>-<Day,2>'));
            CoverageArr.Add(CoverageObj);
        end;

        exit(CoverageArr);
    end;

    local procedure UpdateLastProjectionPoint(var ProjectionArr: JsonArray; NewBalance: Decimal)
    var
        LastToken: JsonToken;
        LastObj: JsonObject;
        NewObj: JsonObject;
        DateToken: JsonToken;
        DateText: Text;
    begin
        if ProjectionArr.Count() = 0 then
            exit;

        ProjectionArr.Get(ProjectionArr.Count() - 1, LastToken);
        LastObj := LastToken.AsObject();
        LastObj.Get('date', DateToken);
        DateText := DateToken.AsValue().AsText();

        // Replace the last element with updated balance
        Clear(NewObj);
        NewObj.Add('date', DateText);
        NewObj.Add('balance', NewBalance);
        ProjectionArr.RemoveAt(ProjectionArr.Count() - 1);
        ProjectionArr.Add(NewObj);
    end;
}
