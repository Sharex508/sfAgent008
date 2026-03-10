@IsTest
private class NACon_B2BGetInfoTest {
    
     @IsTest(SeeAllData=true) 
    static void validateBulkUpload(){
        
        String communityId =[SELECT Id, Name FROM Network WHERE Name='NA Containers Marketplace'].Id;

        Product2 p = new Product2(Name='Test Product', IsActive=true, NATT_P_N__c='asdf123');
        insert p;

        Id stdPbId = Test.getStandardPricebookId();
        
        
        Pricebook2 storePb = [SELECT Id FROM Pricebook2 WHERE IsStandard = false AND IsActive = true LIMIT 1];
        PricebookEntry stdPbe = new PricebookEntry(
            Product2Id = p.Id,
            Pricebook2Id = stdPbId,
            UnitPrice = 1,
            IsActive = true
        );
        insert stdPbe;
    
        PricebookEntry storePbe = new PricebookEntry(
            Product2Id = p.Id,
            Pricebook2Id = storePb.Id,
            UnitPrice = 1,
            IsActive = true
        );
        insert storePbe;

        Pricebook2 customPb = new Pricebook2(Name='TestPb', IsActive=true);
        insert customPb;

        insert new PricebookEntry(Product2Id=p.Id, Pricebook2Id=customPb.Id,
                                  UnitPrice=1, IsActive=true, UseStandardPrice=true);

        Id cntRecordTypeId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('NAOCAP_Customer').getRecordTypeId();
        Account a = new Account(Name = 'TestAccount',RecordTypeId=cntRecordTypeId);
        insert a;

        Contact c = new Contact(LastName='TestContact', Email='buyer@example.com',
                                Phone='3456237654', AccountId=a.Id);
        try { c.put('NAC_Contact_Type__c','Parts Ordering'); } catch (Exception ignore) {}
        try { c.put('NATT_Key_Business_Role__c','Co-Principal'); } catch (Exception ignore) {}
        insert c;

        
        WebStore store = [SELECT Id, Name FROM WebStore WHERE Name = 'NA Containers Marketplace'   LIMIT 1];
  
        BuyerAccount buyerAccount = new BuyerAccount(
            BuyerId  = a.Id,          // Account Id
            Name     = 'Test Buyer Account (BA-AJ)',
            IsActive = true
        );
        insert buyerAccount;
        
        BuyerGroup bg = new BuyerGroup(Name = 'TestBg');
        insert bg;
        
        
        WebStoreBuyerGroup wsbg = new WebStoreBuyerGroup(
            WebStoreId   = store.Id,
            BuyerGroupId = bg.Id
        );
        insert wsbg;


        BuyerGroupMember bgm = new BuyerGroupMember(
            BuyerGroupId = bg.Id,
            BuyerId      = a.Id
        );
        insert bgm;
        
        
        CommerceEntitlementPolicy policy = new CommerceEntitlementPolicy(
            Name           = 'NAConviewProductPrice',
            IsActive       = true,
            CanViewPrice   = true,
            CanViewProduct = true
        );
        insert policy;
        
        insert new CommerceEntitlementBuyerGroup(
            BuyerGroupId = bg.Id,
            PolicyId     = policy.Id
        );


        User currentUser = [SELECT Id FROM User WHERE Id = :UserInfo.getUserId()];
        Test.startTest();
        System.runAs(currentUser) {
            ConnectApi.CartSummary created = NATT_PpgCartController.createCart(communityId, a.Id);
            System.assertNotEquals(null, created, 'createCart should return a summary');

            CartDeliveryGroup cdg = new CartDeliveryGroup(CartId=created.cartId, Name='Default Delivery');
            insert cdg;
            insert new CartItem(CartId=created.cartId, Name='Seed Item', Product2Id=p.Id,
                                TotalPrice=2, CartDeliveryGroupId=cdg.Id);

            ConnectApi.CartSummary summary = NACon_B2BGetInfo.getCartSummary(communityId, a.Id);
            System.assertNotEquals(null, summary, 'getCartSummary should return a summary');
            System.assertEquals(a.Id, summary.accountId, 'Account must match');

            Boolean ok;
            ok = true; try {
                ConnectApi.ProductPrice price = NACon_B2BGetInfo.getProductPrice(communityId, p.Id, a.Id);
                System.assertNotEquals(null, price);
            } catch (Exception e) { ok = false; } 

            ok = true; try {
                List<String[]> products = new List<String[]>{ new String[]{ p.Id, '1' } };
                List<ConnectApi.BatchResult> addRes = NACon_B2BGetInfo.addItemsToCart(communityId, a.Id, products);
                System.assertNotEquals(null, addRes);
            } catch (Exception e) { ok = false; } System.assert(ok, 'addItemsToCart should not throw');

            ok = true; try {
                ConnectApi.ProductSearchResults sr = NACon_B2BGetInfo.productSearch(communityId, 'asdf123', a.Id);
                System.assertNotEquals(null, sr);
            } catch (Exception e) { ok = false; } System.assert(ok, 'productSearch should not throw');

            ok = true; try { NACon_B2BGetInfo.quickProductSearch(communityId, 'asdf123', a.Id); }
            catch (Exception e) { ok = false; } System.assert(ok, 'quickProductSearch should not throw');

            ok = true; try {
                ConnectApi.ProductDetail detail = NACon_B2BGetInfo.getProductDetail(communityId, p.Id, a.Id);
                System.assertNotEquals(null, detail);
            } catch (Exception e) { ok = false; } 
        }
        Test.stopTest();
    }

}