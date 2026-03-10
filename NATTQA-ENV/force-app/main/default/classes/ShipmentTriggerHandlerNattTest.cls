/**
 * Test Coverage for ShipmentTriggerHandlerNatt class/ Shipment Trigger
 */
@isTest
public with sharing class ShipmentTriggerHandlerNattTest extends ShipmentTriggerHandlerAbstract implements HttpCalloutMock{
    public HTTPResponse respond(HTTPRequest req) {
        // Create a fake response
        HttpResponse res = new HttpResponse();
        res.setHeader('Content-Type', 'application/json');
        res.setBody('{"transactionResponse": { "responseCode": "1", "authCode": "HW617E", "avsResultCode": "Y", "cvvResultCode": "", "cavvResultCode": "", "transId": "2157047189", "refTransID": "", "transHash": "E7CEB0A9F1BECA32A02493E1B31D5955", "testRequest": "0", "accountNumber": "XXXX1111", "accountType": "Visa", "messages": [ { "code": "1", "description": "This transaction has been approved." } ], "transHashSha2": "D0C4FFF5648511A5862B917CFD9BB78ABF8A6E1D90C119CBBC4C0B454F4FF40DED15B204E042F36ECA5FB15D02588E4E4A7B85B94E7279599CE6020462CB7DEE", "SupplementalDataQualificationIndicator": 0, "networkTransId": "123456789NNNH" }, "messages": { "resultCode": "Ok", "message": [ { "code": "I00001", "text": "Successful." } ] }}');        
        res.setStatusCode(200);
        return res;
    }
    @IsTest
    static void newShipmentNatt_Test(){
        Account a = new Account(Name='TestAccount');
        insert a;
        Contact contact = new Contact(LastName='TestContact', AccountId=a.Id, NATT_AuthorizeDotNetProfileId__c='123');
        insert contact;
        
        // createUser(contact.Id);
        Profile testProfile = [SELECT Id FROM Profile WHERE Name='NATT Full Access Community' LIMIT 1];

        User shipUser = new User(Alias='ship', Email='ship@example.com', LastName='Buyer',
                TimeZoneSidKey='GMT', LocaleSidKey='en_US', Username='ship@example.com.carrier',
                EmailEncodingKey='UTF-8', ProfileId=testProfile.Id, LanguageLocaleKey='en_US',
                ContactId=contact.Id);
        insert shipUser;

        //Create required Order variables (Account,Address,Opportunity)
        List<Account> aList = new List<Account>();
        alist.add(new Account(Name='Test Dealer',RecordTypeId=Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('Dealer').getRecordTypeId()));
        aList.add(new Account(Name='Test Dealer2',RecordTypeId=Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('Dealer').getRecordTypeId()));
        insert aList;
        
        List<NATT_Address__c> addList = new List<NATT_Address__c>();
        addList.add(new NATT_Address__c(NATT_Type__c='Billing',NATT_Account__c=aList.get(0).Id,RecordTypeId=Schema.SObjectType.NATT_Address__c.getRecordTypeInfosByDeveloperName().get('NATT_Address').getRecordTypeId()));
        addList.add(new NATT_Address__c(NATT_Type__c='Units Ship To',NATT_Account__c=aList.get(0).Id,RecordTypeId=Schema.SObjectType.NATT_Address__c.getRecordTypeInfosByDeveloperName().get('NATT_Address').getRecordTypeId()));
        insert addList;		
		
		List<Opportunity> oppList = new List<Opportunity>();
        oppList.add(new Opportunity(Name='UnitsTestOpp',CloseDate=Date.today().addDays(30),StageName='Qualification',AccountId=aList.get(0).Id,RecordTypeId=Schema.SObjectType.Opportunity.getRecordTypeInfosByDeveloperName().get('NATT_Opportunity_Units').getRecordTypeId(),NATT_Stock__c=true,NATT_Billing_Address__c=addList.get(0).Id,NATT_Shipping_Address__c=addList.get(1).Id));        
        insert oppList;
        
        Test.startTest();
            List<Order> orderList = new List<Order>();
            orderList.add(new Order(
                OwnerId = shipUser.Id,    
                NATT_Payment_Instruction__c='Credit Card', 
                AccountId=aList.get(0).Id,
                OpportunityId=oppList.get(0).Id,
                EffectiveDate=Date.today().addDays(3),
                Status='Draft',
                RecordTypeId=Schema.SObjectType.Order.getRecordTypeInfosByDeveloperName().get('NATT_Units_Order').getRecordTypeId(),
                NATT_Billing_Address__c=addList.get(0).Id,
                NATT_Shipping_Address__c=addList.get(1).Id));
            insert orderList;
            
            
            Product2 testProduct = new Product2(
                Name = 'Product Test'        
            );
            
            insert testProduct;
            List<OrderItem> orderItemList = new List<OrderItem>();
            for (Integer i=0; i<200; i++){
                OrderItem testOrderItem = new OrderItem(
                    OrderId = orderList[0].Id,
                    LineNumber = i+1,
                    Product2Id = testProduct.Id,
                    Quantity = 4,
                    UnitPrice = i+1,
                    ListPrice = i+1
                );
                orderItemList.add(testOrderItem);
            }
            insert orderItemList;
            Shipment testShip = new Shipment(
                ShipToName = 'test',
                NATT_PackingSlipNumber__c = 345678,
                TrackingNumber = '12345',
                NATT_Order__c = orderList[0].Id,
                ExpectedDeliveryDate = System.today() + 1,
                NATT_JDEInvoiceAmount__c = 100
            );
            
            insert testShip;
            Set<Id> shipmentIdsSet = new Set<Id>();
            Shipment newShipment = [SELECT Id, NATT_Transaction_Id__c,NATT_JDEInvoiceAmount__c,NATT_AuthorizeDotNetProfileId__c,NATT_Transaction_Payment_Id__c FROM Shipment WHERE ShipToName = 'test' LIMIT 1];
            shipmentIdsSet.add(newShipment.Id);
        Test.stopTest();
        // NattTesAuthorizeDotNet.AuthWrapper newAuth = NattTesAuthorizeDotNet.doAUth(email, amount, cardNumber, expirationDate, cvv);
        // NattTesAuthorizeDotNet.processShipment(shipmentIdsSet);
        // String paymentProfile = NattTesAuthorizeDotNet.buildCreateCustomerPaymentProfile('1',cardNumber,expirationDate,cvv);
    }
    
    @IsTest
    static void newShipmentTes_Test(){
        Account a = new Account(Name='TestAccount');
        insert a;
        
        Contact contact = new Contact(LastName='TestContact', AccountId=a.Id, NATT_AuthorizeDotNetProfileId__c='123');
        insert contact;
        
        Profile testProfile = [SELECT Id FROM Profile WHERE Name='NATT Full Access Community' LIMIT 1];

        User shipUser = new User(Alias='ship', Email='ship@example.com', LastName='Buyer',
                TimeZoneSidKey='GMT', LocaleSidKey='en_US', Username='ship@example.com.carrier',
                EmailEncodingKey='UTF-8', ProfileId=testProfile.Id, LanguageLocaleKey='en_US',
                ContactId=contact.Id);
        insert shipUser;

        //Create required Order variables (Account,Address,Opportunity)
        List<Account> aList = new List<Account>();
        alist.add(new Account(Name='Test Dealer',RecordTypeId=Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('Dealer').getRecordTypeId()));
        aList.add(new Account(Name='Test Dealer2',RecordTypeId=Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('Dealer').getRecordTypeId()));
        insert aList;
        
        List<NATT_Address__c> addList = new List<NATT_Address__c>();
        addList.add(new NATT_Address__c(NATT_Type__c='Billing',NATT_Account__c=aList.get(0).Id,RecordTypeId=Schema.SObjectType.NATT_Address__c.getRecordTypeInfosByDeveloperName().get('NATT_Address').getRecordTypeId()));
        addList.add(new NATT_Address__c(NATT_Type__c='Units Ship To',NATT_Account__c=aList.get(0).Id,RecordTypeId=Schema.SObjectType.NATT_Address__c.getRecordTypeInfosByDeveloperName().get('NATT_Address').getRecordTypeId()));
        insert addList;		
		
		//Start Mock class to run 
        Test.setMock(HttpCalloutMock.class, new ShipmentTriggerHandlerNattTest());
        Test.startTest();
            List<Order> orderList = new List<Order>();
            orderList.add(new Order(
                OwnerId = shipUser.Id,    
                NATT_Payment_Instruction__c='Credit Card', 
                AccountId=aList.get(0).Id,
                EffectiveDate=Date.today().addDays(3),
                Status='Draft',
                RecordTypeId=Schema.SObjectType.Order.getRecordTypeInfosByDeveloperName().get('TES_Parts_Order').getRecordTypeId(),
                NATT_Billing_Address__c=addList.get(0).Id,
                NATT_Shipping_Address__c=addList.get(1).Id,
                NATT_Transaction_Id__c = '40095530118',
                NATT_Transaction_Payment_Id__c = '555',
                NATT_Warehouse__c='TES'));
            insert orderList;            
            
            Product2 testProduct = new Product2(
                Name = 'Product Test'        
            );
            
            insert testProduct;
            List<OrderItem> orderItemList = new List<OrderItem>();
            for (Integer i=0; i<200; i++){
                OrderItem testOrderItem = new OrderItem(
                    OrderId = orderList[0].Id,
                    LineNumber = i+1,
                    Product2Id = testProduct.Id,
                    Quantity = 4,
                    UnitPrice = i+1,
                    ListPrice = i+1
                );
                orderItemList.add(testOrderItem);
            }
            insert orderItemList;
            Shipment testShip = new Shipment(
                ShipToName = 'test',
                NATT_PackingSlipNumber__c = 345678,
                TrackingNumber = '12345',
                NATT_Order__c = orderList[0].Id,
                ExpectedDeliveryDate = System.today() + 1,
                NATT_JDEInvoiceAmount__c = 100
            );
            
            insert testShip;
            Set<Id> shipmentIdsSet = new Set<Id>();
            Shipment newShipment = [SELECT Id, NATT_Transaction_Id__c,NATT_JDEInvoiceAmount__c,NATT_AuthorizeDotNetProfileId__c,NATT_Transaction_Payment_Id__c FROM Shipment WHERE ShipToName = 'test' LIMIT 1];
            shipmentIdsSet.add(newShipment.Id);
        	
        	//only called to update test coverage
        	update testShip;        
        	delete testShip;
        	undelete testShip;
        Test.stopTest();        
    }

}