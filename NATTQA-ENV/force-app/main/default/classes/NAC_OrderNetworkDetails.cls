public class NAC_OrderNetworkDetails {
    
    @InvocableMethod(label='Shipment Email' description='Using this method to send the emails upon shipment of an item ' category='Shipment')
    
    
    public static void sendEmail(List<ID> shipmentIDs) {
        Map<Shipment,Id> mapShipmentWithContact = new Map<Shipment,Id>();
        Map<Shipment,Id> mapShipmentWithUser = new Map<Shipment,Id>();
        Map<Id,Id> mapUserIdWithContactId = new Map<Id,Id>();
        Map<Id,String> mapConIdWithEmail = new Map<Id,String>();
        List<Messaging.SingleEmailMessage> emailList = new List<Messaging.SingleEmailMessage>();
        List<OrgWideEmailAddress> owdList=[select id, Address from OrgWideEmailAddress where Address='donotreply.refrigeration-marketplace@carrier.com' LIMIT 1];
        List<Shipment> shipmentList =[SELECT Id, TrackingNumber,NATT_Order__c,NATT_Order__r.OwnerId, ShipmentNumber 
                                      FROM Shipment where id=:shipmentIDs]; 
        EmailTemplate emailTemp = [Select id, Subject, Body From EmailTemplate Where 
                                   DeveloperName = 'NAOCAP_Order_Shipped_Email' LIMIT 1];                             
        for(Shipment sh:shipmentList){
            mapShipmentWithUser.put(sh,sh.NATT_Order__r.OwnerId);
        }
        List<User> userList = [select id,email,ContactID from user where id IN :mapShipmentWithUser.values()];
        for(User u:userList){
            mapUserIdWithContactId.put(u.Id,u.ContactID);
            mapConIdWithEmail.put(u.ContactID,u.email);
        }
        for(Shipment ship : mapShipmentWithUser.keyset()){
            if(mapUserIdWithContactId.containskey(mapShipmentWithUser.get(ship))){
                mapShipmentWithContact.put(ship,mapUserIdWithContactId.get(mapShipmentWithUser.get(ship)));
            }
        }
        System.debug('mapShipmentWithContact----->'+mapShipmentWithContact);
        for(Shipment sh: mapShipmentWithContact.keyset()){
            List<String> address = new List<String>{mapConIdWithEmail.get(mapShipmentWithContact.get(sh))};
            Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();        
            mail.setTemplateId(emailTemp.Id);       
            mail.setTargetObjectId(mapShipmentWithContact.get(sh));
            if(!owdList.isEmpty()){
                mail.setOrgWideEmailAddressId(owdList[0].id);
            }
            mail.setWhatId(sh.Id);
            mail.setSaveAsActivity(false);
            mail.setToAddresses(address);
            emailList.add(mail);
        }
        System.debug('emailList---->'+emailList); 
        if(!emailList.isEmpty()){
            try{
                Messaging.sendEmail(emailList);
            }
            catch(Exception ex){
                System.debug('Error Occured in send Email : '+ex.getMessage()+ ' Line Number : '+ex.getLineNumber());
            }
        }
        
    }
    
}