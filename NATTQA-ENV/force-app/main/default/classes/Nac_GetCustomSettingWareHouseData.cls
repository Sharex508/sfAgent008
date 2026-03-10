public without sharing class Nac_GetCustomSettingWareHouseData {
 /*Custom meta data class*/
   @AuraEnabled()
    public static List<CustomMetaDataWrapper> returWarehouses(String communityId,String effectiveAccountId,String activeCartOrId, String productId){
        List<NAC_WareHouseData__mdt> wareHouseConfigList=new List<NAC_WareHouseData__mdt>([SELECT external_url__c,API_VALUE__c,Help_Text_needed__c,sortorder__c, isActive__c,Redirection__c,Warehouse_Name__c from NAC_WareHouseData__mdt ORDER BY sortorder__c ]);
        List<CustomMetaDataWrapper> dataList=new List<CustomMetaDataWrapper>();
        String webstoreId = NAC_B2BUtils.resolveCommunityIdToWebstoreId(communityId);
        WebCart wc;
        if(!Test.isRunningTest()){
            ConnectApi.CartSummary getTheCartDetails=ConnectApi.CommerceCart.getOrCreateActiveCartSummary(webstoreId,effectiveAccountId,activeCartOrId);
            wc=[SELECT Id, Name, AccountId,Warehouse_selected__c, WebStoreId FROM WebCart where id=:getTheCartDetails.cartId];
        }

        //If product Id is sent, fetch the inventory for all those products and put it within the wrapper
        Map<String,NATT_ProductInventoryItem__c> productInventory = new Map<String,NATT_ProductInventoryItem__c>();
        if(productId != null){
            productInventory = Nac_InventoryUtility.getAllWarehouseAvailability(productId); 
        }
        for(NAC_WareHouseData__mdt it:wareHouseConfigList){
            CustomMetaDataWrapper cm=new CustomMetaDataWrapper();
            cm.WarehouseName=it.Warehouse_Name__c;
            cm.Redirection=it.Redirection__c;
            cm.isActive=it.isActive__c;
            cm.externalurl=it.external_url__c;
            cm.apiValue=it.API_VALUE__c;
            cm.Help_Text_needed=it.Help_Text_needed__c;
            if(!Test.isRunningTest()){
                cm.WarehouseStamped = wc.Warehouse_selected__c;
            }else{
                cm.WarehouseStamped= 'ATL';
            }
            System.debug(productInventory);
            if(productId != null && productInventory.get(it.API_VALUE__c) != null){
                if (productInventory.get(it.API_VALUE__c).NATT_AvailableQuantity__c != null && Integer.valueOf(productInventory.get(it.API_VALUE__c).NATT_AvailableQuantity__c) > 0) {
                    cm.inventoryAvailable = 'Available: ' + productInventory.get(it.API_VALUE__c).NATT_AvailableQuantity__c;
                    cm.inventoryExists = true;
                }
                else if(productInventory.get(it.API_VALUE__c).NATT_AvailableQuantity__c != null && Integer.valueOf(productInventory.get(it.API_VALUE__c).NATT_AvailableQuantity__c) <= 0){
                    cm.inventoryAvailable = 'Availability Date: ' + Date.valueOf(productInventory.get(it.API_VALUE__c).NATT_AvailabilityDate__c).format();
                }
                else if(productInventory.get(it.API_VALUE__c).NATT_ProductItem__r.NATT_SignalCode__c=='NSI'){
                    cm.inventoryAvailable = 'NSI';
                }
            }
            dataList.add(cm);
     }
        return dataList;
   }
    class CustomMetaDataWrapper{
        @AuraEnabled public String WarehouseName{get;set;}
        @AuraEnabled public String apiValue{get;set;}
        @AuraEnabled public Boolean Redirection{get;set;}
        @AuraEnabled public Boolean isActive{get;set;}
        @AuraEnabled public String externalurl{get;set;}
        @AuraEnabled public Boolean Help_Text_needed{get;set;}
        @AuraEnabled public String WarehouseStamped{get;set;}
        @AuraEnabled public String inventoryAvailable{get;set;}
        @AuraEnabled public Boolean inventoryExists{get;set;}
    }
    
    @AuraEnabled(cacheable=true)
    public static List<CustomMetaDataWrapper> getSelectedWarehouse(String ClickedWarehouse){
        List<NAC_WareHouseData__mdt> wareHouseConfigList=new List<NAC_WareHouseData__mdt>([SELECT external_url__c,Help_Text_needed__c,isActive__c,API_VALUE__c,Redirection__c,Warehouse_Name__c from NAC_WareHouseData__mdt where API_VALUE__c=:ClickedWarehouse]);
        List<CustomMetaDataWrapper> dataList=new List<CustomMetaDataWrapper>();
        system.debug('@@@@@@@@@@@wareHouseConfigList'+wareHouseConfigList);
        for(NAC_WareHouseData__mdt it:wareHouseConfigList){
           CustomMetaDataWrapper cm=new CustomMetaDataWrapper();
           cm.WarehouseName=it.Warehouse_Name__c;
           cm.Redirection=it.Redirection__c;
           cm.isActive=it.isActive__c;
           cm.apiValue=it.API_VALUE__c;
           cm.externalurl=it.external_url__c;
           cm.Help_Text_needed=it.Help_Text_needed__c;
           dataList.add(cm);
     }
        return dataList;
   }
    
   @AuraEnabled()
    public static WebCart updateTheCart(String communityId,String effectiveAccountId,String activeCartOrId,string ClickedWarehouse){
        String webstoreId = NAC_B2BUtils.resolveCommunityIdToWebstoreId(communityId);
        ConnectApi.CartSummary getTheCartDetails=ConnectApi.CommerceCart.getOrCreateActiveCartSummary(webstoreId,effectiveAccountId,activeCartOrId);
        WebCart wc=[SELECT Id, Name, AccountId,Warehouse_selected__c, WebStoreId FROM WebCart where id=:getTheCartDetails.cartId];
        wc.Warehouse_selected__c=ClickedWarehouse;
        update wc;
        
        return wc;
    }
    @AuraEnabled()
    public static string getCartDetails(String communityId,String effectiveAccountId,String activeCartOrId){
        String webstoreId = NAC_B2BUtils.resolveCommunityIdToWebstoreId(communityId);
        ConnectApi.CartSummary getTheCartDetails=ConnectApi.CommerceCart.getOrCreateActiveCartSummary(webstoreId,effectiveAccountId,activeCartOrId);
        WebCart wc=[SELECT Id, Name, AccountId,Warehouse_selected__c, WebStoreId FROM WebCart where id=:getTheCartDetails.cartId];
        return wc.Warehouse_selected__c;
    }
}