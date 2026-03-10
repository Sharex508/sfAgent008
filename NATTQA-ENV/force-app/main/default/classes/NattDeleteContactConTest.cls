@IsTest
private class NattDeleteContactConTest {
	@isTest
    static void testContactDelete(){
        Map<String,Schema.RecordTypeInfo> rtMap = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName();
         Profile p = [SELECT Id FROM Profile WHERE Name='NATT Account Super User']; 
        User u = new User(Alias = 'standt', Email='standarduser@testorg.com', 
            EmailEncodingKey='UTF-8', LastName='Testing', LanguageLocaleKey='en_US', 
            LocaleSidKey='en_US', ProfileId = p.Id, 
            TimeZoneSidKey='America/Los_Angeles', UserName='testuserxyz@testorg.com.corp.prod');
        insert u;
        System.runAs(u){
            List<Account> aList = new List<Account>();
            aList.add(new Account(Name='Dealer',RecordTypeId=rtMap.get('Dealer').getRecordTypeId()));
            insert aList;
            
            Contact c = new Contact(AccountId=aList.get(0).Id,FirstName='Test',LastName='Contact',RecordTypeId=Schema.SObjectType.Contact.getRecordTypeInfosByDeveloperName().get('NATT_Dealer').getRecordTypeId());
            insert c;
            NattDeleteContactCon.deleteContact(c.Id);
        }
    }    
}