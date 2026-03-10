public with sharing class NattBatchQuantityBreak implements Database.Batchable<sObject>{
    private Id standardPbId;
    public NattBatchQuantityBreak(){
        standardPbId = [SELECT Id FROM Pricebook2 WHERE IsStandard=true].Id;
    }    
    public Database.QueryLocator start(Database.BatchableContext bc){
        return Database.getQueryLocator([SELECT Id, NATT_QuantityFrom__c,NATT_Product__c,NATT_Product__r.NATT_P_N__c,NATT_ListPrice__c,NATT_CustomerNumber__c
                                         FROM NATT_ItemPriceStaging__c 
                                         WHERE NATT_QuantityFrom__c>1 
                                         AND NATT_EffectiveDate__c<=TODAY AND NATT_ExpiryDate__c>=TODAY
                                         AND NATT_Product__c!=''
                                         AND NATT_CustomerNumber__c=0
                                         AND RecordType.DeveloperName IN ('NATT_PPG','NATT_TES')
                                         ORDER BY NATT_Product__c]);
    }
    public void execute(Database.BatchableContext bc, List<NATT_ItemPriceStaging__c> scope){
		Map<Id,List<Integer>> productSizeMap = new Map<Id,List<Integer>>();        
        Map<Id,Map<Decimal,Decimal>> productToQtyListPriceMap = new Map<Id,Map<Decimal,Decimal>>();        
        
        for(NATT_ItemPriceStaging__c ip : scope){                        
            if(!productToQtyListPriceMap.containsKey(ip.NATT_Product__c)){
                productToQtyListPriceMap.put(ip.NATT_Product__c,new Map<Decimal,Decimal>());
            }
            productToQtyListPriceMap.get(ip.NATT_Product__c).put(ip.NATT_QuantityFrom__c,ip.NATT_ListPrice__c);
            if(!productSizeMap.containsKey(ip.NATT_Product__c)){
                productSizeMap.put(ip.NATT_Product__c,new List<Integer>());
            }
            productSizeMap.get(ip.NATT_Product__c).add(Integer.valueOf(ip.NATT_QuantityFrom__c));
            
        }
        
        Map<Id,Map<Id,PricebookEntry>> productToPbMap = new Map<Id,Map<Id,PricebookEntry>>();
        Set<String> pasNameSet = new Set<String>();
        for(PricebookEntry pbe : [SELECT Id, UnitPrice,Pricebook2.Name,Product2Id,Pricebook2Id,Product2.Name,Product2.NATT_P_N__c FROM PricebookEntry WHERE Product2Id IN :productToQtyListPriceMap.keySet()]){
            if(!productToPbMap.containsKey(pbe.Product2Id)){
                productToPbMap.put(pbe.Product2Id,new Map<Id,PricebookEntry>());
            }
            productToPbMap.get(pbe.Product2Id).put(pbe.Pricebook2Id,pbe);
            pasNameSet.add(pbe.Pricebook2.Name+'-'+pbe.Product2.NATT_P_N__c);
        }
        
        //check to see if the PAS exists
        Map<String,PriceAdjustmentSchedule> pasMap = new Map<String,PriceAdjustmentSchedule>();
        for(PriceAdjustmentSchedule pas : [SELECT Id,Name FROM PriceAdjustmentSchedule WHERE Name IN :pasNameSet]){
            pasMap.put(pas.Name,pas);
        }
        
        for(String pasName : pasNameSet){
            if(!pasMap.containsKey(pasName)){
                pasMap.put(pasName,new PriceAdjustmentSchedule(Name=pasName,IsActive=false,AdjustmentMethod='Range'));
            }
        }
        for(PriceAdjustmentSchedule pas : pasMap.values()){
            pas.IsActive=false;
        }
        upsert pasMap.values() Id;
        pasMap.clear();
        
        Map<Id,Map<Decimal, PriceAdjustmentTier>> patMap = new Map<Id,Map<Decimal,PriceAdjustmentTier>>();
        Set<String> pbeAdjustmentSet = new Set<String>();
        //query for the price adjustment schedules so we can grab related tiers and adjustments
        for(PriceAdjustmentSchedule pas : [SELECT Id,Name,IsActive,(SELECT Id,LowerBound,TierValue FROM PriceAdjustmentTiers),(SELECT Id,PriceAdjustmentScheduleId, PricebookEntryId FROM PricebookEntryAdjustments) FROM PriceAdjustmentSchedule WHERE Name in :pasNameSet]){
            pasMap.put(pas.Name,pas);
            if(!patMap.containsKey(pas.Id)){
                patMap.put(pas.Id,new Map<Decimal,PriceAdjustmentTier>());
            }
            for(PriceAdjustmentTier pat : pas.PriceAdjustmentTiers){
            	patMap.get(pas.Id).put(pat.LowerBound,pat);
            }
            
            for(PricebookEntryAdjustment adj : pas.PricebookEntryAdjustments){               
                pbeAdjustmentSet.add(adj.PriceAdjustmentScheduleId+':'+adj.PricebookEntryId);
            }
        }
        //System.debug('patMap:'+patMap);
        
        
        List<PriceAdjustmentTier> patList = new List<PriceAdjustmentTier>();
        List<PricebookEntryAdjustment> pbeAdjList = new List<PricebookEntryAdjustment>();
        //now that the schedule is created, check the tier creation
        decimal tierVal,discount,standardPrice,currentPbDiscountPrice;
        for(NATT_ItemPriceStaging__c ip : scope){
            //get all the pricebooks that the product belongs to and apply quantity breaks
            if(productToPbMap.containsKey(ip.NATT_Product__c)){                
                //we are getting the standard pb price so we can calculate the discount given
                if(productToPbMap.get(ip.NATT_Product__c).containsKey(standardPbId)){
                    standardPrice=productToPbMap.get(ip.NATT_Product__c).get(standardPbId).UnitPrice;
                    //discount=(productToPbMap.get(ip.NATT_Product__c).get(standardPbId).UnitPrice - ip.NATT_ListPrice__c)/productToPbMap.get(ip.NATT_Product__c).get(standardPbId).UnitPrice;
                    //System.debug('discount:'+discount);                    
                }else{
                    continue;
                }
                for(PricebookEntry pbe : productToPbMap.get(ip.NATT_Product__c).values()){
                    
                    currentPbDiscountPrice=productToPbMap.get(ip.NATT_Product__c).get(pbe.Pricebook2Id).UnitPrice;
                    discount=((standardPrice-currentPbDiscountPrice)/standardPrice);
                    System.debug('pb:'+pbe.Pricebook2.Name+'standardPrice:'+standardPrice+' currentPbDiscountPrice:'+currentPbDiscountPrice+' discount:'+discount);                    
                    if(pasMap.containsKey(pbe.Pricebook2.Name+'-'+pbe.Product2.NATT_P_N__c)){
                        System.debug('inside pas map: '+pbe.Pricebook2.Name+' ip.NATT_ListPrice__c:'+ip.NATT_ListPrice__c+' pbe.UnitPrice:'+pbe.UnitPrice);
                        PriceAdjustmentSchedule pas = pasMap.get(pbe.Pricebook2.Name+'-'+pbe.Product2.NATT_P_N__c);
                        if(pbe.Pricebook2Id==standardPbId){
                            tierVal=(pbe.UnitPrice - ip.NATT_ListPrice__c);
                        }else{
                        	tierVal=(standardPrice-ip.NATT_ListPrice__c)*(1-discount);
                        }
                        if(pas.PriceAdjustmentTiers.isEmpty()){
                            System.debug('pas empty so adding for lowerBound:'+ip.NATT_QuantityFrom__c+'tiervalue:'+tierVal);
                            PriceAdjustmentTier pat = new PriceAdjustmentTier(PriceAdjustmentScheduleId=pas.Id,LowerBound=ip.NATT_QuantityFrom__c,TierType='AdjustmentAmount',TierValue=tierVal);
                            Integer loopCount=0;                                                            
                            List<Integer> breakList = productSizeMap.get(pbe.Product2Id);                           
                            breakList.sort();
                            for(Integer breakPoint : breakList){
                                if(ip.NATT_QuantityFrom__c==breakPoint){
                                    if((loopCount+1)<breakList.size()){
                                        pat.UpperBound=(breakList.get(loopCount+1)-1);
                                    }
                                }
                                loopCount++;
                            }
                            patList.add(pat);
                        }
                        else{
                            for(PriceAdjustmentTier pat : pas.PriceAdjustmentTiers){
                                if(patMap.containsKey(pas.Id)){
                                    Decimal qtyFrom = Decimal.valueOf(Integer.valueOf(ip.NATT_QuantityFrom__c));
                                    //System.debug('qtyFrom:'+qtyFrom);
                                    if(patMap.get(pas.Id).containsKey(qtyFrom)){
                                        PriceAdjustmentTier paTier = patMap.get(pas.Id).get(qtyFrom);
                                        //System.debug('contained key:'+qtyFrom);
                                        if(paTier.TierValue != tierVal){                                            
                                            paTier.TierValue=tierVal;
                                            //System.debug('tier value was not equal adding pat:'+paTier);
                                            patList.add(paTier);
                                        }
                                    }else{
                                        //System.debug('key not found:'+qtyFrom+' for pas:'+pas.Id);
                                        patList.add(new PriceAdjustmentTier(PriceAdjustmentScheduleId=pas.Id,LowerBound=ip.NATT_QuantityFrom__c,TierType='AdjustmentAmount',TierValue=tierVal));
                                    }
                                }                                
                            }
                        }
                                           
                        if(!pbeAdjustmentSet.contains(pas.Id+':'+pbe.Id)){
                            pbeAdjList.add(new PricebookEntryAdjustment(PriceAdjustmentScheduleId=pas.Id,PricebookEntryId=pbe.Id));
                        }
                        
                    }
                }
            }
            /*
            */
        }
        
        
        if(!patList.isEmpty()){
            //for(PriceAdjustmentTier pat : patList)
            //	System.debug('pat:'+pat);
            upsert patList Id;
        }
        if(!pbeAdjList.isEmpty()){
            //System.debug('pbeAdjList:'+pbeAdjList);
            List<Database.SaveResult> srList = Database.Insert(pbeAdjList,false);
            integer loopCount=0;
            for(Database.SaveResult sr : srList){
                if(!sr.isSuccess()){
                    System.debug('failed:'+pbeAdjList.get(loopCount)+sr.getErrors().get(0).getMessage());
                }
                loopCount++;
            }
        }
        
        for(PriceAdjustmentSchedule pas :pasMap.values()){
            if(!pas.IsActive){
                pas.IsActive=true;
            }
        }
        upsert pasMap.values();
    }
    /*
    @TestVisible
    private void sendMessage(String errorMsg){
        Messaging.SingleEmailMessage message = new Messaging.SingleEmailMessage();                
        message.toAddresses = new String[] { 'NATT-B2B-SF@carrier.com' };                
        message.subject = 'NattBatchQuantityBreak Failure';
        message.htmlBody = errorMsg;
        Messaging.SingleEmailMessage[] messages = 
            new List<Messaging.SingleEmailMessage> {message};
                Messaging.SendEmailResult[] results = Messaging.sendEmail(messages);
        if (results[0].success) {
            System.debug('The email was sent successfully.');
        } else {
            System.debug('The email failed to send: ' + results[0].errors[0].message);
        }
    }*/

    public void finish(Database.BatchableContext bc){
        List<WebStore> wsList = new List<WebStore>([SELECT Id,Name FROM WebStore WHERE Name in ('Performance Parts','TES Storefront')]);
        if(!wsList.isEmpty()){            
            ConnectApi.CommerceSearchSettings.createCommerceSearchIndex(wsList.get(0).Id);
            if(wsList.get(1)!=null){
                ConnectApi.CommerceSearchSettings.createCommerceSearchIndex(wsList.get(1).Id);
            }
        }
    }
}