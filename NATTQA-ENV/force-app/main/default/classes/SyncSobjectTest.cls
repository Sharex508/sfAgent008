/**
* @name SyncSobjectTest
* @description Test class for SyncSobject 
* @date 9 August 2021
* @author DS
* @changes
***/
@isTest
private class SyncSobjectTest {
    
    private static testmethod void testsyncSobject(){
        String uniqueUserName = 'sysadmin' + DateTime.now().getTime() + '@testorg.com';
        // This code runs as the system user
        Profile p = [SELECT Id FROM Profile WHERE Name='System Administrator'];
        User u = new User(Alias = 'sysadm', Email='sysadm@testorg.com',
                          EmailEncodingKey='UTF-8', LastName='Testing', LanguageLocaleKey='en_US',
                          LocaleSidKey='en_US', ProfileId = p.Id,
                          TimeZoneSidKey='America/Los_Angeles',
                          UserName=uniqueUserName);
        
        System.runAs(u) {
            List<Account> accLst = new List<Account>();
            //Account acc = NATT_DataFactory.accRecord();
            Id dealerRecordTypeId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('Dealer').getRecordTypeId();          
            Account acc = new Account(
            Name = 'Test Account1',
            recordTypeID = dealerRecordTypeId,
            AccountNumber = '4578');
            acc.NATT_Status__c = 'Active';
            acc.NATT_Warranty_Status__c = 'Active';
            acc.NATT_Organization__c = 'NATT';
            acc.NATT_Region__c = 'East';
            accLst.add(acc);
            insert accLst;
            
            List<Contact> conLst = new List<Contact>();
            //Contact con = NATT_DataFactory.conRecord(acc.ID);
            Id rectypeNattDealer = Schema.SObjectType.Contact.getRecordTypeInfosByDeveloperName().get('NATT_Dealer').getRecordTypeId();        
            Contact con = new Contact(
            firstName = 'TestContact',
            lastName = 'Con',
            recordTypeId = rectypeNattDealer,
            accountID = accLst[0].Id);
            conLst.add(con);
            insert conLst;
            
            Account a = new Account(Name='Test', NATT_Organization__c = 'NATT', NATT_Region__c = 'East',RecordTypeId=Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('Dealer').getRecordTypeId());
            insert a;
            Contact c = new Contact(AccountId=a.Id,FirstName='Test',LastName='User',NATT_Key_Business_Role__c='Technician',NATT_Refrigeration_Technician__c=true,
                                    RecordTypeId=Schema.SObjectType.Contact.getRecordTypeInfosByDeveloperName().get('NATT_Dealer').getRecordTypeId());
            insert c;
            
            Test.startTest(); 
            
            c.NATT_Refrigeration_Technician__c=false;
            update c;
            
            delete c;   
                     
            delete a;
            
            PartnerNetworkConnection existingConnection = [SELECT Id, ConnectionName FROM PartnerNetworkConnection WHERE ConnectionName = 'Carrier Transicold Europe' AND ConnectionStatus = 'Accepted' LIMIT 1];
            system.assertequals('Carrier Transicold Europe',existingConnection.ConnectionName,'Proper connection found');

            List<NATT_Extended_Warranty__c> warrantyLst = new List<NATT_Extended_Warranty__c>();
            NATT_Extended_Warranty__c wartyObj = new NATT_Extended_Warranty__c();
            wartyObj.Action__c = 'dummyAction';
            wartyObj.IsProcessed__c = true;
            wartyObj.Deductibles__c = '3.5';
            wartyObj.CurrencyIsoCode = 'USD';
            warrantyLst.add(wartyObj);
            insert warrantyLst;
            
            //Assertion check
            System.assertEquals(1, accLst.size(), 'Account success');
            System.assertEquals(1, conLst.size(), 'Contact success');
            System.assertEquals(1, warrantyLst.size(), 'Warranty success');  
            Test.stopTest();   
        }
        
    }
}