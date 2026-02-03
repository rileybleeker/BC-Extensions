page 50102 "CSV Sales Order Import"
{
    PageType = Card;
    ApplicationArea = All;
    UsageCategory = Tasks;
    Caption = 'Import Sales Order from CSV';

    layout
    {
        area(Content)
        {
            group(Instructions)
            {
                Caption = 'Instructions';

                field(InstructionText; InstructionLbl)
                {
                    ApplicationArea = All;
                    Editable = false;
                    ShowCaption = false;
                    MultiLine = true;
                }
            }
        }
    }

    actions
    {
        area(Processing)
        {
            action(ImportCSV)
            {
                Caption = 'Select CSV File and Import';
                Image = Import;
                Promoted = true;
                PromotedCategory = Process;
                PromotedIsBig = true;
                PromotedOnly = true;

                trigger OnAction()
                var
                    ImportMgt: Codeunit "CSV Sales Order Import";
                begin
                    ImportMgt.ImportFromFile();
                end;
            }
            action(OpenSetup)
            {
                Caption = 'Manufacturing Setup';
                Image = Setup;
                Promoted = true;
                PromotedCategory = Process;
                PromotedOnly = true;

                trigger OnAction()
                var
                    MfgSetup: Record "Manufacturing Setup";
                begin
                    if MfgSetup.Get() then
                        Page.Run(Page::"Manufacturing Setup", MfgSetup);
                end;
            }
        }
    }

    var
        InstructionLbl: Label 'CSV File Format:\Color,Size,Quantity\RED,M,10\BLUE,L,5\\Before importing, configure the default customer in Manufacturing Setup.\\Click "Select CSV File and Import" to begin.';
}
