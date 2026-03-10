public with sharing class NattBatchProductPriceGroupAdjustment implements Database.Batchable<sObject>,Database.Stateful{
    private Id standardPbId;
    private Boolean hasErrors = false;
    private List<String> errorMessages = new List<String>();
    public NattBatchProductPriceGroupAdjustment(){
        standardPbId = [SELECT Id FROM Pricebook2 WHERE IsStandard=true].Id;
    }    
    public Database.QueryLocator start(Database.BatchableContext bc){
        return Database.getQueryLocator([SELECT Id,NATT_ItemPriceGroup__c,NATT_UnitCost__c,Name,NATT_P_N__c
                                         FROM Product2 
                                         WHERE IsActive=true 
                                         AND NATT_UnitCost__c!=null and RecordType.Name != 'NAC Products'
                                         AND NATT_ItemPriceGroup__c!=null
                                         AND NATT_ItemPriceGroup__c NOT IN ('999','980')
                                         ORDER BY NATT_ItemPriceGroup__c]);
    }
    public void execute(Database.BatchableContext bc, List<Product2> scope){
        Set<String> itemPriceGroupSet = new Set<String>();
        Set<Id> productIdSet = new Set<Id>();
        Set<String> pbNameSet = new Set<String>();
        Set<String> dupeCheckSet = new Set<String>();
        
        Map<String,List<NATT_PriceAdjustmentStaging__c>> itemPriceGroupMap = new Map<String,List<NATT_PriceAdjustmentStaging__c>>();        
        
        for(Product2 p : scope){
            itemPriceGroupSet.add(p.NATT_ItemPriceGroup__c);     
            productIdSet.add(p.Id);
        }
        
        String key;
        //grab all item price groups (by customer price group) so we can process the adjustments
        for(NATT_PriceAdjustmentStaging__c pas : [SELECT Id,NATT_AdjustmentType__c,NATT_AdjustmentValue__c,NATT_CustomerPriceGroup__c,NATT_ItemPriceGroup__c,NATT_EffectiveDate__c
                                                  FROM NATT_PriceAdjustmentStaging__c  
                                                  WHERE NATT_EffectiveDate__c<=TODAY AND NATT_ExpiryDate__c>=TODAY 
                                                  AND NATT_AdjustmentType__c in ('REGD','SURCHG')
                                                  AND NATT_Product__c=null  
                                                  AND NATT_CustomerNumber__c=0 
                                                  AND RecordType.DeveloperName IN ('NATT_PPG','NATT_TES')
                                                  AND NATT_ItemPriceGroup__c IN :itemPriceGroupSet]){
                                                      key = pas.NATT_CustomerPriceGroup__c+':'+pas.NATT_ItemPriceGroup__c+':'+pas.NATT_AdjustmentType__c;
                                                      if(!itemPriceGroupMap.containsKey(pas.NATT_ItemPriceGroup__c)){
                                                          itemPriceGroupMap.put(pas.NATT_ItemPriceGroup__c,new List<NATT_PriceAdjustmentStaging__c>());
                                                      }
                                                      if(!dupeCheckSet.contains(key)){
                                                          itemPriceGroupMap.get(pas.NATT_ItemPriceGroup__c).add(pas);
                                                          dupeCheckSet.add(key);
                                                      }
                                                      pbNameSet.add(pas.NATT_CustomerPriceGroup__c);
                                                  }
        
        //get all the referenced pricebooks
        Map<String,Id> pbNameToIdMap = new Map<String,Id>();
        Map<String,Map<Id,PricebookEntry>> pbToProductPbeMap = new Map<String,Map<Id,PricebookEntry>>();
        for(Pricebook2 pb : [SELECT Id,Name FROM Pricebook2 WHERE Name IN :pbNameSet]){
            pbNameToIdMap.put(pb.Name,pb.Id);
            if(!pbToProductPbeMap.containsKey(pb.Name)){
                pbToProductPbeMap.put(pb.Name,new Map<Id,PricebookEntry>());
            }
        }
        
        System.debug('pbNameSet:'+pbNameSet);
        
        //get all the existing PBEs        
        for(PricebookEntry pbe : [SELECT Id,Pricebook2.Name,Product2Id,UnitPrice FROM PricebookEntry WHERE Product2Id IN :productIdSet AND Pricebook2Id IN :pbNameToIdMap.values()]){
            if(!pbToProductPbeMap.containsKey(pbe.Pricebook2.Name)){
                pbToProductPbeMap.put(pbe.Pricebook2.Name,new Map<Id,PricebookEntry>());
            }
            pbToProductPbeMap.get(pbe.Pricebook2.Name).put(pbe.Product2Id,pbe);
        }
        
        System.debug('pbToPRoductPbeMap:'+pbToProductPbeMap);
        //get all referenced policies (in case there are no products added yet)
        Map<String,Id> entPolicyMap = new Map<String,Id>();
        for(CommerceEntitlementPolicy policy : [SELECT Id,Name FROM CommerceEntitlementPolicy WHERE Name in :pbNameSet]){
            entPolicyMap.put(policy.Name,policy.Id);
        }
        
        //get all the existing commerceentitlement products
        Map<String,Map<Id,CommerceEntitlementProduct>> entitlementProductMap = new Map<String,Map<Id,CommerceEntitlementProduct>>();
        for(CommerceEntitlementProduct cep : [SELECT Id,PolicyId,Policy.Name,ProductId FROM CommerceEntitlementProduct WHERE Policy.Name in :pbNameSet AND ProductId IN :productIdSet]){
            if(!entitlementProductMap.containsKey(cep.Policy.Name)){
                entitlementProductMap.put(cep.Policy.Name,new Map<Id,CommerceEntitlementProduct>());
            }
            entitlementProductMap.get(cep.Policy.Name).put(cep.ProductId,cep);
        }
        
        //get the standard price
        Map<Id,PricebookEntry> standardPbMap = new Map<Id,PricebookEntry>();
        for(PricebookEntry pbe : [SELECT Id,Pricebook2Id,Product2Id,CurrencyIsoCode,UnitPrice
                                  FROM PricebookEntry 
                                  WHERE CurrencyIsoCode='USD' 
                                  AND Pricebook2Id=:standardPbId
                                  AND Product2Id IN :productIdSet]){
                                      standardPbMap.put(pbe.Product2Id,pbe);
                                  }
        
        decimal cost;
        List<PricebookEntry> pbeList = new List<PricebookEntry>();
        List<CommerceEntitlementProduct> cepList = new List<CommerceEntitlementProduct>();
        Set<String> addedPolicyProductSet = new Set<String>();
        Set<String> addedPbeSet = new Set<String>();
        for(Product2 p : scope){
            System.debug('looking for ItemPriceGroup:'+p.NATT_ItemPriceGroup__c);
            if(itemPriceGroupMap.containsKey(p.NATT_ItemPriceGroup__c)){
                System.debug('found ItemPriceGroup:'+itemPriceGroupMap.get(p.NATT_ItemPriceGroup__c));
                //once we have staging records for the product...pull them and process
                for(NATT_PriceAdjustmentStaging__c pas : itemPriceGroupMap.get(p.NATT_ItemPriceGroup__c)){
                    System.debug('pas:'+pas);            
                    //loop over all the customer price groups for this item price group
                    if(pas.NATT_AdjustmentType__c=='REGD' && standardPbMap.containsKey(p.Id)){
                        cost = standardPbMap.get(p.Id).UnitPrice;
                    }else if(pas.NATT_AdjustmentType__c=='SURCHG'){
                        cost = p.NATT_UnitCost__c;                        
                    }
                    else{
                        //if we can't find a cost because it's missing or some other reason, skip the record
                        continue;
                    }
                    if(pas.NATT_AdjustmentValue__c!=0){
                        System.debug('cost:'+cost+' for product:'+p.Name+':'+p.NATT_P_N__c);
                        cost = cost + (cost * (pas.NATT_AdjustmentValue__c/100));
                    }
                    //add all the products to their custom pricebook
                    System.debug('looking for customer price group:'+pas.NATT_CustomerPriceGroup__c);
                    if(pbNameToIdMap.containsKey(pas.NATT_CustomerPriceGroup__c)){
                        if(!addedPbeSet.contains(pbNameToIdMap.get(pas.NATT_CustomerPriceGroup__c)+':'+p.Id)){
                            addedPbeSet.add(pbNameToIdMap.get(pas.NATT_CustomerPriceGroup__c)+':'+p.Id);
                            if(pbToProductPbeMap.containsKey(pas.NATT_CustomerPriceGroup__c)){
                                System.debug('found pricebook:'+pbToProductPbeMap.get(pas.NATT_CustomerPriceGroup__c));
                                if(pbToProductPbeMap.get(pas.NATT_CustomerPriceGroup__c).containsKey(p.Id)){
                                    if(pbToProductPbeMap.get(pas.NATT_CustomerPriceGroup__c).get(p.Id).UnitPrice!=cost){
                                        pbeList.add(new PricebookEntry(Id=pbToProductPbeMap.get(pas.NATT_CustomerPriceGroup__c).get(p.Id).Id,UnitPrice=cost,IsActive=true));
                                    }
                                }else {                                    
                                    pbeList.add(new PricebookEntry(Pricebook2Id=pbNameToIdMap.get(pas.NATT_CustomerPriceGroup__c),CurrencyIsoCode='USD',Product2Id=p.Id,UnitPrice=cost,IsActive=true));
                                }
                            }else{
                                System.debug('did not find pricebook:'+pas.NATT_CustomerPriceGroup__c);
                            }
                        }   
                    }
                    
                    //create the relationship for the entitlment product
                    System.debug('entitlement looking for customerprice group:'+pas.NATT_CustomerPriceGroup__c);
                    if(entPolicyMap.containsKey(pas.NATT_CustomerPriceGroup__c)){
                        if(!addedPolicyProductSet.contains(entpolicyMap.get(pas.NATT_CustomerPriceGroup__c)+':'+p.Id)){
                            addedPolicyProductSet.add(entpolicyMap.get(pas.NATT_CustomerPriceGroup__c)+':'+p.Id);
                            if(entitlementProductMap.containsKey(pas.NATT_CustomerPriceGroup__c)){
                                System.debug('entitlement found customerprice group:'+entitlementProductMap.get(pas.NATT_CustomerPriceGroup__c));
                                if(!entitlementProductMap.get(pas.NATT_CustomerPriceGroup__c).containsKey(p.Id)){
                                    System.debug('adding productId:'+p.Id);
                                    cepList.add(new CommerceEntitlementProduct(PolicyId=entPolicyMap.get(pas.NATT_CustomerPriceGroup__c),ProductId=p.Id));
                                }
                            }else{
                                cepList.add(new CommerceEntitlementProduct(PolicyId=entPolicyMap.get(pas.NATT_CustomerPriceGroup__c),ProductId=p.Id));
                            }
                        }
                    }
                }
            }
        }
        String errorMsg='';
        if(!pbeList.isEmpty()){
            System.debug('pbeList:'+pbeList);
            List<Database.UpsertResult> urList=Database.upsert(pbeList, PricebookEntry.Id, false);
            integer i = 0;
            for(Database.UpsertResult ur : urList){
                if(!ur.isSuccess()){
                    errorMsg+=pbeList.get(i).Product2Id+':'+' UnitCost: '+pbeList.get(i).UnitPrice+'-'+ur.getErrors().get(0).getMessage()+'<br/>';                    
                }
                i++;
            }
        }
        if(!cepList.isEmpty()){
            System.debug('cepList:'+cepList);
            List<Database.UpsertResult> urList=Database.upsert(cepList, CommerceEntitlementProduct.Id, false);
            integer i = 0;
            for(Database.UpsertResult ur : urList){
                if(!ur.isSuccess()){
                    errorMsg+='CommerceEntitleProduct error: '+ur.getErrors().get(0).getMessage()+'<br/>';                    
                }
                i++;
            }
        }
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
        message.subject = 'NattBatchProductPriceGroupAdjustment Failure';
        message.htmlBody = body;
        Messaging.SingleEmailMessage[] messages = new List<Messaging.SingleEmailMessage> {message};
        Messaging.SendEmailResult[] results = Messaging.sendEmail(messages);
        if (results[0].success) {
            System.debug('The email was sent successfully.');
        } else {
            System.debug('The email failed to send: ' + results[0].errors[0].message);
        }
    }
    
    public void finish(Database.BatchableContext bc){
        Boolean NATTEnableDebugBatchEmail = Boolean.valueOf(Label.NATTEnableDebugBatchEmail);
        if (hasErrors && NATTEnableDebugBatchEmail) {
            sendMessage(errorMessages);
        }
        if(!Test.isRunningTest())
        	Database.executeBatch(new NattBatchQuantityBreak());
    }
}