trigger Natt_Casequeueemailnotification on Case (after update) {
    
    if(Trigger.IsAfter && Trigger.Isupdate ){
        Id profileId= userinfo.getProfileId();
        String profileName =[Select Id,Name from Profile where Id=:profileId].Name;
        if(profileName == 'NATT Parts and Service Community' ){
            
            Natt_Case_Queue_Email_Notification.sendQueueeMailNotification(Trigger.new,Trigger.oldMap);
        }
     else
        {
            
            System.Debug('Class CaseCloseRestrictionHandler==>');
            CaseCloseRestrictionHandler.beforeUpdate(trigger.new,trigger.oldmap);
        }
    } 
}