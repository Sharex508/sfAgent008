public class UserCreationOktaIntegration {
    
    // Constants for configuration
    
    private static final String OKTA_USER_CREATION_ENDPOINT = 'callout:UCP_Okta_User_Creation/api/v1/users?activate=true';
    private static final String OKTA_GROUP_ENDPOINT = 'callout:UCP_Okta_User_Creation/api/v1/groups/';
    private static final String OKTA_USER_ENDPOINT = 'callout:UCP_Okta_User_Creation/api/v1/users/';
    
    // Create a user in Okta and add to groups
    public static void createUserInOkta(String firstName, String lastName, String email, List<String> groupIds) {
        try {
            String token = getOktaAppConfigByRegion('Okta_Api_Token');
            if (token == null) {
                System.debug('Okta API token not found.');
                return;
            }
            
            // Construct request body
            Map<String, Object> requestBody = new Map<String, Object>{
                'profile' => new Map<String, String>{
                    'firstName' => firstName,
                        'lastName' => lastName,
                        'email' => email,
                        'login' => email
                        }
            };
                
                // Send HTTP request to create user
                HttpResponse response = sendHttpRequest(OKTA_USER_CREATION_ENDPOINT, 'POST', token, JSON.serialize(requestBody));
            if (response != null && (response.getStatusCode() == 200 || response.getStatusCode() == 201)) {
                String oktaUserId = (String) ((Map<String, Object>) JSON.deserializeUntyped(response.getBody())).get('id');
                addUserToGroups(oktaUserId, groupIds); // Add user to groups in bulk
            } else {
                System.debug('Failed to create user in Okta. Response: ' + response.getBody());
            }
        } catch (Exception e) {
            System.debug('Error creating user in Okta: ' + e.getMessage());
        }
    }
    
    // Add user to multiple groups in bulk
    private static void addUserToGroups(String oktaUserId, List<String> groupIds) {
        String token = getOktaAppConfigByRegion('Okta_Api_Token');
        if (token == null) {
            System.debug('Okta API token not found.');
            return;
        }
        
        for (String groupId : groupIds) {
            String endpoint = OKTA_GROUP_ENDPOINT + groupId + '/users/' + oktaUserId;
            HttpResponse response = sendHttpRequest(endpoint, 'PUT', token, null);
            if (response == null || response.getStatusCode() != 204) {
                System.debug('Failed to add user to group ' + groupId + '. Response: ' + response.getBody());
            }
        }
    }
    
    // Get Okta app configuration by region
    public static String getOktaAppConfigByRegion(String region) {
        try {
            List<UCP_Okta_User_Setup__mdt> metadataRecords = [
                SELECT Okta_App_Token__c 
                FROM UCP_Okta_User_Setup__mdt 
                WHERE UCP_Region__c = :region 
                LIMIT 1
            ];
            return metadataRecords.isEmpty() ? null : metadataRecords[0].Okta_App_Token__c;
        } catch (Exception e) {
            System.debug('Error fetching Okta app configuration for region: ' + e.getMessage());
            return null;
        }
    }
    
    // Send HTTP request
    private static HttpResponse sendHttpRequest(String endpoint, String method, String token, String body) {
        try {
            HttpRequest request = new HttpRequest();
            request.setEndpoint(endpoint);
            request.setMethod(method);
            request.setHeader('Authorization', 'SSWS ' + token);
            request.setHeader('Content-Type', 'application/json');
            if (body != null) request.setBody(body);
            return new Http().send(request);
        } catch (Exception e) {
            System.debug('Error sending HTTP request to endpoint: ' + e.getMessage());
            return null;
        }
    }
    
    // Get Okta user ID by email
    public static String getUserIdByEmail(String email) {
        try {
            String encodedEmail = EncodingUtil.urlEncode(email, 'UTF-8');
            String url = OKTA_USER_ENDPOINT + '?q=' + encodedEmail;
            String token = getOktaAppConfigByRegion('Okta_Api_Token');
            HttpResponse res = sendHttpRequest(url, 'GET', token, null);
            
            if (res != null && res.getStatusCode() == 200) {
                List<Object> users = (List<Object>) JSON.deserializeUntyped(res.getBody());
                if (!users.isEmpty()) {
                    return (String) ((Map<String, Object>) users[0]).get('id');
                }
            }
        } catch (Exception e) {
            System.debug('Error fetching Okta user ID by email: ' + e.getMessage());
        }
        return null;
    }
    
    // Deactivate a user in Okta
    @future(callout=true)
    public static void deactivateUser(Set<Id> userIds) {
        try {
            List<User> users = [SELECT Id, Email FROM User WHERE Id IN :userIds];
            String token = getOktaAppConfigByRegion('Okta_Api_Token');
            if (token == null) {
                System.debug('Okta API token not found.');
                return;
            }
            
            for (User user : users) {
                String oktaUserId = getUserIdByEmail(user.Email);
                if (oktaUserId != null) {
                    String url = OKTA_USER_ENDPOINT + oktaUserId + '/lifecycle/deactivate';
                    HttpResponse res = sendHttpRequest(url, 'POST', token, null);
                    if (res == null || res.getStatusCode() != 200) {
                        System.debug('Failed to deactivate user ' + user.Id + ': HTTP Status ' + res.getStatusCode());
                    }
                }
            }
        } catch (Exception e) {
            System.debug('Error deactivating users: ' + e.getMessage());
        }
    }
    
    @future(callout = true)
    public static void setupNewUser(Set<Id> userIds) {
        try {
            List<User> users = [
                SELECT Id, FirstName, LastName, Email, UCP_Region__c, UCP_Permission_Set__c
                FROM User
                WHERE Id IN :userIds
            ];
            
            List<Id> usersToVerify = new List<Id>();
            Map<Id, String> userIdToOktaId = new Map<Id, String>();
            Map<Id, String> userIdToOktaStatus = new Map<Id, String>();
            
            for (User user : users) {
                String userDetail = getOktaUserStatus(user.Email);
                if (String.isEmpty(userDetail) || userDetail.startsWith('Error:') || userDetail.startsWith('Exception:')) {
                    // Add user ID to the list for verification if status retrieval failed
                    usersToVerify.add(user.Id);
                }
                else{
                    Map<String, Object> jsonMap = (Map<String, Object>) JSON.deserializeUntyped(userDetail);
                    String status = (String) jsonMap.get('status');
                    String oktaId = (String) jsonMap.get('id');
                    // Store Okta status and IDs for further processing
                    userIdToOktaId.put(user.Id, oktaId);
                    userIdToOktaStatus.put(user.Id, status);
                }
            }
            
            // Handle users requiring verification
            if (!usersToVerify.isEmpty()) {
                verifyUserDetails(new Set<Id>(usersToVerify));
            }
            
            // Process users with "PROVISIONED" status
            for (Id userId : userIdToOktaStatus.keySet()) {
                if ('PROVISIONED'.equalsIgnoreCase(userIdToOktaStatus.get(userId))) {
                    sendPasswordReset(userIdToOktaId.get(userId));
                }
                else{
                    updateUserGroup(userIds);
                }
            }
            
        } catch (Exception e) {
            system.debug('Error setting up new users'+e);
        }
    }
    
    @future (callout=true)
    public static void updateUserGroupInOkta(Set<Id> userIds){
        updateUserGroup(userIds);
    }
    
    
    // Get user status in Okta
    public static String getOktaUserStatus(String oktaUserIdOrEmail) {
        try {
            String url = 'callout:UCP_Okta_User_Creation/api/v1/users/' + EncodingUtil.urlEncode(oktaUserIdOrEmail, 'UTF-8');
            HttpResponse res = sendHttpRequest(url, 'GET', getOktaAppConfigByRegion('Okta_Api_Token'), null);
            
            system.debug(res);
            system.debug(res.getbody());
            if (res != null && res.getStatusCode() == 200) {
                return res.getBody();
            } else {
                return 'Error: ' + (res != null ? res.getStatusCode() + ' - ' + res.getStatus() : 'No response');
            }
            
        } catch (Exception e) {
            return 'Exception: ' + e.getMessage();
        }
    }
    
    public static void verifyUserDetails(Set<Id> userIds) {
        try {
            // Query users in a single batch
            List<User> users = [
                SELECT Id, FirstName, LastName, Email, UCP_Region__c, UCP_Permission_Set__c
                FROM User
                WHERE Id IN :userIds
            ];
            
            if (users.isEmpty()) {
                System.debug('No users found for verification.');
                return;
            }
            
            Map<User, List<String>> userOktaGroupMap = new Map<User, List<String>>();
            
            // Process each user
            for (User user : users) {
                List<String> oktaGroupTokens = new List<String>();
                String region = user.UCP_Region__c;
                String permissionSet = user.UCP_Permission_Set__c;
                
                // Add default group tokens based on permission sets
                if ('UCP All'.equals(permissionSet) || 'UCP Warranty'.equals(permissionSet)) {
                    String tavantGroup = getOktaAppConfigByRegion('Tavant');
                    if (tavantGroup != null) oktaGroupTokens.add(tavantGroup);
                }
                
                // Add region-based group tokens
                if (('AUS'.equals(region) || 'EMEA'.equals(region)) && 
                    ('UCP All'.equals(permissionSet) || 'UCP Purchase'.equals(permissionSet)) || 
                     ('Americas'.equals(user.UCP_Region__c) && !'UCP Only'.equals(user.UCP_Permission_Set__c))) {
                        String regionGroup = getOktaAppConfigByRegion(region);
                        if (regionGroup != null) oktaGroupTokens.add(regionGroup);
                    }
                
                // Add the ContainerLink App group
                String containerLinkGroup = getOktaAppConfigByRegion('ContainerLink App');
                if (containerLinkGroup != null) oktaGroupTokens.add(containerLinkGroup);
                
                // Only process users with valid Okta configurations
                if (!oktaGroupTokens.isEmpty()) {
                    userOktaGroupMap.put(user, oktaGroupTokens);
                } else {
                    System.debug('No Okta configuration found for user: ' + user.Email + ', Region: ' + region);
                }
            }
            
            // Bulk create users in Okta
            for (User user : userOktaGroupMap.keySet()) {
                createUserInOkta(user.FirstName, user.LastName, user.Email, userOktaGroupMap.get(user));
            }
            
        } catch (Exception e) {
            System.debug('Error verifying user details: ' + e.getMessage());
        }
    }
    
    
    public static String sendPasswordReset(String userId) {
        try {
            if (String.isEmpty(userId)) {
                System.debug('sendPasswordReset: Invalid User ID.');
                return 'Invalid User ID provided.';
            }
            
            // Build the endpoint URL
            String url = 'callout:UCP_Okta_User_Creation/api/v1/users/' + userId + '/lifecycle/reset_password?sendEmail=true';
            String apiToken = getOktaAppConfigByRegion('Okta_Api_Token');
            
            if (String.isEmpty(apiToken)) {
                System.debug('sendPasswordReset: API Token is missing.');
                return 'Error: API Token is missing.';
            }
            
            // Send the HTTP POST request
            HttpResponse res = sendHttpRequest(url, 'POST', apiToken, null);
            
            // Validate and process response
            if (res == null) {
                System.debug('sendPasswordReset: No response received from Okta.');
                return 'Error: No response received from Okta.';
            }
            
            Integer statusCode = res.getStatusCode();
            if (statusCode == 200 || statusCode == 204) {
                return 'Password reset link sent successfully.';
            } else {
                System.debug('sendPasswordReset: Failed to send password reset link. Status: ' + statusCode + ', Response: ' + res.getBody());
                return 'Error: Password reset failed. Status: ' + statusCode;
            }
            
        } catch (Exception e) {
            System.debug('sendPasswordReset: Exception occurred - ' + e.getMessage());
            return 'Error: Exception occurred while sending password reset link.';
        }
    }
    
    
    public static void updateUserGroup(Set<Id> userIds) {
        try {
            if (userIds == null || userIds.isEmpty()) {
                System.debug('updateUserGroup: No user IDs provided.');
                return;
            }
            
            // Query user details
            List<User> users = [ 
                SELECT Id, FirstName, LastName, Email, UCP_Region__c, UCP_Permission_Set__c 
                FROM User 
                WHERE Id IN :userIds 
            ];
            
            Map<String, List<String>> userToGroupsMap = new Map<String, List<String>>();
            Set<Id> usersToVerify = new Set<Id>();
            
            for (User user : users) {
                String oktaUserId = getUserIdByEmail(user.Email);
                
                if (String.isEmpty(oktaUserId)) {
                    System.debug('updateUserGroup: No Okta user ID found for user: ' + user.Email);
                    usersToVerify.add(user.Id);
                    continue;
                }
                
                List<String> oktaGroupTokens = new List<String>();
                
                // Assign groups based on permission sets
                if ('UCP All'.equals(user.UCP_Permission_Set__c) || 'UCP Warranty'.equals(user.UCP_Permission_Set__c)) {
                    oktaGroupTokens.add(getOktaAppConfigByRegion('Tavant'));
                }
                
                // Assign region-based groups
                if (
                    ('AUS'.equals(user.UCP_Region__c) || 'EMEA'.equals(user.UCP_Region__c)) && 
                    ('UCP All'.equals(user.UCP_Permission_Set__c) || 'UCP Purchase'.equals(user.UCP_Permission_Set__c)) ||
                    ('Americas'.equals(user.UCP_Region__c) && !'UCP Only'.equals(user.UCP_Permission_Set__c))
                ) {
                    oktaGroupTokens.add(getOktaAppConfigByRegion(user.UCP_Region__c));
                }
                
                // Always add the ContainerLink App group
                oktaGroupTokens.add(getOktaAppConfigByRegion('ContainerLink App'));
                
                // Ensure no null values in group list
               /* if (oktaGroupTokens == null) {
                    oktaGroupTokens = new List<String>();
                }
                oktaGroupTokens.remove(null);*/
                
                
                if (!oktaGroupTokens.isEmpty()) {
                    userToGroupsMap.put(oktaUserId, oktaGroupTokens);
                }
            }
            
            // Add users to groups in bulk
            for (String oktaUserId : userToGroupsMap.keySet()) {
                for (String groupId : userToGroupsMap.get(oktaUserId)) {
                    addUserToGroup(oktaUserId, groupId);
                }
            }
            
            // Verify users who could not be assigned to groups
            if (!usersToVerify.isEmpty()) {
                verifyUserDetails(usersToVerify);
            }
            
        } catch (Exception e) {
            System.debug('updateUserGroup: Exception occurred - ' + e.getMessage());
        }
    }
    
    // Add user to Okta group
    public static void addUserToGroup(String oktaUserId, String groupId) {
        try {
            String endpoint = 'callout:UCP_Okta_User_Creation/api/v1/groups/' + groupId + '/users/' + oktaUserId;
            HttpResponse response = sendHttpRequest(endpoint, 'PUT', getOktaAppConfigByRegion('Okta_Api_Token'), null);
            
            if (response == null || response.getStatusCode() != 204) {
                system.debug('Failed to add user to group in Okta. Response'+response.getBody());
            }
        } catch (Exception e) {
            system.debug('Error adding user to Okta group'+e);
        }
    }
    
}