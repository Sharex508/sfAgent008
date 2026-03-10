@isTest
private class NATT_PriceAvailabilityControllerAPI_Test {

    @isTest(SeeAllData=true)
    private static void getSolutionCenterURL_Test(){
        String testURL = '';
        Boolean valueCheck = false;
        Test.startTest();
        testURL = NATT_PriceAvailabilityController.getSolutionCenterURL();
        Test.stopTest();
        if(testURL != null && testURL.indexOf('carriersolutioncenter') != -1){
            valueCheck = true;
        }
        System.assertEquals(true, valueCheck, 'We expect the getSolutionCenterURL method to return the Carrier SolutionCenter\'s URL.');
    }

    @isTest(SeeAllData=true)
    private static void getCartSummary_Test(){
        String communityId = [SELECT Id, Name FROM Network WHERE Name='Performance Parts'].Id;
        String webStoreId = B2BUtils.resolveCommunityIdToWebstoreId(CommunityId);
        System.debug('WebStoreId test" ' + webStoreId);
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
        
            BuyerGroup bg = new BuyerGroup(Name='TestBg');
            insert bg;
    
            BuyerGroupMember bgm = new BuyerGroupMember(BuyerGroupId=bg.Id,BuyerId=testAccount.Id);
            insert bgm;
    
            WebStoreBuyerGroup wsbg = new WebStoreBuyerGroup(WebStoreId=webStoreId,BuyerGroupId=bg.Id);
            insert wsbg;
        
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
        
        System.runAs(newUser){
            WebCart testCart = new WebCart(
            AccountId = testAccount.Id,
            WebStoreId = webStoreId,
            Status = 'Active',
            Name = 'Test Cart',
            OwnerId = newUser.Id,
            isSecondary = false);

            insert testCart;
            
            
    
    
            //ConnectApi.Community solutionCenter = ConnectApi.Communities.getCommunity(solutionId.Id);
            
            List<WebCart> cartList = [SELECT Id, WebStoreId FROM WebCart WHERE AccountId = :testAccount.Id ];
            System.debug('WEBCARTS: ' + cartList);
            ConnectApi.CartSummary testCartSummary = NATT_B2BGetInfo.getCartSummary(communityId, testAccount.Id);
            System.debug('testCartSummary: ' + testCartSummary);
        }
            
    }

    @isTest(SeeAllData=true)
    private static void addItemsToCart_Test(){
        /**
         * addItemsToCart(
                String communityId,
                String effectiveAccountId,
                List<String[]> products
            )
         */

        Network solutionId = [SELECT ID FROM Network WHERE Name = 'Performance Parts'];
        ConnectApi.Community solutionCenter = ConnectApi.Communities.getCommunity(solutionId.Id);       
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