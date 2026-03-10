/*
* NAME         : CustomerSummaryControllerTest
* DESCRIPTION  : Test class of CustomerSummaryController and CustomerSummaryDocumentOnQuoteController controller
*                    
* @AUTHOR : Utkarsh Mishra
* @DATE   : 07-May-2023 
* 
* MODIFICATION LOG:  
* -------------------------------------------------------------------------------------------------------------------------------------------------------------
* DEVELOPER                DATE                DESCRIPTION 
* -------------------------------------------------------------------------------------------------------------------------------------------------------------
*
*
*/
/**
* @description - CustomerSummaryControllerTest class
*/
@IsTest 
public with sharing class CustomerSummaryControllerTest {
    /** 
    * @description - Setup Method to create data. Do not take any thing as argument
    */ 
    @TestSetup
    static void makeData(){
        List<Account> aList = new List<Account>();
        alist.add(new Account(Name='Test Dealer',RecordTypeId=Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('Dealer').getRecordTypeId()));
        aList.add(new Account(Name='Test Dealer2',RecordTypeId=Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('Dealer').getRecordTypeId()));
        insert aList;
        
        List<NATT_Address__c> addList = new List<NATT_Address__c>();
        addList.add(new NATT_Address__c(NATT_Type__c='Billing',NATT_Account__c=aList.get(0).Id,RecordTypeId=Schema.SObjectType.NATT_Address__c.getRecordTypeInfosByDeveloperName().get('NATT_Address').getRecordTypeId()));
        addList.add(new NATT_Address__c(NATT_Type__c='Units Ship To',NATT_Account__c=aList.get(0).Id,RecordTypeId=Schema.SObjectType.NATT_Address__c.getRecordTypeInfosByDeveloperName().get('NATT_Address').getRecordTypeId()));
        insert addList;


        List<Product2> productList = new List<Product2>();
        productList.add(new Product2(Name = 'Product Test',ProductCode = 'xyz',NATT_CoreCharge__c = TRUE,IsActive = TRUE,NATT_Standard_Features__c = 'Fully Hermetic Electric Scroll Compressor'));
        productList.add(new Product2( Name = 'Product Test 2',ProductCode = 'abc',NATT_CoreCharge__c = TRUE,IsActive = TRUE));
        insert productList;


        // SBQQ__ProductOption__c testoption = new SBQQ__ProductOption__c();
        //     testoption.SBQQ__ConfiguredSKU__c = productList.get(0).Name;
        //     testoption.SBQQ__OptionalSKU__c = productList.get(1).Name;
        //     testoption.SBQQ__Feature__c = 'Fuel Tank';
        //     testoption.SBQQ__Feature__c.SBQQ__Category__c = 'Standard Sales Options';
        // insert testoption;


        Id pricebookId = Test.getStandardPricebookId();
        PricebookEntry pbe1 = new PricebookEntry(Product2Id = productList.get(0).Id, pricebook2Id = pricebookId, unitprice=100, isActive=true);
        insert pbe1;
          PricebookEntry pbe2 = new PricebookEntry(Product2Id = productList.get(1).Id, pricebook2Id = pricebookId, unitprice=100, isActive=true);
        insert pbe2;


        
        List<Opportunity> oppList = new List<Opportunity>();
        oppList.add(new Opportunity(Name='UnitsTestOpp',CloseDate=Date.today().addDays(30),StageName='Qualification',AccountId=aList.get(0).Id,RecordTypeId=Schema.SObjectType.Opportunity.getRecordTypeInfosByDeveloperName().get('NATT_Opportunity_Units').getRecordTypeId(),NATT_Stock__c=true,NATT_Billing_Address__c=addList.get(0).Id,NATT_Shipping_Address__c=addList.get(1).Id,Pricebook2Id = pricebookId));        
        insert oppList;

        List<SBQQ__Quote__c> quoteList = new List<SBQQ__Quote__c>();
        quoteList.add(new SBQQ__Quote__c(SBQQ__Account__c = aList.get(0).Id,SBQQ__Opportunity2__c = oppList.get(0).Id,RecordTypeId=Schema.SObjectType.SBQQ__Quote__c.getRecordTypeInfosByDeveloperName().get('NATT_Units_Quote').getRecordTypeId()));
        insert quoteList;

        List<Order> orderList = new List<Order>();
        orderList.add(new Order(AccountId=aList.get(0).Id,OpportunityId=oppList.get(0).Id,EffectiveDate=Date.today().addDays(3),Status='Draft',RecordTypeId=Schema.SObjectType.Order.getRecordTypeInfosByDeveloperName().get('NATT_Parts_Order').getRecordTypeId(),NATT_Billing_Address__c=addList.get(0).Id,NATT_Shipping_Address__c=addList.get(1).Id));
        insert orderList;  
    }

    /** 
    * @description - testGetRecordDetailsQuote
    */
    @IsTest 
    static void testGetRecordDetailsQuote(){ 
        //creating quoteline items records-
        //QL1
        SBQQ__QuoteLine__c qtLine1 = new SBQQ__QuoteLine__c();
        qtLine1.SBQQ__Quote__c = [select id from SBQQ__Quote__c limit 1].Id;
        qtLine1.SBQQ__Product__c = [select id from Product2 limit 2].get(0).Id;
        qtLine1.CONTAINER_Warranty_Description__c = 'Test';
        insert qtLine1;

        //QL2
        SBQQ__QuoteLine__c qtLine2 = new SBQQ__QuoteLine__c();
        qtLine2.SBQQ__Quote__c = [select id from SBQQ__Quote__c limit 1].Id;
        qtLine2.SBQQ__Product__c = [select id from Product2 limit 2].get(1).Id;
        qtLine2.CONTAINER_Warranty_Description__c = 'Test';
        insert qtLine2;

        SBQQ__Quote__c q = [select id from SBQQ__Quote__c limit 1];
        String result = CustomerSummaryController.getRecordDetails(q.Id,  q.Id.getSObjectType().getDescribe().getName());
        System.assert( result!='','Not working');
    }

    /** 
    * @description - testGetRecordDetailsOrder
    */
    @IsTest 
    static void testGetRecordDetailsOrder(){
        Order o = [select id from Order limit 1];
        String result = CustomerSummaryController.getRecordDetails(o.Id,  o.Id.getSObjectType().getDescribe().getName());
        System.assert( result!='','Not working');

    }

    /** 
    * @description - TestupdateRecordQuote
    */
    @IsTest 
    static void testupdateRecordQuote(){
        /*String objectJSON = '{"id" : '+ q.id + ','+
                            '"dealerComment" :'+ dealerComment +'}';*/

        SBQQ__Quote__c q = [select id,NATT_Dealer_Comments__c from SBQQ__Quote__c limit 1];
        string quoteDealerComment = 'Test Dealer Comment1';
        q.NATT_Dealer_Comments__c =quoteDealerComment;        
        
        Order o= [select id,NATT_Dealer_Comments__c from Order limit 1];
        string orderDealerComment = 'Test Dealer Comment2';
        o.NATT_Dealer_Comments__c =orderDealerComment;

        CustomerSummaryController.updateRecord(JSON.serialize(q), 'SBQQ__Quote__c');
        CustomerSummaryController.updateRecord(JSON.serialize(o), 'Order');

        test.startTest();
        SBQQ__Quote__c q1 = [select id,NATT_Dealer_Comments__c from SBQQ__Quote__c limit 1];
        Order o1 = [select id,NATT_Dealer_Comments__c from Order limit 1];
        system.assertEquals(quoteDealerComment, q1.NATT_Dealer_Comments__c,'value of NATT_Dealer_Comments__c Not equal.');
        system.assertEquals(orderDealerComment, o1.NATT_Dealer_Comments__c,'value of NATT_Dealer_Comments__c Not equal.');
        test.stopTest();

    }

    /** 
    * @description - testConstructorForQuote
    */
    @isTest
    public static void testConstructorForQuote() {
        // Create a test quote
        SBQQ__Quote__c testQuote = [select id,Name,NATT_Dealer_Comments__c from SBQQ__Quote__c limit 1];
        string quoteDealerComment = 'Test Dealer Comment1';
        testQuote.NATT_Dealer_Comments__c =quoteDealerComment;        

        // Set up the test page parameters
        ApexPages.currentPage().getParameters().put('id', testQuote.Id);
        ApexPages.currentPage().getParameters().put('objAPI', 'SBQQ__Quote__c');
        
        // Instantiate the controller
        CustomerSummaryDocumentOnQuoteController controller = new CustomerSummaryDocumentOnQuoteController();
        
        // Verify that the recordId and objAPIName properties are set correctly
        System.assertEquals(testQuote.Id, controller.recordId,'recordId not Match');
        System.assertEquals('SBQQ__Quote__c', controller.objAPIName,'objAPIName not Match');
        
        // Verify that the dataOutput property is set correctly
        CustomerSummaryController.DataOutputWrapper dataOutput = (CustomerSummaryController.DataOutputWrapper)JSON.deserialize(CustomerSummaryController.getQuoteRecordDetails(testQuote.Id),CustomerSummaryController.DataOutputWrapper.Class);
        
        // Verify the debug statements
        System.assertEquals(dataOutput.id, testQuote.id,'Id not Match');
        System.assertEquals(dataOutput.quoteNumber, testQuote.Name,'Name not Match');
    }

    /** 
    * @description - testConstructorForOrder
    */
    @isTest
    public static void testConstructorForOrder() {
        // Create a test quote
        SBQQ__Quote__c q = [select id,NATT_Dealer_Comments__c from SBQQ__Quote__c limit 1];
        string quoteDealerComment = 'Test Dealer Comment1';
        q.NATT_Dealer_Comments__c =quoteDealerComment;     

        // Create a test order
        Order o= [select id,NATT_Dealer_Comments__c from Order limit 1];
        string orderDealerComment = 'Test Dealer Comment2';
        o.NATT_Dealer_Comments__c =orderDealerComment;

        // Set up the test page parameters
        ApexPages.currentPage().getParameters().put('id', o.Id);
        ApexPages.currentPage().getParameters().put('objAPI', 'Order');
        
        // Instantiate the controller
        CustomerSummaryDocumentOnQuoteController controller = new CustomerSummaryDocumentOnQuoteController();
        
        // Verify that the recordId and objAPIName properties are set correctly
        System.assertEquals(o.Id, controller.recordId,'recordId not Match');
        System.assertEquals('Order', controller.objAPIName,'objAPIName not Match');
        
        // Verify that the dataOutput property is set correctly
        CustomerSummaryController.DataOutputWrapper dataOutput = (CustomerSummaryController.DataOutputWrapper)JSON.deserialize(CustomerSummaryController.getOrderRecordDetails(o.Id),CustomerSummaryController.DataOutputWrapper.Class);

        // Verify the debug statements
        System.assertEquals(dataOutput.id, o.id,'recordId not Match');
    }
}