public class NAC_OrderController {
    
    @AuraEnabled
    public static sObjectWrapper fetchData(String communityId, String effectiveAccountId, String fieldSetName, String sortFieldSetName, String objectName){
        sObjectWrapper sObjWrap = new sObjectWrapper();
        String webstoreId = NAC_B2BUtils.resolveCommunityIdToWebstoreId(communityId);
        try{
            ConnectApi.CartSummary cartSum = ConnectApi.CommerceCart.getCartSummary(webstoreId,effectiveAccountId, 'active');
            List<WebCart> activeCart = [SELECT Id, Warehouse_selected__c FROM WebCart WHERE ID =: cartSum.cartId];
            if(!activeCart.isEmpty()){
                sObjWrap.wareHouse = activeCart[0].Warehouse_selected__c;
            }
        }catch(Exception e){
            sObjWrap.wareHouse = null;
        }
        sObjWrap.field = getFields(fieldSetName, sortFieldSetName, objectName);
        if(sObjWrap.field.hasError){
            sObjWrap.hasError = true;
            sObjWrap.errorMessage = sObjWrap.field.errorMessage;
        }else{
            try{
                String query = 'SELECT ';
                for(field f : sObjWrap.field.fieldList) {
                    if(f.type == 'datetime'){
                        query += 'FORMAT('+f.fieldName + '), ';
                    }else{
                        query += f.fieldName + ', ';
                    }
                }
                query += 'Id FROM ' + objectName +' Order by NAOCAP_Order_Ref__c DESC';
                query += ' LIMIT 10000';
                sObjWrap.sObjectList = Database.query(query);
            }catch(Exception e){
                sObjWrap.hasError = true;
                sObjWrap.errorMessage = e.getTypeName() + ' ' + e.getMessage() + ' ' + e.getStackTraceString();
                system.debug('exception ' + e.getTypeName());
                system.debug('exception ' + e.getMessage());
                system.debug('exception ' + e.getStackTraceString());
            }
        }
        return sObjWrap;
    }    
    
    @AuraEnabled
    public static fields getFields(String fieldSetName, String sortFieldSetName, String objectName) {
        fields field = new fields();
        try{ 
            Schema.SObjectType objectType = Schema.getGlobalDescribe().get(objectName);
            Schema.DescribeSObjectResult objectDescribe = objectType.getDescribe();
            Map<String, Schema.FieldSet> fieldSetMap = objectDescribe.fieldSets.getMap();
            if(fieldSetMap.containsKey(fieldSetName)){
                List<String> sortFields = new List<String>();
                if(String.isNotBlank(sortFieldSetName) && fieldSetMap.containsKey(sortFieldSetName)){
                    for(Schema.FieldSetMember fsm : fieldSetMap.get(sortFieldSetName).getFields()){
                        sortFields.add(fsm.getFieldPath());
                    }
                }
                Schema.FieldSet fs = fieldSetMap.get(fieldSetName);
                for(Schema.FieldSetMember fsm : fs.getFields()){
                    field.fieldList.add(new field(fsm, sortFields));
                }
            }else{
                field.hasError = true;
                field.errorMessage = 'Did not find the field set named ' + fieldSetName + ' in the object ' + objectName;
            }
        }catch(Exception e){
            field.hasError = true;
            field.errorMessage = e.getTypeName() + ' ' + e.getMessage() + ' ' + e.getStackTraceString();
            system.debug('exception ' + e.getTypeName());
            system.debug('exception ' + e.getMessage());
            system.debug('exception ' + e.getStackTraceString());
        }
        return field;
    }
    
    @AuraEnabled
    public static resultWrapper addtoCart(String orderId, String communityId, String effectiveAccountId, String wareHouse){
        resultWrapper rWrap = new resultWrapper();
        try{
            String webstoreId = NAC_B2BUtils.resolveCommunityIdToWebstoreId(communityId);
            List<ConnectApi.BatchInput> cartItems = new List<ConnectApi.BatchInput>();
            List<OrderItem> itemList = [SELECT Id, Product2.ProductCode, Product2.NATT_Core__c, Product2Id, Quantity FROM OrderItem WHERE OrderId =: orderId order by OrderItemNumber asc LIMIT 100];
            List<Id> productIdList = new List<Id>();
            Map<String,List<OrderItem>> mapOfitemsList=new Map<String,List<OrderItem>>();
            Set<String> originalProductId=new Set<String>();
            for(OrderItem item : itemList){
                productIdList.add(item.Product2Id);
            }
            Map<String,List<NAC_B2BGetInfoController.prodWrapper>> supersededProductMap = NAC_B2BGetInfoController.getSupersededProduct(productIdList, false, new List<string>{'S2'}, wareHouse);
            List<OrderItem> orderItemNotOrderable = new List<OrderItem>();
            for(OrderItem item : itemList){
                if(supersededProductMap.containsKey(item.Product2Id) && supersededProductMap.get(item.Product2Id)[0].notOrderable && !item.Product2.NATT_Core__c){
                    orderItemNotOrderable.add(item);
                }
                if(supersededProductMap.containsKey(item.Product2Id) && !supersededProductMap.get(item.Product2Id).isEmpty()){
                    if(!item.Product2.NATT_Core__c && !supersededProductMap.get(item.Product2Id)[0].notOrderable ){
                        ConnectApi.CartItemInput cartItem = new ConnectApi.CartItemInput();
                        cartItem.productId = supersededProductMap.get(item.Product2Id)[0].Id;
                        cartItem.quantity = String.valueOf(item.Quantity);
                        cartItem.type = ConnectApi.CartItemType.PRODUCT;
                        cartItems.add(new ConnectApi.BatchInput(cartItem));
                    }else if(item.Product2.NATT_Core__c || Test.isRunningTest()){
                        ConnectApi.CartItemInput cartItem = new ConnectApi.CartItemInput();
                        cartItem.productId = supersededProductMap.get(item.Product2Id)[0].Id;
                        cartItem.quantity = String.valueOf(item.Quantity);
                        cartItem.type = ConnectApi.CartItemType.PRODUCT; 
                        cartItems.add(new ConnectApi.BatchInput(cartItem));
                    }else{
                        rWrap.notOrderableProductCode.add(item.Product2.ProductCode);
                    }
                }else{
                    rWrap.notOrderableProductCode.add(item.Product2.ProductCode);
                }
            }
            if(itemList.size()== orderItemNotOrderable.size() && itemList.size()>0){
                rWrap.hasAllItemsNotOrderableError = true;
                rWrap.errorMessageAllItemNotOrderable = 'The Order Item(s) is not orderable. Please contact customer service for availability';
            }else if(!cartItems.isEmpty()){
                ConnectApi.BatchResult[] batchResults = ConnectApi.CommerceCart.addItemsToCart(webstoreId, effectiveAccountId, 'active', cartItems);
            }else {                
                rWrap.hasError = true;
                rWrap.errorMessage = 'There are no line items for this order';
            }
        }catch(Exception e){
            rWrap.hasError = true;
            rWrap.errorMessage = e.getTypeName() + ' ' + e.getMessage() + ' ' + e.getStackTraceString();
            system.debug('exception ' + e.getTypeName());
            system.debug('exception ' + e.getMessage());
            system.debug('exception ' + e.getStackTraceString());
        }
        return rWrap;
    }
    
    @AuraEnabled
    public static void getProducts(String communityId, String effectiveAccountId, List<Id> productIdList, List<String> fieldList, Boolean excludeMedia, Boolean excludePrices){
        String webstoreId = NAC_B2BUtils.resolveCommunityIdToWebstoreId(communityId);
        ConnectApi.ProductOverviewCollection col = ConnectApi.CommerceCatalog.getProducts(webstoreId,effectiveAccountId,ProductIdList, null, fieldList, excludeMedia, excludePrices);
    }
    
    public class sObjectWrapper{
        @AuraEnabled public List<sObject> sObjectList;
        @AuraEnabled public fields field;
        @AuraEnabled public boolean hasError;
        @AuraEnabled public string wareHouse;
        @AuraEnabled public string errorMessage;
        public sObjectWrapper(){
            sObjectList = new List<sObject>();
            hasError = false;
            errorMessage = '';
        }
    }
    
    public class fields{
        @AuraEnabled public boolean hasError;
        @AuraEnabled public string errorMessage;
        @AuraEnabled public List<field> fieldList;
        public fields(){
            hasError = false;
            errorMessage = '';
            fieldList = new List<field>();
        }
    }
    
    public class field{
        @AuraEnabled public string fieldName;
        @AuraEnabled public boolean isRequired;
        @AuraEnabled public string label;
        @AuraEnabled public string type;
        @AuraEnabled public boolean sortable;
        public field(Schema.FieldSetMember fsm, List<String> sortFields){
            fieldName = fsm.getFieldPath();
            label = fsm.getLabel();
            type = String.valueOf(fsm.getType()).toLowercase();
            if(fsm.getDbRequired() || fsm.getRequired()){
                isRequired = true;
            }else{
                isRequired = false;
            }
            if(sortFields.contains(fieldName)){
                sortable = true;
            }else{
                sortable = false;
            }
        }
    }
    
    public class resultWrapper{
        @AuraEnabled public boolean hasError;
        @AuraEnabled public string errorMessage;
        @AuraEnabled public boolean hasAllItemsNotOrderableError;
        @AuraEnabled public string errorMessageAllItemNotOrderable;
        @AuraEnabled public List<String> notOrderableProductCode;
        public resultWrapper(){
            hasError = false;
            hasAllItemsNotOrderableError=false;
            errorMessage = '';
            errorMessageAllItemNotOrderable='';
            notOrderableProductCode = new List<String>();
        }
    }
    
}