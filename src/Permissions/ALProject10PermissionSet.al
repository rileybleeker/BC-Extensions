permissionset 50100 "ALProject10"
{
    Caption = 'ALProject10 Full Access';
    Assignable = true;

    Permissions =
        table "Quality Order" = X,
        tabledata "Quality Order" = RIMD,
        table "Inventory Alert Log" = X,
        tabledata "Inventory Alert Log" = RIMD,
        table "CSV Import Buffer" = X,
        tabledata "CSV Import Buffer" = RIMD,
        table "Planning Parameter Suggestion" = X,
        tabledata "Planning Parameter Suggestion" = RIMD,
        table "Demand History Staging" = X,
        tabledata "Demand History Staging" = RIMD,
        table "Planning Analysis Setup" = X,
        tabledata "Planning Analysis Setup" = RIMD,
        table "Vendor Performance" = X,
        tabledata "Vendor Performance" = RIMD,
        table "Lead Time Variance Entry" = X,
        tabledata "Lead Time Variance Entry" = RIMD,
        table "Vendor NCR" = X,
        tabledata "Vendor NCR" = RIMD,
        table "Purchase Suggestion" = X,
        tabledata "Purchase Suggestion" = RIMD,
        table "Vendor Ranking" = X,
        tabledata "Vendor Ranking" = RIMD,
        table "Visualizer Event Buffer" = X,
        tabledata "Visualizer Event Buffer" = RIMD,
        table "Planning Explanation" = X,
        tabledata "Planning Explanation" = RIMD;
}
