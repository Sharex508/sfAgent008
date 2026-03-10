/*************************************************************************************************
Apex Class Name : ClosedCaseEmailAlertBatch_Test
Version : 1.0
Created Date : 11/05/2023
Function : This is a test class for ClosedCaseEmailAlertBatch

Modification Log:
-------------------------------------------------------------------------------------------------------------------------------------------------
* Developer                                Date                                Description
* -----------------------------------------------------------------------------------------------------------------------------------------------
* Sanjay Sarraf         		     11/05/2023                        Initial creation        
*************************************************************************************************/

@isTest
public class ClosedCaseEmailAlertBatch_Test {  
   
    static testMethod void testClosedCaseEmailAlertBatchLogic() {
        //Creating new Performance Parts case 
        Case cs = new Case();
		cs.RecordTypeId = Schema.SObjectType.Case.getRecordTypeInfosByName().get('Performance Parts').getRecordTypeId();
		cs.Status = 'New';
		cs.Type = 'Sales Order Inquiry';
		cs.Origin = 'Phone';
		insert cs;
		

		Test.setCreatedDate(cs.Id, Date.today().addDays(-13));

		Test.startTest();
		Case ppCase = [SELECT Id, CreatedDate FROM Case 
							 WHERE Type = 'Sales Order Inquiry' limit 1];
        System.debug('ppCase.CreatedDate++'+ppCase.CreatedDate);
		System.assertEquals(ppCase.CreatedDate, Date.today().addDays(-13));
		ClosedCaseEmailAlertBatch batchInstance= new ClosedCaseEmailAlertBatch();
        Id jobid= Database.executeBatch(batchInstance);
		//System.assert to validate the result
        assert.isNotNull(jobid);
		Test.stopTest();
    }  
}