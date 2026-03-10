/*************************************************************************************************
Apex Class Name : ClosedCaseEmailAlertBatchScheduler
Version : 1.0
Created Date : 11/05/2023
Function : TO schedule ClosedCaseEmailAlertBatch

Modification Log:
-------------------------------------------------------------------------------------------------------------------------------------------------
* Developer                                Date                                Description
* -----------------------------------------------------------------------------------------------------------------------------------------------
* Sanjay Sarraf         		     11/05/2023                         Initial creation        
*************************************************************************************************/
public without sharing class ClosedCaseEmailAlertBatchScheduler implements Schedulable {
    public void execute(SchedulableContext sc) {
        //execute batch
        ClosedCaseEmailAlertBatch assignBtchSch = new ClosedCaseEmailAlertBatch(); 
        database.executebatch(assignBtchSch,200);
    }
}