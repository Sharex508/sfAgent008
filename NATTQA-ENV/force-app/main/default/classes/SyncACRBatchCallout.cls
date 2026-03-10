/**
Batch class to keep ACR in sync with NATT and TAVANT org.
Need to call this batch every 6 hours
**/
global class SyncACRBatchCallout implements Database.Batchable<sObject>, Schedulable, Database.AllowsCallouts, Database.Stateful {
    
    global integer totalSizeRecords=0;
    private static final String calloutEndpoint = 'callout:UATCallout/services/apexrest/v1/acrSync/';
    
    public void execute(SchedulableContext sc){
        SyncACRBatchCallout batch = new SyncACRBatchCallout();
        Database.executeBatch(batch,50);
    }
    
    global Database.QueryLocator start(Database.BatchableContext bc){
        ACR_Batch__c cs = ACR_Batch__c.getInstance('LastRun');
        Datetime lastRun = cs.Last_run__c; 
        
        //Record type fecthing of Account and Contact
        String accdealerRecordTypeId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('Dealer').getRecordTypeId();
        String condealerRecordTypeId = Schema.SObjectType.Contact.getRecordTypeInfosByDeveloperName().get('NATT_Dealer').getRecordTypeId();
        
        return Database.getQueryLocator('Select id, NATT_External_ID__c from AccountContactRelation WHERE '+
                                        +' account.recordTypeID =:accdealerRecordTypeId and NATT_isMigrated__c = false'+
                                        +' and contact.recordTypeID =:condealerRecordTypeId and LastModifiedDate >: lastRun');
        
    }
    
    global void execute(Database.BatchableContext bc, List<AccountContactRelation> scope) {
        
        Map<String, ID> externalIDMap = new Map<String, ID>();
        totalSizeRecords += scope.size();
        List<ACRWrapper.Records> recLst = new List<ACRWrapper.Records>();
        
        for(AccountContactRelation acr : scope){
            if(!String.isBlank(acr.NATT_External_ID__c)){
                ACRWrapper.Records rec = new ACRWrapper.Records();
                rec.acrExternal = acr.NATT_External_ID__c;
                externalIDMap.put(acr.NATT_External_ID__c, acr.ID);
                recLst.add(rec);
            }
        }
        
        if(!recLst.isEmpty()){
            ACRWrapper wrap = new ACRWrapper();
            wrap.rec = recLst;
            String jsonstr = System.JSON.serialize(wrap, true);
            String jsonResponse;
            
            try{
                HttpResponse response = new HttpResponse();
                HttpRequest request = new HttpRequest();
                Http http = new Http();
                
                request.setHeader('Content-Type', 'application/json;charset=UTF-8');
                request.setEndpoint(calloutEndpoint);
                request.setMethod('PUT');
                request.setTimeout(120000);
                request.setBody(jsonstr);
                
                if(!Test.isRunningTest()){
                    response = http.send(request);
                }
                else{
                    response = SyncACRBatchCalloutMock.getResp(externalIDMap);
                }
                
                //checking callout status
                if (response.getStatusCode() == 200) {
                    List<AccountContactRelation> updateACRLst = new List<AccountContactRelation>();
                    jsonResponse = response.getBody();
                    
                    //deserializing
                    Map<String, ResponseWrapper> respResult = (Map<String, ResponseWrapper>) JSON.deserialize(jsonResponse, Map<String, ResponseWrapper>.class);
                    
                    for(String respExternalID : respResult.keySet()){
                        AccountContactRelation acrObj = new AccountContactRelation();
                        acrObj.ID = externalIDMap.get(respExternalID);
                        acrObj.NATT_isMigrated__c = true;
                        updateACRLst.add(acrObj);
                    }
                    
                    if(!updateACRLst.isEmpty()){
                        Database.update(updateACRLst, false);
                    }
                }
            }
            catch(Exception e){
                System.debug('Error-' + e.getMessage() + e.getLineNumber());   
            }
        }
    }
    
    global void finish(Database.BatchableContext bc){
        
        system.debug('Total number of records processed' +totalSizeRecords);
    }
    
    public class ResponseWrapper{
        String success;
        String externalID;
        String message;
    }
}