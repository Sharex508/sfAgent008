@isTest
public class NAC_B2BUtilsTest {
    
    static string communityId =[SELECT Id, Name FROM Network WHERE Name =:NAC_Global_Constants.DEFAULT_COMMUNITY_NAME_NAC].Id;
   // static string communityId1 =[SELECT Id, Name FROM Network WHERE Name ='TransicoldStore'].id;
    @testSetup 
     public static void setupTestData(){
        NAC_TestDataFactory.webstoreCreation();
    }
    
    @isTest
    public static void resolveCommunityIdToWebstoreId_Positive_Test(){
        webStore webSt = [SELECT Id FROM webStore LIMIT 1];
        NAC_B2BUtils.communityIdToWebStoreIdCache.put(communityId,webSt.id);
        string webStoreId = NAC_B2BUtils.resolveCommunityIdToWebstoreId(communityId);
       // NAC_B2BUtils.resolveCommunityIdToWebstoreId(communityId1);
        system.assertEquals(webSt.Id, webStoreId);
        ConnectApi.CartItemSortOrder sortOrder=NAC_B2BUtils.resolveSortParam(null);
        System.assertEquals(sortOrder,null,'sorting failed using connect API');
    }
    @isTest
    public static void returnCoreItemIDTest(){
        Account acc = NAC_TestDataFactory.insertAccount();
        Contact con=NAC_TestDataFactory.insertAssociatedContact(acc);
        
        String effectiveAccountId=acc.id;
        BuyerAccount buyerAccount=NAC_TestDataFactory.insertBuyerAccount(acc);
        
        BuyerGroup bg = NAC_TestDataFactory.insertBuyerGroup();
        BuyerGroupMember bgm = NAC_TestDataFactory.insertBuyerGroupMember(acc,bg);
        
       // WebStore webstore = [SELECT id FROM WebStore WHERE Name =:NAC_Global_Constants.DEFAULT_COMMUNITY_NAME_NAC LIMIT 1];
        WebStore webstore=NAC_TestDataFactory.webstoreCreation();
        NAC_B2BUtils.communityIdToWebStoreIdCache.put(communityId,webstore.id);
        WebStoreBuyerGroup wsbg = NAC_TestDataFactory.insertWebStoreBuyerGroup(webstore,bg);
        
        WebCart cartCreate=NAC_TestDataFactory.cartCreation(webstore.id,acc.id);
        List<CartItem> cartItem=[select CartId,product2ID,CartDeliveryGroupId from cartItem where CartId=:cartCreate.id];
        
        Test.startTest();
        String s=NAC_B2BUtils.returnCoreItemID(cartItem[0].id);
        String s1=NAC_B2BUtils.returnCoreItemID(cartItem[2].id);
        Test.stopTest();
        
        System.assertNotEquals(s, null, 'An error has occured while getting the core product');
        System.assertEquals(s1, null, 'An error has occured while getting the core product');
    }
}