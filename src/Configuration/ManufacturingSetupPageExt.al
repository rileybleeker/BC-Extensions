pageextension 50103 "Manufacturing Setup Ext" extends "Manufacturing Setup"
{
    layout
    {
        addlast(General)
        {
            field("Upper Tolerance"; Rec."Upper Tolerance")
            {
                ApplicationArea = All;
                ToolTip = 'Specifies the upper tolerance percentage for production order lines.';
            }
            group("Inventory Alerts")
            {
                Caption = 'Low Inventory Alert Integration';

                field("Enable Inventory Alerts"; Rec."Enable Inventory Alerts")
                {
                    ApplicationArea = All;
                    ToolTip = 'Enable automatic alerts when inventory drops below safety stock.';
                }
                field("Logic Apps Endpoint URL"; Rec."Logic Apps Endpoint URL")
                {
                    ApplicationArea = All;
                    ToolTip = 'Azure Logic Apps HTTP endpoint URL for inventory alerts.';
                    Enabled = Rec."Enable Inventory Alerts";
                }
                field("Logic Apps API Key"; Rec."Logic Apps API Key")
                {
                    ApplicationArea = All;
                    ToolTip = 'API key for authenticating with Azure Logic Apps.';
                    Enabled = Rec."Enable Inventory Alerts";
                }
            }
            group("CSV Sales Order Import")
            {
                Caption = 'CSV Sales Order Import Settings';

                field("CSV Import Customer No."; Rec."CSV Import Customer No.")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the default customer for CSV sales order imports.';
                }
                field("CSV Item Template Code"; Rec."CSV Item Template Code")
                {
                    ApplicationArea = All;
                    ToolTip = 'Optional: Item template for auto-created items. If blank, creates basic items with No. and Description only.';
                }
            }
            group(VendorPerformanceSettings)
            {
                Caption = 'Vendor Performance Settings';

                group(ScoreWeights)
                {
                    Caption = 'Score Weights (must sum to 100%)';

                    field("On-Time Delivery Weight"; Rec."On-Time Delivery Weight")
                    {
                        ApplicationArea = All;
                        ToolTip = 'Weight for on-time delivery in overall score calculation (default 30%).';
                    }
                    field("Quality Weight"; Rec."Quality Weight")
                    {
                        ApplicationArea = All;
                        ToolTip = 'Weight for quality acceptance rate in overall score calculation (default 30%).';
                    }
                    field("Lead Time Reliability Weight"; Rec."Lead Time Reliability Weight")
                    {
                        ApplicationArea = All;
                        ToolTip = 'Weight for lead time reliability in overall score calculation (default 25%).';
                    }
                    field("Price Stability Weight"; Rec."Price Stability Weight")
                    {
                        ApplicationArea = All;
                        ToolTip = 'Weight for price stability in overall score calculation (default 15%).';
                    }
                }
                group(Tolerances)
                {
                    Caption = 'Tolerances';

                    field("On-Time Tolerance Days"; Rec."On-Time Tolerance Days")
                    {
                        ApplicationArea = All;
                        ToolTip = 'Number of days before/after promised date that is still considered on-time (default 2).';
                    }
                    field("Lead Time Variance Tolerance %"; Rec."Lead Time Variance Tolerance %")
                    {
                        ApplicationArea = All;
                        ToolTip = 'Percentage variance from promised lead time that is acceptable (default 10%).';
                    }
                    field("Auto-Approve Score Threshold"; Rec."Auto-Approve Score Threshold")
                    {
                        ApplicationArea = All;
                        ToolTip = 'Minimum vendor score to auto-approve purchase suggestions (default 80).';
                    }
                }
                group(RiskThresholds)
                {
                    Caption = 'Risk Level Thresholds';

                    field("Low Risk Score Threshold"; Rec."Low Risk Score Threshold")
                    {
                        ApplicationArea = All;
                        ToolTip = 'Minimum score for Low risk level (default 80).';
                    }
                    field("Medium Risk Score Threshold"; Rec."Medium Risk Score Threshold")
                    {
                        ApplicationArea = All;
                        ToolTip = 'Minimum score for Medium risk level (default 60).';
                    }
                    field("High Risk Score Threshold"; Rec."High Risk Score Threshold")
                    {
                        ApplicationArea = All;
                        ToolTip = 'Minimum score for High risk level (default 40). Below this is Critical.';
                    }
                }
                group(CalculationSettings)
                {
                    Caption = 'Calculation Settings';

                    field("Perf Calc Period Months"; Rec."Perf Calc Period Months")
                    {
                        ApplicationArea = All;
                        ToolTip = 'Number of months of historical data to use for calculations (default 12).';
                    }
                    field("Auto-Recalc on Receipt"; Rec."Auto-Recalc on Receipt")
                    {
                        ApplicationArea = All;
                        ToolTip = 'Automatically recalculate vendor performance when a receipt is posted.';
                    }
                }
                group(NCRSettings)
                {
                    Caption = 'Non-Conformance Report Settings';

                    field("Auto-Create NCR from Quality"; Rec."Auto-Create NCR from Quality")
                    {
                        ApplicationArea = All;
                        ToolTip = 'Automatically create a Vendor NCR when a Quality Order fails.';
                    }
                    field("NCR No. Series"; Rec."NCR No. Series")
                    {
                        ApplicationArea = All;
                        ToolTip = 'Number series for Vendor NCR documents.';
                    }
                }
            }
        }
    }
}
