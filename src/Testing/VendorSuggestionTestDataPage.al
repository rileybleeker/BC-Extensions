page 50116 "Vendor Suggestion Test Data"
{
    PageType = Card;
    Caption = 'Vendor Suggestion Test Data Generator';
    UsageCategory = Administration;
    ApplicationArea = All;
    SourceTable = Integer;
    SourceTableTemporary = true;

    layout
    {
        area(Content)
        {
            group(Status)
            {
                Caption = 'Current Test Data Status';

                field(VendorCount; VendorCount)
                {
                    ApplicationArea = All;
                    Caption = 'Test Vendors (VEND-TEST-*)';
                    Editable = false;
                    Style = Strong;
                    ToolTip = 'Number of test vendors currently in the system';
                }
                field(ItemCount; ItemCount)
                {
                    ApplicationArea = All;
                    Caption = 'Test Items (ITEM-VSTEST-*)';
                    Editable = false;
                    Style = Strong;
                    ToolTip = 'Number of test items currently in the system';
                }
                field(ItemVendorCount; ItemVendorCount)
                {
                    ApplicationArea = All;
                    Caption = 'Item-Vendor Links';
                    Editable = false;
                    Style = Strong;
                    ToolTip = 'Number of item-vendor relationships for test items';
                }
            }
            group(TestData)
            {
                Caption = 'Test Data Overview';

                field(VendorInfo; VendorInfoText)
                {
                    ApplicationArea = All;
                    Caption = 'Vendors';
                    Editable = false;
                    MultiLine = true;
                    ToolTip = 'Overview of test vendor profiles';
                }
                field(ItemInfo; ItemInfoText)
                {
                    ApplicationArea = All;
                    Caption = 'Items';
                    Editable = false;
                    MultiLine = true;
                    ToolTip = 'Overview of test items and their purposes';
                }
            }
            group(ExpectedResults)
            {
                Caption = 'Expected Scoring Results';

                field(ExpectedScores; ExpectedScoresText)
                {
                    ApplicationArea = All;
                    Caption = 'For ITEM-VSTEST-01 (Due Date = Today + 14)';
                    Editable = false;
                    MultiLine = true;
                    ToolTip = 'Expected vendor scores for verification';
                }
            }
        }
    }

    actions
    {
        area(Processing)
        {
            group(Generate)
            {
                Caption = 'Generate';

                action(GenerateAll)
                {
                    ApplicationArea = All;
                    Caption = 'Generate All Test Data';
                    Image = CreateDocument;
                    ToolTip = 'Generate all test vendors, items, item-vendor links, and performance data';

                    trigger OnAction()
                    var
                        TestDataGen: Codeunit "Vendor Suggestion Test Data";
                    begin
                        TestDataGen.GenerateAllTestData();
                        RefreshCounts();
                        CurrPage.Update(false);
                    end;
                }
                action(GenerateVendors)
                {
                    ApplicationArea = All;
                    Caption = 'Generate Vendors Only';
                    Image = Vendor;
                    ToolTip = 'Generate only the test vendors';

                    trigger OnAction()
                    var
                        TestDataGen: Codeunit "Vendor Suggestion Test Data";
                    begin
                        TestDataGen.GenerateTestVendors();
                        RefreshCounts();
                        CurrPage.Update(false);
                    end;
                }
                action(GenerateItems)
                {
                    ApplicationArea = All;
                    Caption = 'Generate Items Only';
                    Image = Item;
                    ToolTip = 'Generate only the test items';

                    trigger OnAction()
                    var
                        TestDataGen: Codeunit "Vendor Suggestion Test Data";
                    begin
                        TestDataGen.GenerateTestItems();
                        RefreshCounts();
                        CurrPage.Update(false);
                    end;
                }
                action(GenerateItemVendors)
                {
                    ApplicationArea = All;
                    Caption = 'Generate Item-Vendor Links';
                    Image = Relationship;
                    ToolTip = 'Generate item-vendor relationships with lead times and costs';

                    trigger OnAction()
                    var
                        TestDataGen: Codeunit "Vendor Suggestion Test Data";
                    begin
                        TestDataGen.GenerateItemVendorRecords();
                        RefreshCounts();
                        CurrPage.Update(false);
                    end;
                }
                action(GeneratePerformance)
                {
                    ApplicationArea = All;
                    Caption = 'Generate Performance Data';
                    Image = Statistics;
                    ToolTip = 'Generate vendor performance records';

                    trigger OnAction()
                    var
                        TestDataGen: Codeunit "Vendor Suggestion Test Data";
                    begin
                        TestDataGen.GenerateVendorPerformanceData();
                        RefreshCounts();
                        CurrPage.Update(false);
                    end;
                }
                action(GenerateSubstitutions)
                {
                    ApplicationArea = All;
                    Caption = 'Generate Item Substitutions';
                    Image = Change;
                    ToolTip = 'Generate item substitution records';

                    trigger OnAction()
                    var
                        TestDataGen: Codeunit "Vendor Suggestion Test Data";
                    begin
                        TestDataGen.GenerateItemSubstitutions();
                        RefreshCounts();
                        CurrPage.Update(false);
                    end;
                }
            }
            group(Cleanup)
            {
                Caption = 'Cleanup';

                action(CleanupAll)
                {
                    ApplicationArea = All;
                    Caption = 'Cleanup All Test Data';
                    Image = Delete;
                    ToolTip = 'Block test vendors and items, delete related records';

                    trigger OnAction()
                    var
                        TestDataGen: Codeunit "Vendor Suggestion Test Data";
                    begin
                        if not Confirm('This will block all test vendors and items, and delete item-vendor links, performance records, and substitutions.\Do you want to continue?') then
                            exit;

                        TestDataGen.CleanupAllTestData();
                        RefreshCounts();
                        CurrPage.Update(false);
                    end;
                }
            }
        }
        area(Navigation)
        {
            action(ViewTestVendors)
            {
                ApplicationArea = All;
                Caption = 'View Test Vendors';
                Image = Vendor;
                ToolTip = 'Open the Vendor List filtered to test vendors';
                RunObject = page "Vendor List";
                RunPageView = where("No." = filter('VEND-TEST-*'));
            }
            action(ViewTestItems)
            {
                ApplicationArea = All;
                Caption = 'View Test Items';
                Image = Item;
                ToolTip = 'Open the Item List filtered to test items';
                RunObject = page "Item List";
                RunPageView = where("No." = filter('ITEM-VSTEST-*'));
            }
            action(ViewVendorPerformance)
            {
                ApplicationArea = All;
                Caption = 'View Vendor Performance';
                Image = Statistics;
                ToolTip = 'Open the Vendor Performance List';
                RunObject = page "Vendor Performance List";
            }
            action(OpenReqWorksheet)
            {
                ApplicationArea = All;
                Caption = 'Open Requisition Worksheet';
                Image = Worksheet;
                ToolTip = 'Open the Requisition Worksheet to test vendor suggestions';
                RunObject = page "Req. Worksheet";
            }
            action(OpenPlanningWorksheet)
            {
                ApplicationArea = All;
                Caption = 'Open Planning Worksheet';
                Image = Planning;
                ToolTip = 'Open the Planning Worksheet to test vendor suggestions';
                RunObject = page "Planning Worksheet";
            }
        }
        area(Promoted)
        {
            group(Category_Process)
            {
                Caption = 'Process';

                actionref(GenerateAll_Promoted; GenerateAll) { }
                actionref(CleanupAll_Promoted; CleanupAll) { }
            }
            group(Category_Navigate)
            {
                Caption = 'Navigate';

                actionref(ViewTestVendors_Promoted; ViewTestVendors) { }
                actionref(ViewTestItems_Promoted; ViewTestItems) { }
                actionref(OpenReqWorksheet_Promoted; OpenReqWorksheet) { }
            }
        }
    }

    trigger OnOpenPage()
    begin
        Rec.Number := 1;
        Rec.Insert();
        RefreshCounts();
        SetInfoText();
    end;

    var
        VendorCount: Integer;
        ItemCount: Integer;
        ItemVendorCount: Integer;
        VendorInfoText: Text;
        ItemInfoText: Text;
        ExpectedScoresText: Text;

    local procedure RefreshCounts()
    var
        TestDataGen: Codeunit "Vendor Suggestion Test Data";
    begin
        VendorCount := TestDataGen.GetTestVendorCount();
        ItemCount := TestDataGen.GetTestItemCount();
        ItemVendorCount := TestDataGen.GetTestItemVendorCount();
    end;

    local procedure SetInfoText()
    begin
        VendorInfoText := 'VEND-TEST-01: Acme Premium (Q:98%, D:95%) - High performer\' +
                          'VEND-TEST-02: Budget Parts (Q:85%, D:80%) - Medium\' +
                          'VEND-TEST-03: Quick Ship (Q:70%, D:90%) - Fast, lower quality\' +
                          'VEND-TEST-04: Quality First (Q:95%, D:65%) - Quality, slow\' +
                          'VEND-TEST-05: Basic Supplies (Q:60%, D:60%) - Low performer';

        ItemInfoText := 'ITEM-VSTEST-01: Multi-Vendor Widget - All 5 vendors\' +
                        'ITEM-VSTEST-02: No-Vendor Part - Fallback test\' +
                        'ITEM-VSTEST-03: Lead Time Test - Fast vs Slow vendors\' +
                        'ITEM-VSTEST-04: Substitutable - Has substitute item';

        ExpectedScoresText := 'VEND-TEST-01: ~97.9 (Best overall)\' +
                              'VEND-TEST-03: ~87.0 (Fast delivery)\' +
                              'VEND-TEST-02: ~84.5 (Medium)\' +
                              'VEND-TEST-04: ~78.0 (Slow delivery penalty)\' +
                              'VEND-TEST-05: ~76.0 (Low performer)';
    end;
}
