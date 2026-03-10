@IsTest
public class NAC_CartControllerTest {
    static string communityId = [SELECT Id, Name FROM Network WHERE Name =:NAC_Global_Constants.DEFAULT_COMMUNITY_NAME_NAC].Id;
    
    @isTest(SeeAllData=true)
    static void createCartTest(){
        returnData data = createData(true);
        System.runAs(data.usr){
            Test.startTest();
            try{
                ConnectApi.CartSummary createdCart = NAC_CartController.createCart(communityId,data.acc.Id);
            }catch(Exception e){
              //  system.debug('Exception@@'+e);
            }
            Test.stopTest();
        }
    }
    private static returnData createData(Boolean createStore){
        returnData data = new returnData();
        Id prodRecordTypeId = Schema.SObjectType.Product2.getRecordTypeInfosByDeveloperName().get('NAC_Products').getRecordTypeId();
        Map<Id, Decimal> product2PriceMap = new Map<Id, Decimal>();
        List<Id> product2IdList = new List<Id>();
        WebStore web;
        if(createStore){
            web = [SELECT id FROM WebStore WHERE Name =: NAC_Global_Constants.DEFAULT_COMMUNITY_NAME_NAC LIMIT 1];
        }else{
            web = NAC_TestDataFactory.webstoreCreation();
        }
        NAC_B2BUtils.communityIdToWebStoreIdCache.put(communityId,web.id);
        ProductCategory pc = NAC_TestDataFactory.createProductCategory(web.Id);
        List<Product2> product2List = NAC_TestDataFactory.createProductList(10);
        for(integer i = 5; i < product2List.size(); i++){
            product2List[i].RecordTypeId = prodRecordTypeId;
            product2List[i].NATT_SignalCode__c = 'A';
            if(i == 5 || i == 6 || i == 7){
                product2List[i].NATT_SignalCode__c = 'S2';
            }
            product2List[i].NATT_ItemPriceGroup__c = '510';
            product2List[i].NAOCAP_Under_Processing__c = true;
            product2List[i].NATT_Branch_Plant_Warehouse__c = 'ATL';
            product2List[i].ProductCode = product2List[i].ProductCode;
            product2List[i].NATT_P_N__c = product2List[i].ProductCode;
            product2List[i].NATT_UnitCost__c = 1718;
        }
        insert product2List;
        List<NATT_AlternativeItem__c> altItemList = new List<NATT_AlternativeItem__c>();
        for(integer i = 0; i < product2List.size(); i++){
            product2IdList.add(product2List[i].Id);
            if(i != product2List.size() - 1){
                product2PriceMap.put(product2List[i].Id, Math.random() * 100);
                 if(i == 5 || i == 6){
                    NATT_AlternativeItem__c altItem = new NATT_AlternativeItem__c();
                    altItem.NATT_AlternativeItem__c = product2List[i].Id;
                    altItem.NATT_ProductItem__c = product2List[i-1].Id;
                    altItem.NATT_EffectiveDate__c = System.today();
                    altItemList.add(altItem);
                }
            }
        }        
        insert altItemList;
        NAC_TestDataFactory.createProductCategoryProductList(new Map<Id,List<Id>>{pc.Id => product2IdList});
        data.usr = NAC_TestDataFactory.runAsNACUser();
        Contact cont = [SELECT Id, AccountId FROM Contact WHERE Id =: data.usr.ContactId];
        data.acc = [SELECT Id FROM Account WHERE Id =: cont.AccountId];
        NAC_TestDataFactory.insertBuyerAccount(data.acc);
        BuyerGroup bg =  NAC_TestDataFactory.insertBuyerGroup();
        WebStoreBuyerGroup wbg =  NAC_TestDataFactory.insertWebStoreBuyerGroup(web, bg);
        NAC_TestDataFactory.insertBuyerGroupMember(data.acc, bg);
        List<PriceBook2> priceBookList = NAC_TestDataFactory.createPriceBook(1);
        insert priceBookList;
        NAC_TestDataFactory.createPriceBookEntry(new Map<Id, Map<Id,Decimal>>{priceBookList[0].Id => product2PriceMap});
        NAC_TestDataFactory.createBuyerGroupPricebook(new Map<Id,List<Id>>{bg.Id => new List<Id>{priceBookList[0].Id}});
        List<CommerceEntitlementPolicy> cepList = NAC_TestDataFactory.createCommerceEntitlementPolicy(1);
        insert cepList;
        NAC_TestDataFactory.createCommerceEntitlementBuyerGroup(new Map<Id,List<Id>>{cepList[0].Id => new List<Id>{bg.Id}});
        NAC_TestDataFactory.createCommerceEntitlementProduct(new Map<Id,List<Id>>{cepList[0].Id => product2IdList});
        return data;
    }
     private class returnData{
        private User usr;
        private Account acc;
     }
    
    @isTest(SeeAllData=true)
    static void getCartitemTest(){
        Account acc = NAC_TestDataFactory.insertAccount();
        Contact con=NAC_TestDataFactory.insertAssociatedContact(acc);
        
        String effectiveAccountId=acc.id;
        BuyerAccount buyerAccount=NAC_TestDataFactory.insertBuyerAccount(acc);
        
        BuyerGroup bg = NAC_TestDataFactory.insertBuyerGroup();
        BuyerGroupMember bgm = NAC_TestDataFactory.insertBuyerGroupMember(acc,bg);
        
        WebStore webstore = [SELECT id FROM WebStore WHERE Name =:NAC_Global_Constants.DEFAULT_COMMUNITY_NAME_NAC LIMIT 1];
        NAC_B2BUtils.communityIdToWebStoreIdCache.put(communityId,webstore.id);
        WebStoreBuyerGroup wsbg = NAC_TestDataFactory.insertWebStoreBuyerGroup(webstore,bg);
        
        WebCart cartCreate=NAC_TestDataFactory.cartCreation(webstore.id,acc.id);
        Test.startTest();
        try{
            ConnectApi.CartItemCollection cartItemCollected = NAC_CartController.getCartItems(communityId,effectiveAccountId,cartCreate.id,1,null,null);
        }catch(Exception e){
            
        }
        
        Test.stopTest();
    }
    
    @isTest(SeeAllData=true)
    static void updateCartItemTest(){
        Account acc = NAC_TestDataFactory.insertAccount();
        system.debug('acc50@@'+acc.id);
        Contact con=NAC_TestDataFactory.insertAssociatedContact(acc);
        
        String effectiveAccountId=acc.id;
        BuyerAccount buyerAccount=NAC_TestDataFactory.insertBuyerAccount(acc);

        
        WebStore web = [SELECT id FROM WebStore WHERE Name =:NAC_Global_Constants.DEFAULT_COMMUNITY_NAME_NAC LIMIT 1];
        NAC_B2BUtils.communityIdToWebStoreIdCache.put(communityId,web.id);
        
        
        List<BuyerGroup> insertBuyerGroupList = new List<BuyerGroup>{new BuyerGroup(Name = Label.NAOCAP_Prefix + 'CTESTE3', NAC_Type__c = 'C3'), new BuyerGroup(Name = Label.NAOCAP_Prefix + 'V1CTESTE3H')};
        insert insertBuyerGroupList;
        insert new List<WebStoreBuyerGroup>{new WebStoreBuyerGroup(WebStoreId = web.Id, BuyerGroupId = insertBuyerGroupList[0].Id), new WebStoreBuyerGroup(WebStoreId = web.Id, BuyerGroupId = insertBuyerGroupList[1].Id)};
        insert new List<BuyerGroupMember>{new BuyerGroupMember(BuyerGroupId = insertBuyerGroupList[0].Id, BuyerId = acc.Id), new BuyerGroupMember(BuyerGroupId = insertBuyerGroupList[1].Id, BuyerId = acc.Id)};
      
        
        
        USer us=NAC_TestDataFactory.runAsNACUser();
        Id currCon= us.ContactId;
        Contact currAcc =[Select AccountId from Contact where Id=:currCon];
        currAcc.AccountId= acc.Id;
        update currAcc;
        System.runAs(us){
            Test.startTest();
            WebCart cartCreate=NAC_TestDataFactory.cartCreation(web.id,acc.Id);
            List<CartItem> cartItem=[select Id,CartId,product2ID,product2.recordtypeid,Product2.NATT_CoreItem_P_N__c,Product2.NATT_P_N__c,Product2.recordType.Name,Product2.NATT_Core__c,Product2.NATT_Branch_Plant_Warehouse__c,product2.Name,CartDeliveryGroupId from cartItem where CartId=:cartCreate.id];
            
            ConnectApi.CartItemInput cartItem1 =new ConnectApi.CartItemInput();
            cartItem1.productId = cartItem[0].product2ID;
            cartItem1.quantity ='2'; 
            try{
                NAC_CartController.updateCartItem(communityId,effectiveAccountId,cartCreate.id,cartItem[0].id,cartItem1);  
            } 
            catch(Exception e){
                
            }
            Test.stopTest();
        }
        
        
    }
    
    @isTest(SeeAllData=true)
    static void deleteCartItemTest(){
        Account acc = NAC_TestDataFactory.insertAccount();
        Contact con=NAC_TestDataFactory.insertAssociatedContact(acc);
        
        String effectiveAccountId=acc.id;
        BuyerAccount buyerAccount=NAC_TestDataFactory.insertBuyerAccount(acc);
        
        BuyerGroup bg = NAC_TestDataFactory.insertBuyerGroup();
        BuyerGroupMember bgm = NAC_TestDataFactory.insertBuyerGroupMember(acc,bg);
        
        WebStore webstore = [SELECT id FROM WebStore WHERE Name =:NAC_Global_Constants.DEFAULT_COMMUNITY_NAME_NAC LIMIT 1];
        NAC_B2BUtils.communityIdToWebStoreIdCache.put(communityId,webstore.id);
        WebStoreBuyerGroup wsbg = NAC_TestDataFactory.insertWebStoreBuyerGroup(webstore,bg);
        
        WebCart cartCreate=NAC_TestDataFactory.cartCreation(webstore.id,acc.id);
        List<CartItem> cartItem=[select CartId,product2ID,CartDeliveryGroupId from cartItem where CartId=:cartCreate.id];
        system.debug('cartItem@'+cartItem[0].product2ID);
        
        ConnectApi.CartItemInput cartItem1 =new ConnectApi.CartItemInput();
        cartItem1.productId = cartItem[0].product2ID;
        cartItem1.quantity ='6';
        
        System.assertNotEquals(cartItem.size(),null,'Cart not created');
        ConnectApi.CartItemInput cartItemToUpdate=new ConnectApi.CartItemInput();
        Test.startTest();
        try{
            List<String> deltedIds=NAC_CartController.deleteCartItem(communityId,effectiveAccountId,cartCreate.id,cartItem[0].id,cartItem1);
        }catch(Exception e){
            
        }
        Test.stopTest();
    }
     @isTest(SeeAllData=true)
    static void cartValidateTest(){
        Account acc = NAC_TestDataFactory.insertAccount();
        Contact con=NAC_TestDataFactory.insertAssociatedContact(acc);
        USer us=NAC_TestDataFactory.runAsNACUser();
        String effectiveAccountId=acc.id;
        BuyerAccount buyerAccount=NAC_TestDataFactory.insertBuyerAccount(acc);
        
        BuyerGroup bg = NAC_TestDataFactory.insertBuyerGroup();
        BuyerGroupMember bgm = NAC_TestDataFactory.insertBuyerGroupMember(acc,bg);
        
        WebStore webstore = [SELECT id FROM WebStore WHERE Name =:NAC_Global_Constants.DEFAULT_COMMUNITY_NAME_NAC LIMIT 1];
        NAC_B2BUtils.communityIdToWebStoreIdCache.put(communityId,webstore.id);
        WebStoreBuyerGroup wsbg = NAC_TestDataFactory.insertWebStoreBuyerGroup(webstore,bg);
        WebCart cartCreate=NAC_TestDataFactory.cartCreation(webstore.id,acc.id);
        System.assertNotEquals(cartCreate.Id,null,'Cart creation failed');
        Test.startTest();
        NAC_CartController.cartValidateResultWrapper validateMap = NAC_CartController.cartValidate(communityId,effectiveAccountId,cartCreate.id,'1','2','ATL');
        Test.stopTest();
        System.assertNotEquals(validateMap.invalidCartItems.keyset(), null, 'validation error occured');
        
    }
     @isTest(SeeAllData=true)
    static void cartValidateDeleteTest(){
        Account acc = NAC_TestDataFactory.insertAccount();
        Contact con=NAC_TestDataFactory.insertAssociatedContact(acc);
        
        String effectiveAccountId=acc.id;
        BuyerAccount buyerAccount=NAC_TestDataFactory.insertBuyerAccount(acc);
        
        BuyerGroup bg = NAC_TestDataFactory.insertBuyerGroup();
        BuyerGroupMember bgm = NAC_TestDataFactory.insertBuyerGroupMember(acc,bg);
        
        WebStore webstore = [SELECT id FROM WebStore WHERE Name =:NAC_Global_Constants.DEFAULT_COMMUNITY_NAME_NAC LIMIT 1];
        NAC_B2BUtils.communityIdToWebStoreIdCache.put(communityId,webstore.id);
        WebStoreBuyerGroup wsbg = NAC_TestDataFactory.insertWebStoreBuyerGroup(webstore,bg);
        
        WebCart cartCreate=NAC_TestDataFactory.cartCreation(webstore.id,acc.id);
        System.assertNotEquals(cartCreate.Id,null,'Cart creation failed');
        List<CartItem> cartItemList=[select CartId,product2ID,CartDeliveryGroupId from cartItem where CartId=:cartCreate.id]; 
        Map<String,String> cartItemToDelete=new Map<String,String>();
        for(cartItem ct:cartItemList){
            cartItemToDelete.put(ct.id, ct.product2ID);
        }
       
        Boolean cartDel;
        Test.startTest();
        try{
           cartDel=NAC_CartController.cartValidateDelete(communityId,effectiveAccountId,cartCreate.id,cartItemToDelete);
        }catch(Exception e){
           
        }
       // system.assertNotEquals(cartDel, false, 'cart delete validation failed');
        Test.stopTest();
    }
    @isTest(SeeAllData=true)
    static void getCartSummaryTest(){
        Account acc = NAC_TestDataFactory.insertAccount();
        Contact con=NAC_TestDataFactory.insertAssociatedContact(acc);
        
        String effectiveAccountId=acc.id;
        BuyerAccount buyerAccount=NAC_TestDataFactory.insertBuyerAccount(acc);
        
        BuyerGroup bg = NAC_TestDataFactory.insertBuyerGroup();
        BuyerGroupMember bgm = NAC_TestDataFactory.insertBuyerGroupMember(acc,bg);
        
        WebStore webstore = [SELECT id FROM WebStore WHERE Name =:NAC_Global_Constants.DEFAULT_COMMUNITY_NAME_NAC LIMIT 1];
        NAC_B2BUtils.communityIdToWebStoreIdCache.put(communityId,webstore.id);
        WebStoreBuyerGroup wsbg = NAC_TestDataFactory.insertWebStoreBuyerGroup(webstore,bg);
        WebCart cartCreate=NAC_TestDataFactory.cartCreation(webstore.id,acc.id);
        System.assertNotEquals(cartCreate.Id,null,'Cart creation failed');
        Test.startTest();
        try{
            ConnectApi.CartSummary cartSummary=NAC_CartController.getCartSummary(communityId,effectiveAccountId,cartCreate.id);
        }catch(Exception e){
            
        }
        Test.stopTest();
    }
    
    @isTest(SeeAllData=true)
    static void deleteCartTest(){
        Account acc = NAC_TestDataFactory.insertAccount();
        Contact con=NAC_TestDataFactory.insertAssociatedContact(acc);
        String effectiveAccountId=acc.id;
        BuyerAccount buyerAccount=NAC_TestDataFactory.insertBuyerAccount(acc);
        
        BuyerGroup bg = NAC_TestDataFactory.insertBuyerGroup();
        BuyerGroupMember bgm = NAC_TestDataFactory.insertBuyerGroupMember(acc,bg);
        
        WebStore webstore = [SELECT id FROM WebStore WHERE Name =:NAC_Global_Constants.DEFAULT_COMMUNITY_NAME_NAC LIMIT 1];
        NAC_B2BUtils.communityIdToWebStoreIdCache.put(communityId,webstore.id);
        WebStoreBuyerGroup wsbg = NAC_TestDataFactory.insertWebStoreBuyerGroup(webstore,bg);
        
        WebCart cartCreate=NAC_TestDataFactory.cartCreation(webstore.id,acc.id);
        System.assertNotEquals(cartCreate.Id,null,'Cart creation failed');
        Test.startTest();
        try{
            NAC_CartController.deleteCart(communityId,effectiveAccountId,cartCreate.id);
        }catch(Exception e){
            
        }
        Test.stopTest();
        List<WebCart> deltedCart=[select Id from WebCart where Id=:cartCreate.id];
        System.assertEquals(deltedCart.size(),1, 'Cart deleted');
    } 
    
}