@isTest
private class InActivateExpiredPricingBtchTest {
    @TestSetup
    static void setupTestData() {
        Account a = new Account(
            Name='Test',
            NATT_Region__c = 'East',
            NATT_Organization__c = 'NATT',
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
            Name = 'Test BG'
            //OwnerId = testUserNew.Id
        );
        insert testBuyerGroup;
        
        Pricebook2 testPricebook = new Pricebook2 (
            Id = Test.getStandardPricebookId(),
            // Name = 'Test Pricebook',
            // Description = 'Test Products',
            IsActive = true
        );
        update testPricebook;
        
        Product2 testProduct = new Product2(
            Name = 'Performance Parts Price Book',
            IsActive = true
        );
        insert testProduct;
        
        Id pricebookId = Test.getStandardPricebookId();
        
        PricebookEntry testPricebookEntry = new PricebookEntry (
            Pricebook2Id = pricebookId,    
            Product2Id = testProduct.Id,
            UnitPrice = 1000,
            IsActive = true
        );
        insert testPricebookEntry;
        
        Pricebook2 customPricebook = new Pricebook2 (
            Name = '12345678',
            isActive = true
        );
        insert customPricebook;
        
        Product2 testProduct2 = new Product2(
            Name = 'Performance Parts Price Book',
            IsActive = true,
            NATT_UnitCost__c = 999
        );
        insert testProduct2;
        
        WebStore testPPGStorefront = new WebStore (
            Name = 'Performance Parts'
        );
        insert testPPGStorefront;
    }
    
    @isTest
    static void Test1(){
        Decimal originalPrice = null;
        BuyerGroup testBuyerGroup = [SELECT ID, Name FROM BuyerGroup];
        list<product2> prodList = new list<product2>();
        list<PricebookEntry> pbelist = new list<PricebookEntry>();

        Product2 testProduct1 = new Product2(
            Name = '12345678', 
            IsActive = true,
            NATT_UnitCost__c = 2100);
        prodList.add(testProduct1);
        
        Product2 testProduct2 = new Product2(
            Name = '12345679', 
            IsActive = true,
            NATT_UnitCost__c = 2200);
        prodList.add(testProduct2);
        
        Product2 testProduct3 = new Product2(
            Name = '12345670', 
            IsActive = true,
            NATT_UnitCost__c = 2300);
        prodList.add(testProduct3);
        insert prodList;
        
        Pricebook2 standardPB = new Pricebook2(
            Id = Test.getStandardPricebookId(),
            IsActive = true
        ); 
        update standardPB;
         Pricebook2 customPB = new Pricebook2(
              Name = '12345678',
            IsActive = true
        );
       insert  customPB;
         PricebookEntry testPricebookEntry = new PricebookEntry (
            Pricebook2Id = standardPB.Id,    
            Product2Id = testProduct1.Id,
            UnitPrice = 1000,
            IsActive = true
        );
			pbelist.add(testPricebookEntry);
        PricebookEntry testPricebookEntry1 = new PricebookEntry (
            Pricebook2Id = customPB.Id,    
            Product2Id = testProduct1.Id,
            UnitPrice = 1000,
            IsActive = true
        );
			pbelist.add(testPricebookEntry1);
        
        PricebookEntry testPricebookEntry2 = new PricebookEntry (
            Pricebook2Id = standardPB.Id,    
            Product2Id = testProduct2.Id,
            UnitPrice = 1000,
            IsActive = true
        );
        pbelist.add(testPricebookEntry2);
        
        PricebookEntry testPricebookEntry3 = new PricebookEntry (
            Pricebook2Id = standardPB.Id,    
            Product2Id = testProduct3.Id,
            UnitPrice = 1000,
            IsActive = true
        );
        pbelist.add(testPricebookEntry3);
        
        insert pbelist;
        
        list<NATT_ItemPriceStaging__c> listPAS = new list<NATT_ItemPriceStaging__c>();
        NATT_ItemPriceStaging__c nattPAS1 = new NATT_ItemPriceStaging__c(
            NATT_Product__c = testProduct1.Id,
            NATT_CustomerPriceGroup__c = testBuyerGroup.Id,
            NATT_CustomerNumber__c = 12345678,
            NATT_EffectiveDate__c=Date.today(),
            NATT_ExpiryDate__c=Date.today().addDays(-10),
            RecordTypeId=Schema.SObjectType.NATT_ItemPriceStaging__c.getRecordTypeInfosByDeveloperName().get('NATT_PPG').getRecordTypeId()
        );
        listPAS.add(nattPAS1);
         NATT_ItemPriceStaging__c nattPAS2 = new NATT_ItemPriceStaging__c(
            NATT_Product__c = testProduct2.Id,
            NATT_CustomerPriceGroup__c = testBuyerGroup.Id,
            NATT_CustomerNumber__c = 12345678,
            NATT_EffectiveDate__c=Date.today(),
            NATT_ExpiryDate__c=Date.today(),
            RecordTypeId=Schema.SObjectType.NATT_ItemPriceStaging__c.getRecordTypeInfosByDeveloperName().get('NATT_PPG').getRecordTypeId()
        );
        listPAS.add(nattPAS2); 
        NATT_ItemPriceStaging__c nattPAS3 = new NATT_ItemPriceStaging__c(
            NATT_Product__c = testProduct3.Id,
            NATT_CustomerPriceGroup__c = testBuyerGroup.Id,
            NATT_CustomerNumber__c = 12345678,
            NATT_EffectiveDate__c=Date.today(),
            NATT_ExpiryDate__c=Date.today().addDays(15),
            RecordTypeId=Schema.SObjectType.NATT_ItemPriceStaging__c.getRecordTypeInfosByDeveloperName().get('NATT_PPG').getRecordTypeId()
        );
        listPAS.add(nattPAS3);
        insert listPAS;
        list<NATT_ItemPriceStaging__c> lst = [select id,name,NATT_ExpiryDate__c from NATT_ItemPriceStaging__c];
        system.debug('lst-'+lst);
        Test.startTest();
        InActivateExpiredPricingBtch batchInstance = new InActivateExpiredPricingBtch();
        Database.executeBatch(batchInstance);
        Test.stopTest();
    }
    
  
}