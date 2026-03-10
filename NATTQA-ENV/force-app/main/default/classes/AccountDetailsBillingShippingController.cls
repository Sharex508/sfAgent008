/**
 * @class AccountDetailsBillingShippingController
 * @description This class provides a method to fetch related Billing and Shipping 
 *              addresses for a given Account.
 * @author Vamsi Mogidi
 * @createdDate 2024-12-12
 * @TestClass AccountDetailsControllerTest
 */
public class AccountDetailsBillingShippingController {

    /**AccountDetailsBillingShippingController.getRelatedAddresses();
     * @method getRelatedAddresses
     * @description Retrieves a list of Billing and Shipping addresses associated 
     *              with a specific Account.
     * @param accountId The Id of the Account whose related addresses are to be fetched.
     * @return A list of NATT_Address__c records representing the related addresses.
     * @developer Vamsi Mogidi
     * @example Example usage: List<NATT_Address__c> addresses = AccountDetailsBillingShippingController.getRelatedAddresses(accountId);
     */
    @AuraEnabled(cacheable=true)
    public static List<NATT_Address__c> getRelatedAddresses(Id accountId) {
        // Query to fetch related addresses of the specified Account
        return [
            SELECT Name, NATT_Type__c, NATT_Street__c, NATT_City__c, 
                   NATT_State_Province__c, NATT_Zip_Postal_Code__c
            FROM NATT_Address__c
            WHERE NATT_Account__c = :accountId
        ];
    }
    @AuraEnabled(cacheable=true)
    public static Account getAccountInfo(Id accountId) {
        // Query to fetch related addresses of the specified Account
        return [
            select Id, Name, RecordType.name, NATT_Dealership__c , NATT_Dealership__r.RecordType.name 
            from Account 
            where id = :accountId
        ];
    }
}