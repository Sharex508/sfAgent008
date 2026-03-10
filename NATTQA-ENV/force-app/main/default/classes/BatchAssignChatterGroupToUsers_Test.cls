/********************************************************************************************************
* @author         (Deloitte)
* @description    This is a test class for BatchAssignChatterGroupToUsers batch class created specific for REF users.
* @date           06/04/2023 [MM/DD/YYYY]
* 
* Modification Log:
* -------------------------------------------------------------------------------------------------------
* Developer                Date                   Modification ID      Description
* -------------------------------------------------------------------------------------------------------
* Deloitte               06/04/2023                                  Initial version
*********************************************************************************************************/
@isTest
public class BatchAssignChatterGroupToUsers_Test {  
   
    static testMethod void testChatterBatchLogic() {
        //Creating new chatter group with name chattertestTest
        CollaborationGroup chatterUserGroup = new CollaborationGroup(Name = 'chattertestTest', CollaborationType = 'Public');
        insert chatterUserGroup;
        
        ChatterGroupProfileCustomSetting__c newCustomRecord = new ChatterGroupProfileCustomSetting__c();
        newCustomRecord.Name = 'System Administrator';
        newCustomRecord.ChatterGroupNames__c = 'chattertestTest';
        insert newCustomRecord;
        
        Test.startTest();
            BatchAssignChatterGroupToUsers batchInstance= new BatchAssignChatterGroupToUsers();
            Id jobid= Database.executeBatch(batchInstance);
            //System.abortJob(jobid);
        Test.stopTest();
        
        //System.assert to validate the result
        assert.isNotNull(jobid);
    }  
}