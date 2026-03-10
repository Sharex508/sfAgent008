public without sharing class NAC_CatalogPDFController {
    public Map<Integer, PriceBookWrapper> productData{get;set;}
    
    public NAC_CatalogPDFController(ApexPages.StandardController con) {
        DateTime dT = System.now();
        Set<Id> Product2Id = new Set<Id>();
        WebStoreBuyerGroup storeBuyerGroup;
        productData = new Map<Integer, PriceBookWrapper>();
        List<PricebookEntry> prodData = new List<PricebookEntry>();
        Map<Id, PricebookEntry> ProdDataMap = new Map<Id, PricebookEntry>();
        List<String> externalUserItemCode = Label.NAOCAP_External_User_Item_Code.split(',');
        Map<Id, NATT_AlternativeItem__c> mapOfproductSuperseded = new Map<Id, NATT_AlternativeItem__c>();
        String customerType, myDate = (String.valueOf(date.newinstance(dT.year(), dT.month(), dT.day()))).substring(0,10);
        Set<String> coreItemPNset = new Set<string>(), signalVal = new Set<String>{'A','BY2','FIN','PRC','S1'}, signalValsecond = new Set<String>{'N/A','OBS'}, signValthird = new Set<String>{'NSI','A','BY2','PRC','FIN','S1'}, signValfourth = new Set<String>{'S2','N/A','OBS','NSU'};
            Apexpages.currentPage().getHeaders().put('content-disposition', 'attachment; filename=Container List Price Book'+' '+myDate+'.pdf');
        User userDetail = [SELECT contactid, contact.AccountId, isportalenabled FROM User WHERE Id =: UserInfo.getUserId() LIMIT 1];
        Id containerStoreId = [SELECT id from Webstore WHERE Name =: Label.NAOCAP_Store_Name LIMIT 1]?.Id;
        Boolean hasCustomPermission = FeatureManagement.checkPermission ('UCP_Download_Pricebook_Access');
            list<PermissionSetAssignment> PermissionSetLicenseAssign = [SELECT Id, PermissionSet.Name, AssigneeId from PermissionSetAssignment where  AssigneeId =:UserInfo.getUserId() and (PermissionSet.Name = 'NAOCP_Commerce_Finance' or PermissionSet.Name = 'NAOCP_Commerce_Parts_Ordering') limit 1];
            boolean licenceAssigned = false;
            if(PermissionSetLicenseAssign.size() > 0){
                licenceAssigned = true;
            }
        if(userDetail.isportalenabled  && (!hasCustomPermission || licenceAssigned) ){
            storeBuyerGroup = [SELECT BuyerGroupId, BuyerGroup.NAC_Type__c from WebStoreBuyerGroup WHERE WebStoreId =: containerStoreId AND BuyerGroupId IN (SELECT BuyerGroupId FROM BuyerGroupMember WHERE BuyerId =: userDetail.contact.AccountId) LIMIT 1];
            customerType = storeBuyerGroup.BuyerGroup.NAC_Type__c;
        }
        //For external customers we need to filter products on Item code
        if(userDetail.isportalenabled && (hasCustomPermission || Label.NAOCAP_External_Customer_Group.contains(customerType))){
            //For external customers we need to filter products on Item code
            prodData=[SELECT CurrencyIsoCode,Name,NATT_Effective_Date__c,Pricebook2Id,Product2Id,Product2.id,Product2.NATT_Weight__c,Product2.ProductCode,Product2.NATT_SignalCode__c,
                      Product2.NATT_Height__c,Product2.NATT_Width__c,Product2.NATT_Discount_Code__c,Product2.NAC_Stocking_Type_UTC__c,Product2.NATT_Length__c,Product2.NAC_Country_of_Origin_COO__c,Product2.NAC_HTSUS__c,
                      Product2.NATT_P_N__c,Product2.Name, Product2.NATT_Core__c ,Product2.NATT_UOM_Conversion__c,Product2.NATT_CoreItem_P_N__c,
                      ProductCode,UnitPrice,UseStandardPrice, Product2.NAC_Line_Of_Business__c FROM PricebookEntry WHERE Pricebook2.Name = 'NA Containers Marketplace Strikethrough Price Book' AND Product2.NATT_ItemPriceGroup__c IN:externalUserItemCode];
            
        }else{
            prodData=[SELECT CurrencyIsoCode,Name,NATT_Effective_Date__c,Pricebook2Id,Product2Id,Product2.id,Product2.NATT_Weight__c,Product2.ProductCode,Product2.NATT_SignalCode__c,
                      Product2.NATT_Height__c,Product2.NATT_Width__c,Product2.NATT_Discount_Code__c,Product2.NAC_Stocking_Type_UTC__c,Product2.NATT_Length__c,Product2.NAC_Country_of_Origin_COO__c,Product2.NAC_HTSUS__c,
                      Product2.NATT_P_N__c,Product2.Name, Product2.NATT_Core__c ,Product2.NATT_UOM_Conversion__c,Product2.NATT_CoreItem_P_N__c,
                      ProductCode,UnitPrice,UseStandardPrice, Product2.NAC_Line_Of_Business__c FROM PricebookEntry WHERE Pricebook2.Name = 'NA Containers Marketplace Strikethrough Price Book'];
        }
        
        
        for(PricebookEntry pe:prodData){
            ProdDataMap.put(pe.product2Id,pe);
        } 
        
        for (Integer i = 0; i < prodData.size(); i++){
            Product2Id.add(prodData[i].Product2Id);
        }
        //getting products with core
        List<Product2> prWithCoreItem=new List<Product2>([SELECT Id, Name, NATT_CoreItem_P_N__c,NATT_CorePrice__c,NATT_Branch_Plant_Warehouse__c  FROM Product2 where Id IN:Product2Id AND NATT_CoreItem_P_N__c!=null and NATT_Branch_Plant_Warehouse__c ='ATL' ]);
        
        for(Product2 prod:prWithCoreItem){
            coreItemPNset.add(prod.NATT_CoreItem_P_N__c);
        }
        //getting the details of core with part number as key and storing in the map//
        MAp<String,Product2> mapOfCorePrDetails=new MAp<String,PRoduct2>();
        for(Product2 prIterator:[select id,ProductCode,Name,NATT_P_N__c,NAOCAP_Not_Orderable__c,NATT_CorePrice__c  from product2 where NATT_P_N__c IN :coreItemPNset and NATT_Branch_Plant_Warehouse__c ='ATL' AND recordtype.Name='NAC Products']){
            mapOfCorePrDetails.put(prIterator.NATT_P_N__c, prIterator);
        }
        for(NATT_AlternativeItem__c nAc:[SELECT Id, NATT_AlternativeItem__c,NATT_ProductItem__r.NAC_Stocking_Type_UTC__c, NATT_ProductItem__r.NATT_SignalCode__c , NATT_ProductItem__r.ProductCode,NATT_ProductItem__r.Name,NATT_AlternativeItem__r.Name,
                                         NATT_AlternativeItem__r.ProductCode,NATT_AlternativeItem__r.NATT_CoreItem_P_N__c ,NATT_ALternativeItem__r.NATT_P_N__c,NATT_ProductItem__r.NATT_P_N__c FROM NATT_AlternativeItem__c WHERE 
                                         NATT_ProductItem__c=:Product2Id AND NATT_ProductItem__r.NATT_SignalCode__c='S2' ORDER BY NATT_EffectiveDate__c DESC]){
                                             mapOfproductSuperseded.put(nAc.NATT_ProductItem__c,nAc);
                                         }
        
        for(integer i=0;i<prodData.size();i++){
            PriceBookWrapper pbWrapper = new PriceBookWrapper();
            pbWrapper.Superseded = ' ';
            pbWrapper.PartNumber = ' ';  
            pbWrapper.PKG =0;
            pbWrapper.AlternatePart = '';
            pbWrapper.Weight = 0;
            pbWrapper.Length = 0;
            pbWrapper.core_Reference=' ';
            pbWrapper.lineOfBusiness='';
            pbWrapper.Width = 0;
            pbWrapper.Height = 0;
            pbWrapper.COO = ''; 
            pbWrapper.HTSUS = ''; 
            pbWrapper.SignalCode ='';    
            pbWrapper.Description = prodData[i].Name;
            pbWrapper.Price =0;
            pbWrapper.Each_price =0; 
            //pbWrapper.totalproductPrice=0;
            pbWrapper.coreListPrice='';
            
            if(mapOfproductSuperseded.containsKey(prodData[i].Product2Id)){
                pbWrapper.Superseded = mapOfproductSuperseded.get(prodData[i].Product2Id).NATT_ALternativeItem__r.ProductCode;
            }
            /*Signal Code Updated Logic CXREF- 3820*/
            if(signalVal.contains(prodData[i].Product2.NATT_SignalCode__c))
                pbWrapper.SignalCode ='A';
            if(prodData[i].Product2.NATT_SignalCode__c == 'NLO' && prodData[i].Product2.NAC_Stocking_Type_UTC__c == 'U')
                pbWrapper.SignalCode ='A';
            if(prodData[i].Product2.NATT_SignalCode__c == 'NLO' && prodData[i].Product2.NAC_Stocking_Type_UTC__c == 'O')
                pbWrapper.SignalCode ='NLO';
            if(signalValsecond.contains(prodData[i].Product2.NATT_SignalCode__c))
                pbWrapper.SignalCode ='NLO';
            if(prodData[i].Product2.NATT_SignalCode__c == 'NSI')
                pbWrapper.SignalCode ='NSI';
            if(prodData[i].Product2.NATT_SignalCode__c == 'NSU' || prodData[i].Product2.NATT_SignalCode__c == 'NEW')
                pbWrapper.SignalCode ='NSU';
            
            if(prodData[i].Product2.ProductCode != null){
                pbWrapper.PartNumber = prodData[i].Product2.ProductCode;
            }
            /*packaging*/
            if(prodData[i].Product2.NATT_UOM_Conversion__c != null){
                pbWrapper.PKG=prodData[i].Product2.NATT_UOM_Conversion__c;
            }
            ////superseded
            if(mapOfproductSuperseded.get(prodData[i].Product2Id) != null){
                if(mapOfproductSuperseded.get(prodData[i].Product2Id).NATT_ProductItem__r.NATT_P_N__c != null){
                    
                    pbWrapper.AlternatePart = mapOfproductSuperseded.get(prodData[i].Product2Id).NATT_ALternativeItem__r.NATT_P_N__c;
                }else{
                    pbWrapper.AlternatePart = '';
                }
            }
            /*Pricing */
            if(prodData[i].UnitPrice != null && signValthird.contains(prodData[i].Product2.NATT_SignalCode__c)){
                pbWrapper.Price=prodData[i].UnitPrice;
              if(prodData[i].Product2.NATT_UOM_Conversion__c != null && prodData[i].Product2.NATT_UOM_Conversion__c != 0){
                    Decimal up           =pbWrapper.Price;
                    Decimal UOM          =prodData[i].Product2.NATT_UOM_Conversion__c;
                    pbWrapper.Each_price =up/UOM; 
                }else{
                    pbWrapper.Each_price =pbWrapper.Price;
                }
                //Calculating core item pricing CXREF- 3280//
                if(mapOfCorePrDetails.containsKey(prodData[i].product2.NATT_CoreItem_P_N__c )){
                    if(ProdDataMap.containsKey(mapOfCorePrDetails.get(prodData[i].product2.NATT_CoreItem_P_N__c).id)){
                        if(ProdDataMap.get(mapOfCorePrDetails.get(prodData[i].product2.NATT_CoreItem_P_N__c).id).UnitPrice != null){
                            pbWrapper.totalproductPrice = pbWrapper.Price + ProdDataMap.get(mapOfCorePrDetails.get(prodData[i].product2.NATT_CoreItem_P_N__c).id).UnitPrice;
                            pbWrapper.coreListPrice = String.ValueOf(ProdDataMap.get(mapOfCorePrDetails.get(prodData[i].product2.NATT_CoreItem_P_N__c).id).UnitPrice);
                        }else{
                            pbWrapper.totalproductPrice = pbWrapper.Price;
                            pbWrapper.coreListPrice = '';
                        }
                    }
                    else{
                        pbWrapper.totalproductPrice = pbWrapper.Price;
                        pbWrapper.coreListPrice = '';
                    }
                }else{
                    //pbWrapper.totalproductPrice= pbWrapper.Price;
                    pbWrapper.coreListPrice = '';
                }
            }
            if(prodData[i].UnitPrice != null && prodData[i].Product2.NATT_SignalCode__c == 'NLO' && prodData[i].Product2.NAC_Stocking_Type_UTC__c == 'U'){
                pbWrapper.Price=prodData[i].UnitPrice;
                if(prodData[i].Product2.NATT_UOM_Conversion__c != null && prodData[i].Product2.NATT_UOM_Conversion__c != 0){
                    Decimal up           =pbWrapper.Price;
                    Decimal UOM          =prodData[i].Product2.NATT_UOM_Conversion__c;
                    pbWrapper.Each_price =up/UOM; 
                }else{
                    pbWrapper.Each_price =pbWrapper.Price;
                }
                //Calculating core item pricing CXREF- 3280//
                if(mapOfCorePrDetails.containsKey(prodData[i].product2.NATT_CoreItem_P_N__c )){
                    if(ProdDataMap.containsKey(mapOfCorePrDetails.get(prodData[i].product2.NATT_CoreItem_P_N__c).id)){
                        if(ProdDataMap.get(mapOfCorePrDetails.get(prodData[i].product2.NATT_CoreItem_P_N__c).id).UnitPrice != null){
                            pbWrapper.totalproductPrice = pbWrapper.Price + ProdDataMap.get(mapOfCorePrDetails.get(prodData[i].product2.NATT_CoreItem_P_N__c).id).UnitPrice;
                            pbWrapper.coreListPrice = String.ValueOf(ProdDataMap.get(mapOfCorePrDetails.get(prodData[i].product2.NATT_CoreItem_P_N__c).id).UnitPrice);
                        }else{
                            pbWrapper.totalproductPrice = pbWrapper.Price;
                            pbWrapper.coreListPrice = '';
                        }
                    }
                    else{
                        pbWrapper.totalproductPrice = pbWrapper.Price;
                        pbWrapper.coreListPrice = '';
                    }
                }else{
                    //pbWrapper.totalproductPrice = pbWrapper.Price;
                    pbWrapper.coreListPrice = '';
                }
            }
            if(prodData[i].UnitPrice != null && signValfourth.contains(prodData[i].Product2.NATT_SignalCode__c)){
                pbWrapper.Price=0;
                pbWrapper.Each_price=0;
                //pbWrapper.totalproductPrice = 0;
                pbWrapper.coreListPrice = '';
            }
            if(prodData[i].UnitPrice != null && prodData[i].Product2.NATT_SignalCode__c == 'NLO' && prodData[i].Product2.NAC_Stocking_Type_UTC__c == 'O'){
                pbWrapper.Price=0;
                pbWrapper.Each_price=0;
                //pbWrapper.totalproductPrice = 0;
                pbWrapper.coreListPrice = ' ';
            }
            if(prodData[i].Product2.NATT_CoreItem_P_N__c != null){
                pbWrapper.EXCH_CORE='Exchange';
            }else if(prodData[i].Product2.NATT_Core__c){
                pbWrapper.EXCH_CORE='Core';
            }
            else{
                pbWrapper.EXCH_CORE='';
            }
            
            if(prodData[i].Product2.NATT_Weight__c != null){
                pbWrapper.Weight = prodData[i].Product2.NATT_Weight__c;
            }
            
            if(prodData[i].Product2.NATT_Length__c != null){
                pbWrapper.Length = prodData[i].Product2.NATT_Length__c;
            }
            
            if(prodData[i].Product2.NATT_CoreItem_P_N__c != null){
                pbWrapper.core_Reference=prodData[i].Product2.NATT_CoreItem_P_N__c;
            }
            
            if(prodData[i].Product2.NAC_Line_Of_Business__c !=null){
                pbWrapper.lineOfBusiness=prodData[i].Product2.NAC_Line_Of_Business__c;
            }
            
            if(prodData[i].Product2.NATT_Width__c != null){
                pbWrapper.Width = prodData[i].Product2.NATT_Width__c;
            }            
            if(prodData[i].Product2.NATT_Height__c != null){
                pbWrapper.Height = prodData[i].Product2.NATT_Height__c;
            }
            
            if(prodData[i].Product2.NAC_Country_of_Origin_COO__c != null){
                pbWrapper.COO = prodData[i].Product2.NAC_Country_of_Origin_COO__c;
            }
            if(prodData[i].Product2.NAC_HTSUS__c != null){
                pbWrapper.HTSUS = prodData[i].Product2.NAC_HTSUS__c;
            }
            
            productData.put(i,pbWrapper);
        }
    }
    
    public class PriceBookWrapper{
        @AuraEnabled public String PartNumber{get;set;}
        @AuraEnabled public string Description{get;set;}
        @AuraEnabled public Decimal PKG{get;set;}
        @AuraEnabled public String AlternatePart{get;set;}
        @AuraEnabled public Decimal Price{get;set;}
        @AuraEnabled public String EXCH_CORE{get;set;}
        @AuraEnabled public String SignalCode{get;set;}
        @AuraEnabled public String Superseded{get;set;}
        @AuraEnabled public Double Each_price{get;set;}
        @AuraEnabled public String core_Reference{get;set;}
        @AuraEnabled public Decimal Weight{get;set;}
        @AuraEnabled public Decimal Length{get;set;}
        @AuraEnabled public Decimal Width{get;set;}
        @AuraEnabled public Decimal Height{get;set;}
        @AuraEnabled public String COO{get;set;}
        @AuraEnabled public String HTSUS{get;set;}
        @AuraEnabled public String lineOfBusiness{get;set;}
        @AuraEnabled public string coreListPrice {get;set;}
        @AuraEnabled public Decimal totalproductPrice {get;set;}
    }
}