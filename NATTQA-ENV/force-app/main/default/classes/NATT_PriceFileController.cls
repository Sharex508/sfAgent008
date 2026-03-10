public with sharing class NATT_PriceFileController {

    /**
     * Grabs Customer Price Group for LWC component
     * Has logic to check for CTM & CTBR Stores
     */
    @AuraEnabled
    public static String getCustomerPriceGroup(){
        User usr = [SELECT Id,Contact.Account.NATT_Customer_Price_Group__c, Contact.Account.NATT_Region__c FROM User WHERE Id=:UserInfo.getUserId()];
        //CTM Storefront Check
        if(usr.Contact.Account.NATT_Region__c == 'Mexico'){
            return 'CTM MEX';
        }else if(usr.Contact.Account.NATT_Region__c == 'Latin America'){
            return 'CTM LATM';
        //CTBR Storefront Check
        }else if(usr.Contact.Account.NATT_Customer_Price_Group__c== 'BCO'){
            return 'CTBR Storefront Container';
        }else if(usr.Contact.Account.NATT_Customer_Price_Group__c== 'BTT'){
            return 'CTBR Storefront Truck Trailer';
        //All Other Stores
        }else{
            return usr.Contact.Account.NATT_Customer_Price_Group__c;
        }
    }

    /**
     * Main method used for populating Price File tabs.
     * Uses different parameters to determine which tab the data is queried for (Complete, Price Changes, Advanced Books)
     * Customer Price Group will always be populated. 
     * DayValue used for Complete Price Files & Advanced Date used for Advanced Books
     */
    @ReadOnly
    @RemoteAction 
    @AuraEnabled(cacheable = false)
    public static PriceFileWrapper grabPriceFileDetails(String customerPriceGroup, Integer limitValue, String lastRecordId, String lastRecordName, String nextOrPrevious, String dayValue, String advancedDate){
        
        System.debug('Day value at start: ' + dayValue);
        Set<Id> productIdSet = new Set<Id>();
        PriceFileWrapper pFWrapper = new PriceFileWrapper();
        List<PriceFileEntry> priceFileEntryList = new List <PriceFileEntry>();
        String lastDayValue = null;
        Integer dayInt = 0;
        if (dayValue != null){
            lastDayValue = 'LAST_N_DAYS:'+dayValue;
            dayInt = Integer.valueOf(dayValue);
        }
        if (advancedDate != null){
            advancedDate = Datetime.now().format('yyyy-MM-dd');
        }
        //Exit this method and return null if no Customer Price Group was found
        if(customerPriceGroup == null || customerPriceGroup == ''){
            return pFWrapper;
        }

        Integer offsetValue = 0;
        Decimal priceValueIfNoCPG = 0;

        List<Discount_Code__mdt> discountCodeValues = [SELECT Discount_Code_Value__c, Item_Price_Group__c FROM Discount_Code__mdt];

        Integer pCount = [SELECT COUNT()
                            FROM PricebookEntry 
                            WHERE Pricebook2.Name = :customerPriceGroup 
                                AND IsActive = true 
                                AND Product2.IsActive = true AND Product2.RecordType.Name != 'NAC Products' ];
        pFWrapper.recordCount = pCount;
        grabProductItems(customerPriceGroup, limitValue, offsetValue, productIdSet, priceFileEntryList ,discountCodeValues, lastRecordId, lastRecordName, nextOrPrevious, lastDayValue, advancedDate, dayInt);
        pFWrapper.priceFiles = priceFileEntryList;
        for(PriceFileEntry pfe : pFWrapper.priceFiles){
            productIdSet.add(pfe.Id);
        }
        List<NATT_AlternativeItem__c> altItemList = [
            SELECT Alternative_P_N__c, NATT_Part_Number__c, NATT_ALternativeItem__c, NATT_ProductItem__c, NATT_ExpiryDate__c 
            FROM NATT_AlternativeItem__c
            WHERE NATT_ExpiryDate__c > TODAY AND NATT_ProductItem__c IN :productIdSet
            ORDER BY NATT_ExpiryDate__c ASC
        ];
        Map<String,String> altItemMatch = new Map<String,String>();
        for(NATT_AlternativeItem__c altItem : altItemList){
            if(altItemMatch.containsKey(altItem.NATT_ProductItem__c)){
                continue;
            }
            altItemMatch.put(altItem.NATT_ProductItem__c,altItem.Alternative_P_N__c);
        }
        for(PriceFileEntry entry : pFWrapper.priceFiles){
            //Signal Code Check here
            // if(entry.SignalCode == 'S2'){
            //     entry.Supersedure = altItemMatch.get(entry.Id);
            // }
        }
        return pFWrapper;
    }
    
    /**
     * Method used to grab and populate the Price File products.
     * PricebookEntry list gets queried and those values are used to populate the Price File Entry wrapper
     */
    private static void grabProductItems(String customerPriceGroup, Integer limitValue, Integer offsetValue, Set<Id> productIdSet, 
                                            List<PriceFileEntry> priceFileEntryList,  
                                            List<Discount_Code__mdt> discountCodeValues, String lastRecordId, String lastRecordName, String nextOrPrevious, String lastDayValue,  String advancedDate, Integer dayInt){
        List <PricebookEntry> pbeList = grabPricebookEntries(customerPriceGroup, limitValue, lastRecordId, lastRecordName, nextOrPrevious, lastDayValue, advancedDate, offsetValue);
        if(nextOrPrevious != null){
            pbeList.sort();
        }
        
        for(PricebookEntry pbe : pbeList){
            productIdSet.add(pbe.Product2Id);
        }
        Map<Id, PricebookEntry> priceBookCheck = new Map<Id, PricebookEntry>();
        Set <PricebookEntry> noDuplicatePBE = new Set <PricebookEntry>();
        List <PricebookEntry> standardPBE = new List <PricebookEntry>();
        List <PricebookEntry> pricebookEntryListBeforeCheck = new List <PricebookEntry>();

        //If lastDayValue found, Price Change logic used
        if(lastDayValue != null){
           String soql = 'SELECT ProductCode, UnitPrice, ID, Product2Id, Pricebook2Id, NATT_Effective_Date__c, Product2.Description, Product2.NATT_UnitCost__c,  Product2.NATT_Core__c, '+
            'Product2.NATT_SignalCode__c, Product2.NATT_PpgDiscountCode__c, Product2.NATT_Weight__c, Product2.NATT_Height__c, Product2.NATT_Length__c, Product2.NATT_Width__c, Product2.NATT_UOM_Conversion__c, '+
            'Product2.NATT_CoreItem_P_N__c, Product2.NATT_ItemPriceGroup__c,  Product2.Name, Product2.NATT_P_N__c, Product2.NATT_Price_Tier_Code__c,Product2.NATT_Cat_Code7_Description_Family__c,Product2.NATT_Cat_Cde6_Description__c, Product2.NATT_Category__c, Product2.NATT_SubCategory__c '+
            'FROM PricebookEntry WHERE IsActive = true AND Product2.IsActive = true AND Pricebook2.Name LIKE \'%'+ customerPriceGroup +'%\' AND Product2.RecordType.Name != \'NAC Products\' ORDER BY Product2.Name, Id ';
            pricebookEntryListBeforeCheck = Database.query(soql);
        }else{
            pricebookEntryListBeforeCheck = [SELECT Product2.NATT_P_N__c, UnitPrice, ID, Product2Id, Pricebook2Id, NATT_Effective_Date__c, Product2.Description, Product2.NATT_UnitCost__c
                                        FROM PricebookEntry 
                                        WHERE Product2Id IN :productIdSet
                                            AND Product2Id IN :productIdSet
                                            AND IsActive = true AND Pricebook2.IsStandard=true
                                            AND Product2Id IN :productIdSet AND Product2.RecordType.Name != 'NAC Products' LIMIT 100];
        }
        for(PricebookEntry pbe : pricebookEntryListBeforeCheck){
            priceBookCheck.put(pbe.Product2Id, pbe);
        }
        for(PricebookEntry entry : pbeList){
            PriceFileEntry pfItem = new PriceFileEntry();
            //If Price Change, checks to see if queried Standard Pricebook Entry exists in CPG Pricebook
            if(lastDayValue != null){
                if(priceBookCheck.containsKey(entry.Product2Id)){
                    pfItem = createPriceFileWrapperItem(entry, pfItem, priceBookCheck, lastDayValue, productIdSet, discountCodeValues, customerPriceGroup);
                    priceFileEntryList.add(pfItem);
                }
            }else{
                pfItem = createPriceFileWrapperItem(entry, pfItem, priceBookCheck, lastDayValue, productIdSet, discountCodeValues, customerPriceGroup);
                priceFileEntryList.add(pfItem);
            }
           
        }  

    }
    /**
     * Method used to create PriceFileEntry Wrapper.
     * Price Changes queries Standard Pricebook instead of CPG Pricebook, so logic changes based on if Price Changes is running
     */
    private static PriceFileEntry createPriceFileWrapperItem(PricebookEntry entry, PriceFileEntry pfItem, Map<Id, PricebookEntry> priceBookCheck, String lastDayValue, Set<Id> productIdSet, List<Discount_Code__mdt> discountCodeValues, String customerPriceGroup){
        pfItem.PKG = entry.Product2.NATT_UOM_Conversion__c;
 
        //Basis price should be from Standard Price Book
        if(lastDayValue != null){
            pfItem.BasisPrice = entry.UnitPrice.setScale(2, RoundingMode.HALF_UP);
        }else{
            pfItem.BasisPrice = priceBookCheck.containsKey(entry.Product2Id)?priceBookCheck.get(entry.Product2Id).UnitPrice.setScale(2, RoundingMode.HALF_UP):0;
        }
        if(pfItem.PKG > 1 && (pfItem.BasisPrice != null && pfItem.BasisPrice != 0)){
            pfItem.EachPrice = pfItem.BasisPrice/pfItem.PKG;
            pfItem.EachPrice = pfItem.EachPrice.setScale(2, RoundingMode.HALF_UP);
        }else{
            pfItem.EachPrice =  pfItem.BasisPrice.setScale(2, RoundingMode.HALF_UP);
        }
        //Internal Customer Check
        if(customerPriceGroup.startsWith('V1') && entry.Product2.NATT_UnitCost__c != null){
            //Transfer price assigned only for Internal Customers
            pfItem.TransferPrice = priceBookCheck.containsKey(entry.Product2Id)?priceBookCheck.get(entry.Product2Id).UnitPrice.setScale(2, RoundingMode.HALF_UP):0;//entry.UnitPrice.setScale(2, RoundingMode.HALF_UP);
        }
        
        pfItem.ExchCore = entry.Product2.NATT_CoreItem_P_N__c != null?'YES':'NO';               
        pfItem.CoreReference = entry.Product2.NATT_CoreItem_P_N__c;            

        if(entry.Product2.NATT_Core__c){
            pfItem.ExchCore = 'CORE';
        }                

        pfItem.PartNumber = entry.Product2.NATT_P_N__c;
        pfItem.Id = entry.Product2Id;
        pfItem.Description = entry.Product2.Name;
        pfItem.Description = pfItem.Description.replaceAll(',',' ').replaceAll('  ',' ').trim();
        pfItem.SignalCode = entry.Product2.NATT_SignalCode__c;
        pfItem.DiscountCode = grabDiscountCode(entry.Product2.NATT_ItemPriceGroup__c, discountCodeValues);
        pfItem.Weight = entry.Product2.NATT_Weight__c;
        pfItem.Length = entry.Product2.NATT_Length__c;
        pfItem.Width = entry.Product2.NATT_Width__c;
        pfItem.Height = entry.Product2.NATT_Height__c;
        //Effective date assigned from standard pricebook
        if(lastDayValue != null){
            pfItem.EffectiveDate = entry.NATT_Effective_Date__c;
        }else{
            pfItem.EffectiveDate = priceBookCheck.containsKey(entry.Product2Id)?priceBookCheck.get(entry.Product2Id).NATT_Effective_Date__c:null;
        }
        return pfItem;
    }

    /**
     * Queries Pricebook Entries. Depending on the values that are passed in, it will trigger different additions to the SOQL statement.
     * The different SOQL statemnet additions relate to the different funcitonalities/tabs related to Price Files
     * 
     */
    
    private static List <PricebookEntry> grabPricebookEntries(String customerPriceGroup, Integer limitValue, String lastRecordId, String lastRecordName, String nextOrPrevious, String lastDayValue, String advancedDate, Integer offsetValue){
        String soql = 'SELECT ProductCode, UnitPrice, ID, Product2Id, Pricebook2Id, NATT_Effective_Date__c, Product2.Description, Product2.NATT_UnitCost__c,  Product2.NATT_Core__c, '+
                            'Product2.NATT_SignalCode__c, Product2.NATT_PpgDiscountCode__c, Product2.NATT_Weight__c, Product2.NATT_Height__c, Product2.NATT_Length__c, Product2.NATT_Width__c, Product2.NATT_UOM_Conversion__c, '+
                            'Product2.NATT_CoreItem_P_N__c, Product2.NATT_ItemPriceGroup__c,  Product2.Name, Product2.NATT_P_N__c '+
                            'FROM PricebookEntry WHERE IsActive = true AND Product2.IsActive = true AND Product2.RecordType.Name != \'NAC Products\' ';
                    
        //lastDayValue used in Price Changes to determine amount of time for the query
        //CTM Storefront does not use Standard Price Book
        System.debug('CustomerPriceGroup Value: ' + customerPriceGroup);
        if(customerPriceGroup == 'CTM MEX' || customerPriceGroup == 'CTM LATM' || customerPriceGroup == 'CTBR Storefront Container' || customerPriceGroup == 'CTBR Storefront Truck Trailer'){
            if(lastDayValue != null){
                soql += 'AND Pricebook2.Name LIKE \'%'+ customerPriceGroup +'%\' AND (NATT_Effective_Date__c =' + lastDayValue + ' ) ';
            }else{
                soql += 'AND Pricebook2.Name LIKE \'%'+ customerPriceGroup +'%\'';
            }
        }else{
            if(lastDayValue != null){
                soql += 'AND Pricebook2.Name = \'Standard Price Book\' AND (NATT_Effective_Date__c =' + lastDayValue + ' ) ';
            }else{
                soql += 'AND Pricebook2.Name = \''+ customerPriceGroup +'\' ';
            }
        }
        //nextOrPrevious used in Complete Price Files for navigation
        System.debug('Next or Previous: ' + nextOrPrevious);
        if(nextOrPrevious != null){
            //replace catches '' in Product name and reformats characters so they work in SOQL query.
            lastRecordName = lastRecordName.replace('\'\'','\\'+'\''+'\\'+'\'' );
            lastRecordName = String.escapeSingleQuotes(lastRecordName);
        }

        //advancedDate used in Advanced Books to determine the current date used in query (queries any product thats effective after today)
        if(advancedDate != null){
             soql += 'AND (NATT_Effective_Date__c >' + advancedDate + ' )';
        }
        soql += ' ORDER BY Product2.Name, Id ';
        //limitValue determines how many products get queried. Used mainly for pagination in Complete Price Files
        if(limitValue != null && (lastDayValue == null || advancedDate == null)){
            soql += 'LIMIT ' + limitValue +'';
        }else{
            if(offsetValue != null){
                soql += ' OFFSET ' + offsetValue + '';
            }
        }
        List<PricebookEntry> pbeList = Database.query(soql);
        return pbeList;
    }

    /**
     * Queries Discount Code from metadata using the Product's itemPriceGroup value
     */
    private static String grabDiscountCode(String itemPriceGroup, List<Discount_Code__mdt> discountCodeValues){
        String returnValue;
        for(Discount_Code__mdt discountCodeMeta : discountCodeValues){
            if(discountCodeMeta.Item_Price_Group__c == itemPriceGroup){
                returnValue = discountCodeMeta.Discount_Code_Value__c;
                break;
            }else{
                returnValue = 'A';
            }
        }
        return returnValue;
    }

    public Class PriceFileWrapper {
        @AuraEnabled public List < PriceFileEntry > priceFiles {get;set;}
        @AuraEnabled public Integer recordCount {get;set;}
    }

    public class PriceFileEntry {
        @AuraEnabled public String Id {get;set;}
        @AuraEnabled public String PartNumber {get;set;}
        @AuraEnabled public String Description {get;set;}
        @AuraEnabled public Decimal PKG {get;set;}
        @AuraEnabled public String Supersedure {get;set;}
        @AuraEnabled public Decimal EachPrice {get;set;}
        @AuraEnabled public String ExchCore {get;set;}
        @AuraEnabled public String CoreReference {get;set;}
        @AuraEnabled public String SignalCode {get;set;}
        @AuraEnabled public String DiscountCode {get;set;}
        @AuraEnabled public Decimal Weight {get;set;}
        @AuraEnabled public Decimal Length {get;set;}
        @AuraEnabled public Decimal Width {get;set;}
        @AuraEnabled public Decimal Height {get;set;}
        @AuraEnabled public Date EffectiveDate {get;set;}
        @AuraEnabled public Decimal BasisPrice {get;set;}
        @AuraEnabled public Decimal TransferPrice {get;set;}
        @AuraEnabled public String CoreFlag {get;set;}
        @AuraEnabled public String ProductCategory {get;set;}
        @AuraEnabled public String ProductSubCategory {get;set;}
        @AuraEnabled public String PriceTierCode {get;set;}
    }

    @ReadOnly
    @RemoteAction
    @AuraEnabled
    public static PriceFileWrapper getPriceFileDetails(String customerPriceGroup){
        boolean isV1 = customerPriceGroup.startsWith('V1');
        customerPriceGroup = '%'+customerPriceGroup+'%';
        Map<Id,PricebookEntry> pbeMap = new Map<Id,PricebookEntry>();
        Map<Id,PricebookEntry> standardPbeMap = new Map<Id,PricebookEntry>();
        PriceFileWrapper pfw = new PriceFileWrapper();    
        //boolean isV1 = customerPriceGroup.startsWith('V1');
       
        List<PriceFileEntry> priceFileEntryList = new List <PriceFileEntry>();
        Map<String,String> discountCodeMap = new Map<String,String>();

        for(Discount_Code__mdt discountCode :  [SELECT Discount_Code_Value__c, Item_Price_Group__c FROM Discount_Code__mdt]){
            discountCodeMap.put(discountCode.Item_Price_Group__c,discountCode.Discount_Code_Value__c);
        }

        Integer pCount = [SELECT COUNT()
                            FROM PricebookEntry 
                            WHERE Pricebook2.Name LIKE :customerPriceGroup 
                                AND IsActive = true 
                                AND Product2.IsActive = true
                                AND Product2.NATT_SignalCode__c!='NSU' AND Product2.RecordType.Name != 'NAC Products'];
        pfw.recordCount=pCount;

        for(PricebookEntry pbe : [SELECT UnitPrice, Id, Product2Id, NATT_Effective_Date__c
                                    FROM PricebookEntry WHERE IsActive = true 
                                    AND Product2.IsActive = true AND Pricebook2.IsStandard=true
                                    AND Product2.RecordType.DeveloperName='NATT_Products'
                                    AND Product2.NATT_SignalCode__c!='NSU'])
        {
            standardPbeMap.put(pbe.Product2Id,pbe);
        }

        for(PricebookEntry pbe : [SELECT ProductCode, UnitPrice, ID, Product2Id, Pricebook2Id, NATT_Effective_Date__c, Product2.Description, Product2.NATT_UnitCost__c,  Product2.NATT_Core__c,  
                                    Product2.NATT_SignalCode__c, Product2.NATT_PpgDiscountCode__c, Product2.NATT_Weight__c, Product2.NATT_Height__c, Product2.NATT_Length__c, Product2.NATT_Width__c, Product2.NATT_UOM_Conversion__c, 
                                    Product2.NATT_CoreItem_P_N__c, Product2.NATT_ItemPriceGroup__c,  Product2.Name, Product2.NATT_P_N__c, Product2.NATT_Price_Tier_Code__c,Product2.NATT_Cat_Code7_Description_Family__c,Product2.NATT_Cat_Cde6_Description__c, Product2.NATT_Category__c, Product2.NATT_SubCategory__c 
                                    FROM PricebookEntry WHERE IsActive = true AND Product2.IsActive = true AND Pricebook2.Name LIKE :customerPriceGroup AND Product2.NATT_SignalCode__c!='NSU' AND Product2.RecordType.Name != 'NAC Products' ORDER BY Product2.Name])
            {           
            PriceFileEntry pfItem = new PriceFileEntry();         
            
            pfItem.PKG = pbe.Product2.NATT_UOM_Conversion__c;

            //Basis price should be from Standard Price Book if not CTM Storefront
            if(customerPriceGroup == '%CTM MEX%' || customerPriceGroup == '%CTM LATM%' || customerPriceGroup == '%CTBR Storefront Container%' || customerPriceGroup == '%CTBR Storefront Truck Trailer%'){
                pfItem.BasisPrice = pbe.UnitPrice;
            }else{
                pfItem.BasisPrice = standardPbeMap.containsKey(pbe.Product2Id)?standardPbeMap.get(pbe.Product2Id).UnitPrice:0;
            }
            // pfItem.BasisPrice = standardPbeMap.containsKey(pbe.Product2Id)?standardPbeMap.get(pbe.Product2Id).UnitPrice:0;
            
            if(pfItem.PKG > 1 && pfItem.BasisPrice != 0){
                pfItem.EachPrice = pfItem.BasisPrice/pfItem.PKG;
                pfItem.EachPrice = pfItem.EachPrice;
            }else{
                pfItem.EachPrice =  pfItem.BasisPrice;
            }
          
            //Internal Customer Check
            if(isV1 && pbe.Product2.NATT_UnitCost__c != null ){
                //Transfer price assigned only for Internal Customers
                pfItem.TransferPrice = pbe.UnitPrice;
            }
            
            pfItem.ExchCore = pbe.Product2.NATT_CoreItem_P_N__c != null?'YES':'NO';               
            pfItem.CoreReference = pbe.Product2.NATT_CoreItem_P_N__c;            

            if(pbe.Product2.NATT_Core__c){
                pfItem.ExchCore = 'CORE';
            }    
            pfItem.PartNumber = pbe.Product2.NATT_P_N__c;
            pfItem.Id = pbe.Product2Id;
            pfItem.Description = pbe.Product2.Name;
            pfItem.Description = pfItem.Description.replaceAll(',',' ').replaceAll('  ',' ').trim();            
            pfItem.SignalCode = pbe.Product2.NATT_SignalCode__c;
            pfItem.DiscountCode = 'A';
            if(discountCodeMap.containsKey(pbe.Product2.NATT_ItemPriceGroup__c)){
                pfItem.DiscountCode=discountCodeMap.get(pbe.Product2.NATT_ItemPriceGroup__c);
            }
            pfItem.Weight = pbe.Product2.NATT_Weight__c;
            pfItem.Length = pbe.Product2.NATT_Length__c;
            pfItem.Width = pbe.Product2.NATT_Width__c;
            pfItem.Height = pbe.Product2.NATT_Height__c;
                pfItem.ProductCategory = pbe.Product2.NATT_Cat_Code7_Description_Family__c;
                pfItem.ProductSubCategory = pbe.Product2.NATT_Cat_Cde6_Description__c;
                pfItem.PriceTierCode = pbe.Product2.NATT_Price_Tier_Code__c; 
            pfItem.EffectiveDate =standardPbeMap.containsKey(pbe.Product2Id)?standardPbemap.get(pbe.Product2Id).NATT_Effective_Date__c:null; 
            if (pfItem.EffectiveDate != null){System.debug('Name: ' + pbe.Product2.Name + ' || Date: ' + pfItem.EffectiveDate);     }   
         
            priceFileEntryList.add(pfItem);            
        }        
        pfw.priceFiles=priceFileEntryList;
        return pfw;
    }

    @AuraEnabled
    public static Map<String,String> getAltItemMap(){
        try {   
            Map<String,String> altItemMap = new Map<String,String>();
            for(List<NATT_AlternativeItem__c> altItemList :  [SELECT Alternative_P_N__c, NATT_Part_Number__c, NATT_AlternativeItem__c, NATT_ProductItem__c, NATT_ExpiryDate__c 
                                                                FROM NATT_AlternativeItem__c
                                                                WHERE NATT_ExpiryDate__c > TODAY 
                                                                ORDER BY NATT_ExpiryDate__c ASC]){
                for(NATT_AlternativeItem__c altItem: altItemList){
                    if(!altItemMap.containsKey(altItem.NATT_ProductItem__c)){
                        altItemMap.put(altItem.NATT_ProductItem__c,altItem.Alternative_P_N__c);
                    }
                }                
            }    
            return altItemMap;           
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }
}