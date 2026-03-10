trigger UserTrigger on User (before insert, before update, before delete, after insert, after update, after delete, after undelete) {
    
    //UserTriggerHandler handler = new UserTriggerHandler();
    
    // Handler for all trigger operations
       new UserTriggerHandler().execute();
    
    if (Trigger.isBefore) {
        if (Trigger.isUpdate) {
            // Placeholder for future before-update logic
        }
    }
    
    if (Trigger.isAfter) {
        Set<Id> userIds = new Set<Id>();
        for (User u : Trigger.new) {
            userIds.add(u.Id);
        }
        
        if (Trigger.isInsert || Trigger.isUpdate) {
            handleAfterInsertOrUpdate(userIds);
        }
        if (Trigger.isInsert) {
            handleAfterInsert(Trigger.new);
        }
        if (Trigger.isUpdate) {
            handleAfterUpdate(Trigger.new, Trigger.oldMap);
        }
    }
    
    public static void handleAfterInsert(List<User> newUsers) {
        Set<Id> userIds = new Set<Id>();
        for (User u : newUsers) {
            userIds.add(u.Id);
        }
        
        UserClass.addNewUserInGroup(newUsers);
        
        Map<Id, Profile> profileMap = getProfileMap(newUsers);
        
        if (System.Label.UCP_ExecuteOktaUserCreation == 'TRUE') {
            
            assignPermissionSets(newUsers);
            
            String allowedProfiles = System.Label.UCP_OktaProfile; 
            List<String> allowedProfileList = allowedProfiles.split(',');
            
            List<String> allowedProfileListRecord = new List<String>();
            for (String profile : allowedProfileList) {
                allowedProfileListRecord.add(profile.trim());
            } 
            
            for (User user : newUsers) {
                if (profileMap.containsKey(user.ProfileId)) {
                    Profile userProfile = profileMap.get(user.ProfileId);
                    
                    // Check if user's profile exists in the allowed profiles list
                    if (allowedProfileListRecord.contains(userProfile.Name.trim()) && 
                        String.isNotBlank(user.UCP_Permission_Set__c) && 
                        String.isNotBlank(user.UCP_Region__c) && 
                        user.IsPortalEnabled == true) {
                            
                            UserCreationOktaIntegration.setupNewUser(userIds);
                        }
                }
            }
        }
    }
    
    private void handleAfterInsertOrUpdate(Set<Id> userIds) {
        UpdateUserQueueUCP.updateContactFedId(userIds);
        UpdateUserQueueUCP.ServiceAgreementShare(userIds);
    }
    
    private void handleAfterUpdate(List<User> newUsers, Map<Id, User> oldUserMap) {
        
        Set<Id> userIdsToUpdateOkta = new Set<Id>();
        Set<Id> userIdsToDeactivate = new Set<Id>();
        Map<String, Id> permissionSetMap = getPermissionSetMap();
        Map<String, String> permissionSetApiMap = getPermissionSetApiMap();
        Map<Id, Profile> profileMap = getProfileMap(newUsers);
        
        List<PermissionSetAssignment> assignmentsToDelete = new List<PermissionSetAssignment>();
        Map<Id, List<PermissionSetAssignment>> userAssignmentMap = getUserPermissionAssignments(newUsers, permissionSetMap.keySet());
        
        
        String allowedProfiles = System.Label.UCP_OktaProfile; 
        List<String> allowedProfileList = allowedProfiles.split(',');
        
        List<String> allowedProfileListRecord = new List<String>();
            for (String profile : allowedProfileList) {
                allowedProfileListRecord.add(profile.trim());
        } 
        
        for (User user : newUsers) {
            User oldUser = oldUserMap.get(user.Id);
            
            if (profileMap.containsKey(user.ProfileId)) {
                
                Profile userProfile = profileMap.get(user.ProfileId);
                
                                          
                if (allowedProfileListRecord.contains(userProfile.Name.trim()) && 
                    String.isNotBlank(user.UCP_Permission_Set__c) && 
                    String.isNotBlank(user.UCP_Region__c) && 
                    user.IsPortalEnabled == true) {
                                                
                        if (userAssignmentMap.containsKey(user.Id) && user.UCP_Permission_Set__c != oldUser.UCP_Permission_Set__c) {
                            assignmentsToDelete.addAll(userAssignmentMap.get(user.Id));
                        }
                        
                        if ((user.UCP_Region__c != oldUser.UCP_Region__c || user.UCP_Permission_Set__c != oldUser.UCP_Permission_Set__c) &&
                            System.Label.UCP_ExecuteOktaUserCreation == 'TRUE' ) {
                                userIdsToUpdateOkta.add(user.Id);
                            }
                        
                        if (!user.IsActive && oldUser.IsActive && String.isNotBlank(user.UCP_Region__c) &&
                            System.Label.UCP_ExecuteOktaUserCreation == 'TRUE') {
                               // userIdsToDeactivate.add(user.Id);
                            }
                        
                        assignPermissionSet(user, permissionSetMap, permissionSetApiMap);
                    }
            }
        }
        
        if (!assignmentsToDelete.isEmpty()) {
            delete assignmentsToDelete;
        }
        
        if (!userIdsToUpdateOkta.isEmpty()) {
            UserCreationOktaIntegration.updateUserGroupInOkta(userIdsToUpdateOkta);
        }
        /*if (!userIdsToDeactivate.isEmpty()) {
           UserCreationOktaIntegration.deactivateUser(userIdsToDeactivate);
        }*/
    }
    
    private Map<Id, Profile> getProfileMap(List<User> users) {
        return new Map<Id, Profile>(
            [SELECT Id, Name FROM Profile WHERE Id IN (SELECT ProfileId FROM User WHERE Id IN :users)]
        );
    }
    
    //Get the triggered user permission set and the record.
    private Map<Id, List<PermissionSetAssignment>> getUserPermissionAssignments(List<User> users, Set<String> permissionSetNames) {
        Map<Id, List<PermissionSetAssignment>> userAssignmentMap = new Map<Id, List<PermissionSetAssignment>>();
        for (PermissionSetAssignment psa : [
            SELECT Id, AssigneeId FROM PermissionSetAssignment 
            WHERE AssigneeId IN :users AND PermissionSet.IsOwnedByProfile = false
            AND PermissionSet.Name IN :permissionSetNames
        ]) {
            if (!userAssignmentMap.containsKey(psa.AssigneeId)) {
                userAssignmentMap.put(psa.AssigneeId, new List<PermissionSetAssignment>());
            }
            userAssignmentMap.get(psa.AssigneeId).add(psa);
        }
        return userAssignmentMap;
    }
    
    //Create a map of the permission set with the id
    private Map<String, Id> getPermissionSetMap() {
        Map<String, Id> permissionSetMap = new Map<String, Id>();
        for (PermissionSet ps : [
            SELECT Id, Name FROM PermissionSet WHERE Name IN ('UCP_All', 'UCP_Only', 'UCP_Purchase', 'UCP_Warranty')
        ]) {
            permissionSetMap.put(ps.Name, ps.Id);
        }
        return permissionSetMap;
    }
    
    //Get the permission set apis
    private Map<String, String> getPermissionSetApiMap() {
        return new Map<String, String>{
            'UCP All' => 'UCP_All',
                'UCP Only' => 'UCP_Only',
                'UCP Purchase' => 'UCP_Purchase',
                'UCP Warranty' => 'UCP_Warranty'
                };
                    }
    
    
    private void assignPermissionSets(List<User> users) {
        Map<String, Id> permissionSetMap = getPermissionSetMap();
        Map<String, String> permissionSetApiMap = getPermissionSetApiMap();
        List<PermissionSetAssignment> psaList = new List<PermissionSetAssignment>();
        
        for (User user : users) {
            if (String.isNotBlank(user.UCP_Permission_Set__c)) {
                psaList.add(new PermissionSetAssignment(
                    AssigneeId = user.Id,
                    PermissionSetId = permissionSetMap.get(permissionSetApiMap.get(user.UCP_Permission_Set__c))
                ));
            }
        }
        try {
            insert psaList;
        } catch (DmlException e) {
            System.debug('Error assigning permission sets: ' + e.getMessage());
        }
    }
    
    //Assignment of the permission set
    private void assignPermissionSet(User user, Map<String, Id> permissionSetMap, Map<String, String> permissionSetApiMap) {
        if (String.isNotBlank(user.UCP_Permission_Set__c)) {
            try {
                insert new PermissionSetAssignment(
                    AssigneeId = user.Id,
                    PermissionSetId = permissionSetMap.get(permissionSetApiMap.get(user.UCP_Permission_Set__c))
                );
            } catch (DmlException e) {
                System.debug('Error assigning permission sets: ' + e.getMessage());
            }
        }
    }
}