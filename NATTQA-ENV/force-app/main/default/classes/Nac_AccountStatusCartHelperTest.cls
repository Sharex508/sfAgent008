@istest
public class Nac_AccountStatusCartHelperTest {
    @isTest
    static void testGetPendingPaymentStatus() {
        Account testAccount = new Account(Name='TestNACAccount',NATT_Organization__c = 'NATT',NATT_Region__c = 'East');
        insert testAccount;
        
        Nac_AccountStatusCartHelper.getPendingPaymentStatus(testAccount.Id);
    }

}