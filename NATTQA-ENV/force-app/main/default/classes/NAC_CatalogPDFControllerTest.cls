@isTest
public class NAC_CatalogPDFControllerTest {
    
    @isTest
    static void createTest(){
        
        Id prodRecordTypeId = Schema.SObjectType.Product2.getRecordTypeInfosByDeveloperName().get('NAC_Products').getRecordTypeId();
        
        List<Id> product2ATLIdList = new List<Id>();
        Map<Id, Decimal> product2PriceMap = new Map<Id, Decimal>(), allProduct2PriceMap = new Map<Id, Decimal>();
        List<Product2> product2List = NAC_TestDataFactory.createProductList(52);
        for(integer i = 0; i < product2List.size(); i++){
            product2List[i].RecordTypeId = prodRecordTypeId;
            Product2List[i].NAC_Stocking_Type_UTC__c = 'U';
            product2List[i].NATT_ItemPriceGroup__c = '510';
            product2List[i].NATT_Branch_Plant_Warehouse__c = 'ATL';
            product2List[i].ProductCode = 'TEST-' + String.valueOf(i);
            product2List[i].NATT_P_N__c = 'TEST-' + String.valueOf(i);
            product2List[i].NATT_UOM_Conversion__c = 5;
            switch on Math.Mod(i, 14) {
                when 0 {
                    product2List[i].NATT_SignalCode__c = 'A';
                }when 1 {
                    product2List[i].NATT_SignalCode__c = 'NLO';
                }when 2 {
                    product2List[i].NATT_SignalCode__c = 'NSI';
                }when 3 {
                    product2List[i].NATT_SignalCode__c = 'NSU';
                }when 4 {
                    product2List[i].NATT_SignalCode__c = 'S1';
                }when 5 {
                    product2List[i].NATT_SignalCode__c = 'S2';
                    product2List[i].NATT_CoreItem_P_N__c = 'TEST-' + String.valueOf(i - 1);
                }when 6 {
                    product2List[i].NATT_SignalCode__c = 'NRC';
                }when 7 {
                    product2List[i].NATT_SignalCode__c = 'BY2';
                }when 8 {
                    product2List[i].NATT_SignalCode__c = 'N/A';
                }when 9 {
                    product2List[i].NATT_SignalCode__c = 'OB1';
                }when 10 {
                    product2List[i].NATT_SignalCode__c = 'OBS';
                }when 11 {
                    product2List[i].NATT_SignalCode__c = 'PRC';
                }when 12 {
                    product2List[i].NATT_SignalCode__c = 'A';
                }when else {		  
                    product2List[i].NATT_SignalCode__c = 'A';
                }
            }
        }
        Product2 prod5 = new Product2(Name ='testProd1'+Math.random(),
                                     StockkeepingUnit ='SKU'+Math.random(),NATT_SignalCode__c='NLO',NAC_Stocking_Type_UTC__c='O',ProductCode='2345678',NATT_UOM_Conversion__c=2.0, NATT_CoreItem_P_N__c='2345678',
                                     NATT_Weight__c=32,NATT_Length__c=37,NATT_Height__c=23, NAC_Country_of_Origin_COO__c='xya',NAC_HTSUS__c='rtyy'
                                    );
        product2List.add(prod5);
        insert product2List;
        for(integer i = 0; i < product2List.size(); i++){
            if(i != 0){
                if(i < product2List.size() - 10){
                    product2PriceMap.put(product2List[i].Id, Math.random() * 100);
                }
                product2ATLIdList.add(product2List[i].Id);
            }
            allProduct2PriceMap.put(product2List[i].Id, Math.random() * 100);
        }
        
        List<PriceBook2> priceBookList = NAC_TestDataFactory.createPriceBook(4);
        priceBookList[0].Name = Label.NAOCAP_Prefix + 'C3';
        priceBookList[1].Name = Label.NAOCAP_Prefix + 'V1H';
        priceBookList[2].Name = Label.NAOCAP_Prefix + '48093801';
        priceBookList[3].Name = Label.NAOCAP_Strikethrough_Price_Book;
        insert priceBookList;
        NAC_TestDataFactory.createPriceBookEntry(new Map<Id, Map<Id,Decimal>>{priceBookList[0].Id => product2PriceMap, priceBookList[1].Id => product2PriceMap, priceBookList[2].Id => product2PriceMap, priceBookList[3].Id => allProduct2PriceMap});        
        
        
        PricebookEntry pd=[SELECT CurrencyIsoCode,Name,NATT_Effective_Date__c,Pricebook2Id,Product2Id,Product2.id,
                           Product2.NATT_P_N__c,Product2.Name, Product2.NATT_Core__c ,Product2.NATT_UOM_Conversion__c, 
                           ProductCode,UnitPrice,UseStandardPrice FROM PricebookEntry WHERE Pricebook2.Name =:Label.NAOCAP_Strikethrough_Price_Book LIMIT 1];
        
        Test.startTest();
        ApexPages.StandardController sc = new ApexPages.StandardController(pd);
        USer us=[select id from User where id=:userinfo.getUserId()];
        system.runAs(us){
            try{
                NAC_CatalogPDFController nc1=new NAC_CatalogPDFController(sc); 
            }
            catch(Exception ex){
                
            }
        }
        Test.stopTest();
    }
}