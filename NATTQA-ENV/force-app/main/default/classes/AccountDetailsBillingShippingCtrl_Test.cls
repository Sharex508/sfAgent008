@isTest
public class AccountDetailsBillingShippingCtrl_Test {
    @testSetup
    public static void testSetup(){
        List<Account> aList = new List<Account>();
        alist.add(new Account(Name='Test Dealer',NATT_Organization__c = 'NATT',NATT_Region__c = 'East',RecordTypeId=Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('Dealer').getRecordTypeId()));
        //aList.add(new Account(Name='Test Dealer2',NATT_Organization__c = 'NATT',NATT_Region__c = 'East',RecordTypeId=Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('Dealer').getRecordTypeId()));
        insert aList;
        
        List<NATT_Address__c> addList = new List<NATT_Address__c>();
        addList.add(new NATT_Address__c(NATT_Type__c='Billing',NATT_Account__c=aList.get(0).Id,RecordTypeId=Schema.SObjectType.NATT_Address__c.getRecordTypeInfosByDeveloperName().get('NATT_Address').getRecordTypeId()));
        addList.add(new NATT_Address__c(NATT_Type__c='Units Ship To',NATT_Account__c=aList.get(0).Id,RecordTypeId=Schema.SObjectType.NATT_Address__c.getRecordTypeInfosByDeveloperName().get('NATT_Address').getRecordTypeId()));
        insert addList;		
    }
    @isTest
    public static void getRelatedAddresses(){
        account acc = [select id from account limit 1];
        AccountDetailsBillingShippingController.getRelatedAddresses(acc.id);
         
    }
         @isTest
    public static void getAccountInfo(){
        account acc = [select id from account limit 1];
        AccountDetailsBillingShippingController.getAccountInfo(acc.id);
         
    }
}