/****
Created by LTI
Test class for SyncACRBatchCallout
****/

@isTest
public class SyncACRBatchCalloutTest {
    
    
    private static testmethod void testBacth(){
        
        ACR_Batch__c cs = new ACR_Batch__c();
        cs.Name = 'LastRun';
        cs.Last_run__c = Datetime.now().addMinutes(-360);
        insert cs;
        
        
        Account acc = NATT_DataFactory.accRecord();
        insert acc;
        
        Contact con = NATT_DataFactory.conRecord(acc.ID);
        insert con;
        
        List<AccountContactRelation> acrLst = [Select ID, NATT_External_ID__c
                                               from AccountContactRelation 
                                               WHERE accountID =: acc.ID
                                               AND contactID =: con.ID];
        System.assertEquals(1, acrLst.size());
        
        Test.startTest();
        
        SyncACRBatchCallout batch = new SyncACRBatchCallout();
        DataBase.executeBatch(batch); 
        
        Database.BatchableContext str;
        
        batch.execute(str, acrLst);
        
        Test.stopTest();
        
        //assertion check
        AccountContactRelation acrCheckObj = [Select id, NATT_isMigrated__c
                                              From AccountContactRelation
                                              Where id =: acrLst[0].ID];
        
        System.assertEquals(acrCheckObj.NATT_isMigrated__c, True);
    }
}