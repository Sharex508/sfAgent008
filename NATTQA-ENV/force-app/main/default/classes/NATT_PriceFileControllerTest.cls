@IsTest
public with sharing class NATT_PriceFileControllerTest {
    
    public Class PriceFileWrapper {
        @AuraEnabled public List < PriceFileEntry > priceFiles{get;set;}
    }

    public class PriceFileEntry {
        @AuraEnabled public String Id {get;set;}
        @AuraEnabled public String PartNumber {get;set;}
        @AuraEnabled public String Description {get;set;}
        @AuraEnabled public String PKG {get;set;}
        @AuraEnabled public String Supersedure {get;set;}
        @AuraEnabled public Decimal ListPrice {get;set;}
        @AuraEnabled public String EachPrice {get;set;}
        @AuraEnabled public Boolean ExchCore {get;set;}
        @AuraEnabled public ID CoreReference {get;set;}
        @AuraEnabled public String SignalCode {get;set;}
        @AuraEnabled public String DiscountCode {get;set;}
        @AuraEnabled public String LineOfBusiness {get;set;}
        @AuraEnabled public Decimal Weight {get;set;}
        @AuraEnabled public Decimal Length {get;set;}
        @AuraEnabled public Decimal Width {get;set;}
        @AuraEnabled public Decimal Height {get;set;}
    }
    
    @testSetup
    private static void testSetup() {

        Account a = new Account(
            Name='Test',
            NATT_Customer_Price_Group__c='T1',
            RecordTypeId=Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('Dealer').getRecordTypeId(),
            NATT_Organization__c = 'NATT',
            NATT_Region__c = 'East'
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

        Account brazilAcct = new Account(
            Name='Test',
            NATT_Customer_Price_Group__c='BCO',
            NATT_Organization__c = 'NATT',
            NATT_Region__c = 'East',
            //IsPartner = true,
            RecordTypeId=Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('Dealer').getRecordTypeId()
            );
        insert brazilAcct;
        Contact brazilCon = new Contact(
            AccountId=brazilAcct.Id,
            FirstName='Test',
            LastName='User',
            NATT_Key_Business_Role__c='Principal',
            RecordTypeId=Schema.SObjectType.Contact.getRecordTypeInfosByDeveloperName().get('NATT_Dealer').getRecordTypeId()
            );
        insert brazilCon;
		User thisUser = new User(Id = UserInfo.getUserId());
        id UserRoleid = [SELECT Id FROM UserRole WHERE Name = 'NA Units Manager' LIMIT 1 ].Id;
        thisUser.UserRoleId = UserRoleid;
        
        System.runAs(thisUser) {
            update thisUser;
        }
        
        System.runAs(thisUser) {
		UserRole portalRole = [SELECT Id FROM UserRole WHERE PortalType = 'Partner' LIMIT 1];
        Profile testProfile = [SELECT Id FROM Profile WHERE Name = 'NATT Full Access Community' LIMIT 1];
        User testUserNew = new User(
           // UserRoleId = portalRole.id,
            Username = 'testUserprice@testclass.com', 
            LastName = 'testing1', 
            Email = 'test@test.test', 
            Alias = 'tuser', 
            TimeZoneSidKey = 'America/New_York', 
            LocaleSidKey = 'en_US', 
            EmailEncodingKey = 'ISO-8859-1', 
            ProfileId = testProfile.Id,
            LanguageLocaleKey = 'en_US',
            ContactId = c.Id
        );
        insert testUserNew;
        User testUserBrazil = new User(
            //UserRoleId = portalRole.id,
            Username = 'testUserBrazil@testclass.com', 
            LastName = 'testing', 
            Email = 'test@test.test', 
            Alias = 'tuser', 
            TimeZoneSidKey = 'America/New_York', 
            LocaleSidKey = 'en_US', 
            EmailEncodingKey = 'ISO-8859-1', 
            ProfileId = testProfile.Id,
            LanguageLocaleKey = 'en_US',
            ContactId = brazilCon.Id
        );
        insert testUserBrazil;
        }

        // User testUserNew2 = new User(
        //     Username = '2test2User@2test2class.com', 
        //     LastName = 'testing', 
        //     Email = 'test@test.test', 
        //     Alias = 'tuser', 
        //     TimeZoneSidKey = 'America/New_York', 
        //     LocaleSidKey = 'en_US', 
        //     EmailEncodingKey = 'ISO-8859-1', 
        //     ProfileId = testProfile.Id,
        //     LanguageLocaleKey = 'en_US',
        //     ContactId = c2.Id
        // );
        // insert testUserNew2;

        Pricebook2 testPricebook = new Pricebook2 (
            Id = Test.getStandardPricebookId(),
            Name = 'Standard Price Book',            
            IsActive = true
        );
        update testPricebook;

        Product2 testProduct = new Product2(
        	Name = 'Test Product 1',
            IsActive = true,
            NATT_UnitCost__c = 17,
            NATT_UOM_Conversion__c = 3,
            NATT_CoreItem_P_N__c = '12-00064-5115RC',
            Description = 'This is a test description'
        );
        insert testProduct;
 
        PricebookEntry testPricebookEntry = new PricebookEntry (
            Pricebook2Id = Test.getStandardPricebookId(),    
            Product2Id = testProduct.Id,
            UnitPrice = 1000,
            IsActive = true,
            NATT_Effective_Date__c = date.today() - 5
        );
        insert testPricebookEntry;

        Pricebook2 customPricebook = new Pricebook2 (
            Name = 'T1',
            isActive = true
        );
        insert customPricebook;

        Pricebook2 customPricebookX1V = new Pricebook2 (
            Name = 'V1X',
            isActive = true
        );
        insert customPricebookX1V;
        Product2 testProduct2 = new Product2(
        	Name = 'Test Product 2',
            IsActive = true,
            NATT_UOM_Conversion__c = 1,
            NATT_CoreItem_P_N__c = '20-12-5115',
            NATT_UnitCost__c = 999
                    );
        insert testProduct2;

        PricebookEntry testPricebookEntry2 = new PricebookEntry (
            Pricebook2Id = customPricebook.Id,    
            Product2Id = testProduct.Id,
            UnitPrice = 9999,
            IsActive = true,
            NATT_Effective_Date__c = date.today() - 400
        );
        insert testPricebookEntry2;

        PricebookEntry testPricebookEntry3 = new PricebookEntry (
            Pricebook2Id = customPricebookX1V.Id,    
            Product2Id = testProduct.Id,
            UnitPrice = 9999,
            IsActive = true,
            NATT_Effective_Date__c = date.today() - 400
        );
        insert testPricebookEntry3;

        WebStore testPPGStorefront = new WebStore (
            Name = 'Performance Parts'
        );
        insert testPPGStorefront;
  }

    @IsTest
    static void grabPriceFileDetails_Test(){
        User testUser = [SELECT ID FROM User WHERE username = 'testUserprice@testclass.com' LIMIT 1];    //T1 User
        User testUserBrazil = [SELECT ID FROM User WHERE username = 'testUserBrazil@testclass.com' LIMIT 1];    //CTBR User


        String customerPriceGroup = null;
        Test.startTest();
        System.runAs(testUser){        	
            customerPriceGroup  = NATT_PriceFileController.getCustomerPriceGroup();
            system.debug('customerPriceGroup-'+customerPriceGroup);
            NATT_PriceFileController.getPriceFileDetails('T1');
            NATT_PriceFileController.getAltItemMap();
        }
        Test.stopTest();
       // System.assertEquals('T1', customerPriceGroup, 'We expect the Customer Price Group to be equal to Account a\'s value in test setup method.');
    }

    @IsTest
    static void grabPriceFileDetailsBrazil_Test(){
        User testUserBrazil = [SELECT ID FROM User WHERE username = 'testUserBrazil@testclass.com' LIMIT 1];    //CTBR User
        String customerPriceGroup = null;
        Test.startTest();
        System.runAs(testUserBrazil){        	
            customerPriceGroup  = NATT_PriceFileController.getCustomerPriceGroup();
            NATT_PriceFileController.getPriceFileDetails('BCO');
            NATT_PriceFileController.getAltItemMap();
        }
        Test.stopTest();
       // System.assertEquals('CTBR Storefront Container', customerPriceGroup, 'We expect the Brazil Customer Price Group to be equal to the Brazil Pricebook Name.');
    }

    @IsTest
    static void grabPriceFileDeails_Test(){
        NATT_PriceFileController.PriceFileWrapper testWrapper = new NATT_PriceFileController.PriceFileWrapper();
        NATT_PriceFileController.PriceFileWrapper testWrapper2 = new NATT_PriceFileController.PriceFileWrapper();

        User testUser = [SELECT ID FROM User WHERE username = 'testUserprice@testclass.com' LIMIT 1];    //T1 User
        // User testUser2 = [SELECT ID FROM User WHERE username = '2test2User@2test2class.com' LIMIT 1];
        String customerPriceGroup,customerPriceGroup2;
        // System.runAs(testUser){
    	//     customerPriceGroup  = NATT_PriceFileController.getCustomerPriceGroup();
        //     System.debug('Customer Price Group: ' + customerPriceGroup);
        // }
        customerPriceGroup = 'T1';
        // System.runAs(testUser2){
	    //     customerPriceGroup2  = NATT_PriceFileController.getCustomerPriceGroup();
        // }

        Pricebook2 t1Pricebook = [SELECT ID, Name FROM Pricebook2 WHERE Name = 'T1'];
        Pricebook2 t1Pricebook2 = [SELECT ID, Name FROM Pricebook2 WHERE Name = 'V1X'];

        Product2 testProductPagination = new Product2(
        	Name = 'Test Pagination 01',
            IsActive = true,
            NATT_UnitCost__c = 1990,
            NATT_UOM_Conversion__c = 5,
            NATT_CoreItem_P_N__c = '12-06464-5115RC',
            Description = 'This is a NEW test description'
        );
        insert testProductPagination;

        Product2 testProductPagination2 = new Product2(
            Name = 'Test Pagination 01',
            IsActive = true,
            NATT_UnitCost__c = 1991,
            NATT_UOM_Conversion__c = 5,
            NATT_CoreItem_P_N__c = '12-06464-5115RC',
            Description = 'This is a NEW test description'
        );
        insert testProductPagination2;
    
        PricebookEntry testPricebookEntryPagination = new PricebookEntry (
            Pricebook2Id = Test.getStandardPricebookId(),    
            Product2Id = testProductPagination.Id,
            UnitPrice = 0,
            IsActive = true,
            NATT_Effective_Date__c = date.today() - 5
        );
        insert testPricebookEntryPagination;

        PricebookEntry testPricebookEntryPagination2 = new PricebookEntry (
            Pricebook2Id = t1Pricebook.Id,    
            Product2Id = testProductPagination.Id,
            UnitPrice = 900,
            IsActive = true,
            NATT_Effective_Date__c = date.today() - 5
        );
        insert testPricebookEntryPagination2;

        PricebookEntry testPricebookEntryPagination3 = new PricebookEntry (
            Pricebook2Id = Test.getStandardPricebookId(),    
            Product2Id = testProductPagination2.Id,
            UnitPrice = 10,
            IsActive = true,
            NATT_Effective_Date__c = date.today() - 5
        );
        insert testPricebookEntryPagination3;

        PricebookEntry testPricebookEntryPagination4 = new PricebookEntry (
            Pricebook2Id = t1Pricebook2.Id,    
            Product2Id = testProductPagination2.Id,
            UnitPrice = 200,
            IsActive = true,
            NATT_Effective_Date__c = date.today() - 5
        );
        insert testPricebookEntryPagination4;

        Integer limitValue = 10;
        String lastRecordId = null; 
        String lastRecordName = null; 
        String nextOrPrevious = null;  
        String dayValue = null;  
        String advancedDate = null; 
        Test.startTest();
        testWrapper = NATT_PriceFileController.grabPriceFileDetails(customerPriceGroup, limitValue, lastRecordId, lastRecordName, nextOrPrevious, dayValue, advancedDate);
        // testWrapper2 = NATT_PriceFileController.grabPriceFileDetails(customerPriceGroup2, limitValue, lastRecordId, lastRecordName, nextOrPrevious, dayValue, advancedDate);
        Test.stopTest();

        SYstem.debug('testWrapper1: ' + testWrapper);
        // SYstem.debug('testWrapper2: ' + testWrapper2);
        Boolean recordCheck1 = false;
        Boolean recordCheck2 = false;
        if(testWrapper.priceFiles != null){
            recordCheck1 = true;
        }
        // if(testWrapper2.priceFiles != null ){
        //     recordCheck2 = true;
        // }
    
        System.assertEquals(true, recordCheck1, 'We expect the T1 user to query records for UI table display.');
        // System.assertEquals(true, recordCheck2, 'We expect the other/standard user to query records for UI table display.');
    }

    @IsTest
    static void grabPriceFileDeails_Pagination_Test(){
        NATT_PriceFileController.PriceFileWrapper testWrapper = new NATT_PriceFileController.PriceFileWrapper();
        NATT_PriceFileController.PriceFileWrapper testWrapper2 = new NATT_PriceFileController.PriceFileWrapper();

        User testUser = [SELECT ID FROM User WHERE username = 'testUserprice@testclass.com' LIMIT 1];    //T1 User
        // User testUser2 = [SELECT ID FROM User WHERE username = '2test2User@2test2class.com' LIMIT 1];

        String customerPriceGroup,customerPriceGroup2;
        // System.runAs(testUser){
    	//     customerPriceGroup  = NATT_PriceFileController.getCustomerPriceGroup();
        // }
        // System.runAs(testUser2){
	    //     customerPriceGroup2  = NATT_PriceFileController.getCustomerPriceGroup();
        // }
        customerPriceGroup = 'T1';
        Pricebook2 t1Pricebook = [SELECT ID, Name FROM Pricebook2 WHERE Name = 'T1'];
        Pricebook2 t1Pricebook2 = [SELECT ID, Name FROM Pricebook2 WHERE Name = 'V1X'];

        Product2 testProductPagination = new Product2(
        	Name = 'Test Pagination 01',
            IsActive = true,
            NATT_UnitCost__c = 1990,
            NATT_UOM_Conversion__c = 5,
            NATT_CoreItem_P_N__c = '12-06464-5115RC',
            Description = 'This is a NEW test description'
        );
        insert testProductPagination;

        Product2 testProductPagination2 = new Product2(
            Name = 'Test Pagination 01',
            IsActive = true,
            NATT_UnitCost__c = 1991,
            NATT_UOM_Conversion__c = 5,
            NATT_CoreItem_P_N__c = '12-06464-5115RC',
            Description = 'This is a NEW test description'
        );
        insert testProductPagination2;
    
        PricebookEntry testPricebookEntryPagination = new PricebookEntry (
            Pricebook2Id = Test.getStandardPricebookId(),    
            Product2Id = testProductPagination.Id,
            UnitPrice = 0,
            IsActive = true,
            NATT_Effective_Date__c = date.today() - 5
        );
        insert testPricebookEntryPagination;

        PricebookEntry testPricebookEntryPagination2 = new PricebookEntry (
            Pricebook2Id = t1Pricebook.Id,    
            Product2Id = testProductPagination.Id,
            UnitPrice = 900,
            IsActive = true,
            NATT_Effective_Date__c = date.today() - 5
        );
        insert testPricebookEntryPagination2;

        PricebookEntry testPricebookEntryPagination3 = new PricebookEntry (
            Pricebook2Id = Test.getStandardPricebookId(),    
            Product2Id = testProductPagination2.Id,
            UnitPrice = 10,
            IsActive = true,
            NATT_Effective_Date__c = date.today() - 5
        );
        insert testPricebookEntryPagination3;

        PricebookEntry testPricebookEntryPagination4 = new PricebookEntry (
            Pricebook2Id = t1Pricebook2.Id,    
            Product2Id = testProductPagination2.Id,
            UnitPrice = 200,
            IsActive = true,
            NATT_Effective_Date__c = date.today() - 5
        );
        insert testPricebookEntryPagination4;

        Integer limitValue = 10;
        String lastRecordId = null; 
        String lastRecordName = 'Test Product 1'; 
        String nextOrPrevious = 'previous';  
        String dayValue = null;  
        String advancedDate = null; 
        Test.startTest();
        testWrapper = NATT_PriceFileController.grabPriceFileDetails(customerPriceGroup, limitValue, lastRecordId, lastRecordName, nextOrPrevious, dayValue, advancedDate);
        // testWrapper2 = NATT_PriceFileController.grabPriceFileDetails(customerPriceGroup2, limitValue, lastRecordId, lastRecordName, nextOrPrevious, dayValue, advancedDate);
        Test.stopTest();

        Boolean recordCheck1 = false;
        Boolean recordCheck2 = false;
        if(testWrapper.priceFiles != null){
            recordCheck1 = true;
        }
        // if(testWrapper2.priceFiles != null ){
        //     recordCheck2 = true;
        // }
    
        System.assertEquals(true, recordCheck1, 'We expect the T1 user to query records for UI table display.');
        // System.assertEquals(true, recordCheck2, 'We expect the other/standard user to query records for UI table display.');
    }

    @IsTest
    static void grabPriceFileDeails_AdvancedBooks_Test(){
        NATT_PriceFileController.PriceFileWrapper testWrapper = new NATT_PriceFileController.PriceFileWrapper();
        NATT_PriceFileController.PriceFileWrapper testWrapper2 = new NATT_PriceFileController.PriceFileWrapper();

        User testUser = [SELECT ID FROM User WHERE username = 'testUserprice@testclass.com' LIMIT 1];    //T1 User
        // User testUser2 = [SELECT ID FROM User WHERE username = '2test2User@2test2class.com' LIMIT 1];

        String customerPriceGroup,customerPriceGroup2;
        // System.runAs(testUser){
    	//     customerPriceGroup  = NATT_PriceFileController.getCustomerPriceGroup();
        // }
        // System.runAs(testUser2){
	    //     customerPriceGroup2  = NATT_PriceFileController.getCustomerPriceGroup();
        // }
        customerPriceGroup = 'T1';
        Pricebook2 t1Pricebook = [SELECT ID, Name FROM Pricebook2 WHERE Name = 'T1'];

        Product2 testProductPagination = new Product2(
        	Name = 'Test Pagination 01',
            IsActive = true,
            NATT_UnitCost__c = 1990,
            NATT_UOM_Conversion__c = 5,
            NATT_CoreItem_P_N__c = '12-06464-5115RC',
            Description = 'This is a NEW test description'
        );
        insert testProductPagination;

        Product2 testProductPagination2 = new Product2(
            Name = 'Test Pagination 01',
            IsActive = true,
            NATT_UnitCost__c = 1991,
            NATT_UOM_Conversion__c = 5,
            NATT_CoreItem_P_N__c = '12-06464-5115RC',
            Description = 'This is a NEW test description'
        );
        insert testProductPagination2;
    
        PricebookEntry testPricebookEntryPagination = new PricebookEntry (
            Pricebook2Id = Test.getStandardPricebookId(),    
            Product2Id = testProductPagination.Id,
            UnitPrice = 0,
            IsActive = true,
            NATT_Effective_Date__c = date.today() + 5
        );
        insert testPricebookEntryPagination;

        PricebookEntry testPricebookEntryPagination2 = new PricebookEntry (
            Pricebook2Id = t1Pricebook.Id,    
            Product2Id = testProductPagination.Id,
            UnitPrice = 900,
            IsActive = true,
            NATT_Effective_Date__c = date.today() + 15
        );
        insert testPricebookEntryPagination2;

        PricebookEntry testPricebookEntryPagination3 = new PricebookEntry (
            Pricebook2Id = Test.getStandardPricebookId(),    
            Product2Id = testProductPagination2.Id,
            UnitPrice = 10,
            IsActive = true,
            NATT_Effective_Date__c = date.today() + 5
        );
        insert testPricebookEntryPagination3;

        PricebookEntry testPricebookEntryPagination4 = new PricebookEntry (
            Pricebook2Id = t1Pricebook.Id,    
            Product2Id = testProductPagination2.Id,
            UnitPrice = 200,
            IsActive = true,
            NATT_Effective_Date__c = date.today() + 5
        );
        insert testPricebookEntryPagination4;

        String userIdValue = testUser.Id;

        PricebookEntry pbE = [SELECT Id, UnitPrice, name FROM PricebookEntry WHERE UnitPrice = 1000];


        Integer limitValue = 10;
        String lastRecordId = null; 
        String lastRecordName = 'Test Product 1'; 
        String nextOrPrevious = 'previous';  
        String dayValue = null;  
        String advancedDate = '90'; 
        Test.startTest();
        testWrapper = NATT_PriceFileController.grabPriceFileDetails(customerPriceGroup, limitValue, lastRecordId, lastRecordName, nextOrPrevious, dayValue, advancedDate);
        // testWrapper2 = NATT_PriceFileController.grabPriceFileDetails(customerPriceGroup2, limitValue, lastRecordId, lastRecordName, nextOrPrevious, dayValue, advancedDate);
        Test.stopTest();
        SYstem.debug('testWrapper1: ' + testWrapper);
        SYstem.debug('testWrapper2: ' + testWrapper2);
        Boolean recordCheck1 = false;
        Boolean recordCheck2 = false;
        if(testWrapper.priceFiles != null){
            recordCheck1 = true;
        }
        // if(testWrapper2.priceFiles != null ){
        //     recordCheck2 = true;
        // }
    
        System.assertEquals(true, recordCheck1, 'We expect the T1 user to query records for UI table display.');
        // System.assertEquals(true, recordCheck2, 'We expect the other/standard user to query records for UI table display.');
    }

    @IsTest
    static void grabPriceFileDeails_BlankCPG_Test(){
        NATT_PriceFileController.PriceFileWrapper testWrapper = new NATT_PriceFileController.PriceFileWrapper();
        NATT_PriceFileController.PriceFileWrapper testWrapper2 = new NATT_PriceFileController.PriceFileWrapper();

        User testUser = [SELECT ID FROM User WHERE username = 'testUserprice@testclass.com' LIMIT 1];    //T1 User
        // User testUser2 = [SELECT ID FROM User WHERE username = '2test2User@2test2class.com' LIMIT 1];

        String customerPriceGroup  = null;
        String customerPriceGroup2  = null;

        Pricebook2 t1Pricebook = [SELECT ID, Name FROM Pricebook2 WHERE Name = 'T1'];

        Product2 testProductPagination = new Product2(
        	Name = 'Test Pagination 01',
            IsActive = true,
            NATT_UnitCost__c = 1990,
            NATT_UOM_Conversion__c = 5,
            NATT_CoreItem_P_N__c = '12-06464-5115RC',
            Description = 'This is a NEW test description'
        );
        insert testProductPagination;

        Product2 testProductPagination2 = new Product2(
            Name = 'Test Pagination 01',
            IsActive = true,
            NATT_UnitCost__c = 1991,
            NATT_UOM_Conversion__c = 5,
            NATT_CoreItem_P_N__c = '12-06464-5115RC',
            Description = 'This is a NEW test description'
        );
        insert testProductPagination2;
    
        PricebookEntry testPricebookEntryPagination = new PricebookEntry (
            Pricebook2Id = Test.getStandardPricebookId(),    
            Product2Id = testProductPagination.Id,
            UnitPrice = 0,
            IsActive = true,
            NATT_Effective_Date__c = date.today() - 5
        );
        insert testPricebookEntryPagination;

        PricebookEntry testPricebookEntryPagination2 = new PricebookEntry (
            Pricebook2Id = t1Pricebook.Id,    
            Product2Id = testProductPagination.Id,
            UnitPrice = 900,
            IsActive = true,
            NATT_Effective_Date__c = date.today() - 5
        );
        insert testPricebookEntryPagination2;

        PricebookEntry testPricebookEntryPagination3 = new PricebookEntry (
            Pricebook2Id = Test.getStandardPricebookId(),    
            Product2Id = testProductPagination2.Id,
            UnitPrice = 10,
            IsActive = true,
            NATT_Effective_Date__c = date.today() - 5
        );
        insert testPricebookEntryPagination3;

        PricebookEntry testPricebookEntryPagination4 = new PricebookEntry (
            Pricebook2Id = t1Pricebook.Id,    
            Product2Id = testProductPagination2.Id,
            UnitPrice = 200,
            IsActive = true,
            NATT_Effective_Date__c = date.today() - 5
        );
        insert testPricebookEntryPagination4;

        String userIdValue = testUser.Id;

        PricebookEntry pbE = [SELECT Id, UnitPrice, name FROM PricebookEntry WHERE UnitPrice = 1000];


        Integer limitValue = 10;
        String lastRecordId = null; 
        String lastRecordName = 'Test Product 1'; 
        String nextOrPrevious = 'previous';  
        String dayValue = null;  
        String advancedDate = '90'; 
        Test.startTest();
        testWrapper = NATT_PriceFileController.grabPriceFileDetails(customerPriceGroup, limitValue, lastRecordId, lastRecordName, nextOrPrevious, dayValue, advancedDate);
        // testWrapper2 = NATT_PriceFileController.grabPriceFileDetails(customerPriceGroup2, limitValue, lastRecordId, lastRecordName, nextOrPrevious, dayValue, advancedDate);
        Test.stopTest();

        Boolean recordCheck1 = false;
        Boolean recordCheck2 = false;
        SYstem.debug('testWrapper: ' + testWrapper);
        if(testWrapper.priceFiles == null){
            recordCheck1 = true;
        }
        // if(testWrapper2.priceFiles == null ){
        //     recordCheck2 = true;
        // }
    
        System.assertEquals(true, recordCheck1, 'We expect the T1 (External Customer) user to return null because no CPG was assigned.');
        // System.assertEquals(true, recordCheck2, 'We expect the V1 (Internal Customer) user to return null because no CPG was assigned..');
    }
    
}