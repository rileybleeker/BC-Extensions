permissionset 50111 "Plan Suggest Admin"
{
    Assignable = true;
    Caption = 'Manage Planning Suggestions';

    Permissions =
        tabledata "Planning Parameter Suggestion" = RIMD,
        tabledata "Planning Analysis Setup" = RIMD,
        tabledata "Demand History Staging" = RIMD,
        tabledata Item = RM,
        table "Planning Parameter Suggestion" = X,
        table "Planning Analysis Setup" = X,
        table "Demand History Staging" = X,
        page "Planning Parameter Suggestions" = X,
        page "Planning Suggestion Card" = X,
        page "Planning Analysis Setup" = X,
        page "Reject Reason Dialog" = X,
        codeunit "Planning Data Collector" = X,
        codeunit "Planning Parameter Calculator" = X,
        codeunit "Planning Suggestion Manager" = X;
}
