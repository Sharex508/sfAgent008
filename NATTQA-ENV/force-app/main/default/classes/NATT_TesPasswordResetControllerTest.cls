@IsTest
private class NATT_TesPasswordResetControllerTest implements HttpCalloutMock {
    public HttpResponse respond(HTTPRequest req){
        HttpResponse res = new HttpResponse();
        res.setStatus('OK');
        res.setHeader('sitekey', '6LeIxAcTAAAAAJcZVRqyHh71UMIEGNQ_MXjiZKhI');
        res.setBody('{"success":"true"}');
        res.setStatusCode(200);
        return res;
    }

    @IsTest
    static void validateButton_Test(){
        String recaptchaValue = '6LeIxAcTAAAAAJcZVRqyHh71UMIEGNQ_MXjiZKhI';
        //String recaptchaValue = '03AGdBq27zf8aysxCp_QO-CY44YeJCUi7W1QCjjej9qBnWC_fjnShPuufXFIafkZo7CyRpbAXcTfNeVFfJ0QL2eLOvlLc30OY4RjVhq99rbAqD4Y2wVM-XVAm5j2f0LT82HNb8SZDawJBdR9nQDpIQfabVI99QPDpNE-fTX89VWAuKr1dwfEBKIbIGZ_6a7oVEhDqTdVk-Jj6LJFybOlL-SIWW83iovM7ZK52vXnRQrTBhtqwOiAkFyzw_4jU2sAGrysXLS3THN-IgZhOXTk103KFN_8RZDuWn1woqCyubujWJOXspVNM_Se4pA1dEmf-KF6xDik-13Io9j2t-_a6Hz9NhLsRIy-uFiukS7y2N7FmDEZsdo-UP4WR2Ahcb1mVaWpyViXAyJ9V1PDCuwmki0IQVn00n_jSaFdCUzMIBUjYoDW0JS2sPGCMLgay38qv6CRFH7X8R4uia6AIBmiAH-w3mP7q2JcB9899KfUd2P7aNwSWjysFUdbhFn6F3dLmq68vrS_35YVss';
        String returnValue = null;
        Test.startTest();
        Test.setMock(HttpCalloutMock.class, new NATT_TesPasswordResetControllerTest());
        // String returnValue = NATT_PasswordResetController.validateButton((String)mapValue.get('key'));
        returnValue = NATT_TesPasswordResetController.validateButton(recaptchaValue);

        System.debug('return value: ' + returnValue);
        Test.stopTest();
    }

    @IsTest
    static void insertRecord_Test(){
        String recaptchaValue = '6LeIxAcTAAAAAJcZVRqyHh71UMIEGNQ_MXjiZKhI';
        //String recaptchaValue = '03AGdBq27zf8aysxCp_QO-CY44YeJCUi7W1QCjjej9qBnWC_fjnShPuufXFIafkZo7CyRpbAXcTfNeVFfJ0QL2eLOvlLc30OY4RjVhq99rbAqD4Y2wVM-XVAm5j2f0LT82HNb8SZDawJBdR9nQDpIQfabVI99QPDpNE-fTX89VWAuKr1dwfEBKIbIGZ_6a7oVEhDqTdVk-Jj6LJFybOlL-SIWW83iovM7ZK52vXnRQrTBhtqwOiAkFyzw_4jU2sAGrysXLS3THN-IgZhOXTk103KFN_8RZDuWn1woqCyubujWJOXspVNM_Se4pA1dEmf-KF6xDik-13Io9j2t-_a6Hz9NhLsRIy-uFiukS7y2N7FmDEZsdo-UP4WR2Ahcb1mVaWpyViXAyJ9V1PDCuwmki0IQVn00n_jSaFdCUzMIBUjYoDW0JS2sPGCMLgay38qv6CRFH7X8R4uia6AIBmiAH-w3mP7q2JcB9899KfUd2P7aNwSWjysFUdbhFn6F3dLmq68vrS_35YVss';
        String returnValue = null;
        Test.startTest();
        Test.setMock(HttpCalloutMock.class, new NATT_TesPasswordResetControllerTest());
        // String returnValue = NATT_PasswordResetController.validateButton((String)mapValue.get('key'));
        returnValue = NATT_TesPasswordResetController.insertRecord(null, recaptchaValue);

        System.debug('return value: ' + returnValue);
        Test.stopTest();
    }

    @IsTest
    static void resetPassword_Test(){
        Account testAccount = new Account(
            Name='Test',
            RecordTypeId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('Dealer').getRecordTypeId()
            );
        insert testAccount;
        Contact testContact = new Contact(
            AccountId=testAccount.Id,
            FirstName='Test',
            LastName='User',
            NATT_Key_Business_Role__c='Principal',
            RecordTypeId = Schema.SObjectType.Contact.getRecordTypeInfosByDeveloperName().get('NATT_Dealer').getRecordTypeId()
            );
        insert testContact;
        Profile profileId = [SELECT Id FROM Profile WHERE Name = 'B2B Customer Community User' LIMIT 1];
        User testUser = new User(
            
            Username = 'Test@User.com', 
            LastName = 'Tuser', 
            Email = 'test@testUser.com', 
            Alias = 'tusr', 
            TimeZoneSidKey = 'America/New_York', 
            LocaleSidKey = 'en_US', 
            EmailEncodingKey = 'ISO-8859-1', 
            LanguageLocaleKey = 'en_US',
            ProfileId = profileId.Id,
            ContactId = testContact.Id);
            
        insert testUser;
        String emailAddress = 'test@testUser.com';
        Test.startTest();
        Boolean emailCheck = NATT_TesPasswordResetController.resetPassword(emailAddress);

        System.debug('return value: ' + emailCheck);
        Test.stopTest();
    }

    

    
//   @testSetup static void init() {
//     insert new (PublicKey__c = 'public',SecretKey__c = 'private');
//   }

//   @isTest static void testVerify() {
//     Test.setMock(HttpCalloutMock.class, new NATT_PasswordResetControllerTest());
//     Test.startTest();
//     reCaptcha.verify('response', new Map<String,String>{'X-Salesforce-SIP' => 'Salesforce'});
//     Test.stopTest();
//   }

//   @isTest static void testVerifyOverload() {
//     Test.setMock(HttpCalloutMock.class,new NATT_PasswordResetControllerTest());
//     Test.startTest();
//     reCaptcha.verify('response');
//     Test.stopTest();
//   }

//   @isTest static void testRemoteHost() {
//     reCaptcha.remoteHost(new Map<String, String>{'x-original-remote-addr'=>''});
//     reCaptcha.remoteHost(new Map<String, String>{'X-Salesforce-SIP'=>''});
//   }

//   @isTest static void testVerifyError() {
//     reCaptcha.verify('response', new Map<String,String>{'X-Salesforce-SIP' => 'Salesforce'});
//   }

//   public class GoogleHTTPCalloutMock implements HttpCalloutMock {
//     // Implement this interface method
//     public HTTPResponse respond(HTTPRequest req) {
//       // Create a fake response
//       HttpResponse res = new HttpResponse();
//       res.setHeader('Content-Type', 'application/json');
//       res.setBody('{"success":"true"}');
//       res.setStatusCode(200);
//       return res;
//     }
//   }

    
}