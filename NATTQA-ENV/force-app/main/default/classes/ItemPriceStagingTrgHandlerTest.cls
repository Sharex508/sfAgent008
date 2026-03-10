@IsTest
private class ItemPriceStagingTrgHandlerTest {
    @IsTest
    static void myUnitTest(){
        Product2 p = new Product2(Name='Test',IsActive=true,RecordTypeId=Schema.SobjectType.Product2.getRecordTypeInfosByDeveloperName().get('NATT_Products').getRecordTypeId());
        insert p;

        WebStore testPp = new WebStore(Name = 'Test Performance Parts');
        insert testPp;

        ProductCatalog pCat = new ProductCatalog(Name='Test Cat');
        insert pCat;

        WebStoreCatalog wsc = new WebStoreCatalog(SalesStoreId=testPp.Id,ProductCatalogId=pCat.Id);
        insert wsc;

        

        ProductCategory pc = new ProductCategory(Name='Products',CatalogId=pCat.Id);
        insert pc;

        NATT_ItemPriceStaging__c ips = new NATT_ItemPriceStaging__c(NATT_Product__c=p.Id);
        insert ips;
    }
}