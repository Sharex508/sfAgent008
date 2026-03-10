/*************************************************************************************************
Apex Class Name : ScheduleBatchAssignChatterGroupToUsers
Version : 1.0
Created Date : 12/04/2023
Function : TO schedule BatchAssignChatterGroupToUsers

Modification Log:
-------------------------------------------------------------------------------------------------------------------------------------------------
* Developer                                Date                                Description
* -----------------------------------------------------------------------------------------------------------------------------------------------
* Sanjay Sarraf         		     12/04/2023                        Initial creation        
*************************************************************************************************/
public without sharing class ScheduleBatchAssignChatterGroupToUsers implements Schedulable {
    public void execute(SchedulableContext sc) {
        //execute batch
        BatchAssignChatterGroupToUsers assignBtchSch = new BatchAssignChatterGroupToUsers(); 
        database.executebatch(assignBtchSch,200);
    }
}