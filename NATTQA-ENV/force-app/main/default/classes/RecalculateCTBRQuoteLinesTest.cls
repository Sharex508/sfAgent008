@isTest(SeeAllData=true)
private class RecalculateCTBRQuoteLinesTest{

    static testMethod void myTestMethod() {        
         Test.startTest();
           
         List<SBQQ__QuoteLine__c> listCTBRQL = new List<SBQQ__QuoteLine__c>();
         listCTBRQL = [SELECT Id, Name, SBQQ__ListPrice__c, CTBR_List_Unit_Price_USD__c, CTBR_List_Unit_Pricing_BRL__c, CTBR_Current_Exchange_Rate__c, CTBR_Previous_Exchange_Rate__c, SBQQ__Quote__c, SBQQ__Quote__r.CurrencyIsoCode, SBQQ__Quote__r.SBQQ__Status__c, SBQQ__Quote__r.NATT_Quote_Record_Type_Developer_Name__c FROM  SBQQ__QuoteLine__c WHERE SBQQ__Quote__r.SBQQ__Status__c = 'Draft' AND (SBQQ__Quote__r.NATT_Quote_Record_Type_Developer_Name__c = 'CTBR_Units_Quote' OR SBQQ__Quote__r.NATT_Quote_Record_Type_Developer_Name__c = 'CTBR_BluEdge') AND SBQQ__Quote__r.CurrencyIsoCode = 'BRL'];
        
         for(SBQQ__QuoteLine__c ql : listCTBRQL){
            ql.SBQQ__ListPrice__c = ql.CTBR_List_Unit_Pricing_BRL__c;
         }
         update listCTBRQL;
         
         RecalculateCTBRQuoteLines myClass = new RecalculateCTBRQuoteLines();   
         String chron = '0 0 23 * * ?';        
         system.schedule('Test Sched', chron, myClass);
         test.stopTest();
    }
    
    static testMethod void myTestMethod2() {        
         Test.startTest();
           
         List<SBQQ__QuoteLine__c> listCTBRQL = new List<SBQQ__QuoteLine__c>();
         listCTBRQL = [SELECT Id, Name, SBQQ__ListPrice__c, CTBR_List_Unit_Price_USD__c, CTBR_List_Unit_Pricing_BRL__c, CTBR_Current_Exchange_Rate__c, CTBR_Previous_Exchange_Rate__c, SBQQ__Quote__c, SBQQ__Quote__r.CurrencyIsoCode, SBQQ__Quote__r.SBQQ__Status__c, SBQQ__Quote__r.NATT_Quote_Record_Type_Developer_Name__c FROM  SBQQ__QuoteLine__c WHERE SBQQ__Quote__r.SBQQ__Status__c = 'Draft' AND (SBQQ__Quote__r.NATT_Quote_Record_Type_Developer_Name__c = 'CTBR_Units_Quote' OR SBQQ__Quote__r.NATT_Quote_Record_Type_Developer_Name__c = 'CTBR_BluEdge') AND SBQQ__Quote__r.CurrencyIsoCode = 'USD'];
        
         for(SBQQ__QuoteLine__c ql : listCTBRQL){
            ql.SBQQ__ListPrice__c = ql.CTBR_List_Unit_Price_USD__c;
         }
         update listCTBRQL;
         
         RecalculateCTBRQuoteLines myClass = new RecalculateCTBRQuoteLines();   
         String chron = '0 0 23 * * ?';        
         system.schedule('Test Sched', chron, myClass);
         test.stopTest();
    }
}