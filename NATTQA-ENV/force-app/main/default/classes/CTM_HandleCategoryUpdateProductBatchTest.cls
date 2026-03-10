@isTest
public class CTM_HandleCategoryUpdateProductBatchTest {
  
    @IsTest
    static void myUnitTest(){
        
        
        Product2 p = new Product2(Name='Test',IsActive=true,RecordTypeId=Schema.SobjectType.Product2.getRecordTypeInfosByDeveloperName().get('MX_Product').getRecordTypeId());
        insert p;

        WebStore testPp = new WebStore(Name = 'CTM Storefront');
        insert testPp;

        ProductCatalog pCat = new ProductCatalog(Name='CTM Storefront Catalog');
        insert pCat;

        WebStoreCatalog wsc = new WebStoreCatalog(SalesStoreId=testPp.Id,ProductCatalogId=pCat.Id);
        insert wsc;

        

        ProductCategory pc = new ProductCategory(Name='Todas las Partes',CatalogId=pCat.Id);
        insert pc;
        
        CommerceEntitlementPolicy cep = new CommerceEntitlementPolicy(Name ='CTM Storefront Products');
        insert cep;
        
        CommerceEntitlementProduct ce = new CommerceEntitlementProduct(policyId=cep.id,productId=p.id);
        insert ce;

        // Start the batch
        Test.startTest();
        CTM_HandleCategoryUpdateProductBatch batchInstance = new CTM_HandleCategoryUpdateProductBatch();
        Database.executeBatch(batchInstance);
        
        Database.executeBatch(new CTM_HandleCategoryUpdateProductBatch());
        String sch = '0 9 17 18 12 ?'; 
        System.schedule('CTM Handle Category Batch', sch ,new CTM_HandleCategoryUpdateProductBatch());
        Test.stopTest();
        
       
    }
}