public without sharing class CONTAINER_Quote_Trigger_Controller extends CONTAINER_TriggerHandler{
	 public override void beforeUpdate(){
        CONTAINER_Quote_Trigger_Helper.onBeforeUpdate((Map<Id,SBQQ__Quote__c>)Trigger.oldMap, (Map<Id,SBQQ__Quote__c>)Trigger.newMap);
    }
    
    /*
    public override void afterUpdate(){
        CONTAINER_Quote_Trigger_Helper.onAfterUpdate((Map<Id,SBQQ__Quote__c>)Trigger.oldMap ,(Map<Id,SBQQ__Quote__c>)Trigger.newMap);
    }*/
}