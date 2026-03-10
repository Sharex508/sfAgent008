public without sharing class NAC_BulkUploadController {
    
    @AuraEnabled
    public static String GetResourceURL(String resourceName) {
        List<StaticResource> resourceList = [SELECT Name, NamespacePrefix, SystemModStamp FROM StaticResource WHERE Name =: resourceName];
        if (resourceList.size() == 1) {
            String namespace = resourceList[0].NamespacePrefix;
            return URL.getSalesforceBaseUrl().toExternalForm() + '/resource/' 
                + resourceList[0].SystemModStamp.getTime() + '/' 
                + (namespace != null && namespace != '' ? namespace + '__' : '') 
                + resourceName; 
        } else return '';
    }
    
    @AuraEnabled
    public static bulkUploadProductWrapper readUploadedFile(String contentDocumentId, String communityId, String effectiveAccountId,String selectedWarehouse) {
        List<Id> productIdList = new List<Id>();
        bulkUploadProductWrapper bulkProdWrap = new bulkUploadProductWrapper();
        Set<String> skuNames = new Set<String>(), entitlementProductNameSet = new set<String>();
        Set<Id> productWithValidPrice = new Set<Id>(), ProductCategoryId = new Set<Id>(), buyerGroupIdSet = new Set<Id>();
        Map<String, String> productName2IdMap = new Map<String, String>(), productIdWithCoreProductCodeMap = new Map<String, String>(), coreProductCodeToIdMap = new Map<String, String>();
        if (contentDocumentId != null) {
            List<ContentVersion> cv = [SELECT Id, VersionData FROM ContentVersion WHERE ContentDocumentId =: contentDocumentId];
            if(!cv.isEmpty()){
                String data = cv[0].VersionData.toString();
                if(String.isNotBlank(data)){
                    List <String> lstCSVLines = data.split('\n');
                    if(lstCSVLines.size() != 1){
                        String headerRow = lstCSVLines[0].replace('\r', '');
                        List<String> headerColumn =  headerRow.split(',');
                        if(headerColumn.size() == 2){
                            for(String s : headerColumn){
                                s = s.toUpperCase();
                            }
                            Integer skuPosition = 0;
                            Integer quantityPosition = 1;
                            for(Integer i = 1; i < lstCSVLines.size(); i++){
                                String csvLine = lstCSVLines[i];
                                String prevLine = csvLine;
                                Integer startIndex;
                                Integer endIndex;
                                while(csvLine.indexOf('"') > -1){
                                    if(startIndex == null){
                                        startIndex = csvLine.indexOf('"');
                                        csvLine = csvLine.substring(0, startIndex) + ':quotes:' + csvLine.substring(startIndex+1, csvLine.length());
                                    }else{
                                        if(endIndex == null){
                                            endIndex = csvLine.indexOf('"');
                                            csvLine = csvLine.substring(0, endIndex) + ':quotes:' + csvLine.substring(endIndex+1, csvLine.length());
                                        }
                                    }
                                    if(startIndex != null && endIndex != null){
                                        String sub = csvLine.substring(startIndex, endIndex);
                                        sub = sub.replaceAll(',', ':comma:'); 
                                        csvLine = csvLine.substring(0, startIndex) + sub + csvLine.substring(endIndex, csvLine.length());
                                        startIndex = null;
                                        endIndex = null;
                                    }
                                }
                                List<String> csvRowData = new List<String>();
                                for(String column : csvLine.split(',')){
                                    column = column.replaceAll(':quotes:', '').replaceAll(':comma:', ',').replaceAll('\r', '');
                                    csvRowData.add(column);
                                }
                                ProductWrapper prodWrap = new ProductWrapper();
                                if(String.isNotBlank(csvRowData[skuPosition])){
                                    prodWrap.name = csvRowData[skuPosition];
                                    if(skuNames.contains(formatString(prodWrap.name))){
                                        prodWrap.hasError = true;
                                        prodWrap.errorMessageList.add(System.Label.nac_Bulk_Upload_Error_Message_Duplicate_Entry);
                                    }
                                    skuNames.add(formatString(prodWrap.name));
                                }else{
                                    prodWrap.hasError = true;
                                    prodWrap.errorMessageList.add(System.Label.nac_Bulk_Upload_Error_Message_Product_Code_Blank);
                                }
                                if(String.isNotBlank(csvRowData[quantityPosition])){
                                    prodWrap.quantity = csvRowData[quantityPosition];
                                    if(!isNumeric(csvRowData[quantityPosition])){
                                        prodWrap.hasError = true;
                                        prodWrap.errorMessageList.add(System.Label.nac_Bulk_Upload_Error_Message_Quantity_Not_Numeric);
                                    }else if(Decimal.valueOf(csvRowData[quantityPosition]) < 1){
                                        prodWrap.hasError = true;
                                        prodWrap.errorMessageList.add(System.Label.nac_Bulk_Upload_Error_Message_Quantity_Less_than_0);
                                    }
                                }else{
                                    prodWrap.hasError = true;
                                    prodWrap.errorMessageList.add(System.Label.nac_Bulk_Upload_Error_Message_Quantity_Blank);
                                }
                                prodWrap.index = i;
                                bulkProdWrap.prodWrapList.add(prodWrap);
                            }
                        }else{
                            //There are more than 2 column
                            bulkProdWrap.hasError = true;
                            bulkProdWrap.errorMessage = System.Label.nac_Bulk_Upload_Error_Message_More_Than_2_column;
                        }
                    }else{
                        //There is only header row and no other row
                        bulkProdWrap.hasError = true;
                        bulkProdWrap.errorMessage = System.Label.nac_Bulk_Upload_Error_Message_Contains_Only_Header;
                    }
                }else{
                    //Posible the uploaded file was empty
                    bulkProdWrap.hasError = true;
                    bulkProdWrap.errorMessage = System.Label.nac_Bulk_Upload_Error_Message_CSV_Empty;
                }
            }else{
                //Wierd, not able to query the uploaded file
                bulkProdWrap.hasError = true;
                bulkProdWrap.errorMessage = System.Label.nac_Bulk_Upload_Error_Message_Unable_Read_CSV;
            }
        }else{
            //contentDocumentId from LWC is null
            bulkProdWrap.hasError = true;
            bulkProdWrap.errorMessage = System.Label.nac_Bulk_Upload_Error_Message_Query_Error;
        }
        Set<String> partNoSet = new Set<String>();
        if(!bulkProdWrap.prodWrapList.isEmpty()){
            /*********************************************/
              for(ProductWrapper prodWrap : bulkProdWrap.prodWrapList){
                  if(String.isNotBlank(prodWrap.name)){
                      partNoSet.add(prodWrap.name);
                  }
              }
            System.debug('PartNumber: '+partNoSet);
            for(ProductCategoryProduct cateId : [SELECT Id,ProductCategoryId  FROM ProductCategoryProduct where Product.natt_P_N__c IN:partNoSet  and Product.RecordType.Name = 'NAC Products']){
                ProductCategoryId.add(cateId.ProductCategoryId);
            }
            System.debug('ProductCategoryId: '+ProductCategoryId);
            /*********************************************/
            String webstoreId = NAC_B2BUtils.resolveCommunityIdToWebstoreId(communityId);
            for(WebStoreBuyerGroup buyerGroup : [SELECT BuyerGroupId from WebStoreBuyerGroup WHERE WebStoreId =: webstoreId AND BuyerGroupId IN (SELECT BuyerGroupId FROM BuyerGroupMember WHERE BuyerId =: effectiveAccountId)]){
                buyerGroupIdSet.add(buyerGroup.BuyerGroupId);
            }
            ProductCatalog cat = [SELECT Id FROM ProductCatalog WHERE Id IN (SELECT ProductCatalogId FROM WebStoreCatalog WHERE SalesStoreId =: webstoreId)];
            for(pricebookEntry pbe: [SELECT Id, Product2Id FROM PricebookEntry WHERE Pricebook2Id IN (SELECT Pricebook2Id FROM BuyerGroupPricebook WHERE BuyerGroupId IN: buyerGroupIdSet AND IsActive = TRUE)]){
                productWithValidPrice.add(pbe.Product2Id);
            }
            System.debug('productWithValidPrice:'+productWithValidPrice.size());
           // for(ProductCategory pc: [SELECT Id FROM ProductCategory WHERE CatalogId =: cat.Id]){
                //ProductCategoryId.add(pc.Id);
           // }
            //Need to remove check for Orderability for Core
            for(CommerceEntitlementProduct prod : [SELECT ProductId, Product.ProductCode, Product.NATT_Core__c, Product.NAOCAP_Not_Orderable__c, Product.NATT_SignalCode__c, Product.NAOCAP_Not_Orderable_ANA__c, Product.NAOCAP_Signal_Code_ANA__c, Product.NAOCAP_Not_Orderable_CHI__c, Product.NAOCAP_Signal_Code_CHI__c, Product.NAOCAP_Not_Orderable_PAN__c, Product.NAOCAP_Signal_Code_PAN__c, Product.NATT_CoreItem_P_N__c FROM CommerceEntitlementProduct WHERE PolicyId IN (SELECT PolicyId FROM CommerceEntitlementBuyerGroup WHERE BuyerGroupId IN : buyerGroupIdSet) AND ProductId IN (SELECT ProductId FROM ProductCategoryProduct WHERE ProductCategoryId IN : ProductCategoryId) ]){
                if(prod.Product.NATT_CoreItem_P_N__c != null){
                    productIdWithCoreProductCodeMap.put(prod.ProductId, prod.Product.NATT_CoreItem_P_N__c);
                }
                if(prod.Product.ProductCode != null){
                    entitlementProductNameSet.add(formatString(prod.Product.ProductCode));
                    if(prod.Product.NATT_Core__c){
                        coreProductCodeToIdMap.put(formatString(prod.Product.ProductCode), prod.ProductId);
                    }else if(selectedWarehouse =='ATL' && ((!prod.Product.NATT_Core__c && !prod.Product.NAOCAP_Not_Orderable__c) || prod.Product.NATT_SignalCode__c == 'S2')){
                        productName2IdMap.put(formatString(prod.Product.ProductCode), prod.ProductId);
                    }else if(selectedWarehouse =='ANA' && ((!prod.Product.NATT_Core__c && !prod.Product.NAOCAP_Not_Orderable_ANA__c) || prod.Product.NAOCAP_Signal_Code_ANA__c == 'S2')){
                        productName2IdMap.put(formatString(prod.Product.ProductCode), prod.ProductId);
                    }else if(selectedWarehouse =='CHI' && ((!prod.Product.NATT_Core__c && !prod.Product.NAOCAP_Not_Orderable_CHI__c) || prod.Product.NAOCAP_Signal_Code_CHI__c == 'S2')){
                        productName2IdMap.put(formatString(prod.Product.ProductCode), prod.ProductId);
                    }else if(selectedWarehouse =='PAN' && ((!prod.Product.NATT_Core__c && !prod.Product.NAOCAP_Not_Orderable_PAN__c) || prod.Product.NAOCAP_Signal_Code_PAN__c == 'S2')){
                        productName2IdMap.put(formatString(prod.Product.ProductCode), prod.ProductId);
                    } 
                }
            }
            for(ProductWrapper prodWrap : bulkProdWrap.prodWrapList){
                if(String.isNotBlank(prodWrap.name)){
                    //Can not order Core Product directly.It will be added with the main product ONLY.
                    if(coreProductCodeToIdMap.containsKey(formatString(prodWrap.name))){
                        prodWrap.hasError = true;
                        prodWrap.errorMessageList.add('Cannot order Core Product directly.');
                    }else{
                        if(productName2IdMap.containsKey(formatString(prodWrap.name))){
                            prodWrap.id = productName2IdMap.get(formatString(prodWrap.name));
                        }else{
                            prodWrap.hasError = true;
                            if(entitlementProductNameSet.contains(formatString(prodWrap.name))){
                                prodWrap.errorMessageList.add(System.Label.nac_Bulk_Upload_Error_Message_Product_Not_Orderable);
                            }else{
                                prodWrap.errorMessageList.add(System.Label.nac_Bulk_Upload_Error_Message_Wrong_Product_Number);
                            }
                        }
                    }
                }
            }
            for(ProductWrapper prodWrap : bulkProdWrap.prodWrapList){
                if(String.isNotBlank(prodWrap.id)){
                    productIdList.add(prodWrap.id);
                }
            }
            System.debug('CountProductlist>>>>'+productIdList.size());
            Map<String,List<NAC_B2BGetInfoController.prodWrapper>> supersededProductMap = NAC_B2BGetInfoController.getSupersededProduct(productIdList, false, new List<string>{'S2'}, selectedWarehouse);
            for(ProductWrapper prodWrap : bulkProdWrap.prodWrapList){
                if(!prodWrap.hasError){
                    if(supersededProductMap.containsKey(prodWrap.id)){
                        if(!supersededProductMap.get(prodWrap.id).isEmpty()){ 
                            if(supersededProductMap.get(prodWrap.id)[0].id != prodWrap.id){
                                if(productName2IdMap.containsKey(formatString(supersededProductMap.get(prodWrap.id)[0].productCode))){
                                    prodWrap.oldProductName = prodWrap.name;
                                    prodWrap.isSuperseded = true;
                                    prodWrap.alternateItemId = supersededProductMap.get(prodWrap.id)[0].id;	
                                    prodWrap.supersededPrName = supersededProductMap.get(prodWrap.id)[0].productCode;
                                    prodWrap.supersededText = 'Product ' + prodWrap.oldProductName + 'superseded by ' + prodWrap.supersededPrName;
                                    if(supersededProductMap.get(prodWrap.id)[0].notOrderable){
                                        prodWrap.hasError = true;
                                        prodWrap.errorMessageList.add('Part is not orderable');
                                    }else{
                                        if(productIdWithCoreProductCodeMap.containsKey(prodWrap.alternateItemId) && coreProductCodeToIdMap.containsKey(formatString(productIdWithCoreProductCodeMap.get(prodWrap.alternateItemId)))){
                                            prodWrap.isCoreItem = true;
                                            prodWrap.corePrQuantity = prodWrap.quantity;
                                            prodWrap.corePrName = productIdWithCoreProductCodeMap.get(prodWrap.alternateItemId);
                                            prodWrap.corePrid = coreProductCodeToIdMap.get(formatString(productIdWithCoreProductCodeMap.get(prodWrap.alternateItemId)));
                                        }
                                    }
                                }else{
                                    prodWrap.hasError = true;
                                    prodWrap.errorMessageList.add('Part is Superseded but not able to find any Active Superseded product');
                                }
                            }else{
                                if(productIdWithCoreProductCodeMap.containsKey(prodWrap.id) && coreProductCodeToIdMap.containsKey(formatString(productIdWithCoreProductCodeMap.get(prodWrap.id)))){
                                    prodWrap.isCoreItem = true;
                                    prodWrap.corePrQuantity = prodWrap.quantity;
                                    prodWrap.corePrName = productIdWithCoreProductCodeMap.get(prodWrap.id);
                                    prodWrap.corePrid = coreProductCodeToIdMap.get(formatString(productIdWithCoreProductCodeMap.get(prodWrap.id)));
                                }
                            }
                        }else{
                            prodWrap.hasError = true;
                            prodWrap.errorMessageList.add('Part is Superseded but not able to find any Active Superseded product');
                        }
                    }else{
                        prodWrap.hasError = true;
                        prodWrap.errorMessageList.add('Part is Superseded but not able to find any Active Superseded product');
                    }
                     
                    //CXREF-4054--->
                    if(!prodWrap.hasError && String.isNotBlank(prodWrap.name) && productName2IdMap.containsKey(formatString(prodWrap.name)) && prodWrap.isSuperseded ? !productWithValidPrice.contains(prodWrap.alternateItemId) : !productWithValidPrice.contains(prodWrap.id)){
                        prodWrap.hasError = true;
                        prodWrap.errorMessageList.add(System.Label.nac_Bulk_Upload_Error_Message_Price_Unavailable);
                    }
                }
            }
        }
        return bulkProdWrap;
    }
    
    public static Boolean isNumeric(String s){
        Boolean ReturnValue;
        try{
            Decimal.valueOf(s);
            ReturnValue = TRUE; 
        } catch (Exception e) {
            ReturnValue = FALSE;
        }
        return ReturnValue;
    }
    
    public static String formatString (String s){
        String upperCaseString = s.toUpperCase();
        return upperCaseString.trim();
    }
    
    @AuraEnabled
    public static void deleteContentDocumentFiles(String contentDocumentId){
        if(contentDocumentId != null){
            List<ContentDocument> deleteContentDocumentList = [SELECT Id from ContentDocument WHERE id = : contentDocumentId];
            if(!deleteContentDocumentList.isEmpty()){
                delete deleteContentDocumentList;
            }
        }
    }
    
    @AuraEnabled 
    public static cartWrapper addItemToCart(String bulkProdWrapString, String communityId, String effectiveAccountId){ 
        cartWrapper cartWrap = new cartWrapper();
        bulkUploadProductWrapper bulkProdWrap = (bulkUploadProductWrapper)JSON.deSerialize(bulkProdWrapString, bulkUploadProductWrapper.class);
        String webstoreId = NAC_B2BUtils.resolveCommunityIdToWebstoreId(communityId);
        ConnectApi.CartSummary cartSummary = ConnectApi.CommerceCart.getCartSummary(webstoreId, effectiveAccountId, 'active');
        cartWrap.path += cartSummary.cartId; 
        if(cartSummary.status != ConnectApi.CartStatus.PROCESSING && cartSummary.status != ConnectApi.CartStatus.CHECKOUT){
            List<ConnectApi.BatchInput> cartItemsMainProduct = new List<ConnectApi.BatchInput>();
            List<ConnectApi.BatchInput> cartItemsCoreProduct = new List<ConnectApi.BatchInput>();
            for(ProductWrapper prodWrap : bulkProdWrap.prodWrapList){
                if(!prodWrap.hasError){
                    /** Adding Main Product / Alternate Product */
                    ConnectApi.CartItemInput cartItem = new ConnectApi.CartItemInput();
                    cartItem.quantity = prodWrap.quantity;
                    if(prodWrap.isSuperseded){
                        cartItem.productId = prodWrap.alternateItemId;
                    }else{
                        cartItem.productId = prodWrap.id;
                    }
                    cartItem.type = ConnectApi.CartItemType.PRODUCT;
                    cartItemsMainProduct.add(new ConnectApi.BatchInput(cartItem));
                     /*Adding the Core product*/
                    if(prodWrap.isCoreItem){
                        ConnectApi.CartItemInput cartItemCore = new ConnectApi.CartItemInput();
                        cartItemCore.productId = prodWrap.corePrid;
                        cartItemCore.quantity = prodWrap.corePrQuantity;
                        cartItemCore.type =ConnectApi.CartItemType.PRODUCT;
                        cartItemsCoreProduct.add(new ConnectApi.BatchInput(cartItemCore));
                    }
                }
            }
           if(cartItemsMainProduct.size() <= 100){
                 ConnectApi.BatchResult[] batchResultsMain = ConnectApi.CommerceCart.addItemsToCart(webstoreId, effectiveAccountId, 'active', cartItemsMainProduct);
            }
            if(cartItemsCoreProduct.size() <= 100){                
                ConnectApi.BatchResult[] batchResultsCore = ConnectApi.CommerceCart.addItemsToCart(webstoreId, effectiveAccountId, 'active', cartItemsCoreProduct);
                 
           }
            else{
                cartWrap.hasError = true;
                cartWrap.errorMessage = 'Looks like there are more than 100 items to process. Kindly try again with lesser items in the uploaded CSV';
            }
           
        }else{
            cartWrap.hasError = true;
            cartWrap.errorMessage = 'The Cart is in ' + cartSummary.status +'process.';
        }
        return cartWrap;
    }
    
    public class bulkUploadProductWrapper {
        @AuraEnabled public List<ProductWrapper> prodWrapList;
        @AuraEnabled public Boolean hasError;
        @AuraEnabled public String errorMessage;
        public bulkUploadProductWrapper(){
            prodWrapList = new List<ProductWrapper>();
            hasError = false;
            errorMessage = '';
        }
    }
    
    public class ProductWrapper {
        @AuraEnabled public String name;
        @AuraEnabled public String id;
        @AuraEnabled public String quantity;
        @AuraEnabled public Boolean hasError;
        @AuraEnabled public Integer index;
        @AuraEnabled public Boolean isSuperseded;
        @AuraEnabled public String supersededPrName;
        @AuraEnabled public String supersededText;
        @AuraEnabled public String oldProductName;
        @AuraEnabled public String alternateItemId;
        @AuraEnabled public Boolean isCoreItem;
        @AuraEnabled public Boolean notOderable;
        @AuraEnabled public String corePrName;
        @AuraEnabled public String corePrid;
        @AuraEnabled public String corePrQuantity;
        @AuraEnabled public List<String> errorMessageList;
        public ProductWrapper(){
            name = '';
            id = '';
            quantity = '';
            alternateItemId = '';
            oldProductName = '';
            hasError = false;
            isSuperseded = false;
            supersededPrName = '';
            supersededText = '';
            isCoreItem = false;
            notOderable = false;
            corePrName = '';
            corePrid = '';
            corePrQuantity = '';
            errorMessageList = new List<String>();
        }
    }
    
    public class cartWrapper {
        @AuraEnabled public String path;
        @AuraEnabled public Boolean hasError;
        @AuraEnabled public String errorMessage;
        public cartWrapper(){
            path = '/cart/';
            hasError = false;
            errorMessage = '';
        }
    }
}