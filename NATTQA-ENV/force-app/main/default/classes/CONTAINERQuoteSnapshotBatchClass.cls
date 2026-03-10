/********************************************************************************************************
* @author         Deloitte
* @description    This class creates the record for ASO Review Report
* @date           07/27/2022 [MM/DD/YYYY]
* 
* Modification Log:
* -------------------------------------------------------------------------------------------------------
* Developer                Date                   Modification ID      Description
* -------------------------------------------------------------------------------------------------------
* Deloitte               07/27/2022                                   Initial version
*********************************************************************************************************/
global class CONTAINERQuoteSnapshotBatchClass implements Database.Batchable<sObject>, Database.stateful, schedulable {
     
    global Database.QueryLocator start(Database.BatchableContext BC) {
         
        String csLabel = System.Label.ContainerASOStartDate; 
        Date startDate = date.valueOf(csLabel);
        
        //Query NT Quote Records
        String query = 'SELECT Id FROM SBQQ__Quote__c where RecordType.Name = \'Container NT Quote\' and createdDate > :startDate';
        return Database.getQueryLocator(query);
    }
     
    global void execute(Database.BatchableContext BC, List<SBQQ__Quote__c> quoteList) {
        try{
            CONTAINERQuoteSnapshotReview.Processbatch(quoteList);
        } catch(Exception e) {
            System.debug('Exception hit on ASO Batch:' + e);
        }
    }   
     
    global void finish(Database.BatchableContext BC) {
        // execute any post-processing operations like sending email
    }
    
    global void execute(SchedulableContext ctx) {
        integer asoBatchSize =  Integer.valueof(System.Label.ContainerASOBatchSize);
        CONTAINERQuoteSnapshotBatchClass scheduleQuoteSnapshot = new CONTAINERQuoteSnapshotBatchClass();
        Database.executeBatch(scheduleQuoteSnapshot, asoBatchSize);
    }

}