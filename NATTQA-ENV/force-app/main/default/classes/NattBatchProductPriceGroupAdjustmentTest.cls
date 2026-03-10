@IsTest
private class NattBatchProductPriceGroupAdjustmentTest {
  @IsTest
    static void myUnitTest() {
        List<String> errorMessages = new List<String>();
        errorMessages.add('Error 1: Sample error message 1');
        errorMessages.add('Error 2: Sample error message 2');

        NattBatchProductPriceGroupAdjustment batch = new NattBatchProductPriceGroupAdjustment();
        Test.startTest();
        Database.executeBatch(batch);
        batch.sendMessage(errorMessages);
        Test.stopTest();
    }

    @TestSetup
    static void setupData() {
        Id pricebookId = Test.getStandardPricebookId();

        Pricebook2 standardPb = new Pricebook2(
            Id = pricebookId,
            IsActive = true
        );
        update standardPb;

        List<Product2> pList = new List<Product2>();
        pList.add(new Product2(Name = 'Test Product 1', IsActive = true, NATT_UnitCost__c = 1, NATT_ItemPriceGroup__c = '1'));
        pList.add(new Product2(Name = 'Test Product 2', IsActive = true, NATT_UnitCost__c = 2, NATT_ItemPriceGroup__c = '2'));
        pList.add(new Product2(Name = 'Test Product 3', IsActive = true, NATT_UnitCost__c = 3, NATT_ItemPriceGroup__c = '3'));
        insert pList;

        List<PricebookEntry> pbeList = new List<PricebookEntry>();
        pbeList.add(new PricebookEntry(
            Pricebook2Id = standardPb.Id,
            Product2Id = pList.get(0).Id,
            UnitPrice = 1,
            IsActive = true
        ));
        pbeList.add(new PricebookEntry(
            Pricebook2Id = standardPb.Id,
            Product2Id = pList.get(1).Id,
            UnitPrice = 2,
            IsActive = true
        ));
        pbeList.add(new PricebookEntry(
            Pricebook2Id = standardPb.Id,
            Product2Id = pList.get(2).Id,
            UnitPrice = 2,
            IsActive = true
        ));
        insert pbeList;

        List<NATT_PriceAdjustmentStaging__c> pasList = new List<NATT_PriceAdjustmentStaging__c>();
        Id rtId = Schema.SObjectType.NATT_PriceAdjustmentStaging__c.getRecordTypeInfosByDeveloperName().get('NATT_PPG').getRecordTypeId();
        pasList.add(new NATT_PriceAdjustmentStaging__c(NATT_EffectiveDate__c = Date.today(), NATT_ExpiryDate__c = Date.today().addDays(10), NATT_CustomerNumber__c = 0, NATT_ItemPriceGroup__c = '1', NATT_CustomerPriceGroup__c = 'CPG1', NATT_AdjustmentValue__c = 1, NATT_AdjustmentType__c = 'REGD', RecordTypeId = rtId));
        pasList.add(new NATT_PriceAdjustmentStaging__c(NATT_EffectiveDate__c = Date.today(), NATT_ExpiryDate__c = Date.today().addDays(10), NATT_CustomerNumber__c = 0, NATT_ItemPriceGroup__c = '2', NATT_CustomerPriceGroup__c = 'CPG2', NATT_AdjustmentValue__c = 20, NATT_AdjustmentType__c = 'SURCHG', RecordTypeId = rtId));
        pasList.add(new NATT_PriceAdjustmentStaging__c(NATT_EffectiveDate__c = Date.today(), NATT_ExpiryDate__c = Date.today().addDays(10), NATT_CustomerNumber__c = 0, NATT_ItemPriceGroup__c = '3', NATT_CustomerPriceGroup__c = 'CPG3', NATT_AdjustmentValue__c = -10, NATT_AdjustmentType__c = 'REGD', RecordTypeId = rtId));
        insert pasList;
    }
}