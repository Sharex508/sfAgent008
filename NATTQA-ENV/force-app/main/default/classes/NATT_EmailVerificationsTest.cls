@isTest
public class NATT_EmailVerificationsTest {
    @isTest
   public static void testInitiateEmailVerification() {
        // Create a test user
        Profile p = [SELECT Id FROM Profile WHERE Name='Standard User' LIMIT 1];
        User testUser = new User(
            FirstName = 'Test',
            LastName = 'User',
            Email = 'testuser@example.com',
            Username = 'testuser@example.com.' + System.currentTimeMillis(),
            Alias = 'tuser',
            TimeZoneSidKey = 'America/Los_Angeles',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US',
            ProfileId = p.Id
        );
        insert testUser;
       
		Test.startTest();
        String result = NATT_EmailVerifications.InitiateEmailVerification(testUser.Id);
        Test.stopTest();
        System.assertEquals('Data processed successfully!', result, 'The method should return the expected success message.');

       

   }

}