trigger OpportunityScheduleDateTrigger on Opportunity_Scheduled_Pick_Date__c (after insert, after update) {
 if (Trigger.isAfter && (Trigger.isInsert || Trigger.isUpdate)) {
        OpportunityScheduleHandler.syncPickDatesToSchedule(Trigger.new);
    }
}