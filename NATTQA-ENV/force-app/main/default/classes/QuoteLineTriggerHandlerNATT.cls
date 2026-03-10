public class QuoteLineTriggerHandlerNATT extends QuoteLineTriggerHandlerAbstract{ 
    
    private final String nattUnitRecTypeId = Schema.SObjectType.SBQQ__Quote__c.getRecordTypeInfosByDeveloperName().get('NATT_Units_Quote').getRecordTypeId();
    
    public override void handleBeforeInsert(List<SObject> newQuoteLines){ 
        
        Set<Id> clonedQuoteLinesSet = new Set<Id>();
        Set<Id> amendmentQuoteSet = new Set<Id>();
        Map<String,Decimal> orginalOrderIdLinesMap = new Map<String,Decimal>();
        
        for(SBQQ__QuoteLine__c ql : (List<SBQQ__QuoteLine__c>)newQuoteLines){
            System.debug('qlqlqlq: ' + ql.SBQQ__ProductName__c + ql.NATT_Quote_Type__c + ql.NATT_Quote_Record_Type_ID__c + nattUnitRecTypeId + ql.NATT_Is_Base_Unit__c + ql.NATT_Original_Order_Id__c);
            if(ql.NATT_Quote_Type__c == 'Amendment' 
               && ql.NATT_Quote_Record_Type_ID__c == nattUnitRecTypeId
               && ql.NATT_Is_Base_Unit__c
               && ql.NATT_Original_Order_Id__c <> null)
            {
                amendmentQuoteSet.add(ql.SBQQ__Quote__c);
                
                if(orginalOrderIdLinesMap.containsKey(ql.NATT_Original_Order_Id__c)){
                    orginalOrderIdLinesMap.put(ql.NATT_Original_Order_Id__c, orginalOrderIdLinesMap.get(ql.NATT_Original_Order_Id__c) + ql.SBQQ__PriorQuantity__c);
                }else{
                    orginalOrderIdLinesMap.put(ql.NATT_Original_Order_Id__c, ql.SBQQ__PriorQuantity__c);
                }
            }
            
            // defaults values on clone
            if(ql.isClone() && ql.SBQQ__Source__c <> null){
                clonedQuoteLinesSet.add(ql.SBQQ__Source__c);
            }
           /* Removing becuase of issues with old design
            if(ql.NATT_Extended_Basic_Months__c != null && ql.NATT_Optional_Coverage_Months__c != null && ql.NATT_Optional_Coverage_Months__c > ql.NATT_Extended_Basic_Months__c){
                ql.addError('Optional Coverage Months must be less than or equal to Extended Basic Months.');
            }
            
            if(ql.NATT_Extended_Basic_Hours__c != null && ql.NATT_Optional_Coverage_Hours__c != null && ql.NATT_Optional_Coverage_Hours__c > ql.NATT_Extended_Basic_Hours__c){
                ql.addError('Optional Coverage Hours must be less than or equal to Extended Basic Hours.');
            }
            
            if(ql.NATT_Coverage_Type__c == 'Extended Basic + Major Component' && ql.NATT_Major_Component_Months__c != null && ql.NATT_Extended_Basic_Months__c != null && ql.NATT_Extended_Basic_Months__c > ql.NATT_Major_Component_Months__c){
                ql.addError('Extended Basic Months must be less than or equal to Major Component Months.');
            }
            // Removing becuase of error and change of design - CREEDY 1/10/22
            //if(ql.NATT_Coverage_Type__c == 'Extended Basic + Major Component' && ql.NATT_Major_Component_Hours__c != null && ql.NATT_Extended_Basic_Hours__c != null && ql.NATT_Extended_Basic_Hours__c > ql.NATT_Major_Component_Hours__c){
            //    ql.addError('Extended Basic Hours must be less than or equal to Major Component Hours.');
            //}
            
            if(ql.NATT_Coverage_Type__c == 'Extended Basic + Major Component' && ql.NATT_Major_Component_Months__c != null && ql.NATT_Optional_Coverage_Months__c != null && ql.NATT_Optional_Coverage_Months__c > ql.NATT_Major_Component_Months__c){
                ql.addError('Optional Coverage Months must be less than or equal to Major Component Months.');
            }
            
            if(ql.NATT_Coverage_Type__c == 'Extended Basic + Major Component' && ql.NATT_Major_Component_Hours__c != null && ql.NATT_Optional_Coverage_Hours__c != null && ql.NATT_Optional_Coverage_Hours__c > ql.NATT_Major_Component_Hours__c){
                ql.addError('Optional Coverage Months must be less than or equal to Major Component Hours.');
            } */
        }
        System.debug('orginalOrderIdLinesMap'+orginalOrderIdLinesMap);
        if(!orginalOrderIdLinesMap.isEmpty()){            
            System.debug('amendmentQuoteSet'+amendmentQuoteSet);
            Map<Id,SBQQ__Quote__c> quoteMap = new Map<Id,SBQQ__Quote__c>([Select Id,
                                                                          NATT_Enforce_Amendment_Error__c 
                                                                          From SBQQ__Quote__c 
                                                                          Where Id IN :amendmentQuoteSet]);
            
            Map<String, Decimal> assetQtyMap = new Map<String, Decimal>();
            
            for(AggregateResult agr : [Select NATT_Original_Order_Id__c,
                                       SUM(Quantity) agrQty
                                       From Asset
                                       Where NATT_Is_Base_Unit__c = true 
                                       AND NATT_Original_Order_Id__c IN :orginalOrderIdLinesMap.keySet() Group By NATT_Original_Order_Id__c])
            {
                assetQtyMap.put((String)agr.get('NATT_Original_Order_Id__c'),(Decimal)agr.get('agrQty'));
            }
            
            System.debug('assetQtyMap'+assetQtyMap);
            
            for(SBQQ__QuoteLine__c ql : (List<SBQQ__QuoteLine__c>)newQuoteLines){
                System.debug('aaaNATT_Enforce_Amendment_Error__c'+quoteMap.get(ql.SBQQ__Quote__c).NATT_Enforce_Amendment_Error__c);
                 System.debug('bbbNATT_Original_Order_Id__c'+assetQtyMap.get(ql.NATT_Original_Order_Id__c));
                 System.debug('cccNATT_Original_Order_Id__c'+orginalOrderIdLinesMap.get(ql.NATT_Original_Order_Id__c));
                if(quoteMap.get(ql.SBQQ__Quote__c).NATT_Enforce_Amendment_Error__c && assetQtyMap.get(ql.NATT_Original_Order_Id__c) > orginalOrderIdLinesMap.get(ql.NATT_Original_Order_Id__c)){
                    ql.addError('Please select all assets before you click the Amend button.');
                }
            }
            
            List<SBQQ__Quote__c> updateAmendedQuotes = new List<SBQQ__Quote__c>();
            for(SBQQ__Quote__c amendedQuote : quoteMap.values()){
                if(amendedQuote.NATT_Enforce_Amendment_Error__c){
                    amendedQuote.NATT_Enforce_Amendment_Error__c = false;
                    updateAmendedQuotes.add(amendedQuote);
                }
            }
            
            if(!updateAmendedQuotes.isEmpty()){
                update updateAmendedQuotes;
            } 
        }
        
        if(!clonedQuoteLinesSet.isEmpty()){
            
            Map<Id,SBQQ__QuoteLine__c> clonedQuoteLinesMap = new Map<Id,SBQQ__QuoteLine__c>([Select Id,
                                                                                             NATT_Extended_Basic_Months__c,
                                                                                             NATT_Extended_Basic_Hours__c,
                                                                                             NATT_Major_Component_Months__c,
                                                                                             NATT_Major_Component_Hours__c,
                                                                                             NATT_Major_Component_Deductible__c,
                                                                                             NATT_Optional_Coverage_Months__c,
                                                                                             NATT_Optional_Coverage_Hours__c,
                                                                                             NATT_CMRA_Term_Years__c,
                                                                                             NATT_Coverage_Type__c
                                                                                             From SBQQ__QuoteLine__c Where Id IN :clonedQuoteLinesSet]);
            
            for(SBQQ__QuoteLine__c ql : (List<SBQQ__QuoteLine__c>)newQuoteLines){
                
                // defaults values on clone
                if(ql.isClone() && ql.SBQQ__Source__c <> null && clonedQuoteLinesMap.containsKey(ql.SBQQ__Source__c)){
                    ql.NATT_Locked__c = false;
                    ql.NATT_Extended_Basic_Months__c = clonedQuoteLinesMap.get(ql.SBQQ__Source__c).NATT_Extended_Basic_Months__c != null ? clonedQuoteLinesMap.get(ql.SBQQ__Source__c).NATT_Extended_Basic_Months__c : '';
                    ql.NATT_Extended_Basic_Hours__c = clonedQuoteLinesMap.get(ql.SBQQ__Source__c).NATT_Extended_Basic_Hours__c != null ? clonedQuoteLinesMap.get(ql.SBQQ__Source__c).NATT_Extended_Basic_Hours__c : '';
                    ql.NATT_Major_Component_Months__c = clonedQuoteLinesMap.get(ql.SBQQ__Source__c).NATT_Major_Component_Months__c != null ? clonedQuoteLinesMap.get(ql.SBQQ__Source__c).NATT_Major_Component_Months__c : '';
                    ql.NATT_Major_Component_Hours__c = clonedQuoteLinesMap.get(ql.SBQQ__Source__c).NATT_Major_Component_Hours__c != null ? clonedQuoteLinesMap.get(ql.SBQQ__Source__c).NATT_Major_Component_Hours__c : '';
                    ql.NATT_Major_Component_Deductible__c = clonedQuoteLinesMap.get(ql.SBQQ__Source__c).NATT_Major_Component_Deductible__c != null ? clonedQuoteLinesMap.get(ql.SBQQ__Source__c).NATT_Major_Component_Deductible__c : '';
                    ql.NATT_Optional_Coverage_Months__c = clonedQuoteLinesMap.get(ql.SBQQ__Source__c).NATT_Optional_Coverage_Months__c != null ? clonedQuoteLinesMap.get(ql.SBQQ__Source__c).NATT_Optional_Coverage_Months__c : '';
                    ql.NATT_Optional_Coverage_Hours__c = clonedQuoteLinesMap.get(ql.SBQQ__Source__c).NATT_Optional_Coverage_Hours__c != null ? clonedQuoteLinesMap.get(ql.SBQQ__Source__c).NATT_Optional_Coverage_Hours__c : '';
                    ql.NATT_CMRA_Term_Years__c = clonedQuoteLinesMap.get(ql.SBQQ__Source__c).NATT_CMRA_Term_Years__c != null ? clonedQuoteLinesMap.get(ql.SBQQ__Source__c).NATT_CMRA_Term_Years__c : null;
                    ql.NATT_Coverage_Type__c = clonedQuoteLinesMap.get(ql.SBQQ__Source__c).NATT_Coverage_Type__c != null ? clonedQuoteLinesMap.get(ql.SBQQ__Source__c).NATT_Coverage_Type__c : '';
                }  
            }
        }
    }
    
    public override void handleBeforeUpdate(Map<Id,Sobject> trgOldMap, Map<Id,SObject> trgNewMap){
        /*
        Map<Id,SBQQ__QuoteLine__c> newQuoteLineMap = (Map<Id,SBQQ__QuoteLine__c>)trgNewMap;
        Map<Id,SBQQ__QuoteLine__c> oldQuoteLineMap = (Map<Id,SBQQ__QuoteLine__c>)trgOldMap;
        
        for(SBQQ__QuoteLine__c ql : newQuoteLineMap.values()){
            
            if(ql.NATT_Quote_Type__c == 'Amendment' 
               && ql.NATT_Quote_Record_Type_ID__c == nattUnitRecTypeId
               && ql.NATT_Locked__c)
            { 
                // quantity changes are not allowed on locked quote lines
                if(ql.SBQQ__Quantity__c <> oldQuoteLineMap.get(ql.Id).SBQQ__Quantity__c){
                    ql.addError('This unit has been locked for editing due to its order status (Quantity Changes) - '+ql.Name);
                }
                
                // Price changes are not allowed on locked quote lines
                if(ql.SBQQ__NetPrice__c <> oldQuoteLineMap.get(ql.Id).SBQQ__NetPrice__c){
                    ql.addError('This unit has been locked for editing due to its order status (Price Changes) - '+ql.Name);
                }
                
                // End Customer Price changes are not allowed on locked quote lines
                if(ql.NATT_End_Customer_Price__c <> oldQuoteLineMap.get(ql.Id).NATT_End_Customer_Price__c){
                    ql.addError('This unit has been locked for editing due to its order status (End Customer Prices) - '+ql.Name);
                }
            } 
            
            if(ql.NATT_Quote_Type__c == 'Amendment' 
               && ql.NATT_Quote_Record_Type_ID__c == nattUnitRecTypeId
               && ql.NATT_Locked__c
               && ql.SBQQ__UpgradedAsset__c <> null
               && ql.NATT_P_N__c == null
               && !ql.NATT_Is_Base_Unit__c)
            { 
                // quantity changes are not allowed on locked quote lines
                if(ql.SBQQ__Quantity__c <> oldQuoteLineMap.get(ql.Id).SBQQ__Quantity__c){
                    ql.addError('You may not change the Line # - '+ql.SBQQ__Number__c+' - '+ ql.SBQQ__ProductName__c +' because it is on unit.');
                }
                
                // Price changes are not allowed on locked quote lines
                if(ql.SBQQ__NetPrice__c <> oldQuoteLineMap.get(ql.Id).SBQQ__NetPrice__c){
                    ql.addError('You may not change the Line # - '+ql.SBQQ__Number__c+' - '+ ql.SBQQ__ProductName__c +' because it is on unit.');
                }
                
                // End Customer Price changes are not allowed on locked quote lines
                if(ql.NATT_End_Customer_Price__c <> oldQuoteLineMap.get(ql.Id).NATT_End_Customer_Price__c){
                    ql.addError('You may not change the Line # - '+ql.SBQQ__Number__c+' - '+ ql.SBQQ__ProductName__c +' because it is on unit.');
                }
            } 
          /* Removing because this moved from code to configuration  
            if(ql.NATT_Extended_Basic_Months__c != null && ql.NATT_Optional_Coverage_Months__c != null && ql.NATT_Optional_Coverage_Months__c > ql.NATT_Extended_Basic_Months__c){
                ql.addError('Optional Coverage Months must be less than or equal to Extended Basic Months.');
            }
            
            if(ql.NATT_Extended_Basic_Hours__c != null && ql.NATT_Optional_Coverage_Hours__c != null && ql.NATT_Optional_Coverage_Hours__c > ql.NATT_Extended_Basic_Hours__c){
                ql.addError('Optional Coverage Hours must be less than or equal to Extended Basic Hours.');
            }
            
            if(ql.NATT_Coverage_Type__c == 'Extended Basic + Major Component' && ql.NATT_Major_Component_Months__c != null && ql.NATT_Extended_Basic_Months__c != null && ql.NATT_Extended_Basic_Months__c > ql.NATT_Major_Component_Months__c){
                ql.addError('Extended Basic Months must be less than or equal to Major Component Months.');
            }
            
            //if(ql.NATT_Coverage_Type__c == 'Extended Basic + Major Component' && ql.NATT_Major_Component_Hours__c != null && ql.NATT_Extended_Basic_Hours__c != null && ql.NATT_Extended_Basic_Hours__c > ql.NATT_Major_Component_Hours__c){
            //    ql.addError('Extended Basic Hours must be less than or equal to Major Component Hours.');
            //}
            
            if(ql.NATT_Coverage_Type__c == 'Extended Basic + Major Component' && ql.NATT_Major_Component_Months__c != null && ql.NATT_Optional_Coverage_Months__c != null && ql.NATT_Optional_Coverage_Months__c > ql.NATT_Major_Component_Months__c){
                ql.addError('Optional Coverage Months must be less than or equal to Major Component Months.');
            }
            
            if(ql.NATT_Coverage_Type__c == 'Extended Basic + Major Component' && ql.NATT_Major_Component_Hours__c != null && ql.NATT_Optional_Coverage_Hours__c != null && ql.NATT_Optional_Coverage_Hours__c > ql.NATT_Major_Component_Hours__c){
                ql.addError('Optional Coverage Months must be less than or equal to Major Component Hours.');
            }
        }*/
    }
    
    public override void handleBeforeDelete(Map<Id,SObject> oldQuoteLinesMap){ 
        /*
        for(SBQQ__QuoteLine__c ql : (List<SBQQ__QuoteLine__c>) oldQuoteLinesMap.values()){
            
            if(ql.NATT_Quote_Type__c == 'Amendment' 
               && ql.NATT_Quote_Record_Type_ID__c == nattUnitRecTypeId 
               && ql.SBQQ__ProductCode__c == 'BluEdge')
            {
                ql.addError('BluEdge Bundle can not be modified during amendments. Create a new after market Quote for any changes to BluEdge.');
            }
            
            if(ql.NATT_Quote_Type__c == 'Amendment' 
               && ql.NATT_Quote_Record_Type_ID__c == nattUnitRecTypeId 
               && ql.NATT_Locked__c 
               && ql.NATT_Is_Base_Unit__c)
            {
                ql.addError('This unit has been locked and can not be deleted.');
            }
            
            if(ql.NATT_Quote_Type__c == 'Amendment' 
               && ql.NATT_Quote_Record_Type_ID__c == nattUnitRecTypeId 
               && ql.NATT_Locked__c 
               && ql.SBQQ__UpgradedAsset__c <> null
               && ql.NATT_P_N__c == null
               && !ql.NATT_Is_Base_Unit__c)
            {
                ql.addError('You may not change the Line # - '+ql.SBQQ__Number__c+' - '+ ql.SBQQ__ProductName__c+' because it is on unit.');
            }
        }*/
    }
}