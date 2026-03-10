@IsTest
public class NAC_TestDataFactoryTest {
    static string communityId = [SELECT Id, Name FROM Network WHERE Name =:NAC_Global_Constants.DEFAULT_COMMUNITY_NAME_NAC].Id;
    
    @IsTest
    static void createinsertAccount(){
        Product2 prod = new Product2(Name ='testProd'+Math.random(),
                                     StockkeepingUnit ='SKU'+Math.random()                            
                                    );
        insert prod;
        
        Test.startTest();
        Account acc=NAC_TestDataFactory.insertAccount();
        List<Account> acList=NAC_TestDataFactory.createAccounts(4);
        Contact con=NAC_TestDataFactory.insertAssociatedContact(acc);
        
        BuyerAccount byA =NAC_TestDataFactory.insertBuyerAccount(acc);
        BuyerGroup bg = NAC_TestDataFactory.insertBuyerGroup();
        
        String s=NAC_TestDataFactory.randomStringGenerator();
        USer us=NAC_TestDataFactory.runAsNACUser();
        
        String sc=NAC_TestDataFactory.getCommunityId();
        Webstore wc=NAC_TestDataFactory.webstoreCreation();
        
        NATT_ProductInventoryItem__c nic=NAC_TestDataFactory.createProdInventory(prod,'ATL');
        List<ContentVersion> cvList=NAC_TestDataFactory.setUpContentDocument(2);
        
        NAC_TestDataFactory.createPriceBook(3);
        NAC_TestDataFactory.createCommerceEntitlementPolicy(1);
        
        NAC_TestDataFactory.createNATTpriceAdjustmentStaging(2);
        Order od=NAC_TestDataFactory.createOrder(con.id,acc.id,'');
        
        List<Product2> prList=NAC_TestDataFactory.createProductList(3);
        List<ID> prIDs=new list<ID>();
        for(product2 pr2:prList){
            prIDs.add(pr2.id);
        }
        NAC_TestDataFactory.createNATTitemPriceStaging(prIDs);
        ProductCategory cat = NAC_TestDataFactory.createProductCategory(String.valueOf(wc.Id));
        //ProductCategoryProduct prodCat = NAC_TestDataFactory.createProductCategoryProduct(String.valueOf(pr.Id),String.valueOf(cat.Id));
        Test.stopTest();
        system.assertNotEquals(acList.size(), null, 'Accounts not created');
    }
    
    @isTest(SeeAllData=true)
    static void DataFactory2(){
        WebStore webstore = [SELECT id FROM WebStore WHERE Name =:NAC_Global_Constants.DEFAULT_COMMUNITY_NAME_NAC LIMIT 1];
        Account acc=NAC_TestDataFactory.insertAccount();
        Map<ID,String> accountIDMap=new MAp<ID,String>();
        accountIDMap.put(acc.id,'90000');
        Map<ID,Map<ID,String>> WebstoreMap=new MAp<ID,Map<ID,String>>(); 
        WebstoreMap.put(webstore.id,accountIDMap);
        Test.startTest();
        NAC_TestDataFactory.createWebCart(WebstoreMap);
        //Product2 pr=NAC_TestDataFactory.getProductFromWebStore(webstore.id);
        WebCart wc=NAC_TestDataFactory.cartCreation(webstore.id,acc.id);
        NAC_TestDataFactory.buyerGroupAndMember(acc);
        BuyerGroup bg = NAC_TestDataFactory.insertBuyerGroup();
        WebStoreBuyerGroup wbg=NAC_TestDataFactory.insertWebStoreBuyerGroup(webstore,bg);
        BuyerGroupMember bgmem=NAC_TestDataFactory.insertBuyerGroupMember(acc,bg);
        
        Test.stopTest();
        
    }
    
    @isTest(SeeAllData=false)
    static void DataFactory3(){
        Id prodRecordTypeId = Schema.SObjectType.Product2.getRecordTypeInfosByDeveloperName().get('NAC_Products').getRecordTypeId();
        Map<Id, Decimal> product2PriceMap = new Map<Id, Decimal>(), allProduct2PriceMap = new Map<Id, Decimal>();
        List<Id> product2ATLIdList = new List<Id>();
        WebStore web = NAC_TestDataFactory.webstoreCreation();
        NAC_B2BUtils.communityIdToWebStoreIdCache.put(communityId,web.id);
        ProductCategory pc = NAC_TestDataFactory.createProductCategory(web.Id);
        pc.Name = Label.NAOCAP_Default_Category;
        update pc;
        List<Product2> product2List = NAC_TestDataFactory.createProductList(20);
        for(integer i = 0; i < product2List.size(); i++){
            product2List[i].RecordTypeId = prodRecordTypeId;
            product2List[i].NATT_SignalCode__c = 'A';
            product2List[i].NATT_ItemPriceGroup__c = '510';
            product2List[i].NAOCAP_Under_Processing__c = true;
            product2List[i].NATT_Branch_Plant_Warehouse__c = 'ATL';
            product2List[i].ProductCode = 'TEST-' + String.valueOf(i);
            product2List[i].NATT_P_N__c = 'TEST-' + String.valueOf(i);
            product2List[i].NATT_UnitCost__c = 1718;
        }
        insert product2List;
        for(integer i = 0; i < product2List.size(); i++){
            if(i != 0){
                if(i < product2List.size() - 10){
                    product2PriceMap.put(product2List[i].Id, Math.random() * 100);
                }
                product2ATLIdList.add(product2List[i].Id);
            }
            allProduct2PriceMap.put(product2List[i].Id, Math.random() * 100);
        }
        NAC_TestDataFactory.createProductCategoryProductList(new Map<Id,List<Id>>{pc.Id => product2ATLIdList});
        User usr = NAC_TestDataFactory.runAsNACUser();
        Contact cont = [SELECT Id, AccountId FROM Contact WHERE Id =: usr.ContactId];
        Account acc1 = [SELECT Id FROM Account WHERE Id =: cont.AccountId];
        acc1.NATT_JDE_Parts_Bill_To_Code__c = '48093801';
        acc1.CONTAINER_Customer_Group__c = 'C3';
        update acc1;
        NAC_TestDataFactory.insertBuyerAccount(acc1);
        if(([SELECT Id FROM BuyerAccount where BuyerId =: acc1.id AND isActive = true LIMIT 1]).isEmpty()){
            insert new BuyerAccount(BuyerId = acc1.Id, Name = 'Test', IsActive = true, BuyerStatus = 'Active');
        }
        List<BuyerGroup> insertBuyerGroupList = new List<BuyerGroup>{new BuyerGroup(Name = Label.NAOCAP_Prefix + 'C3'), new BuyerGroup(Name = Label.NAOCAP_Prefix + 'V1H'), new BuyerGroup(Name = Label.NAOCAP_Prefix + '48093801')};
            insert insertBuyerGroupList;
        insert new List<WebStoreBuyerGroup>{new WebStoreBuyerGroup(WebStoreId = web.Id, BuyerGroupId = insertBuyerGroupList[0].Id), new WebStoreBuyerGroup(WebStoreId = web.Id, BuyerGroupId = insertBuyerGroupList[1].Id), new WebStoreBuyerGroup(WebStoreId = web.Id, BuyerGroupId = insertBuyerGroupList[2].Id)};
            insert new List<BuyerGroupMember>{new BuyerGroupMember(BuyerGroupId = insertBuyerGroupList[0].Id, BuyerId = acc1.Id), new BuyerGroupMember(BuyerGroupId = insertBuyerGroupList[1].Id, BuyerId = acc1.Id), new BuyerGroupMember(BuyerGroupId = insertBuyerGroupList[2].Id, BuyerId = acc1.Id)};
                List<PriceBook2> priceBookList = NAC_TestDataFactory.createPriceBook(4);
        priceBookList[0].Name = Label.NAOCAP_Prefix + 'C3';
        priceBookList[1].Name = Label.NAOCAP_Prefix + 'V1H';
        priceBookList[2].Name = Label.NAOCAP_Prefix + '48093801';
        priceBookList[3].Name = Label.NAOCAP_Strikethrough_Price_Book;
        insert priceBookList;
        NAC_TestDataFactory.createPriceBookEntry(new Map<Id, Map<Id,Decimal>>{priceBookList[0].Id => product2PriceMap, priceBookList[1].Id => product2PriceMap, priceBookList[2].Id => product2PriceMap, priceBookList[3].Id => allProduct2PriceMap});
        NAC_TestDataFactory.createBuyerGroupPricebook(new Map<Id,List<Id>>{insertBuyerGroupList[0].Id => new List<Id>{priceBookList[0].Id}, insertBuyerGroupList[1].Id => new List<Id>{priceBookList[1].Id}, insertBuyerGroupList[2].Id => new List<Id>{priceBookList[2].Id}});
        List<CommerceEntitlementPolicy> cepList = NAC_TestDataFactory.createCommerceEntitlementPolicy(3);
        cepList[0].Name = Label.NAOCAP_External_Commerce_Entitlement_Policy;
        cepList[1].Name = Label.NAOCAP_Internal_Commerce_Entitlement_Policy;
        cepList[2].Name = Label.NAOCAP_Prefix + '48093801';
        insert cepList;
        NAC_TestDataFactory.createCommerceEntitlementBuyerGroup(new Map<Id,List<Id>>{cepList[0].Id => new List<Id>{insertBuyerGroupList[0].Id}, cepList[1].Id => new List<Id>{insertBuyerGroupList[1].Id}, cepList[2].Id => new List<Id>{insertBuyerGroupList[2].Id}});
        NAC_TestDataFactory.createCommerceEntitlementProduct(new Map<Id,List<Id>>{cepList[0].Id => product2ATLIdList, cepList[1].Id => product2ATLIdList, cepList[2].Id => product2ATLIdList});
        List<NATT_PriceAdjustmentStaging__c> priceAdjustmentStagingList = NAC_TestDataFactory.createNATTpriceAdjustmentStaging(3);
        priceAdjustmentStagingList[0].NATT_AdjustmentType__c = 'REGD';
        priceAdjustmentStagingList[0].NATT_AdjustmentValue__c = -17;
        priceAdjustmentStagingList[0].NATT_CustomerNumber__c = 0;
        priceAdjustmentStagingList[0].NATT_CustomerPriceGroup__c = 'C3';
        priceAdjustmentStagingList[0].NATT_ItemPriceGroup__c = '510';
        priceAdjustmentStagingList[1].NATT_AdjustmentType__c = 'SURCHG';
        priceAdjustmentStagingList[1].NATT_AdjustmentValue__c = 18;
        priceAdjustmentStagingList[1].NATT_CustomerNumber__c = 0;
        priceAdjustmentStagingList[1].NATT_CustomerPriceGroup__c = 'V1H';
        priceAdjustmentStagingList[1].NATT_ItemPriceGroup__c = '510';
        priceAdjustmentStagingList[2].NATT_AdjustmentValue__c = -19;
        priceAdjustmentStagingList[2].NATT_CustomerNumber__c = 48093801;
        priceAdjustmentStagingList[2].NATT_ItemPriceGroup__c = '510';
        insert priceAdjustmentStagingList;
    }
}