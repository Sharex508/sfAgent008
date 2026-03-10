trigger OrderItemTrigger on OrderItem (before insert, after insert) {
    if(trigger.isBefore){
        if(trigger.isInsert){
            OrderItemTriggerHandlerNATT.onBeforeInsert(trigger.new);
        }
    }else if (trigger.isAfter){
        if(trigger.isInsert){
            OrderItemTriggerHandlerNATT.onAfterInsert(trigger.new);
        }
    }
}