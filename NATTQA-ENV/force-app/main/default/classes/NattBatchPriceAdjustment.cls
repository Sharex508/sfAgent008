/*
job is responsible for processing all customer pricing
*/
public class NattBatchPriceAdjustment implements Database.Batchable<sObject>,Database.Stateful{
    private Id standardPbId;
    private Boolean hasErrors = false;
    private List<String> errorMessages = new List<String>();
    public NattBatchPriceAdjustment(){
        standardPbId = [SELECT Id FROM Pricebook2 WHERE IsStandard=true].Id;
    }    
    public Database.QueryLocator start(Database.BatchableContext bc){
        return Database.getQueryLocator([SELECT Id,NATT_AdjustmentType__c,NATT_AdjustmentValue__c,NATT_BasisCode__c,NATT_CustomerNumber__c,NATT_CustomerPriceGroup__c,
                                         NATT_EffectiveDate__c,NATT_ExpiryDate__c,NATT_ItemNumber__c,NATT_ItemPriceGroup__c,NATT_PriceAdjustmentKeyId__c,
                                         NATT_PricePartial__c,NATT_QuantityFrom__c,NATT_UOM__c,NATT_Product__c,NATT_Product__r.NATT_UnitCost__c
                                         FROM NATT_PriceAdjustmentStaging__c  
                                         WHERE NATT_EffectiveDate__c<=TODAY 
                                         AND NATT_ExpiryDate__c>=TODAY 
                                         AND NATT_Product__c!=null 
                                         AND RecordType.DeveloperName IN ('NATT_PPG','NATT_TES')
                                         AND NATT_CustomerNumber__c>0 ]);
    }
    public void execute(Database.BatchableContext bc, List<NATT_PriceAdjustmentStaging__c> scope){
        Set<String> pbGroupNameSet = new Set<String>();
        Map<String,Id> groupToPbMap = new Map<String,Id>();       
        Set<String> allItemPriceGroupSet = new Set<String>();
        Set<String> allProductIdSet = new Set<String>();
        Map<String,Pricebook2> allReferencedPbMap = new Map<String,Pricebook2>();
        Map<String,Map<Id,PricebookEntry>> pbToPbeMap = new Map<String,Map<Id,PricebookEntry>>();
        Map<String,PricebookEntry> pbeUpsertMap = new Map<String,PricebookEntry>();
        Map<String,Set<String>> buyerGroupToItemPriceGroupMap = new Map<String,Set<String>>();
        Map<Id,PricebookEntry> standardPbMap = new Map<Id,PricebookEntry>();
        
        Set<Id> pricebookIdSet = new Set<Id>();
        for(NATT_PriceAdjustmentStaging__c pas : scope){            
            pbGroupNameSet.add(String.valueOf(Integer.valueOf(pas.NATT_CustomerNumber__c)));
            allProductIdSet.add(pas.NATT_Product__c);            
        }        
        
        
        //Adjustment Type TREGD=TES REGD=PPG
        //get all the referenced PBs so we can add PBEs to them
        for(Pricebook2 pb : [SELECT Id,Name FROM Pricebook2 WHERE Name IN :pbGroupNameSet AND IsStandard=false AND IsActive=true]){
            allReferencedPbMap.put(pb.Name,pb);
            pricebookIdSet.add(pb.Id);
        }
        
        for(PricebookEntry pbe : [SELECT Id,Pricebook2Id,Product2Id,CurrencyIsoCode,UnitPrice,Pricebook2.Name
                                      FROM PricebookEntry WHERE Product2Id in :allProductIdSet
                                      AND CurrencyIsoCode='USD' AND Pricebook2Id IN :priceBookIdSet]){
                if(!pbToPbeMap.containsKey(pbe.Pricebook2.Name)){
                    pbToPbeMap.put(pbe.Pricebook2.Name,new Map<Id,PricebookEntry>());
                }
                pbToPbeMap.get(pbe.Pricebook2.Name).put(pbe.Product2Id,pbe);
        }

        for(PricebookEntry pbe : [SELECT Id,Pricebook2Id,Product2Id,CurrencyIsoCode,UnitPrice
                                      FROM PricebookEntry WHERE Product2Id in :allProductIdSet
                                      AND CurrencyIsoCode='USD' AND Pricebook2Id=:standardPbId]){
            standardPbMap.put(pbe.Product2Id,pbe);
        }

        decimal cost;
        String pbName;
        String errorMsg = '';
        Set<String> pbeKeySet = new Set<String>();
        
        for(NATT_PriceAdjustmentStaging__c pas : scope){
            pbName = String.valueOf(pas.NATT_CustomerNumber__c);
            if(pas.NATT_AdjustmentType__c=='REGD'){
                //get price from standard pricebook
                cost = pas.NATT_Product__r.NATT_UnitCost__c;                
            }else if(pas.NATT_AdjustmentType__c=='SURCHG' && standardPbMap.containsKey(pas.NATT_Product__c)){
                //get unit cost from the product
                cost = standardPbMap.get(pas.NATT_Product__c).UnitPrice;                
            }
            if(pas.NATT_AdjustmentValue__c!=0){
                cost = cost + (cost * (pas.NATT_AdjustmentValue__c/100));
            }
            if(!pbToPbeMap.containsKey(pbName) && allReferencedPbMap.containsKey(pbName)){
                pbToPbeMap.put(pbName,new Map<Id,PricebookEntry>());
            }

            if(!pbToPbeMap.containskey(pbName)){
                errorMsg+='Missing pricebook: '+pbName+'<br/>';
                continue;
            }
            if(pbToPbeMap.get(pbName).containsKey(pas.NATT_Product__c)){
                String key = pbToPbeMap.get(pbName)+':'+pbToPbeMap.get(pbName).get(pas.NATT_Product__c).Id;
                if(!pbeUpsertMap.containsKey(key))
                    pbeUpsertMap.put(key,new PricebookEntry(Id=pbToPbeMap.get(pbName).get(pas.NATT_Product__c).Id,UnitPrice=cost,IsActive=true));                    
            }else if (!pbToPbeMap.get(pbName).containsKey(pas.Id) && allReferencedPbMap.containsKey(pbName)){
                String key = allReferencedPbMap.get(pbName).Id+':'+pas.NATT_Product__c;
                if(!pbeUpsertMap.containsKey(key))
                    pbeUpsertMap.put(key,new PricebookEntry(Pricebook2Id=allReferencedPbMap.get(pbName).Id,CurrencyIsoCode='USD',Product2Id=pas.NATT_Product__c,UnitPrice=cost,IsActive=true));                    
            }
        }
        if(!pbeUpsertMap.isEmpty()){
            List<Database.UpsertResult> urList=Database.upsert(pbeUpsertMap.values(), PricebookEntry.Id, false);
            integer i = 0;
            for(Database.UpsertResult ur : urList){
                if(!ur.isSuccess()){
                    errorMsg+=pbeUpsertMap.values().get(i).Product2Id+':'+' UnitCost: '+pbeUpsertMap.values().get(i).UnitPrice+'-'+ur.getErrors().get(0).getMessage()+'<br/>';                    
                }
                i++;
            }
        }
        system.debug('107=>> ='+errorMsg);
        if(String.isNotBlank(errorMsg)){
            //sendMessage(errorMsg);
            hasErrors = true;
            errorMessages.add(errorMsg);
        }
    }

    @TestVisible
    private void sendMessage(List<String> errorMessages){
        String emailAddress = Label.NATTBATCHEmailList;
        Messaging.SingleEmailMessage message = new Messaging.SingleEmailMessage(); 
        String body = 'The batch process encountered the following errors:\n' + String.join(errorMessages, '\n');
        message.toAddresses = emailAddress.split(',');
        message.subject = 'NattBatchPriceAdjustment Failure';
        message.htmlBody = body;
        Messaging.SingleEmailMessage[] messages =  new List<Messaging.SingleEmailMessage> {message};
        Messaging.SendEmailResult[] results;
        if(!Test.isRunningTest()){
            results = Messaging.sendEmail(messages);
            if (results[0].success) {
                System.debug('The email was sent successfully.');
            } else {
                System.debug('The email failed to send: ' + results[0].errors[0].message);
            }
        }
    }
    
    public void finish(Database.BatchableContext bc){
        Boolean NATTEnableDebugBatchEmail = Boolean.valueOf(Label.NATTEnableDebugBatchEmail);
        if (hasErrors && NATTEnableDebugBatchEmail) {
            sendMessage(errorMessages);
        }
        if(!Test.isRunningTest())
        	Database.executeBatch(new NattBatchProductPriceGroupAdjustment(),25);
       
    }
}