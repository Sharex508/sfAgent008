/************
Test class for ContactDeleteCallout
*************/
@isTest
public class ContactDeleteCalloutTest {
    
    @testSetup static void setup(){
        //StaticTest.setDoNotRunTrigger();//DG for SOQL LimitException issue
        Account acc = NATT_DataFactory.accRecord();
        insert acc;
        
        Contact technicianCon = NATT_DataFactory.conRecord(acc.ID);
        technicianCon.NATT_Refrigeration_Technician__c = True;
        insert technicianCon;
        
        Contact nonTechnicianCon = NATT_DataFactory.conRecord(acc.ID);
        nonTechnicianCon.NATT_Key_Business_Role__c = 'Sales Manager';
        insert nonTechnicianCon;
    }
    
    private static testmethod void testTechnicianContactDeletion(){
        
        List<Contact> conLst = [Select id, name
                                From Contact
                                Where NATT_Refrigeration_Technician__c = True];
        
        System.assertEquals(conLst.size(), 1);
        
        Test.startTest();
        delete conLst;
        Test.stopTest();
        
        //assertion check
        List<Contact> conLstLstCheck = [Select id, name
                                        From Contact
                                        Where NATT_Refrigeration_Technician__c = True];
        
        System.assertEquals(conLstLstCheck.size(), 0);
    }
    
    private static testmethod void testNonTechnicianContactDeletion(){
        
        List<Contact> conLst = [Select id, name
                                From Contact
                                Where NATT_Key_Business_Role__c = 'Sales Manager'];
        
        System.assertEquals(conLst.size(), 1);
        
        Test.startTest();
        delete conLst;
        Test.stopTest();
        
        //assertion check
        List<Contact> conLstLstCheck = [Select id, name
                                        From Contact
                                        Where NATT_Key_Business_Role__c = 'Sales Manager'];
        
        System.assertEquals(conLstLstCheck.size(), 0);
    }
}