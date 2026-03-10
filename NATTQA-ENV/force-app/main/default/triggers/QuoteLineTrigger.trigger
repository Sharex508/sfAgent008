trigger QuoteLineTrigger on SBQQ__QuoteLine__c (after delete,after insert,after undelete,after update,before delete,before insert,before update) {
    new QuoteLineTriggerHandler().execute();
}