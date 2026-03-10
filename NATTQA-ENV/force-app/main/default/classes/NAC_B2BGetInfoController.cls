public without sharing class NAC_B2BGetInfoController {
    
    @AuraEnabled 
    public static ConnectApi.ProductOverviewCollection getProducts(String communityId, String effectiveAccountId, String displayType, Integer numofTiles, String categoryId){
        Map<Id,ConnectApi.ProductOverview> productMap = new Map<Id,ConnectApi.ProductOverview>();
        String webstoreId = NAC_B2BUtils.resolveCommunityIdToWebstoreId(communityId);
        Set<String> ProductIdSet = new Set<String>();
        String query;
        String userId = UserInfo.getUserId();
        if(displayType == 'displayRecentlyOrderedProducts'){
            String wareHouse = 'ATL';
            try{
                ConnectApi.CartSummary cartSum = ConnectApi.CommerceCart.getCartSummary(webstoreId,effectiveAccountId, 'active');
                List<WebCart> activeCart = [SELECT Id, Warehouse_selected__c FROM WebCart WHERE ID =: cartSum.cartId ];
                List<string> invalidStockingTypeForNLO = Label.NAOCAP_NLO_PLP_Stocking_Type.split(',');
                if(!activeCart.isEmpty()){
                    wareHouse = activeCart[0].Warehouse_selected__c;
                }
            }catch(Exception e){
                wareHouse = 'ATL';
            }
            query = 'SELECT Product2Id FROM OrderItem where Order.OwnerId =: userId AND Order.SalesStoreId =: webstoreId AND Product2.NATT_Core__c = FALSE AND TypeCode = \'Product\'';
            if(!Test.isRunningTest()){
                query += wareHouse == 'ANA' ? ' AND (Product2.NAOCAP_Signal_Code_ANA__c != \'NLO\' OR Product2.NAOCAP_Stocking_Type_UTC_ANA__c NOT IN : invalidStockingTypeForNLO)' : wareHouse == 'CHI' ? ' AND (Product2.NAOCAP_Signal_Code_CHI__c != \'NLO\' OR Product2.NAOCAP_Stocking_Type_UTC_CHI__c NOT IN : invalidStockingTypeForNLO)' : wareHouse == 'PAN' ? ' AND (Product2.NAOCAP_Signal_Code_PAN__c != \'NLO\' OR Product2.NAOCAP_Stocking_Type_UTC_PAN__c NOT IN : invalidStockingTypeForNLO)' : ' AND (Product2.NATT_SignalCode__c != \'NLO\' OR Product2.NAC_Stocking_Type_UTC__c NOT IN : invalidStockingTypeForNLO)';
            }
            if(categoryId != null){ 
                query += ' AND Product2Id IN (SELECT ProductId FROM ProductCategoryProduct WHERE (ProductCategoryId =: categoryId OR ProductCategory.ParentCategoryId =: categoryId OR ProductCategory.ParentCategory.ParentCategoryId =: categoryId))';
            }
            query += ' ORDER BY CreatedDate DESC';
        }
        query += ' LIMIT :numofTiles';
        System.debug('query '+query);
        System.debug('query res: '+Database.query(query));
        for (OrderItem item: Database.query(query)) {
            system.debug('item'+item);
            ProductIdSet.add(item.Product2Id);
        }
        List<String> ProductIdList = new List<String>(ProductIdSet);
        ConnectApi.ProductOverviewCollection prodCollection;
        if(!ProductIdSet.isEmpty()){
            prodCollection = ConnectApi.CommerceCatalog.getProducts(webstoreId, effectiveAccountId, ProductIdList, new List<String>(), new List<String>(), false, false);
            for(ConnectApi.ProductOverview prod : prodCollection.products){
                productMap.put(prod.Id,prod);
            }
            prodCollection.products.clear();
            for(String item : ProductIdList){
                if(productMap.containsKey(item)){
                    prodCollection.products.add(productMap.get(item));
                }
            } 
        }
        return prodCollection;
    }
    
    @AuraEnabled
    public static ProdSearchResults recentlyOrderdProducts(String communityId, String effectiveAccountId, String categoryId){
        ConnectApi.ProductOverviewCollection prodCollection = getProducts(communityId, effectiveAccountId, 'displayRecentlyOrderedProducts', 20, categoryId);
        ProdSummaryCollection psm = new ProdSummaryCollection();
        if(prodCollection != null){
            for(ConnectApi.ProductOverview prod : prodCollection.products){
                psm.products.add(new ProdSummary(prod));
            }
        }
        psm.total = 1;
        ProdSearchResults psr = new ProdSearchResults();
        psr.locale = 'en_US';
        psr.productsPage = psm;	
        return psr;
    }
    
    public static String guestEffectiveAccount(){
        String accountIdParameter = '';
        try {
            GuestBuyerProfile guestEffectiveAcc = [SELECT id from GuestBuyerProfile where Name =: Label.NAC_Guest_Buyer_Group  LIMIT 1];
            accountIdParameter = '?effectiveAccountId='+String.valueOf(guestEffectiveAcc?.Id);
        } catch (Exception e) {
            
        }
        return accountIdParameter;
    }
    
    @AuraEnabled
    public static ProductCategoryWrapper getProductCategory(String communityId){
        ProductCategoryWrapper pcWrap = new ProductCategoryWrapper();
        String webstoreId = NAC_B2BUtils.resolveCommunityIdToWebstoreId(communityId);
		List<ProductCategory> pcList;
		try{
            pcList = [SELECT Id, Name, ParentCategoryId FROM ProductCategory WHERE CatalogId IN (SELECT ProductCatalogId from WebStoreCatalog where SalesStoreId =: webstoreId)  ORDER BY SortOrder];
			if(!pcList.isEmpty()){
				for(ProductCategory pc :[SELECT Id, Name, ParentCategoryId FROM ProductCategory WHERE CatalogId IN (SELECT ProductCatalogId from WebStoreCatalog where SalesStoreId =: webstoreId)  ORDER BY SortOrder]){
            if(pc.ParentCategoryId == null){
                pcWrap.topMostParentCategoryId = pc.Id;
            }else{
                pcWrap.productCategoryList.add(pc);
            }
        }
			}
        }catch(System.QueryException qe){
            System.debug(qe.getMessage());
        }
		
        return pcWrap;
    }
    
    @AuraEnabled
    public static string getProductPath(String communityId, String productCategoryId){
        string path = '/category';
        String webstoreId = NAC_B2BUtils.resolveCommunityIdToWebstoreId(communityId);
        ConnectApi.ProductCategoryPath categoryPathList = ConnectApi.CommerceCatalog.getProductCategoryPath(webstoreId,productCategoryId);
        for(ConnectApi.ProductCategoryData categoryPath : categoryPathList.path){
            if(categoryPath.name != null){
                path = path + '/' + categoryPath.name;
            }
        }
        path = path + '/' + productCategoryId;
        return path.replace(' ','-');
    }
    
    @AuraEnabled
    public static List<staticResourceWrapper> getStaticResourceData(){
        List<StaticResourceWrapper> srWrapper = new List<StaticResourceWrapper>();
        try{
			StaticResource static_resource = [SELECT Id, Name, SystemModStamp FROM StaticResource WHERE Name = 'carouselImages'  LIMIT 1];
        boolean isGuest = UserInfo.getUserType() == 'Guest' ? true : false;
        if(!isGuest){
            String text_file_ref = '/resource/'
                + String.valueOf(((DateTime)static_resource.get('SystemModStamp')).getTime())
                + '/' 
                + static_resource.get('Name')
                + '/Description.txt';
            String texth2_file_ref = '/resource/'
                + String.valueOf(((DateTime)static_resource.get('SystemModStamp')).getTime())
                + '/' 
                + static_resource.get('Name')
                + '/Descriptionh2.txt';    
            String button_file_ref = '/resource/'
                + String.valueOf(((DateTime)static_resource.get('SystemModStamp')).getTime())
                + '/' 
                + static_resource.get('Name')
                + '/Buttons.txt';    
             system.debug('text_file_ref'+ text_file_ref);
             PageReference file_ref = new PageReference(text_file_ref);
             system.debug('file_ref'+ file_ref);
             // PageReference file_ref = new PageReference('https://carrier-global--nattcapdev.sandbox.my.site.com/NAContainersMarketplace/resource/1688125405000/carouselImages/Description.txt');
            // PageReference file_ref = ;
           // system.debug('text_file_ref'+ text_file_ref);
            //PageReference file_ref = new PageReference('/resource/1688125405000/carouselImages');
            String res_json_body; 
            res_json_body = Test.isRunningTest()?String.valueOf('Unit.Test,Unit.Test2,Unit.Test3'):file_ref.getContent().toString();
            List<String> imageDescription = res_json_body.split(',');
            PageReference fileh2_ref = new PageReference(texth2_file_ref);
            String resh2_json_body;        
            resh2_json_body = Test.isRunningTest()?String.valueOf('Unit.Test,Unit.Test2,Unit.Test3'):fileh2_ref.getContent().toString();
            List<String> imageDescriptionh2 = resh2_json_body.split(',');
            //CXREF- 3443 - Start
            PageReference but_file_ref = new PageReference(button_file_ref);
            String res_button_json_body;        
            res_button_json_body = Test.isRunningTest()?String.valueOf('Unit.Test;123,Unit.Test2;333,Unit.Test3;444'):but_file_ref.getContent().toString();
            List<String> buttonDescription = res_button_json_body.split(',');
            for(Integer i=1;i<=imageDescription.size();i++){
                StaticResourceWrapper wrapper = new StaticResourceWrapper();
                String url_file_ref = '/resource/'
                    + String.valueOf(((DateTime)static_resource.get('SystemModStamp')).getTime())
                    + '/' 
                    + static_resource.get('Name')
                    + '/Image'+i+'.jpg';
                wrapper.imagePath = url_file_ref;
                wrapper.description = imageDescription[i-1];
                wrapper.descriptionh2 = imageDescriptionh2[i-1];
                //CXREF- 3443 - Start
                List<String> buttons= buttonDescription[i-1].split(';');
                wrapper.buttonlabel=buttons[0]; 
                wrapper.buttonurl=buttons[1];
                //if(buttons[0]=='Bulk Upload' && UserInfo.getUserType() =='Guest'){
                //    wrapper.buttonurl='/NAContainersMarketplace/s/login';
                //}else{
                //    wrapper.buttonurl='/NAContainersMarketplace/s'+buttons[1];
                //}
                //CXREF- 3443 - End
                srWrapper.add(wrapper);
            }
        }else{
            StaticResourceWrapper wrapper = new StaticResourceWrapper();
            String url_file_ref = '/resource/'
                + String.valueOf(((DateTime)static_resource.get('SystemModStamp')).getTime())
                + '/' 
                + static_resource.get('Name')
                + '/Image'+1+'.jpg';
            wrapper.imagePath = url_file_ref;
            wrapper.description = 'Shop All Products';
            wrapper.descriptionh2 = 'Browse our catalogue to find the parts you need';
            wrapper.buttonlabel = 'Shop all products';
            wrapper.buttonurl = Label.NAOCAP_Shop_All_Products_URL;
            srWrapper.add(wrapper);
        }
		}catch(System.QueryException qe) {
            System.debug(qe.getMessage());
        }
        return srWrapper;
    }
    
    @AuraEnabled(cacheable=true)
    public static List<PriceBookWrapperinnerclass> fetchListCatalog() {
        set<ID> Product2Id=new set<ID>();
		User userDetail;
       List<PriceBookWrapperinnerclass> priceBookList=new List<PriceBookWrapperinnerclass>();
        List<PricebookEntry> prodData = new List<PricebookEntry>();
        List<String> externalUserItemCode = Label.NAOCAP_External_User_Item_Code.split(',');
        Id containerStoreId;
        String customerType;
        WebStoreBuyerGroup storeBuyerGroup;
		try{	
            userDetail = [SELECT contactid, contact.AccountId, isportalenabled FROM User WHERE Id =: UserInfo.getUserId()  LIMIT 1];
            containerStoreId = [SELECT id from Webstore WHERE Name =: Label.NAOCAP_Store_Name LIMIT 1]?.Id;
            Boolean hasCustomPermission = FeatureManagement.checkPermission ('UCP_Download_Pricebook_Access');
            list<PermissionSetAssignment> PermissionSetLicenseAssign = [SELECT Id, PermissionSet.Name, AssigneeId from PermissionSetAssignment where  AssigneeId =:UserInfo.getUserId() and (PermissionSet.Name = 'NAOCP_Commerce_Finance' or PermissionSet.Name = 'NAOCP_Commerce_Parts_Ordering') limit 1];
            boolean licenceAssigned = false;
            if(PermissionSetLicenseAssign.size() > 0){
                licenceAssigned = true;
            }
            if(userDetail.isportalenabled && (!hasCustomPermission ||licenceAssigned ) ){
				storeBuyerGroup = [SELECT BuyerGroupId, BuyerGroup.NAC_Type__c from WebStoreBuyerGroup WHERE WebStoreId =: containerStoreId AND BuyerGroupId IN (SELECT BuyerGroupId FROM BuyerGroupMember WHERE BuyerId =: userDetail.contact.AccountId)  LIMIT 1];
            customerType = storeBuyerGroup.BuyerGroup.NAC_Type__c;
            system.debug('Raj2-'+ customerType); 
        }
        if(userDetail.isportalenabled &&(hasCustomPermission || Label.NAOCAP_External_Customer_Group.contains(customerType))){ 
           
            //For external customers we need to filter products on Item code
            prodData=[SELECT CurrencyIsoCode,Name,NATT_Effective_Date__c,Pricebook2Id,Product2Id,Product2.NATT_Branch_Plant_Warehouse__c,Product2.id,Product2.NATT_Weight__c,Product2.ProductCode,Product2.NATT_SignalCode__c,
                      Product2.NATT_Height__c,Product2.NATT_Width__c,Product2.NATT_Discount_Code__c,Product2.NAC_Stocking_Type_UTC__c,Product2.NATT_Length__c,Product2.NAC_Country_of_Origin_COO__c,Product2.NAC_HTSUS__c,
                      Product2.NATT_P_N__c,Product2.Name, Product2.NATT_Core__c ,Product2.NATT_UOM_Conversion__c,Product2.NATT_CoreItem_P_N__c,
						  ProductCode,UnitPrice,UseStandardPrice, Product2.NAC_Line_Of_Business__c FROM PricebookEntry WHERE Pricebook2.Name = 'NA Containers Marketplace Strikethrough Price Book' AND Product2.NATT_ItemPriceGroup__c IN:externalUserItemCode ];
        }else{
            prodData=[SELECT CurrencyIsoCode,Name,NATT_Effective_Date__c,Pricebook2Id,Product2.NATT_Branch_Plant_Warehouse__c,Product2Id,Product2.id,Product2.NATT_Weight__c,Product2.ProductCode,Product2.NATT_SignalCode__c,
                      Product2.NATT_Height__c,Product2.NATT_Width__c,Product2.NATT_Discount_Code__c,Product2.NAC_Stocking_Type_UTC__c,Product2.NATT_Length__c,Product2.NAC_Country_of_Origin_COO__c,Product2.NAC_HTSUS__c,
                      Product2.NATT_P_N__c,Product2.Name, Product2.NATT_Core__c ,Product2.NATT_UOM_Conversion__c,Product2.NATT_CoreItem_P_N__c,
						  ProductCode,UnitPrice,UseStandardPrice, Product2.NAC_Line_Of_Business__c FROM PricebookEntry WHERE Pricebook2.Name = 'NA Containers Marketplace Strikethrough Price Book' ];
			}
		} catch(System.QueryException qe) {
            System.debug('error-'+qe.getLineNumber() + ' - ' +qe.getMessage());
        }
        Map<Id,PricebookEntry> ProdDataMap = new Map<Id,PricebookEntry>();
        for(PricebookEntry pe:prodData){
            ProdDataMap.put(pe.product2Id,pe);
        }
        for (Integer i = 0; i < prodData.size(); i++){
            
            Product2Id.add(prodData[i].Product2Id);
            
        }
        //getting products with core
        List<Product2> prWithCoreItem=new List<Product2>([SELECT Id, Name, NATT_CoreItem_P_N__c,NATT_CorePrice__c,NATT_Branch_Plant_Warehouse__c  FROM Product2 where Id IN:Product2Id AND NATT_CoreItem_P_N__c!=null and NATT_Branch_Plant_Warehouse__c ='ATL' ]);
        set<string> coreItemPNset=new set<string>();
        for(Product2 prod:prWithCoreItem){
            coreItemPNset.add(prod.NATT_CoreItem_P_N__c);
        }
        //getting the details of core with part number as key and storing in the map//
        system.debug('coreItemPNset@@@ '+coreItemPNset);
        MAp<String,Product2> mapOfCorePrDetails=new MAp<String,PRoduct2>();
		try{
			for(Product2 prIterator:[select id,ProductCode,Name,NATT_P_N__c,NAOCAP_Not_Orderable__c,NATT_CorePrice__c  from product2 where NATT_P_N__c IN :coreItemPNset and NATT_Branch_Plant_Warehouse__c ='ATL' AND recordtype.Name='NAC Products' ]){
            mapOfCorePrDetails.put(prIterator.NATT_P_N__c, prIterator);
        }
        system.debug('mapOfCorePrDetails@@@ '+mapOfCorePrDetails);
		}catch(System.QueryException qe) {
            System.debug(qe.getMessage());
        }
        Map<ID,NATT_AlternativeItem__c> mapOfproductSuperseded =new Map<Id,NATT_AlternativeItem__c>();
		try{
        for(NATT_AlternativeItem__c nAc:[SELECT Id, NATT_AlternativeItem__c,NATT_ProductItem__r.NAC_Stocking_Type_UTC__c, NATT_ProductItem__r.NATT_SignalCode__c , NATT_ProductItem__r.ProductCode,NATT_ProductItem__r.Name,NATT_AlternativeItem__r.Name,
                                         NATT_AlternativeItem__r.ProductCode,NATT_AlternativeItem__r.NATT_CoreItem_P_N__c ,NATT_ProductItem__r.NATT_P_N__c,NATT_AlternativeItem__r.NATT_P_N__c FROM NATT_AlternativeItem__c WHERE 
                                         NATT_ProductItem__c=:Product2Id AND NATT_ProductItem__r.NATT_SignalCode__c='S2'  ORDER BY NATT_EffectiveDate__c DESC]){
                                             if(!mapOfproductSuperseded.containsKey(nAc.NATT_ProductItem__c)){
                                                 mapOfproductSuperseded.put(nAc.NATT_ProductItem__c,nAc);
                                             }
                                         }
		}catch(System.QueryException qe) {
            System.debug(qe.getMessage());
        }
        Set<String> signalVal = new Set<String>();
        signalVal.add('A');
        signalVal.add('BY2');
        signalVal.add('FIN');
        signalVal.add('PRC');
        signalVal.add('S1');
        
        Set<String> signalValsecond = new Set<String>();
        signalValsecond.add('N/A');
        signalValsecond.add('OBS');
        
        Set<String> signValthird = new Set<String>();
         signValthird.add('NSI');
         signValthird.add('A');
         signValthird.add('BY2');
         signValthird.add('PRC');
         signValthird.add('FIN');
         signValthird.add('S1');
        
        Set<String> signValfourth = new Set<String>();
         signValfourth.add('S2');        
         signValfourth.add('N/A');
         signValfourth.add('OBS'); 
         signValfourth.add('NSU'); 
        
        for(integer i=0;i<prodData.size();i++){
            PriceBookWrapperinnerclass pbWrapper = new PriceBookWrapperinnerclass();
            pbWrapper.Superseded = ' ';
            pbWrapper.PartNumber = ' ';  
            pbWrapper.PKG =0;
            pbWrapper.AlternatePart = '';
            pbWrapper.Weight = 0;
            pbWrapper.Length = 0;
            pbWrapper.core_Reference=' ';
            pbWrapper.lineOfBusiness='';
            pbWrapper.Width = 0;
            pbWrapper.Height = 0;
            pbWrapper.COO = ''; 
            pbWrapper.HTSUS = ''; 
            pbWrapper.SignalCode ='';    
            pbWrapper.Description = prodData[i].Name;
            pbWrapper.Price =0;
            pbWrapper.Each_price =0; 
            //pbWrapper.totalproductPrice=0;
            pbWrapper.coreListPrice='';
            
            if(mapOfproductSuperseded.containsKey(prodData[i].Product2Id)){
                pbWrapper.Superseded = mapOfproductSuperseded.get(prodData[i].Product2Id).NATT_ALternativeItem__r.ProductCode;
            }
            
            /*Signal Code Updated Logic CXREF- 3820*/
            if(signalVal.contains(prodData[i].Product2.NATT_SignalCode__c))
                pbWrapper.SignalCode ='A';
            if(prodData[i].Product2.NATT_SignalCode__c == 'NLO' && prodData[i].Product2.NAC_Stocking_Type_UTC__c == 'U')
                pbWrapper.SignalCode ='A';
            if(prodData[i].Product2.NATT_SignalCode__c == 'NLO' && prodData[i].Product2.NAC_Stocking_Type_UTC__c == 'O')
                pbWrapper.SignalCode ='NLO';
            if(signalValsecond.contains(prodData[i].Product2.NATT_SignalCode__c))
                pbWrapper.SignalCode ='NLO';
            if(prodData[i].Product2.NATT_SignalCode__c == 'NSI')
                pbWrapper.SignalCode ='NSI';
            if(prodData[i].Product2.NATT_SignalCode__c == 'NSU' || prodData[i].Product2.NATT_SignalCode__c == 'NEW')
                pbWrapper.SignalCode ='NSU';
            
            if(prodData[i].Product2.ProductCode != null){
                pbWrapper.PartNumber = prodData[i].Product2.ProductCode;
            }
            /*packaging*/
            if(prodData[i].Product2.NATT_UOM_Conversion__c != null){
                pbWrapper.PKG=prodData[i].Product2.NATT_UOM_Conversion__c;
            }
            //superseded
            if(mapOfproductSuperseded.get(prodData[i].Product2Id) != null){
                system.debug('mapOfproductSuperseded'+mapOfproductSuperseded);
                if(mapOfproductSuperseded.get(prodData[i].Product2Id).NATT_ProductItem__r.NATT_P_N__c != null){
                    pbWrapper.AlternatePart = mapOfproductSuperseded.get(prodData[i].Product2Id).NATT_ALternativeItem__r.NATT_P_N__c;
                }else{
                    pbWrapper.AlternatePart = '';
                }
            }
            /*Pricing */
            if(prodData[i].UnitPrice != null && signValthird.contains(prodData[i].Product2.NATT_SignalCode__c)){
                pbWrapper.Price=prodData[i].UnitPrice;
                if(prodData[i].Product2.NATT_UOM_Conversion__c != null && prodData[i].Product2.NATT_UOM_Conversion__c != 0){
                    Decimal up           =pbWrapper.Price;
                    Decimal UOM          =prodData[i].Product2.NATT_UOM_Conversion__c;
                    pbWrapper.Each_price =up/UOM; 
                }else{
                    pbWrapper.Each_price =pbWrapper.Price;
                }
                //Calculating core item pricing CXREF- 3280//
               
                if(mapOfCorePrDetails.containsKey(prodData[i].product2.NATT_CoreItem_P_N__c )){
                   if(ProdDataMap.containsKey(mapOfCorePrDetails.get(prodData[i].product2.NATT_CoreItem_P_N__c).id)){
                       if(ProdDataMap.get(mapOfCorePrDetails.get(prodData[i].product2.NATT_CoreItem_P_N__c).id).UnitPrice != null){
                           pbWrapper.totalproductPrice = pbWrapper.Price + ProdDataMap.get(mapOfCorePrDetails.get(prodData[i].product2.NATT_CoreItem_P_N__c).id).UnitPrice;
                           pbWrapper.coreListPrice = String.ValueOf(ProdDataMap.get(mapOfCorePrDetails.get(prodData[i].product2.NATT_CoreItem_P_N__c).id).UnitPrice);
                       }else{
                           pbWrapper.totalproductPrice = pbWrapper.Price;
                           pbWrapper.coreListPrice = '';
                       }
                   }
                   else{
                      pbWrapper.totalproductPrice = pbWrapper.Price;
                      pbWrapper.coreListPrice = '';
                   }
               }else{
                    //pbWrapper.totalproductPrice= pbWrapper.Price;
                    pbWrapper.coreListPrice = '';
                } 
            }
            if(prodData[i].UnitPrice != null && prodData[i].Product2.NATT_SignalCode__c == 'NLO' && prodData[i].Product2.NAC_Stocking_Type_UTC__c == 'U'){
                pbWrapper.Price=prodData[i].UnitPrice;
                if(prodData[i].Product2.NATT_UOM_Conversion__c != null && prodData[i].Product2.NATT_UOM_Conversion__c!= 0){
                    Decimal up           =pbWrapper.Price;
                    Decimal UOM          =prodData[i].Product2.NATT_UOM_Conversion__c;
                    pbWrapper.Each_price =up/UOM; 
                }else{
                    pbWrapper.Each_price =pbWrapper.Price;
                }
                //Calculating core item pricing CXREF- 3280//
                 if(mapOfCorePrDetails.containsKey(prodData[i].product2.NATT_CoreItem_P_N__c )){
                    if(ProdDataMap.containsKey(mapOfCorePrDetails.get(prodData[i].product2.NATT_CoreItem_P_N__c).id)){
                        if(ProdDataMap.get(mapOfCorePrDetails.get(prodData[i].product2.NATT_CoreItem_P_N__c).id).UnitPrice != null){
                            pbWrapper.totalproductPrice = pbWrapper.Price + ProdDataMap.get(mapOfCorePrDetails.get(prodData[i].product2.NATT_CoreItem_P_N__c).id).UnitPrice;
                            pbWrapper.coreListPrice = String.ValueOf(ProdDataMap.get(mapOfCorePrDetails.get(prodData[i].product2.NATT_CoreItem_P_N__c).id).UnitPrice);
                        }else{
                            pbWrapper.totalproductPrice = pbWrapper.Price;
                            pbWrapper.coreListPrice = '';
                        }
                    }
                    else{
                        pbWrapper.totalproductPrice = pbWrapper.Price;
                        pbWrapper.coreListPrice = '';
                    }
                }else{
                    //pbWrapper.totalproductPrice = pbWrapper.Price;
                    pbWrapper.coreListPrice = '';
                }
            }
            if(prodData[i].UnitPrice != null && signValfourth.contains(prodData[i].Product2.NATT_SignalCode__c)){
                pbWrapper.Price=0;
                pbWrapper.Each_price=0;
                //pbWrapper.totalproductPrice = 0;
                pbWrapper.coreListPrice = '';
            }
            if(prodData[i].UnitPrice != null && prodData[i].Product2.NATT_SignalCode__c == 'NLO' && prodData[i].Product2.NAC_Stocking_Type_UTC__c == 'O'){
                pbWrapper.Price=0;
                pbWrapper.Each_price=0;
                //pbWrapper.totalproductPrice = 0;
                pbWrapper.coreListPrice = ' ';
            }
            if(prodData[i].Product2.NATT_CoreItem_P_N__c != null){
                pbWrapper.EXCH_CORE='Exchange';
            }else if(prodData[i].Product2.NATT_Core__c){
                pbWrapper.EXCH_CORE='Core';
            }else{
                pbWrapper.EXCH_CORE='';
            }
            
            if(prodData[i].Product2.NATT_Weight__c != null){
                pbWrapper.Weight = prodData[i].Product2.NATT_Weight__c;
            }
            
            if(prodData[i].Product2.NATT_Length__c != null){
                pbWrapper.Length = prodData[i].Product2.NATT_Length__c;
            }
            
            if(prodData[i].Product2.NATT_CoreItem_P_N__c != null){
                pbWrapper.core_Reference=prodData[i].Product2.NATT_CoreItem_P_N__c;
            }
            
            if(prodData[i].Product2.NAC_Line_Of_Business__c !=null){
                pbWrapper.lineOfBusiness=prodData[i].Product2.NAC_Line_Of_Business__c;
            }
            
            if(prodData[i].Product2.NATT_Width__c != null){
                pbWrapper.Width = prodData[i].Product2.NATT_Width__c;
            }            
            if(prodData[i].Product2.NATT_Height__c != null){
                pbWrapper.Height = prodData[i].Product2.NATT_Height__c;
            }
            
            if(prodData[i].Product2.NAC_Country_of_Origin_COO__c != null){
                pbWrapper.COO = prodData[i].Product2.NAC_Country_of_Origin_COO__c;
            }
            if(prodData[i].Product2.NAC_HTSUS__c != null){
                pbWrapper.HTSUS = prodData[i].Product2.NAC_HTSUS__c;
            }
            
            priceBookList.add(pbWrapper);
        }
        return priceBookList;
    }
    
    //CXREF -3818
    @AuraEnabled(cacheable=true)
    public static List<PriceChangeWrapper> fetchPriceListChangeData() {
        List<PriceChangeWrapper> priceChangeWrapperList = new List<PriceChangeWrapper>();
        String customerType;
        WebStoreBuyerGroup storeBuyerGroup;
        List<NATT_ItemPriceStaging__c> itemPriceStgList = new List<NATT_ItemPriceStaging__c>();
        Date dToday = Date.today();
        Date firstdayCurrentYear = Date.newInstance(dToday.year(), 1, 1);
        List<String> externalUserItemCode = Label.NAOCAP_External_User_Item_Code.split(',');
        Id containerStoreId = [SELECT id from Webstore WHERE Name =: Label.NAOCAP_Store_Name LIMIT 1]?.Id;

        Set<String> signalVal = new Set<String>();
        signalVal.add('A');
        signalVal.add('BY2');
        signalVal.add('FIN');
        signalVal.add('PRC');
        signalVal.add('S1');        
        Set<String> signalValsecond = new Set<String>();
        signalValsecond.add('N/A');
        signalValsecond.add('OBS');        
        Set<String> signValthird = new Set<String>();
         signValthird.add('NSI');
         signValthird.add('A');
         signValthird.add('BY2');
         signValthird.add('PRC');
         signValthird.add('FIN');
         signValthird.add('S1');        
        Set<String> signValfourth = new Set<String>();
         signValfourth.add('S2');        
         signValfourth.add('N/A');
         signValfourth.add('OBS'); 
         signValfourth.add('NSU');         
		User userDetail;
		try{
            Boolean hasCustomPermission = FeatureManagement.checkPermission ('UCP_Download_Pricebook_Access');
            list<PermissionSetAssignment> PermissionSetLicenseAssign = [SELECT Id, PermissionSet.Name, AssigneeId from PermissionSetAssignment where  AssigneeId =:UserInfo.getUserId() and (PermissionSet.Name = 'NAOCP_Commerce_Finance' or PermissionSet.Name = 'NAOCP_Commerce_Parts_Ordering') limit 1];
            boolean licenceAssigned = false;
            if(PermissionSetLicenseAssign.size() > 0){
                licenceAssigned = true;
            }
			userDetail = [SELECT contactid, contact.AccountId, isportalenabled FROM User WHERE Id =: UserInfo.getUserId()  LIMIT 1];        
            // if(userDetail.isportalenabled ){
            if(userDetail.isportalenabled && (!hasCustomPermission || licenceAssigned )){
                
                storeBuyerGroup = [SELECT BuyerGroupId, BuyerGroup.NAC_Type__c from WebStoreBuyerGroup WHERE WebStoreId =: containerStoreId AND BuyerGroupId IN (SELECT BuyerGroupId FROM BuyerGroupMember WHERE BuyerId =: userDetail.contact.AccountId)  LIMIT 1];
                customerType = storeBuyerGroup.BuyerGroup.NAC_Type__c;
            }
       // if(userDetail.isportalenabled && Label.NAOCAP_External_Customer_Group.contains(customerType)){
            if(userDetail.isportalenabled &&(hasCustomPermission || Label.NAOCAP_External_Customer_Group.contains(customerType))){ 

            //For external customers we need to filter products on Item code
            System.debug('firstdayCurrentYear--->'+ firstdayCurrentYear ); 
            System.debug('itemPriceGroup In--->' +externalUserItemCode ); 
			itemPriceStgList = [Select NATT_Product__c,NATT_Product__r.Id,NATT_ItemNumber__c,NATT_ExpiryDate__c,NATT_EffectiveDate__c,NATT_ListPrice__c, 
                                NATT_Product__r.NATT_Weight__c,NATT_Product__r.ProductCode,NATT_Product__r.NATT_SignalCode__c,
                                NATT_Product__r.NATT_Height__c,NATT_Product__r.NATT_Width__c,NATT_Product__r.NATT_Discount_Code__c,NATT_Product__r.NAC_Stocking_Type_UTC__c,NATT_Product__r.NATT_Length__c,NATT_Product__r.NAC_Country_of_Origin_COO__c,NATT_Product__r.NAC_HTSUS__c,
                                NATT_Product__r.NATT_P_N__c,NATT_Product__r.Name, NATT_Product__r.NATT_Core__c ,NATT_Product__r.NATT_UOM_Conversion__c,NATT_Product__r.NATT_CoreItem_P_N__c,NATT_Product__r.NAC_Line_Of_Business__c
                                                    from NATT_ItemPriceStaging__c                                
                                WHERE NATT_CustomerNumber__c = 0 AND NATT_ItemPriceType__c = 'CLP'
								AND Recordtype.name = 'NAOCAP' AND NATT_ExpiryDate__c >= THIS_YEAR AND NATT_EffectiveDate__c >= :firstdayCurrentYear AND NATT_Product__r.NATT_ItemPriceGroup__c IN:externalUserItemCode  Order by NATT_ExpiryDate__c asc LIMIT 50000 ];

          System.debug('itemPriceStgList size1--->'+itemPriceStgList.size());  
        }
        else{
            itemPriceStgList = [Select NATT_Product__c,NATT_Product__r.Id,NATT_ItemNumber__c,NATT_ExpiryDate__c,NATT_EffectiveDate__c,NATT_ListPrice__c,
                                NATT_Product__r.NATT_Weight__c,NATT_Product__r.ProductCode,NATT_Product__r.NATT_SignalCode__c,
                                NATT_Product__r.NATT_Height__c,NATT_Product__r.NATT_Width__c,NATT_Product__r.NATT_Discount_Code__c,NATT_Product__r.NAC_Stocking_Type_UTC__c,NATT_Product__r.NATT_Length__c,NATT_Product__r.NAC_Country_of_Origin_COO__c,NATT_Product__r.NAC_HTSUS__c,
                                NATT_Product__r.NATT_P_N__c,NATT_Product__r.Name, NATT_Product__r.NATT_Core__c ,NATT_Product__r.NATT_UOM_Conversion__c,NATT_Product__r.NATT_CoreItem_P_N__c,NATT_Product__r.NAC_Line_Of_Business__c
                                from NATT_ItemPriceStaging__c
                                WHERE NATT_CustomerNumber__c = 0 AND NATT_ItemPriceType__c = 'CLP'
									AND Recordtype.name = 'NAOCAP' AND NATT_ExpiryDate__c >= THIS_YEAR AND NATT_EffectiveDate__c >= :firstdayCurrentYear  Order by NATT_ExpiryDate__c asc LIMIT 50000 ];
            System.debug('itemPriceStgList size2--->'+itemPriceStgList.size()); 
        }
		}
		catch(System.QueryException qe) {
            System.debug('error- ');
            System.debug('error1- '+qe.getLineNumber()+ '-' +qe.getMessage());
        }
        Map<String,List<NATT_ItemPriceStaging__c>> mapOfProductWithPriceChange = new Map<String,List<NATT_ItemPriceStaging__c>>();
        Set<String> coreItemPNset = new Set<String>(); 
        for(NATT_ItemPriceStaging__c item:itemPriceStgList){
            if(item.NATT_Product__r.NATT_CoreItem_P_N__c != null){
                coreItemPNset.add(item.NATT_Product__r.NATT_CoreItem_P_N__c);
            }            
            if(mapOfProductWithPriceChange.containsKey(item.NATT_Product__r.Id)){
                List<NATT_ItemPriceStaging__c> currItems = mapOfProductWithPriceChange.get(item.NATT_Product__r.Id);
                currItems.add(item);
                mapOfProductWithPriceChange.put(item.NATT_Product__r.Id,currItems);
            }
            else{
                List<NATT_ItemPriceStaging__c> newItems = new List<NATT_ItemPriceStaging__c>();
                newItems.add(item);
                mapOfProductWithPriceChange.put(item.NATT_Product__r.Id,newItems);
            }
            
            
        }
		System.debug('coreItemPNset- '+ coreItemPNset);
        System.debug('mapOfProductWithPriceChange- '+ mapOfProductWithPriceChange);
        Map<ID,NATT_AlternativeItem__c> mapOfproductSuperseded =new Map<Id,NATT_AlternativeItem__c>();
		try{
            list<NATT_AlternativeItem__c> nAcLst = [SELECT Id, NATT_AlternativeItem__c,NATT_ProductItem__r.NAC_Stocking_Type_UTC__c, NATT_ProductItem__r.NATT_SignalCode__c , NATT_ProductItem__r.ProductCode,NATT_ProductItem__r.Name,NATT_AlternativeItem__r.Name,
                                        NATT_AlternativeItem__r.ProductCode,NATT_AlternativeItem__r.NATT_CoreItem_P_N__c ,NATT_ProductItem__r.NATT_P_N__c,NATT_AlternativeItem__r.NATT_P_N__c FROM NATT_AlternativeItem__c WHERE 
                                        NATT_ProductItem__c IN:mapOfProductWithPriceChange.keyset() AND NATT_ProductItem__r.NATT_SignalCode__c='S2'  ORDER BY NATT_EffectiveDate__c DESC];
            System.debug('nAcLst- '+ nAcLst);
        for(NATT_AlternativeItem__c nAc:[SELECT Id, NATT_AlternativeItem__c,NATT_ProductItem__r.NAC_Stocking_Type_UTC__c, NATT_ProductItem__r.NATT_SignalCode__c , NATT_ProductItem__r.ProductCode,NATT_ProductItem__r.Name,NATT_AlternativeItem__r.Name,
                                        NATT_AlternativeItem__r.ProductCode,NATT_AlternativeItem__r.NATT_CoreItem_P_N__c ,NATT_ProductItem__r.NATT_P_N__c,NATT_AlternativeItem__r.NATT_P_N__c FROM NATT_AlternativeItem__c WHERE 
                                        NATT_ProductItem__c IN:mapOfProductWithPriceChange.keyset() AND NATT_ProductItem__r.NATT_SignalCode__c='S2'  ORDER BY NATT_EffectiveDate__c DESC]){
                                           system.debug('nAc.NATT_ProductItem__c-'+nAc.NATT_ProductItem__c);
                                           System.debug('mapOfproductSuperseded- '+ mapOfproductSuperseded);
                                            if(!mapOfproductSuperseded.containsKey(nAc.NATT_ProductItem__c)){
                                                mapOfproductSuperseded.put(nAc.NATT_ProductItem__c,nAc);
                                            }
                                        }
		}catch(System.QueryException qe) {
            System.debug('Error-'+qe.getMessage());
        }								
       /** //getting products with core
        List<Product2> prWithCoreItem=new List<Product2>([SELECT Id, Name, NATT_CoreItem_P_N__c,NATT_CorePrice__c,NATT_Branch_Plant_Warehouse__c  FROM Product2 where Id IN:mapOfProductWithPriceChange.keyset() AND NATT_CoreItem_P_N__c!=null and NATT_Branch_Plant_Warehouse__c ='ATL' ]);
        set<string> coreItemPNset=new set<string>();
        for(Product2 prod:prWithCoreItem){
            coreItemPNset.add(prod.NATT_CoreItem_P_N__c);
        }*/ 
        //getting the details of core with part number as key and storing in the map//
        System.debug('coreItemPNset--->'+coreItemPNset);
        MAp<String,NATT_ItemPriceStaging__c> mapOfCorePrDetails=new MAp<String,NATT_ItemPriceStaging__c>();
        //for(Product2 prIterator:[select id,ProductCode,Name,NATT_P_N__c,NAOCAP_Not_Orderable__c,NATT_CorePrice__c  from product2 where NATT_P_N__c IN :coreItemPNset and NATT_Branch_Plant_Warehouse__c ='ATL' AND recordtype.Name='NAC Products']){
        try{
        for(NATT_ItemPriceStaging__c prIterator:[Select NATT_Product__c,NATT_Product__r.Id,NATT_ItemNumber__c,NATT_ExpiryDate__c,NATT_EffectiveDate__c,NATT_ListPrice__c,
        NATT_Product__r.NATT_Weight__c,NATT_Product__r.ProductCode,NATT_Product__r.NATT_SignalCode__c,
        NATT_Product__r.NATT_Height__c,NATT_Product__r.NATT_Width__c,NATT_Product__r.NATT_Discount_Code__c,NATT_Product__r.NAC_Stocking_Type_UTC__c,NATT_Product__r.NATT_Length__c,NATT_Product__r.NAC_Country_of_Origin_COO__c,NATT_Product__r.NAC_HTSUS__c,
        NATT_Product__r.NATT_P_N__c,NATT_Product__r.Name, NATT_Product__r.NATT_Core__c ,NATT_Product__r.NATT_UOM_Conversion__c,NATT_Product__r.NATT_CoreItem_P_N__c,NATT_Product__r.NAC_Line_Of_Business__c
        from NATT_ItemPriceStaging__c
        WHERE NATT_CustomerNumber__c = 0 AND NATT_ItemPriceType__c = 'CLP'
			AND Recordtype.name = 'NAOCAP' AND NATT_ExpiryDate__c >= TODAY AND NATT_Product__r.NATT_P_N__c IN :coreItemPNset AND NATT_Product__r.NATT_Branch_Plant_Warehouse__c ='ATL' Order by NATT_ExpiryDate__c]){    
         system.debug('prIterator-'+prIterator); 
 
        mapOfCorePrDetails.put(prIterator.NATT_Product__r.NATT_P_N__c, prIterator);
        }	
		}catch(System.QueryException qe) {
            System.debug(qe.getMessage());
        }	
        System.debug('mapOfCorePrDetails--->'+mapOfCorePrDetails);
        System.debug('mapOfProductWithPriceChange--->'+mapOfProductWithPriceChange);
        if(mapOfProductWithPriceChange.size()>0){
            for(String prod:mapOfProductWithPriceChange.keyset()){  
                        System.debug('mapOfProductWithPriceChange.get(prod)--->'+mapOfProductWithPriceChange.get(prod));
                        System.debug('mapOfProductWithPriceChange.get(prod)--->'+mapOfProductWithPriceChange.get(prod).size());

                
                if(mapOfProductWithPriceChange.get(prod).size()>1){
                    for(Integer i=1;i<mapOfProductWithPriceChange.get(prod).size();i++){                                         
                        PriceChangeWrapper prChangeWrap = new PriceChangeWrapper();
                        prChangeWrap.PartNumber= mapOfProductWithPriceChange.get(prod)[i].NATT_ItemNumber__c;
                        prChangeWrap.NewPartPrice= mapOfProductWithPriceChange.get(prod)[i].NATT_ListPrice__c;
                        prChangeWrap.OldPartPrice= mapOfProductWithPriceChange.get(prod)[i-1].NATT_ListPrice__c;
                        Date effDate = mapOfProductWithPriceChange.get(prod)[i].NATT_EffectiveDate__c;
                        prChangeWrap.DateChange= DateTime.newInstance(effDate.year(), effDate.month(),effDate.day()).format('MM/dd/yyyy');
                        prChangeWrap.Description = mapOfProductWithPriceChange.get(prod)[i].NATT_Product__r.Name;
                        prChangeWrap.SignalCode = '';
                        if(signalVal.contains(mapOfProductWithPriceChange.get(prod)[i].NATT_Product__r.NATT_SignalCode__c))
                            prChangeWrap.SignalCode ='A';
                        if(mapOfProductWithPriceChange.get(prod)[i].NATT_Product__r.NATT_SignalCode__c == 'NLO' && mapOfProductWithPriceChange.get(prod)[i].NATT_Product__r.NAC_Stocking_Type_UTC__c == 'U')
                            prChangeWrap.SignalCode ='A';
                        if(mapOfProductWithPriceChange.get(prod)[i].NATT_Product__r.NATT_SignalCode__c == 'NLO' && mapOfProductWithPriceChange.get(prod)[i].NATT_Product__r.NAC_Stocking_Type_UTC__c == 'O')
                            prChangeWrap.SignalCode ='NLO';
                        if(signalValsecond.contains(mapOfProductWithPriceChange.get(prod)[i].NATT_Product__r.NATT_SignalCode__c))
                            prChangeWrap.SignalCode ='NLO';
                        if(mapOfProductWithPriceChange.get(prod)[i].NATT_Product__r.NATT_SignalCode__c == 'NSI')
                            prChangeWrap.SignalCode ='NSI';
                        if(mapOfProductWithPriceChange.get(prod)[i].NATT_Product__r.NATT_SignalCode__c == 'NSU' || mapOfProductWithPriceChange.get(prod)[i].NATT_Product__r.NATT_SignalCode__c == 'NEW')
                            prChangeWrap.SignalCode ='NSU';
                    
                        prChangeWrap.PKG =0;
                        /*packaging*/
                        if(mapOfProductWithPriceChange.get(prod)[i].NATT_Product__r.NATT_UOM_Conversion__c != null && mapOfProductWithPriceChange.get(prod)[i].NATT_Product__r.NATT_UOM_Conversion__c!=0){
                            prChangeWrap.PKG=mapOfProductWithPriceChange.get(prod)[i].NATT_Product__r.NATT_UOM_Conversion__c;
                        }

                         //superseded
                        prChangeWrap.AlternatePart ='';
                        if(mapOfproductSuperseded.get(mapOfProductWithPriceChange.get(prod)[i].NATT_Product__r.Id) != null){
                            if(mapOfproductSuperseded.get(mapOfProductWithPriceChange.get(prod)[i].NATT_Product__r.Id).NATT_ProductItem__r.NATT_P_N__c != null){
                                prChangeWrap.AlternatePart = mapOfproductSuperseded.get(mapOfProductWithPriceChange.get(prod)[i].NATT_Product__r.Id).NATT_ALternativeItem__r.NATT_P_N__c;
                            }else{
                                prChangeWrap.AlternatePart = '';
                            }
                        }

                        //Core/Exchange
                        if(mapOfProductWithPriceChange.get(prod)[i].NATT_Product__r.NATT_CoreItem_P_N__c != null){
                            prChangeWrap.EXCH_CORE='Exchange';
                        }else if(mapOfProductWithPriceChange.get(prod)[i].NATT_Product__r.NATT_Core__c){
                            prChangeWrap.EXCH_CORE='Core';
                        }else{
                            prChangeWrap.EXCH_CORE='';
                        }                        
                        prChangeWrap.Price= prChangeWrap.NewPartPrice;
                        prChangeWrap.Each_price =0;
                        prChangeWrap.totalproductPrice =0;
                        prChangeWrap.coreListPrice ='';

                         /*Pricing */
                         if(mapOfProductWithPriceChange.get(prod)[i].NATT_ListPrice__c != null && signValthird.contains(mapOfProductWithPriceChange.get(prod)[i].NATT_Product__r.NATT_SignalCode__c)){
                            prChangeWrap.Price=mapOfProductWithPriceChange.get(prod)[i].NATT_ListPrice__c;
                            if(mapOfProductWithPriceChange.get(prod)[i].NATT_Product__r.NATT_UOM_Conversion__c != null && mapOfProductWithPriceChange.get(prod)[i].NATT_Product__r.NATT_UOM_Conversion__c!= 0){
                                Decimal up           =prChangeWrap.Price;
                                Decimal UOM          =mapOfProductWithPriceChange.get(prod)[i].NATT_Product__r.NATT_UOM_Conversion__c;
                                prChangeWrap.Each_price =up/UOM; 
                            }else{
                                prChangeWrap.Each_price =prChangeWrap.Price;
                            }
                           
                            if(mapOfCorePrDetails.containsKey(mapOfProductWithPriceChange.get(prod)[i].NATT_Product__r.NATT_CoreItem_P_N__c )){
                                  	if(mapOfCorePrDetails.get(mapOfProductWithPriceChange.get(prod)[i].NATT_Product__r.NATT_CoreItem_P_N__c).NATT_ListPrice__c != null){
                                  		 prChangeWrap.totalproductPrice = prChangeWrap.Price + mapOfCorePrDetails.get(mapOfProductWithPriceChange.get(prod)[i].NATT_Product__r.NATT_CoreItem_P_N__c).NATT_ListPrice__c;
                           			     prChangeWrap.coreListPrice = String.valueof(mapOfCorePrDetails.get(mapOfProductWithPriceChange.get(prod)[i].NATT_Product__r.NATT_CoreItem_P_N__c).NATT_ListPrice__c);
                                  }
                                  else{
                                      prChangeWrap.totalproductPrice = prChangeWrap.Price;
                                      prChangeWrap.coreListPrice = '';
                                   }
                               
                            }else{                                     
                                      prChangeWrap.coreListPrice = '';
                            }                         
                        }
                       
                        if(mapOfProductWithPriceChange.get(prod)[i].NATT_ListPrice__c != null && mapOfProductWithPriceChange.get(prod)[i].NATT_Product__r.NATT_SignalCode__c == 'NLO' && mapOfProductWithPriceChange.get(prod)[i].NATT_Product__r.NAC_Stocking_Type_UTC__c == 'U'){
                            //Each Price and Price
                            prChangeWrap.Price= prChangeWrap.NewPartPrice;
                            if(mapOfProductWithPriceChange.get(prod)[i].NATT_Product__r.NATT_UOM_Conversion__c != null && mapOfProductWithPriceChange.get(prod)[i].NATT_Product__r.NATT_UOM_Conversion__c!= 0){
                                Decimal up           =prChangeWrap.Price;
                                Decimal UOM          =mapOfProductWithPriceChange.get(prod)[i].NATT_Product__r.NATT_UOM_Conversion__c;
                                prChangeWrap.Each_price =up/UOM; 
                            }else{
                                prChangeWrap.Each_price =prChangeWrap.Price;
                            }
                            
                            if(mapOfCorePrDetails.containsKey(mapOfProductWithPriceChange.get(prod)[i].NATT_Product__r.NATT_CoreItem_P_N__c )){
                               // if(mapOfProductWithPriceChange.containsKey(mapOfCorePrDetails.get(mapOfProductWithPriceChange.get(prod)[i].NATT_Product__r.NATT_CoreItem_P_N__c).id)){
                                 if(mapOfCorePrDetails.get(mapOfProductWithPriceChange.get(prod)[i].NATT_Product__r.NATT_CoreItem_P_N__c).NATT_ListPrice__c != null){                                  
                                        prChangeWrap.totalproductPrice = prChangeWrap.Price + mapOfCorePrDetails.get(mapOfProductWithPriceChange.get(prod)[i].NATT_Product__r.NATT_CoreItem_P_N__c).NATT_ListPrice__c;
                                        prChangeWrap.coreListPrice = String.valueof(mapOfCorePrDetails.get(mapOfProductWithPriceChange.get(prod)[i].NATT_Product__r.NATT_CoreItem_P_N__c).NATT_ListPrice__c);
                                    }else{
                                        prChangeWrap.totalproductPrice = prChangeWrap.Price;
                                        prChangeWrap.coreListPrice = '';
                                    }
                              /*  }
                                else{
                                    prChangeWrap.totalproductPrice = prChangeWrap.Price;
                                    prChangeWrap.coreListPrice = '';
                                }**/
                            }else{
                                 
                                 prChangeWrap.coreListPrice = '';
                             } 
                        }  
                        
                        if(mapOfProductWithPriceChange.get(prod)[i].NATT_ListPrice__c != null && signValfourth.contains(mapOfProductWithPriceChange.get(prod)[i].NATT_Product__r.NATT_SignalCode__c)){
                            prChangeWrap.Price=0;
                            prChangeWrap.Each_price=0;                            
                            prChangeWrap.coreListPrice = '';
                        }
                        if(mapOfProductWithPriceChange.get(prod)[i].NATT_ListPrice__c != null && mapOfProductWithPriceChange.get(prod)[i].NATT_Product__r.NATT_SignalCode__c == 'NLO' && mapOfProductWithPriceChange.get(prod)[i].NATT_Product__r.NAC_Stocking_Type_UTC__c == 'O'){
                            prChangeWrap.Price=0;
                            prChangeWrap.Each_price=0;                           
                            prChangeWrap.coreListPrice = ' ';
                        }
                        //Superseded
                        prChangeWrap.Superseded =' ';

                        if(mapOfproductSuperseded.containsKey(mapOfProductWithPriceChange.get(prod)[i].NATT_Product__r.Id)){
                            prChangeWrap.Superseded = mapOfproductSuperseded.get(mapOfProductWithPriceChange.get(prod)[i].NATT_Product__r.Id).NATT_ALternativeItem__r.ProductCode;
                        }
                        
                        prChangeWrap.core_Reference = mapOfProductWithPriceChange.get(prod)[i].NATT_Product__r.NATT_CoreItem_P_N__c != null ? mapOfProductWithPriceChange.get(prod)[i].NATT_Product__r.NATT_CoreItem_P_N__c:'';
                        prChangeWrap.lineOfBusiness = mapOfProductWithPriceChange.get(prod)[i].NATT_Product__r.NAC_Line_Of_Business__c != null ? mapOfProductWithPriceChange.get(prod)[i].NATT_Product__r.NAC_Line_Of_Business__c:'';
                        prChangeWrap.Weight = mapOfProductWithPriceChange.get(prod)[i].NATT_Product__r.NATT_Weight__c != null ? mapOfProductWithPriceChange.get(prod)[i].NATT_Product__r.NATT_Weight__c:0;
                        prChangeWrap.Length = mapOfProductWithPriceChange.get(prod)[i].NATT_Product__r.NATT_Length__c != null ? mapOfProductWithPriceChange.get(prod)[i].NATT_Product__r.NATT_Length__c:0;
                        prChangeWrap.Height = mapOfProductWithPriceChange.get(prod)[i].NATT_Product__r.NATT_Height__c != null ? mapOfProductWithPriceChange.get(prod)[i].NATT_Product__r.NATT_Height__c:0;
                        prChangeWrap.COO = mapOfProductWithPriceChange.get(prod)[i].NATT_Product__r.NAC_Country_of_Origin_COO__c != null ? mapOfProductWithPriceChange.get(prod)[i].NATT_Product__r.NAC_Country_of_Origin_COO__c:'';
                        prChangeWrap.HTSUS = mapOfProductWithPriceChange.get(prod)[i].NATT_Product__r.NAC_HTSUS__c != null ? mapOfProductWithPriceChange.get(prod)[i].NATT_Product__r.NAC_HTSUS__c:'';
                        prChangeWrap.Width = mapOfProductWithPriceChange.get(prod)[i].NATT_Product__r.NATT_Width__c != null ? mapOfProductWithPriceChange.get(prod)[i].NATT_Product__r.NATT_Width__c:0;
                        priceChangeWrapperList.add(prChangeWrap); 

                                           
                    }
                }
            }
        }
        
        return priceChangeWrapperList;
    }

    
    //CXREF-3320--->
    @AuraEnabled
    public static ConnectApi.SortRulesCollection getSortRule(String communityId){
        String webstoreId = NAC_B2BUtils.resolveCommunityIdToWebstoreId(communityId);
        return ConnectApi.CommerceSearch.getSortRules(webstoreId);
    }
    //--->CXREF-3320
    
    @AuraEnabled
    public static string getEffectiveAccountId(Boolean isGuestUser) {
        String effectiveAccountId;
        if(isGuestUser){
            effectiveAccountId = Test.isRunningTest() ? 'abc0000111111' :[SELECT id from GuestBuyerProfile where Name =: Label.NAC_Guest_Buyer_Group LIMIT 1].Id;
            
        }else{
			
            List<User> userInfo = [SELECT Id, Profile.Name, Contact.AccountId FROM User WHERE Id = : UserInfo.getUserId()];
            if(!userInfo.isEmpty()){
                if(userInfo[0].Contact.AccountId != null){
                    effectiveAccountId = userInfo[0].Contact.AccountId;
                }
            }
        }
        return effectiveAccountId;
    }
    
    @AuraEnabled
    public static List<string> fetchSearchData(String communityId, String effectiveAccountId, String searchKey){
        String sWildCardText = '%' + searchKey + '%';
        String webstoreId = NAC_B2BUtils.resolveCommunityIdToWebstoreId(communityId);
        Set<Id> buyerGroupIdSet = new Set<Id>();
		Set<String> searchResultSet = new Set<String>();
		ProductCatalog cat;
		Set<Id> ProductCategoryId = new Set<Id>();
		try{
			for(WebStoreBuyerGroup buyerGroup : [SELECT BuyerGroupId from WebStoreBuyerGroup WHERE WebStoreId =: webstoreId AND BuyerGroupId IN (SELECT BuyerGroupId FROM BuyerGroupMember WHERE BuyerId =: effectiveAccountId) ]){
            buyerGroupIdSet.add(buyerGroup.BuyerGroupId);
        }
        
			cat	= [SELECT Id FROM ProductCatalog WHERE Id IN (SELECT ProductCatalogId FROM WebStoreCatalog WHERE SalesStoreId =: webstoreId) ];
			
			for(ProductCategory pc: [SELECT Id FROM ProductCategory WHERE CatalogId =: cat.Id ]){
            ProductCategoryId.add(pc.Id);
        }
			for(CommerceEntitlementProduct cep : [SELECT ProductId, Product.Name, Product.StockKeepingUnit, Product.ProductCode FROM CommerceEntitlementProduct WHERE (Product.Name LIKE : sWildCardText OR Product.StockKeepingUnit LIKE : sWildCardText OR Product.ProductCode LIKE : sWildCardText) AND ProductId IN (SELECT ProductId FROM ProductCategoryProduct WHERE ProductCategoryId IN : ProductCategoryId) AND PolicyId IN (SELECT PolicyId FROM CommerceEntitlementBuyerGroup WHERE BuyerGroupId IN : buyerGroupIdSet)  ORDER BY Product.Name DESC LIMIT 20]){
            
            searchResultSet.add(cep.Product.ProductCode + '  ' + cep.Product.Name);
            
        }
		}catch(System.QueryException qe) {
            System.debug(qe.getMessage());
        }
        // Size limit to 10 searchResultList 
        Set<String> searchResultListFinal = new Set<String>();
        if(searchResultSet.size()>0){
            Integer i=0;
            for(String s :searchResultSet ){
                if(i<10){
                    searchResultListFinal.add(s);
                    i++;
                }
                
            }
        }
        List<String> searchResultList = new List<String>(searchResultListFinal);
        
        return searchResultList;
    }
    
    @AuraEnabled(cacheable=true)
    public static ConnectApi.ProductDetail getProduct(String communityId,String productId,String effectiveAccountId) {
        String webstoreId = NAC_B2BUtils.resolveCommunityIdToWebstoreId(communityId);
        return ConnectApi.CommerceCatalog.getProduct(webstoreId,productId,effectiveAccountID,null,false,null,false,true,false);
    }
    
    @AuraEnabled
    public static ConnectApi.CartSummary getCartSummary(String communityId,String effectiveAccountId) {
        String webstoreId = NAC_B2BUtils.resolveCommunityIdToWebstoreId(communityId);
        String activeCartOrId = 'current';
        return ConnectApi.CommerceCart.getCartSummary(webstoreId,effectiveAccountId,activeCartOrId);
    }
    
    @AuraEnabled
    public static List<ConnectApi.CartItem> addToCart(String communityId,String productId,String quantity,String effectiveAccountId) {
        List<ConnectApi.CartItem> addedItemList=new List<ConnectApi.CartItem>();
        String webstoreId = NAC_B2BUtils.resolveCommunityIdToWebstoreId(communityId);
        String pId=productId;
        productId=pId;
        ConnectApi.CartItemInput cartInput = new ConnectApi.CartItemInput();
        cartInput.productId = productId;
        cartInput.quantity = quantity;
        cartInput.type = ConnectApi.CartItemType.PRODUCT;
        ConnectApi.CartItem originalPr = ConnectApi.CommerceCart.addItemToCart(webstoreId,effectiveAccountId,'active',cartInput);
        addedItemList.add(originalPr); 

        Set<String> validProductSet = new Set<String>();
        
        List<Product2> prWithCoreItem;
		Set<Id> buyerGroupIdSet = new Set<Id>();
		ProductCatalog cat;
		Set<String> productWithValidPrice;
		Set<Id> ProductCategoryId;
		try{
			prWithCoreItem = [SELECT Id, Name, NATT_CoreItem_P_N__c FROM Product2 where id=:productId  LIMIT 1];
        
        if(!prWithCoreItem.isEmpty()){
            if(prWithCoreItem[0].NATT_CoreItem_P_N__c != null){
					
					for(WebStoreBuyerGroup buyerGroup : [SELECT BuyerGroupId from WebStoreBuyerGroup WHERE WebStoreId =: webstoreId AND BuyerGroupId IN (SELECT BuyerGroupId FROM BuyerGroupMember WHERE BuyerId =: effectiveAccountId)  ]){
                    buyerGroupIdSet.add(buyerGroup.BuyerGroupId);
                }
					cat = [SELECT Id FROM ProductCatalog WHERE Id IN (SELECT ProductCatalogId FROM WebStoreCatalog WHERE SalesStoreId =: webstoreId) ];
					productWithValidPrice = new Set<String>();
					for(pricebookEntry pbe: [SELECT Id, Product2Id,Product2.NATT_P_N__c FROM PricebookEntry WHERE Pricebook2Id IN (SELECT Pricebook2Id FROM BuyerGroupPricebook WHERE BuyerGroupId IN: buyerGroupIdSet AND IsActive = TRUE) ]){
                    productWithValidPrice.add(pbe.Product2.NATT_P_N__c);
                }
					ProductCategoryId = new Set<Id>();
					for(ProductCategory pc: [SELECT Id FROM ProductCategory WHERE CatalogId =: cat.Id ]){
                    ProductCategoryId.add(pc.Id);
                }
					for(CommerceEntitlementProduct prod : [SELECT Product.Name, ProductId FROM CommerceEntitlementProduct WHERE Product.NATT_P_N__c=:prWithCoreItem[0].NATT_CoreItem_P_N__c AND PolicyId IN (SELECT PolicyId FROM CommerceEntitlementBuyerGroup WHERE BuyerGroupId IN : buyerGroupIdSet) AND ProductId IN (SELECT ProductId FROM ProductCategoryProduct WHERE ProductCategoryId IN : ProductCategoryId) ]){
                    validProductSet.add(prod.ProductId);
                }
					List<Product2> coreItemDetails = [select id,Name,NATT_P_N__c,NATT_Core__c FROM Product2 where NATT_P_N__c=:prWithCoreItem[0].NATT_CoreItem_P_N__c and Recordtype.Name='NAC Products' AND Id IN:validProductSet  LIMIT 1];
                if(!coreItemDetails.isEmpty() && productWithValidPrice.Contains(prWithCoreItem[0].NATT_CoreItem_P_N__c)){
                    //ConnectApi.CartSummary cartSummary = ConnectApi.CommerceCart.getCartSummary(webstoreId, effectiveAccountId, 'active');
                    //ConnectApi.ProductDetail coreItemProductDetails = ConnectApi.CommerceCatalog.getProduct(webstoreId,productId,effectiveAccountID,null,false,null,false,true,false);
                    //ConnectApi.ProductPrice coreItemProductPricingDetails = ConnectApi.CommerceStorePricing.getProductPrice(webstoreId,productId,effectiveAccountId);
                    //cartItem coreItem = new cartItem();
                    //coreItem.Type = 'Product';
                    //coreItem.CartId = cartSummary.cartId;
                    //coreItem.CartDeliveryGroupId = [SELECT CartDeliveryGroupId FROM cartItem WHERE CartId =: cartSummary.cartId LIMIT 1].CartDeliveryGroupId;
                    //coreItem.Name = coreItemProductDetails.fields.get('Name');
                    //coreItem.Product2Id = coreItemDetails[0].id;
                    //coreItem.Quantity = Integer.valueOf(quantity);
                    //coreItem.CurrencyIsoCode = 'USD';
                    //coreItem.ListPrice = Decimal.valueOf(coreItemProductPricingDetails.listPrice);
                    //coreItem.SalesPrice = Decimal.valueOf(coreItemProductPricingDetails.unitPrice);
                    //coreItem.AdjustmentAmount = 0;
                    //coreItem.TotalAdjustmentAmount = 0;
                    //coreItem.UnitAdjustedPrice = coreItem.SalesPrice;
                    //coreItem.UnitAdjustmentAmount = 0;
                    //coreItem.TotalPromoAdjustmentAmount = 0;
                    //coreItem.TotalLineAmount = coreItem.SalesPrice * coreItem.Quantity;
                    //coreItem.TotalListPrice = coreItem.ListPrice * coreItem.Quantity;
                    //coreItem.TotalPrice = coreItem.TotalLineAmount;
                    //coreItem.TotalPriceAfterAllAdjustments = coreItem.TotalLineAmount;
                    //insert coreItem;
                    productId=coreItemDetails[0].id;
                    ConnectApi.CartItemInput cartInput2 = new ConnectApi.CartItemInput();
                    cartInput2.productId = productId;
                    cartInput2.quantity = quantity;
                    cartInput2.type = ConnectApi.CartItemType.PRODUCT;
                    ConnectApi.CartItem corePr = ConnectApi.CommerceCart.addItemToCart(webstoreId,effectiveAccountId,'active',cartInput2);
                    addedItemList.add(corePr);
                }
            }
        }
        
        }catch(System.QueryException qe) {
            System.debug(qe.getMessage());
        }
        return addedItemList;
    }
    
    @AuraEnabled
    public static ConnectApi.Wishlist createAndAddToList(String communityId,String productId,String wishlistName,String effectiveAccountId) {
        String webstoreId = NAC_B2BUtils.resolveCommunityIdToWebstoreId(communityId);
        ConnectApi.WishlistItemInput wishlistItemInput = new ConnectApi.WishlistItemInput();
        wishlistItemInput.productId = productId;
        ConnectApi.WishlistInput wishlistInput = new ConnectApi.WishlistInput();
        wishlistInput.name = wishlistName;
        wishlistInput.products = new List<ConnectApi.WishlistItemInput>{wishlistItemInput};
            return ConnectApi.CommerceWishlist.createWishlist(webstoreId,effectiveAccountId,wishlistInput);
    }
    
    @AuraEnabled(cacheable=true)
    public static ConnectApi.ProductPrice getProductPrice(String communityId,String productId,String effectiveAccountId) {
        String webstoreId = NAC_B2BUtils.resolveCommunityIdToWebstoreId(communityId);
        return ConnectApi.CommerceStorePricing.getProductPrice(webstoreId,productId,effectiveAccountId);
    }
    
    @AuraEnabled 
    public static SupersededProductWrapper getSupersessionProducts(String communityId, String effectiveAccountId, String recordId){
        SupersededProductWrapper spWrap = new SupersededProductWrapper();
        Map<Id,ConnectApi.ProductOverview> productMap = new Map<Id,ConnectApi.ProductOverview>();
        String webstoreId = NAC_B2BUtils.resolveCommunityIdToWebstoreId(communityId);
        String wareHouse = 'ATL', signalCode;
        try{
            ConnectApi.CartSummary cartSum = ConnectApi.CommerceCart.getCartSummary(webstoreId,effectiveAccountId, 'active');
            List<WebCart> activeCart = [SELECT Id, Warehouse_selected__c FROM WebCart WHERE ID =: cartSum.cartId ];
            if(!activeCart.isEmpty()){
                wareHouse = activeCart[0].Warehouse_selected__c;
            }
        }catch(Exception e){
            wareHouse = 'ATL';
        }
		try{
			Product2 prodData = [SELECT NATT_SignalCode__c, NAOCAP_Signal_Code_ANA__c, NAOCAP_Signal_Code_CHI__c, NAOCAP_Signal_Code_PAN__c FROM Product2 WHERE Id =: recordId ];
        signalCode = wareHouse == 'ANA' ? prodData.NAOCAP_Signal_Code_ANA__c : wareHouse == 'CHI' ? prodData.NAOCAP_Signal_Code_CHI__c : wareHouse == 'PAN' ? prodData.NAOCAP_Signal_Code_PAN__c : prodData.NATT_SignalCode__c;
		} catch(Exception e){
            
        }
        
        List<string> signalCodeList = new List<string>{'S2'};
            if(signalCodeList.contains(signalCode)){
                spWrap.isSuperseded = true; 
                Map<String,List<prodWrapper>> supersededProductMap = getSupersededProduct(new List<Id>{recordId}, false, signalCodeList, wareHouse);
                if(supersededProductMap.containsKey(recordId)){
                    List<String> productIdList = new List<String>();
                    for(prodWrapper prod : supersededProductMap.get(recordId)){
                        productIdList.add(prod.id);
                    }
                    if(!productIdList.isEmpty()){
                        spWrap.supersededProducts = ConnectApi.CommerceCatalog.getProducts(webstoreId, effectiveAccountId, productIdList, new List<String>(), new List<String>(), false, false);
                        for(ConnectApi.ProductOverview prod : spWrap.supersededProducts.products){
                            productMap.put(prod.Id,prod);
                        }
                        spWrap.supersededProducts.products.clear();
                        for(String item : productIdList){
                            if(productMap.containsKey(item)){
                                spWrap.hasSupersededProducts = true;
                                spWrap.supersededProducts.products.add(productMap.get(item));
                            }
                        } 
                    }
                }
            }
        return spWrap;
    }

    public static Map<String,List<prodWrapper>> getSupersededProduct(List<Id> product2IdList, Boolean getAllProducts, List<string> signalCodeList, String wareHouse){
        Set<String> checkSupersededProductIdSet = new Set<String>();
        Map<String,List<prodWrapper>> supersededProductMap = new Map<String,List<prodWrapper>>();
        Map<Id,List<NATT_AlternativeItem__c>> altItemMap = new Map<Id,List<NATT_AlternativeItem__c>>();
		try{
			for(Product2 prod : [SELECT Id, ProductCode, NAOCAP_Signal_Code_ANA__c, NAOCAP_Signal_Code_CHI__c, NAOCAP_Signal_Code_PAN__c, NATT_SignalCode__c, NATT_Core__c , NAOCAP_Not_Orderable__c, NAOCAP_Not_Orderable_ANA__c, NAOCAP_Not_Orderable_CHI__c, NAOCAP_Not_Orderable_PAN__c FROM Product2 WHERE Id IN: product2IdList ]){
            string signalCode = wareHouse == 'ANA' ? prod.NAOCAP_Signal_Code_ANA__c : wareHouse == 'CHI' ? prod.NAOCAP_Signal_Code_CHI__c : wareHouse == 'PAN' ? prod.NAOCAP_Signal_Code_PAN__c : prod.NATT_SignalCode__c;
            boolean notOrderable = wareHouse == 'ANA' ? prod.NAOCAP_Not_Orderable_ANA__c : wareHouse == 'CHI' ? prod.NAOCAP_Not_Orderable_CHI__c : wareHouse == 'PAN' ? prod.NAOCAP_Not_Orderable_PAN__c : prod.NAOCAP_Not_Orderable__c;
            if(signalCodeList.contains(signalCode) && !prod.NATT_Core__c){
                checkSupersededProductIdSet.add(prod.Id);
            }else{
                prodWrapper pWrap = new prodWrapper();
                pWrap.id = prod.Id;
                pWrap.productCode = prod.ProductCode;
                pWrap.notOrderable = notOrderable;
                supersededProductMap.put(prod.Id, new List<prodWrapper>{pWrap});
            }
        }
		}catch(Exception e){
		}
        string query = 'SELECT Id, NATT_ProductItem__c, NATT_ProductItem__r.NATT_SignalCode__c, NATT_AlternativeItem__r.recordtype.developername, NATT_AlternativeItem__c, NATT_AlternativeItem__r.ProductCode, NATT_AlternativeItem__r.NAOCAP_Not_Orderable_ANA__c, NATT_AlternativeItem__r.NAOCAP_Not_Orderable_CHI__c, NATT_AlternativeItem__r.NAOCAP_Not_Orderable_PAN__c, NATT_AlternativeItem__r.NAOCAP_Not_Orderable__c, NATT_AlternativeItem__r.NATT_SignalCode__c, NATT_EffectiveDate__c FROM NATT_AlternativeItem__c WHERE NATT_ProductItem__r.NATT_Branch_Plant_Warehouse__c = \'ATL\' AND NATT_EffectiveDate__c < TODAY AND NATT_ExpiryDate__c >= TODAY AND NATT_AlternativeItem__r.recordtype.Name = \'NAC Products\' AND NATT_ProductItem__c IN : product2IdList AND ';
        query += wareHouse == 'ANA' ? 'NATT_ProductItem__r.NAOCAP_Signal_Code_ANA__c IN : signalCodeList' : wareHouse == 'CHI' ? 'NATT_ProductItem__r.NAOCAP_Signal_Code_CHI__c IN : signalCodeList' : wareHouse == 'PAN' ? 'NATT_ProductItem__r.NAOCAP_Signal_Code_PAN__c IN : signalCodeList' : 'NATT_ProductItem__r.NATT_SignalCode__c IN : signalCodeList';
        query += ' ORDER BY NATT_EffectiveDate__c DESC';
        System.debug('Total number of records retrieved by SOQL queries:'+Limits.getLimitDmlRows());
        System.debug('Number of records retrieved by SOQL queries so far: '+ Limits.getDmlRows());
        for(NATT_AlternativeItem__c altItem : Database.query(query)){
            if(altItemMap.containsKey(altItem.NATT_ProductItem__c)){
                altItemMap.get(altItem.NATT_ProductItem__c).add(altItem);
            }else{
                altItemMap.put(altItem.NATT_ProductItem__c,new List<NATT_AlternativeItem__c>{altItem});
            }
        }
        for(String prod2Id : checkSupersededProductIdSet){
            if(altItemMap.containsKey(prod2Id)){
                List<prodWrapper> supersededProductList = getpartHistory(new Set<Id>{prod2Id}, new Set<prodWrapper>(), altItemMap, getAllProducts, wareHouse);
                if(!supersededProductList.isEmpty()){
                    if(getAllProducts){
                        supersededProductMap.put(prod2Id,supersededProductList);
                    }else{
                        supersededProductMap.put(prod2Id, new List<prodWrapper>{supersededProductList[0]});
                    }
                }
            }
        }
        return supersededProductMap;
    }
    
    public static List<prodWrapper> getpartHistory(Set<Id> prod2IdSet, Set<prodWrapper>altProd2Set, Map<Id,List<NATT_AlternativeItem__c>> altItemMap, Boolean getAllProducts, String wareHouse) {
        Map<Id, prodWrapper> prodMap = new Map<Id, prodWrapper>();
        for(Id prod2Id : prod2IdSet){
            if(altItemMap.containsKey(prod2Id)){
                for(NATT_AlternativeItem__c altItem : altItemMap.get(prod2Id)){
                    prodWrapper pWrap = new prodWrapper();
                    pWrap.id = altItem.NATT_AlternativeItem__c;
                    pWrap.productCode = altItem.NATT_AlternativeItem__r.ProductCode;
                    pWrap.notOrderable = wareHouse == 'ANA' ? altItem.NATT_AlternativeItem__r.NAOCAP_Not_Orderable_ANA__c : wareHouse == 'CHI' ? altItem.NATT_AlternativeItem__r.NAOCAP_Not_Orderable_CHI__c : wareHouse == 'PAN' ? altItem.NATT_AlternativeItem__r.NAOCAP_Not_Orderable_PAN__c : altItem.NATT_AlternativeItem__r.NAOCAP_Not_Orderable__c;
                    prodMap.put(altItem.NATT_AlternativeItem__c, pWrap);
                }
            }
        }
        if(prodMap.keySet().isEmpty()){
            return new List<prodWrapper>(altProd2Set);
        }else{
            if(getAllProducts){
                altProd2Set.addAll(prodMap.values());
            }else{
                for(prodWrapper pWrap : prodMap.values()){
                    if(!altItemMap.containsKey(pWrap.id)){
                        altProd2Set.add(pWrap);
                    }
                }
            }
            return getpartHistory(prodMap.keySet(), altProd2Set, altItemMap, getAllProducts, wareHouse);
        }
    }
    
    //CXREF -3818
    @AuraEnabled(cacheable=true)
    public static String fetchPriceBookGuideData(String staticResourceName) {
        String downloadLink ='';
        downloadLink = NAC_BulkUploadController.GetResourceURL(staticResourceName);
        
        return downloadLink;
    }
    
    //CXREF-4590--->
    @AuraEnabled
    public static string getCustomerSpecificPriceBookEntryId (string productId){
        string priceBookEntryId = '';
        if(String.isNotBlank(productId)){
			List<Account> communityUserAccount;
			List<priceBookEntry> customerSpecificPbe;
			try{
				communityUserAccount = [SELECT CONTAINER_JDE_Bill_To_Code__c FROM Account WHERE Id IN (SELECT AccountId FROM User WHERE Id =: UserInfo.getUserId()) ];
            if(!communityUserAccount.isEmpty()){
                string priceBookName = Label.NAOCAP_Prefix + communityUserAccount[0].CONTAINER_JDE_Bill_To_Code__c;
					customerSpecificPbe = [SELECT Id FROM priceBookEntry WHERE Product2Id =: productId AND Pricebook2.Name =: priceBookName AND IsActive = TRUE AND Pricebook2.IsActive = TRUE ];
                if(!customerSpecificPbe.isEmpty()){
                    priceBookEntryId = customerSpecificPbe[0].Id;
                }
            }
			}catch(Exception e){
			}
        }        
        return priceBookEntryId;
    }
    //--->CXREF-4590
    
    //Wrapper for sending static resources data to LWC
    public class StaticResourceWrapper{
        @AuraEnabled public String imagePath;
        @AuraEnabled public String description;
        @AuraEnabled public String buttonlabel;
        @AuraEnabled public String buttonurl;
        @AuraEnabled public String descriptionh2;
    }
    
    public class ProductCategoryWrapper {
        @AuraEnabled public List<ProductCategory> productCategoryList;
        @AuraEnabled public String topMostParentCategoryId;
        ProductCategoryWrapper(){
            productCategoryList = new List<ProductCategory>();
        }
    }
    
    public class ProdSearchResults{
        @AuraEnabled public SearchCategory categories;
        @AuraEnabled public String correlationId;
        @AuraEnabled public List<Object> facets;
        @AuraEnabled public String locale;
        @AuraEnabled public ProdSummaryCollection productsPage;
        ProdSearchResults(){
            facets = new List<Object>();
        }
    }
    
    public class SearchCategory{
        @AuraEnabled public ProdCategory category;
        @AuraEnabled public List<SearchCategory> children;
        @AuraEnabled public Long productCount;
        SearchCategory(){
            children = new List<SearchCategory>();
        }
    }
    
    public class ProdCategory{
        @AuraEnabled public String description;
        @AuraEnabled public String id;
        @AuraEnabled public String name;
    }
    
    public class ProdSummaryCollection {
        @AuraEnabled public String currencyIsoCode;
        @AuraEnabled public Integer pageSize;
        @AuraEnabled public List<ProdSummary> products;
        @AuraEnabled public Long total;
        ProdSummaryCollection(){
            pageSize = 1;
            products = new List<ProdSummary>();
        }
    }
    
    public class ProdSummary {
        @AuraEnabled public ConnectApi.ProductMedia defaultImage;
        @AuraEnabled public Map<String, FieldValue> fields;
        @AuraEnabled public String id;
        @AuraEnabled public String name;
        @AuraEnabled public ConnectApi.PricingResultLineItem prices;
        ProdSummary(ConnectApi.ProductOverview prod){
            defaultImage = prod.defaultImage;
            fields = new Map<String, FieldValue>();
            for(String field : prod.fields.keySet()){
                FieldValue val = new FieldValue();
                val.value = prod.fields.get(field);
                fields.put(field, val);
                if(field == 'Name'){
                    name = prod.fields.get(field);
                }
            }
            id = prod.id;
            prices = prod.prices;
        }
    }
    
    public class FieldValue {
        @AuraEnabled public String value;
    }
    
    public class PriceBookWrapper{
        @AuraEnabled public Decimal unitPrice;
        @AuraEnabled public String productName;
        @AuraEnabled public String currencyIsoCode;
    }
    
    public class PriceBookWrapperinnerclass{
        @AuraEnabled public String PartNumber{get;set;}
        @AuraEnabled public string Description{get;set;}
        @AuraEnabled public Decimal PKG{get;set;}
        @AuraEnabled public String AlternatePart{get;set;}
        @AuraEnabled public Decimal Price{get;set;}
        @AuraEnabled public String EXCH_CORE{get;set;}
        @AuraEnabled public String SignalCode{get;set;}
        @AuraEnabled public String Superseded{get;set;}
        @AuraEnabled public Double Each_price{get;set;}
        @AuraEnabled public String core_Reference{get;set;}
        @AuraEnabled public String lineOfBusiness{get;set;}
        @AuraEnabled public Decimal Weight{get;set;}
        @AuraEnabled public Decimal Length{get;set;}
        @AuraEnabled public Decimal Width{get;set;}
        @AuraEnabled public Decimal Height{get;set;}
        @AuraEnabled public String COO{get;set;}
        @AuraEnabled public String HTSUS{get;set;}
        @AuraEnabled public string coreProductCode {get;set;}
        @AuraEnabled public string coreListPrice {get;set;}
        @AuraEnabled public Decimal totalproductPrice {get;set;}
    }
    
    public class prodWrapper{
        @AuraEnabled public string id {get;set;}
        @AuraEnabled public string productCode {get;set;}
        @AuraEnabled public boolean notOrderable {get;set;}
    }
    
    public class SupersededProductWrapper{
        @AuraEnabled public boolean isSuperseded {get;set;}
        @AuraEnabled public boolean hasSupersededProducts {get;set;}
        @AuraEnabled public ConnectApi.ProductOverviewCollection supersededProducts {get;set;}
        SupersededProductWrapper(){
            isSuperseded = false;
            hasSupersededProducts = false;
        }
    }
    
    public class PriceChangeWrapper{
        @AuraEnabled public String PartNumber{get;set;}
        @AuraEnabled public Decimal NewPartPrice{get;set;}
        @AuraEnabled public Decimal OldPartPrice{get;set;}
        @AuraEnabled public String DateChange{get;set;}
        //Newly Added
        @AuraEnabled public string Description{get;set;}
        @AuraEnabled public Decimal PKG{get;set;}
        @AuraEnabled public String AlternatePart{get;set;}
        @AuraEnabled public Decimal Price{get;set;}
        @AuraEnabled public String EXCH_CORE{get;set;}
        @AuraEnabled public String SignalCode{get;set;}
        @AuraEnabled public String Superseded{get;set;}
        @AuraEnabled public Double Each_price{get;set;}
        @AuraEnabled public String core_Reference{get;set;}
        @AuraEnabled public String lineOfBusiness{get;set;}
        @AuraEnabled public Decimal Weight{get;set;}
        @AuraEnabled public Decimal Length{get;set;}
        @AuraEnabled public Decimal Width{get;set;}
        @AuraEnabled public Decimal Height{get;set;}
        @AuraEnabled public String COO{get;set;}
        @AuraEnabled public String HTSUS{get;set;}
        @AuraEnabled public string coreProductCode {get;set;}
        @AuraEnabled public string coreListPrice {get;set;}
        @AuraEnabled public Decimal totalproductPrice {get;set;}
        
    } 
}