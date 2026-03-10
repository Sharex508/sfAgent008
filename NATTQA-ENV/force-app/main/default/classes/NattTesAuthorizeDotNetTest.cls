/**
 * Test Coverage for NattTesAuthorizeDotNet class
 */
@isTest
private class NattTesAuthorizeDotNetTest implements HttpCalloutMock {
    public HTTPResponse respond(HTTPRequest req) {
        // Create a fake response
        HttpResponse res = new HttpResponse();
        res.setHeader('Content-Type', 'application/json');
        res.setBody('{"customerProfileId":"1000177237","transactionRequest" : {"customer":{"id":"1000177237"}},"transactionResponse": {"profileResponse":{"customerProfileId": "1000177237"}, "responseCode": "1", "authCode": "HW617E", "avsResultCode": "Y", "cvvResultCode": "", "cavvResultCode": "", "transId": "2157047189", "refTransID": "", "transHash": "E7CEB0A9F1BECA32A02493E1B31D5955", "testRequest": "0", "accountNumber": "XXXX1111", "accountType": "Visa", "messages": [ { "code": "1", "description": "This transaction has been approved." } ], "transHashSha2": "D0C4FFF5648511A5862B917CFD9BB78ABF8A6E1D90C119CBBC4C0B454F4FF40DED15B204E042F36ECA5FB15D02588E4E4A7B85B94E7279599CE6020462CB7DEE", "SupplementalDataQualificationIndicator": 0, "networkTransId": "123456789NNNH" }, "messages": { "resultCode": "Ok", "message": [ { "code": "I00001", "text": "Successful." } ] }}');
        res.setStatusCode(200);
        return res;
    }
    @IsTest(SeeAllData=true) 
    static void nattTesAuthorize_Test(){
        Account a = new Account(Name='TestAccount');
        insert a;
        Contact contact = new Contact(LastName='TestContact', AccountId=a.Id, NATT_AuthorizeDotNetProfileId__c='123');
        insert contact;
        
        Profile profile1 = [SELECT Id FROM Profile WHERE Name='B2B Customer Community User' LIMIT 1];

        User shipUser = new User(Alias='ship', Email='buyer@example.com', LastName='Buyer',
                TimeZoneSidKey='GMT', LocaleSidKey='en_US', Username='buyer@example.com.carrier',
                EmailEncodingKey='UTF-8', ProfileId=profile1.Id, LanguageLocaleKey='en_US',
                ContactId=contact.Id);
        insert shipUser;

        //Variables to mimic CC input
        String email = 'test@test.com';
        String amount = '100';
        String cardNumber = '5555555555555555';
        String expirationDate = '';
        String cvv = '105';

        //Creation of required Order/Shipment information
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
	        
        Test.setMock(HttpCalloutMock.class, new NattTesAuthorizeDotNetTest());
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
            NATT_Shipping_Address__c=addList.get(1).Id,
            NATT_Transaction_Id__c = '40095530118',
            NATT_Transaction_Payment_Id__c = '555'));
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
        NattTesAuthorizeDotNet.AuthWrapper newAuth = NattTesAuthorizeDotNet.doAUth(email, amount, cardNumber, expirationDate, cvv);
        NattTesAuthorizeDotNet.processShipment(shipmentIdsSet);
        String paymentProfile = NattTesAuthorizeDotNet.buildCreateCustomerPaymentProfile('1',cardNumber,expirationDate,cvv);
    }

    @future
    private static void createUser(String cId){
        Profile profile = [SELECT Id FROM Profile WHERE Name='B2B Customer Community User' LIMIT 1];
        // Profile profile = [SELECT Id FROM Profile WHERE Name='NATT Full Access Community' LIMIT 1];
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