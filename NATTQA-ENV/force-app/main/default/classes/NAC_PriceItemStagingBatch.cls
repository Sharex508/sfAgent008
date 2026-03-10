public class NAC_PriceItemStagingBatch implements Database.Batchable<sObject>, Database.Stateful{
    
    Id standardPbId = Test.isRunningTest() ? Test.getStandardPricebookId() : [SELECT Id, Name FROM Pricebook2 WHERE IsStandard=true].Id;
    Id strikeThroughPbId = [SELECT Id FROM Pricebook2 WHERE Name =: Label.NAOCAP_Strikethrough_Price_Book].Id;
    Id storeId = [SELECT Id FROM WebStore WHERE Name =: Label.NAOCAP_Store_Name].Id;
    List<String> internalCustomerGroup = Label.NAOCAP_Internal_Customer_Group.split(','), externalCustomerGroup = Label.NAOCAP_External_Customer_Group.split(',');
    List<WebStoreBuyerGroup> validBuyerGroupList  = new List<WebStoreBuyerGroup>([SELECT BuyerGroupId from WebStoreBuyerGroup WHERE WebStore.Name =: Label.NAOCAP_Store_Name]);
    string internalEntitlementPolicyName = Label.NAOCAP_Internal_Commerce_Entitlement_Policy, externalEntitlementPolicyName = Label.NAOCAP_External_Commerce_Entitlement_Policy, prefix = Label.NAOCAP_Prefix;
    
    public Database.QueryLocator start(Database.BatchableContext bc){
        return Database.getQueryLocator([SELECT Id, NATT_CustomerNumber__c, NATT_EffectiveDate__c, NATT_ItemPriceType__c, NATT_ListPrice__c, NATT_QuantityFrom__c, NATT_Product__c, NATT_Product__r.NATT_UnitCost__c
                                         FROM NATT_ItemPriceStaging__c WHERE RecordType.DeveloperName = 'NAOCAP' AND NATT_EffectiveDate__c <= TODAY AND NATT_ExpiryDate__c >= TODAY AND NATT_Product__c != '' 
                                         AND NAOCAP_Under_Processing__c = true AND NATT_Product__r.NATT_Branch_Plant_Warehouse__c = 'ATL' ORDER BY NATT_CustomerNumber__c DESC, NATT_QuantityFrom__c ASC]);
    }
    
    public void execute(Database.BatchableContext bc, List<NATT_ItemPriceStaging__c> scope){
        List<String> policyNameList = new List<String>();
        Map<Id, Account> accIdMap = new Map<Id, Account>();
        List<Product2> updateProdList = new List<Product2>();
        Map<String, Id> policyNameIdMap = new Map<String, Id>();
        List<BuyerAccount> upsertBuyerAcc = new List<BuyerAccount>();
        Map<Id,BuyerAccount> buyerAccMap = new Map<Id,BuyerAccount>();
        Map<String, String> customerNumberMap = new Map<String, String>();
        Map<Id,PricebookEntry> nacStorePbeMap = new Map<Id,PricebookEntry>();
        Map<String, Account> customerNumberAccountMap = new Map<String, Account>();
        List<PricebookEntry> upsertPriceBookEntryList = new List<PricebookEntry>();
        Map<String,Set<Id>> buyerGroupToAccountMemberMap = new Map<String,Set<Id>>();
        List<BuyerGroupMember> upsertBuyerGroupMembers = new List<BuyerGroupMember>();
        List<WebStoreBuyerGroup> insertWebStoreBuyerGroup = new List<WebStoreBuyerGroup>();
        List<BuyerGroupPricebook> upsertBuyerGroupPricebookList = new List<BuyerGroupPricebook>();
        List<NATT_ItemPriceStaging__c> updateItemPriceStagingList = new List<NATT_ItemPriceStaging__c>();
        Map<Id, List<BuyerGroupPricebook>> priceBook2BuyerGroupMap = new Map<Id, List<BuyerGroupPricebook>>();
        List<CommerceEntitlementBuyerGroup> insertEntitlementBuyerGroupList = new List<CommerceEntitlementBuyerGroup>();
        Map<String, Pricebook2> upsertpbMap = new Map<String, Pricebook2>(), existingPbNameMap = new Map<String, Pricebook2>();
        Map<String, BuyerGroup> buyerGroupMap = new Map<String, BuyerGroup>(), upsertBuyerGroupMap = new Map<String, BuyerGroup>();
        Map<String, Map<String, Map<String, PricebookEntry>>> customerNumPriceBookIdProdPricebookEntryMap = new Map<String, Map<String, Map<String, PricebookEntry>>>();
        Set<Id> prodIdSet = new Set<Id>(), nacPbAdded = new Set<Id>(), buyerGroupTaggedtoEntitlementId = new Set<Id>(), validBuyerGroupId = new Set<Id>(), priceBookIdSet = new Set<Id>(), prodIdSetWithStdPb = new Set<Id>();
        
        for(NATT_ItemPriceStaging__c ip : scope){
            if((ip.NATT_ItemPriceType__c == 'CLP' && ip.NATT_QuantityFrom__c == 1) || ip.NATT_ItemPriceType__c == 'INTPRC'){
                prodIdSet.add(ip.NATT_Product__c);
                if(ip.NATT_CustomerNumber__c > 0){
                    customerNumberMap.put(prefix + String.valueOf(Integer.valueOf(ip.NATT_CustomerNumber__c)), String.valueOf(Integer.valueOf(ip.NATT_CustomerNumber__c)));
                }
            }
        }
        if(!prodIdSet.isEmpty()){
            //Get the products which has entry in our Strike through pricebook and standard pricebook
            for(PricebookEntry pbe : [SELECT Id, Pricebook2Id, Product2Id, CurrencyIsoCode, UnitPrice, Pricebook2.Name FROM PricebookEntry WHERE Product2Id in :prodIdSet AND CurrencyIsoCode = 'USD' AND (Pricebook2Id =: strikeThroughPbId OR Pricebook2Id =: standardPbId)]){
                if(pbe.Pricebook2Id == strikeThroughPbId){
                    nacStorePbeMap.put(pbe.Product2Id,pbe);
                }else if(pbe.Pricebook2Id == standardPbId){
                    prodIdSetWithStdPb.add(pbe.Product2Id);
                }
            }
        }
        if(!customerNumberMap.keySet().isEmpty()){
            for(WebStoreBuyerGroup webBuyerGroup : validBuyerGroupList){
                validBuyerGroupId.add(webBuyerGroup.BuyerGroupId);
            }
            for(Account acc : [SELECT Id, Name, CONTAINER_JDE_Bill_To_Code__c, CONTAINER_Customer_Group__c FROM Account WHERE CONTAINER_JDE_Bill_To_Code__c IN : customerNumberMap.values()]){
                customerNumberAccountMap.put(prefix + acc.CONTAINER_JDE_Bill_To_Code__c, acc);
                accIdMap.put(acc.Id, acc);
            }
            //Check if the Buyer Group exists for this customer
            for(BuyerGroup bg: [SELECT Id, Name, NAC_Type__c FROM BuyerGroup WHERE Name in :customerNumberMap.keySet() AND Id IN : validBuyerGroupId]){
                buyerGroupMap.put(bg.Name,bg);
            }
            for(String bgName : customerNumberMap.keySet()){
                if(!upsertBuyerGroupMap.containsKey(bgName)){
                    if(!buyerGroupMap.containsKey(bgName)){
                        //If Buyer Group does not exist, create them.
                        //CONTAINER_Customer_Group__c defines what type of customer it is. C3,C5,C7,C11,V1H,V1K
                        if(customerNumberAccountMap.containsKey(bgName) && customerNumberAccountMap.get(bgName).CONTAINER_Customer_Group__c != null && (externalCustomerGroup.contains(customerNumberAccountMap.get(bgName).CONTAINER_Customer_Group__c) || internalCustomerGroup.contains(customerNumberAccountMap.get(bgName).CONTAINER_Customer_Group__c))){
                            upsertBuyerGroupMap.put(bgName, new BuyerGroup(Name = bgName, NAC_Type__c = customerNumberAccountMap.get(bgName).CONTAINER_Customer_Group__c));
                        }else{
                            upsertBuyerGroupMap.put(bgName, new BuyerGroup(Name = bgName));
                        }
                    }else if(customerNumberAccountMap.containsKey(bgName) && customerNumberAccountMap.get(bgName).CONTAINER_Customer_Group__c != null && customerNumberAccountMap.get(bgName).CONTAINER_Customer_Group__c != buyerGroupMap.get(bgName).NAC_Type__c && (externalCustomerGroup.contains(customerNumberAccountMap.get(bgName).CONTAINER_Customer_Group__c) || internalCustomerGroup.contains(customerNumberAccountMap.get(bgName).CONTAINER_Customer_Group__c))){
                        upsertBuyerGroupMap.put(bgName, new BuyerGroup(Id = buyerGroupMap.get(bgName).Id, NAC_Type__c = customerNumberAccountMap.get(bgName).CONTAINER_Customer_Group__c));
                    }
                }
            }
            upsert upsertBuyerGroupMap.values();
            //Link the newly created Buyer Group to the NA Container Marketplace store
            for(BuyerGroup bg : upsertBuyerGroupMap.values()){
                insertWebStoreBuyerGroup.add(new WebStoreBuyerGroup(BuyerGroupId = bg.Id, WebStoreId = storeId));
                buyerGroupMap.put(bg.Name, bg);
            }
            if(!insertWebStoreBuyerGroup.isEmpty()){
                insert insertWebStoreBuyerGroup;
            }
            //Check if the customers are enabled as Buyer
            for(BuyerAccount buyerAcc : [SELECT Id, BuyerId, IsActive FROM BuyerAccount WHERE BuyerId IN: accIdMap.keySet()]){
                buyerAccMap.put(buyerAcc.BuyerId, buyerAcc);
            }
            //If the customer are not enabled as Buyer or they are not Active, create/update them
            for(Id accIds : accIdMap.keySet()){
                if(buyerAccMap.containsKey(accIds) && !buyerAccMap.get(accIds).IsActive){
                    buyerAccMap.get(accIds).IsActive = true;
                    upsertBuyerAcc.add(buyerAccMap.get(accIds));
                }else if(!buyerAccMap.containsKey(accIds)){
                    upsertBuyerAcc.add(new BuyerAccount(BuyerId = accIds, BuyerStatus = 'Active', IsActive = TRUE, Name = accIdMap.get(accIds).Name));
                }
            }
            if(!upsertBuyerAcc.isEmpty()){
                upsert upsertBuyerAcc;
                for(BuyerAccount buyerAcc : upsertBuyerAcc){
                    buyerAccMap.put(buyerAcc.BuyerId, buyerAcc);
                }
            }
            //Get a list of all Buyer Group Members associated with a particular Buyer Group
            for(BuyerGroupMember bgMembers : [SELECT Id, BuyerId, BuyerGroup.Name FROM BuyerGroupMember WHERE BuyerId IN : accIdMap.keySet() AND BuyerGroup.Name IN : buyerGroupMap.keySet()]){
                if(!buyerGroupToAccountMemberMap.containsKey(bgMembers.BuyerGroup.Name)){
                    buyerGroupToAccountMemberMap.put(bgMembers.BuyerGroup.Name, new Set<Id>());
                }
                buyerGroupToAccountMemberMap.get(bgMembers.BuyerGroup.Name).add(bgMembers.BuyerId);
            }
            policyNameList.add(internalEntitlementPolicyName);
            policyNameList.add(externalEntitlementPolicyName);
            //Check if the Buyer Group are associated with a Entitlement Policy
            for(CommerceEntitlementBuyerGroup ceBuyerGroup : [SELECT Id, PolicyId, Policy.Name, BuyerGroupId FROM CommerceEntitlementBuyerGroup WHERE Policy.Name IN: policyNameList AND BuyerGroupId IN : validBuyerGroupId]){
                policyNameIdMap.put(ceBuyerGroup.Policy.Name,ceBuyerGroup.PolicyId);
                buyerGroupTaggedtoEntitlementId.add(ceBuyerGroup.BuyerGroupId);
            }
            for(String customerNumber : buyerGroupMap.keySet()){
                if(customerNumberAccountMap.containsKey(customerNumber)){
                    //Depending on the CONTAINER_Customer_Group__c associate the Buyer Group with either Interanl or External Entitlement Policy
                    if(!buyerGroupTaggedtoEntitlementId.contains(buyerGroupMap.get(customerNumber).Id) && (internalCustomerGroup.contains(customerNumberAccountMap.get(customerNumber).CONTAINER_Customer_Group__c) || externalCustomerGroup.contains(customerNumberAccountMap.get(customerNumber).CONTAINER_Customer_Group__c))){
                        Id policyId = internalCustomerGroup.contains(customerNumberAccountMap.get(customerNumber).CONTAINER_Customer_Group__c) ? policyNameIdMap.get(internalEntitlementPolicyName) : externalCustomerGroup.contains(customerNumberAccountMap.get(customerNumber).CONTAINER_Customer_Group__c) ? policyNameIdMap.get(externalEntitlementPolicyName) : null;
                        if(String.isNotBlank(policyId)){
                            insertEntitlementBuyerGroupList.add(new CommerceEntitlementBuyerGroup(BuyerGroupId = buyerGroupMap.get(customerNumber).Id, PolicyId = policyId));
                        }
                    }
                    //Associate the Account as the Buyer Group Member
                    if(buyerAccMap.containsKey(customerNumberAccountMap.get(customerNumber).Id) && (!buyerGroupToAccountMemberMap.containsKey(customerNumber) || (buyerGroupToAccountMemberMap.containsKey(customerNumber) && !buyerGroupToAccountMemberMap.get(customerNumber).contains(customerNumberAccountMap.get(customerNumber).Id)))){
                        upsertBuyerGroupMembers.add(new BuyerGroupMember (BuyerId = customerNumberAccountMap.get(customerNumber).Id, BuyerGroupId = buyerGroupMap.get(customerNumber).Id));
                    }
                }
            }
            if(!upsertBuyerGroupMembers.isEmpty()){
                insert upsertBuyerGroupMembers;
            }
            if(!insertEntitlementBuyerGroupList.isEmpty()){
                insert insertEntitlementBuyerGroupList;
            }
            //Check if the Buyer Group are associated with customer specific pricebook
            for(BuyerGroupPricebook bgPriceBook : [SELECT Id, IsActive, Pricebook2Id, Pricebook2.Name, Pricebook2.IsActive FROM BuyerGroupPricebook WHERE Pricebook2.Name IN : buyerGroupMap.keySet() AND BuyerGroupId IN : validBuyerGroupId]){
                existingPbNameMap.put(bgPriceBook.Pricebook2.Name, new Pricebook2(Id = bgPriceBook.Pricebook2Id, Name = bgPriceBook.Pricebook2.Name, IsActive = bgPriceBook.Pricebook2.IsActive));
                priceBookIdSet.add(bgPriceBook.Pricebook2Id);
                if(!priceBook2BuyerGroupMap.containsKey(bgPriceBook.Pricebook2Id)){
                    priceBook2BuyerGroupMap.put(bgPriceBook.Pricebook2Id, new List<BuyerGroupPricebook>());
                }
                priceBook2BuyerGroupMap.get(bgPriceBook.Pricebook2Id).add(bgPriceBook);
            }
            //If the customer are not associated with customer specific pricebook or they are not Active, create/update them
            for(String customerNumber : buyerGroupMap.keySet()){
                if(!existingPbNameMap.containsKey(customerNumber)){
                    upsertpbMap.put(customerNumber, new Pricebook2(Name = customerNumber, IsActive = true));
                }else if(!existingPbNameMap.get(customerNumber).IsActive){
                    upsertpbMap.put(customerNumber, new Pricebook2(Id = existingPbNameMap.get(customerNumber).Id, IsActive = true));
                }
            }
            upsert upsertpbMap.values() Id;
            existingPbNameMap.putAll(upsertpbMap);
            for(Pricebook2 pb : upsertpbMap.values()){
                priceBookIdSet.add(pb.Id);
            }
            //Associate the pricebook with the Buyer Group
            if(!existingPbNameMap.isEmpty()){
                for(String customerNumber : existingPbNameMap.keySet()){
                    Id priceBookId = existingPbNameMap.get(customerNumber).Id;
                    if(priceBook2BuyerGroupMap.containsKey(priceBookId)){
                        for(BuyerGroupPricebook bgPricebook : priceBook2BuyerGroupMap.get(priceBookId)){
                            if(!bgPricebook.IsActive){
                                upsertBuyerGroupPricebookList.add(new BuyerGroupPricebook(Id = bgPricebook.Id, IsActive = true));
                            }
                        }
                    }else{
                        if(buyerGroupMap.containsKey(customerNumber)){
                            upsertBuyerGroupPricebookList.add(new BuyerGroupPricebook(IsActive = true, Pricebook2Id = priceBookId, BuyerGroupId = buyerGroupMap.get(customerNumber).Id));
                        }
                    }
                }
                if(!upsertBuyerGroupPricebookList.isEmpty()){
                    upsert upsertBuyerGroupPricebookList Id;
                }
            }
            //Get customer specific pricebook entries
            for(Pricebook2 pb : [SELECT Id, Name, (SELECT Id, Product2Id, UnitPrice FROM PricebookEntries WHERE Product2Id IN: prodIdSet AND CurrencyIsoCode = 'USD') FROM Pricebook2 WHERE Id IN: priceBookIdSet]){
                if(!customerNumPriceBookIdProdPricebookEntryMap.containsKey(pb.Name)){
                    customerNumPriceBookIdProdPricebookEntryMap.put(pb.Name, new Map<String, Map<String, PricebookEntry>>{pb.Id => new Map<String, PricebookEntry>()});
                }
                for(PricebookEntry pbe : pb.PricebookEntries){
                    if(!customerNumPriceBookIdProdPricebookEntryMap.get(pb.Name).get(pb.Id).containsKey(pbe.Product2Id)){
                        customerNumPriceBookIdProdPricebookEntryMap.get(pb.Name).get(pb.Id).put(pbe.Product2Id, pbe);
                    }  
                }
            }
        }
        for(NATT_ItemPriceStaging__c ip : scope){
            boolean processed = false;
            if((ip.NATT_ItemPriceType__c == 'CLP' && ip.NATT_QuantityFrom__c == 1) || ip.NATT_ItemPriceType__c == 'INTPRC'){
                if(ip.NATT_CustomerNumber__c == 0){
                    //If the type is CLP and customer number is 0, create/update the strike through pricebook entry with the List Price 
                    if(ip.NATT_ItemPriceType__c == 'CLP' && ip.NATT_QuantityFrom__c == 1){
                        if(nacStorePbeMap.containsKey(ip.NATT_Product__c) && nacStorePbeMap.get(ip.NATT_Product__c).UnitPrice != ip.NATT_ListPrice__c && !nacPbAdded.contains(ip.NATT_Product__c)){
                            if(!prodIdSetWithStdPb.contains(ip.NATT_Product__c)){
                                upsertPriceBookEntryList.add(new PricebookEntry(Pricebook2Id = standardPbId, CurrencyIsoCode = 'USD', Product2Id = ip.NATT_Product__c, UnitPrice = 0, IsActive = true)); 
                            }
                            upsertPriceBookEntryList.add(new PricebookEntry(Id = nacStorePbeMap.get(ip.NATT_Product__c).Id, UnitPrice = ip.NATT_ListPrice__c, IsActive = true, NATT_Effective_Date__c = ip.NATT_EffectiveDate__c));
                            nacPbAdded.add(ip.NATT_Product__c);
                            processed = true;
                        }else if (!nacStorePbeMap.containsKey(ip.NATT_Product__c) && !nacPbAdded.contains(ip.NATT_Product__c)){
                            if(!prodIdSetWithStdPb.contains(ip.NATT_Product__c)){
                                upsertPriceBookEntryList.add(new PricebookEntry(Pricebook2Id = standardPbId, CurrencyIsoCode = 'USD', Product2Id = ip.NATT_Product__c, UnitPrice = 0, IsActive = true)); 
                            }
                            upsertPriceBookEntryList.add(new PricebookEntry(Pricebook2Id = strikeThroughPbId, CurrencyIsoCode = 'USD', Product2Id = ip.NATT_Product__c, UnitPrice = ip.NATT_ListPrice__c, IsActive = true, NATT_Effective_Date__c = ip.NATT_EffectiveDate__c));
                            nacPbAdded.add(ip.NATT_Product__c);
                            processed = true;
                        }
                    }
                    //If the type is INTPRC, this indicates this is the Unit Cost price of the product and this needs to be stored in the NATT_UnitCost__c of the product
                    else if((ip.NATT_ItemPriceType__c == 'INTPRC') && ip.NATT_Product__r.NATT_UnitCost__c != ip.NATT_ListPrice__c){
                        updateProdList.add(new Product2(Id = ip.NATT_Product__c, NATT_UnitCost__c = ip.NATT_ListPrice__c, IsActive = true));
                        processed = true;
                    }
                }
                //If the customer number is greater than 0 indicating its a customer specific List Price
                //create/update the customer specific pricebook entry with the NAOCAP_Customer_List_Price__c as inactive
                else if(ip.NATT_CustomerNumber__c > 0){
                    if(customerNumPriceBookIdProdPricebookEntryMap.containsKey(prefix + String.valueOf(Integer.valueOf(ip.NATT_CustomerNumber__c)))){
                        for(String pbId : customerNumPriceBookIdProdPricebookEntryMap.get(prefix + String.valueOf(Integer.valueOf(ip.NATT_CustomerNumber__c))).keySet()){
                            if(customerNumPriceBookIdProdPricebookEntryMap.get(prefix + String.valueOf(Integer.valueOf(ip.NATT_CustomerNumber__c))).containsKey(pbId)){
                                boolean activatePrice = ip.NATT_ItemPriceType__c == 'INTPRC' ? true : false;
                                if(customerNumPriceBookIdProdPricebookEntryMap.get(prefix + String.valueOf(Integer.valueOf(ip.NATT_CustomerNumber__c))).get(pbId).containsKey(ip.NATT_Product__c)){
                                    upsertPriceBookEntryList.add(new PricebookEntry(Id = customerNumPriceBookIdProdPricebookEntryMap.get(prefix + String.valueOf(Integer.valueOf(ip.NATT_CustomerNumber__c))).get(pbId).get(ip.NATT_Product__c).Id, CurrencyIsoCode = 'USD', UnitPrice = ip.NATT_ListPrice__c, NAOCAP_Customer_List_Price__c = ip.NATT_ListPrice__c, IsActive = activatePrice, NATT_Effective_Date__c = ip.NATT_EffectiveDate__c));
                                    processed = true;
                                }else{
                                    if(!prodIdSetWithStdPb.contains(ip.NATT_Product__c)){
                                        upsertPriceBookEntryList.add(new PricebookEntry(Pricebook2Id = standardPbId, CurrencyIsoCode = 'USD', Product2Id = ip.NATT_Product__c, UnitPrice = 0, IsActive = true)); 
                                    }
                                    upsertPriceBookEntryList.add(new PricebookEntry(Pricebook2Id = pbId, CurrencyIsoCode = 'USD', Product2Id = ip.NATT_Product__c, UnitPrice = ip.NATT_ListPrice__c, NAOCAP_Customer_List_Price__c = ip.NATT_ListPrice__c, IsActive = activatePrice, NATT_Effective_Date__c = ip.NATT_EffectiveDate__c));
                                    processed = true;
                                }
                            }
                        } 
                    }
                }
            }
            if(processed){
                updateItemPriceStagingList.add(new NATT_ItemPriceStaging__c(Id = ip.Id, NAOCAP_Under_Processing__c = false));
            }
        }
        if(!updateProdList.isEmpty()){
            update updateProdList;
        }
        if(!upsertPriceBookEntryList.isEmpty()){
            upsert upsertPriceBookEntryList Id;
        }
        update updateItemPriceStagingList;
    }
    
    public void finish(Database.BatchableContext bc){
        if(!Test.isRunningTest()){
            Database.executeBatch(new NAC_PriceAdjustmentBatch(),1);
        }
    }
    
}