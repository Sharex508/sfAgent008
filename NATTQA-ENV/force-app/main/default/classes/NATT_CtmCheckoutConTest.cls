@isTest
public with sharing class NATT_CtmCheckoutConTest {
    @IsTest(SeeAllData=true) 
    static void test1(){
        Id cpaRecordTypeId = Schema.SObjectType.ContactPointAddress.getRecordTypeInfosByName().get('NATT Parts Address').getRecordTypeId(); //NattRecordType
        Account a = new Account(Name='TestAccount',NATT_Organization__c = 'NATT',NATT_Region__c = 'East');
        insert a;
        Contact contact = new Contact(LastName='TestContact', AccountId=a.Id);
        insert contact;
        user thisUser = new User(Id = UserInfo.getUserId());
        user adminUser = new user();
        system.runAs(thisUser){
            adminUser = createAdminUser();
        }
		user commUser = new user();
        Account a1 = new Account();
        system.runAs(adminUser){
              a1 = new Account(Name='TestAccount',NATT_Organization__c = 'NATT',NATT_Region__c = 'East');
            insert a1;
            Contact contact1 = new Contact(LastName='TestContact', AccountId=a1.Id);
            insert contact1;
            string cntId1 = contact1.Id;
            commUser = createUser(contact1.Id);
        }
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
                                                           Country='US', PostalCode='12345', IsDefault=true, AddressType='Billing', ParentId=a.Id, RecordtypeId = cpaRecordTypeId);
        ContactPointAddress cpa2 = new ContactPointAddress(Name='CPA2', Street='Street2', City='city2', State='GA',
                                                           Country='US', PostalCode='12345', IsDefault=false, AddressType='Billing', ParentId=a.Id);
        
        // This contact point address should not show up because it's set to AddressType Shipping
        ContactPointAddress cpaShipping = new ContactPointAddress(Name='CPAS', Street='StreetS', City='cityS',State='GA',
                                                                  Country='US', PostalCode='12345', IsDefault=false, AddressType='Shipping', ParentId=a.Id);
        
        insert cpa1;
        insert cpa2;
        insert cpaShipping;
        
        /*Test.startTest();
        createUser(contact.Id);
        Test.stopTest();
        
        User user = [SELECT Id FROM User WHERE Email='buyer@example.com'];*/
        
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
        
        //System.runAs(user){ 
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
            
            NATT_CtmCheckoutCon.getCartDetail(cart.Id);

            NATT_CtmCheckoutCon.getAccountRegion(a.Id);
            
            NATT_CtmCheckoutCon.getAddressList(a.Id,'a');
        try{
            NATT_CtmCheckoutCon.getOrderDeliveryMethod('AF - AIR FREIGHT');
        }
        catch(exception e){
            system.debug(e);
        }

            NATT_CtmCheckoutCon.reallyBadCoverageFix();
        	
        	NATT_CtmCheckoutCon.getUserProfile(userInfo.getUserId());
        
        //}
    }
     
     private static user createUser(String cId){
        Profile profile = [SELECT Id FROM Profile WHERE Name='B2B Customer Community User' LIMIT 1];
        User user = new User(Alias='buyer', Email='buyer@example.com', LastName='Buyer1', ContactId=cId,
                             TimeZoneSidKey='GMT',  LocaleSidKey='en_US',  Username='buyer13@example.com',
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
                             TimeZoneSidKey='GMT',  LocaleSidKey='en_US',  Username='portaluser13@example.com',
                             EmailEncodingKey='UTF-8', ProfileId=profile.Id, LanguageLocaleKey='en_US' );
        insert user; 
        return user;
    }
}