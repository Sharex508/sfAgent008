@isTest
public with sharing class NATT_AccountInformationHelperTest {

    @TestSetup
    static void setupTestData() {
        Profile testProfile = [SELECT Id FROM Profile WHERE Name = 'NATT Full Access Community' LIMIT 1];
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
        User testUser = new User(
            Username = 'testUser@testclass.com', 
            LastName = 'testing', 
            Email = 'test@test.test', 
            Alias = 'tuser', 
            TimeZoneSidKey = 'America/New_York', 
            LocaleSidKey = 'en_US', 
            EmailEncodingKey = 'ISO-8859-1', 
            ProfileId = testProfile.Id,
            LanguageLocaleKey = 'en_US',
            ContactId = c.Id
        );
        insert testUser;
    }

    //EffectiveAccount method used to grab account details.
    @isTest
    public static void grabEfectiveAccount_Test(){
        Account testAccount = [SELECT ID FROM Account];
        Account newAcct = new Account();
        Test.startTest();
        newAcct = NATT_AccountInformationHelper.grabEffectiveAccount(testAccount.Id);
        Test.stopTest();
        System.assertEquals(testAccount.Id, newAcct.Id, 'We expect the method to return a detailed view of the Account.');
    }


    @isTest
    public static void grabAddresses_Test(){
        Account testAccount = [SELECT ID FROM Account];
        User testUserNew = [SELECT ID FROM User WHERE Email = 'test@test.test'];
        ContactPointAddress testAddress = new ContactPointAddress(
           Name = 'Test Address', 
           ParentId = testAccount.id,  
           street = '105 Test Street', 
           city = 'Atlanta', 
           state = 'GA',
           Country='US',
           NATT_Address__c = null,
           AddressType = 'Shipping'
        );
        insert testAddress;
        ContactPointAddress contactPointAddresses = [SELECT Id, Name, ParentId, Address, street, city, state, NATT_Address__c, AddressType FROM ContactPointAddress]; 

        List <ContactPointAddress> newAddressGrab = new List <ContactPointAddress>();

        Test.startTest();
            newAddressGrab = NATT_AccountInformationHelper.grabAddresses(testAccount.Id);
        Test.stopTest();
       
        String addressName = '';
        for(ContactPointAddress contactAddress : newAddressGrab){
            addressName = contactAddress.Name;
        }
        System.assertEquals('Test Address', addressName, 'We expect the User Id to query the Address.');
    }

    @isTest
    public static void grabJdeAddresses_Test(){
        Account testAccount = [SELECT ID FROM Account];
        User testUserNew = [SELECT ID FROM User WHERE Email = 'test@test.test'];
        NATT_Address__c testJdeAddress = new NATT_Address__c(
            Name = 'Test JDE',
            NATT_Street__c = '123 Test Drive',
            NATT_Account__c = testAccount.Id
        );
        insert testJdeAddress;

        ContactPointAddress testAddress = new ContactPointAddress(
           Name = 'Test Address', 
           ParentId = testAccount.id,  
           street = '105 Test Street', 
           city = 'Atlanta', 
           state = 'GA',
           Country='US',
           NATT_Address__c = testJdeAddress.Id,
           AddressType = 'Shipping'
        );
        insert testAddress;
        ContactPointAddress contactPointAddresses = [SELECT Id, Name, ParentId, Address, street, city, state, NATT_Address__c, AddressType FROM ContactPointAddress]; 

        List <ContactPointAddress> newAddressGrab = new List <ContactPointAddress>();

        Test.startTest();
            newAddressGrab = NATT_AccountInformationHelper.grabJdeAddresses(testAccount.Id);
        Test.stopTest();
       
        String addressName = '';
        for(ContactPointAddress contactAddress : newAddressGrab){
            addressName = contactAddress.Name;
        }
        System.assertEquals('Test Address', addressName, 'We expect the User Id to query the Address.');
    }


    @isTest
    public static void updateAddress_Test(){
        Boolean updateCheck = false;
        Boolean updateCheckFailure = false;
        Account testAccount = [SELECT ID FROM Account];
        User testUserNew = [SELECT ID FROM User WHERE Email = 'test@test.test'];
        List <ContactPointAddress> addressList = new List <ContactPointAddress> ();
        List <ContactPointAddress> addressListToFail = new List <ContactPointAddress> ();
        ContactPointAddress testAddress = new ContactPointAddress(
           Name = 'Test Address', 
           ParentId = testAccount.id,  
           street = '105 Test Street', 
           city = 'Atlanta', 
           state = 'GA',
           Country='US'
        );
        insert testAddress;

        ContactPointAddress testAddressToFail = new ContactPointAddress(
            Name = 'Failed Address', 
            ParentId = testAccount.id,  
            street = '001 First Street', 
            city = 'Atlanta', 
            state = 'GA'
         );
         addressListToFail.add(testAddressToFail);

        Test.startTest();
        addressList = [SELECT Id, Name FROM ContactPointAddress WHERE Id = :testAddress.Id];
        for(ContactPointAddress cpa : addressList){
            cpa.Name = 'Updated Address';
        }
        updateCheck = NATT_AccountInformationHelper.updateAddresses(addressList);
        updateCheckFailure = NATT_AccountInformationHelper.updateAddresses(addressListToFail);
        Test.stopTest();

        System.assertEquals(true, updateCheck, 'We expect the Contact Point Address List to successfully update.');
        System.assertEquals(false, updateCheckFailure, 'We do not expect this List to update because the Contact Point Address has not been properly inserted yet.');

    }

    @isTest
    public static void grabAccountDetails_Test(){
        Account testAccount = [SELECT ID FROM Account];
        Test.startTest();
        NATT_AccountInformationHelper.grabAccountDetails(testAccount.Id);
        Test.stopTest();
    }

    @isTest
    public static void deleteAddress_test(){
        Boolean updateCheck = false;
        Boolean updateCheckFailure = false;
        Account testAccount = [SELECT ID FROM Account];
        User testUserNew = [SELECT ID FROM User WHERE Email = 'test@test.test'];
        List <ContactPointAddress> addressList = new List <ContactPointAddress> ();
        List <ContactPointAddress> addressListToFail = new List <ContactPointAddress> ();

        ContactPointAddress testAddress = new ContactPointAddress(
           Name = 'Test Address', 
           ParentId = testAccount.id,  
           street = '105 Test Street', 
           city = 'Atlanta', 
           state = 'GA',
           Country='US'
        );
        insert testAddress;
        List <ContactPointAddress> listOfAddressesBeforeDelete = new List <ContactPointAddress>();
        List <ContactPointAddress> listOfAddressesAfterDelete = new List <ContactPointAddress>();

        Test.startTest();
        listOfAddressesBeforeDelete = [SELECT ID, Name FROM ContactPointAddress WHERE Id = :testAddress.Id];
        NATT_AccountInformationHelper.deleteAddress(testAddress);
        listOfAddressesAfterDelete = [SELECT ID FROM ContactPointAddress WHERE Id = :testAddress.Id];

        Test.stopTest();

        System.assertEquals(false, listOfAddressesBeforeDelete.isEmpty(), 'We expect the Contact Point Address List to successfully update.');
        System.assertEquals(true, listOfAddressesAfterDelete.isEmpty(), 'We do not expect this List to update because the Contact Point Address has not been properly inserted yet.');

    }

}