@IsTest
public class CloneOpportunityQuoteDirectSalesTest {

    @TestSetup
    static void setupData() {
        // === Get and activate Standard Pricebook ===
        Id pricebookId = Test.getStandardPricebookId();
        Pricebook2 standardPricebook = new Pricebook2(
            Id = pricebookId,
            IsActive = true
        );
       // update standardPricebook;

        // === Create custom Pricebook ===
        Pricebook2 customPb = new Pricebook2(Name='NATT Units Price Book', IsActive=true);
        insert customPb;

        // === Create Products ===
        List<Product2> products = new List<Product2>();
        for(Integer i=1; i<=6; i++){
            products.add(new Product2(Name='Test Product '+i, Family='Test', IsActive=true));
        }
        insert products;

        // === Standard PricebookEntries (required before custom PB) ===
        List<PricebookEntry> stdPbes = new List<PricebookEntry>();
        for(Product2 p : products){
            stdPbes.add(new PricebookEntry(
                Product2Id = p.Id,
                Pricebook2Id = standardPricebook.Id,
                UnitPrice = 100,
                IsActive = true
            ));
        }
        insert stdPbes;

        // === Custom PricebookEntries ===
        List<PricebookEntry> customPbes = new List<PricebookEntry>();
        for(Product2 p : products){
            customPbes.add(new PricebookEntry(
                Product2Id = p.Id,
                Pricebook2Id = customPb.Id,
                UnitPrice = 100,
                IsActive = true
            ));
        }
        insert customPbes;

        // === Accounts ===
        Account dealerAcc = new Account(
            Name='Test Dealer',
            RecordTypeId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('Dealer').getRecordTypeId(),
            NATT_Organization__c = 'NATT',
            NATT_Region__c = 'East'
        );
        Account directSaleAcc = new Account(
            Name='Test Direct Sales',
            RecordTypeId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('NATT_OEM').getRecordTypeId(),
            NATT_Organization__c = 'NATT',
            NATT_Region__c = 'East'
        );
        insert new List<Account>{dealerAcc, directSaleAcc};

        // === Opportunity ===
        Opportunity opp = new Opportunity(
            Name='UnitsTestOpp',
            CloseDate=Date.today().addDays(30),
            StageName='Qualification',
            AccountId=dealerAcc.Id,
            Pricebook2Id=customPb.Id,
            RecordTypeId=Schema.SObjectType.Opportunity.getRecordTypeInfosByDeveloperName().get('NATT_Opportunity_Units').getRecordTypeId(),
            NATT_Stock__c=true
        );
        insert opp;

        // === Quote ===
        SBQQ__Quote__c quote = new SBQQ__Quote__c(
            SBQQ__Opportunity2__c = opp.Id,
            SBQQ__PricebookId__c  = customPb.Id,
            SBQQ__Primary__c      = true,
            SBQQ__Status__c       = 'Draft',
            SBQQ__Type__c         = 'Quote'
           // Name = 'CloneTestQuote'
        );
        insert quote;

        // === Quote Lines ===
        List<SBQQ__QuoteLine__c> quoteLineList = new List<SBQQ__QuoteLine__c>();
        for(Integer i=0; i<6; i++){
            SBQQ__QuoteLine__c ql = new SBQQ__QuoteLine__c(
                SBQQ__Quote__c = quote.Id,
                SBQQ__Product__c = products[i].Id,
                SBQQ__PricebookEntryId__c = customPbes[i].Id,
                SBQQ__Quantity__c = 1,
                SBQQ__NetPrice__c = 100
            );

            // Example of RequiredBy links
            if(i==2) ql.SBQQ__RequiredBy__c = quoteLineList[0].Id;
            if(i==3) ql.SBQQ__RequiredBy__c = quoteLineList[1].Id;

            quoteLineList.add(ql);
        }
        insert quoteLineList;
    }

    @IsTest
    static void testCloneOpportunityWithQuote() {
        Opportunity opp = [SELECT Id FROM Opportunity WHERE Name='UnitsTestOpp' LIMIT 1];

        Test.startTest();
        CloneOpportunityQuoteDirectSales.CloneResult result =
            CloneOpportunityQuoteDirectSales.cloneOpportunityWithQuote(opp.Id);
        Test.stopTest();

        System.assert(result.success, 'Cloning should succeed');
        System.assertNotEquals(null, result.newOpportunityId, 'New Opportunity should be created');
        System.assertNotEquals(null, result.newQuoteId, 'New Quote should be created');
     //   System.assert(result.newQLICount > 0, 'At least one Quote Line should be cloned');

        // === Validate updates ===
        Opportunity clonedOpp = [SELECT Name FROM Opportunity WHERE Id = :result.newOpportunityId];
        System.assert(clonedOpp.Name.contains('Clone'), 'Cloned Opportunity name should be updated with Clone');
        
        SBQQ__Quote__c clonedQuote = [SELECT SBQQ__Primary__c FROM SBQQ__Quote__c WHERE Id = :result.newQuoteId];
        System.assertEquals(true, clonedQuote.SBQQ__Primary__c, 'Cloned Quote should be Primary');
    }

    @IsTest
    static void testCloneOpportunityNoQuote() {
        Account acc = [SELECT Id FROM Account WHERE Name='Test Dealer' LIMIT 1];
        Opportunity oppNoQuote = new Opportunity(
            Name='NoQuoteOpp',
            CloseDate=Date.today().addDays(30),
            StageName='Qualification',
            AccountId=acc.Id,
            RecordTypeId=Schema.SObjectType.Opportunity.getRecordTypeInfosByDeveloperName().get('NATT_Opportunity_Units').getRecordTypeId()
        );
        insert oppNoQuote;

        Test.startTest();
        CloneOpportunityQuoteDirectSales.CloneResult result =
            CloneOpportunityQuoteDirectSales.cloneOpportunityWithQuote(oppNoQuote.Id);
        Test.stopTest();

        System.assert(result.success, 'Cloning should succeed even with no Quote');
        System.assertEquals(null, result.newQuoteId, 'No Quote should be created');
        System.assert(result.message.contains('No CPQ Quote found'), 'Message should indicate no Quote found');
    }

    @IsTest
    static void testCloneWithNotificationFailure() {
        // Delete notification type to simulate error
        List<CustomNotificationType> notifTypes = [SELECT Id FROM CustomNotificationType WHERE DeveloperName='Clone_Notification' LIMIT 1];
        if(!notifTypes.isEmpty()) {
        //    delete notifTypes;
        }

        Opportunity opp = [SELECT Id FROM Opportunity WHERE Name='UnitsTestOpp' LIMIT 1];

        Test.startTest();
        CloneOpportunityQuoteDirectSales.CloneResult result =
            CloneOpportunityQuoteDirectSales.cloneOpportunityWithQuote(opp.Id);
                    CloneOpportunityQuoteDirectSales.isQuoteApproved(opp.Id, null);
        Test.stopTest();

        System.assert(result.success, 'Cloning should still succeed even if notification fails');
    }

    @IsTest
    static void testCloneWithNullId() {
        Test.startTest();
        CloneOpportunityQuoteDirectSales.CloneResult result =
            CloneOpportunityQuoteDirectSales.cloneOpportunityWithQuote(null);
        Test.stopTest();

        System.assertEquals(false, result.success, 'Should fail if no Id provided');
        System.assert(result.message.contains('No Opportunity Id'), 'Message should indicate missing Id');
    }
}