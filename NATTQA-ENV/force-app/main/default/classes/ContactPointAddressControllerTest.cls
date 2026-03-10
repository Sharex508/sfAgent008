@istest
public class ContactPointAddressControllerTest {
    
    @isTest
    static void testCreateContactPointAddress() {

        Account testAccount = new Account(Name='TestNACAccount',NATT_Organization__c = 'NATT',NATT_Region__c = 'East');
        insert testAccount;
        
        ContactPointAddress objCPA = new ContactPointAddress();
        objCPA.Name ='Testing';
        objCPA.City='Test';
        objCPA.Country ='US';
        objCPA.ParentId =testAccount.Id;
        insert objCPA;
         
        ContactPointAddressController.upsertContactPointAddress(objCPA.Id,'Test Address','123 Test Street','MH', 'US','12345','Test City',testAccount.Id );
        
    }
    @isTest
    static void testInsertContactPointAddress() {
        Account testAccount = new Account(Name='TestInsertAccount', NATT_Organization__c='NATT', NATT_Region__c='West');
        insert testAccount;

        
        ContactPointAddressController.upsertContactPointAddress(null, 'New Address', '789 New Street', 'CA', 'US', '54321', 'New City', testAccount.Id);
        
    }

}