trigger ContainerQuoteTrigger on SBQQ__Quote__c (after delete,after insert,after undelete,after update,before delete,before insert,before update) {
     new CONTAINER_Quote_Trigger_Controller().run();
}