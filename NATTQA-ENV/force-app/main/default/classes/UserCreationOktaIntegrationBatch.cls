public class UserCreationOktaIntegrationBatch implements Database.Batchable<User>, Database.AllowsCallouts {
    private Set<Id> userIds;

    public UserCreationOktaIntegrationBatch(Set<Id> userIds) {
        this.userIds = userIds;
    }

    public Iterable<User> start(Database.BatchableContext context) {
        return [
            SELECT Id, FirstName, LastName, Email, UCP_Region__c, UCP_Permission_Set__c 
            FROM User 
            WHERE Id IN :userIds
        ];
    }

    public void execute(Database.BatchableContext context, List<User> scope) {
        try {
            Map<Id, String> userIdToOktaId = new Map<Id, String>();
            Map<Id, String> userIdToOktaStatus = new Map<Id, String>();
            List<Id> usersToVerify = new List<Id>();

            // Process each user in the scope
            for (User user : scope) {
                String userDetail = UserCreationOktaIntegration.getOktaUserStatus(user.Email);
                if (String.isEmpty(userDetail) || userDetail.startsWith('Error:') || userDetail.startsWith('Exception:')) {
                    usersToVerify.add(user.Id);
                } else {
                    Map<String, Object> jsonMap = (Map<String, Object>) JSON.deserializeUntyped(userDetail);
                    userIdToOktaId.put(user.Id, (String) jsonMap.get('id'));
                    userIdToOktaStatus.put(user.Id, (String) jsonMap.get('status'));
                }
            }

            // Verify users with failed status retrieval
            if (!usersToVerify.isEmpty()) {
                UserCreationOktaIntegration.verifyUserDetails(new Set<Id>(usersToVerify));
            }

            // Handle Okta "PROVISIONED" users
            for (Id userId : userIdToOktaStatus.keySet()) {
                if ('PROVISIONED'.equalsIgnoreCase(userIdToOktaStatus.get(userId))) {
                    UserCreationOktaIntegration.sendPasswordReset(userIdToOktaId.get(userId));
                }
            }

            // Update group for all users
            if (!userIdToOktaId.isEmpty()) {
                UserCreationOktaIntegration.updateUserGroup(userIdToOktaId.keySet());
            }

        } catch (Exception e) {
            System.debug('Error in execute method: ' + e.getMessage());
        }
    }

    public void finish(Database.BatchableContext context) {
        try {
            Map<String, Id> permissionSetMap = getPermissionSetMap();
            Map<String, String> permissionSetApiMap = getPermissionSetApiMap();

            List<User> users = [
                SELECT Id, UCP_Permission_Set__c 
                FROM User 
                WHERE Id IN :userIds
            ];

            List<PermissionSetAssignment> psaList = new List<PermissionSetAssignment>();
            for (User user : users) {
                if (String.isNotBlank(user.UCP_Permission_Set__c)) {
                    String permissionSetApiName = permissionSetApiMap.get(user.UCP_Permission_Set__c);
                    if (permissionSetApiName != null && permissionSetMap.containsKey(permissionSetApiName)) {
                        psaList.add(new PermissionSetAssignment(
                            AssigneeId = user.Id,
                            PermissionSetId = permissionSetMap.get(permissionSetApiName)
                        ));
                    }
                }
            }

            if (!psaList.isEmpty()) {
                try {
                    insert psaList;
                } catch (DmlException e) {
                    System.debug('Error assigning permission sets: ' + e.getMessage());
                }
            }

        } catch (Exception e) {
            System.debug('Error in finish method: ' + e.getMessage());
        }
    }

    private Map<String, Id> getPermissionSetMap() {
        Map<String, Id> permissionSetMap = new Map<String, Id>();
        for (PermissionSet ps : [
            SELECT Id, Name 
            FROM PermissionSet 
            WHERE Name IN ('UCP_All', 'UCP_Only', 'UCP_Purchase', 'UCP_Warranty')
        ]) {
            permissionSetMap.put(ps.Name, ps.Id);
        }
        return permissionSetMap;
    }

    private Map<String, String> getPermissionSetApiMap() {
        return new Map<String, String>{
            'UCP All' => 'UCP_All',
            'UCP Only' => 'UCP_Only',
            'UCP Purchase' => 'UCP_Purchase',
            'UCP Warranty' => 'UCP_Warranty'
        };
    }
}