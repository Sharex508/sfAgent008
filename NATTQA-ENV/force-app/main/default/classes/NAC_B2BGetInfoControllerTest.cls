/**********************************************************************************************
Class name       :  NAC_B2BGetInfoControllerTest              
Author           :  
Description      :  Test class for NAC_B2BGetInfoController
*************************************************************************************************/
@isTest
public class NAC_B2BGetInfoControllerTest { 
    
    static string communityId = [SELECT Id, Name FROM Network WHERE Name =: NAC_Global_Constants.DEFAULT_COMMUNITY_NAME_NAC].Id;
    static Id prodRecordTypeId = Schema.SObjectType.Product2.getRecordTypeInfosByDeveloperName().get('NAC_Products').getRecordTypeId();
    List<String> spgCode = Label.NAOCAP_SPG_Code.split(',');
    
    private static returnData createData(Boolean createStore){
        returnData data = new returnData();
        Map<Id, Decimal> product2PriceMap = new Map<Id, Decimal>();
        List<Id> product2IdList = new List<Id>();
        WebStore web;
        if(createStore){
            web = [SELECT id FROM WebStore WHERE Name =: NAC_Global_Constants.DEFAULT_COMMUNITY_NAME_NAC LIMIT 1];
        }else{
            web = NAC_TestDataFactory.webstoreCreation();
        }
        NAC_B2BUtils.communityIdToWebStoreIdCache.put(communityId,web.id);
        data.pc = NAC_TestDataFactory.createProductCategory(web.Id);
        data.product2List = NAC_TestDataFactory.createProductList(5);
        for(integer i = 0; i < data.product2List.size(); i++){
            data.product2List[i].RecordTypeId = prodRecordTypeId;
            data.product2List[i].NATT_SignalCode__c = 'A';
            if(i == 1 || i == 2){
                data.product2List[i].NATT_SignalCode__c = 'S2';
            }
            if(i == 1){
                data.product2List[i].NATT_CoreItem_P_N__c = data.product2List[i-1].ProductCode;
            }
            if(i == 0){
                data.product2List[i].NATT_Core__c=true;
            }
            data.product2List[i].NATT_ItemPriceGroup__c = '317';
            data.product2List[i].NAOCAP_Under_Processing__c = true;
            data.product2List[i].NATT_Branch_Plant_Warehouse__c = 'ATL';
            data.product2List[i].ProductCode = 'TEST-' + String.valueOf(i);
            data.product2List[i].NATT_P_N__c = 'TEST-' + String.valueOf(i);
            data.product2List[i].NATT_CoreItem_P_N__c = 'TEST-' + String.valueOf(i - 1);
            data.product2List[i].NATT_UnitCost__c = 1718;
                        
        }
        insert data.product2List;
        List<NATT_AlternativeItem__c> altItemList = new List<NATT_AlternativeItem__c>();
        for(integer i = 0; i < data.product2List.size(); i++){
            product2IdList.add(data.product2List[i].Id);
            if(i != data.product2List.size() - 1){
                product2PriceMap.put(data.product2List[i].Id, Math.random() * 100);
                if(data.product2List[i].NATT_SignalCode__c == 'S2'){
                    NATT_AlternativeItem__c altItem = new NATT_AlternativeItem__c();
                    altItem.NATT_AlternativeItem__c = data.product2List[i].Id;
                    altItem.NATT_ProductItem__c = data.product2List[i-1].Id;
                    altItem.NATT_EffectiveDate__c = System.today();
                    altItemList.add(altItem);
                }
            }
        }
        insert altItemList;
        NAC_TestDataFactory.createProductCategoryProductList(new Map<Id,List<Id>>{data.pc.Id => product2IdList});
        data.usr = NAC_TestDataFactory.runAsNACUser();
        Contact cont = [SELECT Id, AccountId FROM Contact WHERE Id =: data.usr.ContactId];
        data.acc = [SELECT Id FROM Account WHERE Id =: cont.AccountId];
        NAC_TestDataFactory.insertBuyerAccount(data.acc);
        BuyerGroup bg =  NAC_TestDataFactory.insertBuyerGroup();
        WebStoreBuyerGroup wbg =  NAC_TestDataFactory.insertWebStoreBuyerGroup(web, bg);
        NAC_TestDataFactory.insertBuyerGroupMember(data.acc, bg);
        List<PriceBook2> priceBookList = NAC_TestDataFactory.createPriceBook(1);
        insert priceBookList;
        NAC_TestDataFactory.createPriceBookEntry(new Map<Id, Map<Id,Decimal>>{priceBookList[0].Id => product2PriceMap});
        NAC_TestDataFactory.createBuyerGroupPricebook(new Map<Id,List<Id>>{bg.Id => new List<Id>{priceBookList[0].Id}});
        List<CommerceEntitlementPolicy> cepList = NAC_TestDataFactory.createCommerceEntitlementPolicy(1);
        insert cepList;
        NAC_TestDataFactory.createCommerceEntitlementBuyerGroup(new Map<Id,List<Id>>{cepList[0].Id => new List<Id>{bg.Id}});
        NAC_TestDataFactory.createCommerceEntitlementProduct(new Map<Id,List<Id>>{cepList[0].Id => product2IdList});
        return data;
    }
    
    private class returnData{
        private User usr;
        private Account acc;
        Private WebStore web;
        private ProductCategory pc;
        private List<Product2> product2List;
    } 
    
    @isTest(SeeAllData = false)
    public static void recentlyOrderdProducts_Test(){
        returnData data = createData(false);
        Test.startTest();
        NAC_B2BGetInfoController.ProdSearchResults prodSearchRes = NAC_B2BGetInfoController.recentlyOrderdProducts(communityId, data.acc.Id, data.pc.Id);
        Test.stopTest();
        System.assert(prodSearchRes != null, 'recentlyOrderdProducts_Test - ProdSearchResult is null');
    }
    
    @isTest(SeeAllData = false)
    public static void guestEffectiveAccount_Test(){
        insert NAC_TestDataFactory.createGuestBuyerProfile(new List<String>{Label.NAC_Guest_Buyer_Group});
        System.assert(!String.isEmpty(NAC_B2BGetInfoController.guestEffectiveAccount()), 'GuestEffective Account is Empty');
    }
    
    @isTest(SeeAllData = false)
    public static void getProductCategory_NoParentCategory_Test(){
        NAC_TestDataFactory.webstoreCreation();
        WebStore webSt = [Select Id from WebStore Limit 1];
        String commId = [SELECT Id, Name FROM Network WHERE Name=:NAC_Global_Constants.DEFAULT_COMMUNITY_NAME_NAC].Id;
        NAC_B2BUtils.communityIdToWebStoreIdCache.put(commId,webSt.id);
        ProductCategory pCat= NAC_TestDataFactory.createProductCategory(webSt.Id);        
        Test.startTest();
        NAC_B2BGetInfoController.ProductCategoryWrapper pwrap= NAC_B2BGetInfoController.getProductCategory(commId);
        Test.stopTest();
        System.assert(pwrap!=null, 'ProductCategoryWrapper is Empty');
    }
    
    @isTest(SeeAllData = false) 
    public static void getProductCategory_Test(){
        NAC_TestDataFactory.webstoreCreation();
        WebStore webSt=[Select Id from WebStore Limit 1];
        String commId = [SELECT Id, Name FROM Network WHERE Name=:NAC_Global_Constants.DEFAULT_COMMUNITY_NAME_NAC].Id;
        NAC_B2BUtils.communityIdToWebStoreIdCache.put(commId,webSt.id);
        ProductCatalog pcat= new ProductCatalog(
            CurrencyIsoCode = NAC_Global_Constants.USD_CURRENCY_CODE,
            Name = NAC_Global_Constants.DEALER_CATALOG_LABEL+Math.random()
        ); 
        insert pcat;
        ProductCategory parentCat= new ProductCategory( 
            CatalogId =pcat.Id,
            Name = NAC_Global_Constants.PRODUCT_LABEL,
            SortOrder=10) ;
        insert parentCat;
        ProductCategory prodCat= new ProductCategory(
            CatalogId =pcat.Id,
            Name = NAC_Global_Constants.PRODUCT_LABEL,
            SortOrder=10,
            ParentCategoryId =parentCat.Id
        );
        Insert prodCat;
        WebStoreCatalog webstCatalog= new WebStoreCatalog(
            ProductCatalogId=pcat.Id,
            SalesStoreId=webSt.Id
        );        
        insert webstCatalog; 
        Test.startTest();
        NAC_B2BGetInfoController.ProductCategoryWrapper prodcatWrap = NAC_B2BGetInfoController.getProductCategory(commId);
        Test.stopTest();
        System.assert(prodcatWrap!=null, 'ProductCategoryWrapper is Empty');
    }
    
    @isTest(SeeAllData = true)
    public static void getProductsByRecentProducts_Test(){
        
        returnData data = createData(true);
        Test.startTest();
        try{
            NAC_B2BGetInfoController.getProducts(communityId,data.acc.Id,NAC_Global_Constants.DISPLAY_RECENT_PRODUCTS,3,null);
        }catch(Exception e){
            
        }
        Test.stopTest();
    }
    
    @isTest(SeeAllData = true)
    public static void getProductPath_Test(){
        returnData data = createData(true);
        Test.startTest();
        try{
            NAC_B2BGetInfoController.getProductPath(communityId, data.pc.Id);
        }catch(Exception e){
            
        }
        Test.stopTest();
    }
    
    @isTest(SeeAllData=false)
    public static void getStaticResourceData_Test(){
        Test.startTest();
               Profile guestProfile = [SELECT Id FROM Profile WHERE Name = 'NA Containers Marketplace Profile' AND UserLicense.Name = 'Guest User License' LIMIT 1];

        //Create our test guest user
        User guestUser = new User(
            Alias = 'random',
            Email='random@salesforce.com',
            EmailEncodingKey = 'UTF-8',
            LastName = 'random',
            LocaleSidKey = 'en_US',
            LanguageLocaleKey = 'en_US',
            ProfileId = guestProfile.Id,
            TimeZoneSidKey ='America/Los_Angeles',
            UserName ='randomuser121212@salesforceTest.com'
        );

        //Insert user record
        insert guestUser;
        System.runAs(guestUser){
        List<NAC_B2BGetInfoController.staticResourceWrapper> staticResourceList = NAC_B2BGetInfoController.getStaticResourceData();
        }
        List<NAC_B2BGetInfoController.staticResourceWrapper> staticResourceList1 = NAC_B2BGetInfoController.getStaticResourceData();
        Test.stopTest();
        System.assert(staticResourceList1.size()>0, 'staticResourceList is Empty');
    }
    @isTest(SeeAllData = false)
    public static void fetchPriceBookGuideDataTest(){
        Test.startTest();
        String link=NAC_B2BGetInfoController.fetchPriceBookGuideData('Test');
        Test.stopTest();
    }
    
    @isTest(SeeAllData = false)
    public static void fetchListCatalog_Test12(){
        
        List<String> spgCode = Label.NAOCAP_SPG_Code.split(',');
        Pricebook2 pb2 = new Pricebook2(Name = 'NA Containers Marketplace Strikethrough Price Book',IsActive = true);
        insert pb2;
        
        Product2 coreProd =new Product2(Name ='testProd2'+Math.random(), NATT_SignalCode__c='NLO',NAC_Stocking_Type_UTC__c='U',RecordTypeId = prodRecordTypeId,NATT_Core__c =true,
                                        StockkeepingUnit ='SKU'+Math.random(),NATT_UOM_Conversion__c=3,productcode='#23457',NATT_P_N__c='#23457',NATT_Branch_Plant_Warehouse__c='ATL',NATT_ItemPriceGroup__c='317'
                                       );
        insert coreProd;
        Product2 prod = new Product2(Name ='testProd'+Math.random(), NATT_SignalCode__c='NLO',NAC_Stocking_Type_UTC__c='O',RecordTypeId = prodRecordTypeId,
                                     StockkeepingUnit ='SKU'+Math.random(),NATT_UOM_Conversion__c=3,NATT_Width__c=23,productcode='#23456',NATT_CoreItem_P_N__c ='#23457',NATT_Branch_Plant_Warehouse__c='ATL',NATT_ItemPriceGroup__c='317'
                                    );
        insert prod;
        
        Pricebook2 standardPricebook = new Pricebook2(
            Id = Test.getStandardPricebookId(),
            IsActive = true
        );
        Update standardPricebook;  
        
        standardPricebook = [SELECT Id, IsStandard FROM Pricebook2 WHERE Id = :standardPricebook.Id];
        PricebookEntry pbe2 = new PricebookEntry(
            Pricebook2Id = standardPricebook.Id,
            Product2Id = prod.Id,
            UnitPrice = 1,
            IsActive = true
        ); 
        Insert pbe2;
        
        PricebookEntry pbecore = new PricebookEntry(
            Pricebook2Id = standardPricebook.Id,
            Product2Id = coreProd.Id,
            UnitPrice = 1,
            IsActive = true
        );
        insert pbecore; 
        
        PricebookEntry pbe = new PricebookEntry(
            Pricebook2Id = pb2.Id,
            Product2Id = prod.Id,
            UnitPrice = 78,
            IsActive = true
        );  
        Insert pbe;
        PricebookEntry pbecore1 = new PricebookEntry(
            Pricebook2Id = pb2.Id,
            Product2Id = coreProd.Id,
            UnitPrice = 173,
            IsActive = true
        );  
        Insert pbecore1;
        user us=NAC_TestDataFactory.runAsNACUser();
        
        
        Account acc=NAC_TestDataFactory.insertAccount();
       
        system.runAs(us){
            try{
                List<NAC_B2BGetInfoController.PriceBookWrapperinnerclass> priceListwrapus= NAC_B2BGetInfoController.fetchListCatalog();
                
            }
            catch(Exception ex){
                
            }
        }
        
    }
    @isTest(SeeAllData = false)
    public static void fetchListCatalog_Test(){
        List<String> spgCode = Label.NAOCAP_SPG_Code.split(',');
        Pricebook2 pb2 = new Pricebook2(Name = 'NA Containers Marketplace Strikethrough Price Book',IsActive = true);
        insert pb2;
        
        
        Product2 coreProd =new Product2(Name ='testProd2'+Math.random(), NATT_SignalCode__c='NLO',NAC_Stocking_Type_UTC__c='U',RecordTypeId = prodRecordTypeId,NATT_Core__c =true,
                                        StockkeepingUnit ='SKU'+Math.random(),NATT_UOM_Conversion__c=3,productcode='2345678',NATT_P_N__c='2345678',NATT_Branch_Plant_Warehouse__c='ATL',NATT_ItemPriceGroup__c='317');
        insert coreProd;
        Product2 prod = new Product2(Name ='testProd'+Math.random(), NATT_SignalCode__c='NLO',NAC_Stocking_Type_UTC__c='O',RecordTypeId = prodRecordTypeId,
                                     StockkeepingUnit ='SKU'+Math.random(),NATT_UOM_Conversion__c=3,NATT_Width__c=23,productcode='#23456',NATT_ItemPriceGroup__c='317'
                                    );
        insert prod;
        Product2 prod1 = new Product2(Name ='testProd1'+Math.random(),
                                      StockkeepingUnit ='SKU'+Math.random(),ProductCode='2345678',NATT_UOM_Conversion__c=2.0, NATT_CoreItem_P_N__c='#23457',NATT_P_N__c='4567',RecordTypeId = prodRecordTypeId,
                                      NATT_Weight__c=32,NATT_Length__c=37,NATT_Height__c=23, NAC_Country_of_Origin_COO__c='xya',NAC_HTSUS__c='rtyy',NATT_Branch_Plant_Warehouse__c='ATL',NATT_ItemPriceGroup__c='317'
                                     );
        insert prod1;
        Product2 prod2 = new Product2(Name ='testProd2'+Math.random(), NATT_SignalCode__c='NLO',NAC_Stocking_Type_UTC__c='U',NATT_P_N__c='8900',RecordTypeId = prodRecordTypeId,
                                      StockkeepingUnit ='SKU'+Math.random(),NATT_UOM_Conversion__c=3,productcode='#2345799',NATT_CoreItem_P_N__c ='#23457',NATT_Branch_Plant_Warehouse__c='ATL',NATT_ItemPriceGroup__c='317'
                                     );
        insert prod2;
        Product2 prod3 = new Product2(Name ='testProd1'+Math.random(),
                                      StockkeepingUnit ='SKU'+Math.random(),NATT_SignalCode__c='NSI',ProductCode='2345678',NATT_UOM_Conversion__c=2.0, NATT_CoreItem_P_N__c='2345678',RecordTypeId = prodRecordTypeId,
                                      NATT_Weight__c=32,NATT_Length__c=37,NATT_Height__c=23, NAC_Country_of_Origin_COO__c='xya',NAC_HTSUS__c='rtyy',NATT_Branch_Plant_Warehouse__c='ATL',NATT_ItemPriceGroup__c='317'
                                     );
        insert prod3;
        Product2 prod4 = new Product2(Name ='testProd1'+Math.random(),
                                      StockkeepingUnit ='SKU'+Math.random(),NATT_SignalCode__c='NSU',ProductCode='2345678',NATT_UOM_Conversion__c=2.0, NATT_CoreItem_P_N__c='2345678',RecordTypeId = prodRecordTypeId,
                                      NATT_Weight__c=32,NATT_Length__c=37,NATT_Height__c=23, NAC_Country_of_Origin_COO__c='xya',NAC_HTSUS__c='rtyy',NATT_Branch_Plant_Warehouse__c='ATL',NATT_ItemPriceGroup__c='317'
                                     );
        insert prod4;
        Product2 prod5 = new Product2(Name ='testProd1'+Math.random(),
                                      StockkeepingUnit ='SKU'+Math.random(),NATT_SignalCode__c='A',ProductCode='2345678',NATT_UOM_Conversion__c=2.0, NATT_CoreItem_P_N__c='2345678',RecordTypeId = prodRecordTypeId,
                                      NATT_Weight__c=32,NATT_Length__c=37,NATT_Height__c=23, NAC_Country_of_Origin_COO__c='xya',NAC_HTSUS__c='rtyy',NATT_Branch_Plant_Warehouse__c='ATL',NATT_ItemPriceGroup__c='317'
                                     );
        insert prod5;
        Product2 prod6 = new Product2(Name ='testProd1'+Math.random(),
                                      StockkeepingUnit ='SKU'+Math.random(),NATT_SignalCode__c='OBS',ProductCode='2345678',NATT_UOM_Conversion__c=2.0, NATT_CoreItem_P_N__c='2345678',RecordTypeId = prodRecordTypeId,
                                      NATT_Weight__c=32,NATT_Length__c=37,NATT_Height__c=23, NAC_Country_of_Origin_COO__c='xya',NAC_HTSUS__c='rtyy',NATT_Branch_Plant_Warehouse__c='ATL',NATT_ItemPriceGroup__c='317'
                                     );
        insert prod6;
        
        
        Pricebook2 standardPricebook = new Pricebook2(
            Id = Test.getStandardPricebookId(),
            IsActive = true
        );
        Update standardPricebook;  
        
        standardPricebook = [SELECT Id, IsStandard FROM Pricebook2 WHERE Id = :standardPricebook.Id];
        PricebookEntry pbe2 = new PricebookEntry(
            Pricebook2Id = standardPricebook.Id,
            Product2Id = prod.Id,
            UnitPrice = 1,
            IsActive = true
        ); 
        Insert pbe2;
        PricebookEntry pbe21 = new PricebookEntry(
            Pricebook2Id = standardPricebook.Id,
            Product2Id = prod1.Id,
            UnitPrice = 1,
            IsActive = true
        ); 
        Insert pbe21;
        PricebookEntry pbe23 = new PricebookEntry(
            Pricebook2Id = standardPricebook.Id,
            Product2Id = prod2.Id,
            UnitPrice = 1,
            IsActive = true
        );
        insert pbe23;
        PricebookEntry pbecore = new PricebookEntry(
            Pricebook2Id = standardPricebook.Id,
            Product2Id = coreProd.Id,
            UnitPrice = 1,
            IsActive = true
        );
        insert pbecore;
        PricebookEntry p41 = new PricebookEntry(
            Pricebook2Id = standardPricebook.Id,
            Product2Id = prod3.Id,
            UnitPrice = 1,
            IsActive = true
        );
        insert p41;
        PricebookEntry p51 = new PricebookEntry(
            Pricebook2Id = standardPricebook.Id,
            Product2Id = prod4.Id,
            UnitPrice = 1,
            IsActive = true
        );
        insert p51;
        PricebookEntry p61 = new PricebookEntry(
            Pricebook2Id = standardPricebook.Id,
            Product2Id = prod5.Id,
            UnitPrice = 1,
            IsActive = true
        );
        insert p61; 
        PricebookEntry p71 = new PricebookEntry(
            Pricebook2Id = standardPricebook.Id,
            Product2Id = prod6.Id,
            UnitPrice = 1,
            IsActive = true
        );
        insert p71; 
        
        PricebookEntry pbe = new PricebookEntry(
            Pricebook2Id = pb2.Id,
            Product2Id = prod.Id,
            UnitPrice = 78,
            IsActive = true
        );  
        Insert pbe;
        PricebookEntry pbe11 = new PricebookEntry(
            Pricebook2Id = pb2.Id,
            Product2Id = prod1.Id,
            UnitPrice = 89,
            IsActive = true
        );  
        Insert pbe11;
        PricebookEntry pbe31 = new PricebookEntry(
            Pricebook2Id = pb2.Id,
            Product2Id = prod2.Id,
            UnitPrice = 17,
            IsActive = true
        );  
        Insert pbe31;
        PricebookEntry pbecore1 = new PricebookEntry(
            Pricebook2Id = pb2.Id,
            Product2Id = coreProd.Id,
            UnitPrice = 173,
            IsActive = true
        );  
        Insert pbecore1;
        PricebookEntry p42 = new PricebookEntry(
            Pricebook2Id = pb2.Id,
            Product2Id = prod3.Id,
            UnitPrice = 173,
            IsActive = true
        );  
        Insert p42;
        PricebookEntry p52 = new PricebookEntry(
            Pricebook2Id = pb2.Id,
            Product2Id = prod4.Id,
            UnitPrice = 173,
            IsActive = true
        );  
        Insert p52;
        PricebookEntry p62 = new PricebookEntry(
            Pricebook2Id = pb2.Id,
            Product2Id = prod5.Id,
            UnitPrice = 173,
            IsActive = true
        );  
        Insert p62;
        PricebookEntry p72 = new PricebookEntry(
            Pricebook2Id = pb2.Id,
            Product2Id = prod6.Id,
            UnitPrice = 173,
            IsActive = true
        );  
        Insert p72;
        NATT_AlternativeItem__c altItem = new NATT_AlternativeItem__c();
        altItem.NATT_AlternativeItem__c =prod2.id;
        altItem.NATT_ProductItem__c = prod1.id;
        altItem.NATT_EffectiveDate__c = System.today();
        insert altItem;
        
        user us=NAC_TestDataFactory.runAsNACUser();
        
        
        Account acc=NAC_TestDataFactory.insertAccount();
        List<NAC_B2BGetInfoController.PriceBookWrapperinnerclass> priceListwrap= NAC_B2BGetInfoController.fetchListCatalog();
        system.runAs(us){
            try{
                List<NAC_B2BGetInfoController.PriceBookWrapperinnerclass> priceListwrapus= NAC_B2BGetInfoController.fetchListCatalog();
                
            }
            catch(Exception ex){
                
            }
        }
    }
    
    @isTest(SeeAllData = false)
    public static void fetchPriceListChangeData_Test(){
        Pricebook2 pb2 = new Pricebook2(Name = 'NA Containers Marketplace Strikethrough Price Book',IsActive = true);
        insert pb2;
        Product2 prod = new Product2(Name ='testProd'+Math.random(),
                                     StockkeepingUnit ='SKU'+Math.random()
                                    );
        insert prod;
        
        Product2 prod1 = new Product2(Name ='testProd'+Math.random(),
                                      StockkeepingUnit ='SKU'+Math.random(),ProductCode='2345678',NATT_UOM_Conversion__c=2.0, NATT_CoreItem_P_N__c='2345678',RecordTypeId = prodRecordTypeId,
                                      NATT_Weight__c=32,NATT_Length__c=37,NATT_Height__c=23, NAC_Country_of_Origin_COO__c='xya',NAC_HTSUS__c='rtyy'
                                     );
        insert prod1;
        Product2 prod2 = new Product2(Name ='testProd2'+Math.random(),
                                      StockkeepingUnit ='SKU'+Math.random(),ProductCode='2345679',NATT_UOM_Conversion__c=2.0, NATT_CoreItem_P_N__c='23456791',RecordTypeId = prodRecordTypeId,NATT_Branch_Plant_Warehouse__c ='ATL',
                                       NATT_SignalCode__c='NLO',NAC_Stocking_Type_UTC__c='U',NATT_Weight__c=32,NATT_Length__c=37,NATT_Height__c=23, NAC_Country_of_Origin_COO__c='xya',NAC_HTSUS__c='rtyy'
                                     );
        insert prod2;
        Product2 coreProd =new Product2(Name ='testProdcore'+Math.random(),RecordTypeId = prodRecordTypeId,NATT_Core__c =true,NATT_Branch_Plant_Warehouse__c ='ATL',
                                        StockkeepingUnit ='SKU'+Math.random(),NATT_UOM_Conversion__c=3,productcode='23456791',NATT_P_N__c='2345678');
        insert coreProd;
        Product2 prod3 = new Product2(Name ='testProd3'+Math.random(),
                                      StockkeepingUnit ='SKU'+Math.random(),ProductCode='23456792',NATT_UOM_Conversion__c=2.0, NATT_CoreItem_P_N__c='23456791',RecordTypeId = prodRecordTypeId,NATT_Branch_Plant_Warehouse__c ='ATL',
                                       NATT_SignalCode__c='OBS',NATT_Weight__c=32,NATT_Length__c=37,NATT_Height__c=23, NAC_Country_of_Origin_COO__c='xya',NAC_HTSUS__c='rtyy'
                                     );
        insert prod3;
         Product2 prod4 = new Product2(Name ='testProd4'+Math.random(),
                                      StockkeepingUnit ='SKU'+Math.random(),ProductCode='23456793',NATT_UOM_Conversion__c=2.0, NATT_CoreItem_P_N__c='23456791',RecordTypeId = prodRecordTypeId,NATT_Branch_Plant_Warehouse__c ='ATL',
                                       NATT_SignalCode__c='NLO',NAC_Stocking_Type_UTC__c='O',NATT_Weight__c=32,NATT_Length__c=37,NATT_Height__c=23, NAC_Country_of_Origin_COO__c='xya',NAC_HTSUS__c='rtyy'
                                     );
        insert prod4;
        Product2 prod5 = new Product2(Name ='testProd5'+Math.random(),
                                      StockkeepingUnit ='SKU'+Math.random(),ProductCode='23456794',NATT_UOM_Conversion__c=2.0, NATT_CoreItem_P_N__c='23456791',RecordTypeId = prodRecordTypeId,NATT_Branch_Plant_Warehouse__c ='ATL',
                                       NATT_SignalCode__c='NSI',NATT_Weight__c=32,NATT_Length__c=37,NATT_Height__c=23, NAC_Country_of_Origin_COO__c='xya',NAC_HTSUS__c='rtyy'
                                     );
        insert prod5;
         Product2 prod6 = new Product2(Name ='testProd6'+Math.random(),
                                      StockkeepingUnit ='SKU'+Math.random(),ProductCode='23456795',NATT_UOM_Conversion__c=2.0, NATT_CoreItem_P_N__c='23456791',RecordTypeId = prodRecordTypeId,NATT_Branch_Plant_Warehouse__c ='ATL',
                                       NATT_SignalCode__c='NSU',NATT_Weight__c=32,NATT_Length__c=37,NATT_Height__c=23, NAC_Country_of_Origin_COO__c='xya',NAC_HTSUS__c='rtyy'
                                     );
        insert prod6;
        Id itemPriceStagingRecordType = Schema.getGlobalDescribe().get('NATT_ItemPriceStaging__c').getDescribe().getRecordTypeInfosByName().get('NAOCAP').getRecordTypeId();
        Date dToday = Date.today();
        Insert new NATT_ItemPriceStaging__c(
            recordtypeId=itemPriceStagingRecordType,
            NATT_ItemPriceKeyId__c='155985|CON',
            NATT_ItemPriceType__c ='CLP',
            NATT_EffectiveDate__c=Date.newInstance(dToday.year(), 1, 1),//Date.newInstance(2023, 3, 01), 
            NATT_ExpiryDate__c=Date.newInstance(2040, 10, 08),
            NATT_QuantityFrom__c=1,
            NATT_UOM__c ='EA',
            NATT_ItemNumber__c=prod1.Name,
            NATT_CustomerNumber__c=0,
            NATT_ListPrice__c=20.50,
            NATT_Product__c=prod1.id                                   
        );
        
        Insert new NATT_ItemPriceStaging__c(
            recordtypeId=itemPriceStagingRecordType,
            NATT_ItemPriceKeyId__c='155985|CON',
            NATT_ItemPriceType__c ='CLP',
            NATT_EffectiveDate__c=Date.newInstance(dToday.year(), 1, 1),//Date.newInstance(2023, 3, 01), 
            NATT_ExpiryDate__c=Date.newInstance(2040, 10, 08),
            NATT_QuantityFrom__c=1,
            NATT_UOM__c ='EA',
            NATT_ItemNumber__c=prod1.Name,
            NATT_CustomerNumber__c=0,
            NATT_ListPrice__c=20.50,
            NATT_Product__c=prod1.id                                   
        );
        
        /*List<NATT_ItemPriceStaging__c> updateList=[Select Id,NATT_ItemPriceKeyId__c,NATT_ListPrice__c from NATT_ItemPriceStaging__c where NATT_ItemPriceKeyId__c='155985|CON'];
        for(NATT_ItemPriceStaging__c updatePrice:updateList){
            updatePrice.NATT_ListPrice__c=30;
            Update updatePrice;
        }*/
        
       
        
         Insert new NATT_ItemPriceStaging__c(
            recordtypeId=itemPriceStagingRecordType,
            NATT_ItemPriceKeyId__c='155987|CON',
            NATT_ItemPriceType__c ='CLP',
            NATT_EffectiveDate__c=Date.newInstance(dToday.year(), 1, 1),//Date.newInstance(2023, 3, 01), 
            NATT_ExpiryDate__c=Date.newInstance(2040, 10, 08),
            NATT_QuantityFrom__c=1,
            NATT_UOM__c ='EA',
            NATT_ItemNumber__c=prod2.Name,
            NATT_CustomerNumber__c=0,
            NATT_ListPrice__c=20.50,
            NATT_Product__c=prod2.id                                   
        );
        
        Insert new NATT_ItemPriceStaging__c(
            recordtypeId=itemPriceStagingRecordType,
            NATT_ItemPriceKeyId__c='155988|CON',
            NATT_ItemPriceType__c ='CLP',
            NATT_EffectiveDate__c=Date.newInstance(dToday.year(), 1, 1),//Date.newInstance(2023, 3, 01), 
            NATT_ExpiryDate__c=Date.newInstance(2030, 10, 08),
            NATT_QuantityFrom__c=1,
            NATT_UOM__c ='EA',
            NATT_ItemNumber__c=prod2.Name,
            NATT_CustomerNumber__c=0,
            NATT_ListPrice__c=20.50,
            NATT_Product__c=prod2.id                                   
        );
          Insert new NATT_ItemPriceStaging__c(
            recordtypeId=itemPriceStagingRecordType,
            NATT_ItemPriceKeyId__c='155989|CON',
            NATT_ItemPriceType__c ='CLP',
            NATT_EffectiveDate__c=Date.newInstance(dToday.year(), 1, 1),//Date.newInstance(2023, 3, 01), 
            NATT_ExpiryDate__c=Date.newInstance(2040, 10, 08),
            NATT_QuantityFrom__c=1,
            NATT_UOM__c ='EA',
            NATT_ItemNumber__c=prod3.Name,
            NATT_CustomerNumber__c=0,
            NATT_ListPrice__c=20.50,
            NATT_Product__c=prod3.id                                   
        );
        
        Insert new NATT_ItemPriceStaging__c(
            recordtypeId=itemPriceStagingRecordType,
            NATT_ItemPriceKeyId__c='155990|CON',
            NATT_ItemPriceType__c ='CLP',
            NATT_EffectiveDate__c=Date.newInstance(dToday.year(), 1, 1),//Date.newInstance(2023, 3, 01), 
            NATT_ExpiryDate__c=Date.newInstance(2030, 10, 08),
            NATT_QuantityFrom__c=1,
            NATT_UOM__c ='EA',
            NATT_ItemNumber__c=prod3.Name,
            NATT_CustomerNumber__c=0,
            NATT_ListPrice__c=20.50,
            NATT_Product__c=prod3.id                                   
        );
          Insert new NATT_ItemPriceStaging__c(
            recordtypeId=itemPriceStagingRecordType,
            NATT_ItemPriceKeyId__c='155991|CON',
            NATT_ItemPriceType__c ='CLP',
            NATT_EffectiveDate__c=Date.newInstance(dToday.year(), 1, 1),//Date.newInstance(2023, 3, 01), 
            NATT_ExpiryDate__c=Date.newInstance(2040, 10, 08),
            NATT_QuantityFrom__c=1,
            NATT_UOM__c ='EA',
            NATT_ItemNumber__c=prod4.Name,
            NATT_CustomerNumber__c=0,
            NATT_ListPrice__c=20.50,
            NATT_Product__c=prod4.id                                   
        );
        
        Insert new NATT_ItemPriceStaging__c(
            recordtypeId=itemPriceStagingRecordType,
            NATT_ItemPriceKeyId__c='155992|CON',
            NATT_ItemPriceType__c ='CLP',
            NATT_EffectiveDate__c=Date.newInstance(dToday.year(), 1, 1),//Date.newInstance(2023, 3, 01), 
            NATT_ExpiryDate__c=Date.newInstance(2030, 10, 08),
            NATT_QuantityFrom__c=1,
            NATT_UOM__c ='EA',
            NATT_ItemNumber__c=prod4.Name,
            NATT_CustomerNumber__c=0,
            NATT_ListPrice__c=20.50,
            NATT_Product__c=prod4.id                                   
        );
          Insert new NATT_ItemPriceStaging__c(
            recordtypeId=itemPriceStagingRecordType,
            NATT_ItemPriceKeyId__c='155993|CON',
            NATT_ItemPriceType__c ='CLP',
            NATT_EffectiveDate__c = Date.newInstance(dToday.year(), 1, 1),//Date.newInstance(2023, 3, 01), 
            NATT_ExpiryDate__c=Date.newInstance(2040, 10, 08),
            NATT_QuantityFrom__c=1,
            NATT_UOM__c ='EA',
            NATT_ItemNumber__c=prod5.Name,
            NATT_CustomerNumber__c=0,
            NATT_ListPrice__c=20.50,
            NATT_Product__c=prod5.id                                   
        );
        
        Insert new NATT_ItemPriceStaging__c(
            recordtypeId=itemPriceStagingRecordType,
            NATT_ItemPriceKeyId__c='155994|CON',
            NATT_ItemPriceType__c ='CLP',
            NATT_EffectiveDate__c=Date.newInstance(dToday.year(), 1, 1),//Date.newInstance(2023, 3, 01), 
            NATT_ExpiryDate__c=Date.newInstance(2030, 10, 08),
            NATT_QuantityFrom__c=1,
            NATT_UOM__c ='EA',
            NATT_ItemNumber__c=prod5.Name,
            NATT_CustomerNumber__c=0,
            NATT_ListPrice__c=20.50,
            NATT_Product__c=prod5.id                                   
        );
          Insert new NATT_ItemPriceStaging__c(
            recordtypeId=itemPriceStagingRecordType,
            NATT_ItemPriceKeyId__c='155995|CON',
            NATT_ItemPriceType__c ='CLP',
            NATT_EffectiveDate__c=Date.newInstance(dToday.year(), 1, 1),//Date.newInstance(2023, 3, 01), 
            NATT_ExpiryDate__c=Date.newInstance(2040, 10, 08),
            NATT_QuantityFrom__c=1,
            NATT_UOM__c ='EA',
            NATT_ItemNumber__c=prod6.Name,
            NATT_CustomerNumber__c=0,
            NATT_ListPrice__c=20.50,
            NATT_Product__c=prod6.id                                   
        );
        
        Insert new NATT_ItemPriceStaging__c(
            recordtypeId=itemPriceStagingRecordType,
            NATT_ItemPriceKeyId__c='155996|CON',
            NATT_ItemPriceType__c ='CLP',
            NATT_EffectiveDate__c=Date.newInstance(dToday.year(), 1, 1),//Date.newInstance(2023, 3, 01), 
            NATT_ExpiryDate__c=Date.newInstance(2030, 10, 08),
            NATT_QuantityFrom__c=1,
            NATT_UOM__c ='EA',
            NATT_ItemNumber__c=prod6.Name,
            NATT_CustomerNumber__c=0,
            NATT_ListPrice__c=20.50,
            NATT_Product__c=prod6.id                                   
        );
        Pricebook2 standardPricebook = new Pricebook2(
            Id = Test.getStandardPricebookId(),
            IsActive = true
        );
        Update standardPricebook;        
        standardPricebook = [SELECT Id, IsStandard FROM Pricebook2 WHERE Id = :standardPricebook.Id];
        PricebookEntry pbe2 = new PricebookEntry(
            Pricebook2Id = standardPricebook.Id,
            Product2Id = prod.Id,
            UnitPrice = 1,
            IsActive = true
        ); 
        Insert pbe2;
        PricebookEntry pbe21 = new PricebookEntry(
            Pricebook2Id = standardPricebook.Id,
            Product2Id = prod1.Id,
            UnitPrice = 1,
            IsActive = true
        ); 
        Insert pbe21;
       PricebookEntry pbe22 = new PricebookEntry(
            Pricebook2Id = standardPricebook.Id,
            Product2Id = prod2.Id,
            UnitPrice = 1,
            IsActive = true
        ); 
        Insert pbe22;
       PricebookEntry pbe23 = new PricebookEntry(
            Pricebook2Id = standardPricebook.Id,
            Product2Id = coreProd.Id,
            UnitPrice = 1,
            IsActive = true
        ); 
        Insert pbe23;
         PricebookEntry pbe24 = new PricebookEntry(
            Pricebook2Id = standardPricebook.Id,
            Product2Id = prod3.Id,
            UnitPrice = 1,
            IsActive = true
        ); 
        Insert pbe24;
         PricebookEntry pbe25 = new PricebookEntry(
            Pricebook2Id = standardPricebook.Id,
            Product2Id = prod4.Id,
            UnitPrice = 1,
            IsActive = true
        ); 
        Insert pbe25;
         PricebookEntry pbe26 = new PricebookEntry(
            Pricebook2Id = standardPricebook.Id,
            Product2Id = prod5.Id,
            UnitPrice = 1,
            IsActive = true
        ); 
        Insert pbe26;
         PricebookEntry pbe27 = new PricebookEntry(
            Pricebook2Id = standardPricebook.Id,
            Product2Id = prod6.Id,
            UnitPrice = 1,
            IsActive = true
        ); 
        Insert pbe27;
        PricebookEntry pbe = new PricebookEntry(
            Pricebook2Id = pb2.Id,
            Product2Id = prod.Id,
            UnitPrice = 1,
            IsActive = true
        );  
        Insert pbe;
        PricebookEntry pbe11 = new PricebookEntry(
            Pricebook2Id = pb2.Id,
            Product2Id = prod1.Id,
            UnitPrice = 1,
            IsActive = true
        );  
        Insert pbe11;
       
        PricebookEntry pbe12 = new PricebookEntry(
            Pricebook2Id = pb2.Id,
            Product2Id = prod2.Id,
            UnitPrice = 1,
            IsActive = true
        );  
        Insert pbe12;
         PricebookEntry pbe13 = new PricebookEntry(
            Pricebook2Id = pb2.Id,
            Product2Id = coreProd.Id,
            UnitPrice = 1,
            IsActive = true
        );  
        Insert pbe13;
         PricebookEntry pbe14 = new PricebookEntry(
            Pricebook2Id = pb2.Id,
            Product2Id = prod3.Id,
            UnitPrice = 1,
            IsActive = true
        );  
        Insert pbe14;
         PricebookEntry pbe15 = new PricebookEntry(
            Pricebook2Id = pb2.Id,
            Product2Id = prod4.Id,
            UnitPrice = 1,
            IsActive = true
        );  
        Insert pbe15;
         PricebookEntry pbe16 = new PricebookEntry(
            Pricebook2Id = pb2.Id,
            Product2Id = prod5.Id,
            UnitPrice = 1,
            IsActive = true
        );  
        Insert pbe16;
         PricebookEntry pbe17 = new PricebookEntry(
            Pricebook2Id = pb2.Id,
            Product2Id = prod6.Id,
            UnitPrice = 1,
            IsActive = true
        );  
        Insert pbe17;
        user us=NAC_TestDataFactory.runAsNACUser();
        
        Account acc=NAC_TestDataFactory.insertAccount();
        Contact con=[SELECT Id,AccountId from Contact where Id=:us.contactId Limit 1];
        BuyerGroup bg1=new BuyerGroup(Name='TestBG1',
                                      NAC_Type__c='C3');
        insert bg1;
        insert new BuyerAccount(IsActive=true,
                                PayerId=con.AccountId,
                                SendToId =con.AccountId,
                                Name='Test',
                                BuyerId=con.AccountId);
        
        insert new BuyerGroupMember(BuyerId=con.AccountId,
                                    BuyerGroupId=bg1.Id);
        WebStore webSt=NAC_TestDataFactory.webstoreCreation();
        insert new WebStoreBuyerGroup(BuyerGroupId=bg1.Id,
                                      WebStoreId=webSt.Id);
        Test.startTest();
        List<NAC_B2BGetInfoController.PriceChangeWrapper> priceListwrap= NAC_B2BGetInfoController.fetchPriceListChangeData();
        system.runAs(us){
            try{
                List<NAC_B2BGetInfoController.PriceChangeWrapper> priceListwrapus= NAC_B2BGetInfoController.fetchPriceListChangeData(); 
            }
            catch(Exception ex){
                
            }
            
        }
        Test.stopTest();
        
        System.assertNotEquals(priceListwrap.size(), 0, 'Not able to fetch the PriceListChangeData');
        
    }
    
    
    
    @isTest(SeeAllData = false)
    public static void fetchPriceListChangeData_Test2(){
        Pricebook2 pb2 = new Pricebook2(Name = 'NA Containers Marketplace Strikethrough Price Book',IsActive = true);
        insert pb2;
        Product2 prod = new Product2(Name ='testProd'+Math.random(),
                                     StockkeepingUnit ='SKU'+Math.random()
                                    );
        insert prod;
        
        Product2 prod1 = new Product2(Name ='testProd'+Math.random(),NATT_SignalCode__c='A',
                                      StockkeepingUnit ='SKU'+Math.random(),ProductCode='2345678',NATT_UOM_Conversion__c=2.0, NATT_CoreItem_P_N__c='2345678',RecordTypeId = prodRecordTypeId,
                                      NATT_Weight__c=32,NATT_Length__c=37,NATT_Height__c=23, NAC_Country_of_Origin_COO__c='xya',NAC_HTSUS__c='rtyy'
                                     );
        insert prod1;
        Id itemPriceStagingRecordType = Schema.getGlobalDescribe().get('NATT_ItemPriceStaging__c').getDescribe().getRecordTypeInfosByName().get('NAOCAP').getRecordTypeId();
         Date dToday = Date.today();
        Insert new NATT_ItemPriceStaging__c(
            recordtypeId=itemPriceStagingRecordType,
            NATT_ItemPriceKeyId__c='155985|CON',
            NATT_ItemPriceType__c ='CLP',
            NATT_EffectiveDate__c=Date.newInstance(dToday.year(), 1, 1),//Date.newInstance(2023, 3, 01), 
            NATT_ExpiryDate__c=Date.newInstance(2040, 10, 08),
            NATT_QuantityFrom__c=1,
            NATT_UOM__c ='EA',
            NATT_ItemNumber__c=prod1.Name,
            NATT_CustomerNumber__c=0,
            NATT_ListPrice__c=20.50,
            NATT_Product__c=prod1.id                                   
        );
        
        Insert new NATT_ItemPriceStaging__c(
            recordtypeId=itemPriceStagingRecordType,
            NATT_ItemPriceKeyId__c='155986|CON',
            NATT_ItemPriceType__c ='CLP',
             NATT_EffectiveDate__c=Date.newInstance(dToday.year(), 1, 1),//Date.newInstance(2023, 3, 01),  
            NATT_ExpiryDate__c=Date.newInstance(2030, 10, 08),
            NATT_QuantityFrom__c=1,
            NATT_UOM__c ='EA',
            NATT_ItemNumber__c=prod1.Name,
            NATT_CustomerNumber__c=0,
            NATT_ListPrice__c=20.50,
            NATT_Product__c=prod1.id                                   
        );
        
        Pricebook2 standardPricebook = new Pricebook2(
            Id = Test.getStandardPricebookId(),
            IsActive = true
            
        );
        Update standardPricebook;        
        standardPricebook = [SELECT Id, IsStandard FROM Pricebook2 WHERE Id = :standardPricebook.Id];
        PricebookEntry pbe2 = new PricebookEntry(
            Pricebook2Id = standardPricebook.Id,
            Product2Id = prod.Id,
            UnitPrice = 1,
            IsActive = true
        ); 
        Insert pbe2;
        PricebookEntry pbe21 = new PricebookEntry(
            Pricebook2Id = standardPricebook.Id,
            Product2Id = prod1.Id,
            UnitPrice = 1,
            IsActive = true
        ); 
        Insert pbe21;
        PricebookEntry pbe = new PricebookEntry(
            Pricebook2Id = pb2.Id,
            Product2Id = prod.Id,
            UnitPrice = 1,
            IsActive = true
        );  
        Insert pbe;
        PricebookEntry pbe11 = new PricebookEntry(
            Pricebook2Id = pb2.Id,
            Product2Id = prod1.Id,
            UnitPrice = 1,
            IsActive = true
        );  
        Insert pbe11;
        user us=NAC_TestDataFactory.runAsNACUser();
        Account acc=NAC_TestDataFactory.insertAccount();
        Contact con=[SELECT Id,AccountId from Contact where Id=:us.contactId Limit 1];
        BuyerGroup bg1=new BuyerGroup(Name='TestBG1',
                                      NAC_Type__c='C3');
        insert bg1;
        insert new BuyerAccount(IsActive=true,
                                PayerId=con.AccountId,
                                SendToId =con.AccountId,
                                Name='Test',
                                BuyerId=con.AccountId);
        
        insert new BuyerGroupMember(BuyerId=con.AccountId,
                                    BuyerGroupId=bg1.Id);
        WebStore webSt=NAC_TestDataFactory.webstoreCreation();
        insert new WebStoreBuyerGroup(BuyerGroupId=bg1.Id,
                                      WebStoreId=webSt.Id);
        Test.startTest();
        List<NAC_B2BGetInfoController.PriceChangeWrapper> priceListwrap= NAC_B2BGetInfoController.fetchPriceListChangeData();
        system.runAs(us){
            try{
                List<NAC_B2BGetInfoController.PriceChangeWrapper> priceListwrapus= NAC_B2BGetInfoController.fetchPriceListChangeData(); 
            }
            catch(Exception ex){
                
            }
            
        }
        Test.stopTest();
        
        System.assertNotEquals(priceListwrap.size(), 0, 'Not able to fetch the PriceListChangeData');
        
    }
    
   
    @isTest(SeeAllData=true)
    public static void getSortRule_Test(){
        returnData data = createData(true);
        Test.startTest();
        try{
            NAC_B2BGetInfoController.getSortRule(communityId);
        }catch(Exception e){
            
        }
        Test.stopTest();
    }
    
    @isTest(SeeAllData=false)
    public static void getEffectiveAccountId_Guest_Test(){
        Test.startTest();
        String guestEffAccId= NAC_B2BGetInfoController.getEffectiveAccountId(true);
        Test.stopTest();
        System.assertEquals(guestEffAccId != null,true,  'Guest effective Account is present');
    }
    @isTest(SeeAllData=false)
    public static void getEffectiveAccountId_NotGuest_Test(){
        User us=NAC_TestDataFactory.runAsNACUser();
        Contact con=[Select Id,AccountId from Contact where Id=:us.ContactId];
        String effAccId;
        Test.startTest();
        system.runAs(us){
            effAccId= NAC_B2BGetInfoController.getEffectiveAccountId(false);
        }
        Test.stopTest();
        System.assertEquals( effAccId != null, true, 'Effective Account is present');
    }
    @isTest(SeeAllData=false)
    public static void fetchSearchData_Test(){
        List<string> results = new List<string>();
        User us=NAC_TestDataFactory.runAsNACUser();
        String commId = [SELECT Id, Name FROM Network WHERE Name=:NAC_Global_Constants.DEFAULT_COMMUNITY_NAME_NAC].Id;
        Contact con=[Select Id,AccountId from Contact where Id=:us.ContactId];
        BuyerAccount buyerAccount = new BuyerAccount();
        buyerAccount.BuyerId = con.AccountId;
        buyerAccount.Name = 'Test Acc' + NAC_TestDataFactory.randomStringGenerator();
        buyerAccount.IsActive = true;
        insert buyerAccount;
        BuyerGroup bg = new BuyerGroup(Name=NAC_TestDataFactory.randomStringGenerator());
        insert bg;
        BuyerGroupMember bgm = new BuyerGroupMember(BuyerGroupId=bg.Id,BuyerId=con.AccountId);
        insert bgm;
        WebStore webSt=NAC_TestDataFactory.webstoreCreation();
        NAC_B2BUtils.communityIdToWebStoreIdCache.put(commId,webSt.id);
        
        WebStoreBuyerGroup wsbg = new WebStoreBuyerGroup(WebStoreId=webSt.Id,BuyerGroupId=bg.Id);
        insert wsbg;
        ProductCatalog pcat= new ProductCatalog(
            CurrencyIsoCode='USD',
            Name='Dealer Catalog'+Math.random()
        ); 
        insert pcat;
        WebStoreCatalog wbc = new WebStoreCatalog(SalesStoreId=webSt.Id,ProductCatalogId= pcat.Id);
        insert wbc;
        ProductCategory prodCat= new ProductCategory(
            CatalogId =pcat.Id,
            Name='Products',
            SortOrder=10
        );
        insert prodCat;
        Product2 prod = new Product2(
            Name='PORD10'+Math.random(),
            Stockkeepingunit='SKU0101'+Math.random(),
            ProductCode = 'SKU0101'+Math.random()
        );        
        insert prod;
        ProductCategoryProduct pcp = new ProductCategoryProduct(
            ProductCategoryId = prodCat.Id,
            IsPrimaryCategory=true,
            ProductId =prod.Id );
        insert pcp;
        
        CommerceEntitlementPolicy cepolicy = new CommerceEntitlementPolicy(
            IsActive=true,
            CanViewPrice=true,
            CanViewProduct=true,
            Name='ceploicy'+Math.random());
        insert cepolicy; 
        CommerceEntitlementProduct cep = new CommerceEntitlementProduct(
            PolicyId=cepolicy.Id,
            ProductId=prod.Id);
        insert cep;
        CommerceEntitlementBuyerGroup cebg= new CommerceEntitlementBuyerGroup(
            BuyerGroupId=bg.Id,
            PolicyId=cepolicy.Id);
        insert cebg;
        
        Test.startTest();
        results= NAC_B2BGetInfoController.fetchSearchData(commId,con.AccountId,'101');
        Test.stopTest();
        System.assertEquals(results.size()>0,true, 'results is Empty Line 237');
    }

    
    @isTest(SeeAllData=false)
    public static void getpartHistory_Test(){
        returnData data = new returnData();
        data.product2List = NAC_TestDataFactory.createProductList(5);
        
        
        Set<Id> prod2IdSet=new set<Id>();
        for(Product2 p:data.product2List){
            prod2IdSet.add(p.id);
        }
        List<NATT_AlternativeItem__c> altItemList = new List<NATT_AlternativeItem__c>();
        System.debug('dfdd::'+data.product2List.size());
        for(integer i = 0; i < data.product2List.size()-1; i++){
            //product2IdList.add(data.product2List[i].Id);
            // data.product2List[1].NATT_SignalCode__c = 'S2';
            if(i != data.product2List.size() - 1){
                System.debug('dfdd::'+data.product2List[i]);
                if(data.product2List[i].NATT_SignalCode__c == 'S2'){
                    NATT_AlternativeItem__c altItem = new NATT_AlternativeItem__c();
                    altItem.NATT_AlternativeItem__c = data.product2List[i+1].Id;
                    altItem.NATT_ProductItem__c = data.product2List[i].Id;
                    altItem.NATT_EffectiveDate__c = System.today();
                    altItemList.add(altItem);
                }
            }
        }
        Map<ID,List<NATT_AlternativeItem__c>> mapOfNatt=new MAp<ID,List<NATT_AlternativeItem__c>>();
        for(NATT_AlternativeItem__c ac:altItemList){
            if(mapOfNatt.containskey(ac.NATT_AlternativeItem__c)){
                List<NATT_AlternativeItem__c> temp=mapOfNatt.get(ac.id);
                temp.add(ac);
                mapOfNatt.put(ac.id,temp);
            }
            else{
                List<NATT_AlternativeItem__c> temp=new List<NATT_AlternativeItem__c>();
                temp.add(ac);
                mapOfNatt.put(ac.id,temp);
            }
        }
        Set<NAC_B2BGetInfoController.prodWrapper> altProd2Set=new set<NAC_B2BGetInfoController.prodWrapper>();
        List<NAC_B2BGetInfoController.prodWrapper> getpartHistoryReturn=NAC_B2BGetInfoController.getpartHistory(prod2IdSet,altProd2Set,mapOfNatt,true,'PAN');
        
    }
    @isTest(SeeAllData=true)
    public static void getProduct_Test(){
        
        returnData data = createData(true);
        Test.startTest();
        try{
            NAC_B2BGetInfoController.getProduct(communityId, data.product2List[1].Id, data.acc.Id);
        }catch(Exception e){
            
        }
        Test.stopTest();
        
    }
    
    @isTest(SeeAllData = true)
    public static void getCartSummary_Test(){
        returnData data = createData(true);
        Test.startTest();
        try{
            NAC_B2BGetInfoController.getCartSummary(communityId, data.acc.id);
        }catch(Exception e){
            
        }
        Test.stopTest();
    }
    
    @isTest(SeeAllData = true)
    public static void addToCart_Test(){
        returnData data = createData(true);
        Test.startTest();
        try{
            List<ConnectApi.CartItem> cartItemDetails = NAC_B2BGetInfoController.addToCart(communityId, data.product2List[0].Id, '4', data.acc.Id);
        }catch(Exception e){
            try{
                List<ConnectApi.CartItem> cartItemDetails = NAC_B2BGetInfoController.addToCart(communityId, data.product2List[1].Id, '4', data.acc.Id);
            }catch(Exception ex){
                system.debug('Exception@@@ '+ex);
            }
        }
        Test.stopTest();
    }
    
    @isTest(SeeAllData=true)
    public static void getProductPrice_Test(){
        returnData data = createData(true);
        Test.startTest();
        try{
            NAC_B2BGetInfoController.getProductPrice(communityId, data.product2List[1].Id, data.acc.Id);
        }catch(Exception e){
            
        }
        Test.stopTest();
    }
    
    
    @isTest(SeeAllData = true)
    public static void createAndAddToList_Test(){
        returnData data = createData(true);
        Test.startTest();
        try{
            NAC_B2BGetInfoController.createAndAddToList(communityId, data.product2List[1].Id,'TestWish', data.acc.Id);
        }catch(Exception e){
            
        }
        Test.stopTest();
    }
    
    @isTest(SeeAllData=true)
    public static void getSupersessionProducts_Test(){
        returnData data = createData(true);
        Test.startTest();
        try{
            NAC_B2BGetInfoController.getSupersessionProducts(communityId,data.acc.Id,data.product2List[2].Id);
        }catch(Exception e){
            
        }
        
        Test.stopTest();
        
    }
    
    @isTest(SeeAllData=true)
    public static void getCustomerSpecificPriceBookEntryId_Test(){
        returnData data = createData(true);
        User us=NAC_TestDataFactory.runAsNACUser();
        Test.startTest();
        try{
            NAC_B2BGetInfoController.getCustomerSpecificPriceBookEntryId(data.product2List[1].Id);
            system.runAs(us){
                NAC_B2BGetInfoController.getCustomerSpecificPriceBookEntryId(data.product2List[1].Id);
            }
        }catch(Exception e){
            
        }
        Test.stopTest();
    }
    
}