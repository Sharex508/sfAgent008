//Test coverage for the NATT_AccountInformationCartPageHandler class

@isTest
private class Natt_AccountInformationCartPageHandTest {

    @IsTest(SeeAllData=true)    
    private static void getCartListTest(){
        String communityId = [SELECT Id, Name FROM Network WHERE Name='Performance Parts'].Id;
        String webStoreId = B2BUtils.resolveCommunityIdToWebstoreId(CommunityId);
        System.debug('WebStore Id CCheck: ' + webStoreId);
        Account testAccount = new Account(
            Name='Test',
            RecordTypeId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('Dealer').getRecordTypeId()
            );
        insert testAccount;
        Contact testContact = new Contact(
            AccountId=testAccount.Id,
            FirstName='Test',
            LastName='User',
            NATT_Key_Business_Role__c='Principal',
            RecordTypeId = Schema.SObjectType.Contact.getRecordTypeInfosByDeveloperName().get('NATT_Dealer').getRecordTypeId()
            );
        insert testContact;
        
        Test.startTest();
        createUser(testContact.Id);
        Test.stopTest();

        User newUser = [SELECT Id FROM User WHERE Email='buyer@example.com'];
        
        WebCart testCart = new WebCart(
            AccountId = testAccount.Id,
            WebStoreId = webStoreId,
            Status = 'Active',
            Name = 'Test Cart',
            OwnerId = newUser.Id
        );

        insert testCart;
        WebCart testCart2 = new WebCart(
            AccountId = testAccount.Id,
            WebStoreId = webStoreId,
            Status = 'PendingDelete',
            Name = 'Test Cart 02',
            OwnerId = newUser.Id
        );
        insert testCart2;
        List<WebCart> webCartList = new List <WebCart>();
        String newUserId = newUser.Id;
        
        webCartList = Natt_AccountInformationCartPageHandler.getCartList(newUserId,communityId,testAccount.Id);
        System.debug('Cart List Value: ' + webCartList);
        

        Boolean containsActive = false;
        Boolean containsDelete = false;

        for(WebCart cart : webCartList){
            if(cart.id == testCart.Id){
                containsActive = true;
            }
            if(cart.id == testCart2.Id){
                containsDelete = true;
            }
        }

        System.assertEquals(true, containsActive, 'We expect getCartList to grab the Active Cart.');
        System.assertEquals(false, containsDelete, 'The getCartList should not return any carts that are not Active.');
    }

    @IsTest(SeeAllData=true)  
    private static void renameCartsTest(){
        String communityId = [SELECT Id, Name FROM Network WHERE Name='Performance Parts'].Id;
        String webStoreId = B2BUtils.resolveCommunityIdToWebstoreId(CommunityId);

        Account testAccount = new Account(
            Name='Test',
            RecordTypeId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('Dealer').getRecordTypeId()
            );
        insert testAccount;
        BuyerAccount buyerAccount = new BuyerAccount();
        buyerAccount.BuyerId = testAccount.Id;
        buyerAccount.Name = 'Test Buyer Account (BA-AJ)';
        buyerAccount.IsActive = true;
        insert buyerAccount;
        Contact testContact = new Contact(
            AccountId=testAccount.Id,
            FirstName='Test',
            LastName='User',
            NATT_Key_Business_Role__c='Principal',
            RecordTypeId = Schema.SObjectType.Contact.getRecordTypeInfosByDeveloperName().get('NATT_Dealer').getRecordTypeId()
            );
        insert testContact;

        Test.startTest();
        createUser(testContact.Id);
        Test.stopTest();

        User newUser = [SELECT Id FROM User WHERE Email='buyer@example.com'];
        
        WebStore performanceParts = [SELECT Id, Name FROM WebStore WHERE Name = 'Performance Parts'];
        WebCart testCart2 = new WebCart(
            AccountId = testAccount.Id,
            WebStoreId = webStoreId,
            Status = 'PendingDelete',
            Name = 'Test2',
            OwnerId = newUser.Id
        );
        insert testCart2;
        List<WebCart> webCartList = new List <WebCart>();
        
        webCartList = Natt_AccountInformationCartPageHandler.renameCarts(testCart2.Id, newUser.Id, 'Renamed Cart', testAccount.Id);
        
        WebCart updatedCart = [SELECT Name FROM WebCart WHERE AccountId = :testAccount.Id];
        System.assertEquals('Renamed Cart', updatedCart.Name, 'We expect the WebCarts name to get updated.');

    } 

    @IsTest(SeeAllData=true)
    public static void makePrimaryTest(){
        String communityId = [SELECT Id, Name FROM Network WHERE Name='Performance Parts'].Id;
        String webStoreId = B2BUtils.resolveCommunityIdToWebstoreId(CommunityId);
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

        Test.startTest();
        createUser(contact.Id);
        Test.stopTest();

        User user = [SELECT Id FROM User WHERE Email='buyer@example.com'];
        WebCart secondaryCart;
        System.runAs(user){
            WebCart cart = new WebCart(Name='Cart', WebStoreId=webStore.Id, AccountId=a.Id,Status='Active',isSecondary=false, OwnerId = user.Id);
        insert cart;

        secondaryCart = new WebCart(
            AccountId = a.Id,
            WebStoreId = webStore.Id,
            Name = 'Test Cart 02',
            isSecondary = true,
            OwnerId = user.Id
            
        );
        insert secondaryCart;
        }

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
            Natt_AccountInformationCartPageHandler.makePrimary(secondaryCart.Id, user.Id, communityId, a.Id);
        }
        List<WebCart> webcartList = [SELECT Name, isSecondary, NATT_Is_Cart_Primary__c FROM WebCart WHERE Id = :secondaryCart.Id ];
        for(WebCart cart: webcartList){
            System.assertEquals(true, cart.NATT_Is_Cart_Primary__c, 'We expect the Secondary Cart to be the primary cart.');
        }

    }

    @future
    private static void createUser(String cId){
        Profile profile = [SELECT Id FROM Profile WHERE Name='B2B Customer Community User' LIMIT 1];
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

    @IsTest(SeeAllData=true)
    public static void newCartApiTest(){
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

       Test.startTest();
        createUser(contact.Id);
        Test.stopTest();

        User user = [SELECT Id FROM User WHERE Email='buyer@example.com'];
        WebCart secondaryCart;
        System.runAs(user){
            WebCart cart = new WebCart(Name='Cart', WebStoreId=webStore.Id, AccountId=a.Id,Status='Active',isSecondary=false);
        insert cart;

        
         secondaryCart = new WebCart(
            AccountId = a.Id,
            WebStoreId = webStore.Id,
            Name = 'Test Cart 02',
            isSecondary = true
        );
        insert secondaryCart;
        }

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

        
        List <WebCart> newCartList = new List <Webcart>();
       
       System.runAs(user){ 
        newCartList = Natt_AccountInformationCartPageHandler.newCartApi(user.Id, 'NewCart Test01', communityId, a.Id);
       }

       WebCart newCartTest = [SELECT Name FROM WebCart WHERE Name = 'NewCart Test01'];
       System.assertEquals('NewCart Test01', newCartTest.Name, 'We expect a new cart to get created with the name of NewCart Test01.');
    }

    @IsTest(SeeAllData=true)
    public static void deleteCartsTest(){
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
        
        Test.startTest();
        createUser(contact.Id);
        Test.stopTest();

        User user = [SELECT Id FROM User WHERE Email='buyer@example.com'];
        WebCart secondaryCart;
        System.runAs(user){
            WebCart cart = new WebCart(Name='Cart', WebStoreId=webStore.Id, AccountId=a.Id,Status='Active',isSecondary=false);
        insert cart;

        
        secondaryCart = new WebCart(
            AccountId = a.Id,
            WebStoreId = webStore.Id,
            Name = 'Test Cart 02',
            isSecondary = true
        );
        insert secondaryCart;
        }

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
        List <WebCart> newCartList = new List <Webcart>();

        System.runAs(user){ 
            Natt_AccountInformationCartPageHandler.deleteCarts(secondaryCart.Id, user.Id, a.Id);
        }
    }
}