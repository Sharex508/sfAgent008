/*************************************************************************************************
Apex Class Name : CoreReturnsCaseCloseEmailAlertBatch_Test
Version : 1.0
Created Date : 11/05/2023
Function : This is a test class for CoreReturnsCaseCloseEmailAlertBatch

Modification Log:
-------------------------------------------------------------------------------------------------------------------------------------------------
* Developer                                Date                                Description
* -----------------------------------------------------------------------------------------------------------------------------------------------
* Sanjay Sarraf         		     06/06/2023                        Initial creation        
*************************************************************************************************/

@isTest
public class CoreReturnsCaseCloseEmailAlertBatch_Test {  
   
    static testMethod void testCoreReturnsCaseCloseEmailAlertBatch() {
        //Creating new Core Returns case 
        Case cs = new Case();
		cs.RecordTypeId = Schema.SObjectType.Case.getRecordTypeInfosByName().get('Core Returns').getRecordTypeId();
		cs.Status = 'New';
		cs.Type = 'Core Return';
		cs.NATT_Case_Reason__c = 'Core Return';
		cs.Origin = 'SolutionCenter';
		cs.NATT_Core_Return_Location__c = 'Carrier/Carlyle Compressor Core Returns';
		insert cs;
		

		Test.setCreatedDate(cs.Id, Date.today().addDays(-14));

		Test.startTest();
		Case ppCase = [SELECT Id, CreatedDate FROM Case 
							 WHERE Type = 'Core Return' limit 1];
        System.debug('ppCase.CreatedDate++'+ppCase.CreatedDate);
		//System.assert to validate the result
		System.assertEquals(ppCase.CreatedDate, Date.today().addDays(-14));
		CoreReturnsCaseCloseEmailAlertBatch batchInstance= new CoreReturnsCaseCloseEmailAlertBatch();
        Id jobid= Database.executeBatch(batchInstance);		
        assert.isNotNull(jobid);
		Test.stopTest();
    }  
}