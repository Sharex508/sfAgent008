public without sharing class NATT_DeleteContactPointAddresses {
    /**
     * Class used to avoid Delete permission restriction
     */
    @AuraEnabled
    public static void deleteContactPointAddress(ContactPointAddress conPointAddress){
        delete conPointAddress;
    } 
}