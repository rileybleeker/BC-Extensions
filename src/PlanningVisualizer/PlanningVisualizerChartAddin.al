controladdin "Planning Visualizer Chart"
{
    RequestedHeight = 700;
    RequestedWidth = 1200;
    MinimumHeight = 500;
    MinimumWidth = 800;
    MaximumHeight = 1200;
    MaximumWidth = 1800;
    VerticalStretch = true;
    HorizontalStretch = true;

    Scripts =
        'src/PlanningVisualizer/scripts/chart.min.js',
        'src/PlanningVisualizer/scripts/chartjs-plugin-annotation.min.js',
        'src/PlanningVisualizer/scripts/PlanningVisualizerChart.js';

    StartupScript =
        'src/PlanningVisualizer/scripts/PlanningVisualizerStartup.js';

    StyleSheets =
        'src/PlanningVisualizer/styles/PlanningVisualizer.css';

    // AL -> JS procedures
    procedure LoadChartData(ChartDataJson: Text);
    procedure LoadExplanations(ExplanationsJson: Text);
    procedure UpdateVisibility(ShowExisting: Boolean; ShowSuggested: Boolean; ShowDemand: Boolean);
    procedure ToggleProjection(ShowBefore: Boolean; ShowAfter: Boolean);
    procedure HighlightEvent(EntryNo: Integer);
    procedure ShowTrackingLines(Visible: Boolean);
    procedure ShowCoverageBars(Visible: Boolean);

    // JS -> AL events
    event OnAddinReady();
    event OnEventClicked(EntryNo: Integer; SourcePageId: Integer; SourceDocNo: Text; SourceLineNo: Integer);
    event OnExplanationClicked(ReqLineNo: Integer);
    event OnHorizonChanged(Days: Integer);
}
