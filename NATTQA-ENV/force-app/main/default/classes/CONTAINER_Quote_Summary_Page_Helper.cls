public with sharing class CONTAINER_Quote_Summary_Page_Helper {
    @AuraEnabled(cacheable=true)
    public static List<DataWrapper> getQuoteSummary(String recId) {

        id myId = recId;
        list<DataWrapper> listLineItems  = new list<DataWrapper>();
        list<DataWrapper> listLineItems1  = new list<DataWrapper>();
        list<DataWrapper> listLineItems2  = new list<DataWrapper>();
        list<DataWrapper> listLineItems3  = new list<DataWrapper>();
        list<DataWrapper> listLineItems4  = new list<DataWrapper>();
        list<DataWrapper> listLineItems5  = new list<DataWrapper>();

        List<SBQQ__QuoteLine__c> quoteList = [SELECT Id,Name,
                                                    SBQQ__RequiredBy__c,SBQQ__OptionLevel__c,SBQQ__Bundle__c,NATT_P_N__c,
                                                    CONTAINER_Model_Number__c,SBQQ__ProductName__c,CONTAINER_List_Price__c,
                                                    CONTAINER_Customer_Part_number__c,SBQQ__Quote__r.CONTAINER_Model_Number__c,
                                                    CONTAINER_Option_Type__c,SBQQ__ProductCode__c,CONTAINER_Warranty_Description__c,
                                                    SBQQ__Quote__r.CONTAINER_Cost_Contract_Price__c,SBQQ__Quote__r.CONTAINER_Net_Sales1__c,
                                                    SBQQ__Quote__r.CONTAINER_GrossMargin_w_Warranty1__c,SBQQ__Quote__r.CONTAINER_GrossMargin_w_o_Warranty1__c
                                                FROM SBQQ__QuoteLine__c WHERE SBQQ__Quote__c =:recId] ; 

        for(SBQQ__QuoteLine__c qItemVar : quoteList){


                if(qItemVar.SBQQ__RequiredBy__c == null && qItemVar.SBQQ__OptionLevel__c == null && 
                    qItemVar.SBQQ__Bundle__c == true && qItemVar.NATT_P_N__c != null){
                    listLineItems1.add(new DataWrapper('Bundle1',qItemVar));
                }
                else if('Extended Warranty Bundle'.equalsIgnoreCase(qItemVar.NATT_P_N__c )){
                    listLineItems2.add(new DataWrapper('Bundle2',qItemVar));
                }
                else if(qItemVar.SBQQ__ProductCode__c == 'Reserves Applied Sales'){
                    listLineItems3.add(new DataWrapper('optionProd1Sales',qItemVar));
                }
                else if(qItemVar.SBQQ__ProductCode__c== 'Reserves Applied Cost'){
                    listLineItems4.add(new DataWrapper('optionProd1Service',qItemVar));
                }
                

        } 
        if(quoteList.size() > 0){
            listLineItems5.add(new DataWrapper('blankColumn',quoteList[0]));
            listLineItems5.add(new DataWrapper('blankColumn',quoteList[0]));
            listLineItems5.add(new DataWrapper('ContractPrice',quoteList[0]));
            listLineItems5.add(new DataWrapper('NetSales',quoteList[0]));
            listLineItems5.add(new DataWrapper('GrossMarginwithWarranty',quoteList[0]));
            listLineItems5.add(new DataWrapper('GrossMarginwithOutWarranty',quoteList[0]));
        }
        // Adding all list to main list
        listLineItems.addAll(listLineItems1);
        listLineItems.addAll(listLineItems2);
        listLineItems.addAll(listLineItems3);
        listLineItems.addAll(listLineItems4);
        listLineItems.addAll(listLineItems5);

        return listLineItems;
    }

    //A wrapper class that will be use do display the data of the object
    public class DataWrapper{

        @AuraEnabled public string Product_Description {get;set;} 
        @AuraEnabled public string Net_Unit_Price {get;set;}

        public DataWrapper(String strVal, SBQQ__QuoteLine__c qItemVarRec){

            if(strVal == 'Bundle1'){
                this.Product_Description =  qItemVarRec.SBQQ__Quote__r.CONTAINER_Model_Number__c + ' - ' + qItemVarRec.SBQQ__ProductName__c;
                this.Net_Unit_Price = String.valueOf(qItemVarRec.CONTAINER_List_Price__c);
            }
            else if(strVal == 'Bundle2'){
                this.Product_Description = qItemVarRec.CONTAINER_Customer_Part_number__c ;
                this.Net_Unit_Price = String.valueOf(qItemVarRec.CONTAINER_List_Price__c);
            }
            else if(strVal == 'optionProd1Sales'){
                if(qItemVarRec.CONTAINER_Warranty_Description__c == null){
                    this.Product_Description =  qItemVarRec.SBQQ__ProductName__c;
                    this.Net_Unit_Price = String.valueOf(qItemVarRec.CONTAINER_List_Price__c);
                }else{
                    this.Product_Description =  qItemVarRec.SBQQ__ProductName__c + ' - ' + qItemVarRec.CONTAINER_Warranty_Description__c;
                    this.Net_Unit_Price = String.valueOf(qItemVarRec.CONTAINER_List_Price__c);
                }
            }
            else if(strVal == 'optionProd1Service'){
                if(qItemVarRec.CONTAINER_Warranty_Description__c == null){
                    this.Product_Description =  qItemVarRec.SBQQ__ProductName__c;
                    this.Net_Unit_Price = String.valueOf(qItemVarRec.CONTAINER_List_Price__c);
                }else{
                    this.Product_Description =  qItemVarRec.SBQQ__ProductName__c + ' - ' + qItemVarRec.CONTAINER_Warranty_Description__c;
                    this.Net_Unit_Price = String.valueOf(qItemVarRec.CONTAINER_List_Price__c);
                }
            }else{
                if(strVal == 'blankColumn'){
                    this.Product_Description =  '       ';
                    this.Net_Unit_Price = '   ';
                }
                if(strVal == 'ContractPrice'){
                    this.Product_Description =  'Contract Price';
                    this.Net_Unit_Price = (qItemVarRec.SBQQ__Quote__r.CONTAINER_Cost_Contract_Price__c != null) ? (String.valueOf(qItemVarRec.SBQQ__Quote__r.CONTAINER_Cost_Contract_Price__c)) : '';
                }
                if(strVal == 'NetSales'){
                    this.Product_Description =  'Net Sales';
                    this.Net_Unit_Price = String.valueOf(qItemVarRec.SBQQ__Quote__r.CONTAINER_Net_Sales1__c);
                }
                if(strVal == 'GrossMarginwithWarranty'){
                    this.Product_Description =  'Gross Margin w/ Warranty %';
                    this.Net_Unit_Price = (qItemVarRec.SBQQ__Quote__r.CONTAINER_GrossMargin_w_Warranty1__c != null) ? String.valueOf(qItemVarRec.SBQQ__Quote__r.CONTAINER_GrossMargin_w_Warranty1__c)+ ' %' : '';
                }
                if(strVal == 'GrossMarginwithOutWarranty'){
                    this.Product_Description =  'Gross Margin w/o Warranty %';
                    this.Net_Unit_Price = (qItemVarRec.SBQQ__Quote__r.CONTAINER_GrossMargin_w_o_Warranty1__c != null ) ? String.valueOf(qItemVarRec.SBQQ__Quote__r.CONTAINER_GrossMargin_w_o_Warranty1__c)+ ' %' : '';
                }
            }

            //this.Net_Unit_Price = qItemVarRec.CONTAINER_List_Price__c;
                    
        }
    }
}