public without sharing class ShipmentTriggerHandlerNatt extends ShipmentTriggerHandlerAbstract{
    public override void handleAfterInsert(Map<Id,SObject> trgNewMap){
        Map<Id,Shipment> newMap = (Map<Id,Shipment>)trgNewMap;
        Set<Id> shipmentIdSet = new Set<Id>();
        List<Messaging.SingleEmailMessage> emList = new List<Messaging.SingleEmailMessage>();

        for(Shipment s : newMap.values()){
            if(String.isNotBlank(s.NATT_Transaction_Id__c) && s.NATT_JDEInvoiceAmount__c!=null){                
                if(String.isBlank(s.NATT_AuthorizeDotNetProfileId__c) || String.isBlank(s.NATT_Transaction_Payment_Id__c)){
                    s.addError('This shipment does not have a valid authorize.net payment profile.');
                }else{                    
                    shipmentIdSet.add(s.Id);
                }
            }
            if(String.isNotBlank(s.NATT_OrderWarehouse__c) && s.NATT_OrderWarehouse__c=='TES'){
                Messaging.SingleEmailMessage em = new Messaging.SingleEmailMessage();
                em.setWhatId(s.Id);
                em.setTargetObjectId(s.NATT_OrderOwnerId__c);
                em.setSaveAsActivity(false);
                emList.add(em);        
            }
        }
        if(!shipmentIdSet.isEmpty()){
            //void the previous transaction and capture the payment
            NattTesAuthorizeDotNet.processShipment(shipmentIdSet);
        }
        if(!emList.isEmpty()){
            List<EmailTemplate> eTemplateList = [SELECT Id FROM EmailTemplate WHERE DeveloperName='TES_Shipment_Notification'];
            if(!eTemplateList.isEmpty()){
                for(Messaging.SingleEmailMessage em : emList){
                    em.TemplateId=eTemplateList.get(0).Id;                    
                }

                Messaging.sendEmail(emList);               
            }
        }
    }
}