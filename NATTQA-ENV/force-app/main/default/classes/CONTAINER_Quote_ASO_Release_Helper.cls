public WITHOUT SHARING class CONTAINER_Quote_ASO_Release_Helper {

    public static void Container_Quote_ASO_Release(List<SBQQ__QuoteDocument__c> quoteDocList){
        List<String> quoteId = new List<String>();
        for(SBQQ__QuoteDocument__c quoteDoc : quoteDocList){
            system.debug('-------Quote Docuemnt -----------');
            system.debug(quoteDoc);
            quoteId.add(quoteDoc.SBQQ__Quote__c);
            system.debug('-------Quote record-----------');
            system.debug(quoteId);
        }
        List<SBQQ__Quote__c> quoteList=[select Id,CONTAINER_ASO_ID__c,CONTAINER_ASO_Rev__c,RecordTypeId from SBQQ__Quote__c where id=:quoteId];
        system.debug(quoteList);       
        
        if(!quoteList.isEmpty()){
            for(SBQQ__QuoteDocument__c quoteDoc : quoteDocList){
                for(SBQQ__Quote__c quote : quoteList){
                    if((quote.RecordTypeId ==  Schema.SObjectType.SBQQ__Quote__c.getRecordTypeInfosByName().get('Container GENSET Quote').getRecordTypeId()) || (quote.RecordTypeId == Schema.SObjectType.SBQQ__Quote__c.getRecordTypeInfosByName().get('Container NT Quote').getRecordTypeId())){
                        
                        if(quote.CONTAINER_ASO_Rev__c != null){
                            quoteDoc.CustomName__c = 'ASO_'+quote.CONTAINER_ASO_ID__c+'-'+quote.CONTAINER_ASO_Rev__c;
                        }else{
                            quoteDoc.CustomName__c = 'ASO_'+quote.CONTAINER_ASO_ID__c;
                        }
                    }
                }
            }            
        }
    }
    public static void sendQuoteDocumentEmailwithAttachment(List<SBQQ__QuoteDocument__c> quoteDocList){
        if(!quoteDocList.isEmpty())
        {
            List<String> quoteId = new List<String>();
            List<Id> listDocId = new List<Id>();
            List<Messaging.SingleEmailMessage> listEmailMessages = new List<Messaging.SingleEmailMessage>();
            for(SBQQ__QuoteDocument__c quoteDoc : quoteDocList){
                quoteId.add(quoteDoc.SBQQ__Quote__c);
            }
            List<SBQQ__Quote__c> quoteList=[select Id,CONTAINER_ASO_ID__c,CONTAINER_ASO_Rev__c,RecordTypeId,CONTAINER_Sales_Region__c from SBQQ__Quote__c where id=:quoteId];   
            EmailTemplate template = [Select id, name, isActive from EmailTemplate
                                      Where name =: ContainerConstants.CONTAINER_Quote_ASO_Template];
            if(!quoteList.isEmpty()){
                for(SBQQ__QuoteDocument__c quoteDoc : quoteDocList){
                    for(SBQQ__Quote__c quote : quoteList){
                        listDocId.clear();
                        Messaging.SingleEmailMessage sendMail = new Messaging.SingleEmailMessage();
                        String groupNameASO ='';
                        //In NT - We don't need to forward the notification
                        //   if((quote.RecordTypeId ==  Schema.SObjectType.SBQQ__Quote__c.getRecordTypeInfosByName().get('Container GENSET Quote').getRecordTypeId()) || (quote.RecordTypeId == Schema.SObjectType.SBQQ__Quote__c.getRecordTypeInfosByName().get('Container NT Quote').getRecordTypeId()))
                       if((quote.RecordTypeId ==  Schema.SObjectType.SBQQ__Quote__c.getRecordTypeInfosByName().get('Container GENSET Quote').getRecordTypeId())){
                            if(template.Id != null && template.IsActive == true)
                            {
                                sendMail.setTemplateId(template.Id);  // Email template Id
                                if(quoteDoc.SBQQ__DocumentId__c != null){
                                    listDocId.add(quoteDoc.SBQQ__DocumentId__c);
                                }
                                system.debug('Quote document id = '+quoteDoc.Id);
                                system.debug('Document id ='+quoteDoc.SBQQ__DocumentId__c);
                                system.debug('Document Ids-----'+listDocId);
                                sendMail.setEntityAttachments(listDocId); // Quote document Id
                                sendMail.setTargetObjectId(UserInfo.getUserId());
                                sendMail.setWhatId(quote.Id);
                                // GENSET record type
                                if(quote.RecordTypeId ==  Schema.SObjectType.SBQQ__Quote__c.getRecordTypeInfosByName().get('Container GENSET Quote').getRecordTypeId()){
                                    if(quote.CONTAINER_Sales_Region__c == ContainerConstants.APO)
                                        groupNameASO = ContainerConstants.CONTAINER_Quote_ASO_GENSET_APO;
                                    else if(quote.CONTAINER_Sales_Region__c == ContainerConstants.NAO)
                                        groupNameASO = ContainerConstants.CONTAINER_Quote_ASO_GENSET_NAO;
                                    else if(quote.CONTAINER_Sales_Region__c == ContainerConstants.EMEA)
                                        groupNameASO = ContainerConstants.CONTAINER_Quote_ASO_GENSET_EMEA;
                                    sendMail.setToAddresses(getMailAddressesBasedonPublicGroupName(groupNameASO));
                                }// NT record type
                                // In NT - We don't need to forward the notification
                               /* else if (quote.RecordTypeId == Schema.SObjectType.SBQQ__Quote__c.getRecordTypeInfosByName().get('Container NT Quote').getRecordTypeId()){
                                    if(quote.CONTAINER_Sales_Region__c == ContainerConstants.APO)
                                        groupNameASO =  ContainerConstants.CONTAINER_Quote_ASO_NT_APO;
                                    else if(quote.CONTAINER_Sales_Region__c == ContainerConstants.NAO)
                                        groupNameASO = ContainerConstants.CONTAINER_Quote_ASO_NT_NAO;
                                    else if(quote.CONTAINER_Sales_Region__c == ContainerConstants.EMEA)
                                        groupNameASO = ContainerConstants.CONTAINER_Quote_ASO_NT_EMEA;
                                    sendMail.setToAddresses(getMailAddressesBasedonPublicGroupName(groupNameASO));
                                } */
                                sendMail.saveAsActivity= false;
                                listEmailMessages.add(sendMail);
                                
                            }
                        }
                    }
                } 
                if(listEmailMessages != null && listEmailMessages.size() > 0)
                    Messaging.SendEmail(listEmailMessages);
            }
        }
    }
    //Get Email Addresses
    public static List<String> getMailAddressesBasedonPublicGroupName(String groupName){
        List<String> idList = new List<String>();
        List<String> mailToAddresses = new List<String>(); 
        
        Group gp = [SELECT (SELECT UserOrGroupId FROM GroupMembers) FROM Group WHERE Name =: groupName];
        for (GroupMember gm : gp.GroupMembers) {
            idList.add(gm.UserOrGroupId);
        }
        List<User> userList = [SELECT Email FROM User WHERE Id IN :idList];
        for(User u : userList) {
            mailToAddresses.add(u.email);
        } 
        return mailToAddresses;
    }
    
    
     //Get Filtered Container quote doc Data
    public static List<SBQQ__QuoteDocument__c> containerSpecificRecords(List<SBQQ__QuoteDocument__c> quoteDocList){
        List<SBQQ__QuoteDocument__c> quoteFilteredDocLists = new List<SBQQ__QuoteDocument__c>();
        String NTRecord = Schema.SObjectType.SBQQ__Quote__c.getRecordTypeInfosByName().get('Container NT Quote').getRecordTypeId();
        String GENSETRecord = Schema.SObjectType.SBQQ__Quote__c.getRecordTypeInfosByName().get('Container GENSET Quote').getRecordTypeId();
        
        //Extract the quote associated with the Docs
        Set<Id> quoteId = new Set<Id>();
        for(SBQQ__QuoteDocument__c quoteDoc : quoteDocList){
            quoteId.add(quoteDoc.SBQQ__Quote__c);
        }
        
        Map<Id, SBQQ__Quote__c> quoteRecord = new Map<Id, SBQQ__Quote__c>([select Id, RecordTypeId from SBQQ__Quote__c where id=:quoteId]);
        
        //Iterate and add the NT and Genset quote doc only
        for(SBQQ__QuoteDocument__c quoteDoc : quoteDocList){
           if(quoteRecord.get(quoteDoc.SBQQ__Quote__c).RecordTypeId  == NTRecord || quoteRecord.get(quoteDoc.SBQQ__Quote__c).RecordTypeId == GENSETRecord){
                    quoteFilteredDocLists.add(quoteDoc);
           }
        }
        
        //Return the final filtered list of records
        return quoteFilteredDocLists;
    }
}