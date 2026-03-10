public class NAC_PriceAdjustmentBatch implements Database.Batchable<sObject>, Database.Stateful{
    
    Id strikeThroughPbId = [SELECT Id FROM Pricebook2 WHERE Name =: Label.NAOCAP_Strikethrough_Price_Book].Id;
    List<String> internalCustomerGroup = Label.NAOCAP_Internal_Customer_Group.split(','), externalCustomerGroup = Label.NAOCAP_External_Customer_Group.split(',');
    List<WebStoreBuyerGroup> validBuyerGroupList  = new List<WebStoreBuyerGroup>([SELECT BuyerGroupId from WebStoreBuyerGroup WHERE WebStore.Name =: Label.NAOCAP_Store_Name]);
    string internalEntitlementPolicyName = Label.NAOCAP_Internal_Commerce_Entitlement_Policy, externalEntitlementPolicyName = Label.NAOCAP_External_Commerce_Entitlement_Policy, prefix = Label.NAOCAP_Prefix;
    
    public Database.QueryLocator start(Database.BatchableContext bc){
        return Database.getQueryLocator([SELECT Id, NATT_AdjustmentType__c, NATT_AdjustmentValue__c, NATT_CustomerNumber__c, NATT_CustomerPriceGroup__c, NATT_ItemPriceGroup__c FROM NATT_PriceAdjustmentStaging__c
                                         WHERE RecordType.DeveloperName = 'NAOCAP' AND NATT_EffectiveDate__c <= TODAY AND NATT_ExpiryDate__c >= TODAY AND NATT_Product__c = '']);
    }
    
    public void execute(Database.BatchableContext bc, List<NATT_PriceAdjustmentStaging__c> scope){
        Map<String,Id> priceBookNameMap = new Map<String,Id>();
        List<PricebookEntry> upsertPriceBookEntryList = new List<PricebookEntry>();
        Map<String, Set<String>> customerGroupToPriceBookEntryMap = new Map<String, Set<String>>();
        Set<Id> prodIdSet = new Set<Id>(), validBuyerGroupId = new Set<Id>(), accIdSet = new Set<Id>();
        Map<Id, PricebookEntry> prodIdToStrikeThroughPriceBookEntryMap = new Map<Id, PricebookEntry>();
        Map<String, List<Product2>> commerceEntitlementProductListMap = new Map<String, List<Product2>>();
        Map<String, Map<Id, PricebookEntry>> customerProdIdPricebookEntryMap = new Map<String, Map<Id, PricebookEntry>>();
        Set<String> priceBookNameSet = new Set<String>(), commerceEntitlementPolicyNameSet = new Set<String>(), itemPriceGroupSet = new Set<String>();

        for(WebStoreBuyerGroup webBuyerGroup : validBuyerGroupList){
            validBuyerGroupId.add(webBuyerGroup.BuyerGroupId);
        }
        //Customer specific Buyer Group & PriceBook have the same name 
        for(NATT_PriceAdjustmentStaging__c adjStage : scope){
            if(adjStage.NATT_CustomerNumber__c == 0){
                if(adjStage.NATT_AdjustmentType__c == 'REGD' && externalCustomerGroup.contains(adjStage.NATT_CustomerPriceGroup__c)){
                    priceBookNameSet.add(prefix + adjStage.NATT_CustomerPriceGroup__c);
                    commerceEntitlementPolicyNameSet.add(externalEntitlementPolicyName);
                    itemPriceGroupSet.add(adjStage.NATT_ItemPriceGroup__c);
                }else if(adjStage.NATT_AdjustmentType__c == 'SURCHG' && internalCustomerGroup.contains(adjStage.NATT_CustomerPriceGroup__c)){
                    priceBookNameSet.add(prefix + adjStage.NATT_CustomerPriceGroup__c);
                    commerceEntitlementPolicyNameSet.add(internalEntitlementPolicyName);
                    itemPriceGroupSet.add(adjStage.NATT_ItemPriceGroup__c);
                }
            }
        }
        //Get all the external customer specific buyer group
        for(BuyerGroupMember bgMembers : [SELECT Id, BuyerId, BuyerGroup.Name FROM BuyerGroupMember WHERE BuyerGroupId IN : validBuyerGroupId AND BuyerGroup.Name NOT IN : priceBookNameSet]){
            if(bgMembers.BuyerId.getSobjectType() == Schema.Account.SObjectType){
                accIdSet.add(bgMembers.BuyerId);
            }
        }
        for(Account acc : [SELECT Id, CONTAINER_Customer_Group__c, CONTAINER_JDE_Bill_To_Code__c FROM Account WHERE Id IN: accIdSet AND CONTAINER_Customer_Group__c IN: externalCustomerGroup AND CONTAINER_JDE_Bill_To_Code__c != null]){
            priceBookNameSet.add(prefix + acc.CONTAINER_JDE_Bill_To_Code__c);
            if(!customerGroupToPriceBookEntryMap.containsKey(acc.CONTAINER_Customer_Group__c)){
                customerGroupToPriceBookEntryMap.put(acc.CONTAINER_Customer_Group__c, new Set<String>());
            }
            customerGroupToPriceBookEntryMap.get(acc.CONTAINER_Customer_Group__c).add(prefix + acc.CONTAINER_JDE_Bill_To_Code__c);
        }
        //Get all the products related to our Entitlement Policy, and create a map with policy name and list of related products
        for(CommerceEntitlementPolicy cep : [SELECT Id, Name, (SELECT Id, ProductId, Product.NATT_UnitCost__c, Product.NATT_ItemPriceGroup__c FROM CommerceEntitlementProducts WHERE Product.NATT_Branch_Plant_Warehouse__c = 'ATL' AND Product.NATT_ItemPriceGroup__c IN : itemPriceGroupSet) FROM CommerceEntitlementPolicy WHERE ID IN (SELECT PolicyId FROM CommerceEntitlementBuyerGroup WHERE BuyerGroupId IN: validBuyerGroupId) AND NAME IN: commerceEntitlementPolicyNameSet]){
            if(!commerceEntitlementProductListMap.containsKey(cep.Name)){
                commerceEntitlementProductListMap.put(cep.Name, new List<Product2>());
            }
            for(CommerceEntitlementProduct entitlementProduct : cep.CommerceEntitlementProducts){
                prodIdSet.add(entitlementProduct.ProductId);
                commerceEntitlementProductListMap.get(cep.Name).add(new Product2(Id = entitlementProduct.ProductId, NATT_UnitCost__c = entitlementProduct.Product.NATT_UnitCost__c, NATT_ItemPriceGroup__c = entitlementProduct.Product.NATT_ItemPriceGroup__c));
            }
        }
        if(!prodIdSet.isEmpty()){
            for(BuyerGroupPricebook bgPriceBook : [SELECT Id, Pricebook2Id, Pricebook2.Name FROM BuyerGroupPricebook WHERE Pricebook2.Name IN : priceBookNameSet AND BuyerGroupId IN : validBuyerGroupId]){
                priceBookNameMap.put(bgPriceBook.Pricebook2.Name, bgPriceBook.Pricebook2Id);
            }
            //For strike through pricebook, create a map with product id and it's corresponding strike through pricebook entry
            //For other, create a map with pricebook name with map of product id and it's corresponding pricebook entry
            for(PricebookEntry pbe : [SELECT Id, Product2Id, UnitPrice, IsActive, NAOCAP_Customer_List_Price__c, Pricebook2Id, Pricebook2.Name FROM PricebookEntry WHERE (Pricebook2Id =: strikeThroughPbId OR Pricebook2Id IN: priceBookNameMap.values()) AND Product2Id IN: prodIdSet]){
                if(pbe.Pricebook2Id == strikeThroughPbId){
                    prodIdToStrikeThroughPriceBookEntryMap.put(pbe.Product2Id, pbe);
                }else{
                    if(customerProdIdPricebookEntryMap.containsKey(pbe.Pricebook2.Name)){
                        customerProdIdPricebookEntryMap.get(pbe.Pricebook2.Name).put(pbe.Product2Id, pbe);
                    }else{
                        customerProdIdPricebookEntryMap.put(pbe.Pricebook2.Name, new Map<Id, PricebookEntry>{pbe.Product2Id => pbe});
                    }
                }
            }
            for(NATT_PriceAdjustmentStaging__c adjStage : scope){
                if(adjStage.NATT_CustomerNumber__c == 0){
                    if(adjStage.NATT_AdjustmentType__c == 'REGD' && externalCustomerGroup.contains(adjStage.NATT_CustomerPriceGroup__c) && commerceEntitlementProductListMap.containsKey(externalEntitlementPolicyName)){
                        //Regular discount on external customer group
                        for(Product2 prod : commerceEntitlementProductListMap.get(externalEntitlementPolicyName)){
                            if(prodIdToStrikeThroughPriceBookEntryMap.containsKey(prod.Id) && prod.NATT_ItemPriceGroup__c == adjStage.NATT_ItemPriceGroup__c){
                                Decimal listPrice = prodIdToStrikeThroughPriceBookEntryMap.get(prod.Id).UnitPrice;
                                Decimal cost = listPrice + (listPrice * (adjStage.NATT_AdjustmentValue__c/100));
                                if(customerProdIdPricebookEntryMap.containsKey(prefix + adjStage.NATT_CustomerPriceGroup__c) && customerProdIdPricebookEntryMap.get(prefix + adjStage.NATT_CustomerPriceGroup__c).containsKey(prod.Id)){
                                    PricebookEntry pbe = customerProdIdPricebookEntryMap.get(prefix + adjStage.NATT_CustomerPriceGroup__c).get(prod.Id);
                                    if(pbe.UnitPrice != cost.setScale(2) || !pbe.IsActive){
                                        upsertPriceBookEntryList.add(new PricebookEntry(Id = pbe.Id, UnitPrice = cost.setScale(2), IsActive = true));
                                    }
                                }else{
                                    if(priceBookNameMap.containsKey(prefix + adjStage.NATT_CustomerPriceGroup__c)){
                                        upsertPriceBookEntryList.add(new PricebookEntry(Pricebook2Id = priceBookNameMap.get(prefix + adjStage.NATT_CustomerPriceGroup__c), CurrencyIsoCode = 'USD', Product2Id = prod.Id, UnitPrice = cost.setScale(2), IsActive = true));
                                    }
                                }
                            }
                        }
                        //Customer specific discount
                        if(customerGroupToPriceBookEntryMap.containsKey(adjStage.NATT_CustomerPriceGroup__c)){
                            for(String customerGroup : customerGroupToPriceBookEntryMap.get(adjStage.NATT_CustomerPriceGroup__c)){
                                for(Product2 prod : commerceEntitlementProductListMap.get(externalEntitlementPolicyName)){
                                    if(customerProdIdPricebookEntryMap.containsKey(customerGroup) && customerProdIdPricebookEntryMap.get(customerGroup).containsKey(prod.Id) && prod.NATT_ItemPriceGroup__c == adjStage.NATT_ItemPriceGroup__c){
                                        Decimal listPrice = customerProdIdPricebookEntryMap.get(customerGroup).get(prod.Id).NAOCAP_Customer_List_Price__c != null ? customerProdIdPricebookEntryMap.get(customerGroup).get(prod.Id).NAOCAP_Customer_List_Price__c : customerProdIdPricebookEntryMap.get(customerGroup).get(prod.Id).UnitPrice;
                                        Decimal cost = listPrice + (listPrice * (adjStage.NATT_AdjustmentValue__c/100));
                                        PricebookEntry pbe = customerProdIdPricebookEntryMap.get(customerGroup).get(prod.Id);
                                        if(pbe.UnitPrice != cost.setScale(2) || !pbe.IsActive){
                                            upsertPriceBookEntryList.add(new PricebookEntry(Id = pbe.Id, UnitPrice = cost.setScale(2), IsActive = true));
                                        }
                                    } 
                                }
                            }
                        }
                    }
                    //Surcharge on internal customer group
                    else if(adjStage.NATT_AdjustmentType__c == 'SURCHG' && internalCustomerGroup.contains(adjStage.NATT_CustomerPriceGroup__c) && commerceEntitlementProductListMap.containsKey(internalEntitlementPolicyName)){
                        for(Product2 prod : commerceEntitlementProductListMap.get(internalEntitlementPolicyName)){
                            if(prod.NATT_ItemPriceGroup__c == adjStage.NATT_ItemPriceGroup__c && prod.NATT_UnitCost__c != null){
                                Decimal cost = prod.NATT_UnitCost__c + (prod.NATT_UnitCost__c * (adjStage.NATT_AdjustmentValue__c/100));
                                if(customerProdIdPricebookEntryMap.containsKey(prefix + adjStage.NATT_CustomerPriceGroup__c) && customerProdIdPricebookEntryMap.get(prefix + adjStage.NATT_CustomerPriceGroup__c).containsKey(prod.Id)){
                                    PricebookEntry pbe = customerProdIdPricebookEntryMap.get(prefix + adjStage.NATT_CustomerPriceGroup__c).get(prod.Id);
                                    if(pbe.UnitPrice != cost.setScale(2) || !pbe.IsActive){
                                        upsertPriceBookEntryList.add(new PricebookEntry(Id = pbe.Id, UnitPrice = cost.setScale(2), IsActive = true));
                                    }
                                }else{
                                    if(priceBookNameMap.containsKey(prefix + adjStage.NATT_CustomerPriceGroup__c)){
                                        upsertPriceBookEntryList.add(new PricebookEntry(Pricebook2Id = priceBookNameMap.get(prefix + adjStage.NATT_CustomerPriceGroup__c), CurrencyIsoCode = 'USD', Product2Id = prod.Id, UnitPrice = cost.setScale(2), IsActive = true));
                                    }
                                } 
                            }
                        }
                    }
                }
            }
        }
        if(!upsertPriceBookEntryList.isEmpty()){
            upsert upsertPriceBookEntryList Id;
        }
    }
    
    public void finish(Database.BatchableContext bc){
        
       //  if(!Test.isRunningTest()){
          //  Database.executeBatch(new NAC_HandleCategoryUpdateProductBatch(),1);
       // }
        List<WebStore> wsList = new List<WebStore>([SELECT Id,Name FROM WebStore WHERE Name =: Label.NAOCAP_Store_Name]);
       if(!wsList.isEmpty() && !Test.isRunningTest()){
            ConnectApi.CommerceSearchSettings.createCommerceSearchIndex(wsList.get(0).Id);
        }
       
    }
}