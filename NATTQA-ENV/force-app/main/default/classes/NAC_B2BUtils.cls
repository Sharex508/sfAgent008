public without sharing class NAC_B2BUtils {
    
    public static Map<String, String> communityIdToWebStoreIdCache = new Map<String, String>();
    public static Map<String, ConnectApi.CartItemSortOrder> sortOrderCache = new Map<String, ConnectApi.CartItemSortOrder>();
    
    public static String resolveCommunityIdToWebstoreId(String communityId) {
        if (communityIdToWebStoreIdCache.containsKey(communityId)) {
            return communityIdToWebStoreIdCache.get(communityId);
        } else {
            String webStoreId = [SELECT WebStoreId FROM WebStoreNetwork WHERE NetworkId = :communityId LIMIT 1].WebStoreId;
            communityIdToWebStoreIdCache.put(communityId, webStoreId);
            return webStoreId;
        }
    }
    
    public static ConnectApi.CartItemSortOrder resolveSortParam(String sortParam) {
        if (sortOrderCache.isEmpty()) {
            for (ConnectApi.CartItemSortOrder sortOrder : ConnectApi.CartItemSortOrder.values()) {
                sortOrderCache.put(sortOrder.name(), sortOrder);
            }
        }
        return sortOrderCache.get(sortParam);
    }
    
    public static String returnCoreItemID(String cartItemId){
        CartItem crt=[SELECT Id, Product2Id FROM CartItem where id=:cartItemId];
        Product2 prWithCoreItem=[SELECT Id, Name, NATT_CoreItem_P_N__c FROM Product2 where id=:crt.Product2Id];
        if(prWithCoreItem.NATT_CoreItem_P_N__c != null){
            List<Product2> coreItemDetails = [select id,Name,NATT_P_N__c,NATT_Core__c  FROM Product2 where NATT_P_N__c=:prWithCoreItem.NATT_CoreItem_P_N__c and recordType.Name='NAC Products' and NATT_Core__c=true AND NATT_Branch_Plant_Warehouse__c ='ATL' LIMIT 1];
            if(!coreItemDetails.isEmpty()){
                return coreItemDetails[0].id;
            }else{
                return null;
            }
        }else{
            return null;
        }
    }
}