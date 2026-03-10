@isTest(seeAllData=false)
public class GlobalProductSearchPluginTest{
    
    @testSetup
    static void testSetup(){
        List<Pricebook2> pbList = new List<Pricebook2>();
        pbList.add(new Pricebook2(Name='NATT Units Price Book',IsActive=true));
        pbList.add(new Pricebook2(Name='NATT Parts Price Book',IsActive=true));
        pbList.add(new Pricebook2(Name='NATT BluEdge',IsActive=true));
        pbList.add(new Pricebook2(Name='NATT Lynx FLeet',IsActive=true));
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
        Product2 product9 = TestUtil.createProduct('X4 7700','APU-T0040');
        products.add(product9);
        
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
        alist.add(new Account(Name='Test Dealer',NATT_Organization__c = 'NATT',NATT_Region__c = 'East',RecordTypeId=Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('Dealer').getRecordTypeId()));
        aList.add(new Account(Name='Test Internal',NATT_Organization__c = 'NATT',NATT_Region__c = 'East',RecordTypeId=Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('Internal').getRecordTypeId()));
        aList.add(new Account(Name='Customer',NATT_Organization__c = 'NATT',NATT_Region__c = 'East',RecordTypeId=Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('Customer').getRecordTypeId()));
        
        insert aList;
        
        // assignes dealership to end customer
        aList[1].NATT_Dealership__c = aList.get(0).Id;
        
        // assignes dealership to end customer
        aList[2].NATT_Dealership__c = aList.get(0).Id;
        
        update aList[2];
        
        List<AccountTeamMember> atmList = new List<AccountTeamMember>();
        atmList.add(new AccountTeamMember(AccountId=aList.get(0).Id,UserId=UserInfo.getUserId(),TeamMemberRole='EAM - NATT'));
        atmList.add(new AccountTeamMember(AccountId=aList.get(0).Id,UserId=UserInfo.getUserId(),TeamMemberRole='RD - NATT'));
        atmList.add(new AccountTeamMember(AccountId=aList.get(0).Id,UserId=UserInfo.getUserId(),TeamMemberRole='Director of Sales - NATT'));
        insert atmList;
        
        List<Opportunity> oppList = new List<Opportunity>();
        oppList.add(new Opportunity(Name='UnitsTestOpp',CloseDate=Date.today().addDays(30),StageName='Qualification',AccountId=aList.get(0).Id,RecordTypeId=Schema.SObjectType.Opportunity.getRecordTypeInfosByDeveloperName().get('NATT_Opportunity_Units').getRecordTypeId(),NATT_Stock__c=true));
        oppList.add(new Opportunity(Name='UnitsTestOppInternal',CloseDate=Date.today().addDays(30),StageName='Qualification',AccountId=aList.get(1).Id,RecordTypeId=Schema.SObjectType.Opportunity.getRecordTypeInfosByDeveloperName().get('NATT_Opportunity_Units').getRecordTypeId(),NATT_Stock__c=true));
        oppList.add(new Opportunity(Name='BluEdgeTestOpp',CloseDate=Date.today().addDays(30),StageName='Qualification',AccountId=aList.get(0).Id,RecordTypeId=Schema.SObjectType.Opportunity.getRecordTypeInfosByDeveloperName().get('NATT_Opportunity_BluEdge').getRecordTypeId(),NATT_Stock__c=true));
        oppList.add(new Opportunity(Name='eSolutionsOpp',CloseDate=Date.today().addDays(30),StageName='Qualification',AccountId=aList.get(1).Id,RecordTypeId=Schema.SObjectType.Opportunity.getRecordTypeInfosByDeveloperName().get('NATT_Opportunity_eSolutions').getRecordTypeId(),NATT_Stock__c=true));
        insert oppList;
    }
    
    @isTest static void searchScenario(){
        
        Account a = [SELECT Id FROM Account WHERE Name='Test Dealer'];
        NattQuoteCon.Wrapper w = NattQuoteCon.getData(a.Id);
        
        Opportunity opp = [SELECT Id,RecordType.DeveloperName FROM Opportunity WHERE Name='UnitsTestOpp'];
        System.debug('Opp RecordType.DeveloperName:'+opp.RecordType.DeveloperName);
        opp = NattQuoteCon.getOppData(opp.Id);
        string QuoteJSON = '{}';
        Id quoteId = NattQuoteCon.createQuote(opp.Id,true,QuoteJSON);
        System.debug('quoteId:'+quoteId);
        SBQQ__Quote__c dbQuote = new SBQQ__Quote__c(Id=quoteId,NATT_Product_Family__c='Trailer',
                                                    NATT_Unit__c='X4 7700');
        update dbQuote;
        //System.debug('dbQuote RecordType.DeveloperName:'+dbQuote.RecordType.DeveloperName);
        //string productname=[Select NATT_Unit__c  from SBQQ__Quote__c where Id=:quoteId].NATT_Unit__c;
        //System.debug('productname:'+productname);
        Product2 pr=[Select id,Family from Product2 where Name ='X4 7700' LIMIT 1];
        pr.Family='Trailer';
        update pr;
        SBQQ__QuoteLine__c qline= new SBQQ__QuoteLine__c();
        qline.SBQQ__Quote__c=quoteId;
        qline.SBQQ__Product__c=pr.Id;
       /// qline.SBQQ__ProductFamily__c='Trailer';
        insert qline;
        SBQQ__Quote__c dbQuote2 = new SBQQ__Quote__c(Id=quoteId,
                                                    SBQQ__Status__c='Pending Approval');
       // update dbQuote2;
        
        List<String> fieldList = new List<String>(SBQQ__Quote__c.sObjectType.getDescribe().fields.getMap().keySet());
        
        String fields = String.join(fieldList,','); 
        
        SBQQ__Quote__c quote = Database.query('SELECT ' + fields + ' FROM SBQQ__Quote__c WHERE Id = :quoteId');        
        
        // instance
        GlobalProductSearchPlugin gp = new GlobalProductSearchPlugin();
        
        // default filter 
        gp.isFilterHidden(quote,'');
        
        // default filter values
        gp.getFilterDefaultValue(quote,'');
        
        NATT_Product_Dealer_Type__c dt1 = new NATT_Product_Dealer_Type__c(NATT_Dealer__c = a.Id,NATT_Product_Type__c = 'Truck');
        insert dt1;
        runSearch(gp,quote);
        NATT_Product_Dealer_Type__c dt2 = new NATT_Product_Dealer_Type__c(NATT_Dealer__c = a.Id,NATT_Product_Type__c = 'Trailer');
        insert dt2;
        runSearch(gp,quote);
        NATT_Product_Dealer_Type__c dt3 = new NATT_Product_Dealer_Type__c(NATT_Dealer__c = a.Id,NATT_Product_Type__c = 'Electric Trailer');
        insert dt3;
        runSearch(gp,quote);
        NATT_Product_Dealer_Type__c dt4 = new NATT_Product_Dealer_Type__c(NATT_Dealer__c = a.Id,NATT_Product_Type__c = 'Special Products');
        insert dt4;
        runSearch(gp,quote);
        NATT_Product_Dealer_Type__c dt5 = new NATT_Product_Dealer_Type__c(NATT_Dealer__c = a.Id,NATT_Product_Type__c = 'Electric Truck');
        insert dt5;
        runSearch(gp,quote);
    }
        
    public static void runSearch(GlobalProductSearchPlugin gp,SBQQ__Quote__c quote){
        Map<String,Object> fieldValuesMap = new Map<String,Object>();
        gp.isSearchCustom(quote,fieldValuesMap);
        
        gp.isSuggestCustom(quote,fieldValuesMap);
        
        gp.isInputHidden(quote,'Name');
        
        gp.getInputDefaultValue(quote,'');
                
        gp.getAdditionalSuggestFilters(quote,fieldValuesMap);
        
        gp.getAdditionalSearchFilters(quote,fieldValuesMap);
        
        gp.search(quote,fieldValuesMap);       
        
        gp.suggest(quote,fieldValuesMap);      
    }
}