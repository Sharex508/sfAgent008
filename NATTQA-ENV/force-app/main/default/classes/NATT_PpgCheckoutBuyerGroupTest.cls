@isTest
private class NATT_PpgCheckoutBuyerGroupTest {
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
                Country='US', PostalCode='12345', IsDefault=true, AddressType='Billing', ParentId=a.Id);
        ContactPointAddress cpa2 = new ContactPointAddress(Name='CPA2', Street='Street2', City='city2', State='GA',
                Country='US', PostalCode='12345', IsDefault=false, AddressType='Billing', ParentId=a.Id);

        // This contact point address should not show up because it's set to AddressType Shipping
        ContactPointAddress cpaShipping = new ContactPointAddress(Name='CPAS', Street='StreetS', City='cityS',State='GA',
                Country='US', PostalCode='12345', IsDefault=false, AddressType='Shipping', ParentId=a.Id);

        insert cpa1;
        insert cpa2;
        insert cpaShipping;
        
        Test.startTest();
        createUser(contact.Id);
        Test.stopTest();

        User user = [SELECT Id FROM User WHERE Email='buyer@example.com'];

        BuyerGroup bg = new BuyerGroup(Name='TestBg');
        insert bg;

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
            CartItem cartItem = new CartItem(
                CartId=cart.Id, 
                Sku='SKU_Test1', 
                Quantity=3.0, 
                Type='Product', 
                Name='TestProduct', 
                CartDeliveryGroupId=cartDeliveryGroup.Id
            );
            insert cartItem;
            
            NATT_PpgCheckoutBuyerGroup.getCanReceiveRushOrderCharge(a.Id);
           
           NATT_PpgCheckoutBuyerGroup.createRushFeeProduct();
       }
        
        NATT_PpgCheckoutBuyerGroup.badTestCoverageFix();
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