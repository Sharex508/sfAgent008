@isTest
public class CtmBuyerGroupMemberUpdateTest {
    
    @testSetup
    static void setupTestData() {
        // Create BuyerGroups
        List<BuyerGroup> buyerGroups = new List<BuyerGroup>();
        buyerGroups.add(new BuyerGroup(Name = 'CTM MEX Parts Buyer Group'));
        buyerGroups.add(new BuyerGroup(Name = 'CTM PAN Parts Buyer Group'));
        buyerGroups.add(new BuyerGroup(Name = 'CTM MIA Parts Buyer Group'));
        buyerGroups.add(new BuyerGroup(Name = 'CTM LATM Parts Buyer Group'));
        insert buyerGroups;
        
        // Create Accounts
        Account acc = new Account(Name='Panama Acc',NATT_Organization__c = 'NATT',NATT_Region__c = 'East');
        insert acc;
        
        // Create existing BuyerGroupMember (to be deleted by method)
        BuyerGroupMember bgm = new BuyerGroupMember(
            BuyerId = acc.Id, 
            BuyerGroupId = buyerGroups[0].Id
        );
        //insert bgm;
    }
    
    @isTest
    static void testUpdateBuyerGroup_MEX() {
        try{
            Account acc = [SELECT Id FROM Account WHERE Name = 'Panama Acc' LIMIT 1];
            Test.startTest();
            CtmBuyerGroupMemberUpdate.updateBuyerGroup(acc.Id, 'MEX');
            Test.stopTest();
            
            List<BuyerGroupMember> existingBGM = [SELECT Id FROM BuyerGroupMember WHERE BuyerId = :acc.Id];
            System.assertEquals(1, existingBGM.size(), 'Expected one BuyerGroupMember to be created.');
        } catch (Exception e) {
            system.debug(e);
        } }
    
    @isTest
    static void testUpdateBuyerGroup_PAN() {
        try{
            Account acc = [SELECT Id FROM Account WHERE Name = 'Panama Acc' LIMIT 1];
            
            Test.startTest();
            CtmBuyerGroupMemberUpdate.updateBuyerGroup(acc.Id, 'PAN');
            Test.stopTest();
            
        } catch (Exception e) {
            system.debug(e);
        } 
    }
    
    @isTest
    static void testUpdateBuyerGroup_ExceptionHandling() {
        // Pass invalid Account ID to test exception handling
        try {
            Test.startTest();
            CtmBuyerGroupMemberUpdate.updateBuyerGroup(null, 'MIA');
            Test.stopTest();
        } catch (Exception e) {
            system.debug(e);
        }
    }
     @isTest
    static void getBuyerGroupMember() {
        account acc= new account();
        acc= [select id from account limit 1];
          BuyerGroupMember bgm = new BuyerGroupMember();
                map<string, string> cartWarehouseBuyergroupMap = new map<string,string>();
                cartWarehouseBuyergroupMap.put('CTM PAN Parts Buyer Group','PAN');
                cartWarehouseBuyergroupMap.put('CTM MIA Parts Buyer Group','MIA');
                cartWarehouseBuyergroupMap.put('CTM LATM Parts Buyer Group','LATAM');
        try {
            Test.startTest();
            CtmBuyerGroupMemberUpdate.getBuyerGroupMember(acc.id, cartWarehouseBuyergroupMap);
            Test.stopTest();
        } catch (Exception e) {
            system.debug(e);
        }
    }
    
    @isTest
    static void getClearCart(){
       
          Account account = [SELECT Id FROM Account WHERE Name = 'Panama Acc' LIMIT 1];
       
        WebStore testWebStore = new WebStore(Name='TestWebStore', DefaultLanguage='en_US');
        insert testWebStore;
        
        WebStore webStore = [SELECT Id FROM WebStore WHERE Name='TestWebStore' LIMIT 1];
        WebCart cart = new WebCart(Name='Cart', WebStoreId=webStore.Id, AccountId=account.Id);
        insert cart;
        
        CtmBuyerGroupMemberUpdate.clearCart(cart.Id);
    }
     
}