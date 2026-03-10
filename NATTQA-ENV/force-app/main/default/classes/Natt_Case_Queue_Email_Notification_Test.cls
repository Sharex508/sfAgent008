@IsTest
public class Natt_Case_Queue_Email_Notification_Test {
    
    @Istest
    public static void crateCase(){
        try{
            Contact cnt = new contact();
            User communityUser = new user();
            User thisUser = new User(Id = UserInfo.getUserId());
            id UserRoleid = [SELECT Id FROM UserRole WHERE Name = 'NA Units Manager' LIMIT 1 ].Id;
            thisUser.UserRoleId = UserRoleid;
            System.runAs(thisUser) {
                update thisUser;
                Account acc = new Account(
                    Name='Test Dealer Natt',
                    NATT_Customer_Price_Group__c='BCO',
                    NATT_Organization__c = 'NATT',
                    NATT_Region__c = 'East',
                    //IsPartner = true,
                    RecordTypeId=Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('Dealer').getRecordTypeId()
                );
                insert acc;
                cnt=NAC_TestDataFactory.insertAssociatedContact(acc);
                Profile profile = [SELECT Id FROM Profile WHERE Name='NATT Parts and Service Community' LIMIT 1];
                
                communityUser = new User(Alias='CTMComm', Email='buyer@example.com', LastName='Buyer',
                                         TimeZoneSidKey='GMT', LocaleSidKey='en_US', Username= 'CTMCommunityUser321'+'@example.com',
                                         EmailEncodingKey='UTF-8', ProfileId=profile.Id, LanguageLocaleKey='en_US',
                                         ContactId=cnt.Id);
                insert communityUser;
            }
            system.runAs(communityUser){
                Test.startTest();
                Case cs = new Case();
                cs.Status = 'New';
                cs.Type = 'Information';
                cs.RecordTypeId = Schema.SObjectType.Case.getRecordTypeInfosByName().get('CTM Performance Parts').getRecordTypeId();
                insert cs;
                Test.stopTest();
            } 
        }
        catch(exception e ){
            system.debug(e.getlinenumber()+' -  '+ e);
        }
        
    }
     @Istest
    public static void getQueueMemberslist(){
        try{
            test.startTest();
            Group testGroup = new Group();
            testGroup.Name = 'testGroup';
            testGroup.DeveloperName = 'ABC';
            testGroup.type = 'Queue';
            insert testGroup;
            Natt_Case_Queue_Email_Notification.getQueueMemberslist(new set<Id>{testGroup.Id});
            test.stopTest();
        }
        catch(exception e){
            
        }
    }
}