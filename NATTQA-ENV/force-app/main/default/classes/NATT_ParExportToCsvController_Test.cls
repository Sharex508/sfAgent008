/********************************************************************************************************
* @author         (Deloitte)
* @description    This is a test class for NATT_ParExportToCsvController apex class created specific for PAR Export Functionality.
* @date           05/04/2023 [MM/DD/YYYY]
* 
* Modification Log:
* -------------------------------------------------------------------------------------------------------
* Developer                Date                   Modification ID      Description
* -------------------------------------------------------------------------------------------------------
* Deloitte               05/04/2023                                  Initial version
*********************************************************************************************************/

@isTest
public class NATT_ParExportToCsvController_Test {

    @isTest
    static void getPARList_Test() {
        Account testPARccount = new Account(Name='Test PAR Account');
        insert testPARccount;
        
        Id RecTypeId = Schema.SObjectType.NATT_PAR__c.getRecordTypeInfosByDeveloperName().get('NATT_PAR').getRecordTypeId();
        NATT_PAR__c parAccount = new NATT_PAR__c(Name='Test PAR Acc',NATT_Account__c = testPARccount.id, RecordTypeId = RecTypeId);
        insert parAccount;
        
        Test.startTest();
        List<NATT_PAR__c> parAccountRecord = NATT_ParExportToCsvController.getPARList(testPARccount.id);
        Test.stopTest();
        
        system.assertEquals(parAccountRecord[0].Name, 'Test PAR Acc');
    }
    
     @isTest
    static void getAccountName_Test() {
        Account testPARccount2 = new Account(Name='Test PAR Account2');
        insert testPARccount2;
        
        Test.startTest();
        Account accountRecord = NATT_ParExportToCsvController.getAccountName(testPARccount2.id);
        Test.stopTest();
        
        system.assertEquals(accountRecord.Name == 'Test PAR Account2', true);
    }
}