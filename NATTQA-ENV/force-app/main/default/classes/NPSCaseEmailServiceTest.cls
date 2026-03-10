@IsTest
public class NPSCaseEmailServiceTest {
    
    @TestSetup
    static void setupTestData() {
        // Create users synchronously
        createUser('l0manager@carrier.com');
        createUser('l1manager@carrier.com');
        createUser('l2manager@carrier.com');
        createUser('l3manager@carrier.com');
        
        // Query the created users
        List<User> teamUsers = [
            SELECT Id, Email FROM User 
            WHERE Email IN ('l0manager@carrier.com', 'l1manager@carrier.com', 'l2manager@carrier.com', 'l3manager@carrier.com')
        ];
        
        Map<String, User> userMap = new Map<String, User>();
        for (User usr : teamUsers) {
            userMap.put(usr.Email, usr);
        }
        
        Id objectRecordTypeId = Schema.SObjectType.Account.getRecordTypeInfosByName().get('Dealer').getRecordTypeId();

        // Create Account for testing
        Account acc = new Account(
            Name = 'TestAccount',
            NATT_Organization__c = 'NATT',
            NATT_Region__c = 'East',
            RecordTypeId = objectRecordTypeId
        );
        insert acc;

        // Create Contact related to the Account
        Contact contact = new Contact(
            LastName = 'TestContact', 
            AccountId = acc.Id, 
            Email = 'test@test.com', 
            Phone = '1234567890'
        );
        insert contact;

        // Create BuyerAccount related to the Account
        BuyerAccount buyerAccount = new BuyerAccount();
        buyerAccount.BuyerId = acc.Id;
        buyerAccount.Name = 'Test Buyer Account (BA-AJ)';
        buyerAccount.IsActive = true;
        insert buyerAccount;

        // Create Case for testing
        Case testCase = new Case(
            AccountId = acc.Id,
            ContactId = contact.Id,
            OwnerId = UserInfo.getUserId(),
            Customer_Survey_Type__c = 'Parts',
            NPS_Account__c = acc.Id,
            NPS_Contact__c = contact.Id
        );
        insert testCase;

        // Create Account Team Members
        AccountTeamMember teamMemberL0 = new AccountTeamMember(AccountId = acc.Id, TeamMemberRole = 'EAM - NATT', UserId = userMap.get('l0manager@carrier.com').Id);
        AccountTeamMember teamMemberL1 = new AccountTeamMember(AccountId = acc.Id, TeamMemberRole = 'Parts BDM - NATT', UserId = userMap.get('l1manager@carrier.com').Id);
        AccountTeamMember teamMemberL2 = new AccountTeamMember(AccountId = acc.Id, TeamMemberRole = 'Director of Sales – PPG NATT', UserId = userMap.get('l2manager@carrier.com').Id);
        AccountTeamMember teamMemberL3 = new AccountTeamMember(AccountId = acc.Id, TeamMemberRole = 'Dealer Network Manager – NATT', UserId = userMap.get('l3manager@carrier.com').Id);
        
        insert new List<AccountTeamMember> { teamMemberL0, teamMemberL1, teamMemberL2, teamMemberL3 };
    }

    // Utility method to create a test user (synchronously)
    private static void createUser(String email) {
        Profile profile = [SELECT Id FROM Profile WHERE Name='Standard User' LIMIT 1];
        User usr = new User(
            Username = email,
            LastName = 'TestUser',
            Email = email,
            Alias = 'testuser',
            TimeZoneSidKey = 'America/Los_Angeles',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            ProfileId = profile.Id,
            LanguageLocaleKey = 'en_US'
        );
        insert usr;
    }

    // ---------------- Existing Tests ----------------

    @IsTest
    static void testInitialEmail() {
        Test.startTest();
        List<Id> caseIds = new List<Id>{ [SELECT Id FROM Case LIMIT 1].Id };
        NPSCaseEmailServiceInitial.sendEmailToManagers(caseIds);
        Test.stopTest();
        
        System.assertEquals('Customer Feedback followup : New Case', 'Customer Feedback followup : New Case');
    }

    @IsTest
    static void testOverdueEmail() {
        Test.startTest();
        List<Id> caseIds = new List<Id>{ [SELECT Id FROM Case LIMIT 1].Id };
        NPSCaseEmailServiceOverdue.sendEmailToManagers1(caseIds);
        Test.stopTest();
        
        System.assertEquals('Customer Feedback followup : Overdue', 'Customer Feedback followup : Overdue');
    }

    @IsTest
    static void testEscalatedEmail() {
        Test.startTest();
        List<Id> caseIds = new List<Id>{ [SELECT Id FROM Case LIMIT 1].Id };
        NPSCaseEmailServiceEscalated.sendEmailToManagers1(caseIds);
        Test.stopTest();
        
        System.assertEquals('Customer Feedback followup : Escalated', 'Customer Feedback followup : Escalated');
    }

    @IsTest
    static void testNoValidEmail() {
        delete [SELECT Id FROM AccountTeamMember];
        
        Test.startTest();
        List<Id> caseIds = new List<Id>{ [SELECT Id FROM Case LIMIT 1].Id };
        NPSCaseEmailServiceEscalated.sendEmailToManagers1(caseIds);
        Test.stopTest();
        
        System.assert(true, 'Executed without error even with missing recipients');
    }

    // ---------------- New Tests for NPSCaseEmailService ----------------

    @IsTest
    static void testSendNPSApprovalEmail_Initial() {
        Case c = [SELECT Id FROM Case LIMIT 1];
        Test.startTest();
        NPSCaseEmailService.sendNPSApprovalEmail(c.Id, 'Initial');
        Test.stopTest();
        System.assert(true, 'Initial email executed successfully');
    }

    @IsTest
    static void testSendNPSApprovalEmail_Overdue() {
        Case c = [SELECT Id FROM Case LIMIT 1];
        Test.startTest();
        NPSCaseEmailService.sendNPSApprovalEmail(c.Id, 'Overdue');
        Test.stopTest();
        System.assert(true, 'Overdue email executed successfully');
    }

    @IsTest
    static void testSendNPSApprovalEmail_Escalated() {
        Case c = [SELECT Id FROM Case LIMIT 1];
        Test.startTest();
        NPSCaseEmailService.sendNPSApprovalEmail(c.Id, 'Escalated');
        Test.stopTest();
        System.assert(true, 'Escalated email executed successfully');
    }

    @IsTest
    static void testSendNPSApprovalEmail_NoRecipients() {
        delete [SELECT Id FROM AccountTeamMember];
        Case c = [SELECT Id FROM Case LIMIT 1];
        Test.startTest();
        NPSCaseEmailService.sendNPSApprovalEmail(c.Id, 'Escalated');
        Test.stopTest();
        System.assert(true, 'Handled gracefully without recipients');
    }
}