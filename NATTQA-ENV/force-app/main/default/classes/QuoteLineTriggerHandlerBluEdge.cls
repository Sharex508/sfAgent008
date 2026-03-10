public class QuoteLineTriggerHandlerBluEdge extends QuoteLineTriggerHandlerAbstract{ 
    
    public virtual class BaseException extends Exception {}
    public class QuoteLineException extends BaseException {}
    
    public override void handleBeforeInsert(List<SObject> newQuoteLines){        
        
    }
    
    public override void handleBeforeUpdate(Map<Id,Sobject> trgOldMap, Map<Id,SObject> trgNewMap){
        
        Set<Id> bluEdgeQuoteSet = new Set<Id>();
        Map<String,Integer> serialNumberToBundleCountMap = new Map<String,Integer>();
        Map<Id,SBQQ__QuoteLine__c> newQuoteLineMap = (Map<Id,SBQQ__QuoteLine__c>)trgNewMap;
        Map<Id,SBQQ__QuoteLine__c> oldQuoteLineMap = (Map<Id,SBQQ__QuoteLine__c>)trgOldMap;
        
        for(SBQQ__QuoteLine__c ql : newQuoteLineMap.values()){            
            bluEdgeQuoteSet.add(ql.SBQQ__Quote__c);
        }
        
        for(SBQQ__QuoteLine__c ql : [Select Id,
                                     SBQQ__ProductCode__c,
                                     NATT_Serial_Number__c 
                                     From SBQQ__QuoteLine__c 
                                     Where SBQQ__Quote__c IN :bluEdgeQuoteSet
                                     AND SBQQ__ProductCode__c = 'BluEdge'
                                     AND NATT_Model_Number2__c != null 
                                     AND NATT_Serial_Number__c != null])
        {
            if(!serialNumberToBundleCountMap.containsKey(ql.NATT_Serial_Number__c)){
                serialNumberToBundleCountMap.put(ql.NATT_Serial_Number__c,1);
            }else{
                serialNumberToBundleCountMap.put(ql.NATT_Serial_Number__c,serialNumberToBundleCountMap.get(ql.NATT_Serial_Number__c) + 1);
            } 
        }
        
        for(SBQQ__QuoteLine__c ql : newQuoteLineMap.values()){
            
            if(ql.SBQQ__ProductCode__c == 'BluEdge' 
               && serialNumberToBundleCountMap.containsKey(ql.NATT_Serial_Number__c) 
               && serialNumberToBundleCountMap.get(ql.NATT_Serial_Number__c) > 1)
            {
               // ql.addError('BluEdge bundle will always be a quantity of one since it corresponds with a single inventory/serial number.'); 
            }
        }
    }
}