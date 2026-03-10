@isTest
public class NAC_HandlecategoryUpdateProductBatchTest {
    
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
            product2List[i].NAC_Cat_Cde6_Description__c = 'HEATER';
            product2List[i].NAC_Cat_Code7_Description_Family__c='GENSET';
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
         ProductCatalog pcat = new ProductCatalog(
                CurrencyIsoCode = 'USD',
                Name = 'NA Containers Marketplace Catalog'
            ); 
            insert pcat;
          ProductCategory prodCat = new ProductCategory(
            CatalogId = pcat.id,
            Name = 'OTHERS',
            SortOrder = 10
        );
        insert prodCat;
        
        ProductCategory prodCatpp = new ProductCategory(
            CatalogId = pcat.id,
            Name = 'PERFORMANCE PARTS',
            SortOrder = 11
        );
        insert prodCatpp;
        
        
        
         ProductCategory prodCatparent = new ProductCategory(
            CatalogId = pcat.id,
            Name = 'GENSET',
            SortOrder = 10
        );
        
        insert prodCatparent;
        
         ProductCategory prodCatone = new ProductCategory(
            CatalogId = pcat.id,
            Name = 'GENERATOR',
            SortOrder = 10,
           ParentCategoryId =prodCatparent.id
        );
        insert prodCatone;
        
         ProductCategoryProduct pcp = new ProductCategoryProduct();
                pcp.ProductCategoryId = prodCat.id;
                pcp.ProductId = product2List[0].id;
                pcp.IsPrimaryCategory = false;
        
            insert pcp;
        
           ProductCategoryProduct pcpone = new ProductCategoryProduct();
                pcpone.ProductCategoryId = prodCatone.id;
                pcpone.ProductId = product2List[1].id;
                pcpone.IsPrimaryCategory = false;
        
            insert pcpone;
        
           Product2 prod = new Product2(Name ='testProd'+Math.random(),ProductCode ='--8E456',NATT_P_N__c='--8E456',
                                     NATT_CoreItem_P_N__c='--8E4567',
                                     StockkeepingUnit ='SKU'+Math.random() ,
                                     recordtypeid=prodRecordTypeId,
                                     NATT_Branch_Plant_Warehouse__c ='ATL',
                                     NAC_Cat_Cde6_Description__c='GENERATOR',
                                     NAC_Cat_Code7_Description_Family__c='GENSET'
                                    );
        insert prod;
        
         Product2 prodone = new Product2(Name ='testProd'+Math.random(),ProductCode ='--8E456',NATT_P_N__c='--8E456',
                                     NATT_CoreItem_P_N__c='--8E4567',
                                     StockkeepingUnit ='SKU'+Math.random() ,
                                     recordtypeid=prodRecordTypeId,
                                     NATT_Branch_Plant_Warehouse__c ='ATL',
                                     NAC_Cat_Cde6_Description__c='',
                                     NAC_Cat_Code7_Description_Family__c=''
                                    );
        insert prodone;
        
       ProductCategoryProduct pcptwo = new ProductCategoryProduct();
                pcptwo.ProductCategoryId = prodCatone.id;
                pcptwo.ProductId = prodone.id;
                pcptwo.IsPrimaryCategory = false;
        
            insert pcptwo; 
        
          }
    
    @isTest
    public static void NAC_HandleCategoryUpdateProductBatch_Test(){
        Set<Id> prodIdATLForProcessing = new Set<Id>(), validateStdPriceBookEntryProdIdSet = new Set<Id>(), validateCategoryProdIdSet = new Set<Id>();
        Map<String, List<Id>> validateCategoryMap = new Map<String, List<Id>>();
        List<Product2> prodATLForProcessing = [SELECT Id, NATT_SignalCode__c, NAOCAP_Signal_Code_ANA__c, NAOCAP_Signal_Code_CHI__c, NAOCAP_Signal_Code_PAN__c FROM Product2 WHERE NATT_Branch_Plant_Warehouse__c = 'ATL' AND NAOCAP_Under_Processing__c = true];
        for(Product2 prod : prodATLForProcessing){
            prodIdATLForProcessing.add(prod.Id);
        }
        
          Id catalogid= [SELECT id, Name FROM ProductCatalog WHERE Name = 'NA Containers Marketplace Catalog'].id;
          Id defaultcategory=[SELECT Id,Name,CatalogId FROM ProductCategory where Name='OTHERS' AND CatalogId =:catalogid ].id;
          Id perPartscategory=[SELECT Id,Name,CatalogId FROM ProductCategory where Name='PERFORMANCE PARTS' AND CatalogId =:catalogid].id;
        Test.startTest();
        Database.executeBatch(new NAC_HandlecategoryUpdateProductBatch());
       // String sch = '0 9 17 18 12 ?'; 
       // System.schedule('NAOCAP Handle Product Batch', sch ,new NAC_HandleProductBatch());
        Test.stopTest();
    }

}