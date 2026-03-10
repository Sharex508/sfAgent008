/* Created a Apex Trigger to create a CONTAINER_Service_Agreement__share__c records with read access
 * Created by : Rajasekharreddy Kotella
 * Created on : 04-10-2024
 * Class Name : ServiceAgreementTrigger
 */
trigger ServiceAgreementTrigger on CONTAINER_Service_Agreement__c (after insert) {
    Trigger_Control__mdt triggerControl = [ SELECT id,Is_Trigger_Enabled__c FROM Trigger_Control__mdt WHERE DeveloperName = 'Service_Agreement_Trigger' LIMIT 1];
    if (triggerControl != null && triggerControl.Is_Trigger_Enabled__c ){ 
        ServiceAgreementTriggerHelper.ShareServiceAgriment(trigger.new);
    }
}