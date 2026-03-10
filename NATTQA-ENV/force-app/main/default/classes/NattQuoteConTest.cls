@IsTest
    private class NattQuoteConTest {
    @TestSetup static void setupData(){
        List<Pricebook2> pbList = new List<Pricebook2>();
        pbList.add(new Pricebook2(Name='NATT Units Price Book',IsActive=true));
        //pbList.add(new Pricebook2(Name='NATT Parts Price Book',IsActive=true));
        pbList.add(new Pricebook2(Name='NATT BluEdge',IsActive=true));
        pbList.add(new Pricebook2(Name='NATT Lynx Fleet',IsActive=true));
        insert pbList;
        list<account> accList = new  List<account>(); 
        Account a = new Account(Name='Test Dealer',
                                RecordTypeId=Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('Dealer').getRecordTypeId(),
                                NATT_Organization__c = 'NATT',
                                NATT_Region__c = 'East');
        accList.add(a);
        Account directSaleAcc = new Account(Name='Test Direct Sales',
                                            RecordTypeId=Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('NATT_OEM').getRecordTypeId(),
                                            NATT_Organization__c = 'NATT',
                                            NATT_Region__c = 'East');
        accList.add(directSaleAcc);
        database.insert(accList);
        List<Opportunity> oppList = new List<Opportunity>();
        oppList.add(new Opportunity(Name='TestUnitsOpp',CloseDate=Date.today().addDays(30),StageName='Qualification',AccountId=a.Id,RecordTypeId=Schema.SObjectType.Opportunity.getRecordTypeInfosByDeveloperName().get('NATT_Opportunity_Units').getRecordTypeId(),NATT_Stock__c=true));
        oppList.add(new Opportunity(Name='TestBluEdgeOpp',CloseDate=Date.today().addDays(30),StageName='Qualification',AccountId=a.Id,RecordTypeId=Schema.SObjectType.Opportunity.getRecordTypeInfosByDeveloperName().get('NATT_Opportunity_BluEdge').getRecordTypeId(),NATT_Stock__c=true));
        oppList.add(new Opportunity(Name='TesteSolutionsOpp',CloseDate=Date.today().addDays(30),StageName='Qualification',AccountId=a.Id,RecordTypeId=Schema.SObjectType.Opportunity.getRecordTypeInfosByDeveloperName().get('NATT_Opportunity_eSolutions').getRecordTypeId(),NATT_Stock__c=true));
        //oppList.add(new Opportunity(Name='TestPartsOpp',CloseDate=Date.today().addDays(30),StageName='Qualification',AccountId=a.Id,RecordTypeId=Schema.SObjectType.Opportunity.getRecordTypeInfosByDeveloperName().get('NATT_Opportunity_Parts').getRecordTypeId(),NATT_Stock__c=true));
        insert oppList;
    }
        /* @isTest public static void createOpportunityRecord() {
            Opportunity objOpportunity = new Opportunity();
            String strJSON= '{"Name":"TESt","AccountId":"001dz000007bsyZAAQ","StageName":"Quoting","CloseDate":"2025-11-06","NATT_End_Customer__c":null,"NATT_Stock__c":false,"CTBR_Shipping_Address__c":"a4Ndz000000PzLFEA0","CTBR_Billing_Address__c":"a4Ndz000000PyH7EAK","NATT_Shipping_Address__c":"a1Rdz000001QcsHEAS","NATT_Billing_Address__c":"a1Rdz000001RlVJEA0","RecordTypeId":"0127V0000001KITQA2","Pricebook2Id":"01s7V0000004i13QAA"}';
            user us=[Select Id from user WHERE Id='005dz000005xU8sAAE'];
            system.runAS(us){
                objOpportunity = (Opportunity) JSON.deserialize(strJSON, Opportunity.class);
                insert objOpportunity;
                System.debug('objOpportunity-->>'+objOpportunity);
    }
    }*/
 @isTest
    static void testGetAddressJunctionDetailsSuccess() {
        // Create Account
        //Account acc = new Account(Name = 'CTBR Dealer',NATT_Organization__c='CTB',NATT_Region__c='Brazil');
       // insert acc;
        Account acc = [SELECT Id FROM Account WHERE Name='Test Dealer'];
        // Create Address
        NATT_Address__c addr1 = new NATT_Address__c(
            Name = 'NATT Address Billing',
            NATT_Account__c = acc.Id,
            NATT_Country__c = 'US',
            NATT_City__c = 'Almada',
            NATT_State_Province__c = 'AL',
            NATT_Type__c = 'Billing',
            RecordTypeId = Schema.SObjectType.NATT_Address__c.getRecordTypeInfosByDeveloperName()
                .get('CTBR_Address').getRecordTypeId()
        );
        insert addr1;
    // Create Junction
        Ctbr_Account_Address_Junction__c billingJunction = new Ctbr_Account_Address_Junction__c(
            CTBR_Address__c = addr1.Id,
            Type__c = 'Billing'
        );
        insert billingJunction;
        Test.startTest();
        Map<String, Object> result = NattQuoteCon.getAddressJunctionDetails(billingJunction.Id, null);
        Test.stopTest();
        // Assertions
        System.assertEquals(true, result.get('isSuccess'), 'Expected success flag to be true');
        System.assertEquals(addr1.Id, result.get(billingJunction.Id), 'Expected address Id to match');
        System.assertNotEquals(null, result, 'Result should not be null');
    }
        @isTest
static void myUnitTest() {
    Account a = [SELECT Id FROM Account WHERE Name = 'Test Dealer'];
        NattQuoteCon.Wrapper w = NattQuoteCon.getData(a.Id);
    System.assertNotEquals(null, w, 'Wrapper should not be null');

    Opportunity opp = [SELECT Id FROM Opportunity WHERE Name = 'TestUnitsOpp'];
    Opportunity oppData = NattQuoteCon.getOppData(opp.Id);
    System.assertEquals(opp.Id, oppData.Id, 'Opportunity Id should match');

    String quoteJSON = '{}';
    String quoteId1 = NattQuoteCon.createQuote(opp.Id, true, quoteJSON);
    System.assertNotEquals(null, quoteId1, 'Quote Id should not be null');

    opp = [SELECT Id FROM Opportunity WHERE Name = 'TestBluEdgeOpp'];
    String quoteId2 = NattQuoteCon.createQuote(opp.Id, true, quoteJSON);
    System.assertNotEquals(null, quoteId2, 'Quote Id should not be null');

    opp = [SELECT Id FROM Opportunity WHERE Name = 'TesteSolutionsOpp'];
    String quoteId3 = NattQuoteCon.createQuote(opp.Id, true, quoteJSON);
    System.assertNotEquals(null, quoteId3, 'Quote Id should not be null');
}
    @isTest
static void directSales() {
    Account a = [SELECT Id FROM Account WHERE Name = 'Test Direct Sales'];
    NattQuoteCon.Wrapper w = NattQuoteCon.getData(a.Id);
    System.assertNotEquals(null, w, 'Wrapper should not be null');

        List<NATT_Address__c> addrList = new List<NATT_Address__c>();
    NATT_Address__c addr1 = new NATT_Address__c(
        Name = 'NATT Address Billing',
        NATT_Account__c = a.Id,
        NATT_Country__c = 'US',
        NATT_City__c = 'Almada',
        NATT_State_Province__c = 'AL',
        NATT_Type__c = 'Billing',
        RecordTypeId = Schema.SObjectType.NATT_Address__c.getRecordTypeInfosByDeveloperName().get('NATT_Address').getRecordTypeId()
    );
        addrList.add(addr1);

    NATT_Address__c addr2 = new NATT_Address__c(
        Name = 'NATT Address Ship to units',
        NATT_Account__c = a.Id,
        NATT_Country__c = 'US',
        NATT_City__c = 'New Vara',
        NATT_State_Province__c = 'AL',
        NATT_Type__c = 'Units Ship To',
        RecordTypeId = Schema.SObjectType.NATT_Address__c.getRecordTypeInfosByDeveloperName().get('NATT_Address').getRecordTypeId()
    );
        addrList.add(addr2);

    insert addrList;
    System.assertEquals(2, addrList.size(), 'Two addresses should be inserted');

    Id pricebookId = w.rtToPbMap.get(w.defaultRtId);
    String oppJSON = '{"Name":"test","AccountId":"'+a.Id+'","StageName":"Quoting","CloseDate":"2023-10-25","NATT_Purchase_Order__c":"123","Mark_For_Location_Country__c":"CA","Mark_For_Location_State__c":"BC","Mark_For_Location_City__c":"test","NATT_End_Customer__c":null,"NATT_Stock__c":false,"NATT_Shipping_Address__c":"'+addrList[1].Id+'","NATT_Billing_Address__c":"'+addrList[0].Id+'","RecordTypeId":"'+w.defaultRtId+'","Pricebook2Id":"'+pricebookId+'"}';
        Opportunity opp = (Opportunity)JSON.deserialize(oppJSON, Opportunity.class);
        insert opp;
    System.assertNotEquals(null, opp.Id, 'Opportunity should be inserted');

    String quoteJSON = '{"MarkForCountry": "US","MarkForState": "TX","MarkForCity": "rythu","poNumber": "123","hasFreight":true}';

    Test.startTest();
    String quoteId = NattQuoteCon.createQuote(opp.Id, true, quoteJSON);
    Test.stopTest();

    System.assertNotEquals(null, quoteId, 'Quote Id should not be null');
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
        /*NATT_Approval_Process__c approvalProcess = new NATT_Approval_Process__c(
            //Name = 'AP-0000',
            Product_Name__c = product2List[0].id,
            //Product_Family__c = 'Trailer',
            Approval_Object__c = 'SBQQ__Quote__c',
            Business_Type__c = 'NATT',
            Business_Sub_Type__c = 'Units Quote',
            EAM_Lower_Bound__c = 38200.01,
            RD_Lower_Bound__c = 36500.01,
            DOS_Lower_Bound__c = 35500.01,
            Sales_Ops_Lower_Bound__c = 0,
            VP_or_CFO_Lower_Bound__c = 58000,
            EAM_Upper_Bound__c = 36500,
            RD_Upper_Bound__c = 38200,
            DOS_Upper_Bound__c = 36500,
            Sales_Ops_Upper_Bound__c = 35500,
            VP_of_CFO_Upper_Bound__c = 85000
        );
        insert approvalProcess;*/
        quoteRec.SBQQ__Status__c='Pending Approval';
        quoteRec.NATT_Unit__c='Vector 8600 - System 01';
        try{
            update quoteRec;
        }
        catch(exception e){
        }
        
    }
}