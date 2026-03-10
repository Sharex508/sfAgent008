public class Natt_Case_Queue_Email_Notification { 
    
    public static void sendQueueeMailNotification(List<Case> caseList, map<Id,case> caseOldMap){
        List<case> casestoUpdate = new List<case>();
        List<string> sendTo = new List<string>();
        map<Id,string> grpMap = new map<id,string>();
        list<string> memberIdList = new list<string>();
        map<Id,string> caseDefaultQueueMap = new map<id,string>();
        map<Id,list<string>> caseMemberMap = new map<id,list<string>>();
        try{
            for(case c : caseList){
                string ownerIdVal = c.OwnerId;
                if (c.OwnerId != null && ownerIdVal.startsWith('00G') &&  caseOldMap !=null && ownerIdVal != caseOldMap.get(c.Id).ownerID ) { 
                    casestoUpdate.add(c);
                    caseDefaultQueueMap.put(c.Id, c.NATT_Default_Queue__c);
                }
            }
            if(casestoUpdate.size() < 1){
                return;
            }
            sendTo = getQueueMembers(caseDefaultQueueMap);
            
            List<Messaging.SingleEmailMessage> emailList = new List<Messaging.SingleEmailMessage>();
            for (Case newCase : casestoUpdate) {
                if(!sendTo.isempty()){
                    Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
                    email.setToAddresses(sendTo); 
                    email.setSubject('New Case Notification.' 	+ newCase.CaseNumber);
                    String  body = 	'Case Number'+		':' + ''+ newCase.CaseNumber+'<br/>' +
                        'Priority'+			':' + ''+ newCase.Priority+'<br/>'+ 
                        'Case Record Type'+	':' + ''+ newCase.RecordTypeId+'<br/>'+
                        'Case Type'+		':' + ''+ newCase.Type+'<br/>' + 
                        'Case Reason'+		':' + ''+ newCase.CTM_Case_Reason__c+'<br/>';
                    email.setHtmlBody(body);    
                    emailList.add(email);
                }
            }
            Messaging.SendEmailResult[] emailResults = Messaging.sendEmail(emailList);
        }
        catch(exception e){
            system.debug(e);
        }
    }
    public static List<string> getQueueMembers( map<Id,string> caseDefaultQueueMap){
        list<string> sendMailsTo = new list<string>();
        set<Id> innerGroup = new set<Id>();
        List<Group> groups = new List<Group>([SELECT Id, Name,DeveloperName,Email  FROM Group WHERE Type = 'Queue' AND DeveloperName IN :  caseDefaultQueueMap.values() ]);
        List<GroupMember> queueMembers = [SELECT id,GroupId,  UserOrGroupId FROM GroupMember WHERE GroupId in : groups ];
        
        for(GroupMember member : queueMembers) {
            string memGroupId = member.UserOrGroupId;
            if(! memGroupId.startsWith('00G')){
                sendMailsTo.add(member.UserOrGroupId);
            }
            else{
                innerGroup.add(member.UserOrGroupId);
            }
        }
        if(innerGroup.size() >0 ){
            List<GroupMember> Memberslist =  getQueueMemberslist(innerGroup);
            for(GroupMember member : queueMembers) {
                string memGroupId = member.UserOrGroupId;
                if(! memGroupId.startsWith('00G')){
                    sendMailsTo.add(member.UserOrGroupId);
                }
                
            }
        }
        
        return  sendMailsTo;
    }
    public static List<GroupMember> getQueueMemberslist(set<id> groupId ){
        List<GroupMember> queueMembersList = [SELECT id,GroupId,  UserOrGroupId FROM GroupMember WHERE GroupId in : groupId ];
        return queueMembersList;
    }
    
    
}