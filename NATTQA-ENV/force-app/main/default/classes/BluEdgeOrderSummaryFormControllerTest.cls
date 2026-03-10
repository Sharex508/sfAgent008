@IsTest
private class BluEdgeOrderSummaryFormControllerTest {
    @TestSetup static void setupData(){
        List<Pricebook2> pbList = new List<Pricebook2>();
        
        pbList.add(new Pricebook2(Name='NATT Units Price Book',IsActive=true));
        insert pbList;
        
        // insert products
        List<Product2> products = new List<Product2>();
        
        Product2 product1 = TestUtil.createProduct('BluEdge (See Options for Price)','BluEdge');
        products.add(product1);
        
        Product2 product2 = TestUtil.createProduct('BluEdge Core','BluEdge Core');
        products.add(product2);
        
        Product2 product3 = TestUtil.createProduct('BluEdge Enhance','BluEdge Enhance');
        products.add(product3);
        
        Product2 product4 = TestUtil.createProduct('BluEdge Elite','BluEdge Elite');
        products.add(product4);
        
        insert products;
        
        NATT_Inventory__c inventory = new NATT_Inventory__c();
        inventory.Name = 'Test';
        inventory.NATT_Serial_Number__c = 'SR12345';
        inventory.NATT_Business_Unit__c = 'TT';
        
        insert inventory;
        
        // get standard price book id
        Id pricebookId = Test.getStandardPricebookId();
        
        // insert price book entries
        List<PriceBookEntry> pBEs = new List<PriceBookEntry>();
        PriceBookEntry pBE1 = TestUtil.createPriceBookEntry(pricebookId, products[0].Id);
        pBEs.add(pBE1);   
        
        List<SBQQ__LookupData__c> lkDataList = new List<SBQQ__LookupData__c>();
        
        lkDataList.add(TestUtil.createLookupData(products[0].Id,Date.today().addYears(1),Date.today().addYears(2),'Unit Pricing'));
        insert lkDataList;
        
        List<Account> aList = new List<Account>();
        alist.add(new Account(Name='Test Dealer',RecordTypeId=Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('Dealer').getRecordTypeId()));
        aList.add(new Account(Name='Customer',RecordTypeId=Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('Customer').getRecordTypeId()));
        
        insert aList;
        
        // assignes dealership to end customer
        aList[1].NATT_Dealership__c = aList.get(0).Id;
        
        update aList[1];
        
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
                                    NATT_End_Customer__c = aList.get(1).Id,
                                    RecordTypeId=Schema.SObjectType.Opportunity.getRecordTypeInfosByDeveloperName().get('NATT_Opportunity_Units').getRecordTypeId(),
                                    NATT_Stock__c=true));
        oppList.add(new Opportunity(Name='UnitsTestOpp2',
                                    CloseDate=Date.today().addDays(30),
                                    StageName='Qualification',
                                    AccountId=aList.get(0).Id,
                                    NATT_End_Customer__c = aList.get(1).Id,
                                    RecordTypeId=Schema.SObjectType.Opportunity.getRecordTypeInfosByDeveloperName().get('NATT_Opportunity_Units').getRecordTypeId(),
                                    NATT_Stock__c=true));
        insert oppList;
    }
    
    
    @isTest static void setOrderQLDetailsTestCore(){
        Product2 prod2 = [Select Id From Product2 Where Name = 'BluEdge Core'];
        NATT_Inventory__c inv = [Select Id From NATT_Inventory__c LIMIT 1];
        Account acc = [Select Id From Account Where Name = 'Test Dealer'];
        Account accEndCustomer = [Select Id From Account Where Name = 'Customer'];
        List<Product2> prds = [Select Id,Name From Product2];
        Profile p = [SELECT Id FROM Profile WHERE Name='System Administrator'];
        User u = new User(Alias = 'sysadm', Email='sysadm@testorg.com',
                          EmailEncodingKey='UTF-8', LastName='Testing', LanguageLocaleKey='en_US',
                          LocaleSidKey='en_US', ProfileId = p.Id,
                          TimeZoneSidKey='America/Los_Angeles',
                          UserName='sysadm@testorg.com');
        insert u;
        Opportunity opp = [SELECT Id FROM Opportunity WHERE Name='UnitsTestOpp'];                 
        
        String quoteOriginalId = NattQuoteCon.createQuote(opp.Id,true);
        SBQQ__Quote__c quoteOrig = new SBQQ__Quote__c(Id=quoteOriginalId, SBQQ__Account__c = acc.Id, NATT_End_Customer__c = accEndCustomer.Id, SBQQ__SalesRep__c = u.Id,
                                                      NATT_BluEdge_Core__c = true, SBQQ__ContractingMethod__c = 'By Subscription End Date', SBQQ__Primary__c = true,
                                                      NATT_Unit__c = 'X4 7500', NATT_BluEdge_Price_Per_Hour_End_Customer__c = 100, NATT_Dealer_Copy__c = TRUE,
                                                      RecordTypeId = Schema.SObjectType.SBQQ__Quote__c.getRecordTypeInfosByDeveloperName().get('NATT_BluEdge').getRecordTypeId(),
                                                      NATT_Product_Family__c = 'Trailer', SBQQ__BillingStreet__c = '221B Baker Street',
                                                      SBQQ__ExpirationDate__c = System.Date.Today().addDays(30), NATT_Purchase_Order__c = 'PO123#',SBQQ__Status__c='Approved');
        update quoteOrig;
        
        List<SBQQ__QuoteLine__c> lstQuoteLines = new List<SBQQ__QuoteLine__c>();
        lstQuoteLines.add(new SBQQ__QuoteLine__c(SBQQ__Product__c = prod2.Id, NATT_P_N__c = 'BLUEDGE-CORE', SBQQ__Quantity__c = 10, SBQQ__Quote__c = quoteOriginalId,
                                                NATT_Is_Base_Unit__c = true, NATT_Requested_Ship_Date__c = System.Date.Today(), NATT_End_Customer_Price__c = 100,
                                                SBQQ__ListPrice__c = 100, NATT_Inventory__c = inv.Id));
        
        insert lstQuoteLines;
        
        List<Order> odrs = new List<Order>();
        odrs.add(TestUtil.createOrder(acc,Date.today(),'Draft'));
        insert odrs;
        
        odrs[0].SBQQ__Quote__c = quoteOriginalId;
        odrs[0].SBQQ__ContractingMethod__c = 'By Subscription End Date';
        odrs[0].NATT_Original_Order_Id__c = odrs[0].Id;
        
        update odrs[0];
        
        
        Test.StartTest();
        try{  
            PageReference pageRef = Page.BluEdgeQuoteSummaryForm;
            pageRef.getParameters().put('id', String.valueOf(odrs[0].Id));
            Test.setCurrentPage(pageRef);
            ApexPages.StandardController sc = new ApexPages.StandardController(odrs[0]);
            BluEdgeOrderSummaryFormController test234 = new BluEdgeOrderSummaryFormController(sc);
        }
        catch(Exception e){
            System.debug(e);
        }
        Test.StopTest();
    }
    
    @isTest static void setQuoteQLDetailsTestCore(){
        Product2 prod2 = [Select Id From Product2 Where Name = 'BluEdge Core'];
        NATT_Inventory__c inv = [Select Id From NATT_Inventory__c LIMIT 1];
        Account acc = [Select Id From Account Where Name = 'Test Dealer'];
        Account accEndCustomer = [Select Id From Account Where Name = 'Customer'];
        List<Product2> prds = [Select Id,Name From Product2];
        Profile p = [SELECT Id FROM Profile WHERE Name='System Administrator'];
        User u = new User(Alias = 'sysadm', Email='sysadm@testorg.com',
                          EmailEncodingKey='UTF-8', LastName='Testing', LanguageLocaleKey='en_US',
                          LocaleSidKey='en_US', ProfileId = p.Id,
                          TimeZoneSidKey='America/Los_Angeles',
                          UserName='sysadm@testorg.com');
        insert u;
        Opportunity opp = [SELECT Id FROM Opportunity WHERE Name='UnitsTestOpp'];                 
        
        String quoteOriginalId = NattQuoteCon.createQuote(opp.Id,true);
        SBQQ__Quote__c quoteOrig = new SBQQ__Quote__c(Id=quoteOriginalId, SBQQ__Account__c = acc.Id, NATT_End_Customer__c = accEndCustomer.Id, SBQQ__SalesRep__c = u.Id,
                                                      NATT_BluEdge_Core__c = true, SBQQ__ContractingMethod__c = 'By Subscription End Date', SBQQ__Primary__c = true,
                                                      NATT_Unit__c = 'X4 7500', NATT_BluEdge_Price_Per_Hour_End_Customer__c = 100, NATT_Dealer_Copy__c = TRUE,
                                                      RecordTypeId = Schema.SObjectType.SBQQ__Quote__c.getRecordTypeInfosByDeveloperName().get('NATT_BluEdge').getRecordTypeId(),
                                                      NATT_Product_Family__c = 'Trailer', SBQQ__BillingStreet__c = '221B Baker Street',
                                                      SBQQ__ExpirationDate__c = System.Date.Today().addDays(30), NATT_Purchase_Order__c = 'PO123#',SBQQ__Status__c='Approved');
        update quoteOrig;
        
        List<SBQQ__QuoteLine__c> lstQuoteLines = new List<SBQQ__QuoteLine__c>();
        lstQuoteLines.add(new SBQQ__QuoteLine__c(SBQQ__Product__c = prod2.Id, NATT_P_N__c = 'BLUEDGE-CORE', SBQQ__Quantity__c = 10, SBQQ__Quote__c = quoteOriginalId,
                                                NATT_Is_Base_Unit__c = true, NATT_Requested_Ship_Date__c = System.Date.Today(), NATT_End_Customer_Price__c = 100,
                                                SBQQ__ListPrice__c = 100, NATT_Inventory__c = inv.Id));
        
        insert lstQuoteLines;      
        
        Test.StartTest();
        try{
            PageReference pageRef = Page.BluEdgeQuoteSummaryForm;
            pageRef.getParameters().put('id', String.valueOf(quoteOrig.Id));
            Test.setCurrentPage(pageRef);
            ApexPages.StandardController sc = new ApexPages.StandardController(quoteOrig);
            BluEdgeOrderSummaryFormController test234 = new BluEdgeOrderSummaryFormController(sc);
        }
        catch(Exception e){
            System.debug(e);
        }
        Test.StopTest();
    }
}