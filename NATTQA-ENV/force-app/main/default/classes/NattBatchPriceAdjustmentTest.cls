@IsTest
public with sharing class NattBatchPriceAdjustmentTest {
      
    @TestSetup
    static void setupTestData() {
        Account a = new Account(
            Name = 'Test',
            NATT_Organization__c = 'NATT',
            NATT_Region__c = 'East',
            RecordTypeId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('Dealer').getRecordTypeId()
        );
        insert a;
 Contact c = new Contact(
        AccountId = a.Id,
        FirstName = 'Test',
        LastName = 'User',
        NATT_Key_Business_Role__c = 'Principal',
        RecordTypeId = Schema.SObjectType.Contact.getRecordTypeInfosByDeveloperName().get('NATT_Dealer').getRecordTypeId()
    );
    insert c;

    BuyerGroup testBuyerGroup = new BuyerGroup(
        Name = 'Test BG'
    );
    insert testBuyerGroup;

    Pricebook2 testPricebook = new Pricebook2(
        Id = Test.getStandardPricebookId(),
        IsActive = true
    );
    update testPricebook;

    Product2 testProduct = new Product2(
        Name = 'Test Product 1',
        IsActive = true
    );
    insert testProduct;

    Id pricebookId = Test.getStandardPricebookId();

    PricebookEntry testPricebookEntry = new PricebookEntry(
        Pricebook2Id = pricebookId,
        Product2Id = testProduct.Id,
        UnitPrice = 1000,
        IsActive = true
    );
    insert testPricebookEntry;

    Pricebook2 customPricebook = new Pricebook2(
        Name = 'Custom Test Pricebook',
        IsActive = true
    );
    insert customPricebook;

    Product2 testProduct2 = new Product2(
        Name = 'Test Product 2',
        IsActive = true,
        NATT_UnitCost__c = 999
    );
    insert testProduct2;

    WebStore testPPGStorefront = new WebStore(
        Name = 'Performance Parts'
    );
    insert testPPGStorefront;
}

@isTest
static void testBatchNattItemPriceStaging_PriceAdjustment() {
    Decimal originalPrice = null;
    BuyerGroup testBuyerGroup = [SELECT ID, Name FROM BuyerGroup LIMIT 1];

    Product2 testProduct = new Product2(
        Name = 'Test Product 01',
        IsActive = true,
        NATT_UnitCost__c = 2000
    );
    insert testProduct;

    Pricebook2 standardPB = new Pricebook2(
        Id = Test.getStandardPricebookId(),
        IsActive = true
    );
    update standardPB;

    PricebookEntry testPricebookEntry = new PricebookEntry(
        Pricebook2Id = standardPB.Id,
        Product2Id = testProduct.Id,
        UnitPrice = 1000,
        IsActive = true
    );
    insert testPricebookEntry;

    Product2 testProduct2 = new Product2(
        Name = 'Test Product 02',
        IsActive = true,
        NATT_UnitCost__c = 100
    );
    insert testProduct2;

    Pricebook2 customPb = new Pricebook2(
        Name = '1',
        IsActive = true
    );
    insert customPb;

    PricebookEntry pbe = new PricebookEntry(
        Product2Id = testProduct.Id,
        UnitPrice = 200,
        IsActive = true,
        Pricebook2Id = customPb.Id
    );
    insert pbe;

    NATT_ItemPriceStaging__c testNattIPS = new NATT_ItemPriceStaging__c(
        NATT_ItemPriceType__c = 'SRP',
        NATT_CustomerPriceGroup__c = testBuyerGroup.Id,
        NATT_CustomerNumber__c = 1,
        NATT_EffectiveDate__c = Date.today() - 1,
        NATT_ExpiryDate__c = Date.today() + 10,
        RecordTypeId = Schema.SObjectType.NATT_ItemPriceStaging__c.getRecordTypeInfosByDeveloperName().get('NATT_PPG').getRecordTypeId()
    );
    insert testNattIPS;

    Product2 testProductCostGrab = [SELECT NATT_UnitCost__c FROM Product2 WHERE Id = :testProduct.Id FOR UPDATE];
    System.debug('originalUnitCost:' + testProductCostGrab.NATT_UnitCost__c);

    NATT_PriceAdjustmentStaging__c nattPAS = new NATT_PriceAdjustmentStaging__c(
        NATT_Product__c = testProduct.Id,
        NATT_CustomerPriceGroup__c = testBuyerGroup.Id,
        NATT_CustomerNumber__c = 1,
        NATT_AdjustmentType__c = 'REGD',
        NATT_AdjustmentValue__c = -17,
        NATT_EffectiveDate__c = Date.today(),
        NATT_ExpiryDate__c = Date.today().addDays(10),
        RecordTypeId = Schema.SObjectType.NATT_PriceAdjustmentStaging__c.getRecordTypeInfosByDeveloperName().get('NATT_PPG').getRecordTypeId()
    );
    insert nattPAS;

    Test.startTest();
    NattBatchPriceAdjustment batchPriceAdj = new NattBatchPriceAdjustment();
    Database.executeBatch(batchPriceAdj);
    Test.stopTest();

    Decimal updatedPrice = (testProduct.NATT_UnitCost__c + (testProduct.NATT_UnitCost__c * (nattPAS.NATT_AdjustmentValue__c / 100)));
    System.debug('updatedPrice:' + updatedPrice);
    System.debug('pbeList:' + [SELECT Name, UnitPrice FROM PricebookEntry]);

    PricebookEntry productList = [SELECT Name, UnitPrice FROM PricebookEntry WHERE UnitPrice = :updatedPrice LIMIT 1];
    System.assertEquals(updatedPrice, productList.UnitPrice, 'We expect a new Pricebook Entry based on the NATT_PriceAdjustmentStagings Adjustment Value');
}

@isTest
static void testBatchPriceAdjustmentStaging_NoUpdate() {
    BuyerGroup testBuyerGroup = [SELECT ID, Name FROM BuyerGroup LIMIT 1];
    Product2 testProduct = new Product2(
        Name = 'Test Product 01',
        IsActive = true
    );
    insert testProduct;

    Pricebook2 standardPB = new Pricebook2(
        Id = Test.getStandardPricebookId(),
        IsActive = true
    );
    update standardPB;

    PricebookEntry testPricebookEntry = new PricebookEntry(
        Pricebook2Id = standardPB.Id,
        Product2Id = testProduct.Id,
        UnitPrice = 1000,
        IsActive = true
    );
    insert testPricebookEntry;

    Product2 testProduct2 = new Product2(
        Name = 'Test Product 02',
        IsActive = true,
        NATT_UnitCost__c = 100
    );
    insert testProduct2;

    Pricebook2 customPb = new Pricebook2(
        Name = 'Custom Pricebook',
        IsActive = true
    );
    insert customPb;

    List<PricebookEntry> pbCheckBef = [SELECT ID, Name FROM PricebookEntry];
    Integer listSizeBefore = pbCheckBef.size();
    System.debug('List Size: ' + listSizeBefore);

    NATT_ItemPriceStaging__c testNattIPS = new NATT_ItemPriceStaging__c(
        NATT_ItemPriceType__c = 'SRP',
        NATT_CustomerPriceGroup__c = testBuyerGroup.Id,
        NATT_CustomerNumber__c = 1,
        NATT_EffectiveDate__c = Date.today() - 1,
        NATT_ExpiryDate__c = Date.today() + 10,
        RecordTypeId = Schema.SObjectType.NATT_ItemPriceStaging__c.getRecordTypeInfosByDeveloperName().get('NATT_PPG').getRecordTypeId()
    );
    insert testNattIPS;

    NATT_PriceAdjustmentStaging__c nattPAS = new NATT_PriceAdjustmentStaging__c(
        NATT_Product__c = testProduct.Id,
        NATT_CustomerPriceGroup__c = testBuyerGroup.Id,
        NATT_CustomerNumber__c = 1,
        NATT_AdjustmentType__c = 'TREGD',
        NATT_AdjustmentValue__c = 17,
        RecordTypeId = Schema.SObjectType.NATT_PriceAdjustmentStaging__c.getRecordTypeInfosByDeveloperName().get('NATT_PPG').getRecordTypeId()
    );
    insert nattPAS;

    Test.startTest();
    NattBatchPriceAdjustment batchPriceAdj = new NattBatchPriceAdjustment();
    Database.executeBatch(batchPriceAdj);
    Test.stopTest();

    List<PricebookEntry> pbCheckAfter = [SELECT ID, Name FROM PricebookEntry];
    Integer listSizeAfter = pbCheckAfter.size();
    System.debug('List Size After: ' + listSizeAfter);
        

        System.assertEquals(listSizeBefore, listSizeAfter, 'Since the Test Product does not include a NATT_UnitCost__c, we do not expect a new Pricebook Entry to get created.');
    }
    
      @isTest
    static void testSendMessage() {
        
        NattBatchPriceAdjustment batchInstance = new NattBatchPriceAdjustment();

        
        List<String> errorMessages = new List<String>();
        errorMessages.add('Error 1: Sample error message 1');
        errorMessages.add('Error 2: Sample error message 2');
        
        Test.startTest();
        batchInstance.sendMessage(errorMessages);
        Test.stopTest();

          }



}