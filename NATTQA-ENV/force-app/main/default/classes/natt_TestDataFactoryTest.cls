@isTest
private class natt_TestDataFactoryTest {
    @isTest
    static void testCreateUser() {
            User thisUser = new User(Id = UserInfo.getUserId());
            Id accRecordTypeId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('Dealer').getRecordTypeId();
            Account testAccount =natt_TestDataFactory.createAccount('PPG Product Development',accRecordTypeId);
            insert testAccount;
            
            Id cntRecordTypeId = Schema.SObjectType.Contact.getRecordTypeInfosByDeveloperName().get('NATT_Dealer').getRecordTypeId();
            Contact testContact = natt_TestDataFactory.createContact(testAccount.Id, 'bCnt1', cntRecordTypeId);
            insert testContact;
            
            User testUser = natt_TestDataFactory.createUser('BackOrderUser1','NATT PPG B2B Admin','bUser1');
            insert testUser;
            
            Id ordRecordTypeId = Schema.SObjectType.Order.getRecordTypeInfosByName().get('NATT Parts Order').getRecordTypeId();
            Order testOrder = natt_TestDataFactory.createOrder(testAccount.Id, ordRecordTypeId);
            insert testOrder;
            
            Product2 testProduct = natt_TestDataFactory.createProduct('Result Product Test01','3450297784' );
            insert testProduct;
            
            OrderItem newItem = natt_TestDataFactory.createOrderItem(testOrder.Id,testProduct.Id, 5 );
            insert newItem;
        	natt_TestDataFactory.createRole();
        }
    }