@isTest 
public without sharing class Nac_GetCustomSettingWareHouseDataTest {
    static string communityId = [SELECT Id, Name FROM Network WHERE Name =:NAC_Global_Constants.DEFAULT_COMMUNITY_NAME_NAC].Id;
    
    @isTest(SeeAllData=true)
    static void returWarehousesTest() {
        Account acc=NAC_TestDataFactory.insertAccount();
        String effectiveAccountId=acc.id; 
        BuyerAccount buyerAccount=NAC_TestDataFactory.insertBuyerAccount(acc);
        
        BuyerGroup bg = NAC_TestDataFactory.insertBuyerGroup();
        BuyerGroupMember bgm = NAC_TestDataFactory.insertBuyerGroupMember(acc,bg);
        
        WebStore webstore = [SELECT id FROM WebStore WHERE Name =:NAC_Global_Constants.DEFAULT_COMMUNITY_NAME_NAC LIMIT 1];
        NAC_B2BUtils.communityIdToWebStoreIdCache.put(communityId,webstore.id);
        Product2 pr=[SELECT Id, Name FROM Product2 LIMIT 1];
        
        WebStoreBuyerGroup wsbg = NAC_TestDataFactory.insertWebStoreBuyerGroup(webstore,bg);
        insert new NATT_ProductInventoryItem__c(NATT_AvailableQuantity__c = 999, NATT_AvailabilityDate__c = system.today()-17, NATT_ProductItem__c = pr.Id, NATT_Warehouse__c = 'ATL');
        Test.startTest();
        try{
            Nac_GetCustomSettingWareHouseData.returWarehouses(communityId,effectiveAccountId,NAC_Global_Constants.ACTIVECARTID,pr.id);
        }catch(Exception e){
            
        }
        
        Test.stopTest();
    }
    @isTest
    static void getSelectedWarehouseTest() {
        Test.startTest();
        Nac_GetCustomSettingWareHouseData.getSelectedWarehouse(NAC_Global_Constants.WAREHOUSEDEF);
        Test.stopTest();
    }
    @isTest(SeeAllData=true)
    static void updateTheCartTest() {
        Account acc=NAC_TestDataFactory.insertAccount();
        String effectiveAccountId=acc.id;
        BuyerAccount buyerAccount=NAC_TestDataFactory.insertBuyerAccount(acc);
        
        BuyerGroup bg = NAC_TestDataFactory.insertBuyerGroup();
        BuyerGroupMember bgm = NAC_TestDataFactory.insertBuyerGroupMember(acc,bg);
        
        WebStore webstore = [SELECT id FROM WebStore WHERE Name =:NAC_Global_Constants.DEFAULT_COMMUNITY_NAME_NAC LIMIT 1];
        NAC_B2BUtils.communityIdToWebStoreIdCache.put(communityId,webstore.id);
        
        WebStoreBuyerGroup wsbg = NAC_TestDataFactory.insertWebStoreBuyerGroup(webstore,bg);
        Test.startTest();
        try{
            Webcart wc=Nac_GetCustomSettingWareHouseData.updateTheCart(communityId,effectiveAccountId,NAC_Global_Constants.ACTIVECARTID,NAC_Global_Constants.WAREHOUSEDEF);
        }catch(Exception e){
            
        }
        
        Test.stopTest();
    }
    
    @isTest(SeeAllData=true)
    static void getCartDetailsTest() {
        Account acc=NAC_TestDataFactory.insertAccount();
        String effectiveAccountId=acc.id;
        BuyerAccount buyerAccount=NAC_TestDataFactory.insertBuyerAccount(acc);
        
        BuyerGroup bg = NAC_TestDataFactory.insertBuyerGroup();
        BuyerGroupMember bgm = NAC_TestDataFactory.insertBuyerGroupMember(acc,bg);
        
        WebStore webstore = [SELECT id FROM WebStore WHERE Name =:NAC_Global_Constants.DEFAULT_COMMUNITY_NAME_NAC LIMIT 1];
        NAC_B2BUtils.communityIdToWebStoreIdCache.put(communityId,webstore.id);
        String Warehouse;
        WebStoreBuyerGroup wsbg = NAC_TestDataFactory.insertWebStoreBuyerGroup(webstore,bg);
        Test.startTest();
        try{
            Warehouse=Nac_GetCustomSettingWareHouseData.getCartDetails(communityId,effectiveAccountId,NAC_Global_Constants.ACTIVECARTID);
            
        }catch(Exception e){
            
        }
        Test.stopTest();
       // System.assertNotEquals(Warehouse,null, 'we couldnt fetch the cart details');
    } 
}