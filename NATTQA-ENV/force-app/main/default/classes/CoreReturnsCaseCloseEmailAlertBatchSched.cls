/*************************************************************************************************
Apex Class Name : CoreReturnsCaseCloseEmailAlertBatchSched
Version : 1.0
Created Date : 07/06/2023
Function : TO schedule CoreReturnsCaseCloseEmailAlertBatch

Modification Log:
-------------------------------------------------------------------------------------------------------------------------------------------------
* Developer                                Date                                Description
* -----------------------------------------------------------------------------------------------------------------------------------------------
* Sanjay Sarraf         		     07/06/2023                        Initial creation        
*************************************************************************************************/
public without sharing class CoreReturnsCaseCloseEmailAlertBatchSched implements Schedulable {
    public void execute(SchedulableContext sc) {
        //execute batch
        CoreReturnsCaseCloseEmailAlertBatch assignBtchSch = new CoreReturnsCaseCloseEmailAlertBatch(); 
        database.executebatch(assignBtchSch,200);
    }
}