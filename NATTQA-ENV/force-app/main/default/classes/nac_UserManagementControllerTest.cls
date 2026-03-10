@IsTest
public class nac_UserManagementControllerTest {
    static string communityId = [SELECT Id, Name FROM Network WHERE Name =:NAC_Global_Constants.DEFAULT_COMMUNITY_NAME_NAC].Id;
    
    @isTest(SeeAllData=true)
    static void fetchDataTest(){
        Account acc = NAC_TestDataFactory.insertAccount();
        
        Contact con=NAC_TestDataFactory.insertAssociatedContact(acc);
        con.NAC_Status__c='Approved';
        con.NAC_Contact_Type__c='Parts Ordering';
        Update con;
        
        String effectiveAccountId=acc.id;
        BuyerAccount buyerAccount=NAC_TestDataFactory.insertBuyerAccount(acc);
        
        BuyerGroup bg = NAC_TestDataFactory.insertBuyerGroup();
        BuyerGroupMember bgm = NAC_TestDataFactory.insertBuyerGroupMember(acc,bg);
        
        WebStore webstore = [SELECT id FROM WebStore WHERE Name =:NAC_Global_Constants.DEFAULT_COMMUNITY_NAME_NAC LIMIT 1];
        NAC_B2BUtils.communityIdToWebStoreIdCache.put(communityId,webstore.id);
        
        WebStoreBuyerGroup wsbg = NAC_TestDataFactory.insertWebStoreBuyerGroup(webstore,bg);
        
        nac_UserManagementController.sObjectWrapper sOw=nac_UserManagementController.fetchData('NAOCAP_Contact_List_View','NAOCAP_Contact_List_View_Sortable_Fields','Contact',effectiveAccountId);
        nac_UserManagementController.sObjectWrapper eOw=nac_UserManagementController.fetchData('NAOCAP_Contact_List_View','NAOCAP_Contact_List_View_Sortable_Fields','Xyz',effectiveAccountId);
        
        
        System.assertNotEquals(sOw,null,'Get fields Data failed');
        System.assertNotEquals(eOw,null,'Get fields Data failed');
    }
    @isTest(SeeAllData=true)
    static void TestMethod1(){
        Account acc = NAC_TestDataFactory.insertAccount();
        
        Contact con=NAC_TestDataFactory.insertAssociatedContact(acc);
        con.NAC_Status__c='Approved';
        con.NAC_Contact_Type__c='Parts Ordering';
        Update con;
        
        String effectiveAccountId=acc.id;
        BuyerAccount buyerAccount=NAC_TestDataFactory.insertBuyerAccount(acc);
        
        BuyerGroup bg = NAC_TestDataFactory.insertBuyerGroup();
        BuyerGroupMember bgm = NAC_TestDataFactory.insertBuyerGroupMember(acc,bg);
        
        WebStore webstore = [SELECT id FROM WebStore WHERE Name =:NAC_Global_Constants.DEFAULT_COMMUNITY_NAME_NAC LIMIT 1];
        NAC_B2BUtils.communityIdToWebStoreIdCache.put(communityId,webstore.id);
        
        WebStoreBuyerGroup wsbg = NAC_TestDataFactory.insertWebStoreBuyerGroup(webstore,bg);
        List<ID> records=new List<Id>();
        nac_UserManagementController nUs=new nac_UserManagementController(records);
        nac_UserManagementController.getContactRt();
        USer us=NAC_TestDataFactory.runAsNACUser();
        System.runAs(us){
            Test.startTest();
            nac_UserManagementController.checkPartContactType();
            nac_UserManagementController.deactivateContactRecord(con.Id);
            Test.stopTest();
        }
    }
    @isTest(SeeAllData=true)
    static void TestMethod2(){
        Account acc = NAC_TestDataFactory.insertAccount();
        
        Contact con=NAC_TestDataFactory.insertAssociatedContact(acc);
        con.NAC_Status__c='Approved';
        con.NAC_Contact_Type__c='Parts Ordering';
        Update con;
        
        String effectiveAccountId=acc.id;
        BuyerAccount buyerAccount=NAC_TestDataFactory.insertBuyerAccount(acc);
        
        BuyerGroup bg = NAC_TestDataFactory.insertBuyerGroup();
        BuyerGroupMember bgm = NAC_TestDataFactory.insertBuyerGroupMember(acc,bg);
        
        WebStore webstore = [SELECT id FROM WebStore WHERE Name =:NAC_Global_Constants.DEFAULT_COMMUNITY_NAME_NAC LIMIT 1];
        NAC_B2BUtils.communityIdToWebStoreIdCache.put(communityId,webstore.id);
        
        WebStoreBuyerGroup wsbg = NAC_TestDataFactory.insertWebStoreBuyerGroup(webstore,bg);
        Map<String,String> contactRecord =new Map<String,String>(); 
        contactRecord.put('FirstName', 'Test');
        contactRecord.put('LastName', 'Test-12');
        contactRecord.put('Email','Test@gmail.com');
        contactRecord.put('Title','TestTitle');
        contactRecord.put('Phone','9087777777');
        User communityUser = NAC_TestDataFactory.runAsNACUser();
        try{
            Boolean bool=nac_UserManagementController.updateContactRecord(contactRecord,communityUser.ContactId);
        }
        catch(Exception e){
        }
    }
}