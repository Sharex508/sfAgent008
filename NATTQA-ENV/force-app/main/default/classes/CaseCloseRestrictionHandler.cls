/********************************************************************************************************
* @author         (LtiMindtree)
* @description    This is a apex class for Container users where the case owner can transfer ownership to another user or queue - CAP-12942
* @date           12/08/2025 [MM/DD/YYYY]
* 
* Modification Log:
* -------------------------------------------------------------------------------------------------------
* Developer                Date                   Modification ID      Description
* -------------------------------------------------------------------------------------------------------
* Pankaj Kumar             12/08/2025                                  Initial version
*********************************************************************************************************/
public with sharing class CaseCloseRestrictionHandler {
    public static void beforeUpdate(List<Case> newList, Map<Id, Case> oldMap) {
        if (newList == null || newList.isEmpty() || oldMap == null || oldMap.isEmpty()) {
            return;
        }
        
        // Execute only for internal users with profile name containing 'Container'
        if (!shouldEnforceForRunningUser()) {
            return;
        }

        // Build set of Case Ids attempting to move to a Closed Status (Status Category = Closed)
        Set<Id> casesMovingToClosed = new Set<Id>();
        // Also collect OwnerIds for queue membership checks
        Set<Id> ownerIds = new Set<Id>();

        System.Debug('newList ==>' + newList);
        
        for (Case c : newList) {
            Case oldC = oldMap.get(c.Id);
            if (oldC == null) continue;

            System.Debug('Case Status ==>' + c.Status + 'c.IsClosed ==> ' + c.IsClosed);
            // Determine if Status category changed to Closed
            // We will check category via Schema Describe to avoid hardcoding values
            if (c.Status != oldC.Status && c.IsClosed == true){  //isClosedCategory(c.Status)) {
                casesMovingToClosed.add(c.Id);
                ownerIds.add(c.OwnerId);
            }
        }

        if (casesMovingToClosed.isEmpty()) {
            return;
        }

        // Running user
        Id runningUserId = UserInfo.getUserId();

        // Identify which owners are queues (Group records with Type = 'Queue')
        Map<Id, Group> queueById = new Map<Id, Group>();
        if (!ownerIds.isEmpty()) {
            for (Group g : [
                SELECT Id, Type
                FROM Group
                WHERE Id IN :ownerIds AND Type = 'Queue'
            ]) {
                queueById.put(g.Id, g);
            }
        }

        // If any cases owned by queues, determine if running user is a member of those queues
        Set<Id> queuesWithRunningUser = new Set<Id>();
        if (!queueById.isEmpty()) {
            for (GroupMember gm : [
                SELECT GroupId, UserOrGroupId
                FROM GroupMember
                WHERE GroupId IN :queueById.keySet() AND UserOrGroupId = :runningUserId
            ]) {
                queuesWithRunningUser.add(gm.GroupId);
            }
        }

        // Enforce: Only case Owner OR members of Owner's queue may move to Closed status category
        String err = 'Only the case owner or members of the owner\'s queue can close this case.';
        for (Case c : newList) {
            if (!casesMovingToClosed.contains(c.Id)) continue;

            // Allow if running user is the owner
            if (c.OwnerId == runningUserId) {
                continue;
            }

            // If owner is a queue, allow if running user is a member of that queue
            if (queueById.containsKey(c.OwnerId) && queuesWithRunningUser.contains(c.OwnerId)) {
                continue;
            }

            // Otherwise, block the close attempt
            c.addError(err);
        }
    }
        // Enforce only for internal users whose Profile name contains 'Container'
    private static Boolean shouldEnforceForRunningUser() {
      
        //Boolean hasPermission = FeatureManagement.checkPermission('ContainerAfterMarketPartsCanCloseCase');
        //System.Debug('hasPermission' + hasPermission);
        
        // Internal user: Not a community/portal user. UserType 'Standard' or 'CSNOnly' etc. Using IsPortalEnabled to filter out external.
        User u = [
            SELECT Id, IsPortalEnabled, Profile.Name
            FROM User
            WHERE Id = :UserInfo.getUserId()
            LIMIT 1
        ];
        if (u.IsPortalEnabled) {
            return false;
        }
        
        return (u.Profile != null && u.Profile.Name != null && 
                (u.Profile.Name.toLowerCase().contains('container') 
                 || u.Profile.Name.toLowerCase().contains('nac super user')
                 || u.Profile.Name.toLowerCase().contains('container service')
                 || u.Profile.Name.toLowerCase().contains('container sales')
				 || u.Profile.Name.toLowerCase().contains('container external commissioning agent')
                 || u.Profile.Name.toLowerCase().contains('system administrator')
                ));
    }
}