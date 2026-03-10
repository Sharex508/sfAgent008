trigger IventoryTrigger on NATT_Inventory__c (after insert, after update) {
    if(trigger.isAfter){
        if(trigger.isInsert){
            InventoryTriggerHandler.onAfterInsert(trigger.newMap);
        }
         /*if(trigger.isUpdate){
            InventoryTriggerHandler.onAfterUpdate(trigger.new, trigger.oldMap);
        }*/
    }
}