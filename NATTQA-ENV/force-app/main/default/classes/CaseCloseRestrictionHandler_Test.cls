@IsTest(SeeAllData=False)
private class CaseCloseRestrictionHandler_Test {

    // ---------------------------
    // Profiles
    // ---------------------------

    private static Profile getSysAdminProfile() {
        return [SELECT Id, Name FROM Profile WHERE Name = 'System Administrator' LIMIT 1];
    }

    // Use a profile that triggers enforcement:
    // Prefer 'Container' if present (internal), else 'System Administrator'.
    private static Profile getEnforcementProfile() {
        List<Profile> containers = [
            SELECT Id, Name FROM Profile WHERE Name LIKE '%Container%' LIMIT 1
        ];
        if (!containers.isEmpty()) return containers[0];
        return getSysAdminProfile();
    }

    // A Standard profile that should NOT trigger enforcement; if none exists, return null.
    private static Profile getNonEnforcementProfileOrNull() {
        List<Profile> stds = [SELECT Id, Name, UserType FROM Profile WHERE UserType = 'Standard'];
        for (Profile p : stds) {
            String nm = (p.Name == null) ? '' : p.Name.toLowerCase();
            Boolean enforced =
                nm.contains('container') ||
                nm.contains('nac super user') ||
                nm.contains('container service') ||
                nm.contains('container sales') ||
                nm.contains('container external commissioning agent') ||
                nm.contains('system administrator');
            if (!enforced) return p;
        }
        return null;
    }

    // ---------------------------
    // User & Queue helpers
    // ---------------------------

    private static User makeInternalUser(Id profileId, String alias, String emailName) {
        return new User(
            Alias             = alias,
            Email             = emailName + '@test.example',
            EmailEncodingKey  = 'UTF-8',
            LastName          = emailName,
            LanguageLocaleKey = 'en_US',
            LocaleSidKey      = 'en_US',
            TimeZoneSidKey    = 'America/New_York',
            Username          = emailName + '+' + String.valueOf(Crypto.getRandomLong()) + '@test.example',
            ProfileId         = profileId,
            IsActive          = true // IMPORTANT
        );
    }

    private static User ensureSysAdminUser() {
        Profile p = getSysAdminProfile();
        User admin = makeInternalUser(p.Id, 'tadmin', 'testadmin');
        insert admin;
        return admin;
    }

    // Create a queue & add members inside SysAdmin context (fixes FIELD_INTEGRITY_EXCEPTION)
    private static Id createQueue(String name, List<User> members) {
        User admin = ensureSysAdminUser();
        Id queueId;
        System.runAs(admin) {
            Group q = new Group(Name = name, Type = 'Queue');
            insert q;
            insert new QueueSobject(QueueId = q.Id, SobjectType = 'Case');

            if (members != null && !members.isEmpty()) {
                List<GroupMember> gms = new List<GroupMember>();
                for (User u : members) {
                    gms.add(new GroupMember(GroupId = q.Id, UserOrGroupId = u.Id));
                }
                insert gms; // now permitted
            }
            queueId = q.Id;
        }
        return queueId;
    }

    // ---------------------------
    // Data helpers
    // ---------------------------

    private static Account ensureAccount() {
        Map<String,Schema.RecordTypeInfo> rtMap = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName();
        Account a = new Account(Name='Dealer',NATT_Organization__c = 'NATT',NATT_Region__c = 'East',RecordTypeId=rtMap.get('CONTAINER_Customer').getRecordTypeId());
        insert a;
        return a;
    }

    // Robust status helpers (metadata-aware)
    private static String getAnyClosedStatus() {
        Set<String> closedLabels = new Set<String>();
        for (CaseStatus cs : [SELECT MasterLabel FROM CaseStatus WHERE IsClosed = true ORDER BY SortOrder]) {
            closedLabels.add(cs.MasterLabel);
        }
        if (closedLabels.isEmpty()) return null;
        for (Schema.PicklistEntry pe : Case.Status.getDescribe().getPicklistValues()) {
            if (closedLabels.contains(pe.getLabel())) return pe.getValue(); // VALUE
        }
        return null;
    }
    private static String getAnyOpenStatus() {
        Set<String> openLabels = new Set<String>();
        for (CaseStatus cs : [SELECT MasterLabel FROM CaseStatus WHERE IsClosed = false ORDER BY SortOrder]) {
            openLabels.add(cs.MasterLabel);
        }
        if (openLabels.isEmpty()) return null;
        for (Schema.PicklistEntry pe : Case.Status.getDescribe().getPicklistValues()) {
            if (openLabels.contains(pe.getLabel())) return pe.getValue();
        }
        return null;
    }

    // ---------------------------
    // Tests
    // ---------------------------

    @IsTest
    static void testOwnerCanClose() {
        String closedStatus = getAnyClosedStatus();
        String openStatus   = getAnyOpenStatus();
        System.assertNotEquals(null, closedStatus, 'Org must have at least one Closed status');
        System.assertNotEquals(null, openStatus,   'Org must have at least one Open status');

        // Owner can be Container or SysAdmin (enforced)
        Profile enforcementProfile = getEnforcementProfile();
        User ownerUser = makeInternalUser(enforcementProfile.Id, 'ownr', 'owneruser');
        insert ownerUser;

        System.runAs(ownerUser) {
            Account a = ensureAccount();
            Map<String,Schema.RecordTypeInfo> rtMapCase = Schema.SObjectType.Case.getRecordTypeInfosByDeveloperName();
            Case c = new Case(Subject = 'Owner Close', Status = openStatus,NATT_Close_Reason_Explanation__c='expired', AccountId = a.Id,RecordTypeId=rtMapCase.get('Container_Aftermarket_Parts').getRecordTypeId());
            insert c;
            c.Status = closedStatus;
            update c;

            Case fetched = [SELECT Id, Status, IsClosed FROM Case WHERE Id = :c.Id];
            System.assertEquals(closedStatus, fetched.Status);
            System.assertEquals(true, fetched.IsClosed);
        }
    }

    @IsTest
    static void testQueueMemberCanClose() {
        String closedStatus = getAnyClosedStatus();
        String openStatus   = getAnyOpenStatus();
        System.assertNotEquals(null, closedStatus, 'Org must have at least one Closed status');
        System.assertNotEquals(null, openStatus,   'Org must have at least one Open status');

        // Make queueMember a SysAdmin to ensure internal/privileged
        Profile sys = getSysAdminProfile();
        User queueMember = makeInternalUser(sys.Id, 'qmem', 'queuemember');
        insert queueMember;

        // NonMember also SysAdmin (to guarantee edit access once we share)
        User nonMember   = makeInternalUser(sys.Id, 'nmem', 'nonmember');
        insert nonMember;

        Id queueId = createQueue('Test Case Queue ' + System.currentTimeMillis(), new List<User>{ queueMember });

        Case qc;
        System.runAs(queueMember) {
            Account a = ensureAccount();
            
            qc = new Case(Subject = 'Queue Case', Status = openStatus, AccountId = a.Id, OwnerId = queueId);
            insert qc;

            // Queue member closes: allowed
            qc.Status = closedStatus;
            qc.NATT_Close_Reason__c = 'Other'; // REQUIRED field
            qc.NATT_Close_Reason_Explanation__c='Test';
            update qc;

            // Re-open for negative test
            qc = [SELECT Id, Status FROM Case WHERE Id = :qc.Id];
            qc.Status = openStatus;
            update qc;

            // Give nonMember edit access so update reaches handler
            insert new CaseShare(
                CaseId          = qc.Id,
                UserOrGroupId   = nonMember.Id,
                CaseAccessLevel = 'Edit',
                RowCause        = Schema.CaseShare.RowCause.Manual
            );
        }

        Boolean blocked = false;
        System.runAs(nonMember) {
            try {
                qc.Status = closedStatus;
                qc.NATT_Close_Reason__c = 'Other';
                update qc;
            } catch (DmlException e) {
                blocked = true;
                String msg = e.getMessage().toLowerCase();
                System.assert(
                    msg.contains('case owner') && msg.contains('close this case'),
                    'Expected error message not found: ' + e.getMessage()
                );
            }
        }
        System.assertEquals(true, blocked, 'Non-member should be blocked from closing queue-owned case.');
    }

    @IsTest
    static void testNonOwnerBlocked() {
        String closedStatus = getAnyClosedStatus();
        String openStatus   = getAnyOpenStatus();
        System.assertNotEquals(null, closedStatus, 'Org must have at least one Closed status');
        System.assertNotEquals(null, openStatus,   'Org must have at least one Open status');

        // Use SysAdmin for both to guarantee object-level edit; handler still enforces
        Profile sys = getSysAdminProfile();
        User owner = makeInternalUser(sys.Id, 'own2', 'owner2');
        insert owner;
        User other = makeInternalUser(sys.Id, 'othr', 'otheruser');
        insert other;

        Case created;
        System.runAs(owner) {
            Account a = ensureAccount();
            created = new Case(Subject = 'Owned by User', Status = openStatus, AccountId = a.Id);
            insert created;
            insert new CaseShare(
                CaseId          = created.Id,
                UserOrGroupId   = other.Id,
                CaseAccessLevel = 'Edit',
                RowCause        = Schema.CaseShare.RowCause.Manual
            );
        }

        Boolean blocked = false;
        System.runAs(other) {
            try {
                created.Status = closedStatus; // non-owner attempt
                created.NATT_Close_Reason__c = 'Other'; // REQUIRED field
                created.NATT_Close_Reason_Explanation__c='Test';
                update created;
            } catch (DmlException e) {
                blocked = true;
                String msg = e.getMessage().toLowerCase();
                System.assert(
                    msg.contains('case owner') && msg.contains('close this case'),
                    'Expected error message not found: ' + e.getMessage()
                );
            }
        }
        System.assertEquals(true, blocked, 'Non-owner should be blocked when not queue member.');
    }

    @IsTest
    static void testNoContainerProfileNoEnforcement() {
        String closedStatus = getAnyClosedStatus();
        String openStatus   = getAnyOpenStatus();
        System.assertNotEquals(null, openStatus,   'Org must have at least one Open status');
        System.assertNotEquals(null, closedStatus, 'Org must have at least one Closed status');

        Profile nonEnf = getNonEnforcementProfileOrNull();
        if (nonEnf == null) {
            System.assert(true, 'No non-enforcement profile found; skipping.');
            return;
        }

        // Owner (enforced)
        Profile enforcementProfile = getEnforcementProfile();
        User owner = makeInternalUser(enforcementProfile.Id, 'stdown', 'stdowner');
        insert owner;

        Case c;
        System.runAs(owner) {
            Account a = ensureAccount();
            c = new Case(Subject = 'No Enforcement', Status = openStatus, AccountId = a.Id);
            insert c;
        }

        // Actor with non-enforcement profile; share to guarantee edit access
        User actor = makeInternalUser(nonEnf.Id, 'stdus', 'standarduser');
        insert actor;
        insert new CaseShare(
            CaseId          = c.Id,
            UserOrGroupId   = actor.Id,
            CaseAccessLevel = 'Edit',
            RowCause        = Schema.CaseShare.RowCause.Manual
        );

        System.runAs(actor) {
            c.Status = closedStatus; // allowed because shouldEnforceForRunningUser() = false
            update c;
        }
        System.assert(true, 'Reached end without exceptions.');
    }
}