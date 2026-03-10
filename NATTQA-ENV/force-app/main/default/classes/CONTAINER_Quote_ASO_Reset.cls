public class CONTAINER_Quote_ASO_Reset {
	public Id quoteId;
    public SBQQ__Quote__c quote{get;set;}
	public CONTAINER_Quote_ASO_Reset(ApexPages.StandardController stdController) {
	 quoteId = stdController.getId();
        system.debug('quoteId'+quoteId);
	}
    
	public PageReference onReset(){ 
        //public Id quoteId;
        List<SBQQ__Quote__c> quoteList=[select Id,CONTAINER_ASO_ID__c,CONTAINER_ASO_Rev__c,CONTAINER_Status__c,CONTAINER_GENSET_RevNumber__c,CONTAINER_NT_RevNumber__c,CONTAINER_Genset_Previous_ASO_ID__c,CONTAINER_NT_Previous_ASO_ID__c,CONTAINER_Job__c,RecordTypeId from SBQQ__Quote__c where Id = :quoteId limit 1];
        system.debug(quoteList);
        // Get all metadata revision mapping records
        Map<Integer,String> mapQuoteRevNumbertoName = new Map<Integer,String>();
        for(CONTAINER_Quote_Revision_Mapping__mdt obj : [SELECT Revision_Name__c, Revision_Number__c FROM CONTAINER_Quote_Revision_Mapping__mdt]){
            if(!mapQuoteRevNumbertoName.containsKey(Integer.valueOf(obj.Revision_Number__c))){
                mapQuoteRevNumbertoName.put(Integer.valueOf(obj.Revision_Number__c),obj.Revision_Name__c);
            } 
        }
        // fetch current GENSET ASO ID from all GENSET Quote Filter based on record type & ASO_ID__c != null  sort by ASO_ID__c DESC LIMIT 1
        List<SBQQ__Quote__c> currentGENSETASOId = [select CONTAINER_ASO_ID__c from SBQQ__Quote__c where CONTAINER_ASO_ID__c <> null and RecordType.name = 'Container GENSET Quote'  ORDER BY CONTAINER_ASO_ID__c DESC limit 1] ;
        // fetch current NT ASO ID from all NT Quote Filter based on record type & ASO_ID__c!= null  sort by ASO_ID__c DESC LIMIT 1
        List<SBQQ__Quote__c> currentNTASOId = [select CONTAINER_ASO_ID__c from SBQQ__Quote__c where CONTAINER_ASO_ID__c <> null and RecordType.name = 'Container NT Quote'  ORDER BY CONTAINER_ASO_ID__c DESC limit 1] ;
        List<SBQQ__Quote__c> lstQuote = new List<SBQQ__Quote__c>();
        
        if(!quoteList.isEmpty()){
                for(SBQQ__Quote__c quote : quoteList){
                    //if (quote.CONTAINER_Job__c == null && quote.CONTAINER_Status__c != 'Job # Issued' && quote.CONTAINER_Status__c != 'ASO Released' && quote.CONTAINER_Status__c != 'SO Released'){
                        //Apexpages.addMessage(new ApexPages.Message(ApexPages.Severity.ERROR, 'Job # shouldn’t be blank'));
                    //}else{
                        // If GENSET Record Type
                        if(quote.RecordTypeId ==  Schema.SObjectType.SBQQ__Quote__c.getRecordTypeInfosByName().get('Container GENSET Quote').getRecordTypeId()){
                            	if(!String.isBlank(quote.CONTAINER_ASO_ID__c) && !String.isBlank(quote.CONTAINER_ASO_Rev__c)) {
                                    //checking ASO ID and ASO Rev scenarios
                                    if(quote.CONTAINER_ASO_Rev__c == 'A' && quote.CONTAINER_GENSET_RevNumber__c == 0) {
                                        quote.CONTAINER_ASO_Rev__c = null;
                                        quote.CONTAINER_GENSET_RevNumber__c = null;
                                    }
                                    else {
                                        quote.CONTAINER_GENSET_RevNumber__c = quote.CONTAINER_GENSET_RevNumber__c -1;
                            			quote.CONTAINER_ASO_Rev__c = mapQuoteRevNumbertoName.get(Integer.valueOf(quote.CONTAINER_GENSET_RevNumber__c)); 
                                    }
                        			
                            	}
                            
                            	else if(!String.isBlank(quote.CONTAINER_ASO_ID__c) && String.isBlank(quote.CONTAINER_ASO_Rev__c)) {
                                   quote.CONTAINER_ASO_ID__c = null;
                                }
                            
                            	else if(String.isBlank(quote.CONTAINER_ASO_ID__c) && String.isBlank(quote.CONTAINER_ASO_Rev__c)) {
                                	Apexpages.addMessage(new ApexPages.Message(ApexPages.Severity.ERROR, 'Both ASO ID and ASO REV are already blank.'));   
                                }
                            	       	                                            
                        }else if(quote.RecordTypeId == Schema.SObjectType.SBQQ__Quote__c.getRecordTypeInfosByName().get('Container NT Quote').getRecordTypeId()){
                            // If NT Record Type
                            
                            if(quote.RecordTypeId ==  Schema.SObjectType.SBQQ__Quote__c.getRecordTypeInfosByName().get('Container NT Quote').getRecordTypeId()){
                            	if(!String.isBlank(quote.CONTAINER_ASO_ID__c) && !String.isBlank(quote.CONTAINER_ASO_Rev__c)) {
                                    //checking ASO ID and ASO Rev scenarios
                                    if(quote.CONTAINER_ASO_Rev__c == 'A' && quote.CONTAINER_NT_RevNumber__c == 0) {
                                        quote.CONTAINER_ASO_Rev__c = null;
                                        quote.CONTAINER_NT_RevNumber__c = null;
                                    }
                                    else {
                                        quote.CONTAINER_NT_RevNumber__c = quote.CONTAINER_NT_RevNumber__c -1;
                            			quote.CONTAINER_ASO_Rev__c = mapQuoteRevNumbertoName.get(Integer.valueOf(quote.CONTAINER_NT_RevNumber__c));   
                                    }
                        			
                            	}
                            
                            	else if(!String.isBlank(quote.CONTAINER_ASO_ID__c) && String.isBlank(quote.CONTAINER_ASO_Rev__c)) {
                                   quote.CONTAINER_ASO_ID__c = null;
                                }
                            
                            	else if(String.isBlank(quote.CONTAINER_ASO_ID__c) && String.isBlank(quote.CONTAINER_ASO_Rev__c)) {
                                	Apexpages.addMessage(new ApexPages.Message(ApexPages.Severity.ERROR, 'Both ASO ID and ASO REV are already blank.'));   
                                }
                            
                            }
                        } 
                    	quote.CONTAINER_IsRevised__c=FALSE;
                    	lstQuote.add(quote);
                    //}
                }
            
            if(lstQuote != null && lstQuote.size() > 0){
                update lstQuote;
            }
       }
       return new PageReference('/' + quoteId);
    }   
}