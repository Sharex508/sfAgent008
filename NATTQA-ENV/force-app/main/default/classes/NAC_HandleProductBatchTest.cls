@isTest
public class NAC_HandleProductBatchTest {
    
    static string communityId = [SELECT Id, Name FROM Network WHERE Name =: NAC_Global_Constants.DEFAULT_COMMUNITY_NAME_NAC].Id;
    
    @testSetup
    public static void setupTestData(){
        Id prodRecordTypeId = Schema.SObjectType.Product2.getRecordTypeInfosByDeveloperName().get('NAC_Products').getRecordTypeId();
        Map<Id, Decimal> product2PriceMap = new Map<Id, Decimal>();
        List<Id> product2ATLIdList = new List<Id>();
        WebStore web = NAC_TestDataFactory.webstoreCreation();
        NAC_B2BUtils.communityIdToWebStoreIdCache.put(communityId,web.id);
        ProductCategory pc = NAC_TestDataFactory.createProductCategory(web.Id);
        pc.Name = Label.NAOCAP_Default_Category;
        update pc;
        List<Product2> product2List = NAC_TestDataFactory.createProductList(20);
        for(integer i = 0; i < product2List.size(); i++){
            product2List[i].RecordTypeId = prodRecordTypeId;
            product2List[i].NATT_ItemPriceGroup__c = '510';
            product2List[i].NAOCAP_Under_Processing__c = true;
            if(Math.Mod(i, 4) == 0){
                product2List[i].NATT_Branch_Plant_Warehouse__c = 'ATL';
                if(i == 0 || i == 4){
                    product2List[i].NAOCAP_Under_Processing__c = false;
                    product2List[i].NATT_SignalCode__c = 'A';
                }else if(i == 16){
                    product2List[i].NATT_SignalCode__c = 'A';
                }else{
                    product2List[i].NATT_SignalCode__c = 'N/A';
                }
                product2List[i].ProductCode = 'TEST-' + String.valueOf(i - 0);
                product2List[i].NATT_P_N__c = 'TEST-' + String.valueOf(i - 0);
            }else if(Math.Mod(i, 4) == 1){
                product2List[i].NATT_Branch_Plant_Warehouse__c = 'ANA';
                product2List[i].NATT_SignalCode__c = 'A';
                product2List[i].ProductCode = 'TEST-' + String.valueOf(i - 1);
                product2List[i].NATT_P_N__c = 'TEST-' + String.valueOf(i - 1);
            }else if(Math.Mod(i, 4) == 2){
                product2List[i].NATT_Branch_Plant_Warehouse__c = 'PAN';
                product2List[i].NATT_SignalCode__c = 'NSI';
                product2List[i].ProductCode = 'TEST-' + String.valueOf(i - 2);
                product2List[i].NATT_P_N__c = 'TEST-' + String.valueOf(i - 2);
            }else{
                product2List[i].NATT_Branch_Plant_Warehouse__c = 'CHI';
                product2List[i].NATT_SignalCode__c = 'S1';
                product2List[i].ProductCode = 'TEST-' + String.valueOf(i - 3);
                product2List[i].NATT_P_N__c = 'TEST-' + String.valueOf(i - 3);
            }
        }
        insert product2List;        
        for(integer i = 1; i < product2List.size(); i++){
            if(i < product2List.size() - 5){
                product2PriceMap.put(product2List[i].Id, Math.random() * 100);
            }
            if(product2List[i].NATT_Branch_Plant_Warehouse__c == 'ATL'){
                product2ATLIdList.add(product2List[i].Id);
            }
        }
        List<Id> prodIdATLReduceList = new List<Id>(product2ATLIdList);
        prodIdATLReduceList.remove(product2ATLIdList.size() - 1);
        NAC_TestDataFactory.createProductCategoryProductList(new Map<Id,List<Id>>{pc.Id => prodIdATLReduceList});
        User usr = NAC_TestDataFactory.runAsNACUser();
        Contact cont = [SELECT Id, AccountId FROM Contact WHERE Id =: usr.ContactId];
        Account acc = [SELECT Id FROM Account WHERE Id =: cont.AccountId];
        acc.NATT_JDE_Parts_Bill_To_Code__c = '48093801';
        acc.CONTAINER_Customer_Group__c = 'C3';
        update acc;
        NAC_TestDataFactory.insertBuyerAccount(acc);
        if(([SELECT Id FROM BuyerAccount where BuyerId =: acc.id AND isActive = true LIMIT 1]).isEmpty()){
            insert new BuyerAccount(BuyerId = acc.Id, Name = 'Test', IsActive = true, BuyerStatus = 'Active');
        }
        List<BuyerGroup> insertBuyerGroupList = new List<BuyerGroup>{new BuyerGroup(Name = Label.NAOCAP_Prefix + 'C3'), new BuyerGroup(Name = Label.NAOCAP_Prefix + 'V1H')};
        insert insertBuyerGroupList;
        insert new List<WebStoreBuyerGroup>{new WebStoreBuyerGroup(WebStoreId = web.Id, BuyerGroupId = insertBuyerGroupList[0].Id), new WebStoreBuyerGroup(WebStoreId = web.Id, BuyerGroupId = insertBuyerGroupList[1].Id)};
        insert new List<BuyerGroupMember>{new BuyerGroupMember(BuyerGroupId = insertBuyerGroupList[0].Id, BuyerId = acc.Id), new BuyerGroupMember(BuyerGroupId = insertBuyerGroupList[1].Id, BuyerId = acc.Id)};
        List<PriceBook2> priceBookList = NAC_TestDataFactory.createPriceBook(3);
        priceBookList[0].Name = Label.NAOCAP_Prefix + 'C3';
        priceBookList[1].Name = Label.NAOCAP_Prefix + 'V1H';
        priceBookList[2].Name = Label.NAOCAP_Strikethrough_Price_Book;
        insert priceBookList;
        NAC_TestDataFactory.createPriceBookEntry(new Map<Id, Map<Id,Decimal>>{priceBookList[0].Id => product2PriceMap, priceBookList[1].Id => product2PriceMap});
        NAC_TestDataFactory.createBuyerGroupPricebook(new Map<Id,List<Id>>{insertBuyerGroupList[0].Id => new List<Id>{priceBookList[0].Id}, insertBuyerGroupList[1].Id => new List<Id>{priceBookList[1].Id}});
        List<CommerceEntitlementPolicy> cepList = NAC_TestDataFactory.createCommerceEntitlementPolicy(2);
        cepList[0].Name = Label.NAOCAP_External_Commerce_Entitlement_Policy;
        cepList[1].Name = Label.NAOCAP_Internal_Commerce_Entitlement_Policy;
        insert cepList;
        NAC_TestDataFactory.createCommerceEntitlementBuyerGroup(new Map<Id,List<Id>>{cepList[0].Id => new List<Id>{insertBuyerGroupList[0].Id}, cepList[1].Id => new List<Id>{insertBuyerGroupList[1].Id}});
        NAC_TestDataFactory.createCommerceEntitlementProduct(new Map<Id,List<Id>>{cepList[0].Id => prodIdATLReduceList});
    }
    
    @isTest
    public static void NAC_HandleProductBatch_Positive_Test(){
        Set<Id> prodIdATLForProcessing = new Set<Id>(), validateStdPriceBookEntryProdIdSet = new Set<Id>(), validateCategoryProdIdSet = new Set<Id>();
        Map<String, List<Id>> validateCategoryMap = new Map<String, List<Id>>();
        List<Product2> prodATLForProcessing = [SELECT Id, NATT_SignalCode__c, NAOCAP_Signal_Code_ANA__c, NAOCAP_Signal_Code_CHI__c, NAOCAP_Signal_Code_PAN__c FROM Product2 WHERE NATT_Branch_Plant_Warehouse__c = 'ATL' AND NAOCAP_Under_Processing__c = true];
        for(Product2 prod : prodATLForProcessing){
            prodIdATLForProcessing.add(prod.Id);
        }
        Test.startTest();
        Database.executeBatch(new NAC_HandleProductBatch());
        String sch = '0 9 17 18 12 ?'; 
        System.schedule('NAOCAP Handle Product Batch', sch ,new NAC_HandleProductBatch());
        Test.stopTest();
        List<Product2> validateProductList = [SELECT Id, NATT_SignalCode__c, NAOCAP_Signal_Code_ANA__c, NAOCAP_Signal_Code_CHI__c, NAOCAP_Signal_Code_PAN__c FROM Product2 WHERE NATT_Branch_Plant_Warehouse__c = 'ATL'];
        system.assert(!validateProductList.isEmpty(), 'Queried Product List should not be Empty');
        List<PriceBookEntry> validateStdPriceBookEntryList = [SELECT Product2Id FROM PriceBookEntry WHERE Pricebook2Id =: Test.getStandardPricebookId()];
        system.assert(!validateStdPriceBookEntryList.isEmpty(), 'Queried PriceBookEntry List should not be Empty');
        for(PriceBookEntry pbe : validateStdPriceBookEntryList){
            validateStdPriceBookEntryProdIdSet.add(pbe.Product2Id);
        }
        List<ProductCategoryProduct> validateCategory = [SELECT ProductId FROM ProductCategoryProduct WHERE ProductCategory.Name =: Label.NAOCAP_Default_Category];
        system.assert(!validateCategory.isEmpty(), 'Queried Product Category List should not be Empty');
        for(ProductCategoryProduct pcp : validateCategory){
            validateCategoryProdIdSet.add(pcp.ProductId);
        }
        List<CommerceEntitlementProduct> validatePolicy = [SELECT Policy.Name, ProductId FROM CommerceEntitlementProduct WHERE (Policy.Name =: Label.NAOCAP_Internal_Commerce_Entitlement_Policy OR Policy.Name =: Label.NAOCAP_External_Commerce_Entitlement_Policy)];
        system.assert(!validatePolicy.isEmpty(), 'Queried Commerce Entitlement Product List should not be Empty');
        for(CommerceEntitlementProduct cep : validatePolicy){
            if(!validateCategoryMap.containsKey(cep.Policy.Name)){
                validateCategoryMap.put(cep.Policy.Name, new List<Id>());
            }
            validateCategoryMap.get(cep.Policy.Name).add(cep.ProductId);
        }
        for(Product2 prod : validateProductList){
            system.assertEquals('A', prod.NAOCAP_Signal_Code_ANA__c, 'Signal Code for all ANA products is set as \'A\', which should be updated in the ATL Products');
            system.assertEquals('S1', prod.NAOCAP_Signal_Code_CHI__c, 'Signal Code for all CHI products is set as \'S1\', which should be updated in the CHI Products');
            system.assertEquals('NSI', prod.NAOCAP_Signal_Code_PAN__c, 'Signal Code for all PAN products is set as \'NSI\', which should be updated in the PAN Products');
            if(prodIdATLForProcessing.contains(prod.Id)){
                system.assert(validateStdPriceBookEntryProdIdSet.contains(prod.Id), 'Standard Price book should be created for all the ATL Products for which NAOCAP_Under_Processing__c is set as true');
                system.assert(validateCategoryProdIdSet.contains(prod.Id), 'Product should be tagged to the category Others for all the ATL Products for which NAOCAP_Under_Processing__c is set as true');
                if(!Label.NAOCAP_Signal_Code_Availability.split(',').contains(prod.NATT_SignalCode__c)){
                    system.assert(validateCategoryMap.get(Label.NAOCAP_Internal_Commerce_Entitlement_Policy).contains(prod.Id), 'Product should be tagged to the Internal Commerce Entitlement Policy for all the ATL Products for a valid Signal Code');
                    system.assert(validateCategoryMap.get(Label.NAOCAP_External_Commerce_Entitlement_Policy).contains(prod.Id), 'Product should be tagged to the External Commerce Entitlement Policy for all the ATL Products for a valid Signal Code');
                }
            }
        }
    }
    
}