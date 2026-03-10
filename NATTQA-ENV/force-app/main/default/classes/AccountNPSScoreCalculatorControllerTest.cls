@isTest
public class AccountNPSScoreCalculatorControllerTest {
    
    /** 
    * @description - Setup data required for testing    
    * @return void
    */
    @testSetup
    static void setupData() {
        User objUser = [SELECT Id FROM User WHERE IsActive = true LIMIT 1];
        System.runAs(objUser) {
            Account objAccount = new Account();
            objAccount.AccountNumber = '1234443232398';
            objAccount.Name = 'Testing Account';
            objAccount.Status__c = 'Active';
            insert objAccount;
            
            Contact objContact = new Contact();
            objContact.AccountId = objAccount.Id;
            objContact.FirstName = 'Testing';
            objContact.LastName = 'User ' + System.now();
            objContact.Email = 'test@123829292sfdc.com';
            insert objContact; 
            
            List<nps_Feedback__c> lstResponses = new List<nps_Feedback__c>();
            for (Integer i = 0; i < 5; i++) {
                nps_Feedback__c objResponse = new nps_Feedback__c();
                objResponse.nps_Contact_Id__c = objContact.Id;
                objResponse.nps_Contact_Email__c = objContact.Email;
                objResponse.nps_Contact_Lastname__c = objContact.LastName;
                objResponse.nps_Contact_Firstname__c = objContact.FirstName;
                objResponse.nps_Account_Id__c = objAccount.Id;
                objResponse.nps_Response_Driver_1__c = 9;
                objResponse.nps_Response_Driver_2__c = 9;
                objResponse.nps_Response_Driver_3__c = 9;
                objResponse.nps_Response_Driver_4__c = 9;
                objResponse.nps_Response_Driver_5__c = 9;
                objResponse.nps_Response_Driver_6__c = 9;
                objResponse.nps_Response_Driver_7__c = 9;
                objResponse.nps_Response_Driver_8__c = 7;
                objResponse.nps_Response_Driver_9__c = 8;
                objResponse.nps_Response_Driver_10__c = 8;
                objResponse.nps_Response_Date__c = System.now();
                
                if (i == 0 || i == 1) {
                    objResponse.nps_Response_Main_score__c = 5;
                } else {
                    objResponse.nps_Response_Main_score__c = 9;
                }
                objResponse.nps_Response_Main_score_comment__c = 'test';
                objResponse.nps_Ticket_Number__c = 'T-4618' + i;
                objResponse.nps_Record_NPS_Id__c = 'R_2ruRV3MXLc2VN50' + i;
                
                lstResponses.add(objResponse);
            }
            
            insert lstResponses;
        }
    }

    /** 
    * @description - test method to check score calculation
    * @return void
    */
    @isTest
    static void calculateScore() {
        Account objAccount = [SELECT Id FROM Account LIMIT 1];
        Test.startTest();
        String strResponse = AccountNPSScoreCalculatorController.calculateScore(objAccount.Id, 'This Year');
        AccountNPSScoreCalculatorController.getWhereClauseBasedOnTimeRange('This Quarter');
        AccountNPSScoreCalculatorController.getWhereClauseBasedOnTimeRange('This Month');
        AccountNPSScoreCalculatorController.getWhereClauseBasedOnTimeRange('Last Year');
        AccountNPSScoreCalculatorController.getWhereClauseBasedOnTimeRange('All Time');
        Test.stopTest();

        Map<String, Object> mapStringToValues = (Map<String, Object>) JSON.deserializeUntyped(strResponse);
        String strMessage = String.valueOf(mapStringToValues.get('strMessage'));
        System.assert(strMessage == 'success', 'Responses not found for the account');        
    }

    /** 
    * @description - test method to check score calculation for account with no responses
    * @return void
    */
    @isTest
    static void calculateScoreWithoutResponse() {
        Account objAccount = [SELECT Id FROM Account LIMIT 1];
        List<nps_Feedback__c> lstResponses = [SELECT Id FROM nps_Feedback__c WHERE nps_Contact_Id__r.AccountId = :objAccount.Id];
        delete lstResponses;

        Test.startTest();
        String strResponse = AccountNPSScoreCalculatorController.calculateScore(objAccount.Id, 'This Year');            
        Test.stopTest();

        Map<String, Object> mapStringToValues = (Map<String, Object>) JSON.deserializeUntyped(strResponse);
        String strMessage = String.valueOf(mapStringToValues.get('strMessage'));
        System.assert(strMessage == 'No responses returned', 'Responses should not exist for this account');
    }
}