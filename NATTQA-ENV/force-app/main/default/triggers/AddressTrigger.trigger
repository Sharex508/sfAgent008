trigger AddressTrigger on NATT_Address__c (after delete,after insert,after undelete,after update,before delete,before insert,before update) {
    new AddressTriggerHandler().execute();
}