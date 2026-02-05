page 50115 "Test Data Generator"
{
    // TEMPORARY PAGE - REMOVE AFTER TESTING
    PageType = Card;
    Caption = 'Test Data Generator (TEMP)';
    ApplicationArea = All;
    UsageCategory = Administration;

    layout
    {
        area(Content)
        {
            group(Instructions)
            {
                Caption = 'Instructions';

                field(InstructionText; InstructionText)
                {
                    ApplicationArea = All;
                    Caption = '';
                    Editable = false;
                    MultiLine = true;
                    ShowCaption = false;
                }
            }
            group(Options)
            {
                Caption = 'Options';

                field(ItemNo; ItemNo)
                {
                    ApplicationArea = All;
                    Caption = 'Item No.';
                    ToolTip = 'Leave blank to create test item TEST-PLAN-001, or enter existing item.';
                    TableRelation = Item;
                }
                field(LocationCode; LocationCode)
                {
                    ApplicationArea = All;
                    Caption = 'Location Code';
                    ToolTip = 'Leave blank to use first available location.';
                    TableRelation = Location;
                }
                field(InitialInventory; InitialInventory)
                {
                    ApplicationArea = All;
                    Caption = 'Initial Inventory Qty';
                    ToolTip = 'Quantity to add as initial inventory.';
                    MinValue = 100;
                }
                field(MonthsOfHistory; MonthsOfHistory)
                {
                    ApplicationArea = All;
                    Caption = 'Months of Sales History';
                    ToolTip = 'Number of months of historical sales to generate.';
                    MinValue = 3;
                    MaxValue = 24;
                }
            }
        }
    }

    actions
    {
        area(Processing)
        {
            action(GenerateData)
            {
                ApplicationArea = All;
                Caption = 'Generate Test Data';
                Image = CreateDocument;
                ToolTip = 'Generate inventory and sales transactions for testing.';

                trigger OnAction()
                var
                    TestDataGen: Codeunit "Test Data Generator";
                begin
                    if not Confirm('This will create inventory adjustments and post sales orders.\Continue?') then
                        exit;

                    TestDataGen.GenerateTestDataWithParams(ItemNo, LocationCode, InitialInventory, MonthsOfHistory);
                end;
            }
            action(QuickGenerate)
            {
                ApplicationArea = All;
                Caption = 'Quick Generate (Defaults)';
                Image = Start;
                ToolTip = 'Generate test data with default settings (new item, 1000 qty, 6 months).';

                trigger OnAction()
                var
                    TestDataGen: Codeunit "Test Data Generator";
                begin
                    if not Confirm('This will create a test item with inventory and 6 months of sales history.\Continue?') then
                        exit;

                    TestDataGen.GenerateTestData();
                end;
            }
            action(Cleanup)
            {
                ApplicationArea = All;
                Caption = 'Cleanup Test Data';
                Image = Delete;
                ToolTip = 'Block the test item and customer. Note: Ledger entries cannot be deleted.';

                trigger OnAction()
                var
                    TestDataGen: Codeunit "Test Data Generator";
                begin
                    if not Confirm('This will block the test item and customer.\Continue?') then
                        exit;

                    TestDataGen.CleanupTestData();
                end;
            }
        }
        area(Promoted)
        {
            group(Category_Process)
            {
                Caption = 'Process';

                actionref(QuickGenerate_Promoted; QuickGenerate) { }
                actionref(GenerateData_Promoted; GenerateData) { }
                actionref(Cleanup_Promoted; Cleanup) { }
            }
        }
    }

    trigger OnOpenPage()
    begin
        InstructionText := 'This page generates test data for the Planning Parameter Suggestion system.' +
            '\' +
            '\It will:' +
            '\1. Create or use an item with Planning Suggestion Enabled' +
            '\2. Add initial inventory via positive adjustment' +
            '\3. Create and post sales orders over several months' +
            '\' +
            '\After testing, use Cleanup to block test records.' +
            '\' +
            '\DELETE THIS PAGE AND CODEUNIT 50199 AFTER TESTING.';

        InitialInventory := 1000;
        MonthsOfHistory := 6;
    end;

    var
        ItemNo: Code[20];
        LocationCode: Code[10];
        InitialInventory: Decimal;
        MonthsOfHistory: Integer;
        InstructionText: Text;
}
