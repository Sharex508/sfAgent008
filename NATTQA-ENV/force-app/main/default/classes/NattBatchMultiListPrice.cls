public class NattBatchMultiListPrice implements Database.Batchable<sObject>,Database.Stateful{
    Id standardPbId = Test.isRunningTest()?Test.getStandardPricebookId():[SELECT Id FROM Pricebook2 WHERE IsStandard=true].Id;
    private Boolean hasErrors = false;
    private List<String> errorMessages = new List<String>();
    public Database.QueryLocator start(Database.BatchableContext bc){
        return Database.getQueryLocator([SELECT Id,NATT_BasisCode__c,NATT_CustomerNumber__c,NATT_CustomerPriceGroup__c,NATT_EffectiveDate__c,NATT_ExpiryDate__c,NATT_ItemNumber__c,
                                         NATT_ItemPriceGroup__c,NATT_ItemPriceKeyId__c,NATT_ItemPriceType__c,NATT_ListPrice__c,NATT_PricePartial__c,NATT_QuantityFrom__c,NATT_UOM__c,
                                         NATT_Product__c,NATT_Product__r.NATT_UnitCost__c,NATT_Product__r.NATT_ItemPriceGroup__c
                                         FROM NATT_ItemPriceStaging__c 
                                         WHERE NATT_EffectiveDate__c<=TODAY AND NATT_ExpiryDate__c>=TODAY 
                                         AND NATT_ItemPriceType__c='SRP'
                                         AND NATT_CustomerPriceGroup__c=null
                                         AND NATT_ItemPriceGroup__c=null
                                         AND NATT_ListPrice__c>0
                                         AND NATT_Product__c!=''
                                         AND NATT_CustomerNumber__c!=null  
                                         AND RecordType.DeveloperName IN ('NATT_PPG','NATT_TES')                                       
                                         ORDER BY NATT_CustomerNumber__c DESC, NATT_QuantityFrom__c ASC]);
    }
    public void execute(Database.BatchableContext bc, List<NATT_ItemPriceStaging__c> scope){        
        Set<Id> srpIdSet = new Set<Id>();
        Set<String> accountPartCodeSet = new Set<String>();
        Map<Id,PricebookEntry> standardPbeMap = new Map<Id,PricebookEntry>();
        List<PricebookEntry> pbeUpsertList = new List<PricebookEntry>();        
        Map<String,Account> accountMap = new Map<String,Account>();
        Set<String> customerPriceGroupSet = new Set<String>();
        Map<String,NATT_PriceAdjustmentStaging__c> adjustmentMap = new Map<String,NATT_PriceAdjustmentStaging__c>();
        Set<String> itemPriceGroupSet = new Set<String>();
        Set<Id> pricebookIdSet = new Set<Id>();
        Map<String,Pricebook2> allReferencedPbMap = new Map<String,Pricebook2>();
        Map<String,Map<Id,PricebookEntry>> pbToPbeMap = new Map<String,Map<Id,PricebookEntry>>();
        Map<String,PricebookEntry> pbeUpsertMap = new Map<String,PricebookEntry>();		
        
        for(NATT_ItemPriceStaging__c ip : scope){            
            srpIdSet.add(ip.NATT_Product__c);
            accountPartCodeSet.add(String.valueOf(ip.NATT_CustomerNumber__c));
            itemPriceGroupSet.add(ip.NATT_Product__r.NATT_ItemPriceGroup__c);
        }

        for(Account a : [SELECT Id,NATT_JDE_Parts_Bill_To_Code__c,NATT_Customer_Price_Group__c FROM Account WHERE NATT_JDE_Parts_Bill_To_Code__c IN :accountPartCodeSet]){
            accountMap.put(a.NATT_JDE_Parts_Bill_To_Code__c,a);
            customerPriceGroupSet.add(a.NATT_Customer_Price_Group__c);            
        }
		System.debug('AccountMap:'+accountMap);
        System.debug('customerPriceGroupSet:'+customerPriceGroupSet);
        System.debug('itemPriceGroupSet:'+itemPriceGroupSet);
        //get all the referenced PBs so we can add PBEs to them
        for(Pricebook2 pb : [SELECT Id,Name FROM Pricebook2 WHERE Name IN :accountMap.keySet() AND IsStandard=false AND IsActive=true]){
            allReferencedPbMap.put(pb.Name,pb);
            pricebookIdSet.add(pb.Id);
        }
        
        //find pricebooks that have not been previously created (which is the case for most of the customer specific standard prices)
        Set<String> pbNotCreatedSet = new Set<String>();
        for(String accountCode : accountPartCodeSet){
            if(!allReferencedPbMap.containsKey(accountCode)){
                pbNotCreatedSet.add(accountCode);
            }
        }        
        if(!pbNotCreatedSet.isEmpty()){
            System.debug('creating: '+pbNotCreatedSet);
            PriceAdjustmentStagingTrgHandler.handleBuyerGroupSetup(pbNotCreatedSet);
            for(Pricebook2 pb : [SELECT Id,Name FROM Pricebook2 WHERE Name IN :accountMap.keySet() AND IsStandard=false AND IsActive=true]){
                allReferencedPbMap.put(pb.Name,pb);
                pricebookIdSet.add(pb.Id);
            }
        }
        
        for(PricebookEntry pbe : [SELECT Id,Pricebook2Id,Product2Id,CurrencyIsoCode,UnitPrice,Pricebook2.Name
                                      FROM PricebookEntry WHERE Product2Id in :srpIdSet 
                                      AND CurrencyIsoCode='USD' AND Pricebook2Id=:standardPbId]){
        	standardPbeMap.put(pbe.Product2Id,pbe);
         }
        
        for(PricebookEntry pbe : [SELECT Id,Pricebook2Id,Product2Id,CurrencyIsoCode,UnitPrice,Pricebook2.Name
                                      FROM PricebookEntry WHERE Product2Id in :srpIdSet
                                      AND CurrencyIsoCode='USD' AND Pricebook2Id IN :priceBookIdSet]){
                if(!pbToPbeMap.containsKey(pbe.Pricebook2.Name)){
                    pbToPbeMap.put(pbe.Pricebook2.Name,new Map<Id,PricebookEntry>());
                }
                //per Carrier: only adding if there is a standard price to adjust
                if(standardPbeMap.containsKey(pbe.Product2Id)){
                	pbToPbeMap.get(pbe.Pricebook2.Name).put(pbe.Product2Id,pbe);
                }
        }
		System.debug('pbToPbeMap:'+pbToPbeMap);
        for(NATT_PriceAdjustmentStaging__c stage : [SELECT Id,NATT_CustomerPriceGroup__c,NATT_ItemPriceGroup__c,NATT_AdjustmentValue__c 
                                                    FROM NATT_PriceAdjustmentStaging__c 
                                                    WHERE NATT_CustomerPriceGroup__c IN :customerPriceGroupSet
                                                    AND NATT_ItemPriceGroup__c IN :itemPriceGroupSet 
                                                    AND NATT_AdjustmentType__c='REGD' 
                                                    AND NATT_AdjustmentValue__c!=0
                                                    AND NATT_EffectiveDate__c<=TODAY AND NATT_ExpiryDate__c>=TODAY ]){
            adjustmentMap.put(stage.NATT_CustomerPriceGroup__c+':'+stage.NATT_ItemPriceGroup__c,stage);
        }
        System.debug('adjustmentMap:'+adjustmentMap);
        String key;
        decimal adjustmentValue;
        decimal pbeValue;
        String errorMsg='';
        for(NATT_ItemPriceStaging__c ip : scope){
            if(accountMap.containsKey(String.valueOf(ip.NATT_CustomerNumber__c))){
                Account a = accountMap.get(String.valueOf(ip.NATT_CustomerNumber__c));
                key = a.NATT_Customer_Price_Group__c+':'+ip.NATT_Product__r.NATT_ItemPriceGroup__c;
                if(adjustmentMap.containsKey(key)){
                    adjustmentValue = adjustmentMap.get(key).NATT_AdjustmentValue__c;
                    pbeValue = ip.NATT_ListPrice__c * (1 + (adjustmentValue/100));
                }
                if(pbToPbeMap.containsKey(a.NATT_JDE_Parts_Bill_To_Code__c) && pbToPbeMap.get(a.NATT_JDE_Parts_Bill_To_Code__c).containsKey(ip.NATT_Product__c)){
                    String pbkey = pbToPbeMap.get(a.NATT_JDE_Parts_Bill_To_Code__c)+':'+pbToPbeMap.get(a.NATT_JDE_Parts_Bill_To_Code__c).get(ip.NATT_Product__c).Id;
                    if(!pbeUpsertMap.containsKey(pbkey))
                        pbeUpsertMap.put(pbkey,new PricebookEntry(Id=pbToPbeMap.get(a.NATT_JDE_Parts_Bill_To_Code__c).get(ip.NATT_Product__c).Id,UnitPrice=pbeValue,IsActive=true));                    
                }else if ((!pbToPbeMap.containsKey(a.NATT_JDE_Parts_Bill_To_Code__c) || !pbToPbeMap.get(a.NATT_JDE_Parts_Bill_To_Code__c).containsKey(ip.NATT_Product__c)) && allReferencedPbMap.containsKey(a.NATT_JDE_Parts_Bill_To_Code__c)){
                    String pbkey = allReferencedPbMap.get(a.NATT_JDE_Parts_Bill_To_Code__c).Id+':'+ip.NATT_Product__c;
                    if(!pbeUpsertMap.containsKey(pbkey))
                        pbeUpsertMap.put(pbkey,new PricebookEntry(Pricebook2Id=allReferencedPbMap.get(a.NATT_JDE_Parts_Bill_To_Code__c).Id,CurrencyIsoCode='USD',Product2Id=ip.NATT_Product__c,UnitPrice=pbeValue,IsActive=true));                    
                }
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
            System.debug('errorMsg'+errorMsg);
            if(String.isNotBlank(errorMsg)){
                //sendMessage(errorMsg);
                hasErrors = true;
                errorMessages.add(errorMsg);
            }
        }
    }

    public void finish(Database.BatchableContext bc){
        Boolean NATTEnableDebugBatchEmail = Boolean.valueOf(Label.NATTEnableDebugBatchEmail);
        if (hasErrors && NATTEnableDebugBatchEmail) {
            sendMessage(errorMessages);
        }
        if(!Test.isRunningTest())
        	Database.executeBatch(new NattBatchPriceAdjustment());
    }
    
    @TestVisible
    private void sendMessage(List<String> errorMessages){
        String emailAddress = Label.NATTBATCHEmailList;
        Messaging.SingleEmailMessage message = new Messaging.SingleEmailMessage(); 
         String body = 'The batch process encountered the following errors:\n' + String.join(errorMessages, '\n');
        message.toAddresses = emailAddress.split(','); 
        message.subject = 'NattBatchMultiListPrice Failure';
        message.htmlBody = body;
        Messaging.SingleEmailMessage[] messages = new List<Messaging.SingleEmailMessage> {message};
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
}