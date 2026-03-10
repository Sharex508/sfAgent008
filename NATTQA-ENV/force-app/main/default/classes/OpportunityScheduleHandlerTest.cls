@istest
public class OpportunityScheduleHandlerTest {


    @isTest
    static void testSyncPickDatesToSchedule() {
       
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

        OpportunityLineItem oli = new OpportunityLineItem(
            OpportunityId = opp.Id,
            Quantity = 5,
            UnitPrice = 100,
            PricebookEntryId = standardPbe.Id
        );
        insert oli;

        Opportunity_Scheduled_Pick_Date__c pickDate = new Opportunity_Scheduled_Pick_Date__c(
            Opportunity__c = opp.Id,
            Scheduled_Date__c = Date.today().addDays(5),
            Scheduled_Quantity__c  =5
        );
        insert pickDate;

        Test.startTest();
        OpportunityScheduleHandler.syncPickDatesToSchedule(new List<Opportunity_Scheduled_Pick_Date__c>{pickDate});
        Test.stopTest();

    }


}