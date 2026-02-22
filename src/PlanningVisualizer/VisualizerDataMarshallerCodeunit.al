codeunit 50163 "Visualizer Data Marshaller"
{
    // Serializes temp table data into JSON for the ControlAddin

    procedure BuildChartDataJSON(
        var TempEventBuffer: Record "Inventory Event Buffer" temporary;
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

        // Events and projections
        TempEventBuffer.Reset();
        TempEventBuffer.SetCurrentKey("Event Date", "Entry No.");

        LastBeforeDate := 0D;
        LastAfterDate := 0D;

        if TempEventBuffer.FindSet() then
            repeat
                // Event data
                Clear(EventObj);
                EventObj.Add('entryNo', TempEventBuffer."Entry No.");
                EventObj.Add('date', Format(TempEventBuffer."Event Date", 0, '<Year4>-<Month,2>-<Day,2>'));
                EventObj.Add('type', Format(TempEventBuffer."Event Type"));
                EventObj.Add('qty', TempEventBuffer.Quantity);
                EventObj.Add('isSupply', TempEventBuffer."Is Supply");
                EventObj.Add('isSuggestion', TempEventBuffer."Is Suggestion");
                EventObj.Add('description', TempEventBuffer."Source Description");
                EventObj.Add('sourcePageId', TempEventBuffer."Source Page ID");
                EventObj.Add('sourceDocNo', TempEventBuffer."Source Document No.");
                EventObj.Add('sourceLineNo', TempEventBuffer."Source Line No.");
                EventObj.Add('actionMessage', TempEventBuffer."Action Message");
                EventObj.Add('balanceBefore', TempEventBuffer."Running Total Before");
                EventObj.Add('balanceAfter', TempEventBuffer."Running Total After");
                if TempEventBuffer."Tracked Against Entry No." <> 0 then
                    EventObj.Add('trackedAgainst', TempEventBuffer."Tracked Against Entry No.");
                EventsArr.Add(EventObj);

                // Before projection points (only add when balance changes)
                if TempEventBuffer."Event Date" <> LastBeforeDate then begin
                    Clear(ProjectionObj);
                    ProjectionObj.Add('date', Format(TempEventBuffer."Event Date", 0, '<Year4>-<Month,2>-<Day,2>'));
                    ProjectionObj.Add('balance', TempEventBuffer."Running Total Before");
                    ProjectionBeforeArr.Add(ProjectionObj);
                    LastBeforeDate := TempEventBuffer."Event Date";
                end else begin
                    // Update the last projection point if multiple events on same date
                    UpdateLastProjectionPoint(ProjectionBeforeArr, TempEventBuffer."Running Total Before");
                end;

                // After projection points
                if TempEventBuffer."Event Date" <> LastAfterDate then begin
                    Clear(ProjectionObj);
                    ProjectionObj.Add('date', Format(TempEventBuffer."Event Date", 0, '<Year4>-<Month,2>-<Day,2>'));
                    ProjectionObj.Add('balance', TempEventBuffer."Running Total After");
                    ProjectionAfterArr.Add(ProjectionObj);
                    LastAfterDate := TempEventBuffer."Event Date";
                end else begin
                    UpdateLastProjectionPoint(ProjectionAfterArr, TempEventBuffer."Running Total After");
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
