public class NattBatchItemPrice implements Database.Batchable<sObject>,Schedulable,Database.Stateful{
    Id standardPbId = [SELECT Id,Name FROM Pricebook2 WHERE IsStandard=true].Id;
    List<Pricebook2> pbList  = new List<Pricebook2>([SELECT Id,Name FROM Pricebook2 WHERE Name in ('Performance Parts Price Book','TES Storefront Pricebook')]);
    private Boolean hasErrors = false;
    private List<String> errorMessages = new List<String>();
    public Database.QueryLocator start(Database.BatchableContext bc){
        return Database.getQueryLocator([SELECT Id,NATT_BasisCode__c,NATT_CustomerNumber__c,NATT_CustomerPriceGroup__c,NATT_EffectiveDate__c,NATT_ExpiryDate__c,NATT_ItemNumber__c,
                                         NATT_ItemPriceGroup__c,NATT_ItemPriceKeyId__c,NATT_ItemPriceType__c,NATT_ListPrice__c,NATT_PricePartial__c,NATT_QuantityFrom__c,NATT_UOM__c,
                                         NATT_Product__c,NATT_Product__r.NATT_UnitCost__c,NATT_Product__r.NATT_Branch_Plant_Warehouse__c
                                         FROM NATT_ItemPriceStaging__c 
                                         WHERE NATT_EffectiveDate__c<=TODAY AND NATT_ExpiryDate__c>=TODAY 
                                         AND NATT_Product__c!=''
                                         AND RecordType.DeveloperName IN ('NATT_PPG','NATT_TES') ORDER BY NATT_CustomerNumber__c DESC, NATT_QuantityFrom__c ASC]);
    }
    public void execute(Database.BatchableContext bc, List<NATT_ItemPriceStaging__c> scope){        
        Set<Id> srpIdSet = new Set<Id>();
        Map<Id,PricebookEntry> standardPbeMap = new Map<Id,PricebookEntry>();
        Map<Id,PricebookEntry> ppgStorePbeMap = new Map<Id,PricebookEntry>();
        Map<Id,PricebookEntry> tesStorePbeMap = new Map<Id,PricebookEntry>();
        List<PricebookEntry> pbeUpsertList = new List<PricebookEntry>();
        List<PricebookEntry> storePbeUpsertList = new List<PricebookEntry>();
        List<Product2> pUpdateList = new List<Product2>();
        Date dToday = Date.today();
        Id ppgPbId, tesPbId;
        Map<String,Map<Id,CommerceEntitlementProduct>> tesEntitlementProductMap = new Map<String,Map<Id,CommerceEntitlementProduct>>();
        Set<String> tesAddedPolicyProductSet = new Set<String>();
        List<CommerceEntitlementProduct> tesCepList = new List<CommerceEntitlementProduct>();
        Set<Id> standardPbAdded = new Set<Id>();
        Set<Id> tesPbAdded = new Set<Id>();
        Set<Id> ppgPbAdded = new Set<Id>();

        Map<String,Id> entPolicyMap = new Map<String,Id>();
        for(CommerceEntitlementPolicy policy : [SELECT Id,Name FROM CommerceEntitlementPolicy WHERE Name ='All Access for TES Store']){
            entPolicyMap.put(policy.Name,policy.Id);
        }

        Set<Id> pbIdSet = new Set<Id>();
        pbIdSet.add(standardPbId);
        for(Pricebook2 pb : pbList){
            if(pb.Name=='Performance Parts Price Book'){
                ppgPbId=pb.Id;
            }else if(pb.Name=='TES Storefront Pricebook'){
                tesPbId=pb.Id;
            }
            pbIdSet.add(pb.Id);
        }
        

        for(NATT_ItemPriceStaging__c ip : scope){            
            if(ip.NATT_ItemPriceType__c=='SRP' || ip.NATT_ItemPriceType__c=='LPRC'){
                srpIdSet.add(ip.NATT_Product__c);
            }
        }
        
        if(!srpIdSet.isEmpty()){            
            for(PricebookEntry pbe : [SELECT Id,Pricebook2Id,Product2Id,CurrencyIsoCode,UnitPrice,Pricebook2.Name
                                      FROM PricebookEntry WHERE Product2Id in :srpIdSet 
                                      AND CurrencyIsoCode='USD' AND Pricebook2Id in :pbIdSet]){
                if(pbe.Pricebook2Id==standardPbId){
                    standardPbeMap.put(pbe.Product2Id,pbe);
                }else if(pbe.Pricebook2Id==ppgPbId){
                    ppgStorePbeMap.put(pbe.Product2Id,pbe);
                }else if(pbe.Pricebook2Id==tesPbId){
                    tesStorePbeMap.put(pbe.Product2Id,pbe);
                }
            }
            System.debug('standardPbemap:'+standardPbeMap);
        }

        if(!tesStorePbeMap.isEmpty()){
            for(CommerceEntitlementProduct cep : [SELECT Id,PolicyId,Policy.Name,ProductId FROM CommerceEntitlementProduct WHERE Policy.Name='All Access for TES Store' AND ProductId IN :tesStorePbeMap.keySet()]){
                if(!tesEntitlementProductMap.containsKey(cep.Policy.Name)){
                    tesEntitlementProductMap.put(cep.Policy.Name,new Map<Id,CommerceEntitlementProduct>());
                }
                tesEntitlementProductMap.get(cep.Policy.Name).put(cep.ProductId,cep);
            }
        }
        
        for(NATT_ItemPriceStaging__c ip : scope){
            //srp=PPG lprc=TES
            if(ip.NATT_ItemPriceType__c=='SRP' || ip.NATT_ItemPriceType__c=='LPRC'){                
                //add list price to standard price book
                if(ip.NATT_CustomerNumber__c==0 && ip.NATT_QuantityFrom__c==1){
                    //get the standard pricebook and check to see if there is a PBE, if not, create it
                    if(standardPbeMap.containsKey(ip.NATT_Product__c) && standardPbeMap.get(ip.NATT_Product__c).UnitPrice!=ip.NATT_ListPrice__c && !standardPbAdded.contains(ip.NATT_Product__c)){                        
                        pbeUpsertList.add(new PricebookEntry(Id=standardPbemap.get(ip.NATT_Product__c).Id,UnitPrice=ip.NATT_ListPrice__c,IsActive=true,NATT_Effective_Date__c=ip.NATT_EffectiveDate__c));
                        standardPbAdded.add(ip.NATT_Product__c);
                    }else if (!standardPbeMap.containsKey(ip.NATT_Product__c) && !standardPbAdded.contains(ip.NATT_Product__c)){
                        pbeUpsertList.add(new PricebookEntry(Pricebook2Id=standardPbId,CurrencyIsoCode='USD',Product2Id=ip.NATT_Product__c,UnitPrice=ip.NATT_ListPrice__c,IsActive=true,NATT_Effective_Date__c=ip.NATT_EffectiveDate__c));
                        standardPbAdded.add(ip.NATT_Product__c);
                    }

                    //add to store
                    if(ip.NATT_Product__r.NATT_Branch_Plant_Warehouse__c=='TES'){
                        if(tesStorePbeMap.containsKey(ip.NATT_Product__c) && tesStorePbeMap.get(ip.NATT_Product__c).UnitPrice!=ip.NATT_ListPrice__c && !tesPbAdded.contains(ip.NATT_Product__c)){                        
                            storePbeUpsertList.add(new PricebookEntry(Id=tesStorePbemap.get(ip.NATT_Product__c).Id,UnitPrice=ip.NATT_ListPrice__c,IsActive=true,NATT_Effective_Date__c=ip.NATT_EffectiveDate__c));
                            tesPbAdded.add(ip.NATT_Product__c);
                        }else if (!tesStorePbeMap.containsKey(ip.NATT_Product__c) && !tesPbAdded.contains(ip.NATT_Product__c)){
                            storePbeUpsertList.add(new PricebookEntry(Pricebook2Id=tesPbId,CurrencyIsoCode='USD',Product2Id=ip.NATT_Product__c,UnitPrice=ip.NATT_ListPrice__c,IsActive=true,NATT_Effective_Date__c=ip.NATT_EffectiveDate__c));
                            tesPbAdded.add(ip.NATT_Product__c);
                        }

                        if(!tesAddedPolicyProductSet.contains(entpolicyMap.get('All Access for TES Store')+':'+ip.NATT_Product__c)){
                            tesAddedPolicyProductSet.add(entpolicyMap.get('All Access for TES Store')+':'+ip.NATT_Product__c);
                            if(tesEntitlementProductMap.containsKey('All Access for TES Store')){                            
                                if(!tesEntitlementProductMap.get('All Access for TES Store').containsKey(ip.NATT_Product__c)){                                
                                    tesCepList.add(new CommerceEntitlementProduct(PolicyId=entPolicyMap.get('All Access for TES Store'),ProductId=ip.NATT_Product__c));
                                }
                            }else{
                                tesCepList.add(new CommerceEntitlementProduct(PolicyId=entPolicyMap.get('All Access for TES Store'),ProductId=ip.NATT_Product__c));
                            }
                        }                            
                    }else{
                        if(ppgStorePbeMap.containsKey(ip.NATT_Product__c) && ppgStorePbeMap.get(ip.NATT_Product__c).UnitPrice!=ip.NATT_ListPrice__c && !ppgPbAdded.contains(ip.NATT_Product__c)){                        
                            storePbeUpsertList.add(new PricebookEntry(Id=ppgStorePbemap.get(ip.NATT_Product__c).Id,UnitPrice=ip.NATT_ListPrice__c,IsActive=true,NATT_Effective_Date__c=ip.NATT_EffectiveDate__c));
                            ppgPbAdded.add(ip.NATT_Product__c);
                        }else if (!ppgStorePbeMap.containsKey(ip.NATT_Product__c) && !ppgPbAdded.contains(ip.NATT_Product__c)){
                            storePbeUpsertList.add(new PricebookEntry(Pricebook2Id=ppgPbId,CurrencyIsoCode='USD',Product2Id=ip.NATT_Product__c,UnitPrice=ip.NATT_ListPrice__c,IsActive=true,NATT_Effective_Date__c=ip.NATT_EffectiveDate__c));
                            ppgPbAdded.add(ip.NATT_Product__c);
                        }
                    }
                }                
            }else if((ip.NATT_ItemPriceType__c=='INTPRC'||ip.NATT_ItemPriceType__c=='TINT') && ip.NATT_Product__r.NATT_UnitCost__c!=ip.NATT_ListPrice__c){                
                pUpdateList.add(new Product2(Id=ip.NATT_Product__c,NATT_UnitCost__c=ip.NATT_ListPrice__c,IsActive=true));                
            }            
        }
        System.debug('pbeUpserList:'+pbeUpsertList);
        String errorMsg='';
        if(!pUpdateList.isEmpty()){
            update pUpdateList;
        }
        //create standard entries before adding to custom PB
        if(!pbeUpsertList.isEmpty()){
           // upsert pbeUpsertList PricebookEntry.Id;
            List<Database.UpsertResult> pbeList=Database.upsert(pbeUpsertList, PricebookEntry.Id, false);
            integer i = 0;
            for(Database.UpsertResult ur : pbeList){
                if(!ur.isSuccess()){
                    System.debug('price entry Product error: '+ur.getErrors().get(0).getMessage()); 
                    errorMsg+=pbeUpsertList[i].Product2Id+' :- '+ur.getErrors().get(0).getMessage()+'<br/>'; 
                }
                i++;
            }
        }        

        if(!storePbeUpsertList.isEmpty()){
            //upsert storePbeUpsertList PricebookEntry.Id;
             List<Database.UpsertResult> storePbeList=Database.upsert(storePbeUpsertList, PricebookEntry.Id, false);
            integer i = 0;
            for(Database.UpsertResult ur : storePbeList){
                if(!ur.isSuccess()){
                    System.debug('price entry Product error: '+ur.getErrors().get(0).getMessage()); 
                    errorMsg+=storePbeUpsertList[i].Product2Id+' :- '+ur.getErrors().get(0).getMessage()+'<br/>'; 
                }
                i++;
            }
            errorMsg+='No error in the batch chunk';
        }

        if(!tesCepList.isEmpty()){
            System.debug('cepList:'+tesCepList);
            List<Database.UpsertResult> urList=Database.upsert(tesCepList, CommerceEntitlementProduct.Id, false);
            integer i = 0;
            for(Database.UpsertResult ur : urList){
                if(!ur.isSuccess()){
                    System.debug('CommerceEntitleProduct error: '+ur.getErrors().get(0).getMessage()); 
                    errorMsg+='Tes Error :- '+ur.getErrors().get(0).getMessage()+'<br/>';
                }
                i++;
            }
        }
        System.debug('errorMsg'+errorMsg);
        if(String.isNotBlank(errorMsg)){
            hasErrors = true;
            errorMessages.add(errorMsg);
        }
    }

    public void finish(Database.BatchableContext bc){
        Boolean NATTEnableDebugBatchEmail = Boolean.valueOf(Label.NATTEnableDebugBatchEmail);
        if (hasErrors && NATTEnableDebugBatchEmail) {
            sendMessage(errorMessages);
        }
        Database.executeBatch(new NattBatchMultiListPrice());        
    }

    public void execute(SchedulableContext sc){
        Database.executeBatch(new NattBatchItemPrice());
        integer i=0;
        i++;
    }
    
    @TestVisible
    private void sendMessage(List<String> errorMessages){
        
        String emailAddress = Label.NATTBATCHEmailList;
        Messaging.SingleEmailMessage message = new Messaging.SingleEmailMessage(); 
        String body = 'The batch process encountered the following errors:\n' + String.join(errorMessages, '\n');
        message.toAddresses = emailAddress.split(',');                
        message.subject = 'NattBatchItemPrice Failure';
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