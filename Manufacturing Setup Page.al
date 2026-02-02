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
        }
    }
}
