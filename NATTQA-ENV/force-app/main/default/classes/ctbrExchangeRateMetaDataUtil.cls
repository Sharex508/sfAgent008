public class ctbrExchangeRateMetaDataUtil {
    //Created By : Tejas Hatalkar/Dharani S - 11/11/2022
    //Purpose : This Class will upsert Custom Metadata 'CTBR_Exchange_Rate__mdt' with Current, Previous Rates passed to it from
    //ExchangeRateTriggerHandler. ExchangeRate Object will be upserted everyday by SAP via Bulk API Integration.
    
    @future(callout = true)
    public static void updateCustomMetadataFuture(Set<Id> exchrateIds){
        try{
            //This Method is called from ExchageRateTriggerHandler when Current Rate, Previous Rates are updated via Bulk API Integration (SAP)
            List<Exchange_Rate__c>exchlist = new List<Exchange_Rate__c>([select id,name,CTBR_Current_Rate__c,CTBR_Previous_Rate__c from Exchange_Rate__c where id in :exchrateIds]);
            Map<String, Object> currentRateMap = new Map<String, Object>();
            Map<String, Object> previousRateMap = new Map<String, Object>();
            Map<Id,Exchange_Rate__c> exchMap = new Map<Id,Exchange_Rate__c>();
            List<CTBR_Exchange_Rate__mdt> MetadataListtoAdd = new List<CTBR_Exchange_Rate__mdt>();
            List<CTBR_Exchange_Rate__mdt> MetadataList = [SELECT MasterLabel, DeveloperName,Current_Rate__c,Previous_Rate__c FROM CTBR_Exchange_Rate__mdt]; //MasterLabel, DeveloperName is required when query as we need them in update
            
            for(Exchange_Rate__c exch : exchlist)
            {
                //     exchMap.put(exch.id,exch);
                //     updateCustomMetadata('CTBR_Exchange_Rate__mdt','CTBR_Units', 'CTBR Units',exchMap);
                currentRateMap.put('Current_Rate__c', exch.CTBR_Current_Rate__c);
                //if(exch.Name == 'CTBR Units')
                //{	updateCustomMetadata('CTBR_Exchange_Rate__mdt','CTBR_Units', 'CTBR Units',currentRateMap); }
                //else {	updateCustomMetadata('CTBR_Exchange_Rate__mdt','CTBR_BlueEdge', 'CTBR Blue Edge',currentRateMap); }
                //previousRateMap.put('Yesterday_Rate__c', exch.CTBR_Previous_Rate__c);
                //            updateCustomMetadata('CTBR_Exchange_Rate__mdt','CTBR_Units', 'CTBR Units',previousRateMap);
                metadatalisttoadd.add(new CTBR_Exchange_Rate__mdt(MasterLabel=exch.name,DeveloperName=exch.Name,current_rate__c=exch.CTBR_Current_Rate__c,Previous_Rate__c=exch.CTBR_Previous_Rate__c));
                
            }
            String jobId2 = ctbrExchangeRateMetaDataUtil.upsertMetadata(MetadataListtoadd);
        }
        catch(Exception ex)
        {
            ctbrUtility.LogException(ex, 'ctbrExchangeRateMetadataUtil', 'updateCustomMetadataFuture');
            System.debug('Error in invoking ExchangeRateMetadatautilFutureMethod: '+ex.getMessage() + ' : ' +ex.getStackTraceString());
        }
    }
    
    public static String upsertMetadata(List<sObject> customMetadataList ) {
        try{
            //Create Deployment container for custom Metadata
            Metadata.DeployContainer mdContainer = new Metadata.DeployContainer();
            if(!customMetadataList.isempty()){
                for(sobject sObMD : customMetadataList) {
                    //Get metadata object name and details
                    String sObjectname = sObMD.getSObjectType().getDescribe().getName();
                    System.debug('Object Name is'+sObjectname);
                    //Create custom Metadata instance
                    Metadata.CustomMetadata customMetadata =  new Metadata.CustomMetadata();
                    String recordName = String.valueOf(sObMD.get('DeveloperName')).replaceAll(' ','_');
                    System.debug('Record name is'+recordname);
                    customMetadata.fullName = sObjectname +'.'+recordName;
                    customMetadata.label = (String)sObMD.get('MasterLabel');
                    //Get all fields
                    schema.SObjectType sobjType = Schema.getGlobalDescribe().get(sObjectname );
                    Map<String, Schema.sObjectField> sObjectFields = sobjType.getDescribe().fields.getMap();
                    System.debug('Map sojbectfields is'+sObjectFields);
                    Set<String> skipFieldSet = new Set<String>{'developername','masterlabel','language','namespaceprefix', 'label','qualifiedapiname', 'id'};
                        
                        // Use getPopulatedFieldsAsMap to get the populate field and iterate over them
                        for(String fieldName : sObMD.getPopulatedFieldsAsMap().keySet()) {
                            if(skipFieldSet.contains(fieldName.toLowerCase())|| sObMD.get(fieldName) == null)
                                continue;
                            Object value = sObMD.get(fieldName);    
                            //create field instance and populate it with field API name and value
                            Metadata.CustomMetadataValue customField = new Metadata.CustomMetadataValue();
                            customField.field = fieldName;
                            Schema.DisplayType valueType = sObjectFields.get(fieldName).getDescribe().getType();
                            customField.value = value;
                            //Add fields in the object, similar to creating sObject instance
                            customMetadata.values.add(customField);
                        }
                    //Add metadata in container
                    mdContainer.addMetadata(customMetadata);
                }
                // Callback class instance
                ctbrCustomMetadataCallback callback = new ctbrCustomMetadataCallback();
                
                // Enqueue custom metadata deployment
                // jobId is the deployment ID
                Id jobId = Metadata.Operations.enqueueDeployment(mdContainer, callback);
                return jobId;
            }
            else 
                return 'Null';
        }
        catch(Exception ex)
        {
            ctbrUtility.LogException(ex, 'ctbrExchangeRateMetadataUtil', 'updateCustomMetadata');
            return 'Error in invoking ExchangeRateMetadatautil: '+ex.getMessage() + ' : ' +ex.getStackTraceString();
        }
    }
        
    //use it to pass single metadata instance
    public static String upsertMetadata(sObject customMetadata ) {
        return upsertMetadata(new List<sObject>{customMetadata} );
    }
    
}