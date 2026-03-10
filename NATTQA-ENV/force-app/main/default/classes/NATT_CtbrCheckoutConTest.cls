@isTest
private  class NATT_CtbrCheckoutConTest {
    @IsTest(SeeAllData=true) 
    static void test1(){
        
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
        
        WebCart cart = new WebCart(Name='Cart', WebStoreId=webStore.Id, AccountId=a.Id);
        insert cart;
        
        CartDeliveryGroup cartDeliveryGroup = new CartDeliveryGroup(CartId=cart.Id, Name='Default Delivery');
        insert cartDeliveryGroup;
        
        // The cpas are related to the account (and through it to the contact)
        ContactPointAddress cpa1 = new ContactPointAddress(Name='CPA1', Street='Street1', City='city1', State='GA',
                                                           Country='US', PostalCode='12345', IsDefault=true, AddressType='Billing', ParentId=a.Id, Status__c='Approved');
        ContactPointAddress cpa2 = new ContactPointAddress(Name='CPA2', Street='Street2', City='city2', State='GA',
                                                           Country='US', PostalCode='12345', IsDefault=false, AddressType='Billing', ParentId=a.Id, Status__c='Approved');
        
        // This contact point address should not show up because it's set to AddressType Shipping
        ContactPointAddress cpaShipping = new ContactPointAddress(Name='CPAS', Street='StreetS', City='cityS',State='GA',
                                                                  Country='US', PostalCode='12345', IsDefault=false, AddressType='Shipping', ParentId=a.Id, Status__c='Approved');
        
        insert cpa1;
        insert cpa2;
        insert cpaShipping;
        
        Test.startTest();
        createUser(contact.Id);
        Test.stopTest();
        
        User user = [SELECT Id FROM User WHERE Email='buyer@example.com'];
        
        BuyerGroup bg = new BuyerGroup(Name='TestBg');
        insert bg;
        
        
        Product2 testProduct = new Product2(
        	Name = 'Test Product 1',
            IsActive = true       
        );
        insert testProduct;

        Id standardPbId = Test.getStandardPricebookId();

        PricebookEntry testPricebookEntry = new PricebookEntry (
            Pricebook2Id = standardPbId,    
            Product2Id = testProduct.Id,
            UnitPrice = 1000,
            IsActive = true
        );
        insert testPricebookEntry;

        Pricebook2 customPricebook = new Pricebook2 (
            Name = '1',
            isActive = true
        );
        insert customPricebook;

        BuyerGroupPricebook testBuyerGroupPricebook = new BuyerGroupPriceBook (
            BuyerGroupId = bg.Id,
            Pricebook2Id = customPricebook.Id
        );
        insert testBuyerGroupPricebook;

        PricebookEntry customPricebookEntry = new PricebookEntry(
            Pricebook2Id = customPricebook.Id,
            Product2Id = testProduct.Id,
            UnitPrice = 1000,
            isActive = true
        );
        insert customPricebookEntry;
        
        
        BuyerGroupMember bgm = new BuyerGroupMember(BuyerGroupId=bg.Id,BuyerId=a.Id);
        insert bgm;
        
        WebStoreBuyerGroup wsbg = new WebStoreBuyerGroup(WebStoreId=webStore.Id,BuyerGroupId=bg.Id);
        insert wsbg;
        
        
        
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
        
        System.runAs(user){ 
            List<CartItem> ciList = new List<CartItem>();
            for(Integer x = 0; x < 103; x++){
                CartItem ci = new CartItem(
                    CartId=cart.Id, 
                    Sku='SKU_Test1'+x, 
                    Quantity=1.0, 
                    Product2Id=testProduct.Id,
                    Type='Product', 
                    Name='TestProduct' + x, 
                    CartDeliveryGroupId=cartDeliveryGroup.Id
                );
                ciList.add(ci);
            }
            insert ciList;            
            
            NATT_B2bDelivery.SyncDeliveryActionRequest ar = new NATT_B2bDelivery.SyncDeliveryActionRequest();
            ar.cartId=cart.Id;
            ar.orderType='1';
            NATT_B2bDelivery.syncDelivery(new List<NATT_B2bDelivery.SyncDeliveryActionRequest>{ar});
            
            
            List<CartDeliveryGroupMethod> cdgmList = NATT_PpgCheckoutCon.getAvailableDeliveryGroupMethods(cart.Id,111);
            System.assert(cdgmList.size()>0);
            
            
            ciList = new List<CartItem>([SELECT Id FROM CartItem WHERE CartId=:cart.Id]);
            System.debug('Cart Item Count: ' + ciList.size());
            
            
            
            //CartDeliveryGroupMethod dm = [SELECT Id FROM CartDeliveryGroupMethod limit 1];
            
            NATT_CtbrCheckoutCon.createRushFeeCartItem(cart.Id, cdgmList.get(0).Id, 100.00);
            
            
        }
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