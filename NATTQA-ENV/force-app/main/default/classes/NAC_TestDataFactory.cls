/**
* @date 2022
* @description Test data factory. Should be used in every test class to generate data for testing.
*  Each object has function responsible for just creating given object,
*  and function which perform create and insert operation
* @group Testing util
*/


public without sharing class NAC_TestDataFactory {
    
    
    
 public static Id conRecordTypeId = Schema.SObjectType.Contact.getRecordTypeInfosByDeveloperName().get('NAOCAP_End_Customer').getRecordTypeId();
    
    
    /**********************************************************************************************
Method Number    :  M-001              
Method           :  create Cart
Description      :  Setup Data for Cart
*************************************************************************************************/
    //Inserts an account and returns it
    public static Account insertAccount(){
        Account a = new Account(Name='TestNACAccount'+randomStringGenerator(),NATT_Organization__c = 'NATT',NATT_Region__c = 'East');
        insert a;
        return a;
    }
    
    //Return a list of accounts
    public static List<Account> createAccounts(Integer numAccts) {
        List<Account> accts = new List<Account>();        
        for(Integer i=0; i<numAccts; i++) {
            Account a = new Account(Name = 'TestAccount' + i);
            a.ShippingStreet = '111 W Madison St';
            a.ShippingCity = 'Oak Park';
            a.ShippingState = 'IL';
            a.ShippingPostalCode = '60302';
            accts.add(a);
        }
        return accts;
    }
    
    //Inserts an account and returns it
    public static Contact insertAssociatedContact(Account a){
        Contact con = new Contact(LastName='TestNACContact',RecordTypeId=conRecordTypeId , AccountId=a.Id);
        insert con;
        return con;
    }
    
    //Insert buyer group and associate to an account
    public static BuyerAccount insertBuyerAccount(Account a){
        BuyerAccount buyerAccount = new BuyerAccount();
        buyerAccount.BuyerId = a.Id;
        buyerAccount.Name = 'Test Buyer Account (BA-AJ)'+randomStringGenerator();
        buyerAccount.IsActive = true;
        buyerAccount.BuyerStatus = 'Active';
        insert buyerAccount;
        return buyerAccount;
    }
    
    public static BuyerGroup insertBuyerGroup(){
        BuyerGroup bg = new BuyerGroup();
        bg.Name=randomStringGenerator();
        insert bg;
        return bg;
    }
    
    public static WebStoreBuyerGroup insertWebStoreBuyerGroup(Webstore webstore,BuyerGroup bg){
        WebStoreBuyerGroup wsbg = new WebStoreBuyerGroup();
        wsbg.WebStoreId=webstore.Id;
        wsbg.BuyerGroupId=bg.Id;
        insert wsbg;
        return wsbg;
    }
    
    public static BuyerGroupMember insertBuyerGroupMember(Account acc,BuyerGroup bg){
        
        List<BuyerAccount> byAct=[SELECT Id, BuyerId, IsActive FROM BuyerAccount where BuyerId=:acc.id AND isActive=true LIMIT 1];
        BuyerGroupMember bgm = new BuyerGroupMember();
        if(byAct.size() < 1){
         insertBuyerAccount(acc);
        }
        bgm.BuyerGroupId=bg.Id;
        bgm.BuyerId=acc.Id;
        insert bgm;
        return bgm;
    }
    
    public static WebStore buyerGroupAndMember(Account acc){
        BuyerAccount buyerAccount = new BuyerAccount();
        buyerAccount.BuyerId = acc.Id;
        buyerAccount.Name = 'Test Buyer Account (BA-AJ)';
        buyerAccount.IsActive = true;
        insert buyerAccount;
        BuyerGroup bg = new BuyerGroup(Name=NAC_TestDataFactory.randomStringGenerator());
        insert bg;
        BuyerGroupMember bgm = new BuyerGroupMember(BuyerGroupId=bg.Id,BuyerId=acc.Id);
        insert bgm;
        String communityId = NAC_TestDataFactory.getCommunityId();
        WebStore webstore = NAC_TestDataFactory.webstoreCreation();
        WebStoreBuyerGroup wsbg = new WebStoreBuyerGroup(WebStoreId=webstore.Id,BuyerGroupId=bg.Id);
        insert wsbg;
        return webstore;
    }
    
    public static String randomStringGenerator(){
        String orgId = UserInfo.getOrganizationId();
        String dateString = String.valueof(Datetime.now())
            .replace(' ', '')
            .replace(':', '')
            .replace('-', '');
        Integer randomInt = Integer.valueOf(math.rint(math.random() * 1000000));
        return orgId + dateString + randomInt;
    } 
    
    //Creates a user to run the flow as with input as contact ID
    public static User runAsNACUser(){
         Id conRecordTypeId = Schema.SObjectType.Contact.getRecordTypeInfosByDeveloperName().get('NAOCAP_End_Customer').getRecordTypeId();
        //UserRole userrole = [Select Id, DeveloperName From UserRole Limit 1];
        User adminUser = [Select Id,isActive, UserRoleId From User Where Profile.Name='System Administrator' AND UserRoleId != null AND isActive=true Limit 1];
        
        // adminUser.UserRoleId = userRole.Id;
        //update adminUser;
        User communityUser = new User();
        System.runAs(adminUser){
            Account a = insertAccount();
            Contact c = new Contact(LastName = 'Contact Last Name'+Math.random(),RecordTypeId=conRecordTypeId, AccountId = a.id);
            insert c;
            String orgId = UserInfo.getOrganizationId();
            String dateString = String.valueof(Datetime.now())
                .replace(' ', '')
                .replace(':', '')
                .replace('-', '');
            Integer randomInt = Integer.valueOf(math.rint(math.random() * 1000000));
            String uniqueName = orgId + dateString + randomInt;
            string profileName = 'NAC Customer Community Profile';
            Profile profile = [SELECT Id FROM Profile WHERE Name='NAC Customer Community Profile' LIMIT 1];
            
            communityUser = new User(Alias='buyer', Email='buyer@example.com', LastName='Buyer',
                                     TimeZoneSidKey='GMT', LocaleSidKey='en_US', Username=uniqueName+'@example.com',
                                     EmailEncodingKey='UTF-8', ProfileId=profile.Id, LanguageLocaleKey='en_US',
                                     ContactId=c.Id);
            insert communityUser;
            PermissionSet ps = [SELECT Id FROM PermissionSet WHERE Name='B2B_Commerce_User'];
            PermissionSetAssignment psa = new PermissionSetAssignment(PermissionSetId = ps.Id, AssigneeId = communityUser.Id);
            insert psa; 
        }
        return communityUser;
    }
    
    //Return Community Id
    public static String getCommunityId(){
        return [SELECT Id, Name FROM Network WHERE Name='NA Containers Marketplace'].Id;
    }
    
    //Link webstore to community
    public static WebStore webstoreCreation(){
        WebStore webStore = new WebStore(Name='NA Containers Marketplace');
        insert webStore;
        return webStore;
    }
    
    public static WebCart cartCreation(String webStoreId,String accId){ 
        WebCart cart = new WebCart(Name='Cart', WebStoreId=webStoreId, AccountId=accId, Status='active');
        insert cart;
        CartDeliveryGroup cartDeliveryGroup = new CartDeliveryGroup(CartId=cart.Id, Name='Default Delivery');
        insert cartDeliveryGroup;
        Id devRecordTypeId = Schema.SObjectType.Product2.getRecordTypeInfosByName().get('NAC Products').getRecordTypeId();
        Product2 prod = new Product2(Name ='testProd'+Math.random(),ProductCode ='--8E456',NATT_P_N__c='--8E456',
                                     NATT_CoreItem_P_N__c='--8E4567',
                                     StockkeepingUnit ='SKU'+Math.random() ,
                                     recordtypeid=devRecordTypeId,
                                     NATT_Branch_Plant_Warehouse__c ='ATL'
                                    );
        insert prod;
        Product2 coreprod = new Product2(Name ='testProdcore'+Math.random(),ProductCode ='--8E4567',NATT_P_N__c='--8E4567',
                                     StockkeepingUnit ='SKU'+Math.random(),
                                     recordtypeid=devRecordTypeId,
                                     NATT_Branch_Plant_Warehouse__c = 'ATL',
                                     NATT_Core__c=true
                                    );
        insert coreprod;
        Product2 coreprods2 = new Product2(Name ='testProdcore'+Math.random(),ProductCode ='--8E45699',
                                     StockkeepingUnit ='SKU'+Math.random(),
                                     recordtypeid=devRecordTypeId,
                                     NATT_Branch_Plant_Warehouse__c = 'ATL',NATT_SignalCode__c ='S2'                                   
                                    );
        insert coreprods2;
         Product2 nonCoreprod = new Product2(Name ='testProdnoncore'+Math.random(),ProductCode ='--8E458',NATT_P_N__c='--8E458',
                                     StockkeepingUnit ='SKU'+Math.random() ,
                                     recordtypeid=devRecordTypeId,NATT_Core__c=false,
                                     NATT_Branch_Plant_Warehouse__c ='ATL'
                                    );
        insert nonCoreprod;
        
        CartItem cartItem = new CartItem(
            CartId=cart.Id, 
            Sku='SKU_Test1',  
            Type='Product',
            
            PRoduct2Id=prod.id,
            Name='TestProduct', 
            CartDeliveryGroupId=cartDeliveryGroup.Id
        );
        insert cartItem;
        
       CartItem cartItem1 = new CartItem(
            CartId=cart.Id, 
            Sku='SKU_Test2', 
            Type='Product',
            PRoduct2Id=coreprod.id,
            Name='TestProduct1', 
            CartDeliveryGroupId=cartDeliveryGroup.Id
        );
        insert cartItem1;
        
        CartItem cartItem2 = new CartItem(
            CartId=cart.Id, 
            Sku='SKU_Test2', 
            Type='Product',
            PRoduct2Id=nonCoreprod.id,
            Name='TestProduct2', 
            CartDeliveryGroupId=cartDeliveryGroup.Id
        );
        insert cartItem2;
        
        return cart;
    }
    /*ANother webCArt addition
     public static WebCart cartCreationNon(String webStoreId,String accId){ 
        WebCart cart = new WebCart(Name='Cart', WebStoreId=webStoreId, AccountId=accId, Status='active');
        insert cart;
        CartDeliveryGroup cartDeliveryGroup = new CartDeliveryGroup(CartId=cart.Id, Name='Default Delivery');
        insert cartDeliveryGroup;
        Id devRecordTypeId = Schema.SObjectType.Product2.getRecordTypeInfosByName().get('NAC Products').getRecordTypeId();
        Product2 prod = new Product2(Name ='testProd'+Math.random(),ProductCode ='--8E456',NATT_P_N__c='--8E456',
                                     NATT_CoreItem_P_N__c='--8E4567',
                                     StockkeepingUnit ='SKU'+Math.random() ,
                                     recordtypeid=devRecordTypeId,
                                     NATT_Branch_Plant_Warehouse__c ='ATL'
                                    );
        insert prod;
        CartItem cartItem = new CartItem(
            CartId=cart.Id, 
            Sku='SKU_Test1', 
            Type='Product',
            PRoduct2Id=prod.id,
            Name='TestProduct', 
            CartDeliveryGroupId=cartDeliveryGroup.Id
        );
        insert cartItem;
        return cart;
    }*/
    
    
    public static NATT_ProductInventoryItem__c createProdInventory(Product2 p,String warehouse){
        NATT_ProductInventoryItem__c nic=new NATT_ProductInventoryItem__c();
         nic.NATT_ProductItem__c=p.id;
         nic.NATT_Warehouse__c=warehouse;
         return nic;
    }
    
    /**********************************************************************************************
Method Number    :  M-002              
Method           :  create Custom Setting Data for Warehouse selection
Description      :  Setup Data for Custom Setting
*************************************************************************************************/  
    /*public static List<NAC_WareHouseData__mdt> InsertCustomMetaWareHouse() {
        
        List<NAC_WareHouseData__mdt> customMetaList=new List<NAC_WareHouseData__mdt>();
        Account acc=insertAccount();
        Contact Con=insertAssociatedContact(acc);
        User us=runAsNACUser();
        insert us;
        
        NAC_WareHouseData__mdt cs = new NAC_WareHouseData__mdt();
        cs.external_url__c='www.google.com';
        cs.Warehouse_Name__c='Chile';
        cs.API_VALUE__c='CHI';
        //cs.SetupOwnerId=UserInfo.getUserId();
        cs.Redirection__c=true;
        cs.isActive__c=true;
        insert cs;
        
        customMetaList.add(cs);
        //insert customMetaList;
        return cs;
    } */
    
    /*Subendu - We dont need this method although keeping it for now just in case if we need to add one more user from another profile*/
    /**********************************************************************************************
Method Number    :  M-003              
Method           :  create Test User 
Description      :  Setup Data for Test User Creation
*************************************************************************************************/  
    /* public static User setUpTestUserDefaultProfile(){
Profile p = [SELECT Id FROM Profile WHERE Name=:DEFAULT_PROFILE_NAME]; 
Account acc=insertAccount();
Contact Con=insertAssociatedContact(acc);
User u = new User();
u.Alias = 'DefUser'; 
u.Email='DefaultProfileUser@testorg.com';
u.ContactId=Con.id;
u.EmailEncodingKey='UTF-8';
u.LastName='Testing';
u.LanguageLocaleKey='en_US'; 
u.LocaleSidKey='en_US'; 
u.ProfileId = p.Id; 
u.TimeZoneSidKey='America/Los_Angeles'; 
u.UserNPagani Huayra V12ame='DefaultProfileUser@testorg.com';
insert u; 

return u;
}*/
    
    /**********************************************************************************************
Method Number    :  M-004              
Method           :  create Content Version
Description      :  Setup Data for Creating Content Version to get the content document id from it
*************************************************************************************************/  
    public static List<ContentVersion> setUpContentDocument(Integer numberOfContentVersion){
        List<ContentVersion> contentVersionList = new List<ContentVersion>();
        for(integer i = 1; i <= numberOfContentVersion; i ++){
            ContentVersion cv = new ContentVersion();
            cv.Title = 'Test Document '+ i;
            cv.PathOnClient = 'TestDocument.pdf';
            contentVersionList.add(cv);
        }
        return contentVersionList;
    }
    
/**********************************************************************************************
Method Number    :                
Method           :  createshipment and Shipment Item
Description      :  Setup Data for Creating shipment and related objects
*************************************************************************************************/ 
    public static Shipment createShipment(String orderID){
     Shipment sh=new Shipment();
     sh.ShipToName='Test Shipment';
     sh.NATT_Order__c= orderID;
     return sh;
    }
    
    public static Shipmentitem createShipmentitem(String shipmentId,OrderItem OdItem){
     ShipmentItem shm=new  ShipmentItem();
     shm.ShipmentId = shipmentId;
     shm.NATT_OrderProduct__c=odItem.id;
     shm.Quantity=1;
     shm.Product2Id = odItem.Product2Id;
     return shm;
    }
    /**********************************************************************************************
Method Number    :  M-005              
Method           :  createOrder
Description      :  Setup Data for Creating Order and related objects
*************************************************************************************************/ 
    public static Order createOrder(String contactId,String accountId,String pricebookId){
      
        //Insert product
        Product2 prod = new Product2(Name ='testProd'+Math.random(),
                                     StockkeepingUnit ='SKU'+Math.random()                            
                                    );
        insert prod;
        Product2 prod1 = new Product2(Name ='testProd'+Math.random(),
                                     StockkeepingUnit ='SKU'+Math.random(),NATT_Sales_Code__c ='SM1',NATT_SignalCode__c ='S2',NATT_Core__c=true                        
                                    );
        insert prod1;
        PricebookEntry pbe = new PricebookEntry();
        //Instantiate the Pricebook2 record with StandardPricebookId
        if(String.isEmpty(pricebookId)){
            Pricebook2 standardPricebook = new Pricebook2(
                Id = Test.getStandardPricebookId(),
                IsActive = true
            );
            
            //Execute an update DML on the Pricebook2 record, to make IsStandard to true
            Update standardPricebook;
            //Query for the Pricebook2 record, to check IsStandard field
            standardPricebook = [SELECT Id, IsStandard FROM Pricebook2 WHERE Id = :standardPricebook.Id];
            
            //Create the PricebookEntry
            pbe = new PricebookEntry(
                Pricebook2Id = standardPricebook.Id,
                Product2Id = prod.Id,
                UnitPrice = 1,
                IsActive = true
            );
            Insert pbe;
        }
        else{
            // In See all Data = true ONLY use below code if using connect APIs or to generate Order Summary
            pbe = [Select Id,UnitPrice,Pricebook2Id from PriceBookEntry Where Pricebook2Id=:PricebookId And IsActive = true Limit 1];
        }
        
        
        Order o = new Order(
            EffectiveDate = Date.today(),
            Status = 'Draft',
            AccountId = accountId,
            BillToContactId = contactId,
            BillingState = 'CA',
            BillingCity = 'Beverly Hills',
            BillingCountry = 'US',
            BillingPostalCode = '90210',
            BillingStreet = '444 Fake St.',
            OrderedDate = Datetime.newInstance(2022, 1, 2, 3, 4, 5),
            Pricebook2Id = !(String.isEmpty(PricebookId)) ? PricebookId: System.Test.getStandardPricebookId()
        );
        insert o;
        OrderDeliveryMethod orderDeliveryMethod = new OrderDeliveryMethod(
            Name = 'software-shipping',
            ProductId = prod.Id
        );
        insert orderDeliveryMethod;
        OrderDeliveryGroup orderDeliveryGroup = new OrderDeliveryGroup(
            DeliverToName = 'Buyer USer',
            DeliverToStreet = 'test Street',
            DeliverToCity = 'Minneapolis',
            DeliverToState = 'MN',
            DeliverToPostalCode = '55402',
            DeliverToCountry = 'US',
            OrderDeliveryMethodId = orderDeliveryMethod.Id,
            OrderId = o.Id
        );
        insert orderDeliveryGroup;
        
        OrderItem orderItem = new OrderItem(
            Product2Id = prod.Id,
            Type = 'Order Product',
            Quantity = 1,
            ListPrice = pbe.UnitPrice,
            UnitPrice = pbe.UnitPrice,
            OrderId = o.Id,
            OrderDeliveryGroupId = orderDeliveryGroup.Id,
            PricebookEntryId = pbe.Id,
            TotalLineAmount = 1
        );
          insert orderItem;
        system.debug('orderItem@@@'+orderItem);
         OrderItem orderItem1 = new OrderItem(
            Product2Id = prod1.Id,
            Type = 'Order Product',
            Quantity = 1,
            ListPrice = pbe.UnitPrice,
            UnitPrice = pbe.UnitPrice,
            OrderId = o.Id,
            OrderDeliveryGroupId = orderDeliveryGroup.Id,
            PricebookEntryId = pbe.Id,
            TotalLineAmount = 1
        );
        insert orderItem1;
        system.debug('orderItem1@@'+orderItem1);
        o.Status = 'Activated';
        update o;
        
        if(!String.isEmpty(pricebookId)){
            ConnectApi.OrderSummaryInputRepresentation osir = new ConnectApi.OrderSummaryInputRepresentation();
            osir.orderId=o.Id;
            osir.orderLifeCycleType='MANAGED';
            ConnectApi.OrderSummaryOutputRepresentation osor =ConnectApi.OrderSummaryCreation.createOrderSummary(osir);
        }
        
        return o;
    }
    /**********************************************************************************************
Method Number    :  M-006             
Method           :  createProductCategory
Description      :  Setup Data for Creating ProductCategory
*************************************************************************************************/  
    public static ProductCategory createProductCategory(String webstoreId){
        List<WebStoreCatalog> webStoreCatalogList = [SELECT Id, ProductCatalogId FROM WebStoreCatalog WHERE SalesStoreId =: webstoreId];
        string catalogId;
        if(!webStoreCatalogList.isEmpty()){
            catalogId = webStoreCatalogList[0].ProductCatalogId;
        }else{
            ProductCatalog pcat = new ProductCatalog(
                CurrencyIsoCode = 'USD',
                Name = 'Dealer Catalog'+Math.random()
            ); 
            insert pcat;
            catalogId = pcat.Id;
            WebStoreCatalog webstCatalog = new WebStoreCatalog(
                ProductCatalogId = catalogId,
                SalesStoreId = webstoreId
            );        
            insert webstCatalog; 
        }
        ProductCategory prodCat = new ProductCategory(
            CatalogId = catalogId,
            Name = 'Products',
            SortOrder = 10
        );
        insert prodCat;
        return prodCat;
    }
    /**********************************************************************************************
Method Number    :  M-006             
Method           :  createProductCategoryProduct
Description      :  Setup Data for Creating ProductCategoryProduct 
*************************************************************************************************/  
    public static void createProductCategoryProductList(Map<Id,List<Id>> categoryIdProductListIdMap){
        List<ProductCategoryProduct> pcpList = new List<ProductCategoryProduct>();
        for(Id categoryId : categoryIdProductListIdMap.keySet()){
            for(Id product2Id : categoryIdProductListIdMap.get(categoryId)){
                ProductCategoryProduct pcp = new ProductCategoryProduct();
                pcp.ProductCategoryId = categoryId;
                pcp.ProductId = product2Id;
                pcp.IsPrimaryCategory = false;
                pcpList.add(pcp);
            }
        }
        insert pcpList;
    }
    
    //**********************************************************************************************
    // Method Number    :  M-007           
    // Method           :  createProduct
    // Description      :  Setup Data for Creating Product
    //*************************************************************************************************
    public static List<Product2> createProductList(Integer numberOfProducts){
        List<Product2> product2List = new List<Product2>();
        for(integer i = 1; i <= numberOfProducts; i ++){
            Product2 prod = new Product2(
                Name='Test Product '+ i,
                ProductCode='Test Product '+ i,
                Stockkeepingunit='SKU1010-'+ i
            );
            product2List.add(prod);
        }
        return product2List;
    }
    
    //**********************************************************************************************
    // Method Number    :  M-008          
    // Method           :  createPriceBook
    // Description      :  Create PriceBook.
    //*************************************************************************************************
    public static List<PriceBook2> createPriceBook(Integer numberOfPriceBook){
        List<PriceBook2> priceBookList = new List<PriceBook2>();
        for(integer i = 1; i <= numberOfPriceBook; i ++){
            PriceBook2 pb = new PriceBook2();
            pb.IsActive = true;
            pb.Name = 'TEST PriceBook - '+ i;
            priceBookList.add(pb);
        }
        return priceBookList;
    }
    
    //**********************************************************************************************
    // Method Number    :  M-009          
    // Method           :  createPriceBookEntry
    // Description      :  Setup Data for Creating PriceBookentry and dependent records.
    //*************************************************************************************************
    public static void createPriceBookEntry(Map<Id, Map<Id,Decimal>> priceBookIdProductIdPriceMap){
        List<PricebookEntry> insertPriceBookEntryList = new List<PricebookEntry>();
        Set<Id> createdPriceBookProductId= new Set<Id>();
        Id standardPricebookId = Test.getStandardPricebookId();
        for(Id pricebookId : priceBookIdProductIdPriceMap.keySet()){
            for(Id productId : priceBookIdProductIdPriceMap.get(pricebookId).keySet()){
                if(!createdPriceBookProductId.contains(productId)){
                    PricebookEntry standardPriceBookEntry = new PricebookEntry();
                    standardPriceBookEntry.Pricebook2Id = standardPricebookId;
                    standardPriceBookEntry.Product2Id = productId;
                    standardPriceBookEntry.UnitPrice = priceBookIdProductIdPriceMap.get(pricebookId).get(productId);
                    standardPriceBookEntry.IsActive = true;
                    insertPriceBookEntryList.add(standardPriceBookEntry);
                    createdPriceBookProductId.add(productId);
                }
                PricebookEntry customPriceBookEntry = new PricebookEntry();
                customPriceBookEntry.Pricebook2Id = pricebookId;
                customPriceBookEntry.Product2Id = productId;
                customPriceBookEntry.UnitPrice = priceBookIdProductIdPriceMap.get(pricebookId).get(productId);
                customPriceBookEntry.NAOCAP_Customer_List_Price__c = priceBookIdProductIdPriceMap.get(pricebookId).get(productId);
                customPriceBookEntry.IsActive = true;
                insertPriceBookEntryList.add(customPriceBookEntry);
            }
        }
        insert insertPriceBookEntryList;
    }
    
    //**********************************************************************************************
    // Method Number    :  M-011          
    // Method           :  Return the Product for connect API 
    // Description      :  Setup Data for Returning the Product assocaited with the webStore
    //*************************************************************************************************
    public static Product2 getProductFromWebStore(String webstoreId){
       	    WebStoreBuyerGroup wsbp=[Select Id,BuyerGroupId,WebStoreId from WebStoreBuyerGroup where WebStoreId=:webstoreId Limit 1];
            BuyerGroupMember bgm =[Select Id,BuyerId,BuyerGroupId from BuyerGroupMember Where BuyerGroupId=:wsbp.BuyerGroupId Limit 1];
            BuyerGroupPricebook bgpb=[Select Id,Pricebook2Id from BuyerGroupPricebook Where BuyerGroupId =:bgm.BuyerGroupId AND IsActive = true Limit 1];
            PriceBookEntry pBook=[select Product2Id, id,Pricebook2Id from PriceBookEntry where Pricebook2Id=:bgpb.Pricebook2Id  AND IsActive=true Limit 1];
            Product2 getProduct=[select id from Product2 where id=:pBook.Product2Id AND IsActive=true];
            return getProduct;
    }
    
    //**********************************************************************************************
    //Method Number    :  M-012
    //Method           :  Return the List<CommerceEntitlementPolicy>
    //Description      :  Setup Data for Returning the List<CommerceEntitlementPolicy> assocaited with the webStore
    //*************************************************************************************************
    public static List<CommerceEntitlementPolicy> createCommerceEntitlementPolicy(Integer numberOfPolicies){
        List<CommerceEntitlementPolicy> cepList = new List<CommerceEntitlementPolicy>();
        for(integer i = 1; i <= numberOfPolicies; i ++){
            CommerceEntitlementPolicy cep = new CommerceEntitlementPolicy();
            cep.CanViewPrice = true;
            cep.CanViewProduct = true;
            cep.CurrencyIsoCode = 'USD';
            cep.IsActive = true;
            cep.Name = 'Commerce Entitlement Policy ' + i;
            cepList.add(cep);
        }
        return cepList;
    }
    
    //**********************************************************************************************
    // Method Number    :  M-014
    // Method           :  Insert the List<CommerceEntitlementBuyerGroup>
    // Description      :  Link Entitlement Policy with Buyer Group
    //*************************************************************************************************
    public static void createCommerceEntitlementBuyerGroup(Map<Id,List<Id>> policyIdBuyerGroupListIdMap){
        List<CommerceEntitlementBuyerGroup> ceBgList = new List<CommerceEntitlementBuyerGroup>();
        for(Id policyId : policyIdBuyerGroupListIdMap.keySet()){
            for(Id buyerGroupId : policyIdBuyerGroupListIdMap.get(policyId)){
                CommerceEntitlementBuyerGroup ceBg = new CommerceEntitlementBuyerGroup();
                ceBg.PolicyId = policyId;
                ceBg.BuyerGroupId = buyerGroupId;
                ceBg.CurrencyIsoCode = 'USD';
                ceBgList.add(ceBg);
            }
        }
        insert ceBgList;
    }
    
    //**********************************************************************************************
    // Method Number    :  M-015
    // Method           :  Insert the List<CommerceEntitlementProduct>
    // Description      :  Link Entitlement Policy with Product
    //*************************************************************************************************
    public static void createCommerceEntitlementProduct(Map<Id,List<Id>> policyIdProductListIdMap){
        List<CommerceEntitlementProduct> ceProdList = new List<CommerceEntitlementProduct>();
        for(Id policyId : policyIdProductListIdMap.keySet()){
            for(Id product2Id : policyIdProductListIdMap.get(policyId)){
                CommerceEntitlementProduct ceProd = new CommerceEntitlementProduct();
                ceProd.PolicyId = policyId;
                ceProd.ProductId = product2Id;
                ceProd.CurrencyIsoCode = 'USD';
                ceProdList.add(ceProd);
            }
        }
        insert ceProdList;
    }
    
    //**********************************************************************************************
    // Method Number    :  M-016
    // Method           :  Insert the List<BuyerGroupPricebook>
    // Description      :  Link Buyer Group with PriceBook
    //*************************************************************************************************
    public static void createBuyerGroupPricebook(Map<Id,List<Id>> policyIdPriceBookListIdMap){
        List<BuyerGroupPricebook> bgPriceBookList = new List<BuyerGroupPricebook>();
        for(Id BuyerGroupId : policyIdPriceBookListIdMap.keySet()){
            for(Id priceBookId : policyIdPriceBookListIdMap.get(BuyerGroupId)){
                BuyerGroupPricebook bgPriceBook = new BuyerGroupPricebook();
                bgPriceBook.BuyerGroupId = BuyerGroupId;
                bgPriceBook.Pricebook2Id = priceBookId;
                bgPriceBook.IsActive = true;
                bgPriceBookList.add(bgPriceBook);
            }
        }
        insert bgPriceBookList;
    }
    
    //**********************************************************************************************
    // Method Number    :  M-017
    // Method           :  Create List<WebCart>
    // Description      :  Create a list of Empty webCart
    //*************************************************************************************************
    public static List<WebCart> createWebCart(Map<Id,Map<Id,String>> storeIdAccountIdStatusListMap){
        List<WebCart> webCartList = new List<WebCart>();
        integer i = 1;
        for(Id storeId : storeIdAccountIdStatusListMap.keySet()){
            for(Id accountId : storeIdAccountIdStatusListMap.get(storeId).keySet()){
                WebCart cart = new WebCart();
                cart.Name = 'TEST Cart '+ i;
                cart.WebStoreId = storeId;
                cart.AccountId = accountId;
                cart.Status = storeIdAccountIdStatusListMap.get(storeId).get(accountId);
                webCartList.add(cart);
                i++;
            }
        }
        return webCartList;
    }
    
    //**********************************************************************************************
    // Method Number    :  M-018
    // Method           :  Create List<NATT_ItemPriceStaging__c>
    // Description      :  Create a list of NATT Item Price Staging
    //*************************************************************************************************
    public static List<NATT_ItemPriceStaging__c> createNATTitemPriceStaging(List<Id> productIdList){
        Id recordTypeId = Schema.SObjectType.NATT_ItemPriceStaging__c.getRecordTypeInfosByDeveloperName().get('NAOCAP').getRecordTypeId();
        List<NATT_ItemPriceStaging__c> itemStagingList = new List<NATT_ItemPriceStaging__c>();
        for(Id prodId : productIdList){
            NATT_ItemPriceStaging__c itemStaging = new NATT_ItemPriceStaging__c();
            itemStaging.NATT_Product__c = prodId;
            itemStaging.NAOCAP_Under_Processing__c = true;
            itemStaging.RecordTypeId = recordTypeId;
            itemStaging.NATT_EffectiveDate__c = System.today() - 1;
            itemStaging.NATT_ExpiryDate__c = System.today() + 1;
            itemStaging.NATT_ListPrice__c = Math.random() * 100;
            itemStagingList.add(itemStaging);
        }
        return itemStagingList;
    }
    
    //**********************************************************************************************
    // Method Number    :  M-019
    // Method           :  Create List<NATT_PriceAdjustmentStaging__c>
    // Description      :  Create a list of NATT Price Adjustment Staging
    //*************************************************************************************************
    public static List<NATT_PriceAdjustmentStaging__c> createNATTpriceAdjustmentStaging(Integer numberOfPolicies){
        Id recordTypeId = Schema.SObjectType.NATT_PriceAdjustmentStaging__c.getRecordTypeInfosByDeveloperName().get('NAOCAP').getRecordTypeId();
        List<NATT_PriceAdjustmentStaging__c> priceAdjustmentStagingList = new List<NATT_PriceAdjustmentStaging__c>();
        for(integer i = 1; i <= numberOfPolicies; i ++){
            NATT_PriceAdjustmentStaging__c priceAdjustmentStaging = new NATT_PriceAdjustmentStaging__c();
            priceAdjustmentStaging.NAOCAP_Under_Processing__c = true;
            priceAdjustmentStaging.RecordTypeId = recordTypeId;
            priceAdjustmentStaging.NATT_EffectiveDate__c = System.today() - 1;
            priceAdjustmentStaging.NATT_ExpiryDate__c = System.today() + 1;
            priceAdjustmentStagingList.add(priceAdjustmentStaging);
        }
        return priceAdjustmentStagingList;
    }
    
    //**********************************************************************************************
    // Method Number    :  M-020
    // Method           :  Create List<GuestBuyerProfile>
    // Description      :  Create a list of Guest Buyer Profile
    //*************************************************************************************************
    public static List<GuestBuyerProfile> createGuestBuyerProfile(List<String> guestBuyerProfileNameList){
        List<GuestBuyerProfile> guestBuyerProfileList = new List<GuestBuyerProfile>();
        for(String guestBuyerProfileName : guestBuyerProfileNameList){
            GuestBuyerProfile gBuyerProfile = new GuestBuyerProfile();
            gBuyerProfile.Name = guestBuyerProfileName;
            guestBuyerProfileList.add(gBuyerProfile);
        }
        return guestBuyerProfileList;
    }
    
    public class calloutPostiveResponses implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            String body = '';
            if(req.getEndpoint().contains('/maps/api/geocode/json')){
                body = '{'+
                    '   \"results\" : ['+
                    '      {'+
                    '         \"address_components\" : ['+
                    '            {'+
                    '               \"long_name\" : \"30318\",'+
                    '               \"short_name\" : \"30318\",'+
                    '               \"types\" : [ \"postal_code\" ]'+
                    '            },'+
                    '            {'+
                    '               \"long_name\" : \"Atlanta\",'+
                    '               \"short_name\" : \"Atlanta\",'+
                    '               \"types\" : [ \"locality\", \"political\" ]'+
                    '            },'+
                    '            {'+
                    '               \"long_name\" : \"Fulton County\",'+
                    '               \"short_name\" : \"Fulton County\",'+
                    '               \"types\" : [ \"administrative_area_level_2\", \"political\" ]'+
                    '            },'+
                    '            {'+
                    '               \"long_name\" : \"Georgia\",'+
                    '               \"short_name\" : \"GA\",'+
                    '               \"types\" : [ \"administrative_area_level_1\", \"political\" ]'+
                    '            },'+
                    '            {'+
                    '               \"long_name\" : \"United States\",'+
                    '               \"short_name\" : \"US\",'+
                    '               \"types\" : [ \"country\", \"political\" ]'+
                    '            }'+
                    '         ],'+
                    '         \"formatted_address\" : \"Atlanta, GA 30318, USA\",'+
                    '         \"geometry\" : {'+
                    '            \"bounds\" : {'+
                    '               \"northeast\" : {'+
                    '                  \"lat\" : 33.833444,'+
                    '                  \"lng\" : -84.37363209999999'+
                    '               },'+
                    '               \"southwest\" : {'+
                    '                  \"lat\" : 33.730247,'+
                    '                  \"lng\" : -84.4962731'+
                    '               }'+
                    '            },'+
                    '            \"location\" : {'+
                    '               \"lat\" : 33.7946333,'+
                    '               \"lng\" : -84.44877199999999'+
                    '            },'+
                    '            \"location_type\" : \"APPROXIMATE\",'+
                    '            \"viewport\" : {'+
                    '               \"northeast\" : {'+
                    '                  \"lat\" : 33.833444,'+
                    '                  \"lng\" : -84.37363209999999'+
                    '               },'+
                    '               \"southwest\" : {'+
                    '                  \"lat\" : 33.730247,'+
                    '                  \"lng\" : -84.4962731'+
                    '               }'+
                    '            }'+
                    '         },'+
                    '         \"place_id\" : \"ChIJpQ4QXDAb9YgR5d8TNErZGH0\",'+
                    '         \"types\" : [ \"postal_code\" ]'+
                    '      }'+
                    '   ],'+
                    '   \"status\" : \"OK\"'+
                    '}';
            }else if(req.getEndpoint().contains('/search/product-search')){
                body= '{'+
                    '\"locale\": \"en_US\",'+
                    '   \"total\": 1,'+
                    '      \"pageSize\": 20,'+
                    '         \"categoriesData\": {'+
                    '            \"category\": {'+
                    '               \"description\": \"All Categories\",'+
                    '                  \"name\": \"All Categories\"'+
                    '                     },'+
                    '                        \"children\": ['+
                    '                           {'+
                    '                              \"category\": {'+
                    '                                 \"id\": \"0ZG7e0000008ObBGAU\",'+
                    '                                    \"name\": \"Products\"'+
                    '                                       },'+
                    '                                          \"children\": [],'+
                    '                                             \"productCount\": 1'+
                    '                                                }'+
                    '               ],'+
                    '                  \"productCount\": 1'+
                    '                     },'+
                    '                        \"facetsData\": ['+
                    '                           {'+
                    '                              \"id\": \"Model__c:Custom\",'+
                    '                                 \"nameOrId\": \"Model__c\",'+
                    '                                    \"attributeType\": \"Custom\",'+
                    '                                       \"type\": \"DistinctValue\",'+
                    '                                          \"displayType\": \"MultiSelect\",'+
                    '                                             \"displayName\": \"Model Group\",'+
                    '                                                \"displayRank\": 3,'+
                    '                                                   \"values\": ['+
                    '                                                      {'+
                    '                                                         \"displayName\": \"1169NT107\",'+
                    '                                                            \"nameOrId\": \"1169NT107\",'+
                    '                                                               \"productCount\": 1,'+
                    '                                                                  \"type\": \"DistinctValue\",'+
                    '                                                                     \"checked\": false'+
                    '                                                                        }'+
                    '                                           ]'+
                    '          }'+
                    '     ],'+
                    '        \"layoutData\": ['+
                    '           {'+
                    '              \"id\": \"01t7e000007DXIVAA4\",'+
                    '                 \"name\": \"5W-20 Oil 101\",'+
                    '                    \"fields\": ['+
                    '                       {'+
                    '                          \"name\": \"Name\",'+
                    '                             \"value\": \"5W-20 Oil 101\"'+
                    '                                }'+
                    '               ],'+
                    '                  \"image\": {'+
                    '                     \"url\": \"/NAContainersMarketplace/img/b2b/default-product-image.svg\",'+
                    '                        \"title\": \"image\",'+
                    '                           \"alternateText\": \"\"'+
                    '                              },'+
                    '                                 \"prices\": {'+
                    '                                    \"currencyIsoCode\": \"USD\"'+
                    '                                       }'+
                    '}'+
                    ']'+
                    '};'+
                    '}';
            }
            res.setBody(body);
            res.setStatusCode(200);
            return res;
            
        }
    }
    
    public class calloutNegativeResponses implements HttpCalloutMock{
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            String body = '';
            if(req.getEndpoint().contains('/search/product-search')){
                body= '{}';
            }
            res.setBody(body);
            res.setStatusCode(400);
            return res;
        }
    }
}