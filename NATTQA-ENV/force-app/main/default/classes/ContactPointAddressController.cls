public with sharing class ContactPointAddressController {
    
    
    @AuraEnabled
    public static Id upsertContactPointAddress(Id recordId,String name, String street, String state, String country, String postalCode, String city, Id parentId){
            ContactPointAddress cpa;
            Id recordTypeId = Schema.SObjectType.ContactPointAddress.getRecordTypeInfosByDeveloperName().get('NATT_Parts_Address').getRecordTypeId();
               
            if (recordId != null) {
                cpa = [SELECT Id FROM ContactPointAddress WHERE Id = :recordId LIMIT 1];
            } else {
                cpa = new ContactPointAddress();
                cpa.ParentId = parentId;
                cpa.RecordTypeId = recordTypeId;
                cpa.AddressType = 'Shipping';
            }
        
            cpa.Name = name;
            cpa.Street = street;
            cpa.State = state;
            cpa.Country = country;
            cpa.PostalCode = postalCode;
            cpa.City = city;
        
            upsert cpa;
            return cpa.Id;
 
      }


}