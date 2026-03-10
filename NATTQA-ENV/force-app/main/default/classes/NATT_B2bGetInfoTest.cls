@IsTest
private class NATT_B2bGetInfoTest {
    
    @IsTest(seeAllData = true)
    static void myUnitTest(){
        Product2 p = new Product2();
        Pricebook2 pb = new Pricebook2();
        String communityId =[SELECT Id, Name FROM Network WHERE Name='Performance Parts'].Id;
        system.debug('communityId-'+communityId);
        user thisUser = new User(Id = UserInfo.getUserId());
        user adminUser = new user();
        system.runAs(thisUser){
        p = new Product2(Name='Test',IsActive=true,NATT_P_N__c='asdf1237');
        insert p;
        
        pb = new Pricebook2(Name='TestPb',IsActive=true);
        insert pb;
        
        PricebookEntry spbe = new PricebookEntry(Product2Id=p.Id,Pricebook2Id=Test.getStandardPricebookId(),UnitPrice=1);
        insert spbe;
        
        PricebookEntry pbe = new PricebookEntry(Product2Id=p.Id,Pricebook2Id=pb.Id,UnitPrice=1, UseStandardPrice = true);
        insert pbe;
            adminUser = createAdminUser();
        }
		user commUser = new user();
        Account a1 = new Account();
        Contact contact1 = new contact();
        system.runAs(adminUser){
            a1 = new Account(Name='TestAccount31',NATT_Organization__c = 'NATT',NATT_Region__c = 'East');
            insert a1;
            contact1 = new Contact(LastName='TestContactbuy31', AccountId=a1.Id);
            insert contact1;
             commUser =   createUser(contact1.Id);
        }
        BuyerAccount buyerAccount = new BuyerAccount();
        buyerAccount.BuyerId = a1.Id;
        buyerAccount.Name = 'Test Buyer Account (BA-AJ)';
        buyerAccount.IsActive = true;
        insert buyerAccount;
        WebStore webStore = new WebStore(Name='Performance Parts');
        insert webStore;
        //commUser =[select id,name,contactId,contact.accountID from user where profile.Name='B2B Customer Community User' and IsActive= true  limit 1];
          //  webStore = [SELECT Id FROM WebStore WHERE Name='Performance Parts'];
        //Test.startTest();
        //createUser(contact.Id);
        //Test.stopTest();
        
        WebCart secondaryCart;
        System.runAs(commUser){
            WebCart cart = new WebCart(Name='Cart', WebStoreId=webStore.Id, AccountId=a1.Id,Status='Active',isSecondary=false);
            insert cart;
            
            
            secondaryCart = new WebCart(
                AccountId = a1.Id,
                WebStoreId = webStore.Id,
                Name = 'Test Cart 02',
                isSecondary = true
            );
            insert secondaryCart;
        }
        
         //BuyerGroup bg = new BuyerGroup(Name='Performance Parts Buyer Group');
        // insert bg;
        BuyerGroup bg = [SELECT ID FROM BuyerGroup WHERE Name = 'Performance Parts Buyer Group'];
        system.debug('communityId-bg--'+bg);system.debug('communityId-'+communityId);
        BuyerGroupMember bgm = new BuyerGroupMember(BuyerGroupId=bg.Id,BuyerId=a1.Id);
        insert bgm;
        
        // WebStoreBuyerGroup wsbg = new WebStoreBuyerGroup(WebStoreId=webStore.Id,BuyerGroupId=bg.Id);
        // insert wsbg;
        
        List<CommerceEntitlementPolicy> policyList = new List<CommerceEntitlementPolicy>([SELECT Id FROM CommerceEntitlementPolicy WHERE Name='NATTViewProductPrice']);
        if(policyList.isEmpty()){
            policyList.add(new CommerceEntitlementPolicy(Name='NATTViewProductPrice',IsActive=true,CanViewPrice=true,CanViewProduct=true));
            insert policyList;
        }
        
        //link the buyer group with the policy
        Map<Id,CommerceEntitlementBuyerGroup> cebgMap = new Map<Id,CommerceEntitlementBuyerGroup>();
        for(CommerceEntitlementBuyerGroup cebg : [SELECT Id,BuyerGroupId FROM CommerceEntitlementBuyerGroup WHERE BuyerGroupId =:bg.Id AND PolicyId=:policyList.get(0).Id]){
            cebgMap.put(cebg.BuyerGroupId,cebg);
        }
        
        List<CommerceEntitlementBuyerGroup> entBuyerGroupList = new List<CommerceEntitlementBuyerGroup>();
        
        if(!cebgMap.containsKey(bg.Id)){
            entBuyerGroupList.add(new CommerceEntitlementBuyerGroup(BuyerGroupId=bg.Id,PolicyId=policyList.get(0).Id));
        }
        
        if(!entBuyerGroupList.isEmpty()){
            insert entBuyerGroupList;
        }
        
        
        List <WebCart> newCartList = new List <Webcart>();
        ConnectApi.CartSummary summary = NATT_PpgCartController.createCart(communityId,a1.Id);
        CartDeliveryGroup cartDeliveryGroup = new CartDeliveryGroup(CartId=summary.cartId, Name='Default Delivery');
        insert cartDeliveryGroup;
        CartItem ci = new CartItem(CartId=summary.cartId,Name='Test',Product2Id=p.Id,TotalPrice=2,CartDeliveryGroupId=cartDeliveryGroup.Id);
        insert ci;
        List<ConnectApi.CartItemInput> ciInputList = new List<ConnectApi.CartItemInput>();
        ConnectApi.CartItemInput ciInput = new ConnectApi.CartItemInput();
        ciInput.quantity='2.00';
        ciInputList.add(ciInput); 
        //Product2 newProduct = [SELECT ID FROM Product2 WHERE ID = '01tP0000007XmUBIA0' LIMIT 1];
        
        String[] sArray = new String[]{p.Id, '1'};
            
            List<String[]> products = new List<String[]>();            
        products.add(sArray);
        ConnectApi.CartSummary testCart = null;
        List<ConnectApi.BatchResult> testResult = new List<ConnectApi.BatchResult>();
        ConnectApi.ProductSearchResults testSearchResults = null;
        ConnectApi.ProductPrice testPrice = null;
        ConnectApi.ProductDetail testDetail = null;
        testCart = NATT_B2bGetInfo.getCartSummary(communityId, a1.Id);
        System.debug('Test Cart: ' + testCart);
        // Product2 newProduct = [SELECT ID FROM Product2 WHERE ID = '01tP0000007XmUBIA0' LIMIT 1];
        Boolean testgetProductPricePass = false;
        Boolean testaddItemsToCartPass = false;
        Boolean testproductSearchPass = false;
        Boolean testgetProductDetailPass = false;
        try{
            testPrice = NATT_B2bGetInfo.getProductPrice(communityId, p.Id, a1.Id);
            System.debug('Test Price: ' + testPrice);
            testgetProductPricePass = true;
        }catch(Exception e){
            testgetProductPricePass = false;
        }
        try{
            testResult = NATT_B2BGetInfo.addItemsToCart(communityId, a1.Id, products);   
            System.debug('Test items to cart: ' + testResult);
            testaddItemsToCartPass = true;
        }catch(Exception e){
            testaddItemsToCartPass = false;
        }
        try{
            testSearchResults = NATT_B2BGetInfo.productSearch(communityId, 'asdf123', a1.Id);
            NATT_B2BGetInfo.quickProductSearch(communityId, 'asdf123', a1.Id);
            System.debug('Test search results: ' + testSearchResults);
            testproductSearchPass = true;
        }catch(Exception e){
            system.debug(e);
            testproductSearchPass = false;
        }
        try{
            NATT_B2BGetInfo.quickProductSearch(communityId, 'asdf123', a1.Id);
        }catch(Exception e){
            system.debug(e);
        }
        try{
            testDetail = NATT_B2BGetInfo.getProductDetail(communityId,  p.Id, a1.Id);
            System.debug('test product detail: ' + testDetail);
            testgetProductDetailPass = true;
        }catch(Exception e){
            testgetProductDetailPass = false; 
        }
        try{
            //cover Exception
            NATT_B2BGetInfo.updateWebCart(a1.Id, 'PAN');
            
        } catch (Exception e) {
            system.debug(e);
        } 
        try{
            NATT_B2BGetInfo.updateWebCart(summary.cartId, 'PAN');
            
        } catch (Exception e) {
            system.debug(e);
        }
        /*System.assertEquals(true, testgetProductPricePass, 'We expect getProductPrice to successfully return price.');
		System.assertEquals(true, testaddItemsToCartPass, 'We expect addItemsToCart to successfully add items to the cart.');
		System.assertEquals(true, testproductSearchPass, 'We expect productSearch to successfully return search results.');
		System.assertEquals(true, testgetProductDetailPass, 'We expectgetProductDetail to successfully return product detail info.');       */
        
    }
  //  @future
     private static user createUser(String cId){
        Profile profile = [SELECT Id FROM Profile WHERE Name='B2B Customer Community User' LIMIT 1];
        User user = new User(Alias='buyer', Email='buyer@example.com', LastName='Buyer11', ContactId=cId,
                             TimeZoneSidKey='GMT',  LocaleSidKey='en_US',  Username='buyer11@example.com',
                             EmailEncodingKey='UTF-8', ProfileId=profile.Id, LanguageLocaleKey='en_US' );
        insert user;
        
        PermissionSet ps = [SELECT Id FROM PermissionSet WHERE Name='B2B_Commerce_User'];
        PermissionSetAssignment psa = new PermissionSetAssignment(PermissionSetId = ps.Id, AssigneeId = user.Id);
        insert psa; 
        return user;
    }
    private static user createAdminUser(){
        Profile profile = [SELECT Id FROM Profile WHERE Name='System Administrator' LIMIT 1];
        UserRole role = [SELECT Id FROM UserRole where PortalType ='None'  LIMIT 1];
        User user = new User(Alias='buyer', Email='Portal@example.com', LastName='Portal1', userRoleId = role.Id,
                             TimeZoneSidKey='GMT',  LocaleSidKey='en_US',  Username='portaluser1@example.com',
                             EmailEncodingKey='UTF-8', ProfileId=profile.Id, LanguageLocaleKey='en_US' );
        insert user; 
        return user;
    }
    @isTest
    public static void updateWarehouse() {
        try{
            account ac = [select id from account limit 1];
            Test.startTest();
            NATT_B2BGetInfo.updateBuyerGroup(ac.id, 'MEX');
            Test.stopTest();
        }catch (Exception e) {
            system.debug(e);
        }
    }
    public static void cartUpdate() {
        try{
            account ac = [select id from account limit 1];
            Test.startTest();
            NATT_B2BGetInfo.updateWebCart(ac.id, 'MEX');
            Test.stopTest();
        }catch (Exception e) {
            system.debug(e);
        }
    }
    
    @isTest
    public static void getWarehousefromCart() {
        try{
            Test.startTest();
            NATT_B2BGetInfo.getCartWarehouse('001E23456','001E23456');
            Test.stopTest();
            
        } catch (Exception e) {
            system.debug(e);
        } 
    }
     @isTest
    public static void updateBuyerGroup() {
        try{
            Test.startTest();
            string accID = '01Aabc000DEF';
            NATT_B2BGetInfo.updateBuyerGroup(accID, 'PAN');
            Test.stopTest();
            
        } catch (Exception e) {
            system.debug(e);
        } 
    }
     

   
}