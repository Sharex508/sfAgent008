@isTest
public class AccountDetailsControllerTest {
 @isTest
    static void testGetRelatedAddresses() {
       List<Account> aList = new List<Account>();
        alist.add(new Account(Name='Test Dealer',NATT_Organization__c = 'NATT', NATT_Region__c = 'East',RecordTypeId=Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('Dealer').getRecordTypeId()));
        insert aList;

        // Create Billing Address related to the Account
        List<NATT_Address__c> addressList = new List<NATT_Address__c>();
        addressList.add(new NATT_Address__c (RecordTypeId = Schema.SObjectType.NATT_Address__c.getRecordTypeInfosByDeveloperName().get('NATT_Address').getRecordTypeId(),
                                             NATT_Type__c = 'Billing', NATT_Account__c = aList[0].Id, Name = 'Billing Address'));
        addressList.add(new NATT_Address__c (RecordTypeId = Schema.SObjectType.NATT_Address__c.getRecordTypeInfosByDeveloperName().get('NATT_Address').getRecordTypeId(),
                                             NATT_Type__c = 'Shipping', NATT_Account__c = aList[0].Id, Name = 'Shipping Address'));
			        insert addressList;


       

        // Test the controller method
        Test.startTest();
        List<NATT_Address__c> relatedAddresses = AccountDetailsBillingShippingController.getRelatedAddresses(aList[0].Id);
        Test.stopTest();

        // Validate results
        System.assertEquals(2, relatedAddresses.size(), 'Two addresses should be returned');
        System.assertEquals('Billing', relatedAddresses[0].NATT_Type__c, 'First address should be billing');
        System.assertEquals('Shipping', relatedAddresses[1].NATT_Type__c, 'Second address should be shipping');
    }

   
}