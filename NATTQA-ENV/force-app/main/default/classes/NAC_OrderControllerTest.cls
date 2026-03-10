@isTest
public class NAC_OrderControllerTest {
  static string communityId = [SELECT Id, Name FROM Network WHERE Name =:NAC_Global_Constants.DEFAULT_COMMUNITY_NAME_NAC].Id;

  @isTest(SeeAllData=true)
    static void addtoCartTest(){
        Account acc = NAC_TestDataFactory.insertAccount();
        Contact con=NAC_TestDataFactory.insertAssociatedContact(acc);
        User us=NAC_TestDataFactory.runAsNACUser();
        String effectiveAccountId=acc.id;
        BuyerAccount buyerAccount=NAC_TestDataFactory.insertBuyerAccount(acc);
        
        BuyerGroup bg = NAC_TestDataFactory.insertBuyerGroup();
        BuyerGroupMember bgm = NAC_TestDataFactory.insertBuyerGroupMember(acc,bg);
        
        WebStore webstore = [SELECT id FROM WebStore WHERE Name =:NAC_Global_Constants.DEFAULT_COMMUNITY_NAME_NAC LIMIT 1];
        NAC_B2BUtils.communityIdToWebStoreIdCache.put(communityId,webstore.id);
        
        WebStoreBuyerGroup wsbg = NAC_TestDataFactory.insertWebStoreBuyerGroup(webstore,bg);
        List<PRiceBook2> pb=NAC_TestDataFactory.createPriceBook(1);
        Order ord=NAC_TestDataFactory.createOrder(con.ID,acc.ID,pb[0].id);
        List<String> fieldList= new List<String>();
        List<Id> ProductList=new List<Id>();
        Product2 prod = new Product2(Name ='testProd'+Math.random(),
                                     StockkeepingUnit ='SKU'+Math.random()                           
                                    );
        insert prod;
        ProductList.add(prod.id);
        Boolean excludeMedia=true;
        Boolean excludePrices=true;
        
        try{
                NAC_OrderController.getProducts(communityId,effectiveAccountId,fieldList,ProductList,excludeMedia,excludePrices);
        }
        catch(Exception e){
            
        }
		List<OrderItem> itemList = [SELECT Id, Product2.NAOCAP_Not_Orderable__c, Product2.NAOCAP_Not_Orderable_ANA__c, Product2.NAOCAP_Not_Orderable_CHI__c, Product2.NAOCAP_Not_Orderable_PAN__c, Product2.NATT_Core__c, Product2Id, Quantity FROM OrderItem WHERE OrderId =: ord.Id ];
         List<Id> productIdList = new List<Id>();
            for(OrderItem item : itemList){
                productIdList.add(item.Product2Id);
            }  
        List<Product2> updateProductList = new List<Product2>();
        for(Product2 pro : [Select id,NATT_Core__c from Product2 where Id In:productIdList]){
            pro.NATT_Core__c = true;
            updateProductList.add(pro);
            break;
        }
        update updateProductList;
        NAC_OrderController.resultWrapper roW=NAC_OrderController.addtoCart(ord.id,communityId,effectiveAccountId,'ANA');
      
        System.assertNotEquals(roW,null,'NOt able to add to Cart');
    }
    @isTest(SeeAllData=true)
    static void fetchDataTest(){
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
        List<PRiceBook2> pb=NAC_TestDataFactory.createPriceBook(1);
        Order ord=NAC_TestDataFactory.createOrder(con.ID,acc.ID,pb[0].id);
     
        List<String> fieldList= new List<String>();
        List<Id> ProductList=new List<Id>();
        Product2 prod = new Product2(Name ='testProd'+Math.random(),NATT_Core__c=true,
                                     StockkeepingUnit ='SKU'+Math.random()                            
                                    );
        insert prod;
        ProductList.add(prod.id);
        Boolean excludeMedia=true;
        Boolean excludePrices=true;
        Test.startTest();
        system.runAs(us){
        try{
         NAC_OrderController.sObjectWrapper sOw=NAC_OrderController.fetchData(communityId,effectiveAccountId,'NAOCAP_Order_List_View','NAOCAP_Order_List_View_Sortable_Fields','Order');
         NAC_OrderController.sObjectWrapper rW=NAC_OrderController.fetchData(communityId,effectiveAccountId,'NAOCAP_Order_List_View','NAOCAP_Order_List_View_Sortable_Fields','Xyz');
         System.assertNotEquals(sOw,null,'Data fetching failed');
         System.assertNotEquals(rW,null,'NOt able to fetch data');
        }
        catch(Exception e){
            
        }
        }
        Test.stopTest();
    }
     @isTest(SeeAllData=true)
    static void getFieldsNegativeTest(){
        Test.startTest();
        NAC_OrderController.getFields('Test','Test','Order');
        //NAC_OrderController.getFields('Test','Test','Test');
        Test.stopTest();
    }
    
}