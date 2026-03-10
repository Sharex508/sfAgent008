@IsTest
private class AccountTriggerHandlerNattTest {
    @IsTest
    static void myUnitTest(){
        List<Account> aList = new List<Account>([SELECT Id, Name FROM Account]);
        delete aList;
    }
    @TestSetup
    static void setupData(){
        Map<String,Schema.RecordTypeInfo> rtMap = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName();
        List<Account> aList = new List<Account>();
        aList.add(new Account(Name='Dealer',NATT_Organization__c = 'NATT',NATT_Region__c = 'East',RecordTypeId=rtMap.get('Dealer').getRecordTypeId()));
        aList.add(new Account(Name='Internal',NATT_Organization__c = 'NATT',NATT_Region__c = 'East',RecordTypeId=rtMap.get('Internal').getRecordTypeId()));
        aList.add(new Account(Name='Customer',NATT_Organization__c = 'NATT',NATT_Region__c = 'East',RecordTypeId=rtMap.get('Customer').getRecordTypeId()));
        insert aList;
        
        update aList;
    }
    @isTest
    public static void testInactiveContactAccess(){
        Map<String,Schema.RecordTypeInfo> rtContactMap = Schema.SObjectType.Contact.getRecordTypeInfosByDeveloperName();
        Profile testDealerProfile = [SELECT Id FROM Profile WHERE Name='NATT Full Access Community' LIMIT 1]; 
        
        Account testAccount = new Account(Name='Test Dealer Account',NATT_Organization__c = 'NATT',NATT_Region__c = 'East');
        insert testAccount;
        
        Contact testContact = new Contact(FirstName='Test',LastName='Contact',RecordTypeId=rtContactMap.get('NATT_Dealer').getRecordTypeId(),AccountId=testAccount.Id);
        insert testContact;
        
        User thisUser = new User(Id = UserInfo.getUserId());
        System.runAs(thisUser) {
            UserRole testInternalRole = new UserRole(Name='Test Internal Role',DeveloperName='Test_Internal_Role',PortalType='None');
            insert testInternalRole;
            
            thisUser.UserRoleId = testInternalRole.Id;
            update thisUser;
            
            User testDealerUser = new User(Alias='dealer',Email='dealer@example.com',LastName='Dealer',
                                           TimeZoneSidKey='GMT', LocaleSidKey='en_US',Username='dealer@example.com.carrier',
                                           EmailEncodingKey='UTF-8',ProfileId=testDealerProfile.Id,LanguageLocaleKey='en_US',
                                           ContactId=testContact.Id);
            insert testDealerUser;
        }
        
        testContact.RecordTypeId=rtContactMap.get('NATT_Inactive_Contact').getRecordTypeId();
        update testContact;
        
        User testDealerUser = [SELECT Id FROM User WHERE ContactId =: testContact.Id];
        
        // Perform test
        Test.startTest();       
        System.runAs(testDealerUser) {
            Account newTestAccount = new Account(Name='Test Dealer Account2',NATT_Organization__c = 'NATT',NATT_Region__c = 'East');
            try{
                insert newTestAccount;
            } catch (DmlException e){
                //Assert Error Message 
                System.assert(e.getMessage().contains(Label.NATT_Inactive_Contact_Check_Access), e.getMessage());
                //Assert Status Code
                System.assertEquals('FIELD_CUSTOM_VALIDATION_EXCEPTION', e.getDmlStatusCode(0));
                System.debug('error' + e.getMessage());
            }
        }
        Test.stopTest(); 
    }
    
    @isTest
    public static void testValidateDelete(){
        Map<String,Schema.RecordTypeInfo> rtContactMap = Schema.SObjectType.Contact.getRecordTypeInfosByDeveloperName();
        Profile testDealerProfile = [SELECT Id FROM Profile WHERE Name='NATT Full Access Community' LIMIT 1]; 
        
        Account testAccount = new Account(Name='Test Dealer Account',NATT_Status__c='Active',NATT_Organization__c = 'NATT',NATT_Region__c = 'East');
        insert testAccount;
        
        Contact testContact = new Contact(FirstName='Test',LastName='Contact',RecordTypeId=rtContactMap.get('NATT_Dealer').getRecordTypeId(),AccountId=testAccount.Id);
        insert testContact;
        
        User thisUser = new User(Id = UserInfo.getUserId());
        System.runAs(thisUser) {
            UserRole testInternalRole = new UserRole(Name='Test Internal Role',DeveloperName='Test_Internal_Role',PortalType='None');
            insert testInternalRole;
            
            thisUser.UserRoleId = testInternalRole.Id;
            update thisUser;
            
            User testDealerUser = new User(Alias='dealer',Email='dealer@example.com',LastName='Dealer',
                                           TimeZoneSidKey='GMT', LocaleSidKey='en_US',Username='dealer@example.com.carrier',
                                           EmailEncodingKey='UTF-8',ProfileId=testDealerProfile.Id,LanguageLocaleKey='en_US',
                                           ContactId=testContact.Id);
            insert testDealerUser;
        }
        
        update testContact;
        
        User testDealerUser = [SELECT Id FROM User WHERE ContactId =: testContact.Id];
        
        // Perform test
        Map<String,Schema.RecordTypeInfo> rtAccountMap = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName();
        Test.startTest();       
        System.runAs(testDealerUser) {
            Account newTestAccount = new Account(Name='Test Dealer Account2',NATT_Status__c='Active',NATT_Organization__c = 'NATT',NATT_Region__c = 'East');
            insert newTestAccount;
            try{
                delete newTestAccount;
            } catch (DmlException e){
                System.debug('error' + e.getMessage());
            }
        }
        Test.stopTest(); 
    }
}