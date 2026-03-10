trigger CONTAINER_Quote_ASO_Release on SBQQ__QuoteDocument__c (before insert,before update,before delete,after insert,after update,after delete,after undelete) {
    new Container_Quote_ASO_Release_Controller().run();
}