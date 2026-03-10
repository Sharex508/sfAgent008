public without sharing class PriceAdjustmentStagingTrgHandler {
	public static void onAfterInsert(Map<Id,NATT_PriceAdjustmentStaging__c> trgNewMap){
        Set<String> buyerGroupSet = new Set<String>();        
        
        List<NATT_PriceAdjustmentStaging__c> scope = trgNewMap.values();
        
        for(NATT_PriceAdjustmentStaging__c pas : scope){
            if(String.isNotBlank(pas.NATT_CustomerPriceGroup__c)){
            	buyerGroupSet.add(pas.NATT_CustomerPriceGroup__c);
            }
            else if(String.isNotBlank(String.valueOf(pas.NATT_CustomerNumber__c)) && pas.NATT_CustomerNumber__c!=0){
               buyerGroupSet.add(String.valueOf(pas.NATT_CustomerNumber__c));
            }
        }
		handleBuyerGroupSetup(buyerGroupSet);
    }
    
    public static void handleBuyerGroupSetup(Set<String> buyerGroupSet){
        Map<String,BuyerGroup> bgMap = new Map<String,BuyerGroup>();
        Map<String,BuyerGroup> bgInsertMap = new Map<String,BuyerGroup>();
        
        for(BuyerGroup bg: [SELECT Id,Name FROM BuyerGroup WHERE Name in :buyerGroupSet]){
            bgMap.put(bg.Name,bg);
        }
        
        for(String bgName : buyerGroupSet){
            if(!bgMap.containsKey(bgName) && !bgInsertMap.containsKey(bgName)){
               bgInsertMap.put(bgName,new BuyerGroup(Name=bgName));
            }
        }
        //if there are new buyer groups to add, create all the related objects for the PPG Store
        if(!bgInsertMap.isEmpty()){
            insert bgInsertMap.values();
            for(BuyerGroup bg : bgInsertMap.values()){
                bgMap.put(bg.Name,bg);
            }
            Set<Id> bgIdSet = new Set<Id>();
            for(BuyerGroup bg : bgMap.values()){
                bgIdSet.add(bg.Id);
            }
            //create a policy to view product and price
            Map<String,CommerceEntitlementPolicy> policyMap = new Map<String,CommerceEntitlementPolicy>();
            for(CommerceEntitlementPolicy policy : [SELECT Id,Name FROM CommerceEntitlementPolicy WHERE Name IN :buyerGroupSet]){
                policyMap.put(policy.Name,policy);
            }
            List<CommerceEntitlementPolicy> policyList = new List<CommerceEntitlementPolicy>();
            for(String bgName : bgMap.keySet()){
                if(!policyMap.containsKey(bgName)){
                    policyList.add(new CommerceEntitlementPolicy(Name=bgName,IsActive=true,CanViewPrice=true,CanViewProduct=true));                    
                }
            }
            if(!policyList.isEmpty()){
                insert policyList;
                for(CommerceEntitlementPolicy policy : policyList){
                    policyMap.put(policy.Name,policy);
                }
            }

            //link the buyer group with the policy
            Map<Id,CommerceEntitlementBuyerGroup> cebgMap = new Map<Id,CommerceEntitlementBuyerGroup>();
            for(CommerceEntitlementBuyerGroup cebg : [SELECT Id,BuyerGroupId FROM CommerceEntitlementBuyerGroup WHERE BuyerGroupId IN :bgIdSet AND PolicyId IN :policyMap.values()]){
                cebgMap.put(cebg.BuyerGroupId,cebg);
            }

            List<CommerceEntitlementBuyerGroup> entBuyerGroupList = new List<CommerceEntitlementBuyerGroup>();
            //variable to catch records that are in the same batch
            Set<Id> alreadyAddedSet = new Set<Id>();
            for(String bg : bgMap.keySet()){
                if(!cebgMap.containsKey(bgMap.get(bg).Id) && !alreadyAddedSet.contains(bgMap.get(bg).Id)){
                	entBuyerGroupList.add(new CommerceEntitlementBuyerGroup(BuyerGroupId=bgMap.get(bg).Id,PolicyId=policyMap.get(bg).Id));
                    alreadyAddedSet.add(bgMap.get(bg).Id);
                }
            }
            if(!entBuyerGroupList.isEmpty()){
            	insert entBuyerGroupList;
            }
            
            //create all related pricebooks by name
            Map<String,Pricebook2> pbMap = new Map<String,Pricebook2>();
            Map<String,Pricebook2> existingPbNameMap = new Map<String,Pricebook2>();
            for(Pricebook2 pb : [SELECT Id,IsActive,Name FROM Pricebook2 WHERE Name in :bgMap.keySet()]){
                existingPbNameMap.put(pb.Name,pb);
            }
            for(String bg : bgMap.keySet()){
                if(!existingPbNameMap.containsKey(bg)){
                    pbMap.put(bg,new Pricebook2(Name=bg,IsActive=true));
                }else if(!existingPbNameMap.get(bg).IsActive){
                    pbMap.put(bg,new Pricebook2(Id=existingPbNameMap.get(bg).Id,IsActive=true));
                }
            }
            upsert pbMap.values() Id;

            existingPbNameMap.putAll(pbMap);
            String key;
            if(!existingPbNameMap.isEmpty()){
                List<BuyerGroupPricebook> bgPbList = new List<BuyerGroupPricebook>();                
                Map<String,BuyerGroupPricebook> existingBgPbMap = new Map<String,BuyerGroupPricebook>();
                Set<Id> pbIdSet = new Set<Id>();
                for(Pricebook2 pb : existingPbNameMap.values()){
                    pbIdSet.add(pb.Id);
                }
                
                for(BuyerGroupPricebook bgpb : [SELECT Id,Pricebook2Id,BuyerGroupId,IsActive FROM BuyerGroupPricebook WHERE Pricebook2Id IN :pbIdSet]){
                    key = bgpb.BuyerGroupId+':'+bgpb.Pricebook2Id;
                    existingBgPbMap.put(key,bgpb);
                }

                for(Pricebook2 pb : existingPbNameMap.values()){
                    if(bgMap.containsKey(pb.Name)){
                        BuyerGroup bg = bgMap.get(pb.Name);
                        key = bg.Id+':'+pb.Id;
                        if(!existingBgPbMap.containsKey(key)){
                            bgPbList.add(new BuyerGroupPricebook(IsActive=true,Pricebook2Id=pb.Id,BuyerGroupId=bg.Id));
                        }else if(!existingBgPbMap.get(key).IsActive){
                            bgPbList.add(new BuyerGroupPricebook(Id=existingBgPbMap.get(key).Id,IsActive=true));
                        }
                    }
                }
                upsert bgPbList Id;
            }
        }
    }
}