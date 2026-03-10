@IsTest
private class PriceAdjustmentStagingTrgHandlerTest {
	 @TestSetup
    static void setupTestData() {
        Account a = new Account(
            Name='Test',
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
        User testUserNew = new User();
        
        List <AccountShare> acctShare = [SELECT Id, AccountId,  UserOrGroupId FROM AccountShare];
        for (AccountShare testAcctShare : acctShare){
            testUserNew = [SELECT Id, FirstName FROM User WHERE Id = :testAcctShare.UserOrGroupId];
        }

        BuyerGroup testBuyerGroup = new BuyerGroup(
            Name = 'Test BG',
            OwnerId = testUserNew.Id
        );
        insert testBuyerGroup;

        Pricebook2 testPricebook = new Pricebook2 (
            Name = 'Test Pricebook'
        );
        insert testPricebook;

        BuyerGroupPricebook testBuyerGroupPricebook = new BuyerGroupPriceBook (
            BuyerGroupId = testBuyerGroup.Id,
            Pricebook2Id = testPricebook.Id
        );
        insert testBuyerGroupPricebook;
    }

    @isTest
    static void testNewBuyerGroups () {
        Integer testCount = 0;
        Integer testCount_PostInsert = 0;
        WebStore testPPGStorefront = new WebStore (Name = 'Performance Parts');
        insert testPPGStorefront;
        List <BuyerGroupPricebook> testBGPB = [SELECT Id, Name FROM BuyerGroupPricebook];
        BuyerGroup testBuyerGroup = [SELECT ID FROM BuyerGroup];
        NATT_PriceAdjustmentStaging__c newNattIPS = new NATT_PriceAdjustmentStaging__c (
            NATT_CustomerPriceGroup__c = testBuyerGroup.Id,
            NATT_CustomerNumber__c = 1
        );
        insert newNattIPS;

        /*
        List <WebStorePricebook> webTestBeforeInsert = [SELECT Id,Pricebook2Id FROM WebStorePricebook ];

        for(WebStorePricebook wspb : webTestBeforeInsert ){
            testCount ++;
        }

        Test.startTest();
        NATT_ItemPriceStaging__c newNattIPS_NoCustomerPriceGroup = new NATT_ItemPriceStaging__c (
            NATT_CustomerNumber__c = 1
        );
        insert newNattIPS_NoCustomerPriceGroup;
        Test.stopTest();

        List <WebStorePricebook> webTest = [SELECT Id,Pricebook2Id FROM WebStorePricebook ];

        for(WebStorePricebook wspb : webTest ){
            testCount_PostInsert ++;
        }
        System.assertEquals(1, testCount, 'We expect there to be only one WebStorePricebook before the NATT_ItemPriceStaging__c record is inserted.');
        System.assertEquals(2, testCount_PostInsert, 'We expect there to be two WebStorePricebooks after the NATT_ItemPriceStaging__c record is inserted.');
        */
    }
}