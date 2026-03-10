/* Created a Batch class to create a ServiceAgreementBatch records with read access to the existing records
 * Created by : Rajasekharreddy Kotella
 * Created on : o4-10-2024
 * Class Name : ServiceAgreementBatch
 * Description: Rub the below code in to excute Batch
 * 				ServiceAgreementBatch batch = new ServiceAgreementBatch();
 * 				Database.executeBatch(batch, 50);
 */
public class ServiceAgreementBatch implements Database.Batchable<SObject>, Database.Stateful {

    // Start method to define the query
    public Database.QueryLocator start(Database.BatchableContext bc) {
        // Query for the records you want to process in the batch
        return Database.getQueryLocator([SELECT Id, Account__c, Account__r.RecordType.Name 
                                         FROM CONTAINER_Service_Agreement__c  WHERE Account__r.RecordType.Name = 'CONTAINER Authorized Service Provider'  ]);
    }

    public void execute(Database.BatchableContext bc, List<CONTAINER_Service_Agreement__c> SAList) {
        ServiceAgreementTriggerHelper.ShareServiceAgriment(SAList);
    }

    // Finish method, called after all batches are processed
    public void finish(Database.BatchableContext bc) {
        System.debug('Batch process completed.');
    }
}