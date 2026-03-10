@IsTest
private class B2BUtilsTest {
	@IsTest(SeeAllData=true)
    static void myUnitTest(){
        String communityId =[SELECT Id, Name FROM Network WHERE Name='Performance Parts'].Id;
        B2BUtils.resolveCommunityIdToWebstoreId(communityId);
        B2BUtils.resolveSortParam('test');
        User thisUser = new User(Id = UserInfo.getUserId());
               
       
           user adminUser = new user();                    
        Test.startTest();
        System.runAs(thisUser) {
            adminUser = createAdminUser(); 
        }
         user portalUser = new user();  
        account a = new account();
        System.runAs(adminUser) {
            a = new Account(Name='TestAccount',NATT_Organization__c = 'NATT',NATT_Region__c = 'East');
            insert a;
            Contact contact = new Contact(LastName='TestContact', AccountId=a.Id);
            insert contact;
            portalUser = createUser(contact.Id); 
        }
        Test.stopTest();
        System.runAs(portalUser){        
        	B2BUtils.getUserAccount();
            B2BUtils.getLoginURL();
        }
    }
    
    private static user createUser(String cId){
        Profile profile = [SELECT Id FROM Profile WHERE Name='B2B Customer Community User' LIMIT 1];
        User user = new User(Alias='buyer', Email='buyer@example.com', LastName='Buyer2', ContactId=cId,
                             TimeZoneSidKey='GMT',  LocaleSidKey='en_US',  Username='buyer2@example.com',
                             EmailEncodingKey='UTF-8', ProfileId=profile.Id, LanguageLocaleKey='en_US' );
        insert user;
        
        PermissionSet ps = [SELECT Id FROM PermissionSet WHERE Name='B2B_Commerce_User'];
        PermissionSetAssignment psa = new PermissionSetAssignment(PermissionSetId = ps.Id, AssigneeId = user.Id);
        insert psa; 
        return user;
    }
      private static user createAdminUser(){
        Profile profile = [SELECT Id FROM Profile WHERE Name='System Administrator' LIMIT 1];
        UserRole role = [SELECT Id FROM UserRole where PortalType ='None'  LIMIT 1];
        User user = new User(Alias='buyer', Email='Portal@example.com', LastName='Portal12', userRoleId = role.Id,
                             TimeZoneSidKey='GMT',  LocaleSidKey='en_US',  Username='portaluser12@example.com',
                             EmailEncodingKey='UTF-8', ProfileId=profile.Id, LanguageLocaleKey='en_US' );
        insert user; 
        return user;
    }
}