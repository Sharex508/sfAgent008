/*************************************************************************************************
Apex Class Name : NAC_HandleCategoryUpdateProductBatch
Version : 1.0
Created Date : 30/10/2023
Function : To automatically assign the updated category ( coming from JDE) to product and delete the existing category.

Modification Log:
-------------------------------------------------------------------------------------------------------------------------------------------------
* Developer                                Date                                Description
* -----------------------------------------------------------------------------------------------------------------------------------------------
* Poonam Yadav        		             30/10/2023                        Initial creation        
*************************************************************************************************/

public class NAC_HandleCategoryUpdateProductBatch implements Database.Batchable<sObject>, Database.Stateful{
    
      
    public static Id catalogid= [SELECT id, Name FROM ProductCatalog WHERE Name = 'NA Containers Marketplace Catalog'].id;
    public static Id defaultcategory=[SELECT Id,Name,CatalogId FROM ProductCategory where Name='OTHERS' AND CatalogId =:catalogid ].id;
    public static Id perPartscategory=[SELECT Id,Name,CatalogId FROM ProductCategory where Name='PERFORMANCE PARTS' AND CatalogId =:catalogid].id;
    
      
     public Database.QueryLocator start(Database.BatchableContext BC){
     
        String query = 'SELECT Id,NATT_P_N__c, NAC_Cat_Cde6_Code__c,NAC_Cat_Cde6_Description__c,NAC_Cat_Cde7_Code__c,NAC_Cat_Code7_Description_Family__c  FROM Product2 WHERE RecordType.DeveloperName  = \'NAC_Products\' AND NATT_Branch_Plant_Warehouse__c = \'ATL\' AND LastModifiedDate=TODAY' ;
        return Database.getQueryLocator(query);
    }
    
    
    public void execute(Database.BatchableContext bc, List<Product2> scope){
        List<Product2> products = new List<Product2>();
        Set<Id> productIds = new Set<Id>();
        List<Product2> productDetails=new List<Product2>();
		Set<id> categoryId= new Set<id>();
		Map<id, string> prodcat6Namemap=new Map<id,string>();
        Map<id, string> prod7catNameMap=new Map<id,string>();
		List<Id> existingCategoryList=new List<Id>();
		Map<id,id> prodcatmap=new Map<id,id>();
		Map<String,Id> catnameidMap=new Map<String,Id>();
		Map<String,Id> newCatNameId=new Map <string,id>();
		id newcatId ;
        id newParentcatId;
        List<Id> deletecatpodid=new List<Id>();
        List<ProductCategoryProduct> prodCategory=new List<ProductCategoryProduct>() ;
		List<ProductCategoryProduct> updateproductCategory=new List<ProductCategoryProduct>();
        Map<id,id> newParentcatMap =new Map<id,id>();
        Map<id,String> exisParentcatNameMap =new Map<id,String>();
        String newParentCategory;
       Map<string,id> newparentprodcategory= new  Map<string,id>();
       List<String> newUpdateparentCategory =new List<String>();
       Map <Id,id> Insertedcategories=new Map <id,id>();
       Map<string,id> newParentcatrynameMap=new Map<string,id> (); 
       Map<id,string>  prodParentcatchangeNameMap=new Map<id,string>();
       List <ProductCategory> updateparentcategory =new List<ProductCategory>();
       List <ProductCategory> updateonlyParentCat= new List <ProductCategory>();
       Map<id,id> exisParentonlycatMap=new Map<id,id>();
       Map<id,String> exisParentonlycatNameMap=new  Map<id,String>();
       Map<id,String> prodCat6Detail=new Map<id,String>();
       Map<id,String> prodCat7Detail=new Map<id,String>();
       Map<String,Id> defaultcatMap=new Map<String,Id>();
        
        
        for(Product2 prod : scope){
            products.add(prod);
            productIds.add(prod.id);
            prodCat6Detail.put(prod.Id,prod.NAC_Cat_Cde6_Description__c);
            prodCat7Detail.put(prod.Id,prod.NAC_Cat_Code7_Description_Family__c); 
          } 
   
        if(!products.isEmpty()){   
           for( ProductCategoryProduct pdp: [SELECT Id,Product.NAC_Cat_Cde6_Description__c,Product.NAC_Cat_Code7_Description_Family__c,Product.Name,ProductCategoryId,ProductCategory.Name,ProductId FROM ProductCategoryProduct where ProductId IN:productIds]){
				 prodCategory.add(pdp);
       		 } 
            	 for(Productcategory prdcat: [Select Id ,name from ProductCategory where name IN:prodCat6Detail.values()]){
                 	defaultcatMap.put(prdcat.name,prdcat.id);
                 }
    	 } 
        
         
        
         if(!prodCategory.isEmpty()){
		for (ProductCategoryProduct pc: prodCategory){
      			 categoryId.add(pc.ProductCategoryId);
    			 prodcat6Namemap.put(pc.ProductCategoryId,pc.Product.NAC_Cat_Cde6_Description__c);
                 prod7catNameMap.put(pc.ProductCategoryId,pc.Product.NAC_Cat_Code7_Description_Family__c);
                 prodcatmap.put(pc.ProductCategoryId,pc.ProductId); 
                 prodParentcatchangeNameMap.put(pc.ProductCategoryId,pc.Product.NAC_Cat_Code7_Description_Family__c);
   
			}
        }
         
         
        
        for(Product2 pc: products) {
            if((prodCategory.isEmpty())&&(pc.NAC_Cat_Cde6_Description__c!=null )) {
                 ProductCategoryProduct defaultproductcat=new ProductCategoryProduct();
                 defaultproductcat.ProductId=pc.Id;
                if(defaultcatMap.containsKey(pc.NAC_Cat_Cde6_Description__c)){
           	     defaultproductcat.ProductCategoryId= defaultcatMap.get(pc.NAC_Cat_Cde6_Description__c);
                   }
                 defaultproductcat.CurrencyIsoCode='USD';
                updateproductCategory.add(defaultproductcat);
            }
            
       		 if((prodCategory.isEmpty())&&(pc.NAC_Cat_Cde6_Description__c==null )) {
            
             ProductCategoryProduct defaultproductcat=new ProductCategoryProduct();
             defaultproductcat.ProductId=pc.Id;
           	 defaultproductcat.ProductCategoryId=defaultcategory;
             defaultproductcat.CurrencyIsoCode='USD';
              updateproductCategory.add(defaultproductcat);  // insert assign default category
            
        }
            
    }
     
     List<ProductCategory> newparentcategoryname=[SELECT Id,Name FROM ProductCategory where Name IN:prodCat7Detail.values()];
          for (ProductCategory prdcat:newparentcategoryname ){
             newParentcatrynameMap.put(prdcat.Name, prdcat.Id);
         }
        
      	List<ProductCategory> category=[SELECT Id,Name,ParentCategoryId FROM ProductCategory where id IN:categoryId];
       for (ProductCategory prdcat:category ){
            exisParentonlycatMap.put(prdcat.id, prdcat.ParentCategoryId);
        }
        
        List<ProductCategory> parentCategory=[SELECT Id,Name FROM ProductCategory where id IN:exisParentonlycatMap.values()];
        if(!parentCategory.isEmpty()){
            for(ProductCategory prntcat: parentCategory){
                exisParentonlycatNameMap.put(prntcat.Id, prntcat.Name);
            }
            
        }
                                             
     for (ProductCategory cat: category){
         if(prodcat6Namemap.containskey(cat.id) ){
            if(prodcat6Namemap.get(cat.id)!=null){
     			 if(prodcat6Namemap.get(cat.id)!=cat.Name){  
            		 existingCategoryList.add(cat.id);// existing  category that needs to be updated 
                     deletecatpodid.add(prodcatmap.get(cat.id));
                     system.debug('productid cat to be unassigned  '+ deletecatpodid); // product id of existing Category 
            		 catnameidMap.put( prodcat6Namemap.get(cat.id),cat.ParentCategoryId); // New Category name and parent id
       			  }
                   
   			 }
             if(exisParentonlycatMap.containskey(cat.id)){
                 
                 if(exisParentonlycatNameMap.get(exisParentonlycatMap.get(cat.id))!=prodCat7Detail.get(prodcatmap.get(cat.id))){
                       system.debug('parents not same exi '+ exisParentonlycatNameMap.get(exisParentonlycatMap.get(cat.id)));
                     if(prodCat7Detail.get(prodcatmap.get(cat.id))=='OE'){
                      	cat.ParentCategoryId=perPartscategory ;
                     }else{
                      cat.ParentCategoryId=newParentcatrynameMap.get(prodCat7Detail.get(prodcatmap.get(cat.id)));
                     }
                     
                      updateonlyParentCat.add(cat); //update  parent id also
                 }
                 
             }
             
                 }                   
         
            }

    	 if(!catnameidMap.isEmpty()){
			for(ProductCategory newCa: [SELECT Id,Name,ParentCategoryId FROM ProductCategory where Name IN:catnameidMap.keyset() ]){
          		 newCatNameId.put(newCa.Name,newCa.Id); 
		}
	}
     system.debug(' new updated category '+ newCatNameId);
                                      
     for (ProductCategoryProduct pcp: prodCategory){
    		 if(prodcat6Namemap.containskey(pcp.ProductCategoryId)){
        	 String newCatname= prodcat6Namemap.get(pcp.ProductCategoryId);
       			 if(newCatNameId.containsKey(newCatname) && deletecatpodid.contains(pcp.ProductId)) {
            	 	newcatId= newCatNameId.get(newCatname);
           			ProductCategoryProduct newproductcat=new ProductCategoryProduct();
            		newproductcat.ProductId=prodcatmap.get(pcp.ProductCategoryId);
           		    newproductcat.ProductCategoryId=newcatId;
           			newproductcat.CurrencyIsoCode='USD';
            		updateproductCategory.add(newproductcat) ;
                 }                      
             } 
         
       
        }
        
        try{
            
          system.debug('updatedcategoryList-->'+ existingCategoryList);
          system.debug('deletecatpodid-->'+ deletecatpodid);   
	 if(!existingCategoryList.isEmpty()){
		List<ProductCategoryProduct>  deleteexistingcat=[Select Id,ProductCategoryId,ProductId from ProductCategoryProduct where ProductCategoryId IN :existingCategoryList AND ProductId IN:deletecatpodid];
         system.debug('deleteexistingcat size-->'+ deleteexistingcat.size());
   		 if(deleteexistingcat!=null){
        	 delete deleteexistingcat; // Unassigning the existing category if not same.
    		}
		}

		if(!updateproductCategory.isEmpty()){
			insert updateproductCategory; // assigning the new Category if not same .
        }
           
		 system.debug('updateproductCategory size-->'+ updateproductCategory);
         system.debug('updateproductCategory size-->'+ updateproductCategory.size());
            
        if(!updateonlyParentCat.isEmpty()){
                system.debug(' updateonlyParentCat '+ updateonlyParentCat);
                system.debug(' updateonlyParentCat '+ updateonlyParentCat.size());
                update updateonlyParentCat;// updating parent category if not same.
            } 
            
         
            
			 
        }catch(Exception e){
                System.debug('Error is--- '+e.getMessage());
            }
    }
    
    
     public void finish(Database.BatchableContext bc){
       List<WebStore> wsList = new List<WebStore>([SELECT Id,Name FROM WebStore WHERE Name =: Label.NAOCAP_Store_Name]);
       if(!wsList.isEmpty() && !Test.isRunningTest()){
            ConnectApi.CommerceSearchSettings.createCommerceSearchIndex(wsList.get(0).Id);
        }
    }
    

}