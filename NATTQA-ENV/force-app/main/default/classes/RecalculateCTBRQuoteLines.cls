global class RecalculateCTBRQuoteLines Implements Schedulable{
    global void execute(SchedulableContext sc){
        UpdateCTBRPricing();
    }
    
    public void UpdateCTBRPricing(){
        
        List<SBQQ__QuoteLine__c> listCTBRQL = new List<SBQQ__QuoteLine__c>();
        listCTBRQL = [SELECT Id, Name, SBQQ__ListPrice__c, SBQQ__OriginalPrice__c, CTBR_List_Unit_Price_USD__c, CTBR_List_Unit_Pricing_BRL__c, SBQQ__Quote__c, SBQQ__Quote__r.CurrencyIsoCode, NATT_Quote_Status__c, NATT_Quote_Recordtype_Dev_Name__c 
                      FROM  SBQQ__QuoteLine__c 
                      WHERE NATT_Quote_Status__c = 'Draft' 
                      AND (NATT_Quote_Recordtype_Dev_Name__c = 'CTBR_Units_Quote' OR NATT_Quote_Recordtype_Dev_Name__c = 'CTBR_BluEdge')]; 
                      //AND (SBQQ__ListPrice__c > 0 OR SBQQ__OriginalPrice__c > 0)];
        
        for(SBQQ__QuoteLine__c ql : listCTBRQL){
            if(ql.SBQQ__Quote__r.CurrencyIsoCode == 'BRL'){
                if(ql.NATT_Quote_Recordtype_Dev_Name__c == 'CTBR_Units_Quote'){
                    ql.SBQQ__ListPrice__c = ql.CTBR_List_Unit_Pricing_BRL__c;
                } else if(ql.NATT_Quote_Recordtype_Dev_Name__c == 'CTBR_BluEdge'){
                    ql.SBQQ__OriginalPrice__c = ql.CTBR_List_Unit_Pricing_BRL__c;
                }   
            } else if(ql.SBQQ__Quote__r.CurrencyIsoCode == 'USD'){
                ql.SBQQ__ListPrice__c = ql.CTBR_List_Unit_Price_USD__c;
            }
        }
        update listCTBRQL;
    }
}