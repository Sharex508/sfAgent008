@isTest
public class ContactTriggerHandlerNATTTest {

    @isTest
    static void testNattDealerPrincipal(){	
        Account a = new Account(Name='Test',  NATT_Division__c='Truck Trailer',NATT_Organization__c='NATT',NATT_Region__c='East',RecordTypeId=Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('Dealer').getRecordTypeId());
        insert a;
        Test.startTest();
        Contact c = new Contact(AccountId=a.Id,FirstName='Test',LastName='User',NATT_Key_Business_Role__c='Principal',RecordTypeId=Schema.SObjectType.Contact.getRecordTypeInfosByDeveloperName().get('NATT_Dealer').getRecordTypeId());
        insert c;
        boolean hasError = false;
        try{
            c = new Contact(AccountId=a.Id,FirstName='Test',LastName='duplicate',NATT_Key_Business_Role__c='Principal',RecordTypeId=Schema.SObjectType.Contact.getRecordTypeInfosByDeveloperName().get('NATT_Dealer').getRecordTypeId());
        	insert c;
        }catch(DMLException e){
            hasError=true;
        }
        System.assert(hasError);
        c = new Contact(AccountId=a.Id,FirstName='Test',LastName='User2',NATT_Key_Business_Role__c='VP/Director',RecordTypeId=Schema.SObjectType.Contact.getRecordTypeInfosByDeveloperName().get('NATT_Dealer').getRecordTypeId());
        insert c;
        
        hasError=false;
        try{
            c.NATT_Key_Business_Role__c='Principal';
        	update c;
        }catch(DMLException e){
            hasError=true;
        }
		System.assert(hasError);
        c = [SELECT Id FROM Contact WHERE LastName='User'];
        c.NATT_Key_Business_Role__c='Branch Manager';
        update c;
        
        System.assertEquals(null, [SELECT NATT_Dealer_Principal__c FROM Account WHERE Name='Test'].NATT_Dealer_Principal__c);
        Test.stopTest();
    }
    
    @isTest
    static void testNattRefrigerationTechs(){
        Account a = new Account(Name='Test', NATT_Division__c='Truck Trailer',NATT_Organization__c='NATT',NATT_Region__c='East',RecordTypeId=Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('Dealer').getRecordTypeId());
        insert a;
        Test.startTest();
        Contact c = new Contact(AccountId=a.Id,FirstName='Test',LastName='User',NATT_Key_Business_Role__c='Technician',NATT_Refrigeration_Technician__c=true,
                                RecordTypeId=Schema.SObjectType.Contact.getRecordTypeInfosByDeveloperName().get('NATT_Dealer').getRecordTypeId());
        insert c;
        
        System.assertEquals(1,[SELECT NATT_Number_of_Refrigeration_Techs__c FROM Account WHERE Id=:a.Id].NATT_Number_of_Refrigeration_Techs__c);
        
        c.NATT_Refrigeration_Technician__c=false;
        update c;
        
        System.assertEquals(0,[SELECT NATT_Number_of_Refrigeration_Techs__c FROM Account WHERE Id=:a.Id].NATT_Number_of_Refrigeration_Techs__c);
        
        //c.NATT_Refrigeration_Technician__c=true;
        //update c;
        
        //System.assertEquals(null,[SELECT NATT_Number_of_Refrigeration_Techs__c FROM Account WHERE Id=:a.Id].NATT_Number_of_Refrigeration_Techs__c);
        
        delete c;
        
        System.assertEquals(0,[SELECT NATT_Number_of_Refrigeration_Techs__c FROM Account WHERE Id=:a.Id].NATT_Number_of_Refrigeration_Techs__c);
        Test.stopTest();
    }
}