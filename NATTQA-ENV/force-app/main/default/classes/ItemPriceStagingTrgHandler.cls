public without sharing class ItemPriceStagingTrgHandler {
    public static void onAfterInsert(List<NATT_ItemPriceStaging__c> trgNew){
        Set<Id> productIdSet = new Set<Id>();
        Set<Id> ppgProductIdSet = new Set<Id>();
        for(NATT_ItemPriceStaging__c ips : trgNew){
            if(ips.NATT_Product__c!=null){
                productIdSet.add(ips.NATT_Product__c);
            }
        }


        for(Product2  p : [SELECT Id FROM Product2 WHERE Id in :productIdSet AND RecordType.DeveloperName='NATT_Products']){
            ppgProductIdSet.add(p.Id);
        }

        Set<Id> existingCategoryProductSet = new Set<Id>();
        List<ProductCategory> pcList = new List<ProductCategory>([SELECT Id FROM ProductCategory WHERE Name='Products']);
        ProductCategory pc;
        if(!pcList.isEmpty()){
            pc=pcList.get(0);
            for(ProductCategoryProduct pcp : [SELECT Id,ProductId FROM ProductCategoryProduct WHERE ProductId in :ppgProductIdSet AND ProductCategoryId=:pc.Id]){
                existingCategoryProductSet.add(pcp.ProductId);
            }
            List<ProductCategoryProduct> pcpList = new List<ProductCategoryProduct>();
            for(Id pId : ppgProductIdSet){
                if(!existingCategoryProductSet.contains(pId)){
                    pcpList.add(new ProductCategoryProduct(ProductCategoryId=pc.Id,ProductId=pId));
                }
            }
    
            if(!pcpList.isEmpty()){
                insert pcpList;
            }    
        }
    }
}