public WITHOUT SHARING class Container_Quote_ASO_Release_Controller extends CONTAINER_TriggerHandler{
    public override void beforeInsert(){
        List<SBQQ__QuoteDocument__c> updatedQuoteDocLists = CONTAINER_Quote_ASO_Release_Helper.containerSpecificRecords((List<SBQQ__QuoteDocument__c>)Trigger.new);
        if(!updatedQuoteDocLists.isEmpty()){
            CONTAINER_Quote_ASO_Release_Helper.Container_Quote_ASO_Release(updatedQuoteDocLists);
        }
        //CONTAINER_Quote_ASO_Release_Helper.Container_Quote_ASO_Release((List<SBQQ__QuoteDocument__c>)Trigger.new);
    }
    public override void afterInsert(){
        List<SBQQ__QuoteDocument__c> updatedQuoteDocLists = CONTAINER_Quote_ASO_Release_Helper.containerSpecificRecords((List<SBQQ__QuoteDocument__c>)Trigger.new);
        if(!updatedQuoteDocLists.isEmpty()){
            CONTAINER_Quote_ASO_Release_Helper.sendQuoteDocumentEmailwithAttachment(updatedQuoteDocLists);
            //CONTAINER_Quote_ASO_Release_Helper.sendQuoteDocumentEmailwithAttachment((List<SBQQ__QuoteDocument__c>)Trigger.new);
        }
    }
}