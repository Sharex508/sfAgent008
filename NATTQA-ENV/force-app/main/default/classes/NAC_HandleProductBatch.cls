public class NAC_HandleProductBatch implements Database.Batchable<sObject>, Schedulable, Database.Stateful{
    
    Id standardPbId = Test.isRunningTest() ? Test.getStandardPricebookId() : [SELECT Id, Name FROM Pricebook2 WHERE IsStandard=true].Id;
    List<String> invalidSignalCode = Label.NAOCAP_Signal_Code_Availability.split(','), externalUserItemCode = Label.NAOCAP_External_User_Item_Code.split(','), internalUserItemCode = Label.NAOCAP_Internal_User_Item_Code.split(',');
    string internalEntitlementPolicyName = Label.NAOCAP_Internal_Commerce_Entitlement_Policy, externalEntitlementPolicyName = Label.NAOCAP_External_Commerce_Entitlement_Policy, webStoreName = Label.NAOCAP_Store_Name, fieldListStr = '';
    
    public Database.QueryLocator start(Database.BatchableContext BC){
        Map <String, Schema.SObjectField> product2MapField = Schema.SObjectType.Product2.fields.getMap();
        List<String> fieldList = new List<String>();
        fieldList.addAll(product2MapField.keySet());
        fieldListStr = String.join(fieldList,',');
        String query = 'SELECT ' + fieldListStr + ' FROM Product2 WHERE RecordType.DeveloperName = \'NAC_Products\' AND NAOCAP_Under_Processing__c = true';
        return Database.getQueryLocator(query);
    }
    
    public void execute(Database.BatchableContext bc, List<Product2> scope){
        List<String> policyNameList = new List<String>();
        Map<Id, String> policyIdMap = new Map<Id, String>();
        Map<Id, Product2> updateProductMap = new Map<Id, Product2>();
        List<PricebookEntry> insertStdPriceBookEntryList = new List<PricebookEntry>();
        Map<String,Map<String,Product2>> combineProductMap = new  Map<String,Map<String,Product2>>();
        List<ProductCategoryProduct> insertProductCategoryProductList = new List<ProductCategoryProduct>();
        Map<Id,Map<Id,CommerceEntitlementProduct>> policyToProductMap = new Map<Id,Map<Id,CommerceEntitlementProduct>>();
        Set<Id> prodIdSet = new Set<Id>(), prodATLIdSet = new Set<Id>(), prodIdTaggedToCategory = new Set<Id>(), prodIdSetWithStdPb = new Set<Id>();
        List<CommerceEntitlementProduct> cepUpsertList = new List<CommerceEntitlementProduct>(), cepDeleteList = new List<CommerceEntitlementProduct>();
        
        for(Product2 prod : scope){
            prodIdSet.add(prod.Id);
            if(prod.NATT_Branch_Plant_Warehouse__c == 'ATL'){
                prodATLIdSet.add(prod.Id);
            }
            if(combineProductMap.containsKey(prod.ProductCode)){
                combineProductMap.get(prod.ProductCode).put(prod.NATT_Branch_Plant_Warehouse__c, prod);
            }else{
                combineProductMap.put(prod.ProductCode, new Map<String,Product2>{prod.NATT_Branch_Plant_Warehouse__c => prod});
            }
        }
        
        for(PricebookEntry stdPbe : [SELECT Id, Pricebook2Id, Product2Id FROM PricebookEntry WHERE Pricebook2Id =: standardPbId AND Product2Id =: prodATLIdSet]){
            prodIdSetWithStdPb.add(stdPbe.Product2Id);
        }
        
        if(!combineProductMap.keySet().isEmpty()){
            Set<string> getProductCode = new Set<string>();
            for(string productCode : combineProductMap.keySet()){
                if(!combineProductMap.get(productCode).containsKey('ATL')){
                    getProductCode.add(productCode);
                }
            }
            if(!getProductCode.isEmpty()){
                String query = 'SELECT ' + fieldListStr + ' FROM Product2 WHERE ProductCode IN: getProductCode AND RecordType.DeveloperName = \'NAC_Products\' AND NATT_Branch_Plant_Warehouse__c = \'ATL\'';
                for(Product2 prod : Database.query(query)){
                    if(combineProductMap.containsKey(prod.ProductCode) && !combineProductMap.get(prod.ProductCode).containsKey(prod.NATT_Branch_Plant_Warehouse__c)){
                        combineProductMap.get(prod.ProductCode).put(prod.NATT_Branch_Plant_Warehouse__c, prod);
                    }
                }
            }
        }
        ProductCatalog cat = [SELECT Id FROM ProductCatalog WHERE Id IN (SELECT ProductCatalogId FROM WebStoreCatalog WHERE SalesStore.Name =: webStoreName)];
        if(!prodATLIdSet.isEmpty()){
            for(ProductCategoryProduct catProd : [SELECT ProductId FROM ProductCategoryProduct WHERE ProductId IN: prodATLIdSet AND ProductCategory.CatalogId =: cat.Id]){
                prodIdTaggedToCategory.add(catProd.ProductId);
            }
        }
        
        policyNameList.add(internalEntitlementPolicyName);
        policyNameList.add(externalEntitlementPolicyName);
        
        for(CommerceEntitlementPolicy cep : [SELECT Id, Name, (SELECT Id FROM CommerceEntitlementBuyerGroups WHERE BuyerGroupId IN (SELECT BuyerGroupId from WebStoreBuyerGroup WHERE WebStore.Name =: webStoreName)) FROM CommerceEntitlementPolicy WHERE Name IN: policyNameList]){
            if(!cep.CommerceEntitlementBuyerGroups.isEmpty()){
                policyIdMap.put(cep.Id, cep.Name);
            }
        }
        for(CommerceEntitlementProduct cep : [SELECT Id, PolicyId, ProductId FROM CommerceEntitlementProduct WHERE PolicyId IN : policyIdMap.keySet() AND ProductId IN : prodIdSet]){
            if(!policyToProductMap.containsKey(cep.PolicyId)){
                policyToProductMap.put(cep.PolicyId,new Map<Id,CommerceEntitlementProduct>());
            }
            policyToProductMap.get(cep.PolicyId).put(cep.ProductId,cep);
        }
        
        for(Product2 prod : scope){
            if(prod.NATT_Branch_Plant_Warehouse__c == 'ATL'){
                if(!prodIdSetWithStdPb.contains(prod.Id)){
                    insertStdPriceBookEntryList.add(new PricebookEntry(Pricebook2Id = standardPbId, CurrencyIsoCode = 'USD', Product2Id = prod.Id, UnitPrice = 0, IsActive = true));
                }
                for(Id policyId : policyIdMap.keySet()){
                    boolean validProduct = !(invalidSignalCode.contains(prod.NATT_SignalCode__c) || (policyIdMap.get(policyId) == externalEntitlementPolicyName && !externalUserItemCode.contains(prod.NATT_ItemPriceGroup__c)) || (policyIdMap.get(policyId) == internalEntitlementPolicyName && !internalUserItemCode.contains(prod.NATT_ItemPriceGroup__c)));
                    if(policyToProductMap.containsKey(policyId)){
                        if(!policyToProductMap.get(policyId).containsKey(prod.Id)){
                            if(validProduct){
                                cepUpsertList.add(new CommerceEntitlementProduct(PolicyId = policyId, ProductId = prod.Id));
                            }
                        }else{
                            if(!validProduct){
                                cepDeleteList.add(policyToProductMap.get(policyId).get(prod.Id));
                            }
                        }
                    }else{
                        if(validProduct){
                            cepUpsertList.add(new CommerceEntitlementProduct(PolicyId = policyId, ProductId = prod.Id));
                        }
                    }
                }
                if(!prodIdTaggedToCategory.contains(prod.Id)){
                    insertProductCategoryProductList.add(new ProductCategoryProduct(ProductId = prod.Id));
                }
            }
            if(combineProductMap.containsKey(prod.ProductCode) && combineProductMap.get(prod.ProductCode).containsKey('ATL') && !updateProductMap.containsKey(combineProductMap.get(prod.ProductCode).get('ATL').Id)){
                Product2 prodATL = combineProductMap.get(prod.ProductCode).get('ATL');
                boolean hasUpdate = false;
                Map<String,String> wareHouseFieldMap = new Map<String,String>{'ANA'=>'NAOCAP_Signal_Code_ANA__c','CHI'=>'NAOCAP_Signal_Code_CHI__c','PAN'=>'NAOCAP_Signal_Code_PAN__c'};
                Map<String,String> wareHouseFieldMapStockingType = new Map<String,String>{'ANA'=>'NAOCAP_Stocking_Type_UTC_ANA__c','CHI'=>'NAOCAP_Stocking_Type_UTC_CHI__c','PAN'=>'NAOCAP_Stocking_Type_UTC_PAN__c'};
                
                for(String wareHouse : wareHouseFieldMap.keySet()){

                        if(combineProductMap.get(prod.ProductCode).containsKey(wareHouse) && prodATL.get(wareHouseFieldMap.get(wareHouse)) != combineProductMap.get(prod.ProductCode).get(wareHouse).NATT_SignalCode__c){
                            prodATL.put(wareHouseFieldMap.get(wareHouse),combineProductMap.get(prod.ProductCode).get(wareHouse).NATT_SignalCode__c);
                            hasUpdate = true;
                        }
                    }
                for(String wareHouse : wareHouseFieldMapStockingType.keySet()){

                        if(combineProductMap.get(prod.ProductCode).containsKey(wareHouse) && prodATL.get(wareHouseFieldMapStockingType.get(wareHouse)) != combineProductMap.get(prod.ProductCode).get(wareHouse).NAC_Stocking_Type_UTC__c){
                            prodATL.put(wareHouseFieldMapStockingType.get(wareHouse),combineProductMap.get(prod.ProductCode).get(wareHouse).NAC_Stocking_Type_UTC__c);
                            hasUpdate = true;
                        }
                    }
                        
                if(hasUpdate){
                    updateProductMap.put(prodATL.Id, prodATL);
                }
            }
            if(updateProductMap.containsKey(prod.Id)){
                updateProductMap.get(prod.Id).NAOCAP_Under_Processing__c = false;
            }else{
                prod.NAOCAP_Under_Processing__c = false;
                updateProductMap.put(prod.Id, prod);
            }
        }
        
        if(!cepUpsertList.isEmpty()){
            List<Database.UpsertResult> urList = Database.upsert(cepUpsertList, CommerceEntitlementProduct.Id, false);
        }
        if(!cepDeleteList.isEmpty()){
            List<Database.DeleteResult> drList = Database.delete(cepDeleteList, false);
        }
        if(!updateProductMap.values().isEmpty()){
            List<Database.SaveResult> srList = Database.update(updateProductMap.values(), false);
        }
        if(!insertStdPriceBookEntryList.isEmpty()){
            List<Database.SaveResult> srList = Database.insert(insertStdPriceBookEntryList, false);
        }
        if(!insertProductCategoryProductList.isEmpty()){
            ProductCategory pc = [SELECT Id FROM ProductCategory WHERE CatalogId =: cat.Id AND Name =: Label.NAOCAP_Default_Category];
            for(ProductCategoryProduct prodCatProd : insertProductCategoryProductList){
                prodCatProd.ProductCategoryId = pc.Id;
            }
            List<Database.SaveResult> srList = Database.insert(insertProductCategoryProductList, false);
        }
    }
    
    public void finish(Database.BatchableContext bc){
        if(!Test.isRunningTest()){
            Database.executeBatch(new NAC_PriceItemStagingBatch());
        }
    }
    
    public void execute(SchedulableContext sc){
        Database.executeBatch(new NAC_HandleProductBatch());
    }
}