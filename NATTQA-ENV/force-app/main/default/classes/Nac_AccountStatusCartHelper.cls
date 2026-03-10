public class Nac_AccountStatusCartHelper {
    
    @AuraEnabled(Cacheable=true)
    public static string  getPendingPaymentStatus(Id AccId){
       Account obj = [Select Id,Name,NAC_Hold_Status__c from Account where Id = : AccId Limit 1];
       return obj.NAC_Hold_Status__c;
       
    }

}