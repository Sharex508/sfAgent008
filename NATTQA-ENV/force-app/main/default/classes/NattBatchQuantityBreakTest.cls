@IsTest
private class NattBatchQuantityBreakTest {
	@IsTest
    static void batchTest(){
        Test.startTest();
        Database.executeBatch(new NattBatchQuantityBreak());
        Test.stopTest();
    }
    
    @TestSetup
    static void makeData(){
        Pricebook2 standardPB = new Pricebook2(
            Id = Test.getStandardPricebookId(),
            IsActive = true
        );
        update standardPB;
        
        Product2 testProduct = new Product2(
        	Name = 'Test Product 1',
            IsActive = true,
            NATT_P_N__c='DON10090S'
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

        Pricebook2 customPricebook = new Pricebook2 (
            Name = '1',
            isActive = true
        );
        insert customPricebook;

        PricebookEntry customPricebookEntry = new PricebookEntry(
            Pricebook2Id = customPricebook.Id,
            Product2Id = testProduct.Id,
            UnitPrice = 1000,
            isActive = true
        );
        insert customPricebookEntry;
        Date dToday = Date.today();
        List<NATT_ItemPriceStaging__c> ipsList = new List<NATT_ItemPriceStaging__c>();
        Id rtId=Schema.SObjectType.NATT_ItemPriceStaging__c.getRecordTypeInfosByDeveloperName().get('NATT_PPG').getRecordTypeId();
        ipsList.add(new NATT_ItemPriceStaging__c(NATT_Product__c=testProduct.Id,NATT_QuantityFrom__c=1,NATT_ListPrice__c=900,NATT_EffectiveDate__c=dToday,NATT_ExpiryDate__c=dToday.addDays(5),NATT_CustomerNumber__c=0,RecordTypeId=rtId));
        ipsList.add(new NATT_ItemPriceStaging__c(NATT_Product__c=testProduct.Id,NATT_QuantityFrom__c=20,NATT_ListPrice__c=800,NATT_EffectiveDate__c=dToday,NATT_ExpiryDate__c=dToday.addDays(5),NATT_CustomerNumber__c=0,RecordTypeId=rtId));
        ipsList.add(new NATT_ItemPriceStaging__c(NATT_Product__c=testProduct.Id,NATT_QuantityFrom__c=50,NATT_ListPrice__c=700,NATT_EffectiveDate__c=dToday,NATT_ExpiryDate__c=dToday.addDays(5),NATT_CustomerNumber__c=0,RecordTypeId=rtId));
        insert ipsList;
    }
}