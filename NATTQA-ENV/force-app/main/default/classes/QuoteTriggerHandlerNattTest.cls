@IsTest
private class QuoteTriggerHandlerNattTest  {
        
    @TestSetup static void setupData(){
        List<Pricebook2> pbList = new List<Pricebook2>();
        pbList.add(new Pricebook2(Name='NATT Units Price Book',IsActive=true));
        pbList.add(new Pricebook2(Name='NATT Parts Price Book',IsActive=true));
        insert pbList;
         Date shipDate = Date.today();
        
        List<Product2> products = new List<Product2>();
        
        Product2 product1 = TestUtil.createProduct('X4 7700','X4 7700');
        products.add(product1);
        
        Product2 product2 = TestUtil.createProduct('X4 7700','X4 7700');
        products.add(product2);
        
        Product2 product3 = TestUtil.createProduct('BluEdge (See Options for Price)','BluEdge');
        products.add(product3);
        
        Product2 product4 = TestUtil.createProduct('BluEdge Core','BluEdge Core');
        products.add(product4);
        Product2 product5 = TestUtil.createProduct('Vector 8600','Vector 8600');
        products.add(product5);
        insert products;
        
        List<Account> aList = new List<Account>();
        alist.add(new Account(Name='Test Dealer',NATT_Organization__c = 'NATT', NATT_Region__c = 'East',RecordTypeId=Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('Dealer').getRecordTypeId()));
        alist.add(new Account(Name='Test Dealer 2',NATT_Organization__c = 'NATT', NATT_Region__c = 'East',RecordTypeId=Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('Dealer').getRecordTypeId()));
        aList.add(new Account(Name='Test Internal',NATT_Organization__c = 'NATT', NATT_Region__c = 'East',RecordTypeId=Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('Internal').getRecordTypeId()));
        insert aList;
        
        //Account customerAcc = new Account(NATT_Dealership__c = aList[1].Id,Name='Test Customer',NATT_Status__c = 'Active',RecordTypeId=Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('Customer').getRecordTypeId());
        //insert customerAcc;
        
        List<AccountTeamMember> atmList = new List<AccountTeamMember>();
        atmList.add(new AccountTeamMember(AccountId=aList.get(0).Id,UserId=UserInfo.getUserId(),TeamMemberRole='EAM - NATT'));
        atmList.add(new AccountTeamMember(AccountId=aList.get(0).Id,UserId=UserInfo.getUserId(),TeamMemberRole='RD - NATT'));
        atmList.add(new AccountTeamMember(AccountId=aList.get(0).Id,UserId=UserInfo.getUserId(),TeamMemberRole='Director of Sales - NATT'));
        atmList.add(new AccountTeamMember(AccountId=aList.get(1).Id,UserId=UserInfo.getUserId(),TeamMemberRole='EAM - NATT'));
        atmList.add(new AccountTeamMember(AccountId=aList.get(1).Id,UserId=UserInfo.getUserId(),TeamMemberRole='RD - NATT'));
        atmList.add(new AccountTeamMember(AccountId=aList.get(1).Id,UserId=UserInfo.getUserId(),TeamMemberRole='Director of Sales - NATT'));
        insert atmList;
        
        List<NATT_Address__c> addressList = new List<NATT_Address__c>();
        addressList.add(new NATT_Address__c (RecordTypeId = Schema.SObjectType.NATT_Address__c.getRecordTypeInfosByDeveloperName().get('NATT_Address').getRecordTypeId(),
                                             NATT_Type__c = 'Billing', NATT_Account__c = aList[1].Id, Name = 'Billing Address'));
        addressList.add(new NATT_Address__c (RecordTypeId = Schema.SObjectType.NATT_Address__c.getRecordTypeInfosByDeveloperName().get('NATT_Address').getRecordTypeId(),
                                             NATT_Type__c = 'Units Ship To', NATT_Account__c = aList[1].Id, Name = 'Shipping Address'));
        insert addressList;
        
        List<Opportunity> oppList = new List<Opportunity>();
        oppList.add(new Opportunity(NATT_Billing_Address__c = addressList[0].Id, NATT_Shipping_Address__c = addressList[1].Id, Name='UnitsTestOpp',CloseDate=Date.today().addDays(30),StageName='Qualification',AccountId=aList.get(1).Id,RecordTypeId=Schema.SObjectType.Opportunity.getRecordTypeInfosByDeveloperName().get('NATT_Opportunity_Units').getRecordTypeId(),NATT_Stock__c=true));
        oppList.add(new Opportunity(NATT_Billing_Address__c = addressList[0].Id, NATT_Shipping_Address__c = addressList[1].Id, Name='UnitsTestOppInternal',CloseDate=Date.today().addDays(30),StageName='Qualification',AccountId=aList.get(1).Id,RecordTypeId=Schema.SObjectType.Opportunity.getRecordTypeInfosByDeveloperName().get('NATT_Opportunity_Units').getRecordTypeId(),NATT_Stock__c=true));
        insert oppList;
        
        List<Product2> prds = [Select Id,Name From Product2 Where Name = 'BluEdge Core'];       
        Account a = [SELECT Id FROM Account WHERE Name='Test Dealer'];
        Account b = [SELECT Id FROM Account WHERE Name='Test Dealer 2'];
        NattQuoteCon.Wrapper w = NattQuoteCon.getData(a.Id);
        System.assertNotEquals(null, w, 'Wrapper should not be null');
        
        Opportunity opp = [SELECT Id FROM Opportunity WHERE Name='UnitsTestOpp'];
        opp = NattQuoteCon.getOppData(opp.Id);
        System.assertNotEquals(null, opp, 'Opportunity should not be null');
        
        SBQQ__Quote__c quote = new SBQQ__Quote__c(SBQQ__Type__c = 'Amendment', 
        RecordTypeId = Schema.SObjectType.SBQQ__Quote__c.getRecordTypeInfosByDeveloperName().get('NATT_BluEdge').getRecordTypeId(),
        SBQQ__Primary__c = true, SBQQ__Account__c = b.Id, SBQQ__Opportunity2__c = opp.Id);
        insert quote;
        List<Asset> lstAsset = new List<Asset>();
        List<SBQQ__QuoteLine__c> lstQuoteLines = new List<SBQQ__QuoteLine__c>();
        NATT_Inventory__c inv = new NATT_Inventory__c();
            inv.NATT_Original_Price__c = 0;
            inv.NATT_Extended_Warranty_Code__c = quote.Name;
        insert inv;
             
        lstQuoteLines.add(new SBQQ__QuoteLine__c(SBQQ__Product__c = prds[0].Id, NATT_P_N__c = 'BLUEDGE-CORE', SBQQ__Quantity__c = 10, SBQQ__Quote__c = quote.Id,
                                                NATT_Is_Base_Unit__c = true, NATT_Requested_Ship_Date__c = shipDate, NATT_End_Customer_Price__c = 100,
                                                SBQQ__ListPrice__c = 100, NATT_Unit__c = 'X4 7700', NATT_Inventory__c = inv.Id));
        insert lstQuoteLines;
    }

   @IsTest
    static void afterUpdateOriginalPriceUpdate(){
        String uniqueUserName = 'System Admin' + DateTime.now().getTime() + '@testorg.com';
        
        Profile p = [SELECT Id FROM Profile WHERE Name='System Administrator'];
        User u = new User(Alias = 'sysadm', Email='sysadm@testorg.com',
                          EmailEncodingKey='UTF-8', LastName='Testing', LanguageLocaleKey='en_US',
                          LocaleSidKey='en_US', ProfileId = p.Id,
                          TimeZoneSidKey='America/Los_Angeles',
                          UserName='sysadm@testorg.com');
        
        
       
        System.runAs(u) {
            Account a = [SELECT Id FROM Account WHERE Name='Test Dealer'];
            NattQuoteCon.Wrapper w = NattQuoteCon.getData(a.Id);
            System.assertNotEquals(null, w, 'Wrapper should not be null');
            Opportunity opp = [SELECT Id FROM Opportunity WHERE Name='UnitsTestOpp'];
            opp = NattQuoteCon.getOppData(opp.Id);
            System.assertNotEquals(null, opp, 'Opportunity should not be null');
            string quoteJSON = '{"MarkForCountry": "US","MarkForState": "TX","MarkForCity": "rythu","poNumber": "123","hasFreight":true}';
            Id quoteId = NattQuoteCon.createQuote(opp.Id,true,quoteJSON);
            System.assertNotEquals(null, quoteId, 'Quote ID should not be null after creation');
            
            SBQQ__Quote__c quote = new SBQQ__Quote__c(Id=quoteId,SBQQ__Status__c='Draft');
            update quote;
            //quote.RecordTypeId = Schema.SObjectType.SBQQ__Quote__c.getRecordTypeInfosByName().get('NATT BluEdge').getRecordTypeId();
            //update quote;
            quote.SBQQ__Status__c = 'Approved';
            update quote;
            
            system.debug([Select Id,SBQQ__Status__c,NATT_Quote_Record_Type_Developer_Name__c from SBQQ__Quote__c]);
        }
    }
    
     @IsTest
    static void buildShareFromApproverTest(){
        String uniqueUserName = 'System Admin' + DateTime.now().getTime() + '@testorg.com';
        
        Profile p = [SELECT Id FROM Profile WHERE Name='System Administrator'];
        User u = new User(Alias = 'sysadm', Email='sysadm@testorg.com',
                          EmailEncodingKey='UTF-8', LastName='Testing', LanguageLocaleKey='en_US',
                          LocaleSidKey='en_US', ProfileId = p.Id,
                          TimeZoneSidKey='America/Los_Angeles',
                          UserName='sysadm@testorg.com');
        
        
       
        System.runAs(u) {
            Account a = [SELECT Id FROM Account WHERE Name='Test Dealer'];
            NattQuoteCon.Wrapper w = NattQuoteCon.getData(a.Id);
            System.assertNotEquals(null, w, 'Wrapper should not be null');
            Opportunity opp = [SELECT Id FROM Opportunity WHERE Name='UnitsTestOpp'];
            opp = NattQuoteCon.getOppData(opp.Id);
            System.assertNotEquals(null, opp, 'Opportunity should not be null');
            string quoteJSON = '{"MarkForCountry": "US","MarkForState": "TX","MarkForCity": "rythu","poNumber": "123","hasFreight":true}';
            Id quoteId = NattQuoteCon.createQuote(opp.Id,true,quoteJSON);
            System.assertNotEquals(null, quoteId, 'Quote ID should not be null after creation');
            
           // List <SBQQ__Quote__c> quoteList = new List <SBQQ__Quote__c>();
            List<SBQQ__Quote__c> quotes = [Select id,NATT_Approver_1__c,NATT_Approver_2__c,NATT_Approver_3__c,
                                           NATT_Approver_4__c,NATT_Approver_5__c,NATT_Approver_6__c from SBQQ__Quote__c];
            QuoteTriggerHandlerNATT.buildShareFromApprover(quotes,null);
            
            
     
            
            //system.debug([Select Id,SBQQ__Status__c,NATT_Quote_Record_Type_Developer_Name__c from SBQQ__Quote__c]);
        }
    }
         @IsTest
    static void updateOpportunityRequestedShipDateTest(){
        String uniqueUserName = 'System Admin' + DateTime.now().getTime() + '@testorg.com';
        
        Profile p = [SELECT Id FROM Profile WHERE Name='System Administrator'];
        User u = new User(Alias = 'sysadm', Email='sysadm@testorg.com',
                          EmailEncodingKey='UTF-8', LastName='Testing', LanguageLocaleKey='en_US',
                          LocaleSidKey='en_US', ProfileId = p.Id,
                          TimeZoneSidKey='America/Los_Angeles',
                          UserName='sysadm@testorg.com');
        
        
       
        System.runAs(u) {
            Account a = [SELECT Id FROM Account WHERE Name='Test Dealer'];
            NattQuoteCon.Wrapper w = NattQuoteCon.getData(a.Id);
            System.assertNotEquals(null, w, 'Wrapper should not be null');
            Opportunity opp = [SELECT Id FROM Opportunity WHERE Name='UnitsTestOpp'];
            opp = NattQuoteCon.getOppData(opp.Id);
            System.assertNotEquals(null, opp, 'Opportunity should not be null');
            string quoteJSON = '{"MarkForCountry": "US","MarkForState": "TX","MarkForCity": "rythu","poNumber": "123","hasFreight":true}';
            Id quoteId = NattQuoteCon.createQuote(opp.Id,true,quoteJSON);
            System.assertNotEquals(null, quoteId, 'Quote ID should not be null after creation');
            Opportunity opt = [Select Id,name from Opportunity limit 1];
            Account acc = [Select Id,name from Account limit 1];
            SBQQ__Quote__c qte = [select Id,name from SBQQ__Quote__c limit 1];
            
			SBQQ__Quote__c quoteOld = new SBQQ__Quote__c(Id = qte.Id,SBQQ__Type__c = 'Amendment', 
            SBQQ__Ordered__c = false,                                          
        	RecordTypeId = Schema.SObjectType.SBQQ__Quote__c.getRecordTypeInfosByDeveloperName().get('NATT_Direct_Sales').getRecordTypeId(),
        	SBQQ__Primary__c = true, SBQQ__Account__c = acc.Id, SBQQ__Opportunity2__c = opt.Id);          
            
            SBQQ__Quote__c quoteNew = new SBQQ__Quote__c(Id = qte.Id,SBQQ__Type__c = 'Amendment', SBQQ__Source__c = opt.Id,
                                                         
            SBQQ__Ordered__c = true,                                          
        	RecordTypeId = Schema.SObjectType.SBQQ__Quote__c.getRecordTypeInfosByDeveloperName().get('NATT_Direct_Sales').getRecordTypeId(),
        	SBQQ__Primary__c = true, SBQQ__Account__c = acc.Id, SBQQ__Opportunity2__c = opt.Id);  
     		
            QuoteTriggerHandlerNATT.updateOpportunityRequestedShipDate(new List<SBQQ__Quote__c> {quoteNew},new Map<Id,SBQQ__Quote__c> {qte.Id => quoteOld});
            
            //system.debug([Select Id,SBQQ__Status__c,NATT_Quote_Record_Type_Developer_Name__c from SBQQ__Quote__c]);
        }
    }
    
   /* @IsTest
    static void externalCreation(){
               
        Account a = [SELECT Id FROM Account WHERE Name='Test Dealer'];
        Account b = [SELECT Id FROM Account WHERE Name='Test Dealer 2'];
        NattQuoteCon.Wrapper w = NattQuoteCon.getData(a.Id);
         System.assertNotEquals(null, w, 'Wrapper should not be null');
        Opportunity opp = [SELECT Id FROM Opportunity WHERE Name='UnitsTestOpp'];
        opp = NattQuoteCon.getOppData(opp.Id);
        System.assertNotEquals(null, opp, 'Opportunity should not be null');
        
        string quoteJSON = '{"MarkForCountry": "US","MarkForState": "TX","MarkForCity": "rythu","poNumber": "123","hasFreight":true}';

        Id quoteId = NattQuoteCon.createQuote(opp.Id,true,quoteJSON);
         System.assertNotEquals(null, quoteId, 'Quote ID should not be null after creation');
        SBQQ__Quote__c quote = new SBQQ__Quote__c(Id=quoteId, SBQQ__Account__c = b.Id);
        update quote;
        
        SBQQ__Quote__c quote2 = new SBQQ__Quote__c(Id=quoteId,SBQQ__Status__c='Pending Approval');
        update quote2;
        
        SBQQ__Quote__c quote3 = new SBQQ__Quote__c(SBQQ__Type__c = 'Amendment', 
        RecordTypeId = Schema.SObjectType.SBQQ__Quote__c.getRecordTypeInfosByDeveloperName().get('NATT_Units_Quote').getRecordTypeId(),
        SBQQ__Primary__c = true, SBQQ__Account__c = b.Id, SBQQ__Opportunity2__c = opp.Id);
        insert quote3;
        
        SBQQ__Quote__c quote4 = new SBQQ__Quote__c(Id=quote3.Id,SBQQ__Status__c='Approved',NATT_Approver_1_Approved__c = 'Yes');
        update quote4;
        
        delete quote;
        
    }*/
    
    @IsTest
    static void externalCreationBluEdge(){
        SBQQ__Quote__c quote = [Select Id From SBQQ__Quote__c LIMIT 1];
        
        test.startTest();
        SBQQ__Quote__c quote2 = new SBQQ__Quote__c(Id=quote.Id,SBQQ__Status__c='Approved',NATT_Approver_1_Approved__c = 'Yes');
        update quote2;
        
        delete quote;
        test.stopTest();
        
    }
    
  /* @IsTest
    static void internalCreation(){
        
        Account a = [SELECT Id FROM Account WHERE Name='Test Internal'];
        NattQuoteCon.Wrapper w = NattQuoteCon.getData(a.Id);
        System.assertNotEquals(null, w, 'Wrapper should not be null');
        Opportunity opp = [SELECT Id FROM Opportunity WHERE Name='UnitsTestOppInternal'];
        opp = NattQuoteCon.getOppData(opp.Id);
        System.assertNotEquals(null, opp, 'Opportunity should not be null');
                string quoteJSON = '{"MarkForCountry": "US","MarkForState": "TX","MarkForCity": "rythu","poNumber": "123","hasFreight":true}';

        Id quoteId = NattQuoteCon.createQuote(opp.Id,true,quoteJSON);
         System.assertNotEquals(null, quoteId, 'Quote ID should not be null after creation');
        SBQQ__Quote__c quote = new SBQQ__Quote__c(Id=quoteId,SBQQ__Status__c='Pending Approval',SBQQ__Account__c=null);
        update quote;
    }*/
    
    @IsTest
    static void testClone(){
        Account a = [SELECT Id FROM Account WHERE Name='Test Internal'];
        NattQuoteCon.Wrapper w = NattQuoteCon.getData(a.Id);
         System.assertNotEquals(null, w, 'Wrapper should not be null');
        Opportunity opp = [SELECT Id FROM Opportunity WHERE Name='UnitsTestOppInternal'];
        opp = NattQuoteCon.getOppData(opp.Id);
        System.assertNotEquals(null, opp, 'Opportunity should not be null');
        string quoteJSON = '{"MarkForCountry": "US","MarkForState": "TX","MarkForCity": "rythu","poNumber": "123","hasFreight":true}';

        Id quoteId = NattQuoteCon.createQuote(opp.Id,true,quoteJSON);
         System.assertNotEquals(null, quoteId, 'Quote ID should not be null after creation');
        SBQQ__Quote__c quote = [SELECT Id,Name,SBQQ__Opportunity2__c,SBQQ__Account__c,RecordTypeId FROM SBQQ__Quote__c WHERE Id=:quoteId];
        
        SBQQ__Quote__c qClone = quote.clone();
        System.assertEquals(true,qClone.isClone());
        insert qClone;
    }
    
    @IsTest
    static void coverageChangeLog(){
        SBQQ__Quote__c quote = [Select Id From SBQQ__Quote__c LIMIT 1];
        
        SBQQ__Quote__c quote3 = new SBQQ__Quote__c(Id=quote.Id,SBQQ__Status__c='Approved',NATT_Approver_1_Approved__c = 'Yes', SBQQ__Type__c = 'Amendment', 
        RecordTypeId = Schema.SObjectType.SBQQ__Quote__c.getRecordTypeInfosByDeveloperName().get('NATT_Units_Quote_Amendment').getRecordTypeId(),
        SBQQ__Primary__c = true, NATT_Number_of_Price_Rule_Updates__c = 1);
        update quote3;
         
        
         
        delete quote;
        
    }
    @IsTest
    static void coverageChangeLog2(){
        SBQQ__Quote__c quote = [Select Id From SBQQ__Quote__c LIMIT 1];
        
        SBQQ__Quote__c quote3 = new SBQQ__Quote__c(Id=quote.Id,SBQQ__Status__c='Pending Approval',NATT_Approver_1_Approved__c = 'Yes', SBQQ__Type__c = 'Amendment', 
        RecordTypeId = Schema.SObjectType.SBQQ__Quote__c.getRecordTypeInfosByDeveloperName().get('NATT_Units_Quote_Amendment').getRecordTypeId(),
        SBQQ__Primary__c = true, NATT_Number_of_Price_Rule_Updates__c = 1);
        try{
        update quote3;
        }
        catch(exception e){
            system.debug('Error-'+e);
        }
        
         String uniqueUserName = 'System Admin' + DateTime.now().getTime() + '@testorg.com';
        
        Profile p = [SELECT Id FROM Profile WHERE Name='System Administrator'];
        User u = new User(Alias = 'sysadm', Email='sysadm@testorg.com',
                          EmailEncodingKey='UTF-8', LastName='Testing', LanguageLocaleKey='en_US',
                          LocaleSidKey='en_US', ProfileId = p.Id,
                          TimeZoneSidKey='America/Los_Angeles',
                          UserName='sysadm@testorg.com');
        
         
       
        System.runAs(u) {
            Account a = [SELECT Id FROM Account WHERE Name='Test Dealer'];
            NattQuoteCon.Wrapper w = NattQuoteCon.getData(a.Id);
            System.assertNotEquals(null, w, 'Wrapper should not be null');
            Opportunity opp = [SELECT Id FROM Opportunity WHERE Name='UnitsTestOpp'];
            opp = NattQuoteCon.getOppData(opp.Id);
            System.assertNotEquals(null, opp, 'Opportunity should not be null');
            string quoteJSON = '{"MarkForCountry": "US","MarkForState": "TX","MarkForCity": "rythu","poNumber": "123","hasFreight":true}';
            Id quoteId = NattQuoteCon.createQuote(opp.Id,true,quoteJSON);
            System.assertNotEquals(null, quoteId, 'Quote ID should not be null after creation');
            
            List<Order> odrs = new List<Order>();
        odrs.add(TestUtil.createOrder(a,Date.today(),'Draft'));
        insert odrs;
        
         List<Order> odrsUpdate = new List<Order>();
        odrsUpdate.add(new Order(Id = odrs[0].Id, NATT_Product_Family__c = 'Trailer', NATT_Unit__c = 'X4 7700'));
        update odrsUpdate;
            
            SBQQ__Quote__c quotee = new SBQQ__Quote__c(Id=quoteId,SBQQ__Status__c='Draft');
            update quotee;
            quotee.RecordTypeId = Schema.SObjectType.SBQQ__Quote__c.getRecordTypeInfosByDeveloperName().get('NATT_Units_Quote_Amendment').getRecordTypeId();
            quotee.SBQQ__Status__c = 'Pending Approval';
            quotee.SBQQ__Type__c = 'Amendment';
            quotee.NATT_Approver_6__c = userInfo.getUserId();
            quotee.NATT_Original_Order_Id__c = odrsUpdate[0].id ;
            try{
                update quotee;
            }
            catch(exception e){
                system.debug('Error-'+e);
            }
            
            
            
            system.debug([Select Id,SBQQ__Status__c,NATT_Quote_Record_Type_Developer_Name__c from SBQQ__Quote__c]);
        }
         
        delete quote;
        
    }
@IsTest
    static void afterUpdateOriginalPriceUpdate2(){
        String uniqueUserName = 'System Admin' + DateTime.now().getTime() + '@testorg.com';
        
        Profile p = [SELECT Id FROM Profile WHERE Name='System Administrator'];
        User u = new User(Alias = 'sysad', Email='sysadm2@testorg.com',
                          EmailEncodingKey='UTF-8', LastName='Testing', LanguageLocaleKey='en_US',
                          LocaleSidKey='en_US', ProfileId = p.Id,
                          TimeZoneSidKey='America/Los_Angeles',
                          UserName='sysadm2@testorg.com');
        
        
       
        System.runAs(u) {
            Account a = [SELECT Id FROM Account WHERE Name='Test Dealer'];
            NattQuoteCon.Wrapper w = NattQuoteCon.getData(a.Id);
            System.assertNotEquals(null, w, 'Wrapper should not be null');
            Opportunity opp = [SELECT Id FROM Opportunity WHERE Name='UnitsTestOpp'];
            opp = NattQuoteCon.getOppData(opp.Id);
            System.assertNotEquals(null, opp, 'Opportunity should not be null');
            string quoteJSON = '{"MarkForCountry": "US","MarkForState": "TX","MarkForCity": "rythu","poNumber": "123","hasFreight":true}';
            Id quoteId = NattQuoteCon.createQuote(opp.Id,true,quoteJSON);
            System.assertNotEquals(null, quoteId, 'Quote ID should not be null after creation');
            //Product2 prod = [Select Id,name from Product2 where name = 'X4 7700'];
            SBQQ__Quote__c quote = new SBQQ__Quote__c(Id=quoteId,SBQQ__Status__c='Draft'); 
            update quote;
            quote.RecordTypeId = Schema.SObjectType.SBQQ__Quote__c.getRecordTypeInfosByDeveloperName().get('MX_Units_Quote').getRecordTypeId();
            quote.SBQQ__Status__c = 'Pending Approval';
            quote.NATT_Approver_1__c = userInfo.getUserId();
            quote.NATT_Approver_2__c = userInfo.getUserId();
            quote.NATT_Approver_3__c = userInfo.getUserId();
            quote.NATT_Approver_4__c = userInfo.getUserId();
            quote.NATT_Approver_5__c = userInfo.getUserId();
            quote.NATT_Approver_6__c = userInfo.getUserId();
            //quote.SBQQ__Product__c = prod.Id;
            quote.NATT_Unit__c = 'X4 7700';
            //update quote;
            
            system.debug([Select Id,SBQQ__Status__c,NATT_Quote_Record_Type_Developer_Name__c from SBQQ__Quote__c]);
        }
    }
    /*   @IsTest
    static void unitQuote(){
        String uniqueUserName = 'System Admin' + DateTime.now().getTime() + '@testorg.com';
        
        Profile p = [SELECT Id FROM Profile WHERE Name='System Administrator'];
        User u = new User(Alias = 'sysadm', Email='sysadm@testorg.com',
                          EmailEncodingKey='UTF-8', LastName='Testing', LanguageLocaleKey='en_US',
                          LocaleSidKey='en_US', ProfileId = p.Id,
                          TimeZoneSidKey='America/Los_Angeles',
                          UserName='sysadm@testorg.com');
        
        
       
        System.runAs(u) {
            Account a = [SELECT Id FROM Account WHERE Name='Test Dealer'];
            NattQuoteCon.Wrapper w = NattQuoteCon.getData(a.Id);
            System.assertNotEquals(null, w, 'Wrapper should not be null');
            Opportunity opp = [SELECT Id FROM Opportunity WHERE Name='UnitsTestOpp'];
            opp = NattQuoteCon.getOppData(opp.Id);
            System.assertNotEquals(null, opp, 'Opportunity should not be null');
            string quoteJSON = '{"MarkForCountry": "US","MarkForState": "TX","MarkForCity": "rythu","poNumber": "123","hasFreight":true}';
            Id quoteId = NattQuoteCon.createQuote(opp.Id,true,quoteJSON);
            System.assertNotEquals(null, quoteId, 'Quote ID should not be null after creation');
            
            SBQQ__Quote__c quote = new SBQQ__Quote__c(Id=quoteId,SBQQ__Status__c='Draft');
            
            quote.RecordTypeId = Schema.SObjectType.SBQQ__Quote__c.getRecordTypeInfosByDeveloperName().get('NATT_Units_Quote').getRecordTypeId();
            update quote;
            quote.SBQQ__Status__c = 'Pending Approval';
            update quote;
            
            system.debug([Select Id,SBQQ__Status__c,NATT_Quote_Record_Type_Developer_Name__c from SBQQ__Quote__c]);
        }
    }
   // Added by Rajasekhar for CCRN:2631
    @isTest static void myUnitTest1(){
        Account a = [SELECT Id FROM Account WHERE Name='Test Dealer'];
        NattQuoteCon.Wrapper w = NattQuoteCon.getData(a.Id);
        string qteRecTypeID = Schema.SobjectType.SBQQ__Quote__c.getRecordTypeInfosByDeveloperName().get('MX_Units_Quote').getRecordTypeId();
        Opportunity opp = [SELECT Id FROM Opportunity WHERE Name='TestUnitsOpp'];
        opp = NattQuoteCon.getOppData(opp.Id);  
        string QuoteJSON = '{"SBQQ__Status__c":"Draft"}';
        //string QuoteJSON = '{"MarkForCountry": "US","MarkForState": "TX","MarkForCity": "rythu","poNumber": "123","hasFreight":true, "RecordypeId":'+qteRecTypeID +'}';
        
        NattQuoteCon.createQuote(opp.Id,true,QuoteJSON);
        
        Pricebook2 pb = [Select Id From Pricebook2 Where Name = 'NATT Units Price Book'];
        
        //List<PriceBookEntry> pbes = [Select Id,Product2Id From PriceBookEntry Where PriceBook2Id =:pb.Id];
        
        // insert quote lines
        List<SBQQ__QuoteLine__c> quoteLineList = new List<SBQQ__QuoteLine__c>();
        SBQQ__Quote__c quoteRec = [select id,SBQQ__Status__c from SBQQ__Quote__c where SBQQ__Status__c = 'Draft' and SBQQ__Opportunity2__c =:opp.Id limit 1 ];
        
        List<Product2> product2List = new List<Product2>();
        Product2 prod = new Product2(
            Name='Vector 8600 - System 01',
            ProductCode='Vector 8600 - System 01',
            Family = 'Trailer'
        );
        product2List.add(prod);
        insert product2List;
        
        //SBQQ__QuoteLine__c quoteLine = TestUtil.createQuoteLine(pbes[0].product2List.id, quoteRec.Id);
        
        SBQQ__QuoteLine__c quoteLine = TestUtil.createQuoteLine(product2List[0].id, quoteRec.Id);
        quoteLine.SBQQ__Product__c = product2List[0].id;
        quoteLineList.add(quoteLine);
        upsert quoteLine;
        NATT_Approval_Process__c approvalProcess = new NATT_Approval_Process__c(
            //Name = 'AP-0000',
            Product_Name__c = product2List[0].id,
            //Product_Family__c = 'Trailer',
            Approval_Object__c = 'SBQQ__Quote__c',
            Business_Type__c = 'NATT',
            Business_Sub_Type__c = 'Units Quote',
            Margin_EAM_Lower_Bound__c = 38,
            Margin_RD_Lower_Bound__c = 36,
            Margin_DOS_Lower_Bound__c = 35,
            Margin_Sales_Ops_Lower_Bound__c = 0,
            Margin_VP_or_CFO_Lower_Bound__c = 58,
            Margin_EAM_Upper_Bound__c = 36,
            Margin_RD_Upper_Bound__c = 38,
            Margin_DOS_Upper_Bound__c = 36,
            Margin_Sales_Ops_Upper_Bound__c = 35,
            Margin_VP_of_CFO_Upper_Bound__c = 85
        );
        insert approvalProcess;
        quoteRec.SBQQ__Status__c='Pending Approval';
        quoteRec.NATT_Unit__c='Vector 8600 - System 01';
        try{
            update quoteRec;
        }
        catch(exception e){
            system.debug('Error-'+ e);
        }
        
    }*/
}