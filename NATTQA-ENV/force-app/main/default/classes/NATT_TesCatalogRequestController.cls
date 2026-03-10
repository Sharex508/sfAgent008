public with sharing class NATT_TesCatalogRequestController {
    @AuraEnabled(cacheable=true)
    public static void sendEmailToController(String name, String company, String email, String street, String city, String state, String postalcode, String country, String toSend, String subject){
        try{
            Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
            String[] toAddresses = new String[] {toSend};
            mail.setToAddresses(toAddresses);
            mail.setSubject(subject);
            mail.setHtmlBody('<h1>'+ 'Catalog Request from ' + company + '</h1>'+
                '<b>Name:</b> ' + name + '<p>' +
                '<b>Company:</b> ' + company + '<p>' +
                '<b>Email:</b> ' + email + '<p>' +
                '<b>Address:</b> ' + street + '<p>' +
                '<b>City:</b> ' + city + ', <b>State:</b> '+state + '<p>' +
                '<b>Postal Code:</b> ' + postalcode + '<p>' +
                '<b>Country:</b> ' + country );
            Messaging.sendEmail(new Messaging.SingleEmailMessage[] { mail });
        }catch(Exception ex){
            throw new AuraHandledException(ex.getMessage());
        }
    }
}