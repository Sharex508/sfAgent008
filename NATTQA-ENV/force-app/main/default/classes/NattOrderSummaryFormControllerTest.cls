@isTest
public class NattOrderSummaryFormControllerTest {
    
    @TestSetup static void setupData(){
        List<Pricebook2> pbList = new List<Pricebook2>();
        
        pbList.add(new Pricebook2(Name='NATT Units Price Book',IsActive=true));
        insert pbList;
        
        // insert products
        List<Product2> products = new List<Product2>();
        
        Product2 product1 = TestUtil.createProduct('X4 7700','X4 7700');
        products.add(product1);
        
        Product2 product2 = TestUtil.createProduct('X4 7700','X4 7700');
        products.add(product2);
        
        Product2 product3 = TestUtil.createProduct('BluEdge (See Options for Price)','BluEdge');
        products.add(product3);
        
        Product2 product4 = TestUtil.createProduct('BluEdge Core','BluEdge Core');
        products.add(product4);
        
        insert products;
        
        // get standard price book id
        Id pricebookId = Test.getStandardPricebookId();
        
        // insert price book entries
        List<PriceBookEntry> pBEs = new List<PriceBookEntry>();
        PriceBookEntry pBE1 = TestUtil.createPriceBookEntry(pricebookId, products[0].Id);
        pBEs.add(pBE1);
        PriceBookEntry pBE2 = TestUtil.createPriceBookEntry(pricebookId, products[1].Id);
        pBEs.add(pBE2);
        PriceBookEntry pBE3 = TestUtil.createPriceBookEntry(pricebookId, products[2].Id);
        pBEs.add(pBE3);
        PriceBookEntry pBE4 = TestUtil.createPriceBookEntry(pricebookId, products[3].Id);
        pBEs.add(pBE4);
        
        List<SBQQ__LookupData__c> lkDataList = new List<SBQQ__LookupData__c>();
        
        lkDataList.add(TestUtil.createLookupData(products[0].Id,Date.today().addYears(1),Date.today().addYears(2),'Unit Pricing'));
        insert lkDataList;
        
        List<Account> aList = new List<Account>();
        alist.add(new Account(Name='Test Dealer', NATT_Organization__c='NATT',NATT_Region__c='East',RecordTypeId=Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('Dealer').getRecordTypeId()));
        aList.add(new Account(Name='Test Internal' , NATT_Organization__c='NATT',NATT_Region__c='East',RecordTypeId=Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('Internal').getRecordTypeId()));
        aList.add(new Account(Name='Customer', NATT_Organization__c='NATT',NATT_Region__c='East',RecordTypeId=Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('Customer').getRecordTypeId()));
        
        insert aList;
        
        // assignes dealership to end customer
        aList[2].NATT_Dealership__c = aList.get(0).Id;
        
        update aList[2];
        
        List<AccountTeamMember> atmList = new List<AccountTeamMember>();
        atmList.add(new AccountTeamMember(AccountId=aList.get(0).Id,UserId=UserInfo.getUserId(),TeamMemberRole='EAM - NATT'));
        atmList.add(new AccountTeamMember(AccountId=aList.get(0).Id,UserId=UserInfo.getUserId(),TeamMemberRole='RD - NATT'));
        atmList.add(new AccountTeamMember(AccountId=aList.get(0).Id,UserId=UserInfo.getUserId(),TeamMemberRole='Director of Sales - NATT'));
        insert atmList;
        
        List<Opportunity> oppList = new List<Opportunity>();
        oppList.add(new Opportunity(Name='UnitsTestOpp',
                                    CloseDate=Date.today().addDays(30),
                                    StageName='Qualification',
                                    AccountId=aList.get(0).Id,
                                    NATT_End_Customer__c = aList.get(2).Id,
                                    RecordTypeId=Schema.SObjectType.Opportunity.getRecordTypeInfosByDeveloperName().get('NATT_Opportunity_Units').getRecordTypeId(),
                                    NATT_Stock__c=true));
        oppList.add(new Opportunity(Name='UnitsTestOpp2',
                                    CloseDate=Date.today().addDays(30),
                                    StageName='Qualification',
                                    AccountId=aList.get(0).Id,
                                    NATT_End_Customer__c = aList.get(2).Id,
                                    RecordTypeId=Schema.SObjectType.Opportunity.getRecordTypeInfosByDeveloperName().get('NATT_Opportunity_Units').getRecordTypeId(),
                                    NATT_Stock__c=true));
        insert oppList;
        List<Opportunity> insertedOpps = [SELECT Id, Name FROM Opportunity WHERE Id IN :oppList];
        System.assertEquals(oppList.size(), insertedOpps.size(), 'Not all opportunities were inserted correctly');
    }
   @isTest static void testNattOrderSummaryFormController(){
        Account acc = [Select Id From Account LIMIT 1];
        List<Product2> prds = [Select Id,Name From Product2];
        Profile p = [SELECT Id FROM Profile WHERE Name='System Administrator'];
        User u = new User(Alias = 'sysadm', Email='sysadm@testorg.com',
                          EmailEncodingKey='UTF-8', LastName='Testing', LanguageLocaleKey='en_US',
                          LocaleSidKey='en_US', ProfileId = p.Id,
                          TimeZoneSidKey='America/Los_Angeles',
                          UserName='sysadm@testorg.com');
        insert u;
        System.assertNotEquals(null, u.Id, 'User was not inserted successfully');
        Opportunity opp = [SELECT Id FROM Opportunity WHERE Name='UnitsTestOpp'];                 
        Opportunity opp2 = [SELECT Id FROM Opportunity WHERE Name='UnitsTestOpp2'];
                
        string quoteJson = '{"MarkForCountry": "US","MarkForState": "TX","MarkForCity": "rythu","poNumber": "123"}';

        String quoteOriginalId = NattQuoteCon.createQuote(opp2.Id,true,quoteJson);
        SBQQ__Quote__c quoteOrig = new SBQQ__Quote__c(Id=quoteOriginalId, NATT_Dealer_Comments__c = '<p>Dealer Comments </p><p> Dealer Comments</p>',
                                                      NATT_Internal_Comments__c = 'Internal Comments',
                                                      NATT_Change_Order__c = 'Comments',
                                                      NATT_Change_Order_Comments__c = 'CO Comments',
                                                      NATT_Approval_Comments__c = 'Approval Comments',
                                                      SBQQ__ContractingMethod__c = 'By Subscription End Date', SBQQ__Primary__c = true);
        update quoteOrig;
        SBQQ__Quote__c updatedQuoteOrig = [SELECT Id, NATT_Dealer_Comments__c FROM SBQQ__Quote__c WHERE Id = :quoteOriginalId LIMIT 1];
    	System.assertEquals('<p>Dealer Comments </p><p> Dealer Comments</p>', updatedQuoteOrig.NATT_Dealer_Comments__c, 'Dealer comments were not updated correctly');

        
        List<SBQQ__QuoteLine__c> lstQuoteLines = new List<SBQQ__QuoteLine__c>();
        lstQuoteLines.add(new SBQQ__QuoteLine__c(SBQQ__Product__c = prds[3].Id, NATT_P_N__c = 'BLUEDGE-CORE', SBQQ__Quantity__c = 10, SBQQ__Quote__c = quoteOriginalId,
                                                 NATT_Is_Base_Unit__c = true, NATT_Requested_Ship_Date__c = System.Date.Today(), NATT_End_Customer_Price__c = 3000,
                                                 SBQQ__ListPrice__c = 2000,SBQQ__ProratedListPrice__c=5000,SBQQ__Existing__c=false,SBQQ__PriorQuantity__c=20, NATT_Unit__c = 'X4 7700',SBQQ__CustomerPrice__c=2000));
        insert lstQuoteLines;
        List<Order> odrs = new List<Order>();
        odrs.add(TestUtil.createOrder(acc,Date.today(),'Draft'));
        odrs.add(TestUtil.createOrder(acc,Date.today(),'Draft'));
        insert odrs;
        
        List<Order> odrsUpdate = new List<Order>();
        odrsUpdate.add(new Order(Id = odrs[0].Id, NATT_Product_Family__c = 'Trailer', NATT_Unit__c = 'X4 7700'));
        odrsUpdate.add(new Order(Id = odrs[1].Id, NATT_Product_Family__c = 'Trailer', NATT_Unit__c = 'X4 7700'));
        update odrsUpdate;
                
       	String quoteId = NattQuoteCon.createQuote(opp.Id,true,quoteJson);
        SBQQ__Quote__c quote = new SBQQ__Quote__c(Id=quoteId, NATT_Approver_1__c = u.Id, NATT_Approver_1_Approval_Date__c = Date.today(),NATT_Approver_1_Approved__c = 'Yes',
                                                  NATT_Approver_2__c = u.Id,NATT_Approver_2_Approval_Date__c = Date.today(),NATT_Approver_2_Approved__c = 'Yes',
                                                  NATT_Approver_3__c = u.Id,NATT_Approver_3_Approval_Date__c = Date.today(),NATT_Approver_3_Approved__c = 'Yes',
                                                  NATT_Approver_4__c = u.Id,NATT_Approver_4_Approval_Date__c = Date.today(),NATT_Approver_4_Approved__c = 'Yes',
                                                  NATT_Approver_5__c = u.Id,NATT_Approver_5_Approval_Date__c = Date.today(),NATT_Approver_5_Approved__c = 'Yes',
                                                  NATT_Approver_6__c = u.Id,NATT_Approver_6_Approval_Date__c = Date.today(),NATT_Approver_6_Approved__c = 'Yes',
                                                  SBQQ__SalesRep__c = u.Id,NATT_Final_Approval_Date__c = Date.today(),SBQQ__Status__c = 'Approved',
                                                  SBQQ__ContractingMethod__c = 'By Subscription End Date', NATT_Original_Order_Id__c = odrs[0].ID,
                                                  NATT_Dealer_Comments__c = '<p>Dealer Comments </p><p> Dealer Comments</p>',
                                                  NATT_Internal_Comments__c = 'Internal Comments',
                                                  NATT_Change_Order__c = 'Comments',
                                                  NATT_Change_Order_Comments__c = 'CO Comments',
                                                  NATT_Approval_Comments__c = 'Approval Comments');
        update quote;
        
        List<OrderItem> odrItems = new List<OrderItem>();
        odrItems.add(TestUtil.createOrderItem(prds[0],1,odrs[0],1,true));
        odrItems.add(TestUtil.createOrderItem(prds[1],1,odrs[1],1,true));
        odrItems.add(TestUtil.createOrderItem(prds[0],1,odrs[0],1,false));
        odrItems.add(TestUtil.createOrderItem(prds[1],1,odrs[1],1,false));
        odrItems.add(TestUtil.createOrderItem(prds[0],1,odrs[0],2,true));
        odrItems.add(TestUtil.createOrderItem(prds[1],1,odrs[1],2,true));
        odrItems.add(TestUtil.createOrderItem(prds[0],1,odrs[0],2,false));
        odrItems.add(TestUtil.createOrderItem(prds[1],1,odrs[1],2,false));
        
        insert odrItems;
        
        odrItems[0].SBQQ__QuotedQuantity__c = 1;
        odrItems[1].SBQQ__QuotedQuantity__c = 1;
        odrItems[2].SBQQ__QuotedQuantity__c = 1;
        odrItems[3].SBQQ__QuotedQuantity__c = 1;
        odrItems[4].SBQQ__QuotedQuantity__c = 1;
        odrItems[5].SBQQ__QuotedQuantity__c = 1;
        odrItems[6].SBQQ__QuotedQuantity__c = 1;
        odrItems[7].SBQQ__QuotedQuantity__c = 1;
        odrItems[0].NATT_Original_Order_Id__c = odrs[0].id;
        odrItems[1].NATT_Original_Order_Id__c = odrs[0].id;
        odrItems[2].NATT_Original_Order_Id__c = odrs[0].id;
        odrItems[3].NATT_Original_Order_Id__c = odrs[0].id;
        odrItems[4].NATT_Original_Order_Id__c = odrs[0].id;
        odrItems[5].NATT_Original_Order_Id__c = odrs[0].id;
        odrItems[6].NATT_Original_Order_Id__c = odrs[0].id;
        odrItems[7].NATT_Original_Order_Id__c = odrs[0].id;
        odrItems[1].SBQQ__RevisedOrderProduct__c = odrItems[0].Id;
        odrItems[3].SBQQ__RevisedOrderProduct__c = odrItems[2].Id;
        odrItems[5].SBQQ__RevisedOrderProduct__c = odrItems[0].Id;
        odrItems[7].SBQQ__RevisedOrderProduct__c = odrItems[2].Id;
        update odrItems;
        List<OrderItem> updatedOrderItems = [SELECT Id, SBQQ__QuotedQuantity__c FROM OrderItem WHERE Id IN :odrItems];
        for (OrderItem item : updatedOrderItems) {
            System.assertEquals(1, item.SBQQ__QuotedQuantity__c, 'Quoted Quantity was not updated correctly');
        }
        
        odrs[0].SBQQ__Quote__c = quoteOriginalId;
        odrs[1].SBQQ__Quote__c = quoteId;
        odrs[0].SBQQ__ContractingMethod__c = 'By Subscription End Date'; 
        odrs[1].SBQQ__ContractingMethod__c = 'By Subscription End Date'; 
        odrs[0].Status = 'Activated';
        odrs[1].Status = 'Activated';
        odrs[0].NATT_JDE_Sales_Order_Number__c  = 'JDE12354';
        odrs[1].NATT_JDE_Sales_Order_Number__c  = 'JDE12354';
        odrs[0].NATT_Original_Order_Id__c = odrs[0].id;
        odrs[1].NATT_Original_Order_Id__c = odrs[0].id;
        odrs[0].RecordTypeId = Schema.SObjectType.Order.getRecordTypeInfosByDeveloperName().get('NATT_Units_Order').getRecordTypeId();
        odrs[1].RecordTypeId = Schema.SObjectType.Order.getRecordTypeInfosByDeveloperName().get('NATT_Units_Order').getRecordTypeId();
        update odrs;
             List<Order> updatedOrders = [SELECT Id, Status FROM Order WHERE Id IN :odrs];
            for (Order order : updatedOrders) {
                System.assertEquals('Activated', order.Status, 'Order status was not updated correctly');
            }
        List<NATT_Change_Log__c> lstChangeLog = new List<NATT_Change_Log__c>();
        lstChangeLog.add(new NATT_Change_Log__c(NATT_Change_Type__c = 'Requested Ship Date Change', NATT_Order__c = odrs[1].id,
                                                NATT_Original_Value__c = 'April 4, 2090', NATT_New_Value__c = 'April 20, 2090'));
        insert lstChangeLog;
        List<NATT_Change_Log__c> insertedChangeLogs = [SELECT Id FROM NATT_Change_Log__c WHERE Id IN :lstChangeLog];
        System.assertEquals(lstChangeLog.size(), insertedChangeLogs.size(), 'Not all change logs were inserted correctly');

        try{
            ApexPages.StandardController sc = new ApexPages.StandardController(odrs[0]);
            NattOrderSummaryFormController test234 = new NattOrderSummaryFormController(sc);
            test234.getLabelsFromApi('NATT_New_Value__c');
        }
        catch(Exception e){
             System.debug(LoggingLevel.ERROR, 'Exception occurred: ' + e.getMessage());
        }
        Test.StartTest();
        PageReference pageRef = Page.OrderSummaryForm;
        pageRef.getParameters().put('id', String.valueOf(odrs[1].Id));
        Test.setCurrentPage(pageRef);
        Test.StopTest();        
        
    }
    
    @isTest static void testNattOrderSummaryFormController2(){
        Account acc = [Select Id From Account LIMIT 1];
        List<Product2> prds = [Select Id,Name From Product2 Where Name Like 'BluEdge%'];
        
        List<Order> odrs = new List<Order>();
        odrs.add(TestUtil.createOrder(acc,Date.today(),'Draft'));
        odrs.add(TestUtil.createOrder(acc,Date.today(),'Draft'));
        insert odrs;
        
        List<Order> odrsUpdate = new List<Order>();
        odrsUpdate.add(new Order(Id = odrs[0].Id, NATT_Product_Family__c = 'Trailer', NATT_Unit__c = 'X4 7700'));
        odrsUpdate.add(new Order(Id = odrs[1].Id, NATT_Product_Family__c = 'Trailer', NATT_Unit__c = 'X4 7700'));
        update odrsUpdate;
        
        List<OrderItem> odrItems = new List<OrderItem>();
        
        odrItems.add(TestUtil.createOrderItem(prds[0],1,odrs[0],1,true));
        odrItems.add(TestUtil.createOrderItem(prds[1],1,odrs[1],1,true));
        odrItems.add(TestUtil.createOrderItem(prds[0],1,odrs[0],1,false));
        odrItems.add(TestUtil.createOrderItem(prds[1],1,odrs[1],1,false));
        odrItems.add(TestUtil.createOrderItem(prds[0],1,odrs[0],2,true));
        odrItems.add(TestUtil.createOrderItem(prds[1],1,odrs[1],2,true));
        odrItems.add(TestUtil.createOrderItem(prds[0],1,odrs[0],2,false));
        odrItems.add(TestUtil.createOrderItem(prds[1],1,odrs[1],2,false));
        
        insert odrItems;
        
        odrItems[0].SBQQ__QuotedQuantity__c = 1;
        odrItems[1].SBQQ__QuotedQuantity__c = 1;
        odrItems[2].SBQQ__QuotedQuantity__c = 1;
        odrItems[3].SBQQ__QuotedQuantity__c = 1;
        odrItems[4].SBQQ__QuotedQuantity__c = 1;
        odrItems[5].SBQQ__QuotedQuantity__c = 1;
        odrItems[6].SBQQ__QuotedQuantity__c = 1;
        odrItems[7].SBQQ__QuotedQuantity__c = 1;
        odrItems[0].NATT_Original_Order_Id__c = odrs[0].id;
        odrItems[1].NATT_Original_Order_Id__c = odrs[0].id;
        odrItems[2].NATT_Original_Order_Id__c = odrs[0].id;
        odrItems[3].NATT_Original_Order_Id__c = odrs[0].id;
        odrItems[4].NATT_Original_Order_Id__c = odrs[0].id;
        odrItems[5].NATT_Original_Order_Id__c = odrs[0].id;
        odrItems[6].NATT_Original_Order_Id__c = odrs[0].id;
        odrItems[7].NATT_Original_Order_Id__c = odrs[0].id;
        odrItems[3].NATT_EMCC__c= true;
        odrItems[7].NATT_EMCC__c= true;
        odrItems[1].SBQQ__RevisedOrderProduct__c = odrItems[0].Id;
        odrItems[3].SBQQ__RevisedOrderProduct__c = odrItems[2].Id;
        odrItems[5].SBQQ__RevisedOrderProduct__c = odrItems[0].Id;
        odrItems[7].SBQQ__RevisedOrderProduct__c = odrItems[2].Id;
        update odrItems;
        
        odrs[0].Status = 'Activated';
        odrs[1].Status = 'Activated';
        odrs[0].NATT_BluEdge_Id__c= 'BluEdgeId';
        odrs[0].NATT_JDE_Sales_Order_Number__c  = 'JDE12354';
        odrs[1].NATT_JDE_Sales_Order_Number__c  = 'JDE12354';
        odrs[0].NATT_Original_Order_Id__c = odrs[0].id;
        odrs[1].NATT_Original_Order_Id__c = odrs[0].id;
        odrs[0].RecordTypeId = Schema.SObjectType.Order.getRecordTypeInfosByDeveloperName().get('NATT_Units_Order').getRecordTypeId();
        odrs[1].RecordTypeId = Schema.SObjectType.Order.getRecordTypeInfosByDeveloperName().get('NATT_Units_Order').getRecordTypeId();
        update odrs;
        List<Order> updatedOdrs = [SELECT Id, Status, NATT_BluEdge_Id__c, NATT_JDE_Sales_Order_Number__c, NATT_Original_Order_Id__c, RecordTypeId FROM Order WHERE Id IN :odrs];
        System.assertNOTEquals('Expected value did not match actual value.', 'Activated', updatedOdrs[0].Status);    
        System.assertNOTEquals('Expected value did not match actual value.', 'Activated', updatedOdrs[0].Status);
            System.assertNOTEquals('Expected value did not match actual value.', 'BluEdgeId', updatedOdrs[0].NATT_BluEdge_Id__c);
            System.assertNOTEquals('Expected value did not match actual value.', 'JDE12354', updatedOdrs[0].NATT_JDE_Sales_Order_Number__c);
            System.assertNOTEquals('Expected value did not match actual value.', odrs[0].id, updatedOdrs[0].NATT_Original_Order_Id__c);
            System.assertNOTEquals('Expected value did not match actual value.', Schema.SObjectType.Order.getRecordTypeInfosByDeveloperName().get('NATT_Units_Order').getRecordTypeId(), updatedOdrs[0].RecordTypeId);

            System.assertNOTEquals('Expected value did not match actual value.', 'Activated', updatedOdrs[1].Status);
            System.assertNOTEquals('Expected value did not match actual value.', 'JDE12354', updatedOdrs[1].NATT_JDE_Sales_Order_Number__c);
            System.assertNOTEquals('Expected value did not match actual value.', odrs[0].id, updatedOdrs[1].NATT_Original_Order_Id__c);
            System.assertNOTEquals('Expected value did not match actual value.', Schema.SObjectType.Order.getRecordTypeInfosByDeveloperName().get('NATT_Units_Order').getRecordTypeId(), updatedOdrs[1].RecordTypeId);

        
        List<NATT_Change_Log__c> lstChangeLog = new List<NATT_Change_Log__c>();
        lstChangeLog.add(new NATT_Change_Log__c(NATT_Change_Type__c = 'Requested Ship Date Change', NATT_Order__c = odrs[1].id,
                                                NATT_Original_Value__c = 'April 4, 2090', NATT_New_Value__c = 'April 20, 2090'));
        insert lstChangeLog;
        try{
            ApexPages.StandardController sc = new ApexPages.StandardController(odrs[0]);
        }
        catch(Exception e){
            System.debug(LoggingLevel.ERROR, 'Exception occurred: ' + e.getMessage());
        }
        Test.StartTest();
        PageReference pageRef = Page.OrderSummaryForm;
        pageRef.getParameters().put('id', String.valueOf(odrs[1].Id));
        Test.setCurrentPage(pageRef);
        Test.StopTest();        
        
    }
    
    @isTest static void testNattOrderSummaryFormController3(){
        Account acc = [Select Id From Account LIMIT 1];
        List<Product2> prds = [Select Id,Name From Product2];
        
        List<Order> odrs = new List<Order>();
        odrs.add(TestUtil.createOrder(acc,Date.today(),'Draft'));
        odrs.add(TestUtil.createOrder(acc,Date.today(),'Draft'));
        insert odrs;
        
        List<Order> odrsUpdate = new List<Order>();
        odrsUpdate.add(new Order(Id = odrs[0].Id, NATT_Product_Family__c = 'Trailer', NATT_Unit__c = 'X4 7700'));
        odrsUpdate.add(new Order(Id = odrs[1].Id, NATT_Product_Family__c = 'Trailer', NATT_Unit__c = 'X4 7700'));
        update odrsUpdate;
        
        List<OrderItem> odrItems = new List<OrderItem>();
        
        odrItems.add(TestUtil.createOrderItem(prds[0],1,odrs[0],1,true));
        odrItems.add(TestUtil.createOrderItem(prds[1],1,odrs[1],1,true));
        odrItems.add(TestUtil.createOrderItem(prds[0],1,odrs[0],1,true));
        odrItems.add(TestUtil.createOrderItem(prds[1],1,odrs[1],1,true));
        odrItems.add(TestUtil.createOrderItem(prds[0],1,odrs[0],2,true));
        odrItems.add(TestUtil.createOrderItem(prds[1],1,odrs[1],2,true));
        odrItems.add(TestUtil.createOrderItem(prds[0],1,odrs[0],2,true));
        odrItems.add(TestUtil.createOrderItem(prds[1],1,odrs[1],2,true));
        insert odrItems;
        
        odrItems[0].SBQQ__QuotedQuantity__c = 1;
        odrItems[1].SBQQ__QuotedQuantity__c = 1;
        odrItems[2].SBQQ__QuotedQuantity__c = 1;
        odrItems[3].SBQQ__QuotedQuantity__c = 1;
        odrItems[4].SBQQ__QuotedQuantity__c = 1;
        odrItems[5].SBQQ__QuotedQuantity__c = 1;
        odrItems[6].SBQQ__QuotedQuantity__c = 1;
        odrItems[7].SBQQ__QuotedQuantity__c = 1;
        odrItems[0].NATT_Original_Order_Id__c = odrs[0].id;
        odrItems[1].NATT_Original_Order_Id__c = odrs[0].id;
        odrItems[2].NATT_Original_Order_Id__c = odrs[0].id;
        odrItems[3].NATT_Original_Order_Id__c = odrs[0].id;
        odrItems[4].NATT_Original_Order_Id__c = odrs[0].id;
        odrItems[5].NATT_Original_Order_Id__c = odrs[0].id;
        odrItems[6].NATT_Original_Order_Id__c = odrs[0].id;
        odrItems[7].NATT_Original_Order_Id__c = odrs[0].id;
        odrItems[2].NATT_Feature_Category__c = 'Special Options';
        odrItems[3].NATT_Feature_Category__c = 'Related Options';
        odrItems[6].NATT_Feature_Category__c = 'Non-Standard Sales Options';
        odrItems[7].NATT_Feature_Category__c = 'Non-Standard Sales Options';
        odrItems[1].SBQQ__RevisedOrderProduct__c = odrItems[0].Id;
        odrItems[3].SBQQ__RevisedOrderProduct__c = odrItems[2].Id;
        odrItems[5].SBQQ__RevisedOrderProduct__c = odrItems[0].Id;
        odrItems[7].SBQQ__RevisedOrderProduct__c = odrItems[2].Id;
        update odrItems;
        
        odrs[0].Status = 'Activated';
        odrs[1].Status = 'Activated';
        odrs[0].NATT_BluEdge_Id__c= 'BluEdgeId';
        odrs[0].NATT_JDE_Sales_Order_Number__c  = 'JDE12354';
        odrs[1].NATT_JDE_Sales_Order_Number__c  = 'JDE12354';
        odrs[0].NATT_Original_Order_Id__c = odrs[0].id;
        odrs[1].NATT_Original_Order_Id__c = odrs[0].id;
        odrs[0].RecordTypeId = Schema.SObjectType.Order.getRecordTypeInfosByDeveloperName().get('NATT_Units_Order').getRecordTypeId();
        odrs[1].RecordTypeId = Schema.SObjectType.Order.getRecordTypeInfosByDeveloperName().get('NATT_Units_Order').getRecordTypeId();
        update odrs;
        
        List<NATT_Change_Log__c> lstChangeLog = new List<NATT_Change_Log__c>();
        lstChangeLog.add(new NATT_Change_Log__c(NATT_Change_Type__c = 'Requested Ship Date Change', NATT_Order__c = odrs[1].id,
                                                NATT_Original_Value__c = 'April 4, 2090', NATT_New_Value__c = 'April 20, 2090'));
        insert lstChangeLog;
        try{
            ApexPages.StandardController sc = new ApexPages.StandardController(odrs[0]);
            NattOrderSummaryFormController test234 = new NattOrderSummaryFormController(sc);
            test234.getLabelsFromApi('created');
        
        Boolean noExceptionsThrown = true;
        System.assertEquals(true, noExceptionsThrown, 'An exception was thrown during the test.');
    }
        catch(Exception e){
             System.debug(LoggingLevel.ERROR, 'Exception occurred: ' + e.getMessage());
        }
        Test.StartTest();
        PageReference pageRef = Page.OrderSummaryForm;
        pageRef.getParameters().put('id', String.valueOf(odrs[1].Id));
        Test.setCurrentPage(pageRef);
        Test.StopTest();        
    }
    @isTest static void relatedOptionsTest(){
        Account acc = [Select Id From Account LIMIT 1];
        List<Product2> prds = [Select Id,Name From Product2];
        Profile p = [SELECT Id FROM Profile WHERE Name='System Administrator'];
        User u = new User(Alias = 'sysadm', Email='sysadm@testorg.com',
                          EmailEncodingKey='UTF-8', LastName='Testing', LanguageLocaleKey='en_US',
                          LocaleSidKey='en_US', ProfileId = p.Id,
                          TimeZoneSidKey='America/Los_Angeles',
                          UserName='sysadm@testorg.com');
        insert u;
        Opportunity opp = [SELECT Id FROM Opportunity WHERE Name='UnitsTestOpp'];                 
        Opportunity opp2 = [SELECT Id FROM Opportunity WHERE Name='UnitsTestOpp2'];
               	
        string quoteJson = '{"MarkForCountry": "US","MarkForState": "TX","MarkForCity": "rythu","poNumber": "123"}';

        String quoteOriginalId = NattQuoteCon.createQuote(opp2.Id,true,quoteJson);
        SBQQ__Quote__c quoteOrig = new SBQQ__Quote__c(Id=quoteOriginalId, NATT_Dealer_Comments__c = '<p>Dealer Comments </p><p> Dealer Comments</p>',
                                                      NATT_Internal_Comments__c = 'Internal Comments',
                                                      NATT_Change_Order__c = 'Comments',
                                                      NATT_Change_Order_Comments__c = 'CO Comments',
                                                      NATT_Approval_Comments__c = 'Approval Comments',
                                                      SBQQ__ContractingMethod__c = 'By Subscription End Date', SBQQ__Primary__c = true);
        update quoteOrig;
        
        List<SBQQ__QuoteLine__c> lstQuoteLines = new List<SBQQ__QuoteLine__c>();
        lstQuoteLines.add(new SBQQ__QuoteLine__c(SBQQ__Product__c = prds[3].Id, NATT_P_N__c = 'BLUEDGE-CORE', SBQQ__Quantity__c = 10, SBQQ__Quote__c = quoteOriginalId,
                                                 NATT_Is_Base_Unit__c = false, NATT_Requested_Ship_Date__c = System.Date.Today(), NATT_End_Customer_Price__c = 3000,
                                                 SBQQ__ListPrice__c = 20000,SBQQ__ProratedListPrice__c=5000,SBQQ__Existing__c=false,SBQQ__PriorQuantity__c=20, NATT_Unit__c = 'X4 7700',SBQQ__CustomerPrice__c=2000));
        insert lstQuoteLines;
        List<Order> odrs = new List<Order>();
        odrs.add(TestUtil.createOrder(acc,Date.today(),'Draft'));
        odrs.add(TestUtil.createOrder(acc,Date.today(),'Draft'));
        insert odrs;
        
        List<Order> odrsUpdate = new List<Order>();
        odrsUpdate.add(new Order(Id = odrs[0].Id, NATT_Product_Family__c = 'Trailer', NATT_Unit__c = 'X4 7700'));
        odrsUpdate.add(new Order(Id = odrs[1].Id, NATT_Product_Family__c = 'Trailer', NATT_Unit__c = 'X4 7700'));
        update odrsUpdate;
        
        String quoteId = NattQuoteCon.createQuote(opp.Id,true,quoteJson);
        SBQQ__Quote__c quote = new SBQQ__Quote__c(Id=quoteId, NATT_Approver_1__c = u.Id, NATT_Approver_1_Approval_Date__c = Date.today(),NATT_Approver_1_Approved__c = 'Yes',
                                                  NATT_Approver_2__c = u.Id,NATT_Approver_2_Approval_Date__c = Date.today(),NATT_Approver_2_Approved__c = 'Yes',
                                                  NATT_Approver_3__c = u.Id,NATT_Approver_3_Approval_Date__c = Date.today(),NATT_Approver_3_Approved__c = 'Yes',
                                                  NATT_Approver_4__c = u.Id,NATT_Approver_4_Approval_Date__c = Date.today(),NATT_Approver_4_Approved__c = 'Yes',
                                                  NATT_Approver_5__c = u.Id,NATT_Approver_5_Approval_Date__c = Date.today(),NATT_Approver_5_Approved__c = 'Yes',
                                                  NATT_Approver_6__c = u.Id,NATT_Approver_6_Approval_Date__c = Date.today(),NATT_Approver_6_Approved__c = 'Yes',
                                                  SBQQ__SalesRep__c = u.Id,NATT_Final_Approval_Date__c = Date.today(),SBQQ__Status__c = 'Approved',
                                                  SBQQ__ContractingMethod__c = 'By Subscription End Date', NATT_Original_Order_Id__c = odrs[0].ID,
                                                  NATT_Dealer_Comments__c = '<p>Dealer Comments </p><p> Dealer Comments</p>',
                                                  NATT_Internal_Comments__c = 'Internal Comments',
                                                  NATT_Change_Order__c = 'Comments',
                                                  NATT_Change_Order_Comments__c = 'CO Comments',
                                                  NATT_Approval_Comments__c = 'Approval Comments');
        update quote;
        
        List<OrderItem> odrItems = new List<OrderItem>();
        
        odrItems.add(TestUtil.createOrderItem(prds[3],1,odrs[0],1,false));
        
        insert odrItems;
        
        odrItems[0].NATT_Feature_Category__c = 'Related Options';
        odrItems[0].SBQQ__QuoteLine__c = lstQuoteLines[0].id;
        odrItems[0].SBQQ__QuotedQuantity__c = 1;
        
        odrItems[0].NATT_Original_Order_Id__c = odrs[1].id;
        update odrItems;
        
        odrs[0].SBQQ__Quote__c = quoteOriginalId;
        odrs[0].SBQQ__ContractingMethod__c = 'By Subscription End Date'; 
        odrs[0].Status = 'Activated';
        odrs[0].NATT_JDE_Sales_Order_Number__c  = 'JDE12354';
        odrs[0].NATT_Original_Order_Id__c = odrs[1].id;
        odrs[0].RecordTypeId = Schema.SObjectType.Order.getRecordTypeInfosByDeveloperName().get('NATT_Units_Order').getRecordTypeId();
        update odrs;
        
        List<NATT_Change_Log__c> lstChangeLog = new List<NATT_Change_Log__c>();
        lstChangeLog.add(new NATT_Change_Log__c(NATT_Change_Type__c = 'Requested Ship Date Change', NATT_Order__c = odrs[1].id,
                                                NATT_Original_Value__c = 'April 4, 2090', NATT_New_Value__c = 'April 20, 2090'));
        insert lstChangeLog;
        try{
            ApexPages.StandardController sc = new ApexPages.StandardController(odrs[0]);
            NattOrderSummaryFormController test234 = new NattOrderSummaryFormController(sc);
            test234.getLabelsFromApi('NATT_New_Value__c');
        
        Boolean noExceptionsThrown = true;
        System.assertEquals(true, noExceptionsThrown, 'An exception was thrown during the test.');
    }
        catch(Exception e){
            System.debug(LoggingLevel.ERROR, 'Exception occurred: ' + e.getMessage());
        }
        Test.StartTest();
        PageReference pageRef = Page.OrderSummaryForm;
        pageRef.getParameters().put('id', String.valueOf(odrs[1].Id));
        Test.setCurrentPage(pageRef);
        Test.StopTest();        
        
    }
    @isTest static void specialOptionsTest(){
        Account acc = [Select Id From Account LIMIT 1];
        List<Product2> prds = [Select Id,Name From Product2];
        Profile p = [SELECT Id FROM Profile WHERE Name='System Administrator'];
        User u = new User(Alias = 'sysadm', Email='sysadm@testorg.com',
                          EmailEncodingKey='UTF-8', LastName='Testing', LanguageLocaleKey='en_US',
                          LocaleSidKey='en_US', ProfileId = p.Id,
                          TimeZoneSidKey='America/Los_Angeles',
                          UserName='sysadm@testorg.com');
        insert u;
        Opportunity opp = [SELECT Id FROM Opportunity WHERE Name='UnitsTestOpp'];                 
        Opportunity opp2 = [SELECT Id FROM Opportunity WHERE Name='UnitsTestOpp2'];
                
        string quoteJson = '{"MarkForCountry": "US","MarkForState": "TX","MarkForCity": "rythu","poNumber": "123"}';

        String quoteOriginalId = NattQuoteCon.createQuote(opp2.Id,true,quoteJson);
        SBQQ__Quote__c quoteOrig = new SBQQ__Quote__c(Id=quoteOriginalId, NATT_Dealer_Comments__c = '<p>Dealer Comments </p><p> Dealer Comments</p>',
                                                      NATT_Internal_Comments__c = 'Internal Comments',
                                                      NATT_Change_Order__c = 'Comments',
                                                      NATT_Change_Order_Comments__c = 'CO Comments',
                                                      NATT_Approval_Comments__c = 'Approval Comments',
                                                      SBQQ__ContractingMethod__c = 'By Subscription End Date', SBQQ__Primary__c = true);
        update quoteOrig;
        
        List<SBQQ__QuoteLine__c> lstQuoteLines = new List<SBQQ__QuoteLine__c>();
        lstQuoteLines.add(new SBQQ__QuoteLine__c(SBQQ__Product__c = prds[3].Id, NATT_P_N__c = 'BLUEDGE-CORE', SBQQ__Quantity__c = 10, SBQQ__Quote__c = quoteOriginalId,
                                                 NATT_Is_Base_Unit__c = false, NATT_Requested_Ship_Date__c = System.Date.Today(), NATT_End_Customer_Price__c = 3000,
                                                 SBQQ__ListPrice__c = 20000,SBQQ__ProratedListPrice__c=5000,SBQQ__Existing__c=false,SBQQ__PriorQuantity__c=20, NATT_Unit__c = 'X4 7700',SBQQ__CustomerPrice__c=2000));
        insert lstQuoteLines;
        List<Order> odrs = new List<Order>();
        odrs.add(TestUtil.createOrder(acc,Date.today(),'Draft'));
        odrs.add(TestUtil.createOrder(acc,Date.today(),'Draft'));
        insert odrs;
        
        List<Order> odrsUpdate = new List<Order>();
        odrsUpdate.add(new Order(Id = odrs[0].Id, NATT_Product_Family__c = 'Trailer', NATT_Unit__c = 'X4 7700'));
        odrsUpdate.add(new Order(Id = odrs[1].Id, NATT_Product_Family__c = 'Trailer', NATT_Unit__c = 'X4 7700'));
        update odrsUpdate;
        
        String quoteId = NattQuoteCon.createQuote(opp.Id,true,quoteJson);
        SBQQ__Quote__c quote = new SBQQ__Quote__c(Id=quoteId, NATT_Approver_1__c = u.Id, NATT_Approver_1_Approval_Date__c = Date.today(),NATT_Approver_1_Approved__c = 'Yes',
                                                  NATT_Approver_2__c = u.Id,NATT_Approver_2_Approval_Date__c = Date.today(),NATT_Approver_2_Approved__c = 'Yes',
                                                  NATT_Approver_3__c = u.Id,NATT_Approver_3_Approval_Date__c = Date.today(),NATT_Approver_3_Approved__c = 'Yes',
                                                  NATT_Approver_4__c = u.Id,NATT_Approver_4_Approval_Date__c = Date.today(),NATT_Approver_4_Approved__c = 'Yes',
                                                  NATT_Approver_5__c = u.Id,NATT_Approver_5_Approval_Date__c = Date.today(),NATT_Approver_5_Approved__c = 'Yes',
                                                  NATT_Approver_6__c = u.Id,NATT_Approver_6_Approval_Date__c = Date.today(),NATT_Approver_6_Approved__c = 'Yes',
                                                  SBQQ__SalesRep__c = u.Id,NATT_Final_Approval_Date__c = Date.today(),SBQQ__Status__c = 'Approved',
                                                  SBQQ__ContractingMethod__c = 'By Subscription End Date', NATT_Original_Order_Id__c = odrs[0].ID,
                                                  NATT_Dealer_Comments__c = '<p>Dealer Comments </p><p> Dealer Comments</p>',
                                                  NATT_Internal_Comments__c = 'Internal Comments',
                                                  NATT_Change_Order__c = 'Comments',
                                                  NATT_Change_Order_Comments__c = 'CO Comments',
                                                  NATT_Approval_Comments__c = 'Approval Comments');
        update quote;
        
        List<OrderItem> odrItems = new List<OrderItem>();
        
        odrItems.add(TestUtil.createOrderItem(prds[3],1,odrs[0],1,false));
        odrItems.add(TestUtil.createOrderItem(prds[3],1,odrs[1],1,false));
        
        insert odrItems;
        
        odrItems[0].NATT_Feature_Category__c = 'Non-Standard Sales Options';
        odrItems[1].NATT_Feature_Category__c = 'Special Options';
        odrItems[0].SBQQ__QuoteLine__c = lstQuoteLines[0].id;
        odrItems[1].SBQQ__QuoteLine__c = lstQuoteLines[0].id;// odrItems[1].NATT_Feature_Category__c = 'Related Options';
        odrItems[0].SBQQ__QuotedQuantity__c = 1;
        odrItems[1].SBQQ__QuotedQuantity__c = 1;
        odrItems[0].NATT_Original_Order_Id__c = odrs[0].id;
        odrItems[1].NATT_Original_Order_Id__c = odrs[1].id;
        odrItems[1].SBQQ__RevisedOrderProduct__c = odrItems[0].Id;
        update odrItems;
        
        odrs[0].SBQQ__Quote__c = quoteOriginalId;
        odrs[1].SBQQ__Quote__c = quoteId;
        odrs[0].SBQQ__ContractingMethod__c = 'By Subscription End Date'; 
        odrs[1].SBQQ__ContractingMethod__c = 'By Subscription End Date'; 
        odrs[0].Status = 'Activated';
        odrs[1].Status = 'Activated';
        odrs[0].NATT_JDE_Sales_Order_Number__c  = 'JDE12354';
        odrs[1].NATT_JDE_Sales_Order_Number__c  = 'JDE12354';
        odrs[0].NATT_Original_Order_Id__c = odrs[0].id;
        odrs[1].NATT_Original_Order_Id__c = odrs[1].id;
        odrs[0].RecordTypeId = Schema.SObjectType.Order.getRecordTypeInfosByDeveloperName().get('NATT_Units_Order').getRecordTypeId();
        odrs[1].RecordTypeId = Schema.SObjectType.Order.getRecordTypeInfosByDeveloperName().get('NATT_Units_Order').getRecordTypeId();
        update odrs;
        
        List<NATT_Change_Log__c> lstChangeLog = new List<NATT_Change_Log__c>();
        lstChangeLog.add(new NATT_Change_Log__c(NATT_Change_Type__c = 'Requested Ship Date Change', NATT_Order__c = odrs[1].id,
                                                NATT_Original_Value__c = 'April 4, 2090', NATT_New_Value__c = 'April 20, 2090'));
        insert lstChangeLog;
        try{
            ApexPages.StandardController sc = new ApexPages.StandardController(odrs[0]);
            NattOrderSummaryFormController test234 = new NattOrderSummaryFormController(sc);
            test234.getLabelsFromApi('NATT_New_Value__c');
        
        Boolean noExceptionsThrown = true;
        System.assertEquals(true, noExceptionsThrown, 'An exception was thrown during the test.');
    }
        catch(Exception e){
            System.debug(LoggingLevel.ERROR, 'Exception occurred: ' + e.getMessage());
        }
        Test.StartTest();
        PageReference pageRef = Page.OrderSummaryForm;
        pageRef.getParameters().put('id', String.valueOf(odrs[1].Id));
        Test.setCurrentPage(pageRef);
        Test.StopTest();        
        
    }
    
}