@isTest
private class NattBatchMultiListPriceTest {
    @IsTest
    static void myUnitTest(){
        Test.startTest();
        Database.executeBatch(new NattBatchMultiListPrice());
        Test.stopTest();
    }
    @TestSetup
    static void createData(){
        Map<String,Schema.RecordTypeInfo> rtMap = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName();
        List<Account> actList = new List<Account>();
        actList.add(new Account(Name='Test1',
            NATT_Organization__c = 'NATT',NATT_Region__c = 'East',NATT_JDE_Parts_Bill_To_Code__c='12345678',NATT_Customer_Price_Group__c='1',RecordTypeId=rtMap.get('Dealer').getRecordTypeId()));
        actList.add(new Account(Name='Test2',
            NATT_Organization__c = 'NATT',NATT_Region__c = 'East',NATT_JDE_Parts_Bill_To_Code__c='23456789',NATT_Customer_Price_Group__c='2',RecordTypeId=rtMap.get('Dealer').getRecordTypeId()));
        insert actList;

        List<Product2> pList = new List<Product2>();
        pList.add(new Product2(Name='P1',IsActive = true,NATT_UnitCost__c=100,NATT_ItemPriceGroup__c='11'));
        pList.add(new Product2(Name='P2',IsActive = true,NATT_UnitCost__c=200,NATT_ItemPriceGroup__c='22'));
        insert pList;

        Id standardPbId = Test.getStandardPricebookId();
        List<PricebookEntry> pbeList = new List<PricebookEntry>();
        pbeList.add(new PricebookEntry(Product2Id=pList.get(0).Id,UnitPrice=100,IsActive=true,Pricebook2Id=standardPbId));
        pbeList.add(new PricebookEntry(Product2Id=pList.get(1).Id,UnitPrice=200,IsActive=true,Pricebook2Id=standardPbId));
        insert pbeList;

        Id rtId=Schema.SObjectType.NATT_ItemPriceStaging__c.getRecordTypeInfosByDeveloperName().get('NATT_PPG').getRecordTypeId();
        Id pasRtId=Schema.SObjectType.NATT_PriceAdjustmentStaging__c.getRecordTypeInfosByDeveloperName().get('NATT_PPG').getRecordTypeId();

        List<NATT_ItemPriceStaging__c> ipsList = new List<NATT_ItemPriceStaging__c>();        
        ipsList.add(new NATT_ItemPriceStaging__c(NATT_EffectiveDate__c=Date.today(),NATT_ExpiryDate__c=Date.today().addDays(10),NATT_ItemPriceType__c='SRP',NATT_ListPrice__c=100,NATT_Product__c=pList.get(0).Id,NATT_CustomerNumber__c=12345678,RecordTypeId=rtId));
        ipsList.add(new NATT_ItemPriceStaging__c(NATT_EffectiveDate__c=Date.today(),NATT_ExpiryDate__c=Date.today().addDays(10),NATT_ItemPriceType__c='SRP',NATT_ListPrice__c=200,NATT_Product__c=pList.get(1).Id,NATT_CustomerNumber__c=23456789,RecordTypeId=rtId));
        insert ipsList;

        List<NATT_PriceAdjustmentStaging__c> pasList = new List<NATT_PriceAdjustmentStaging__c>();
        pasList.add(new NATT_PriceAdjustmentStaging__c(NATT_EffectiveDate__c=Date.today(),NATT_ExpiryDate__c=Date.today().addDays(10),NATT_AdjustmentType__c='REGD',NATT_AdjustmentValue__c=-10,NATT_CustomerPriceGroup__c='1',NATT_ItemPriceGroup__c='11',RecordTypeId=pasRtId));
        pasList.add(new NATT_PriceAdjustmentStaging__c(NATT_EffectiveDate__c=Date.today(),NATT_ExpiryDate__c=Date.today().addDays(10),NATT_AdjustmentType__c='REGD',NATT_AdjustmentValue__c=-20,NATT_CustomerPriceGroup__c='2',NATT_ItemPriceGroup__c='22',RecordTypeId=pasRtId));
        insert pasList;

        List<Pricebook2> pbList = new List<Pricebook2>();
        pbList.add(new Pricebook2(Name='12345678',IsActive=true));
        pbList.add(new Pricebook2(Name='23456789',IsActive=true));
        insert pbList;

        PricebookEntry pbe = new PricebookEntry(Product2Id=pList.get(0).Id,Pricebook2Id=pbList.get(0).Id,IsActive=true,UnitPrice=77);
        insert pbe;
    }
    @isTest
    static void testSendMessage() {
        
        NattBatchMultiListPrice batchInstance = new NattBatchMultiListPrice();

       
        List<String> errorMessages = new List<String>();
        errorMessages.add('Error 1: Sample error message 1');
        errorMessages.add('Error 2: Sample error message 2');
        
        
        Test.startTest();
        batchInstance.sendMessage(errorMessages);
        Test.stopTest();

          }
}