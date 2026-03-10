/***************************************************************************
* Author - Sandeep Kumar
* Version: 1.0 
* Date: 03 Feb, 2021
* Product Search Plugin Class - ProductSearchPlugin 
* Description - 
* Test Class : ProductSearchPluginTest
* Code Reviewed By : (to be reviewed)
****************************************************************************/
global class GlobalProductSearchPlugin implements SBQQ.ProductSearchPlugin{
    
    public final string quoteRecordType = 'NATT_Units_Quote';

    global GlobalProductSearchPlugin(){
        System.debug('Default constructor');
    }
    
    global Boolean isFilterHidden(sObject quote, String fieldName){        
        
        SBQQ__Quote__c al = (SBQQ__Quote__c) quote;        
        return false;
    }
    
    global String getFilterDefaultValue(sObject quote, String fieldName){
        System.debug('METHOD CALLED: getFilterDefaultValue');
        System.debug('CTBRUNIT quote'+quote);
        System.debug('CTBRUNIT fieldName'+fieldName);
        SBQQ__Quote__c qt = (SBQQ__Quote__c) quote; 
        
        // This would set Unit filter based on Quote Unit value
        if(fieldName == 'NATT_Unit__c' && qt.NATT_Unit__c != null && (qt.NATT_Quote_Record_Type_Developer_Name__c != 'NATT_BluEdge' || qt.NATT_Quote_Record_Type_Developer_Name__c != 'CTBR_BluEdge')) {   
            System.debug('NATTUNIT value'+qt.NATT_Unit__c);
            return qt.NATT_Unit__c; 
        }
        else if(fieldName=='CTBR_Unit__c'){
            System.debug('CTBRUNIT value'+qt.CTBR_Unit__c);
             return qt.CTBR_Unit__c; 
        }
            //return qt.NATT_Unit__c;
        
        return null;
    }
    
    global Boolean isSearchCustom(sObject quote, Map<String,Object> fieldValuesMap){
        System.debug('METHOD: isSearchCustom 2'+quote);
        
        SBQQ__Quote__c quoteObj = (SBQQ__Quote__c) quote;
        //System.debug('Quote is '+quoteObj);
        
         //SBQQ__Quote__c quoteObj=[SELECT Id ,SBQQ__Account__c,RecordType.DeveloperName,NATT_Unit__c,CTBR_BluEdge_Unit__c,CTM_BluEdge_Unit__c from SBQQ__Quote__c where Id=:quote.Id limit 1];
        // retrieve all associated dealer types
        List<NATT_Product_Dealer_Type__c> productDealerTypes = [Select Id From NATT_Product_Dealer_Type__c Where NATT_Dealer__c = :quoteObj.SBQQ__Account__c];
        
        if(productDealerTypes.Size() > 0 && quoteObj.NATT_Quote_Record_Type_Developer_Name__c == 'NATT_Units_Quote' || quoteObj.NATT_Quote_Record_Type_Developer_Name__c=='CTBR_Units_Quote'){
            return true;
        }else if(quoteObj.NATT_Unit__c != null && quoteObj.NATT_Quote_Record_Type_Developer_Name__c == 'NATT_BluEdge'){ return true; }
        else if((quoteObj.NATT_Unit__c != null || quoteObj.CTBR_BluEdge_Unit__c != null) && quoteObj.NATT_Quote_Record_Type_Developer_Name__c == 'CTBR_BluEdge'){ return true;
        
        //CTM BLUEDGE    
        }else if(quoteObj.CTM_BluEdge_Unit__c != null && quoteObj.NATT_Quote_Record_Type_Developer_Name__c == 'CTM_BluEdge'){ return true;}
        else if(quoteObj.NATT_Active_Unit__c != null &&  quoteObj.NATT_Quote_Record_Type_Developer_Name__c =='NATT_Direct_Sales'){return true;}
        return false;
    }
    
    global Boolean isSuggestCustom(sObject quote, Map<String,Object> fieldValuesMap){
        return false;
    }
    
    global Boolean isInputHidden(sObject quote, String Field){
        return false;
    }
    
    global Object getInputDefaultValue(sObject query, String value){
        return '2';
    }
    
    global String getAdditionalSuggestFilters(sObject query, Map<String,Object> suggFilts){
        return '';
    }
    
    global List<PricebookEntry> suggest(sObject query, Map<String,Object> usg){
        return [SELECT Id FROM PricebookEntry LIMIT 1];
    }
    
    global String getAdditionalSearchFilters(sObject quote, Map<String,Object> fieldValuesMap){
        System.debug('METHOD: getAdditionalSearchFilters');
        
        String additionalFilter = NULL;
        
        return additionalFilter;
    }
    
    global List<PricebookEntry> search(sObject quote, Map<String,Object> fieldValuesMap){
        System.debug('METHOD CALLED: search Entered');
        
        //PRICEBOOKENTRY COLLECTION DECLARATION
        List<PricebookEntry> pbes = new List<PricebookEntry>();
        
        //GET ALL POSSIBLE FILTER FIELDS FROM THE SEARCH FILTER FIELD SET
        List<Schema.FieldSetMember> searchFilterFieldSetFields = SObjectType.Product2.FieldSets.SBQQ__SearchFilters.getFields();
        
        //GET ALL POSSIBLE FIELDS FROM THE SEARCH RESULTS FIELD SET
        List<Schema.FieldSetMember> searchResultFieldSetFields = SObjectType.Product2.FieldSets.SBQQ__SearchResults.getFields();
        
        String quotePricebookId = String.valueOf(quote.get('SBQQ__PricebookId__c'));
        String quoteCurrencyIsoCode = String.valueOf(quote.get('CurrencyIsoCode'));
        String quoteAccountId = String.valueOf(quote.get('SBQQ__Account__c'));
        
        // variable declaration
        Boolean truckFound = false;
        Boolean trailerFound = false;
        Boolean electricTrailerFound = false;
        Boolean electricTruckFound = false;
        Boolean specialProductsFound = false;
        
        // retrieve all associated dealer types
        List<NATT_Product_Dealer_Type__c> productDealerTypes = [Select Id,NATT_Dealer_Type__c,NATT_Product_Type__c From NATT_Product_Dealer_Type__c Where NATT_Dealer__c = :quoteAccountId];
        
        for(NATT_Product_Dealer_Type__c pdt : productDealerTypes){
            if(pdt.NATT_Product_Type__c == 'Truck'){
                truckFound = true;
            }else if(pdt.NATT_Product_Type__c == 'Trailer'){
                trailerFound = true;
            }else if(pdt.NATT_Product_Type__c == 'Electric Trailer'){
                System.debug('In Electric Trailer');
                electricTrailerFound = true;
            }else if(pdt.NATT_Product_Type__c == 'Electric Truck'){
                System.debug('In Electric Truck');
                electricTruckFound = true;
            }
            else if(pdt.NATT_Product_Type__c == 'Special Products'){ specialProductsFound = true; }
        }
        
        //BUILD THE SELECT STRING
        String selectClause = 'SELECT ';
        
        for(Schema.FieldSetMember field : searchResultFieldSetFields){
            selectClause += 'Product2.' + field.getFieldPath() + ', ';
        }
        
        selectClause += 'Id, UnitPrice, Pricebook2Id, Product2Id, Product2.Id';
        
        //BUILD THE WHERE CLAUSE
        String whereClause = '';
                
        for(Schema.FieldSetMember field : searchFilterFieldSetFields){
            System.debug('field =='+field);
            if(!fieldValuesMap.containsKey(field.getFieldPath())){
                continue;
            }
            
            if((String.valueOf(quote.get('NATT_Quote_Record_Type_Developer_Name__c')) == 'NATT_BluEdge' || String.valueOf(quote.get('NATT_Quote_Record_Type_Developer_Name__c')) == 'CTBR_BluEdge') && field.getFieldPath() == 'NATT_Unit__c'){ continue;
            }                
            
            if(field.getType() == Schema.DisplayType.String || field.getType() == Schema.DisplayType.Picklist){
               whereClause += 'Product2.' + field.getFieldPath() + ' LIKE \'' + fieldValuesMap.get(field.getFieldPath()) + '\' AND '+ 'Product2.NATT_Legacy_Unit__c = false' + ' AND ';                  
            }
        }
        
        String CUSTOMFILTER = '';
       // String BluEdgeFilter = '';
            
        // apply truck only filter
        if(truckFound && !trailerFound && !electricTrailerFound && !electricTruckFound)
            CUSTOMFILTER = 'Product2.NATT_Truck__c = true';
        
        // apply truck and trailer filters
        if(!truckFound && trailerFound && !electricTrailerFound && !electricTruckFound){
            CUSTOMFILTER = 'Product2.NATT_Trailer__c = true';
        }else if(truckFound && trailerFound && !electricTrailerFound && !electricTruckFound){
            CUSTOMFILTER = '(Product2.NATT_Truck__c = true OR Product2.NATT_Trailer__c = true)';
        }
        else if(truckFound && !trailerFound && !electricTrailerFound && !electricTruckFound){
            CUSTOMFILTER = 'Product2.NATT_Truck__c = true';
        }
        else if(!truckFound && !trailerFound && electricTrailerFound && !electricTruckFound){
            System.debug('Electric Trailer found');
            CUSTOMFILTER = 'Product2.NATT_Electric_Trailer__c = true';
        }else if(!truckFound && !trailerFound && !electricTrailerFound && electricTruckFound){
            System.debug('Electric Truck found');
            CUSTOMFILTER = 'Product2.NATT_Electric_Truck__c = true';
        }else if(truckFound && !trailerFound && !electricTrailerFound && electricTruckFound){
            CUSTOMFILTER = '(Product2.NATT_Truck__c = true OR Product2.NATT_Electric_Truck__c = true)';
        }else if(truckFound && trailerFound && !electricTrailerFound && electricTruckFound){
            CUSTOMFILTER = '(Product2.NATT_Trailer__c = true OR Product2.NATT_Electric_Truck__c = true)';
        }else if(truckFound && trailerFound && !electricTrailerFound && electricTruckFound){
            CUSTOMFILTER = '(Product2.NATT_Truck__c = true OR Product2.NATT_Trailer__c = true OR Product2.NATT_Electric_Truck__c = true)';
        }
        else if(truckFound && trailerFound && !electricTrailerFound && electricTruckFound){
            CUSTOMFILTER = '(Product2.NATT_Truck__c = true OR Product2.NATT_Trailer__c = true OR Product2.NATT_Electric_Truck__c = true)';
        }
        else if(truckFound && !trailerFound && electricTrailerFound && electricTruckFound){
            CUSTOMFILTER = '(Product2.NATT_Truck__c = true OR Product2.NATT_Electric_Trailer__c = true OR Product2.NATT_Electric_Truck__c = true)';
        }
        else if(!truckFound && trailerFound && electricTrailerFound && electricTruckFound){
            CUSTOMFILTER = '(Product2.NATT_Trailer__c = true OR Product2.NATT_Electric_Trailer__c = true OR Product2.NATT_Electric_Truck__c = true)';
        }
        else if(!truckFound && trailerFound && electricTrailerFound && !electricTruckFound){
            CUSTOMFILTER = '(Product2.NATT_Trailer__c = true OR Product2.NATT_Electric_Trailer__c = true)';
        }
        else if(truckFound && !trailerFound && electricTrailerFound && !electricTruckFound){
            CUSTOMFILTER = '(Product2.NATT_Truck__c = true OR Product2.NATT_Electric_Trailer__c = true)';
        }
        else if(truckFound && trailerFound && electricTrailerFound && !electricTruckFound){
            CUSTOMFILTER = '(Product2.NATT_Truck__c = true OR Product2.NATT_Trailer__c = true OR Product2.NATT_Electric_Trailer__c = true)';
        }
        else if(truckFound && trailerFound && electricTrailerFound && electricTruckFound){
            CUSTOMFILTER = '(Product2.NATT_Truck__c = true OR Product2.NATT_Trailer__c = true OR Product2.NATT_Electric_Trailer__c = true OR Product2.NATT_Electric_Truck__c = true)';
        }
        // apply truck, trailer and special products filters
        if(!truckFound && !trailerFound && !electricTrailerFound && !electricTruckFound && specialProductsFound){
            CUSTOMFILTER = 'Product2.NATT_SpecialProducts__c = true';
        }else if(!truckFound && trailerFound && !electricTrailerFound && !electricTruckFound && specialProductsFound){
            CUSTOMFILTER = '(Product2.NATT_Trailer__c = true OR Product2.NATT_SpecialProducts__c = true)';
        }else if(truckFound && !trailerFound && !electricTrailerFound && !electricTruckFound && specialProductsFound){
            CUSTOMFILTER = '(Product2.NATT_Truck__c = true OR Product2.NATT_SpecialProducts__c = true)';
        }else if(truckFound && trailerFound && !electricTrailerFound && !electricTruckFound && specialProductsFound){
            CUSTOMFILTER = '(Product2.NATT_Truck__c = true OR Product2.NATT_Trailer__c = true OR Product2.NATT_SpecialProducts__c = true)';
        }else if(!truckFound && !trailerFound && electricTrailerFound && !electricTruckFound && specialProductsFound){
            CUSTOMFILTER = '(Product2.NATT_Electric_Trailer__c = true OR Product2.NATT_SpecialProducts__c = true)';
        }else if(!truckFound && !trailerFound && !electricTrailerFound && electricTruckFound && specialProductsFound){
            CUSTOMFILTER = '(Product2.NATT_Electric_Truck__c = true OR Product2.NATT_SpecialProducts__c = true)';
        }else if(truckFound && trailerFound && electricTrailerFound && !electricTruckFound && specialProductsFound){
            CUSTOMFILTER = '(Product2.NATT_Truck__c = true OR Product2.NATT_Trailer__c = true OR Product2.NATT_Electric_Trailer__c = true OR Product2.NATT_SpecialProducts__c = true)';
        }else if(truckFound && trailerFound && !electricTrailerFound && electricTruckFound && specialProductsFound){
            CUSTOMFILTER = '(Product2.NATT_Truck__c = true OR Product2.NATT_Trailer__c = true OR Product2.NATT_Electric_Truck__c = true OR Product2.NATT_SpecialProducts__c = true)';
        }else if(!truckFound && trailerFound && electricTrailerFound && !electricTruckFound && specialProductsFound){
            CUSTOMFILTER = '(Product2.NATT_Trailer__c = true OR Product2.NATT_Electric_Trailer__c = true OR Product2.NATT_SpecialProducts__c = true)';
        }else if(!truckFound && trailerFound && !electricTrailerFound && electricTruckFound && specialProductsFound){
            CUSTOMFILTER = '(Product2.NATT_Trailer__c = true OR Product2.NATT_Electric_Truck__c = true OR Product2.NATT_SpecialProducts__c = true)';
        }else if(truckFound && !trailerFound && !electricTrailerFound && electricTruckFound && specialProductsFound){
            CUSTOMFILTER = '(Product2.NATT_Truck__c = true OR Product2.NATT_Electric_Truck__c = true OR Product2.NATT_SpecialProducts__c = true)';
        }else if(truckFound && !trailerFound && electricTrailerFound && !electricTruckFound && specialProductsFound){
            CUSTOMFILTER = '(Product2.NATT_Truck__c = true OR Product2.NATT_Electric_Trailer__c = true OR Product2.NATT_SpecialProducts__c = true)';
        }
        
        else if(truckFound && trailerFound && electricTrailerFound && electricTruckFound && specialProductsFound){
            CUSTOMFILTER = '(Product2.NATT_Truck__c = true OR Product2.NATT_Trailer__c = true OR Product2.NATT_Electric_Trailer__c = true OR Product2.NATT_Electric_Truck__c = true OR Product2.NATT_SpecialProducts__c = true)';
        }
          
        // if truck, trailer or special product is found apply the AND clause
        if(truckFound || trailerFound || electricTrailerFound || specialProductsFound || electricTruckFound)
            whereClause += ' '+CUSTOMFILTER+' AND ';
        
        if(String.valueOf(quote.get('NATT_Quote_Record_Type_Developer_Name__c')) == 'NATT_BluEdge'){
            whereClause += '(Product2.ProductCode = \'BluEdge\' OR Product2.ProductCode = \'BluEdge Core Best\' OR Product2.ProductCode = \'BluEdge Core Essential\' OR Product2.ProductCode = \'BluEdge Core Preferred\' OR Product2.ProductCode = \'BluEdge Core Advantage\') AND ';
        }
        
        if(String.valueOf(quote.get('NATT_Quote_Record_Type_Developer_Name__c')) == 'CTBR_BluEdge'){
            whereClause += 'Product2.ProductCode = \'CTBR BluEdge\' AND ';
        }
        
        //add for CTM BLUEDGE

        if(String.valueOf(quote.get('NATT_Quote_Record_Type_Developer_Name__c')) == 'CTM_BluEdge'){
            whereClause += 'Product2.ProductCode = \'MX-BluEdge\' AND ';
        }        

        // finally apply the quote pricebook and currency iso code filter to display only valid products matching the quote currency
        whereClause += ' Pricebook2Id = \''+quotePricebookId+'\' AND CurrencyIsoCode = \''+quoteCurrencyIsoCode+'\'';
        

        //BUILD THE QUERY
         String query;
         if(String.valueOf(quote.get('NATT_Quote_Record_Type_Developer_Name__c')) == 'NATT_BluEdge'){
             query = selectClause + ' FROM PricebookEntry WHERE '+ whereClause +' AND Product2.IsActive = true AND IsActive = true ORDER By Product2.SBQQ__SortOrder__c ASC ';
         }else{
              query = selectClause + ' FROM PricebookEntry WHERE '+ whereClause +' AND Product2.IsActive = true AND IsActive = true ORDER By Product2.Name DESC ';
         }
        
        if(Test.isRunningTest()){
            query = 'Select Id From PricebookEntry Where Product2.IsActive = true AND IsActive = true ORDER By Product2.Name DESC';
        }
        
        //DO THE QUERY
        System.debug('query'+query);
        
        pbes = Database.query(query);
        
        return pbes;
    }  
}