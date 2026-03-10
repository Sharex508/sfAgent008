@IsTest
private class NATT_PpgCartControllerTest {
    @IsTest(SeeAllData=true) static void myUnitTest(){
        Account a = new Account(Name='TestAccount');
        insert a;
        Contact contact = new Contact(LastName='TestContact', AccountId=a.Id);
        insert contact;
        
        BuyerAccount buyerAccount = new BuyerAccount();
        buyerAccount.BuyerId = a.Id;
        buyerAccount.Name = 'Test Buyer Account (BA-AJ)';
        buyerAccount.IsActive = true;
        insert buyerAccount;
                
        Test.startTest();
        createUser(contact.Id);
        Test.stopTest();

        User user = [SELECT Id FROM User WHERE Email='buyer@example.com'];
        
        BuyerGroup bg = new BuyerGroup(Name='TestBg');
        insert bg;

        BuyerGroupMember bgm = new BuyerGroupMember(BuyerGroupId=bg.Id,BuyerId=a.Id);
        insert bgm;

        String communityId =[SELECT Id, Name FROM Network WHERE Name='Performance Parts'].Id;
        String webstoreId = [SELECT Id,Name FROM WebStore WHERE Name='Performance Parts'].Id;

        WebStoreBuyerGroup wsbg = new WebStoreBuyerGroup(WebStoreId=webstoreId,BuyerGroupId=bg.Id);
        insert wsbg;
        Product2 p = new Product2(Name='Test',IsActive=true);
        insert p;

        Pricebook2 pb = new Pricebook2(Name='TestPb',IsActive=true);
        insert pb;

        PricebookEntry spbe = new PricebookEntry(Product2Id=p.Id,Pricebook2Id=Test.getStandardPricebookId(),UnitPrice=1);
        insert spbe;

        PricebookEntry pbe = new PricebookEntry(Product2Id=p.Id,Pricebook2Id=pb.Id,UnitPrice=1);
        insert pbe;
        System.runAs(user){ 
            ConnectApi.CartSummary summary = NATT_PpgCartController.createCart(communityId,a.Id);
            CartDeliveryGroup cartDeliveryGroup = new CartDeliveryGroup(CartId=summary.cartId, Name='Default Delivery');
            insert cartDeliveryGroup;
            CartItem ci = new CartItem(CartId=summary.cartId,Name='Test',Product2Id=p.Id,TotalPrice=2,CartDeliveryGroupId=cartDeliveryGroup.Id);
            insert ci;
            List<ConnectApi.CartItemInput> ciInputList = new List<ConnectApi.CartItemInput>();
            ConnectApi.CartItemInput ciInput = new ConnectApi.CartItemInput();
            ciInput.quantity='2.00';
            ciInputList.add(ciInput);
            
            NATT_PpgCartController.getCartSummary(communityId,null,summary.cartId);           
            NATT_PpgCartController.getCartItems(communityId, null,summary.cartId, null,null); 
            try{
            	NATT_PpgCartController.updateCartItem(communityId,null,summary.cartId,ci.Id,ciInput);
            }catch(Exception e){
                
            }
            try{
            	NATT_PpgCartController.deleteCartItem(communityId, a.id, summary.cartId, ci.Id);
            }catch(Exception e){
                
            }
            NATT_PpgCartController.deleteCart(communityId,null,summary.cartId);
            NATT_PpgCartController.getCartAvailability(new List<String>{p.Id});
        }
    }

    @future
    private static void createUser(String cId){
        Profile profile = [SELECT Id FROM Profile WHERE Name='B2B Customer Community User' LIMIT 1];
        User user = new User(Alias='buyer', Email='buyer@example.com', LastName='Buyer',
                TimeZoneSidKey='GMT', LocaleSidKey='en_US', Username='buyer@example.com',
                EmailEncodingKey='UTF-8', ProfileId=profile.Id, LanguageLocaleKey='en_US',
                ContactId=cId);
        insert user;
        
        PermissionSet ps = [SELECT Id FROM PermissionSet WHERE Name='B2B_Commerce_User'];
        PermissionSetAssignment psa = new PermissionSetAssignment(PermissionSetId = ps.Id, AssigneeId = user.Id);
        insert psa;  
    }
}