/*********************
Name of Trigger: SetFileVisibilityForKnowledge
======================================================
Purpose:
Cases - Customer Access for File Attachments Default
======================================================
History
-------
AUTHOR                  DATE           DETAIL                 Description
Mahesh Meesala        18/10/2022      INITIAL CarStage        Customer Access for File Attachments Default  
*********************/
trigger SetFileVisibilityForKnowledge on ContentDocumentLink (before insert) {
    if(trigger.isBefore && trigger.isInsert){
        for (ContentDocumentLink cdl : Trigger.new) {
            if (cdl.LinkedEntityId.getSObjectType().getDescribe().getName() == 'Knowledge__kav') {
                cdl.visibility = 'AllUsers';
            }
        }
    }
    //Added by Rajasekharreddy Kotella CCRN 1841
    Trigger_Control__mdt triggerControl = [ SELECT id,Is_Trigger_Enabled__c FROM Trigger_Control__mdt WHERE DeveloperName = 'ContentDocumentLink' LIMIT 1];
    if(triggerControl!= null && triggerControl.Is_Trigger_Enabled__c && trigger.isBefore && (trigger.isInsert  ) ){
        ContentDocumentLinkHelper.updateVisiblePermission(Trigger.new);
    }
}