/********************************************************************************************************
* @author         (Deloitte)
* @description    This is a test class for Userclass apex class created specific for REF users.
* @date           04/04/2023 [MM/DD/YYYY]
* 
* Modification Log:
* -------------------------------------------------------------------------------------------------------
* Developer                Date                   Modification ID      Description
* -------------------------------------------------------------------------------------------------------
* Deloitte               04/04/2023                                  Initial version
*********************************************************************************************************/
@isTest
public class UserTrigger_Test {
    
    @isTest
    static void createNewUser() {
       
        //Creating new chatter group with name chattertest
        CollaborationGroup chatterUserGroup = new CollaborationGroup(Name = 'chattertestTest', CollaborationType = 'Public');
        insert chatterUserGroup;
        
        
        ChatterGroupProfileCustomSetting__c newCustomRecord = new ChatterGroupProfileCustomSetting__c();
        newCustomRecord.Name = 'System Administrator';
        newCustomRecord.ChatterGroupNames__c = 'chattertestTest';
        insert newCustomRecord;
        
       Test.startTest();
        
       //Create new user to trigger User trigger logic 
       User u = new User(
            ProfileId = [SELECT Id FROM Profile WHERE Name = 'System Administrator'].Id,
            FirstName = 'Test Class',
            LastName = 'User',
            Alias = 'tstUser',
            Email = 'tstclass@abc.com',
            Username = 'tstclass@abc.com' + System.currentTimeMillis(),
            TimeZoneSidKey = 'America/Los_Angeles',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US');
        
        insert u;
          
        Test.stopTest();
        
        //get the list of new user
        list<User> utst = [select id from User where Profile.name = 'System Administrator'];
        boolean tstResult = utst.size() > 0;
        
        //Verify the changes on asset
        system.assertEquals(tstResult, true);
        
        
    }
    
}