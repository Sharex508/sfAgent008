@isTest
public class UpdateUserQueueUCP_Test {
    
    @isTest
    static void testAddAndRemoveUsersBasedOnActiveStatus() {
        // Create a public group
        Group publicGroup1 = new Group(
            Name = 'Test Public Group 1',
            DeveloperName = 'Test_Public_Group_1',
            Type = 'Regular'
        );
        Group publicGroup2 = new Group(
            Name = 'Test Public Group 2',
            DeveloperName = 'Test_Public_Group_2',
            Type = 'Regular'
        );
        insert new List<Group>{publicGroup1, publicGroup2};
            
            // Create test users
            Profile profile = [SELECT Id FROM Profile WHERE Name = 'System Administrator' LIMIT 1];
        User activeUser = new User(
            ProfileId = profile.Id,
            FirstName = 'Active',
            LastName = 'User',
            Alias = 'actuser',
            Email = 'activeuser@example.com',
            Username = 'activeuser@example.com' + System.currentTimeMillis(),
            TimeZoneSidKey = 'America/Los_Angeles',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US'
        );
        User inactiveUser = new User(
            ProfileId = profile.Id,
            FirstName = 'Inactive',
            LastName = 'User',
            Alias = 'inAct12',
            Email = 'inactiveuser@example.com',
            Username = 'inactiveuser@example.com' + System.currentTimeMillis(),
            TimeZoneSidKey = 'America/Los_Angeles',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US'
        );
        insert new List<User>{activeUser, inactiveUser};
            
            // Add an existing group member to simulate removal of an inactive user
            GroupMember existingMember = new GroupMember(
                UserOrGroupId = inactiveUser.Id,
                GroupId = publicGroup1.Id
            );
        insert existingMember;
        
        // Prepare test data for the Queueable class
        UpdateUserQueueUCP.GroupAssignmentRequest activeRequest = new UpdateUserQueueUCP.GroupAssignmentRequest();
        activeRequest.userId = activeUser.Id;
        activeRequest.groupId = publicGroup2.Id;
        activeRequest.userIsActive = true;
        
        UpdateUserQueueUCP.GroupAssignmentRequest inactiveRequest = new UpdateUserQueueUCP.GroupAssignmentRequest();
        inactiveRequest.userId = inactiveUser.Id;
        inactiveRequest.groupId = publicGroup1.Id;
        inactiveRequest.userIsActive = false;
        
        List<UpdateUserQueueUCP.GroupAssignmentRequest> requests = new List<UpdateUserQueueUCP.GroupAssignmentRequest>{activeRequest, inactiveRequest};
            
            // Start test execution
            Test.startTest();
        UpdateUserQueueUCP.addUsersToGroup(requests);
        Test.stopTest();
        
        // Verify the active user is added to the correct group
        List<GroupMember> groupMembers = [
            SELECT Id, UserOrGroupId, GroupId 
            FROM GroupMember
            WHERE GroupId = :publicGroup2.Id
        ];
        System.assertEquals(1, groupMembers.size(), 'Active user should be added to the correct group.');
        System.assertEquals(activeUser.Id, groupMembers[0].UserOrGroupId, 'The active user should be added to the correct group.');
        
        // Verify the inactive user is removed from all groups
        List<GroupMember> removedGroupMembers = [
            SELECT Id 
            FROM GroupMember 
            WHERE UserOrGroupId = :inactiveUser.Id
        ];
        System.assertEquals(0, removedGroupMembers.size(), 'Inactive user should be removed from all groups.');
    }
    
    //Added bu Rajasekharreddy Kotella for UCP Service agreement Share
    @IsTest 
    static void ServiceAgreementShare(){
        Account a = new Account(Name='TestAccount',
                                NATT_Organization__c = 'NATT',
                                NATT_Region__c = 'East',
                                RecordTypeId=Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('CONTAINER_Authorized_Service_Provider').getRecordTypeId()
                               );
        insert a;
        CONTAINER_Service_Agreement__c serviceAgreement = new CONTAINER_Service_Agreement__c(
                Account__c = a.Id
            );
            insert serviceAgreement;
        Contact contact = new Contact(LastName='TestContact', AccountId=a.Id);
        insert contact;
        string cntId = contact.Id;
        user thisUser = new User(Id = UserInfo.getUserId());
        user adminUser = new user();
        system.runAs(thisUser){
            
            adminUser = createAdminUser();
        }
        user commUser = new user();
        Account a1 = new Account();
        WebCart cart = new WebCart();
        Product2 testProduct = new Product2();
        CartDeliveryGroup cartDeliveryGroup = new CartDeliveryGroup();
        CartDeliveryGroupMethod  cartdeliverymethod = new CartDeliveryGroupMethod();
        system.runAs(adminUser){
            a1 = new Account(Name='TestAccount',NATT_Organization__c = 'NATT',NATT_Region__c = 'East');
            insert a1;
            Contact contact1 = new Contact(LastName='TestContact', AccountId=a1.Id);
            insert contact1;
            string cntId1 = contact1.Id;
            commUser = createUser(contact1.Id);
            
        }
        
    }
    private static user createUser(String cId){
        Profile profile = [SELECT Id FROM Profile WHERE Name='UCP Profile' LIMIT 1];
        User user = new User(Alias='buyer', Email='buyer@example.com', LastName='Buyer1', ContactId=cId,
                             TimeZoneSidKey='GMT',  LocaleSidKey='en_US',  Username='buyer14@example.com',
                             EmailEncodingKey='UTF-8', ProfileId=profile.Id, LanguageLocaleKey='en_US' );
        insert user;
        
       // PermissionSet ps = [SELECT Id FROM PermissionSet WHERE Name='B2B_Commerce_User'];
       // PermissionSetAssignment psa = new PermissionSetAssignment(PermissionSetId = ps.Id, AssigneeId = user.Id);
       // insert psa; 
        return user;
    }
    private static user createAdminUser(){
        Profile profile = [SELECT Id FROM Profile WHERE Name='System Administrator' LIMIT 1];
        UserRole role = [SELECT Id FROM UserRole where PortalType ='None'  LIMIT 1];
        User user = new User(Alias='UCPADm', Email='ADMUser@example.com', LastName='PortalADM', userRoleId = role.Id,
                             TimeZoneSidKey='GMT',  LocaleSidKey='en_US',  Username='portaluserADM@example.com',
                             EmailEncodingKey='UTF-8', ProfileId=profile.Id, LanguageLocaleKey='en_US' );
        insert user; 
        return user;
    }
    
    
}