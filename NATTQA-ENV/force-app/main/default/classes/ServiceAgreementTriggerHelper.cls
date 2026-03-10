/* Created Apex class to create a CONTAINER_Service_Agreement__share__c records with read access
 * Created by : Rajasekharreddy Kotella
 * Created on : o4-10-2024
 * Class Name : ServiceAgreementTriggerHelper
 * Description : All community users of the ASP account service agreements, as well as those of the Customer Account Users,
 *  are granted read access during the creation of new service agreements. For existing records,
 *  a one-time batch job(ServiceAgreementBatch) will be executed to create sharing records, thereby providing read access to these records.
 */
public class ServiceAgreementTriggerHelper {
	
    public static void ShareServiceAgriment(List<CONTAINER_Service_Agreement__c> SAList) {
        string aspRT = 'CONTAINER Authorized Service Provider';
        Set<Id> accountIds = new Set<Id>();
        Set<Id> accountSet = new Set<Id>();
        Map<Id,Id> saAccMap = new Map<Id,Id>();
        set<string> nonAspUsersEmail = new set<string>();
        
        system.debug('SAList--'+ SAList.size());
        
        Map<Id, CONTAINER_Service_Agreement__c> serviceAgreementMap = new Map<Id, CONTAINER_Service_Agreement__c>();
        List<CONTAINER_Service_Agreement__Share> serviceAgreementShares = new List<CONTAINER_Service_Agreement__Share>();
        
        
        for (CONTAINER_Service_Agreement__c sa : SAList) {
            if (sa.Account__c != null) {
                //accountIds.add(sa.Account__c);
                serviceAgreementMap.put(sa.Id, sa);
                saAccMap.put(sa.Id, sa.Account__c);
            }
        }

        List<CONTAINER_Service_Agreement__c> serviceAgreements = [
            SELECT Id, Account__c, Account__r.RecordType.Name 
            FROM CONTAINER_Service_Agreement__c 
            WHERE Id IN :saAccMap.keySet()
        ];

        for (CONTAINER_Service_Agreement__c serviceAgreement : serviceAgreements) {
            if (serviceAgreement.Account__r.RecordType.Name == aspRT) {
                //authorizedAccounts.add(serviceAgreement.Account__c);
                accountSet.add(serviceAgreement.Account__c);
            }
        }
        
        map<id, id> aspAccIDAccIdMap = new map<id, id>();	
        list<Account> nonASPAccounts = [select id,recordtype.name,Authorized_Service_Provider__c from Account where Authorized_Service_Provider__c =: accountSet ];
        for(Account a: nonASPAccounts){
            aspAccIDAccIdMap.put(a.Authorized_Service_Provider__c, a.Id);
        }
        List<Contact> primaryContacts = [SELECT Id,Email, AccountId, Account.RecordType.Name,account.Authorized_Service_Provider__c, Account.Authorized_Service_Provider__r.RecordType.Name   FROM Contact WHERE  AccountId IN: accountSet OR account.Authorized_Service_Provider__c =: accountSet];
        system.debug('primaryContacts--'+ primaryContacts.size());
        List<Contact> nonASPPrimaryContacts = new List<Contact>();
        Set<Id> aspPrimaryContactIds = new Set<Id>();
        Set<Id> nonAspPrimaryContactIds = new Set<Id>();
        for (Contact contact : primaryContacts) {
            if(contact.Account.RecordType.Name == aspRT){
                aspPrimaryContactIds.add(contact.Id);
            }
            else{
                nonAspPrimaryContactIds.add(contact.Id);
            }
        }

        // Retrieve community users linked to those contacts
        List<User> communityUsers = [
            SELECT Id,contactID, contact.AccountId, Contact.Account.RecordType.Name FROM User 
            WHERE IsActive=true and ( ContactId IN :aspPrimaryContactIds OR ContactId =: nonAspPrimaryContactIds )
        ];
        Map<Id, User> nonASPUserMap = new Map<Id, User>();
        for(user u: communityUsers){
            if(u.Contact.Account.RecordType.Name != aspRT ){
                nonASPUserMap.put(u.ContactId, u);
            }
        }
       
        system.debug('communityUsers--'+ communityUsers.size());

        // Create sharing records for each Service Agreement and associated community users
        for (User user : communityUsers) {
            for (CONTAINER_Service_Agreement__c sa : SAList) {
                if(sa.Account__c == user.contact.accountID  ){ 
                    CONTAINER_Service_Agreement__Share share = new CONTAINER_Service_Agreement__Share();
                    share.ParentId = sa.Id;
                    share.AccessLevel = 'Read'; 
                    share.UserOrGroupId = user.Id;
                    serviceAgreementShares.add(share);
					system.debug('if--'+share);
                }
                else If (aspAccIDAccIdMap.containsKey(saAccMap.get(sa.id)) && aspAccIDAccIdMap.get(saAccMap.get(sa.id)) == user.contact.accountID ){
                    CONTAINER_Service_Agreement__Share share = new CONTAINER_Service_Agreement__Share();
                    share.ParentId = sa.Id;
                    share.AccessLevel = 'Read'; 
                    share.UserOrGroupId = user.Id;
                    serviceAgreementShares.add(share);
                    system.debug('Else--'+share);

                }
            }
        }
        system.debug('serviceAgreementShares--'+ serviceAgreementShares.size());

        if (!serviceAgreementShares.isEmpty()) {
            try {
                Database.insert(serviceAgreementShares, false);
            } catch (Exception e) {
                System.debug('Error inserting share records: ' + e.getMessage());
            }
        }
    }
    
    @InvocableMethod(label='Service Agreement Share' description='Service Agreement Share Access')
    public static void InvokeShareServiceAgriment(List<Id> accIDs) {
        List<CONTAINER_Service_Agreement__c> SAList = new List<CONTAINER_Service_Agreement__c>();
        SAList = [SELECT Id, Account__c, Account__r.RecordType.Name 
                  FROM CONTAINER_Service_Agreement__c  
                  WHERE Account__c In: accIDs];
        ShareServiceAgriment(SAList);

         }
    
}