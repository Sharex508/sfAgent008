@isTest
public class OpportunityQuoteCreationControllerTest {
    @TestSetup
    static void setupTestData(){
        // Create Record Types
        //Id unitRecordTypeID = Schema.SObjectType.Opportunity.getRecordTypeInfosByName().get('Units').getRecordTypeId();
        
        List<RecordType> opportunityRecordTypes = [SELECT Id, DeveloperName, Name 
                                                   FROM RecordType 
                                                   WHERE SObjectType = 'Opportunity'
                                                   AND IsActive =true];
        
        // Create Pricebooks
        Pricebook2 pb1 = new Pricebook2(Name = 'NATT BluEdge', IsActive = true);
        Pricebook2 pb2 = new Pricebook2(Name = 'NATT Lynx Fleet', IsActive = true);
        Pricebook2 pb3 = new Pricebook2(Name = 'NATT Units Price Book', IsActive = true);
        insert new List<Pricebook2>{pb1, pb2, pb3};
            
            // Create an Opportunity
            Opportunity opp = new Opportunity(Name = 'Test Opportunity', StageName = 'Qualification', CloseDate = Date.today());
        insert opp;
        Opportunity_Scheduled_Pick_Date__c schedulePickDate = new Opportunity_Scheduled_Pick_Date__c();
        schedulePickDate.Opportunity__c = opp.id;
        
        schedulePickDate.Scheduled_Quantity__c =  0 ;
        schedulePickDate.Scheduled_Date__c =  System.today().addDays(10);
        insert schedulePickDate;
        
        SBQQ__Quote__c quote = new SBQQ__Quote__c(NATT_Stock__c = opp.NATT_Stock__c,NATT_End_Customer__c=opp.NATT_End_Customer__c,SBQQ__Primary__c = true,SBQQ__Opportunity2__c=opp.id);
        insert quote;
    }
    
    @isTest
    static void testGetOpportunityRecordTypes() {
        Id standardPbId = Test.getStandardPricebookId();

        Id recordTypeId = [SELECT Id FROM RecordType WHERE SObjectType = 'Opportunity' AND Name = 'NATT Direct Sales' LIMIT 1].Id;
        
        Product2 prod = new Product2(
            Name = 'Test Product',
            IsActive = true,
            CanUseQuantitySchedule = true,
            CanUseRevenueSchedule = true,
            NATT_Is_Base_Unit__c = true
        );
        insert prod;
        
         PricebookEntry standardPbe = new PricebookEntry(
            Pricebook2Id = standardPbId,
            Product2Id = prod.Id,
            UnitPrice = 100,
            IsActive = true
        );
        insert standardPbe;
        
        Opportunity opp = new Opportunity(
            Name = 'Test Opportunity',
            StageName = 'Prospecting',
            CloseDate = Date.today().addDays(10),
            Pricebook2Id = standardPbId,
            RecordTypeId = recordTypeId
        );
        insert opp;
        
        Id accountRecordTypeId = [SELECT Id FROM RecordType WHERE SObjectType = 'Account' AND Name = 'Dealer' LIMIT 1].Id;
        
        Account objAccount = new Account(
                        Name = 'Dealer',
                        NATT_Organization__c = 'NATT',
                        NATT_Region__c = 'East',
                        RecordTypeId = accountRecordTypeId
                    );
       insert objAccount;

        
        Test.startTest();
        
        List<RecordType> oppRecordTypes = OpportunityQuoteCreationController.getRecordTypes('Opportunity',objAccount.Id);
        List<RecordType> quoteRecordTypes = OpportunityQuoteCreationController.getRecordTypes('SBQQ__Quote__c',opp.Id);
        Test.stopTest();
        System.assert(oppRecordTypes.size()>0, 'Expected more than 1 record types for Opportunity.');
        System.assert(quoteRecordTypes.size()>0, 'Expected more than 1 record types for Quote.');
    }
    
     @isTest
    static void testGetOpportunityRecordTypesData() {
        Id standardPbId = Test.getStandardPricebookId();

        Id recordTypeId = [SELECT Id FROM RecordType WHERE SObjectType = 'Opportunity' AND Name = 'Units' LIMIT 1].Id;
        
        Product2 prod = new Product2(
            Name = 'Test Product',
            IsActive = true,
            CanUseQuantitySchedule = true,
            CanUseRevenueSchedule = true,
            NATT_Is_Base_Unit__c = true
        );
        insert prod;
        
         PricebookEntry standardPbe = new PricebookEntry(
            Pricebook2Id = standardPbId,
            Product2Id = prod.Id,
            UnitPrice = 100,
            IsActive = true
        );
        insert standardPbe;
        
        Opportunity opp = new Opportunity(
            Name = 'Test Opportunity',
            StageName = 'Prospecting',
            CloseDate = Date.today().addDays(10),
            Pricebook2Id = standardPbId,
            RecordTypeId = recordTypeId
        );
        insert opp;
        
        Id accountRecordTypeId = [SELECT Id FROM RecordType WHERE SObjectType = 'Account' AND Name = 'Direct Sale' LIMIT 1].Id;
        
        Account objAccount = new Account(
                        Name = 'Dealer',
                        NATT_Organization__c = 'NATT',
                        NATT_Region__c = 'East',
                        RecordTypeId = accountRecordTypeId
                    );
       insert objAccount;

        
        Test.startTest();
        
        List<RecordType> oppRecordTypes = OpportunityQuoteCreationController.getRecordTypes('Opportunity',objAccount.Id);
        List<RecordType> quoteRecordTypes = OpportunityQuoteCreationController.getRecordTypes('SBQQ__Quote__c',opp.Id);
        
        OpportunityQuoteCreationController.getUserInfo(opp.Id);
        Test.stopTest();
        System.assert(oppRecordTypes.size()>0, 'Expected more than 1 record types for Opportunity.');
        System.assert(quoteRecordTypes.size()>0, 'Expected more than 1 record types for Quote.');
    }
    
    @isTest
    static void testGetPricebookFromRecordTypes() {
        RecordType rt = [SELECT Id FROM RecordType WHERE DeveloperName = 'NATT_Opportunity_Units' LIMIT 1];
        
        Test.startTest();
        String pricebookId = OpportunityQuoteCreationController.getPricebookFromRecordTypes(rt.Id);
        Test.stopTest();
        
        System.assertNotEquals(null, pricebookId, 'Expected a valid Pricebook2Id.');
        Pricebook2 pb = [SELECT Id,Name FROM Pricebook2 WHERE Id = :pricebookId];
        System.assertEquals('NATT Units Price Book', pb.Name, 'Expected NATT BluEdge Pricebook.');
    }
    
    @isTest
    static void testUpdatePricebookOnOpportunity() {
        Opportunity opp = [SELECT Id, Pricebook2Id FROM Opportunity WHERE Name = 'Test Opportunity' LIMIT 1];
        Id rtId = Schema.SObjectType.Opportunity.getRecordTypeInfosByName().get('Units').getRecordTypeId();
        
        Test.startTest();
        OpportunityQuoteCreationController.updatePricebookOnOpportunity(opp.Id, rtId);
        OpportunityQuoteCreationController.addressFromAccount(opp.Id);
        OpportunityQuoteCreationController.getScheduledPickDates(opp.Id);
        Test.stopTest();
        
        // Fetch the updated opportunity and assert that Pricebook2Id was updated
        Opportunity updatedOpp = [SELECT Id, Pricebook2Id FROM Opportunity WHERE Id = :opp.Id];
        System.assertNotEquals(null, updatedOpp.Pricebook2Id, 'Pricebook2Id should have been updated.');
        Pricebook2 pb = [SELECT Name FROM Pricebook2 WHERE Id = :updatedOpp.Pricebook2Id];
        System.assertEquals('NATT Units Price Book', pb.Name, 'Expected NATT Units Pricebook.');
    }  
    @isTest
    static void getProductsNull() {
        Opportunity opp = [SELECT Id, Pricebook2Id FROM Opportunity WHERE Name = 'Test Opportunity' LIMIT 1];
        try{
            OpportunityQuoteCreationController.getOpportunityProducts(null);
        }
        catch(exception e){
            system.debug(e);
        }
    }
    @isTest
    static void getProductsId() {
        Opportunity opp = [SELECT Id, Pricebook2Id FROM Opportunity WHERE Name = 'Test Opportunity' LIMIT 1];
        OpportunityQuoteCreationController.getOpportunityProducts(opp.Id);
        
    }
    @isTest
    static void getProductsException() {
        Id userId = userInfo.getUserId();
        OpportunityQuoteCreationController.getOpportunityProducts(userId);
    }
    
}