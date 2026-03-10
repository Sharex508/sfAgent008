@isTest(seeAllData = false)
public class NattOrderSearchControllerTest {
    
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
        
        insert pBEs;
        
        List<SBQQ__LookupData__c> lkDataList = new List<SBQQ__LookupData__c>();
        
        lkDataList.add(TestUtil.createLookupData(products[0].Id,Date.today().addYears(1),Date.today().addYears(2),'Unit Pricing'));
        lkDataList.add(TestUtil.createLookupData(products[1].Id,Date.today().addYears(1),Date.today().addYears(2),'Unit Pricing'));
        lkDataList.add(TestUtil.createLookupData(products[2].Id,Date.today().addYears(1),Date.today().addYears(2),'Unit Pricing'));
        lkDataList.add(TestUtil.createLookupData(products[3].Id,Date.today().addYears(1),Date.today().addYears(2),'Unit Pricing'));

        insert lkDataList;
        
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
        oppList.add(new Opportunity(Name='UnitsTestOpp',
                                    CloseDate=Date.today().addDays(30),
                                    StageName='Qualification',
                                    AccountId=aList.get(0).Id,
                                    NATT_End_Customer__c = aList.get(2).Id,
                                    RecordTypeId=Schema.SObjectType.Opportunity.getRecordTypeInfosByDeveloperName().get('NATT_Opportunity_Units').getRecordTypeId(),
                                    NATT_Stock__c=true));
        insert oppList;
    }
    
    @isTest static void testOrderSearchController(){
        
        Boolean testUser = NattOrderSearchController.isCommunity_Apex();
        
        System.assertEquals(false, testUser);
        
        Account acc = [Select Id From Account LIMIT 1];
        
        List<Order> odrs = new List<Order>();
            
        odrs.add(TestUtil.createOrder(acc,Date.today(),'Draft'));
        odrs.add(TestUtil.createOrder(acc,Date.today(),'Draft'));
        
        insert odrs;
        
        odrs[0].NATT_Original_Order_Id__c = odrs[0].Id;
        odrs[1].NATT_Original_Order_Id__c = odrs[1].Id;
        update odrs;
        
        List<Product2> prds = [Select Id,Name From Product2];
            
        List<OrderItem> odrItems = new List<OrderItem>();
        
        odrItems.add(TestUtil.createOrderItem(prds[0],1,odrs[0],1,true));
        odrItems.add(TestUtil.createOrderItem(prds[1],1,odrs[1],2,true));
        odrItems.add(TestUtil.createOrderItem(prds[0],2,odrs[0],1,false));
        odrItems.add(TestUtil.createOrderItem(prds[1],3,odrs[1],2,false));
        
        insert odrItems;
        
        Boolean hasopenAmendment = NattOrderSearchController.hasOpenAmendment_Apex(odrs[0].Id);
        
        System.assertEquals(false, hasopenAmendment);
        
        List<Asset> assets = new List<Asset>();
        
        assets.add(TestUtil.createAsset(prds[0],prds[0].Name,odrs[0].Id,acc));
        assets.add(TestUtil.createAsset(prds[1],prds[1].Name,odrs[1].Id,acc));
        assets.add(TestUtil.createAsset(prds[0],prds[0].Name,odrs[0].Id,acc));
        assets.add(TestUtil.createAsset(prds[1],prds[1].Name,odrs[1].Id,acc));
        insert assets;
        
        Boolean shipmentMethodEditable = NattOrderSearchController.getShipmentMethodEditable_Apex(odrs[0].Id);
        
        // fetch related units
        List<NattOrderSearchController.OrderItemWrapper> wrapper = NattOrderSearchController.fetchRelatedUnits_Apex(odrs[0].Id);
        
        // hide assets
        NattOrderSearchController.hideOtherAssets_Apex(odrs[0].Id);
        
        // validate price changes
        NattOrderSearchController.validateRequestedDatePriceChanges_Apex(String.valueOf(Date.today().addDays(100)),odrItems[0].Id);
        
        // in valid scenario price changes
        NattOrderSearchController.validateRequestedDatePriceChanges_Apex(String.valueOf(Date.today().addDays(400)),odrItems[0].Id);
        
        // save new requested ship date changes
        NattOrderSearchController.saveRequestedShipDateChanges_Apex(odrs[0].Id,String.valueOf(Date.today().addDays(100)),odrItems[0].Id);
        
        // save order
        NattOrderSearchController.saveOrder_Apex(odrs[0].Id,'Test PO',null,'markSpecialInstructions',null,false,'dealerComments','',null);
        
        //isJDESalesOrder_NotNull
        NattOrderSearchController.isJDESalesOrder_NotNull(odrs[0].Id);
        
        //hasOpenAmendment2_Apex
        NattOrderSearchController.hasOpenAmendment2_Apex(odrs[0].Id);
        
        //hasOpenAmendment_Apex
        NattOrderSearchController.hasOpenAmendment_Apex(odrs[0].Id);
    }
}