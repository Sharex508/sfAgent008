public class CTM_HandleCategoryUpdateProductBatch implements Database.Batchable<sObject>,Schedulable, Database.Stateful {
    public static Id catalogid= [SELECT id, Name FROM ProductCatalog WHERE Name = 'CTM Storefront Catalog'].id;
    public static Id defaultcategory=[SELECT Id,Name,CatalogId FROM ProductCategory where Name='Todas las Partes' AND CatalogId =:catalogid ].id;
    public static Id defaultEntitlementPolicy =[SELECT Id, Name from CommerceEntitlementPolicy where Name='CTM Storefront Products' limit 1].id;
    
     public Database.QueryLocator start(Database.BatchableContext BC){
     
	   String query = 'SELECT Id,NATT_P_N__c,CTM_Unit_Product__c,IsActive FROM Product2 WHERE RecordType.DeveloperName = \'MX_Product\' and CTM_Unit_Product__c=False and isactive=True ' ;
       return Database.getQueryLocator(query);
    }
    
    public void execute(Database.BatchableContext bc, List<Product2> scope){
        list<Product2> products = new list<Product2>();
        list<ProductCategoryProduct> prodCat = new list<ProductCategoryProduct>();
        List<ProductCategoryProduct> updateproductCategory=new List<ProductCategoryProduct>();
        Set<Id> productId = new Set<Id>();
        Set<Id> productWithCatId = new Set<Id>();
        Set<Id> entitlementProductMapWithId = new Set<Id>();
        set<Id> policyMap = new set<Id>();
        list<CommerceEntitlementProduct> insertEntitlementPolicyRecords = new list<CommerceEntitlementProduct>();
        for(product2 prod : scope){
            productId.add(prod.Id);
        }
     
            for(ProductCategoryProduct pdp : [SELECT Id,Product.Name,ProductCategoryId,ProductCategory.Name,ProductId FROM ProductCategoryProduct where ProductId IN:productId]){
                    productWithCatId.add(pdp.ProductId);
            }
        
       
        for(product2 pc :scope ){
        if(!productWithCatId.contains(pc.Id)){
            ProductCategoryProduct defaultproductcat=new ProductCategoryProduct();
             defaultproductcat.ProductId=pc.id;
           	 defaultproductcat.ProductCategoryId=defaultcategory;
             defaultproductcat.CurrencyIsoCode='USD';
              updateproductCategory.add(defaultproductcat); 
        }
        }
        
        
        for(CommerceEntitlementProduct cep : [SELECT Id, PolicyId, ProductId FROM CommerceEntitlementProduct WHERE  ProductId IN : productId]){
              entitlementProductMapWithId.add(cep.ProductId);
        }
        
        for(product2 pc :scope){
        if(!entitlementProductMapWithId.contains(pc.Id)){
            CommerceEntitlementProduct obj = new CommerceEntitlementProduct();
            obj.PolicyId = defaultEntitlementPolicy;
            obj.ProductId = pc.Id;
            insertEntitlementPolicyRecords.add(obj);
        }
        }   
        
        if(!insertEntitlementPolicyRecords.isEmpty()){
            insert insertEntitlementPolicyRecords;
        }
    
        if(!updateproductCategory.isEmpty()){
			insert updateproductCategory; 
           
        }
        
        
    }
    public void finish(Database.BatchableContext bc){
        List<WebStore> wsList = new List<WebStore>([SELECT Id,Name FROM WebStore WHERE Name =: Label.CTM_Store_Name]);
       if(!wsList.isEmpty() && !Test.isRunningTest()){
            ConnectApi.CommerceSearchSettings.createCommerceSearchIndex(wsList.get(0).Id);
        }
    }
     public void execute(SchedulableContext sc){
        Database.executeBatch(new CTM_HandleCategoryUpdateProductBatch());
    }
        
    

}