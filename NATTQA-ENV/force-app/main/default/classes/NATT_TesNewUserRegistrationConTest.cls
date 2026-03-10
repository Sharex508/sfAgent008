@isTest
public with sharing class NATT_TesNewUserRegistrationConTest {       
    @testSetup 
    static void init() {
        UserRole portalRole = [SELECT Id FROM UserRole WHERE PortalType = 'None' LIMIT 1];
        Profile profile1 = [SELECT Id FROM Profile WHERE name = 'System Administrator'];
        User portalAccountOwner1 = new User(
            UserRoleId = portalRole.Id,
            ProfileId = profile1.Id,
            Username = System.now().millisecond() + 'tesUsertest2@test.com',
            Alias = 'batman',
            Email='bruce.wayne1@wayneenterprises.com',
            EmailEncodingKey='UTF-8',
            Firstname='Bruce',
            Lastname='Wayne',
            LanguageLocaleKey='en_US',
            LocaleSidKey='en_US',
            TimeZoneSidKey='America/Chicago'
        );
        Database.insert(portalAccountOwner1);

        //Create account
        Account portalAccount1 = new Account(
            Name = 'TestAccount',
            OwnerId = portalAccountOwner1.Id
        );
        // Database.insert(portalAccount1);
        System.runAs(portalAccountOwner1){
            Database.insert(portalAccount1);
            //Create contact
            Contact contact1 = new Contact(
                FirstName = 'Test',
                    Lastname = 'McTesty',
                AccountId = portalAccount1.Id,
                    Email = System.now().millisecond() + 'test@test.com'
            );
            Database.insert(contact1);
                    
            //Create user
            Profile portalProfile = [SELECT Id FROM Profile WHERE Name = 'System Administrator' Limit 1];
            User user1 = new User(
                // Username = System.now().millisecond() + 'test12345@test.com',
                Username ='testUser@testclass.com',
                // ContactId = contact1.Id,
                ProfileId = portalProfile.Id,
                Alias = 'test123',
                Email = 'test12345@test.com',
                EmailEncodingKey = 'UTF-8',
                LastName = 'McTesty',
                CommunityNickname = 'test12345',
                TimeZoneSidKey = 'America/Los_Angeles',
                LocaleSidKey = 'en_US',
                LanguageLocaleKey = 'en_US'
            );
            Database.insert(user1);
            BuyerGroup tesBuyerGroup = new BuyerGroup(
                Name = 'TES Storefront Buyer Group'
            );
            insert tesBuyerGroup;
            }
        }

        public class GoogleHTTPCalloutMock implements HttpCalloutMock {
        // Implement this interface method
        public HTTPResponse respond(HTTPRequest req) {
            // Create a fake response
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setBody('{"success":"true"}');
            res.setStatusCode(200);
            return res;
        }
    }

    @isTest
    static void validateButton_Test(){
        // Test.setMock(WebServiceMock.class, new WebServiceMock)
        User runUser = [SELECT ID, LastName FROM User WHERE LastName = 'McTesty'];
        // User runUser = [SELECT ID, LastName FROM User WHERE LastName = 'testGuestUser'];

        Test.setMock(HttpCalloutMock.class, new NATT_TesNewUserRegistrationConTest.GoogleHTTPCalloutMock());
        System.runAs(runUser){
            Test.startTest();
            String returnValue = Natt_TesNewUserRegistrationCon.validateButton('Success');
            System.debug('Return Value: ' + returnValue);
            Test.stopTest();
        }

    }

    @isTest
    static void createPortalUser_Test(){
        Profile testProfile = [SELECT Id FROM Profile WHERE Name = 'NATT Full Access Community' LIMIT 1];
        Contact c = [SELECT ID FROM Contact];
        
        User testUser = new User(
            Username = System.now().millisecond() + 'testUser1@testclass.com', 
            LastName = 'testing', 
            FirstName = 'TES', 
            Email = 'testUser@testclass.com',
            Alias = 'tuser', 
            TimeZoneSidKey = 'America/New_York', 
            LocaleSidKey = 'en_US', 
            ProfileId = testProfile.Id,
            LanguageLocaleKey = 'en_US',
            ContactId = c.Id,
            EmailEncodingKey = 'ISO-8859-1' 
        );
        insert testUser;
            // insert testUser;
        String userId = 'testUserValue';
        String customerName = 'TES';
        String customerLastName = 'testing';
        String password = 'password55!!';
        String email = 'testUser1@testclass.com';
        String company = 'TEST TES';
        String phone = '1325551212';
        String communityId = 'test';
        String street = '123 Ultra Ave';
        String city = 'Miami';
        String state = 'GA';
        String postalCode = '23998';
        String country = 'US';
        // User testUser = [SELECT ID, UserName, FirstName, LastName FROM User LIMIT 1];
        String createUserResult = null;
        Test.startTest();
        // System.runAs(testUser){
            createUserResult = Natt_TesNewUserRegistrationCon.createPortalUser(userId, communityId, customerName, customerLastName, password, email, company, phone, street, city, state, postalCode, country );
        // }
    //   Natt_NewUserRegistrationController.assignPermissions(testUser.Id);
        Test.stopTest();
        System.debug('createUserResult: ' + createUserResult);
        System.assertEquals('SUCCESS', createUserResult, 'We expect createPortalUser method to return a SUCCESS value.');
    }

        @isTest
        static void createPortalUser_TestPermissions(){
        Profile testProfile = [SELECT Id FROM Profile WHERE Name = 'NATT Full Access Community' LIMIT 1];
        Contact c = [SELECT ID FROM Contact];
        User testUser = new User(
            Username = System.now().millisecond() + 'testUser2@testclass.com', 
            LastName = 'testing', 
            FirstName = 'TES', 
            Email = 'testUser@testclass.com',
            Alias = 'tuser', 
            TimeZoneSidKey = 'America/New_York', 
            LocaleSidKey = 'en_US', 
            ProfileId = testProfile.Id,
            LanguageLocaleKey = 'en_US',
            ContactId = c.Id,
            EmailEncodingKey = 'ISO-8859-1' 
        );
        insert testUser;
        String userId = 'testUserValue';
        String customerName = 'TESTestUser';
        String customerLastName = 'LastNameTest';
        String password = 'password55!!';
        String email = 'testUser1@testclass.com';
        String company = 'TEST TES';
        String phone = '1325551212';
        String communityId = 'test';
        String street = '123 Ultra Ave';
        String city = 'Miami';
        String state = 'GA';
        String postalCode = '23998';
        String country = 'US';
        String createUserResult = null;
        Test.startTest();

        Natt_TesNewUserRegistrationCon.assignPermissions(testUser.Id);
        Test.stopTest();
        List<PermissionSetAssignment> psaList = [SELECT Id, AssigneeId FROM PermissionSetAssignment WHERE AssigneeId = :testUser.Id];
        System.debug('psaList: ' + psaList);
    }

    @isTest
    static void createPortalUser_TestBuyerGroup(){
        Profile testProfile = [SELECT Id FROM Profile WHERE Name = 'NATT Full Access Community' LIMIT 1];
        Profile guestProfile = [SELECT Id FROM Profile WHERE Name = 'TES Storefront Profile' LIMIT 1];
        Account a = [SELECT ID FROM Account];

        String userId = 'testUserValue';
        String customerName = 'TESTestUser';
        String customerLastName = 'LastNameTest';
        String password = 'password55!!';
        String email = 'testUser1@testclass.com';
        String company = 'TEST TES';
        String phone = '1325551212';
        String communityId = 'test';
        String street = '123 Ultra Ave';
        String city = 'Miami';
        String state = 'GA';
        String postalCode = '23998';
        String country = 'US';
        // User testUser = [SELECT ID, UserName, FirstName, LastName FROM User LIMIT 1];
        String createUserResult = null;
        BuyerAccount customerBuyerAccount = new BuyerAccount(
        BuyerId = a.Id,
        isActive = true,
        Name = company
    );
    insert customerBuyerAccount;
        Test.startTest();
        Natt_TesNewUserRegistrationCon.assignBuyerGroup(a.Id);
        Test.stopTest();

        List<BuyerGroupMember> bgmList = [SELECT buyerId, BuyerGroupId FROM BuyerGroupMember WHERE buyerId = :a.Id];
        System.debug('bgmList: ' + bgmList);
    }

        @isTest
        static void createPortalUser_ExistingEmail_Test(){
        Profile testProfile = [SELECT Id FROM Profile WHERE Name = 'NATT Full Access Community' LIMIT 1];
        Contact c = [SELECT ID FROM Contact];

        String userId = 'testUserValue';
        String customerName = 'TESTestUser';
        String customerLastName = 'LastNameTest';
        String password = 'password55!!';
        String email = 'test12345@test.com';
        String company = 'TEST TES';
        String phone = '1325551212';
        String communityId = 'test';
        String street = '123 Ultra Ave';
        String city = 'Miami';
        String state = 'GA';
        String postalCode = '23998';
        String country = 'US';
        // User testUser = [SELECT ID, UserName, FirstName, LastName FROM User LIMIT 1];
        String createUserResult = null;
        Test.startTest();
            createUserResult = Natt_TesNewUserRegistrationCon.createPortalUser(userId, communityId, customerName, customerLastName, password, email, company, phone, street, city, state, postalCode, country );
        Test.stopTest();
        System.debug('createUserResult: ' + createUserResult);
        System.assertEquals('EMAIL', createUserResult, 'We expect createPortalUser method to return an EMAIL value since there is already a user with the same email.');

        }

}