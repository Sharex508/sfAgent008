@isTest
private class NATT_TesCartPageHandlerTest {
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
       ID newCartId = null;
       System.runAs(user){ 
        newCartId = NATT_TesCartPageHandler.newCartApi(user.Id, 'NewCart Test01', communityId);
       }
       System.debug('ID VALUE" ' + newCartId);
       WebCart newCartTest = [SELECT Name FROM WebCart WHERE Name = 'NewCart Test01'];
       System.assertEquals('NewCart Test01', newCartTest.Name, 'We expect a new cart to get created with the name of NewCart Test01.');
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