@isTest
public class NattBatchItemPriceTest {
    
   
    
    @TestSetup
    static void setupTestData() {
        Pricebook2 standardPB = new Pricebook2(
            Id = Test.getStandardPricebookId(),
            IsActive = true
        );
        update standardPB;
        
        Pricebook2 pb2 = new Pricebook2(Name='Performance Parts Price Book', IsActive=true);
        insert pb2;
        
        Pricebook2 tesPb2 = new Pricebook2(Name='TES Storefront Pricebook', IsActive=true);
        insert tesPb2;
        
        CommerceEntitlementPolicy cep = new CommerceEntitlementPolicy(Name='All Access for TES Store', CanViewPrice=true, CanViewProduct=true);
        insert cep;

        Account a = new Account(
            Name='Test',
            NATT_Organization__c = 'NATT',
            NATT_Region__c = 'East',
            RecordTypeId=Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('Dealer').getRecordTypeId()
        );
        insert a;

        Contact c = new Contact(
            AccountId=a.Id,
            FirstName='Test',
            LastName='User',
            NATT_Key_Business_Role__c='Principal',
            RecordTypeId=Schema.SObjectType.Contact.getRecordTypeInfosByDeveloperName().get('NATT_Dealer').getRecordTypeId()
        );
        insert c;

        BuyerGroup testBuyerGroup = new BuyerGroup(
            Name = '1'
        );
        insert testBuyerGroup;
        
        Product2 testProduct = new Product2(
            Name = 'Test Product 1',
            IsActive = true       
        );
        insert testProduct;

        Id standardPbId = Test.getStandardPricebookId();

        PricebookEntry testPricebookEntry = new PricebookEntry (
            Pricebook2Id = standardPbId,    
            Product2Id = testProduct.Id,
            UnitPrice = 1000,
            IsActive = true
        );
        insert testPricebookEntry;

        testPricebookEntry = new PricebookEntry (
            Pricebook2Id = tesPb2.Id,    
            Product2Id = testProduct.Id,
            UnitPrice = 1000,
            IsActive = true
        );
        insert testPricebookEntry;
        
        CommerceEntitlementProduct ceproduct = new CommerceEntitlementProduct(PolicyId=cep.Id, ProductId=testProduct.Id);
        insert ceproduct;
        
        Pricebook2 customPricebook = new Pricebook2 (
            Name = '1',
            isActive = true
        );
        insert customPricebook;

        BuyerGroupPricebook testBuyerGroupPricebook = new BuyerGroupPriceBook (
            BuyerGroupId = testBuyerGroup.Id,
            Pricebook2Id = customPricebook.Id
        );
        insert testBuyerGroupPricebook;

        PricebookEntry customPricebookEntry = new PricebookEntry(
            Pricebook2Id = customPricebook.Id,
            Product2Id = testProduct.Id,
            UnitPrice = 1000,
            isActive = true
        );
        insert customPricebookEntry;
    }

    @isTest
    static void testBatchNattItemPriceStaging() {
        BuyerGroup testBuyerGroup = [SELECT ID, Name FROM BuyerGroup LIMIT 1 FOR UPDATE];
        Product2 testProduct = [SELECT ID FROM Product2 LIMIT 1 FOR UPDATE];

        List<NATT_ItemPriceStaging__c> ipsList = new List<NATT_ItemPriceStaging__c>();
        ipsList.add(new NATT_ItemPriceStaging__c (
            NATT_ItemPriceType__c = 'SRP',   
            NATT_CustomerPriceGroup__c = testBuyerGroup.Id,
            NATT_CustomerNumber__c = 0,
            NATT_QuantityFrom__c = 1,
            NATT_EffectiveDate__c = Date.today() - 1,
            NATT_ExpiryDate__c = Date.today() + 10,           
            NATT_Product__c = testProduct.Id,
            NATT_ListPrice__c = 1995,
            RecordTypeId = Schema.SObjectType.NATT_ItemPriceStaging__c.getRecordTypeInfosByDeveloperName().get('NATT_PPG').getRecordTypeId()
        ));
        ipsList.add(new NATT_ItemPriceStaging__c (
            NATT_ItemPriceType__c = 'TINT',   
            NATT_CustomerPriceGroup__c = testBuyerGroup.Id,
            NATT_CustomerNumber__c = 0,
            NATT_QuantityFrom__c = 1,
            NATT_EffectiveDate__c = Date.today() - 1,
            NATT_ExpiryDate__c = Date.today() + 10,           
            NATT_Product__c = testProduct.Id,
            NATT_ListPrice__c = 1995,
            RecordTypeId = Schema.SObjectType.NATT_ItemPriceStaging__c.getRecordTypeInfosByDeveloperName().get('NATT_PPG').getRecordTypeId()
        ));
        insert ipsList;

        List<PriceBookEntry> pBEntryBefore = [SELECT Id, Name, Pricebook2Id, Product2Id, UnitPrice FROM PricebookEntry WHERE UnitPrice = 1995];

        Test.startTest();
        NattBatchItemPrice batchPrice = new NattBatchItemPrice();
        Database.executeBatch(batchPrice);
        Test.stopTest();

        List<PriceBookEntry> pBEntryAfter = [SELECT Id, Name, Pricebook2Id, Product2Id, UnitPrice FROM PricebookEntry WHERE UnitPrice = 1995];

        System.assertEquals(false, pBEntryBefore.size() > 0, 'A Pricebook Entry with Unit Price = 1995 should not exist yet.');
        for (PricebookEntry pbEntry : pBEntryAfter) {
            System.assertEquals(1995, pbEntry.UnitPrice, 'A Pricebook Entry with Unit Price = 1995 should have been queried after the batch ran.');
        }
    }
    
    @isTest
    static void testSchedule() {
        Test.startTest();
        NattBatchItemPrice bip = new NattBatchItemPrice();
        String sch = '0 0 4 ? * * *';        
        String cronId = System.schedule('Testing Schedule', sch, bip);
        CronTrigger ct = [SELECT Id, TimesTriggered, NextFireTime FROM CronTrigger WHERE Id = :cronId];
        System.assertEquals(0, ct.TimesTriggered);
        Test.stopTest(); 
    }
    
    @isTest
    static void testSendMessage() {
        NattBatchItemPrice batchInstance = new NattBatchItemPrice();
        List<String> errorMessages = new List<String>();
        errorMessages.add('Error 1: Sample error message 1');
        errorMessages.add('Error 2: Sample error message 2');
        
        Test.startTest();
        batchInstance.sendMessage(errorMessages);
        Test.stopTest();
    }

}