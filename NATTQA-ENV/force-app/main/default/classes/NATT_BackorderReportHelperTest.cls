@isTest
public with sharing class NATT_BackorderReportHelperTest {
    
    @testSetup 
    public static void testSetup(){
        User thisUser = new User(Id = UserInfo.getUserId());
        Id accRecordTypeId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('Dealer').getRecordTypeId();
        Account testAccount =natt_TestDataFactory.createAccount('PPG Product Development',accRecordTypeId);
        insert testAccount;
        
        Id cntRecordTypeId = Schema.SObjectType.Contact.getRecordTypeInfosByDeveloperName().get('NATT_Dealer').getRecordTypeId();
        Contact testContact = natt_TestDataFactory.createContact(testAccount.Id, 'bCnt1', cntRecordTypeId);
        insert testContact; 
         
        User testUser = natt_TestDataFactory.createUser('BackOrderUser1','NATT PPG B2B Admin','bUser1');
        insert testUser;
        
        System.runAs(testUser) {
            Id ordRecordTypeId = Schema.SObjectType.Order.getRecordTypeInfosByName().get('NATT Parts Order').getRecordTypeId();
            Order testOrder = natt_TestDataFactory.createOrder(testAccount.Id, ordRecordTypeId);
        insert testOrder;
        
            Product2 testProduct = natt_TestDataFactory.createProduct('Result Product Test01','3450297784' );
        insert testProduct;
        
            OrderItem newItem = natt_TestDataFactory.createOrderItem(testOrder.Id,testProduct.Id, 5 );
            newItem.NATT_Shipped_Quantity__c = 5;
        insert newItem;
            OrderItem newItem1 = natt_TestDataFactory.createOrderItem(testOrder.Id,testProduct.Id, 5 );
            newItem1.NATT_Available_Promise_Date__c = Date.Today().addDays(50);
        insert newItem1;
        
        }
    }
    @Istest
    public static void getOrderList(){
        List<Map<String, Object>> orderItemList = NATT_BackorderReportHelper.getOrderList();
    }
    @Istest
    public static void getResults(){
        
        List<Map<String, Object>> orderItemList = NATT_BackorderReportHelper.getResults(null, null, null, null, null);
    }
    @Istest
    public static void getResultsError(){
        try{
            OrderItem ordItem= [select id, Order_Number__c, Purchase_Order_Number__c, Part_Number__c from OrderItem limit 1];
        List<Map<String, Object>> orderItemList = NATT_BackorderReportHelper.getResults(ordItem.Order_Number__c, ordItem.Purchase_Order_Number__c , ordItem.Part_Number__c, date.today(), date.today());
        }
        catch(exception e){
            system.debug('Error- '+e.getLineNumber() + e);
        }
    }
    
    @Istest
    public static void getTopOrderedItems(){
        try{
             User testUser = [select id, name from user where profile.name = 'NATT PPG B2B Admin' limit 1];
            NATT_BackorderReportHelper.getTopOrderedItems(testUser.Id);
        }
        catch(exception e){
            system.debug('Error- '+e.getLineNumber() + e);
        }
    }
      @Istest
    public static void getWebstore(){
        try{
           // string webStoreID = [SELECT id, name ,WebStoreId FROM WebStoreNetwork limit 1].WebStoreId;
            NATT_BackorderReportHelper.getWebstore('1234');
        }
        catch(exception e){
            system.debug('Error- '+e.getLineNumber() + e);
        }
    }
    
    @isTest
    private static void testTopBackorderWrapperCompareTo() {
        NATT_BackorderReportHelper.TopBackorderWrapper wrapper1 = new NATT_BackorderReportHelper.TopBackorderWrapper();
        wrapper1.Id = '001';
        wrapper1.partNumber = 'ABC123';
        wrapper1.quantity = 10;

        NATT_BackorderReportHelper.TopBackorderWrapper wrapper2 = new NATT_BackorderReportHelper.TopBackorderWrapper();
        wrapper2.Id = '002';
        wrapper2.partNumber = 'DEF456';
        wrapper2.quantity = 5;

        System.assertEquals(0, wrapper1.compareTo(wrapper2), 'Wrapper 1 should have higher quantity, so compareTo should return 0');
        System.assertEquals(1, wrapper2.compareTo(wrapper1), 'Wrapper 2 should have lower quantity, so compareTo should return 1');
    }
}