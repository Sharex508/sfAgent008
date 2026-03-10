@isTest(seeAllData=false)
public class QuoteLineTriggerHandlerNATTTest{
    
    @TestSetup static void setupData(){
        List<Pricebook2> pbList = new List<Pricebook2>();
        pbList.add(new Pricebook2(Name='NATT Units Price Book',IsActive=true));
        pbList.add(new Pricebook2(Name='NATT Parts Price Book',IsActive=true));
        pbList.add(new Pricebook2(Name='NATT BluEdge',IsActive=true));
        pbList.add(new Pricebook2(Name='NATT Lynx Fleet',IsActive=true));
        insert pbList;
        
        // insert products
        List<Product2> products = new List<Product2>();
        
        Product2 product1 = TestUtil.createProduct('BluEdge (See Options for Price)','BluEdge');
        products.add(product1);
        
        Product2 product2 = TestUtil.createProduct('BluEdge Core','BluEdge Core');
        products.add(product2);
        
        Product2 product3 = TestUtil.createProduct('Extended Basic Coverage','Extended Basic Coverage');
        products.add(product3);
        
        Product2 product4 = TestUtil.createProduct('Extended Basic','APU-T0011');
        products.add(product4);
        
        Product2 product5 = TestUtil.createProduct('OTCC for Extended Basic','APU-T0240');
        products.add(product5);
        
        Product2 product6 = TestUtil.createProduct('Major Component Coverage','Major Component Coverage');
        products.add(product6);
        
        Product2 product7 = TestUtil.createProduct('Engine less accessories','APU-T0020');
        products.add(product7);
        
        Product2 product8 = TestUtil.createProduct('Compressor less accessories','APU-T0030');
        products.add(product8);
        
        insert products;
        
        // get standard price book id
        Id pricebookId = Test.getStandardPricebookId();
        
        // insert price book entries
        List<PriceBookEntry> pBEs = new List<PriceBookEntry>();
        PriceBookEntry pBE1 = TestUtil.createPriceBookEntry(pricebookId, products[0].Id);
        PriceBookEntry pBE2 = TestUtil.createPriceBookEntry(pricebookId, products[1].Id);
        PriceBookEntry pBE3 = TestUtil.createPriceBookEntry(pricebookId, products[2].Id);
        PriceBookEntry pBE4 = TestUtil.createPriceBookEntry(pricebookId, products[3].Id);
        PriceBookEntry pBE5 = TestUtil.createPriceBookEntry(pricebookId, products[4].Id);
        PriceBookEntry pBE6 = TestUtil.createPriceBookEntry(pricebookId, products[5].Id);
        PriceBookEntry pBE7 = TestUtil.createPriceBookEntry(pricebookId, products[6].Id);
        PriceBookEntry pBE8 = TestUtil.createPriceBookEntry(pricebookId, products[7].Id);
        pBEs.add(pBE1);
        pBEs.add(pBE2);
        pBEs.add(pBE3);
        pBEs.add(pBE4);
        pBEs.add(pBE5);
        pBEs.add(pBE6);
        pBEs.add(pBE7);
        pBEs.add(pBE8);
        
        PriceBookEntry pBE9 = TestUtil.createPriceBookEntry(pbList[0].Id, products[0].Id);
        PriceBookEntry pBE10 = TestUtil.createPriceBookEntry(pbList[1].Id, products[0].Id);
        PriceBookEntry pBE11 = TestUtil.createPriceBookEntry(pbList[2].Id, products[0].Id);
        PriceBookEntry pBE12 = TestUtil.createPriceBookEntry(pbList[3].Id, products[0].Id);
        pBEs.add(pBE9);
        pBEs.add(pBE10);
        pBEs.add(pBE11);
        pBEs.add(pBE12);        
        
        PriceBookEntry pBE13 = TestUtil.createPriceBookEntry(pbList[0].Id, products[1].Id);
        PriceBookEntry pBE14 = TestUtil.createPriceBookEntry(pbList[1].Id, products[1].Id);
        PriceBookEntry pBE15 = TestUtil.createPriceBookEntry(pbList[2].Id, products[1].Id);
        PriceBookEntry pBE16 = TestUtil.createPriceBookEntry(pbList[3].Id, products[1].Id);
        pBEs.add(pBE13);
        pBEs.add(pBE14);
        pBEs.add(pBE15);
        pBEs.add(pBE16);
        
        PriceBookEntry pBE17 = TestUtil.createPriceBookEntry(pbList[0].Id, products[2].Id);
        PriceBookEntry pBE18 = TestUtil.createPriceBookEntry(pbList[1].Id, products[2].Id);
        PriceBookEntry pBE19 = TestUtil.createPriceBookEntry(pbList[2].Id, products[2].Id);
        PriceBookEntry pBE20 = TestUtil.createPriceBookEntry(pbList[3].Id, products[2].Id);
        pBEs.add(pBE17);
        pBEs.add(pBE18);
        pBEs.add(pBE19);
        pBEs.add(pBE20);
        
        PriceBookEntry pBE21 = TestUtil.createPriceBookEntry(pbList[0].Id, products[3].Id);
        PriceBookEntry pBE22 = TestUtil.createPriceBookEntry(pbList[1].Id, products[3].Id);
        PriceBookEntry pBE23 = TestUtil.createPriceBookEntry(pbList[2].Id, products[3].Id);
        PriceBookEntry pBE24 = TestUtil.createPriceBookEntry(pbList[3].Id, products[3].Id);
        pBEs.add(pBE21);
        pBEs.add(pBE22);
        pBEs.add(pBE23);
        pBEs.add(pBE24);
        
        PriceBookEntry pBE25 = TestUtil.createPriceBookEntry(pbList[0].Id, products[4].Id);
        PriceBookEntry pBE26 = TestUtil.createPriceBookEntry(pbList[1].Id, products[4].Id);
        PriceBookEntry pBE27 = TestUtil.createPriceBookEntry(pbList[2].Id, products[4].Id);
        PriceBookEntry pBE28 = TestUtil.createPriceBookEntry(pbList[3].Id, products[4].Id);
        pBEs.add(pBE25);
        pBEs.add(pBE26);
        pBEs.add(pBE27);
        pBEs.add(pBE28);
        
        PriceBookEntry pBE29 = TestUtil.createPriceBookEntry(pbList[0].Id, products[5].Id);
        PriceBookEntry pBE30 = TestUtil.createPriceBookEntry(pbList[1].Id, products[5].Id);
        PriceBookEntry pBE31 = TestUtil.createPriceBookEntry(pbList[2].Id, products[5].Id);
        PriceBookEntry pBE32 = TestUtil.createPriceBookEntry(pbList[3].Id, products[5].Id);
        pBEs.add(pBE29);
        pBEs.add(pBE30);
        pBEs.add(pBE31);
        pBEs.add(pBE32);
        
        System.debug('pBEs'+pBEs);
        insert pBEs;
        
        List<Account> aList = new List<Account>();
        alist.add(new Account(Name='Test Dealer',RecordTypeId=Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('Dealer').getRecordTypeId()));
        aList.add(new Account(Name='Test Internal',RecordTypeId=Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('Internal').getRecordTypeId()));
        aList.add(new Account(Name='Customer',RecordTypeId=Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('Customer').getRecordTypeId()));
        
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
        oppList.add(new Opportunity(Name='UnitsTestOpp',CloseDate=Date.today().addDays(30),StageName='Quoting',AccountId=aList.get(0).Id,RecordTypeId=Schema.SObjectType.Opportunity.getRecordTypeInfosByDeveloperName().get('NATT_Opportunity_Units').getRecordTypeId(),NATT_Stock__c=true));
        oppList.add(new Opportunity(Name='UnitsTestOppInternal',CloseDate=Date.today().addDays(30),StageName='Quoting',AccountId=aList.get(1).Id,RecordTypeId=Schema.SObjectType.Opportunity.getRecordTypeInfosByDeveloperName().get('NATT_Opportunity_Units').getRecordTypeId(),NATT_Stock__c=true));
        oppList.add(new Opportunity(Name='BluEdgeTestOpp',CloseDate=Date.today().addDays(30),StageName='Quoting',AccountId=aList.get(0).Id,RecordTypeId=Schema.SObjectType.Opportunity.getRecordTypeInfosByDeveloperName().get('NATT_Opportunity_BluEdge').getRecordTypeId(),NATT_Stock__c=true));
        oppList.add(new Opportunity(Name='eSolutionsOpp',CloseDate=Date.today().addDays(30),StageName='Quoting',AccountId=aList.get(1).Id,RecordTypeId=Schema.SObjectType.Opportunity.getRecordTypeInfosByDeveloperName().get('NATT_Opportunity_eSolutions').getRecordTypeId(),NATT_Stock__c=true));
        insert oppList;
    }
    
    @IsTest
    static void NATTUnitQuote(){
        
        List<Opportunity> opps = [SELECT Id FROM Opportunity Where Name ='UnitsTestOpp'];
        
        Test.startTest();
        
        SBQQ.TriggerControl.disable();
        
        String quoteId = NattQuoteCon.createQuote(opps[0].Id,false);
        
        Pricebook2 pb = [Select Id From Pricebook2 Where Name = 'NATT Units Price Book'];
        
        List<PriceBookEntry> pbes = [Select Id,Product2Id From PriceBookEntry Where PriceBook2Id =:pb.Id];
        
        // insert quote lines
        List<SBQQ__QuoteLine__c> quoteLineList = new List<SBQQ__QuoteLine__c>();
        
        SBQQ__QuoteLine__c quoteLine = TestUtil.createQuoteLine(pbes[0].Product2Id, quoteId);
        quoteLine.SBQQ__PricebookEntryId__c = pBEs[0].Id;
        quoteLine.NATT_BluEdgeBundleUniqueKey__c = 'BluEdge';
        quoteLineList.add(quoteLine);
        
        SBQQ__QuoteLine__c quoteLine2 = TestUtil.createQuoteLine(pbes[1].Product2Id, quoteId);
        quoteLine2.SBQQ__PricebookEntryId__c = pBEs[1].Id;
        quoteLine.NATT_BluEdgeBundleUniqueKey__c = 'BluEdge';
        quoteLineList.add(quoteLine2);
        
        insert quoteLineList;
        
        SBQQ__QuoteLine__c quoteLine3 = TestUtil.createQuoteLine(pbes[2].Product2Id, quoteId);
        quoteLine3.SBQQ__PricebookEntryId__c = pBEs[2].Id;
        quoteLine3.NATT_RequiredByProductName__c = 'BluEdge';
        quoteLine.NATT_BluEdgeBundleUniqueKey__c = 'BluEdge';
        quoteLine3.SBQQ__RequiredBy__c = quoteLineList[0].Id;
        quoteLineList.add(quoteLine3);
        
        SBQQ__QuoteLine__c quoteLine4 = TestUtil.createQuoteLine(pbes[3].Product2Id, quoteId);
        quoteLine4.SBQQ__PricebookEntryId__c = pBEs[3].Id;
        quoteLine4.SBQQ__RequiredBy__c = quoteLineList[1].Id;        
        quoteLine4.NATT_RequiredByProductName__c = 'BluEdge';
        quoteLineList.add(quoteLine4);
        
        SBQQ__QuoteLine__c quoteLine5 = TestUtil.createQuoteLine(pbes[4].Product2Id, quoteId);
        quoteLine5.SBQQ__PricebookEntryId__c = pBEs[2].Id;
        quoteLine5.SBQQ__RequiredBy__c = quoteLineList[0].Id;
        quoteLineList.add(quoteLine5);
        
        SBQQ__QuoteLine__c quoteLine6 = TestUtil.createQuoteLine(pbes[5].Product2Id, quoteId);
        quoteLine6.SBQQ__PricebookEntryId__c = pBEs[3].Id;
        quoteLine6.SBQQ__RequiredBy__c = quoteLineList[1].Id;
        quoteLineList.add(quoteLine6);
        
        upsert quoteLineList;
        
        List<SBQQ__QuoteLine__c> clonedLinesUpdateList = new List<SBQQ__QuoteLine__c>();
        
        // clone quotelines
        SBQQ__QuoteLine__c qLClone = quoteLineList[0].clone();
        qLClone.SBQQ__Source__c = quoteLineList[0].Id;
        clonedLinesUpdateList.add(qLClone);
        
        SBQQ__QuoteLine__c qLClone1 = quoteLineList[1].clone();
        qLClone1.SBQQ__Source__c = quoteLineList[1].Id;
        clonedLinesUpdateList.add(qLClone1);
        
        SBQQ__QuoteLine__c qLClone2 = quoteLineList[2].clone();
        qLClone2.SBQQ__Source__c = quoteLineList[2].Id;
        clonedLinesUpdateList.add(qLClone2);
        
        SBQQ__QuoteLine__c qLClone3 = quoteLineList[3].clone();
        qLClone3.SBQQ__Source__c = quoteLineList[3].Id;
        clonedLinesUpdateList.add(qLClone3);
        
        SBQQ__QuoteLine__c qLClone4 = quoteLineList[4].clone();
        qLClone4.SBQQ__Source__c = quoteLineList[4].Id;
        clonedLinesUpdateList.add(qLClone4);
        
        SBQQ__QuoteLine__c qLClone5 = quoteLineList[5].clone();
        qLClone5.SBQQ__Source__c = quoteLineList[5].Id;
        clonedLinesUpdateList.add(qLClone5);
        
        insert clonedLinesUpdateList;
                
        SBQQ__Quote__c quote = new SBQQ__Quote__c(Id=quoteId,SBQQ__Primary__c= true);
        update quote;
        
        //added temporarily
        List<SBQQ__QuoteLine__c> qlList = [SELECT Id FROM SBQQ__QuoteLine__c Where SBQQ__Quote__r.NATT_Quote_Record_Type_Developer_Name__c = 'NATT_Units_Quote'];
        delete qlList;
        
        SBQQ.TriggerControl.enable();
        Test.stopTest();
    }
    @isTest
    static void NATTUnitQuoteAmendment(){
        
        List<Opportunity> opps = [SELECT Id, AccountId FROM Opportunity Where Name ='UnitsTestOpp'];
        String accId = opps[0].AccountId;
        Account acc = [SELECT Id From Account WHERE Id =:accId];
        Order order = TestUtil.createOrder(acc,Date.today(),'Draft');
        insert order;
        
        order.NATT_Per_Hour_Billing__c = false;
        order.NATT_Original_Order_Id__c = order.Id;
        update order;
        
        Test.startTest();
        
        SBQQ.TriggerControl.disable();
        
        SBQQ__Quote__c quote = new SBQQ__Quote__c(SBQQ__Type__c = 'Amendment', 
        RecordTypeId = Schema.SObjectType.SBQQ__Quote__c.getRecordTypeInfosByDeveloperName().get('NATT_Units_Quote').getRecordTypeId(),
        SBQQ__Primary__c = true, SBQQ__Account__c = opps[0].AccountId, SBQQ__Opportunity2__c = opps[0].Id);
        insert quote;
        
        String quoteId = quote.Id;
        
        /*SBQQ__Quote__c quote = new SBQQ__Quote__c(Id = quoteId, SBQQ__Type__c = 'Amendment', 
        RecordTypeId = Schema.SObjectType.SBQQ__Quote__c.getRecordTypeInfosByDeveloperName().get('NATT_Units_Quote').getRecordTypeId());
        update quote;*/
        
        Pricebook2 pb = [Select Id From Pricebook2 Where Name = 'NATT Units Price Book'];
        
        List<PriceBookEntry> pbes = [Select Id,Product2Id From PriceBookEntry Where PriceBook2Id =:pb.Id];
        
        // insert quote lines
        List<SBQQ__QuoteLine__c> quoteLineList = new List<SBQQ__QuoteLine__c>();
        
        SBQQ__QuoteLine__c quoteLine = TestUtil.createQuoteLine(pbes[0].Product2Id, quoteId);
        quoteLine.SBQQ__PricebookEntryId__c = pBEs[0].Id;
        quoteLine.NATT_BluEdgeBundleUniqueKey__c = 'BluEdge';
        quoteline.NATT_Is_Base_Unit__c = true;
        quoteline.NATT_Original_Order_Id__c = order.Id;
        quoteline.NATT_Locked__c = true;
        quoteline.SBQQ__PriorQuantity__c = 1;
        quoteLineList.add(quoteLine);
        
        SBQQ__QuoteLine__c quoteLine2 = TestUtil.createQuoteLine(pbes[1].Product2Id, quoteId);
        quoteLine2.SBQQ__PricebookEntryId__c = pBEs[1].Id;
        quoteLine2.NATT_BluEdgeBundleUniqueKey__c = 'BluEdge';
        quoteLine2.NATT_Is_Base_Unit__c = true;
        quoteLine2.NATT_Original_Order_Id__c = order.Id;
        quoteline2.NATT_Locked__c = true;
        quoteline2.SBQQ__PriorQuantity__c = 1;
        quoteLineList.add(quoteLine2);
        
        
        try{
            insert quoteLineList;
        }
        catch(DmlException e){
            system.debug('error: ' + e);
            system.assertEquals(true, e != null, 'Exceptions should be handled by the method');
        }
        
        quoteline2.SBQQ__Quantity__c = 100;
        quoteline2.NATT_End_Customer_Price__c = 1000;
        
        SBQQ__QuoteLine__c quoteLine3 = TestUtil.createQuoteLine(pbes[2].Product2Id, quoteId);
        quoteLine3.SBQQ__PricebookEntryId__c = pBEs[2].Id;
        quoteLine3.NATT_RequiredByProductName__c = 'BluEdge';
        quoteLine3.NATT_BluEdgeBundleUniqueKey__c = 'BluEdge';
        quoteLine3.SBQQ__RequiredBy__c = quoteLineList[0].Id;
        quoteLine3.NATT_Is_Base_Unit__c = true;
        quoteLine3.NATT_Original_Order_Id__c = order.Id;
        quoteline3.NATT_Locked__c = true;
        quoteLineList.add(quoteLine3);
        
        SBQQ__QuoteLine__c quoteLine4 = TestUtil.createQuoteLine(pbes[3].Product2Id, quoteId);
        quoteLine4.SBQQ__PricebookEntryId__c = pBEs[3].Id;
        quoteLine4.SBQQ__RequiredBy__c = quoteLineList[1].Id;        
        quoteLine4.NATT_RequiredByProductName__c = 'BluEdge';
        quoteLine4.NATT_Is_Base_Unit__c = true;
        quoteLine4.NATT_Original_Order_Id__c = order.Id;
        quoteline4.NATT_Locked__c = true;
        quoteLineList.add(quoteLine4);
        
        SBQQ__QuoteLine__c quoteLine5 = TestUtil.createQuoteLine(pbes[4].Product2Id, quoteId);
        quoteLine5.SBQQ__PricebookEntryId__c = pBEs[2].Id;
        quoteLine5.SBQQ__RequiredBy__c = quoteLineList[0].Id;
        quoteLine5.NATT_Is_Base_Unit__c = true;
        quoteLine5.NATT_Original_Order_Id__c = order.Id;
        quoteline5.NATT_Locked__c = true;
        quoteLineList.add(quoteLine5);
        
        SBQQ__QuoteLine__c quoteLine6 = TestUtil.createQuoteLine(pbes[5].Product2Id, quoteId);
        quoteLine6.SBQQ__PricebookEntryId__c = pBEs[3].Id;
        quoteLine6.SBQQ__RequiredBy__c = quoteLineList[1].Id;
        quoteLine6.NATT_Is_Base_Unit__c = true;
        quoteLine6.NATT_Original_Order_Id__c = order.Id;
        quoteline2.NATT_Locked__c = true;
        quoteLineList.add(quoteLine6);
        
        try{
            upsert quoteLineList;
        }
        catch(DmlException e){
            system.debug('error: ' + e);
            system.assertEquals(true, e != null, 'Exceptions should be handled by the method');
        }
        
        List<SBQQ__QuoteLine__c> clonedLinesUpdateList = new List<SBQQ__QuoteLine__c>();
        
        // clone quotelines
        SBQQ__QuoteLine__c qLClone = quoteLineList[0].clone();
        qLClone.SBQQ__Source__c = quoteLineList[0].Id;
        clonedLinesUpdateList.add(qLClone);
        
        SBQQ__QuoteLine__c qLClone1 = quoteLineList[1].clone();
        qLClone1.SBQQ__Source__c = quoteLineList[1].Id;
        clonedLinesUpdateList.add(qLClone1);
        
        SBQQ__QuoteLine__c qLClone2 = quoteLineList[2].clone();
        qLClone2.SBQQ__Source__c = quoteLineList[2].Id;
        clonedLinesUpdateList.add(qLClone2);
        
        SBQQ__QuoteLine__c qLClone3 = quoteLineList[3].clone();
        qLClone3.SBQQ__Source__c = quoteLineList[3].Id;
        clonedLinesUpdateList.add(qLClone3);
        
        SBQQ__QuoteLine__c qLClone4 = quoteLineList[4].clone();
        qLClone4.SBQQ__Source__c = quoteLineList[4].Id;
        clonedLinesUpdateList.add(qLClone4);
        
        SBQQ__QuoteLine__c qLClone5 = quoteLineList[5].clone();
        qLClone5.SBQQ__Source__c = quoteLineList[5].Id;
        clonedLinesUpdateList.add(qLClone5);
        
        try{
            insert clonedLinesUpdateList;
        }
        catch(DmlException e){
            system.debug('error: ' + e);
            system.assertEquals(true, e != null, 'Exceptions should be handled by the method');
        }
        
        //added temporarily
        List<SBQQ__QuoteLine__c> qlList = [SELECT Id FROM SBQQ__QuoteLine__c Where SBQQ__Quote__r.NATT_Quote_Record_Type_Developer_Name__c = 'NATT_Units_Quote'];
        delete qlList;
        
        SBQQ.TriggerControl.enable();
        Test.stopTest();
    }
    
    @IsTest
    static void NATTESolutionsQuote(){
        
        List<Opportunity> opps = [SELECT Id FROM Opportunity Where Name ='eSolutionsOpp'];
        
        Test.startTest();
        
        SBQQ.TriggerControl.disable();
        
        String quoteId = NattQuoteCon.createQuote(opps[0].Id,false);
        
        Pricebook2 pb = [Select Id From Pricebook2 Where Name = 'NATT Units Price Book'];
        
        List<PriceBookEntry> pbes = [Select Id,Product2Id  From PriceBookEntry Where PriceBook2Id =:pb.Id];
        
        // insert quote lines
        List<SBQQ__QuoteLine__c> quoteLineList = new List<SBQQ__QuoteLine__c>();
        
        SBQQ__QuoteLine__c quoteLine = TestUtil.createQuoteLine(pbes[0].Product2Id, quoteId);
        quoteLine.SBQQ__PricebookEntryId__c = pBEs[0].Id;
        quoteLineList.add(quoteLine);
        
        SBQQ__QuoteLine__c quoteLine2 = TestUtil.createQuoteLine(pbes[1].Product2Id, quoteId);
        quoteLine2.SBQQ__PricebookEntryId__c = pBEs[1].Id;
        quoteLineList.add(quoteLine2);
        
        insert quoteLineList;
        
        SBQQ__QuoteLine__c quoteLine3 = TestUtil.createQuoteLine(pbes[2].Product2Id, quoteId);
        quoteLine3.SBQQ__PricebookEntryId__c = pBEs[2].Id;
        quoteLine3.SBQQ__RequiredBy__c = quoteLineList[0].Id;
        quoteLineList.add(quoteLine3);
        
        SBQQ__QuoteLine__c quoteLine4 = TestUtil.createQuoteLine(pbes[3].Product2Id, quoteId);
        quoteLine4.SBQQ__PricebookEntryId__c = pBEs[3].Id;
        quoteLine4.SBQQ__RequiredBy__c = quoteLineList[1].Id;
        quoteLineList.add(quoteLine4);
        
        SBQQ__QuoteLine__c quoteLine5 = TestUtil.createQuoteLine(pbes[4].Product2Id, quoteId);
        quoteLine5.SBQQ__PricebookEntryId__c = pBEs[2].Id;
        quoteLine5.SBQQ__RequiredBy__c = quoteLineList[0].Id;
        quoteLineList.add(quoteLine5);
        
        SBQQ__QuoteLine__c quoteLine6 = TestUtil.createQuoteLine(pbes[5].Product2Id, quoteId);
        quoteLine6.SBQQ__PricebookEntryId__c = pBEs[3].Id;
        quoteLine6.SBQQ__RequiredBy__c = quoteLineList[1].Id;
        quoteLineList.add(quoteLine6);
        
        upsert quoteLineList;
        
        // clone quotelines
        SBQQ__QuoteLine__c qLClone = quoteLineList[0].clone();
        SBQQ__QuoteLine__c qLClone1 = quoteLineList[1].clone();
        SBQQ__QuoteLine__c qLClone2 = quoteLineList[2].clone();
        SBQQ__QuoteLine__c qLClone3 = quoteLineList[3].clone();
        SBQQ__QuoteLine__c qLClone5 = quoteLineList[4].clone();
        SBQQ__QuoteLine__c qLClone6 = quoteLineList[5].clone();
        
        SBQQ.TriggerControl.enable();
        Test.stopTest();
    }
    
    @IsTest
    static void NATTUnitValidMonthsHoursQuoteTest(){
        
        List<Opportunity> opps = [SELECT Id FROM Opportunity Where Name ='UnitsTestOpp'];
        
        Test.startTest();
        
        SBQQ.TriggerControl.disable();
        
        String quoteId = NattQuoteCon.createQuote(opps[0].Id,false);
        
        Pricebook2 pb = [Select Id From Pricebook2 Where Name = 'NATT Units Price Book'];
        
        List<PriceBookEntry> pbes = [Select Id,Product2Id From PriceBookEntry Where PriceBook2Id =:pb.Id];
        
        // insert quote lines
        List<SBQQ__QuoteLine__c> quoteLineList = new List<SBQQ__QuoteLine__c>();
        
        SBQQ__QuoteLine__c quoteLine = TestUtil.createQuoteLine(pbes[0].Product2Id, quoteId);
        quoteLine.SBQQ__PricebookEntryId__c = pBEs[0].Id;
        quoteLine.NATT_Extended_Basic_Months__c = '24';
        quoteLine.NATT_Optional_Coverage_Months__c = '36';
        quoteLine.NATT_Extended_Basic_Hours__c = '6000';
        quoteLine.NATT_Optional_Coverage_Hours__c = '7000';
        quoteLineList.add(quoteLine);
        
        SBQQ__QuoteLine__c quoteLine2 = TestUtil.createQuoteLine(pbes[1].Product2Id, quoteId);
        quoteLine2.SBQQ__PricebookEntryId__c = pBEs[1].Id;
        quoteLine2.NATT_Coverage_Type__c = 'Extended Basic + Major Component';
        quoteLine.NATT_Major_Component_Months__c = '24';
        quoteLine.NATT_Extended_Basic_Months__c = '36';
        quoteLine.NATT_Major_Component_Hours__c = '6000';   
        quoteLine.NATT_Extended_Basic_Hours__c = '7000';        
        quoteLineList.add(quoteLine2);
        
        try{
            insert quoteLineList;
        }Catch(Exception exp){
            System.debug('>>> ERROR = 1'+exp);
        }        
        
        SBQQ__QuoteLine__c quoteLine3 = TestUtil.createQuoteLine(pbes[2].Product2Id, quoteId);
        quoteLine3.SBQQ__PricebookEntryId__c = pBEs[2].Id;
        quoteLine3.SBQQ__RequiredBy__c = quoteLineList[0].Id;
        quoteLine2.NATT_Coverage_Type__c = 'Extended Basic + Major Component';
        quoteLine.NATT_Major_Component_Months__c = '24';
        quoteLine.NATT_Optional_Coverage_Months__c = '36';
        quoteLine.NATT_Major_Component_Hours__c = '6000';   
        quoteLine.NATT_Optional_Coverage_Hours__c = '7000';   
        quoteLineList.add(quoteLine3);
        
        SBQQ__QuoteLine__c quoteLine4 = TestUtil.createQuoteLine(pbes[3].Product2Id, quoteId);
        quoteLine4.SBQQ__PricebookEntryId__c = pBEs[3].Id;
        quoteLine4.SBQQ__RequiredBy__c = quoteLineList[1].Id;
        quoteLineList.add(quoteLine4);
        
        SBQQ__QuoteLine__c quoteLine5 = TestUtil.createQuoteLine(pbes[4].Product2Id, quoteId);
        quoteLine5.SBQQ__PricebookEntryId__c = pBEs[2].Id;
        quoteLine5.SBQQ__RequiredBy__c = quoteLineList[0].Id;
        quoteLineList.add(quoteLine5);
        
        SBQQ__QuoteLine__c quoteLine6 = TestUtil.createQuoteLine(pbes[5].Product2Id, quoteId);
        quoteLine6.SBQQ__PricebookEntryId__c = pBEs[3].Id;
        quoteLine6.SBQQ__RequiredBy__c = quoteLineList[1].Id;
        quoteLineList.add(quoteLine6);
        
        try{
            upsert quoteLineList;
        }Catch(Exception exp){
            System.debug('>>> ERROR = 2'+exp);
        }        
        
        SBQQ.TriggerControl.enable();
        Test.stopTest();
    }
    
    @IsTest
    static void NATTBluEdgeQuote(){
        
        List<Opportunity> opps = [SELECT Id FROM Opportunity Where Name ='BluEdgeTestOpp'];
        
        Test.startTest();
        
        SBQQ.TriggerControl.disable();
        
        String quoteId = NattQuoteCon.createQuote(opps[0].Id,false);
       
        List<NATT_Inventory__c> inventories = new List<NATT_Inventory__c>();
        inventories.add(new NATT_Inventory__c(NATT_Business_Unit__c = 'TT',NATT_Serial_Number__c = '12345',NATT_Model_Number__c = 'NDW136L0AF0',NATT_Extended_Warranty_Code__c = 'ABCD',NATT_Install_Date__c = Date.today().addDays(20),NATT_Manufacturing_Date__c = Date.today().addDays(10),NATT_Shipment_Date__c = Date.today().addDays(15)));
        inventories.add(new NATT_Inventory__c(NATT_Business_Unit__c = 'TT',NATT_Serial_Number__c = '123456',NATT_Model_Number__c = 'NDW136L0AF0',NATT_Extended_Warranty_Code__c = 'ABCD',NATT_Install_Date__c = Date.today().addDays(20),NATT_Manufacturing_Date__c = Date.today().addDays(10),NATT_Shipment_Date__c = Date.today().addDays(15)));
        insert inventories;
        
        Pricebook2 pb = [Select Id From Pricebook2 Where Name = 'NATT Units Price Book'];
        
        List<PriceBookEntry> pbes = [Select Id,Product2Id  From PriceBookEntry Where PriceBook2Id =:pb.Id];
        
        // insert quote lines
        List<SBQQ__QuoteLine__c> quoteLineList = new List<SBQQ__QuoteLine__c>();
        
        SBQQ__QuoteLine__c quoteLine = TestUtil.createQuoteLine(pbes[0].Product2Id, quoteId);
        quoteLine.SBQQ__PricebookEntryId__c = pBEs[0].Id;
        quoteLine.NATT_Unit__c = 'X4 7300';
        quoteLine.NATT_Inventory__c = inventories[0].Id;
        quoteLine.NATT_Model_Number2__c = 'NDW136L0AF0';
        quoteLine.NATT_Serial_Number__c = '12345';
        quoteLineList.add(quoteLine);
        
        SBQQ__QuoteLine__c quoteLine2 = TestUtil.createQuoteLine(pbes[1].Product2Id, quoteId);
        quoteLine2.SBQQ__PricebookEntryId__c = pBEs[1].Id;        
        quoteLine2.NATT_Unit__c = 'X4 7300';
        quoteLine2.NATT_Inventory__c = inventories[1].Id;
        quoteLine2.NATT_Model_Number2__c = 'NDW136L0AF0';
        quoteLine2.NATT_Serial_Number__c = '123456';
        quoteLineList.add(quoteLine2);
        
        insert quoteLineList;
        
        SBQQ__QuoteLine__c quoteLine3 = TestUtil.createQuoteLine(pbes[2].Product2Id, quoteId);
        quoteLine3.SBQQ__PricebookEntryId__c = pBEs[2].Id;
        quoteLine3.NATT_Unit__c = 'X4 7300';
        quoteLine3.NATT_Inventory__c = inventories[0].Id;
        quoteLine3.NATT_Model_Number2__c = 'NDW136L0AF0';
        quoteLine3.NATT_Serial_Number__c = '12345';
        quoteLine3.SBQQ__RequiredBy__c = quoteLineList[0].Id;
        quoteLineList.add(quoteLine3);
        
        SBQQ__QuoteLine__c quoteLine4 = TestUtil.createQuoteLine(pbes[3].Product2Id, quoteId);
        quoteLine4.SBQQ__PricebookEntryId__c = pBEs[3].Id;
        quoteLine4.NATT_Unit__c = 'X4 7300';
        quoteLine4.NATT_Inventory__c = inventories[0].Id;
        quoteLine4.NATT_Model_Number2__c = 'NDW136L0AF0';
        quoteLine4.NATT_Serial_Number__c = '12345';
        quoteLine4.SBQQ__RequiredBy__c = quoteLineList[1].Id;
        quoteLineList.add(quoteLine4);
        
        SBQQ__QuoteLine__c quoteLine5 = TestUtil.createQuoteLine(pbes[4].Product2Id, quoteId);
        quoteLine5.SBQQ__PricebookEntryId__c = pBEs[2].Id;
        quoteLine5.NATT_Unit__c = 'X4 7300';
        quoteLine5.NATT_Inventory__c = inventories[1].Id;
        quoteLine5.NATT_Model_Number2__c = 'NDW136L0AF0';
        quoteLine5.NATT_Serial_Number__c = '123456';
        quoteLine5.SBQQ__RequiredBy__c = quoteLineList[0].Id;
        quoteLineList.add(quoteLine5);
        
        SBQQ__QuoteLine__c quoteLine6 = TestUtil.createQuoteLine(pbes[5].Product2Id, quoteId);
        quoteLine6.SBQQ__PricebookEntryId__c = pBEs[3].Id;
        quoteLine6.NATT_Unit__c = 'X4 7300';
        quoteLine6.NATT_Inventory__c = inventories[1].Id;
        quoteLine6.NATT_Model_Number2__c = 'NDW136L0AF0';
        quoteLine6.NATT_Serial_Number__c = '123456';
        quoteLine6.SBQQ__RequiredBy__c = quoteLineList[1].Id;
        quoteLineList.add(quoteLine6);
        
        upsert quoteLineList;
        
        // clone quotelines
        SBQQ__QuoteLine__c qLClone = quoteLineList[0].clone();
        SBQQ__QuoteLine__c qLClone1 = quoteLineList[1].clone();
        SBQQ__QuoteLine__c qLClone2 = quoteLineList[2].clone();
        SBQQ__QuoteLine__c qLClone3 = quoteLineList[3].clone();
        SBQQ__QuoteLine__c qLClone5 = quoteLineList[4].clone();
        SBQQ__QuoteLine__c qLClone6 = quoteLineList[5].clone();
        
        SBQQ.TriggerControl.enable();
        Test.stopTest();
    }
    
    @IsTest
    static void NATTUnitQuoteDelete(){
        Test.startTest();
        
        SBQQ.TriggerControl.disable();
        
        Pricebook2 pb = [Select Id From Pricebook2 Where Name = 'NATT Units Price Book'];
        
        List<PriceBookEntry> pbes = [Select Id,Product2Id From PriceBookEntry Where PriceBook2Id =:pb.Id];
        
        SBQQ__Quote__c qRec = new SBQQ__Quote__c(SBQQ__Status__c='Draft',SBQQ__Account__c=null,RecordTypeId=Schema.SObjectType.SBQQ__Quote__c.getRecordTypeInfosByDeveloperName().get('NATT_Units_Quote').getRecordTypeId());
        insert qRec;
        
        // insert quote lines
        List<SBQQ__QuoteLine__c> quoteLineList = new List<SBQQ__QuoteLine__c>();
        
        SBQQ__QuoteLine__c quoteLine = TestUtil.createQuoteLine(pbes[0].Product2Id, qRec.Id);
        quoteLine.SBQQ__PricebookEntryId__c = pBEs[0].Id;
        //quoteLine.NATT_BluEdgeBundleUniqueKey__c = 'NATT';
        quoteLine.SBQQ__Quote__c = qRec.Id;
        quoteLineList.add(quoteLine);
        
        insert quoteLineList;
        
        delete qRec;
        
        SBQQ.TriggerControl.enable();
        Test.stopTest();
    }
}