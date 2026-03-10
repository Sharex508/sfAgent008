@IsTest
private class NATT_DirectSales_AddBundleOnParent_Test {

    @TestSetup
    static void setupData() { 
        // Activate Standard Pricebook
        Id stdPbId = Test.getStandardPricebookId();
        update new Pricebook2(Id = stdPbId, IsActive = true);

        // Products (bundle parent + two children)
        Product2 pParent = new Product2(Name = 'Bundle Parent', Family = 'Test', IsActive = true);
        Product2 pChild1 = new Product2(Name = 'Child 1',NATT_Is_Base_Unit__c = true, Family = 'Test', IsActive = true);
        Product2 pChild2 = new Product2(Name = 'Child 2', Family = 'Test', IsActive = true);
        insert new List<Product2>{ pParent, pChild1, pChild2 };

        // PBEs on Standard PB
        PricebookEntry pbeParent = new PricebookEntry(Product2Id = pParent.Id, Pricebook2Id = stdPbId, UnitPrice = 100, IsActive = true);
        PricebookEntry pbeChild1 = new PricebookEntry(Product2Id = pChild1.Id, Pricebook2Id = stdPbId, UnitPrice = 10,  IsActive = true);
        PricebookEntry pbeChild2 = new PricebookEntry(Product2Id = pChild2.Id, Pricebook2Id = stdPbId, UnitPrice = 20,  IsActive = true);
        insert new List<PricebookEntry>{ pbeParent, pbeChild1, pbeChild2 };

        // Basic Account & Opportunity
            Account acc = new Account(Name='Test Direct Sales',
                                      RecordTypeId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('NATT_OEM').getRecordTypeId(),
                                      NATT_Organization__c = 'NATT',
                                      NATT_Region__c = 'East'
                                     );
        insert acc;
        Opportunity opp = new Opportunity(
            Name = 'Test Opp',
            AccountId = acc.Id,
            CloseDate=Date.today().addDays(30),
            StageName='Qualification',
            RecordTypeId=Schema.SObjectType.Opportunity.getRecordTypeInfosByDeveloperName().get('NATT_Direct_Sales').getRecordTypeId(),
            NATT_Stock__c=true,
            Pricebook2Id = stdPbId
        );
        insert opp;
          Opportunity opp2 = new Opportunity(
            Name = 'Test Opp',
            AccountId = acc.Id,
            CloseDate=Date.today().addDays(30),
            StageName='Qualification',
            RecordTypeId=Schema.SObjectType.Opportunity.getRecordTypeInfosByDeveloperName().get('NATT_Direct_Sales').getRecordTypeId(),
            NATT_Stock__c=true,
            Pricebook2Id = stdPbId,
            Opportunity_Source__c = opp.Id

        );
        insert opp2;

        // Destination quote (receives the clones)
        SBQQ__Quote__c qDest = new SBQQ__Quote__c(
            SBQQ__Opportunity2__c = opp.Id,
            SBQQ__PricebookId__c  = stdPbId,
            SBQQ__Primary__c      = true,
            SBQQ__Status__c       = 'Draft',
            SBQQ__Type__c         = 'Quote',
            RecordTypeId = Schema.SObjectType.SBQQ__Quote__c.getRecordTypeInfosByDeveloperName().get('NATT_Direct_Sales').getRecordTypeId()

        );
        insert qDest;

        // Input/template quote
        SBQQ__Quote__c qInput = new SBQQ__Quote__c(
            SBQQ__Opportunity2__c = opp.Id,
            SBQQ__PricebookId__c  = stdPbId,
            SBQQ__Primary__c      = false,
            SBQQ__Status__c       = 'Draft',
            SBQQ__Type__c         = 'Quote',
            SBQQ__Source__c		  = qDest.Id,
            RecordTypeId = Schema.SObjectType.SBQQ__Quote__c.getRecordTypeInfosByDeveloperName().get('NATT_Direct_Sales').getRecordTypeId()
        );
        insert qInput;

        // Create bundle on INPUT quote
        SBQQ__QuoteLine__c qlParent = new SBQQ__QuoteLine__c(
            SBQQ__Quote__c          = qInput.Id,
            SBQQ__Product__c        = pParent.Id,
            SBQQ__PricebookEntryId__c = pbeParent.Id,
            SBQQ__Quantity__c       = 1,
            SBQQ__NetPrice__c       = 100,
            SBQQ__RequiredBy__c     = null,
            NATT_Is_Base_Unit__c    = true  // <-- required by your query
        );
        insert qlParent;

        SBQQ__QuoteLine__c qlChild1 = new SBQQ__QuoteLine__c(
            SBQQ__Quote__c          = qInput.Id,
            SBQQ__Product__c        = pChild1.Id,
            SBQQ__PricebookEntryId__c = pbeChild1.Id,
            SBQQ__Quantity__c       = 1,
            SBQQ__NetPrice__c       = 10,
            SBQQ__RequiredBy__c     = qlParent.Id
        );
        SBQQ__QuoteLine__c qlChild2 = new SBQQ__QuoteLine__c(
            SBQQ__Quote__c          = qInput.Id,
            SBQQ__Product__c        = pChild2.Id,
            SBQQ__PricebookEntryId__c = pbeChild2.Id,
            SBQQ__Quantity__c       = 1,
            SBQQ__NetPrice__c       = 20,
            SBQQ__RequiredBy__c     = qlParent.Id
        );
        insert new List<SBQQ__QuoteLine__c>{ qlChild1, qlChild2 };
    }

    @IsTest
    static void test_clone_then_add_same_product_again() {
        // Fetch our quotes
        SBQQ__Quote__c cloneQuote = [SELECT Id,Direct_Sales_Units__c  FROM SBQQ__Quote__c where SBQQ__Source__c != null LIMIT 1];
        // Pick the other quote as destination
        SBQQ__Quote__c SourceQuote  = [SELECT Id,Direct_Sales_Units__c FROM SBQQ__Quote__c WHERE SBQQ__Source__c = null LIMIT 1];
        Product2 productc1 = [select id, name from product2 where Name = 'Child 1' limit 1];
        PricebookEntry pbe = [SELECT Id,Name,Product2.Name from PricebookEntry where Product2.name = 'Child 1' limit 1] ;
        // Create bundle on INPUT quote
        SBQQ__QuoteLine__c qlParent = new SBQQ__QuoteLine__c(
            SBQQ__Quote__c          = cloneQuote.Id,
            SBQQ__Product__c        = productc1.Id,
            SBQQ__PricebookEntryId__c = pbe.Id,
            SBQQ__Quantity__c       = 1,
            SBQQ__NetPrice__c       = 100,
            SBQQ__RequiredBy__c     = null,
            NATT_Is_Base_Unit__c    = true  // <-- required by your query
        );
        insert qlParent;

        SBQQ__QuoteLine__c qlChild1 = new SBQQ__QuoteLine__c(
            SBQQ__Quote__c          = cloneQuote.Id,
            SBQQ__Product__c        = productc1.Id,
            SBQQ__PricebookEntryId__c = pbe.Id,
            SBQQ__Quantity__c       = 1,
            SBQQ__NetPrice__c       = 10,
            SBQQ__RequiredBy__c     = qlParent.Id
        );
        SBQQ__QuoteLine__c qlChild2 = new SBQQ__QuoteLine__c(
            SBQQ__Quote__c          = cloneQuote.Id,
            SBQQ__Product__c        = productc1.Id,
            SBQQ__PricebookEntryId__c = pbe.Id,
            SBQQ__Quantity__c       = 1,
            SBQQ__NetPrice__c       = 20,
            SBQQ__RequiredBy__c     = qlParent.Id
        );
        insert new List<SBQQ__QuoteLine__c>{ qlChild1, qlChild2 };
          list<SBQQ__QuoteLine__c> qlList = [   SELECT Id, SBQQ__Quote__c, SBQQ__Quote__r.SBQQ__Source__c, NATT_Is_Base_Unit__c
                    FROM SBQQ__QuoteLine__c
                    WHERE SBQQ__Quote__c = :cloneQuote.Id];
        // Baseline counts on destination
        Decimal Source = [SELECT Direct_Sales_Units__c FROM SBQQ__Quote__c WHERE id = :SourceQuote.Id].Direct_Sales_Units__c;
        Decimal Clone = [SELECT Direct_Sales_Units__c FROM SBQQ__Quote__c WHERE id = :cloneQuote.Id ].Direct_Sales_Units__c;
        // 1) Clone from INPUT -> DEST (timesToAdd = 1)
        NATT_DirectSales_AddBundleOnParentQuote.Request r1 = new NATT_DirectSales_AddBundleOnParentQuote.Request();
        r1.QuoteId      = cloneQuote.Id;
        r1.SourceQuoteId = SourceQuote.Id;  // your class uses this as destination
        r1.timesToAdd   = 1;

        Test.startTest();
        List<NATT_DirectSales_AddBundleOnParentQuote.Result> res1 =
            NATT_DirectSales_AddBundleOnParentQuote.cloneOneBundleNtimes(
                new List<NATT_DirectSales_AddBundleOnParentQuote.Request>{ r1 }
            );
        Test.stopTest();
    }
    
        @IsTest
    static void test_clone_then_add_same_product_again2() {
       
 NATT_DirectSales_AddBundleOnParentQuote.Request r1 = new NATT_DirectSales_AddBundleOnParentQuote.Request();
        r1.QuoteId      = null;
        r1.SourceQuoteId = null;  // your class uses this as destination
        r1.timesToAdd   = 2;
        Test.startTest();
        List<NATT_DirectSales_AddBundleOnParentQuote.Result> res1 =
            NATT_DirectSales_AddBundleOnParentQuote.cloneOneBundleNtimes(
                new List<NATT_DirectSales_AddBundleOnParentQuote.Request>{ r1 }
            );
       
    }
        @IsTest
    static void test_clone_then_add_same_product_again3() {
        SBQQ__Quote__c cloneQuote = [SELECT Id,Direct_Sales_Units__c  FROM SBQQ__Quote__c where SBQQ__Source__c != null LIMIT 1];
        // Pick the other quote as destination
        SBQQ__Quote__c SourceQuote  = [SELECT Id,Direct_Sales_Units__c FROM SBQQ__Quote__c WHERE SBQQ__Source__c = null LIMIT 1];
         list<SBQQ__QuoteLine__c> qlList = [   SELECT Id, SBQQ__Quote__c, SBQQ__Quote__r.SBQQ__Source__c, NATT_Is_Base_Unit__c
                    FROM SBQQ__QuoteLine__c
                    WHERE SBQQ__Quote__c = :cloneQuote.Id OR  SBQQ__Quote__c = :SourceQuote.Id];
        delete qlList;
    NATT_DirectSales_AddBundleOnParentQuote.Request r1 = new NATT_DirectSales_AddBundleOnParentQuote.Request();
        r1.QuoteId      = cloneQuote.Id;
        r1.SourceQuoteId = SourceQuote.Id;  // your class uses this as destination
        r1.timesToAdd   = 2;
        Test.startTest();
        List<NATT_DirectSales_AddBundleOnParentQuote.Result> res1 =
            NATT_DirectSales_AddBundleOnParentQuote.cloneOneBundleNtimes(
                new List<NATT_DirectSales_AddBundleOnParentQuote.Request>{ r1 }
            );
       
    }

    @IsTest
    static void test_validation_guard_timesToAdd() {
        // Use any existing quote as both template and destination to hit guard
        SBQQ__Quote__c anyQuote = [SELECT Id FROM SBQQ__Quote__c LIMIT 1];

        NATT_DirectSales_AddBundleOnParentQuote.Request r = new NATT_DirectSales_AddBundleOnParentQuote.Request();
        r.QuoteId       = anyQuote.Id;
        r.SourceQuoteId = anyQuote.Id;
        r.timesToAdd    = 0; // invalid

        Test.startTest();
        List<NATT_DirectSales_AddBundleOnParentQuote.Result> res =
            NATT_DirectSales_AddBundleOnParentQuote.cloneOneBundleNtimes(
                new List<NATT_DirectSales_AddBundleOnParentQuote.Request>{ r }
            );
        Test.stopTest();

        System.assertEquals(1, res.size(), 'One result expected');
        System.assertEquals(false, res[0].IsSuccess, 'Should fail validation when timesToAdd <= 0');
        System.assert(res[0].Message != null && res[0].Message.contains('timesToAdd'),
            'Message should explain invalid timesToAdd');
    }
}