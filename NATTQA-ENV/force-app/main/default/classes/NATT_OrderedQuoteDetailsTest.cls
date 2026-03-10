@isTest
public class NATT_OrderedQuoteDetailsTest {
    
    @TestSetup 
    static void setupData(){
        List<Pricebook2> pbList = new List<Pricebook2>();
        
        pbList.add(new Pricebook2(Name='NATT Units Price Book',IsActive=true));
        insert pbList;
        
        // insert products
        List<Product2> products = new List<Product2>();
        
        Product2 product1 = TestUtil.createProduct('Vector 8600 - System 16','Vector 8600 - System 16');
        products.add(product1);
        
        insert products;
        
        Id pricebookId = Test.getStandardPricebookId();
        List<PriceBookEntry> pBEs = new List<PriceBookEntry>();
        PriceBookEntry pBE1 = TestUtil.createPriceBookEntry(pricebookId, products[0].Id);
        pBEs.add(pBE1);
        
        List<SBQQ__LookupData__c> lkDataList = new List<SBQQ__LookupData__c>();
        
        lkDataList.add(TestUtil.createLookupData(products[0].Id,Date.today().addYears(1),Date.today().addYears(2),'Unit Pricing'));
        insert lkDataList;
        
       
    }
    @isTest
    static void testGetRecentOrderDetails() {
        
        Account acc = new Account(Name='Test Dealer', NATT_Organization__c='NATT',NATT_Region__c='East',RecordTypeId=Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('Dealer').getRecordTypeId());
        insert acc;
        Account CustAcc = new Account(Name='Test Customer',NATT_Dealership__c =acc.id,  NATT_Organization__c='NATT',NATT_Region__c='East',RecordTypeId=Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('Customer').getRecordTypeId());
        insert CustAcc;
        // Create test Opportunity
        Opportunity opp = new Opportunity(
            Name = 'Test Opportunity',
            StageName = 'Closed Won',
            CloseDate = Date.today().addDays(10),
            AccountId = acc.Id
        );
        insert opp;
                Id pricebookId = [SELECT Id FROM Pricebook2 WHERE name = 'NATT Units Price Book' limit 1].id;
		 Id quoteRTId = Schema.SobjectType.SBQQ__Quote__c.getRecordTypeInfosByDeveloperName().get('NATT_Units_Quote').getRecordTypeId();

        SBQQ__Quote__c parentQuote = new SBQQ__Quote__c(
            SBQQ__Opportunity2__c = opp.Id,
            SBQQ__Status__c = 'Draft',
            SBQQ__PriceBook__c = pricebookId,
            SBQQ__Account__c = acc.id,
            NATT_End_Customer__c = CustAcc.id ,
            NATT_Unit__c = 'Vector 8600 - System 16',
             NATT_Product_Family__c = 'Trailer',
            RecordTypeId = quoteRTId,
            NATT_Quote_Record_Type_Developer_Name__c= 'NATT_Units_Quote'
        );
        insert parentQuote;

        SBQQ__Quote__c quote = new SBQQ__Quote__c(
            SBQQ__Opportunity2__c = opp.Id,
            SBQQ__Status__c = 'Ordered',
            SBQQ__PriceBook__c = pricebookId,
            SBQQ__Primary__c = true,
            SBQQ__Account__c = acc.id,
            NATT_End_Customer__c = CustAcc.id ,
            NATT_Product_Family__c = 'Trailer',
            NATT_Unit__c = 'Vector 8600 - System 16',
            SBQQ__Ordered__c = true,
            RecordTypeId = quoteRTId,
            NATT_Quote_Record_Type_Developer_Name__c= 'NATT_Units_Quote'
        );
        insert quote;
        
        
        // Create test Order linked to Quote
        Order ord = new Order(
            AccountId = acc.Id,
            EffectiveDate = Date.today(),
            Status = 'Draft',
            SBQQ__Quote__c = quote.Id,
            Pricebook2Id = pricebookId
        );
        insert ord;
        
        Product2 prod = new Product2(Name = 'Vector 8600 - System 16', IsActive = true);
        insert prod;
        
         Id stdPricebookId = Test.getStandardPricebookId();
        PricebookEntry stdPbe = new PricebookEntry(
            Product2Id = prod.Id,
            Pricebook2Id = stdPricebookId,
            UnitPrice = 100,
            IsActive = true
        );
        insert stdPbe;
        PricebookEntry pbe = new PricebookEntry(
            Product2Id = prod.Id,
            Pricebook2Id = pricebookId,
            UnitPrice = 100,
            IsActive = true
        );
        insert pbe;
        
        OrderItem oi = new OrderItem(
            OrderId = ord.Id,
            Quantity = 2,
            UnitPrice = 100,
            PricebookEntryId = pbe.Id
        );
        insert oi;
        
        Test.startTest();
        NATT_OrderedQuoteDetails.getOrderDetails(parentQuote.Id);
        
        Test.stopTest();
        

    }
}