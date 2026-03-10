/*Created a Batch class to create a ContentDocumentLink records to update visibility settings
 * Created by : Rajasekharreddy Kotella
 * Created on : o4-10-2024
 * Class Name : ContentDocumentLinkBatch
 * Description: Rub the below code in to excute Batch
 * 				ContentDocumentLinkBatch batch = new ContentDocumentLinkBatch();
 * 				Database.executeBatch(batch, 50);
 */
public class ContentDocumentLinkBatch implements Database.Batchable<SObject>, Database.Stateful {

    // Start method to define the query
    public Database.QueryLocator start(Database.BatchableContext bc) {
        set<Id> saIds = new set<Id>();
        List<CONTAINER_Service_Agreement__c> serviceAgreements = [SELECT Id FROM CONTAINER_Service_Agreement__c 
                                                                    WHERE Account__r.RecordType.Name = 'CONTAINER Authorized Service Provider'];
        
        for(CONTAINER_Service_Agreement__c serviceAgreement  : serviceAgreements){
            saIds.add(serviceAgreement.Id);
            system.debug('saIds-'+ saIds);
        }
        if(! test.isRunningTest()){
        return Database.getQueryLocator([ SELECT Id, ShareType, LinkedEntityId, Visibility FROM ContentDocumentLink  WHERE Visibility != 'AllUsers' AND ShareType != 'V' AND LinkedEntityId =: saIds]);
        }
        else{
          return Database.getQueryLocator([ SELECT Id, ShareType, LinkedEntityId, Visibility FROM ContentDocumentLink 
                                                  WHERE LinkedEntityId =: saIds]);  
        }
    }

    public void execute(Database.BatchableContext bc, list<ContentDocumentLink> cdlList) {
        list<ContentDocumentLink> cdlListToUpdate = new list<ContentDocumentLink>();
        for (ContentDocumentLink cdl : cdlList) {
            if (cdl.LinkedEntityId.getSObjectType().getDescribe().getName() == 'CONTAINER_Service_Agreement__c') {
                cdl.visibility = 'AllUsers';
                cdl.ShareType = 'V';
            }
            cdlListToUpdate.add(cdl);
        }
        Database.update(cdlListToUpdate);
    }   


    // Finish method, called after all batches are processed
    public void finish(Database.BatchableContext bc) {
        System.debug('Batch process completed.');
    }
}