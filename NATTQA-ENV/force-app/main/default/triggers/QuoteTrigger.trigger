trigger QuoteTrigger on SBQQ__Quote__c (after delete,after insert,after undelete,after update,before delete,before insert,before update) {
    new QuoteTriggerHandler().execute();
}