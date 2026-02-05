permissionset 50110 "Plan Suggest View"
{
    Assignable = true;
    Caption = 'View Planning Suggestions';

    Permissions =
        tabledata "Planning Parameter Suggestion" = R,
        tabledata "Planning Analysis Setup" = R,
        tabledata "Demand History Staging" = R,
        table "Planning Parameter Suggestion" = X,
        table "Planning Analysis Setup" = X,
        table "Demand History Staging" = X,
        page "Planning Parameter Suggestions" = X,
        page "Planning Suggestion Card" = X,
        page "Planning Analysis Setup" = X,
        codeunit "Planning Data Collector" = X,
        codeunit "Planning Parameter Calculator" = X,
        codeunit "Planning Suggestion Manager" = X;
}
