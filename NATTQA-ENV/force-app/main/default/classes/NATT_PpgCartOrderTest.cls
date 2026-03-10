@IsTest
private class NATT_PpgCartOrderTest {
    @IsTest(SeeAllData=true)
    static void myUnitTest(){
        NATT_PpgCartOrder.SyncOrderRequest sor = new NATT_PpgCartOrder.SyncOrderRequest();
               
        Product2 p = new Product2(Name='Test',IsActive=true,NATT_P_N__c='asdf123');
        insert p;
        
        Pricebook2 pb = new Pricebook2(Name='TestPb',IsActive=true);
        insert pb;
        
        PricebookEntry spbe = new PricebookEntry(Product2Id=p.Id,Pricebook2Id=Test.getStandardPricebookId(),UnitPrice=1);
        insert spbe;
        
        PricebookEntry pbe = new PricebookEntry(Product2Id=p.Id,Pricebook2Id=pb.Id,UnitPrice=1, UseStandardPrice = true);
        insert pbe;
        // System.runAs(testGuestUser){ 
        String communityId =[SELECT Id, Name FROM Network WHERE Name='Performance Parts'].Id;
        Account a = new Account(Name='TestAccount');
        insert a;
        Contact contact = new Contact(LastName='TestContact', AccountId=a.Id);
        insert contact;
        
        BuyerAccount buyerAccount = new BuyerAccount();
        buyerAccount.BuyerId = a.Id;
        buyerAccount.Name = 'Test Buyer Account (BA-AJ)';
        buyerAccount.IsActive = true;
        insert buyerAccount;
        
        WebStore webStore = [SELECT Id FROM WebStore WHERE Name='Performance Parts'];
        
        BuyerGroup bg = [SELECT ID FROM BuyerGroup WHERE Name = 'T1'];
        // insert bg;
        
        BuyerGroupMember bgm = new BuyerGroupMember(BuyerGroupId=bg.Id,BuyerId=a.Id);
        insert bgm;
        
        
        
        Test.startTest();
        createUser(contact.Id);
        Test.stopTest();
        
        User user = [SELECT Id FROM User WHERE Email='buyer@example.com'];
        
        WebCart cart;
        Order o;
        CartDeliveryGroup cartDeliveryGroup;
        System.runAs(user){
            cart = new WebCart(Name='Cart', WebStoreId=webStore.Id, AccountId=a.Id,Status='Active',isSecondary=false);
            insert cart;
            
            cartDeliveryGroup = new CartDeliveryGroup(CartId=cart.Id, Name='Default Delivery');
            insert cartDeliveryGroup;
            
            CartItem ci = new CartItem(Name='Test',CartId=cart.Id,Product2Id=p.Id,Quantity=1,ListPrice=1,CartDeliveryGroupId=cartDeliveryGroup.Id);
            insert ci;
            
            o = new Order(AccountId=a.Id,EffectiveDate=Date.today(),Status='Draft');
            insert o;
            
            OrderItem oi = new OrderItem(OrderId=o.Id,Quantity=2,Product2Id=p.Id,UnitPrice=1);
            insert oi;
        }
        
        
        
        sor.cartId=cart.Id;
        sor.orderId=o.Id;
        
        NATT_PpgCartOrder.syncOrderLines(new List<NATT_PpgCartOrder.SyncOrderRequest>{sor});
    }
    
    @future
    private static void createUser(String cId){        
        Profile profile = [SELECT Id FROM Profile WHERE Name='NATT Full Access Community' LIMIT 1];
        User user = new User(Alias='buyer', Email='buyer@example.com', LastName='Buyer',
                             TimeZoneSidKey='GMT', LocaleSidKey='en_US', Username='buyer@example.com.carrier',
                             EmailEncodingKey='UTF-8', ProfileId=profile.Id, LanguageLocaleKey='en_US',
                             ContactId=cId);
        insert user;
        List<PermissionSetAssignment> psaList = new List<PermissionSetAssignment>();
        for(PermissionSet ps : [SELECT Id FROM PermissionSet WHERE Name IN ('B2B_Commerce_Buyer','B2BBuyer')]){
            psaList.add(new PermissionSetAssignment(PermissionSetId = ps.Id, AssigneeId = user.Id));
        }
        insert psaList; 
    }
}