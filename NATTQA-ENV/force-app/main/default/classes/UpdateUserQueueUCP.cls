public with sharing class UpdateUserQueueUCP {
    // Added for the story 
    @InvocableMethod(label = 'Add Users to Public Group UCP' description = 'Adds users to the specified public group. Pass userId and groupId as inputs.')
    public static void addUsersToGroup(List<GroupAssignmentRequest> requests) {
        System.debug('requests--' + requests);
        System.enqueueJob(new AddUsersToPublicGroupQueueable(requests));
    }
    
    public class AddUsersToPublicGroupQueueable implements Queueable {
        private List<GroupAssignmentRequest> requests;
        
        public AddUsersToPublicGroupQueueable(List<GroupAssignmentRequest> requests) {
            this.requests = requests;
        }
        
        public void execute(QueueableContext context) {
            List<GroupMember> groupMembersToInsert = new List<GroupMember>();
            List<GroupMember> groupMembersToDelete = new List<GroupMember>();
            Map<Id, Id> userWithGroupMap = new Map<Id, Id>();
            Set<Id> inactiveUsers = new Set<Id>();
            Set<Id> activeUsers = new Set<Id>();
            
            // Categorize users as active or inactive and build map for active users
            for (GroupAssignmentRequest request : this.requests) {
                if (request.userIsActive) {
                    userWithGroupMap.put(request.userId, request.groupId);
                    activeUsers.add(request.userId);
                } else {
                    inactiveUsers.add(request.userId);
                }
            }
            System.debug('userWithGroupMap-' + userWithGroupMap);
            System.debug('inactiveUsers-' + inactiveUsers);
            
            // Query to fetch all group members where users are in any of the specified groups
            List<GroupMember> grpMembers = [
                SELECT Id, UserOrGroupId, GroupId, Group.Name
                FROM GroupMember
                WHERE UserOrGroupId IN :userWithGroupMap.keySet() OR UserOrGroupId IN :inactiveUsers
            ];
            
            // Process each existing group member
            for (GroupMember member : grpMembers) {
                Id userId = member.UserOrGroupId;
                if (inactiveUsers.contains(userId)) {
                    // If the user is inactive, remove them from the group
                    groupMembersToDelete.add(member);
                } else if (userWithGroupMap.containsKey(userId)) {
                    // If the user is active, check group membership
                    Id targetGroupId = userWithGroupMap.get(userId);
                    if (member.GroupId != targetGroupId) {
                        // Remove from the current group if it's not the target group
                        groupMembersToDelete.add(member);
                    }
                }
            }
            
            // Add active users to their target groups
            for (GroupAssignmentRequest request : this.requests) {
                if (request.userIsActive) {
                    GroupMember gm = new GroupMember();
                    gm.UserOrGroupId = request.userId;
                    gm.GroupId = request.groupId;
                    groupMembersToInsert.add(gm);
                }
            }
            
            // Bulk DML operations: delete and insert group members
            try {
                if (!groupMembersToDelete.isEmpty()) {
                    delete groupMembersToDelete; // Remove users from groups
                }
                
                if (!groupMembersToInsert.isEmpty()) {
                    insert groupMembersToInsert; // Add active users to the correct groups
                }
            } catch (DmlException ex) {
                System.debug('Error processing group membership changes: ' + ex.getMessage());
            }
        }
    }
    
    public class GroupAssignmentRequest {
        @InvocableVariable(required=true)
        public String userId;
        
        @InvocableVariable(required=true)
        public String groupId;
        
        @InvocableVariable(required=true)
        public Boolean userIsActive;
    }
    
    @future
    public static void updateContactFedId(Set<Id> userIds) {
        List<User> users = [SELECT Id, ContactId, FederationIdentifier,UCP_Region__c,UCP_Permission_Set__c,Container_Service_Agreement__c FROM User WHERE Id IN :userIds];
        List<Contact> contactsToUpdate = new List<Contact>();
        
        // Loop through the users and update their related contact
        for (User u : users) {
            if (u.ContactId != null) {
                Contact con = new Contact(Id = u.ContactId);
                con.Federation_ID__c = u.FederationIdentifier;
                con.UCP_Permission_Set__c = u.UCP_Permission_Set__c;
                con.UCP_Region__c = u.UCP_Region__c;
                con.Container_Service_Agreement_UCP__c = u.Container_Service_Agreement__c;
                contactsToUpdate.add(con);
            }
        }
        
        // Update the contact records
        if (!contactsToUpdate.isEmpty()) {
            update contactsToUpdate;
        }
    }
    @future
    public static void ServiceAgreementShare(Set<Id> userIds) {
        set<Id> accountId = new set<Id>();
        List<User> users = [select Id, Name, Contact.AccountId,contact.account.Authorized_Service_Provider__c from User where Contact.AccountId  != null and Profile.Name In ('UCP Profile','NAC Customer Community Profile' ) and Id IN :userIds];
        system.debug('UCp users--'+users);
        for (user u: users){
            accountId.add(u.Contact.AccountId);  
            if(u.contact.account.Authorized_Service_Provider__c != null){
                accountId.add(u.contact.account.Authorized_Service_Provider__c); 
            }
        }
        system.debug('UCp Accounts--'+accountId);
        if(accountId.size()==0){
            return;
        }
        List<CONTAINER_Service_Agreement__c> SAList = [select id,name,Account__c, Account__r.RecordType.Name from CONTAINER_Service_Agreement__c where Account__r.RecordType.Name ='CONTAINER Authorized Service Provider' and account__c IN : accountId ];
       system.debug('UCp serviceAgg--'+SAList.size());
        if(SAList.size()>0){
        ServiceAgreementTriggerHelper.ShareServiceAgriment(SAList);
        }
    }
    
    
    
    
    
    
}