public without sharing class NAC_CheckoutController {

    @AuraEnabled
    public static Order fetchOrderData(Id orderId){
        return [SELECT id, OrderNumber,NAOCAP_Rush_Order_Charge__c, BillingStreet, BillingCity, BillingState, BillingPostalCode, BillingCountry, TotalAmount,
                ShippingStreet,NATT_Requested_Ship_Date__c , ShippingCity, ShippingState, ShippingCountry,ShippingPostalCode,NATT_Purchase_Order__c,NAOCAP_Order_Ref__c,
                OrderedDate, toLabel(NAC_Order_Type__c),NAC_Billing_Delivery_Term__c , toLabel(NAC_Shipping_Method__c) FROM Order WHERE Id =: orderId];
    }
    
    @AuraEnabled
    public static checkOutWrapper getCheckOutDetails(String userId, String communityId, String resourceName,String effectiveAccountId){
        checkOutWrapper checkOutWrap = new checkOutWrapper();
        boolean isDomestic = true;
        Decimal totalCartAmountNonCore = 0.0;
        String webstoreId = NAC_B2BUtils.resolveCommunityIdToWebstoreId(communityId);
        List<String> externalCustomerGroup = Label.NAOCAP_External_Customer_Group.split(',');
        List<String> productIdList = new List<String>(), currCartItemIdList = new List<String>();
        User userDetail = [SELECT contactid, contact.AccountId FROM User WHERE Id =: userId LIMIT 1];
        checkOutWrap.userDetail = [SELECT id, FirstName, LastName, Name, Phone, Email FROM Contact WHERE id =: userDetail.contactid LIMIT 1];
        Map<String,String> orderTypePickListValuesList = new Map<String,String>(), shippingMethodPickListValuesList = new Map<String,String>(), billingDeliveryTermPickListValuesList = new Map<String,String>();
        Map<String,picklistValue> orderTypeOptionsMap = new Map<String,picklistValue>(), shippingMethodOptionsMap = new Map<String,picklistValue>(), billingDeliveryOptionsMap = new Map<String,picklistValue>();
        WebStoreBuyerGroup storeBuyerGroup = [SELECT BuyerGroupId, BuyerGroup.NAC_Type__c from WebStoreBuyerGroup WHERE WebStoreId =: webstoreId AND BuyerGroupId IN (SELECT BuyerGroupId FROM BuyerGroupMember WHERE BuyerId =: userDetail.contact.AccountId) LIMIT 1];
        String customerType = storeBuyerGroup.BuyerGroup.NAC_Type__c, wareHouse;
        checkOutWrap.customerType = storeBuyerGroup.BuyerGroup.NAC_Type__c;
        if(checkOutWrap.customerType == 'V1H'){
            checkOutWrap.countryStatePicklistValue = NAC_UserSignUp.fetchCountryandStates();
        }
        List<NAOCAP_Store_Configuration__mdt> checkoutConfigList= [SELECT MasterLabel,NAOCAP_Enable_Custom_Shipping_Address__c FROM NAOCAP_Store_Configuration__mdt Where MasterLabel=:storeBuyerGroup.BuyerGroup.NAC_Type__c AND NAOCAP_Enable_Custom_Shipping_Address__c=true];
        if(checkoutConfigList.size()>0){
            checkOutWrap.isCustomAddEnabled = true;
        }else{
            checkOutWrap.isCustomAddEnabled = false;
        }
        ConnectApi.CartSummary cartSumm = ConnectApi.CommerceCart.getCartSummary(webstoreId, effectiveAccountId, 'active');
        WebCart cartDetails = [SELECT Warehouse_selected__c, (SELECT TotalPrice FROM CartItems WHERE Product2.NATT_Core__c = false) FROM WebCart WHERE ID =: cartSumm.cartId];
        wareHouse = cartDetails.Warehouse_selected__c;
        for(cartItem items : cartDetails.CartItems){
            totalCartAmountNonCore += items.TotalPrice;
        }
        checkOutWrap.selectedBranchPlantWarehouse = [SELECT Warehouse_Name__c from NAC_WareHouseData__mdt where API_VALUE__c =: wareHouse].Warehouse_Name__c;
        checkOutWrap.totalNonCoreCartAmount = totalCartAmountNonCore;
        String accountId = (effectiveAccountId != null && effectiveAccountId != '000000000000000') ? effectiveAccountId : userDetail.contact.AccountId;
        checkOutWrap.addressList = [SELECT Id, Street, City, State, PostalCode, Country, IsDefault, NATT_Address__c, NATT_Address__r.Id, AddressType FROM ContactPointAddress WHERE Recordtype.Name='NAC' AND ParentId =: accountId AND Status__c = 'Approved'];
        String query = 'SELECT Id, Customer_Type__c, NAC_Order_Type__c, Order_Type_Sort_Order__c, NAC_Shipping_Method__c, NAC_Billing_Delivery_Term__c, Shipping_Method_Sort_Order__c FROM NAC_Customer_Type_Option__mdt WHERE Customer_Type__c =: customerType AND ';
        query += wareHouse == 'ANA' ? 'Warehouse_Anaheim__c = TRUE' : wareHouse == 'CHI' ? 'Warehouse_Chile__c = TRUE' : wareHouse == 'PAN' ? 'Warehouse_Panama__c = TRUE' : 'Warehouse_Atlanta__c = TRUE';
        query += ' ORDER BY Order_Type_Sort_Order__c, NAC_Order_Type__c, Shipping_Method_Sort_Order__c';
        List<NAC_Customer_Type_Option__mdt> options = Database.query(query);
        checkOutWrap.downloadLink = NAC_BulkUploadController.GetResourceURL(resourceName);
        for(Schema.PicklistEntry orderType : Order.NAC_Order_Type__c.getDescribe().getPicklistValues()){
            orderTypePickListValuesList.put(orderType.getValue(),orderType.getLabel());
        }
        for(Schema.PicklistEntry shippingMethod : Order.NAC_Shipping_Method__c.getDescribe().getPicklistValues()){
            shippingMethodPickListValuesList.put(shippingMethod.getValue(),shippingMethod.getLabel());
        }
        for(Schema.PicklistEntry billingDeliveryTerm : Order.NAC_Billing_Delivery_Term__c.getDescribe().getPicklistValues()){
            billingDeliveryTermPickListValuesList.put(billingDeliveryTerm.getValue(),billingDeliveryTerm.getLabel());
        }
        checkOutWrap.orderTypeData = new picklistValueList();
        for(NAC_Customer_Type_Option__mdt option : options){
            if(!orderTypeOptionsMap.containsKey(option.NAC_Order_Type__c) && orderTypePickListValuesList.containsKey(option.NAC_Order_Type__c)){
                picklistValue picklist = new picklistValue();
                picklist.label = orderTypePickListValuesList.get(option.NAC_Order_Type__c);
                picklist.value = option.NAC_Order_Type__c;
                if(checkOutWrap.orderTypeData.defaultValue == null){
                    checkOutWrap.orderTypeData.defaultValue = picklist;
                }
                orderTypeOptionsMap.put(option.NAC_Order_Type__c, picklist);
            }
        }
        checkOutWrap.orderTypeData.values = orderTypeOptionsMap.values();
        if(!checkOutWrap.orderTypeData.values.isEmpty()){
            checkOutWrap.shippingMethodData = new picklistValueList();
            checkOutWrap.deliveryTermData = new picklistValueList();
            for(NAC_Customer_Type_Option__mdt option : options){
                for(picklistValue orderTypeValues :checkOutWrap.orderTypeData.values){
                    checkOutWrap.shippingMethodData.controllerValues.put(orderTypeValues.value, checkOutWrap.orderTypeData.values.indexOf(orderTypeValues));
                    checkOutWrap.deliveryTermData.parentControllerValues.put(orderTypeValues.value, checkOutWrap.orderTypeData.values.indexOf(orderTypeValues));
                }
            }
            for(NAC_Customer_Type_Option__mdt option : options){
                if(shippingMethodPickListValuesList.containsKey(option.NAC_Shipping_Method__c)){
                    if(!shippingMethodOptionsMap.containsKey(option.NAC_Shipping_Method__c)){
                        picklistValue picklist = new picklistValue();
                        picklist.label = shippingMethodPickListValuesList.get(option.NAC_Shipping_Method__c);
                        picklist.value = option.NAC_Shipping_Method__c;
                        picklist.validFor.add(checkOutWrap.shippingMethodData.controllerValues.get(option.NAC_Order_Type__c));
                        if(checkOutWrap.shippingMethodData.defaultValue == null){
                            checkOutWrap.shippingMethodData.defaultValue = picklist;
                        }
                        shippingMethodOptionsMap.put(option.NAC_Shipping_Method__c, picklist);
                    }else{
                        picklistValue picklist = shippingMethodOptionsMap.get(option.NAC_Shipping_Method__c);
                        if(!picklist.validFor.contains(checkOutWrap.shippingMethodData.controllerValues.get(option.NAC_Order_Type__c))){
                            picklist.validFor.add(checkOutWrap.shippingMethodData.controllerValues.get(option.NAC_Order_Type__c));
                        }
                    }
                }
            }
            checkOutWrap.shippingMethodData.values = shippingMethodOptionsMap.values();
            if(!checkOutWrap.shippingMethodData.values.isEmpty()){
                for(NAC_Customer_Type_Option__mdt option : options){
                    for(picklistValue shippingMethodValues :checkOutWrap.shippingMethodData.values){
                        checkOutWrap.deliveryTermData.controllerValues.put(shippingMethodValues.value, checkOutWrap.shippingMethodData.values.indexOf(shippingMethodValues));
                    }
                }
                for(NAC_Customer_Type_Option__mdt option : options){
                    if(billingDeliveryTermPickListValuesList.containsKey(option.NAC_Billing_Delivery_Term__c) ){
                        if(!billingDeliveryOptionsMap.containsKey(option.NAC_Billing_Delivery_Term__c)){
                            picklistValue picklist = new picklistValue();
                            picklist.label = billingDeliveryTermPickListValuesList.get(option.NAC_Billing_Delivery_Term__c);
                            picklist.value = option.NAC_Billing_Delivery_Term__c;
                            picklist.validFor.add(checkOutWrap.deliveryTermData.controllerValues.get(option.NAC_Shipping_Method__c));
                            picklist.childrenValidFor.add(checkOutWrap.deliveryTermData.parentControllerValues.get(option.NAC_Order_Type__c));
                            if(checkOutWrap.deliveryTermData.defaultValue == null){
                                checkOutWrap.deliveryTermData.defaultValue = picklist;
                            }
                            billingDeliveryOptionsMap.put(option.NAC_Billing_Delivery_Term__c, picklist);
                        }else{
                            picklistValue picklist = billingDeliveryOptionsMap.get(option.NAC_Billing_Delivery_Term__c);
                            if(!picklist.validFor.contains(checkOutWrap.deliveryTermData.controllerValues.get(option.NAC_Shipping_Method__c))){
                                picklist.validFor.add(checkOutWrap.deliveryTermData.controllerValues.get(option.NAC_Shipping_Method__c));
                            }
                            if(!picklist.childrenValidFor.contains(checkOutWrap.deliveryTermData.parentControllerValues.get(option.NAC_Order_Type__c))){
                                picklist.childrenValidFor.add(checkOutWrap.deliveryTermData.parentControllerValues.get(option.NAC_Order_Type__c));
                            }
                        }                    
                    }
                }
            }
            checkOutWrap.deliveryTermData.values = billingDeliveryOptionsMap.values();
        }
        return checkOutWrap;
    }
    
    @AuraEnabled
    public static orderResultWrapper createOrders(String cartId, Map<Object, Object> orderInformation){
        Savepoint sp;
        sp = Database.setSavepoint();
        orderResultWrapper odrWrap = new orderResultWrapper();
        try{
            Id userId = UserInfo.getUserId();
            List<WebCart> cartDetailList = new List<WebCart>();
            List<String> webCartFieldList = new List<String>();
            List<String> webCartItemFieldList = new List<String>();
            Map <String, Schema.SObjectField> orderFieldMap = Schema.SObjectType.Order.fields.getMap();
            Map <String, Schema.SObjectField> orderItemFieldMap = Schema.SObjectType.OrderItem.fields.getMap();
            Map <String, Schema.SObjectField> webCartFieldMap = Schema.SObjectType.WebCart.fields.getMap();
            Map <String, Schema.SObjectField> webCartItemFieldMap = Schema.SObjectType.CartItem.fields.getMap();
            Map<String,String> fieldtoObjectMap = new Map<String,String>{
                'ShippingStreet'=>'shippingStreetValue',
                    'ShippingCity'=>'shippingCityValue',
                    'ShippingState'=>'shippingStateValue',
                    'ShippingCountry'=>'shippingCountryValue',
                    'ShippingPostalCode'=>'shippingPostalCodeValue',
                    'NATT_Freight_Account_Number__c'=>'freightAccountNumber',
                    'BillingStreet'=>'billingStreetValue',
                    'BillingCity'=>'billingCityValue',
                    'BillingState'=>'billingStateValue',
                    'BillingCountry'=>'billingCountryValue',
                    'BillingPostalCode'=>'billingPostalCodeValue',
                    'NATT_Purchase_Order__c'=>'purchaseOrderNo',
                    'NATT_Shipping_Address__c'=>'shippingNATTAddressId',
                    'NAOCAP_Ship_To_Mailing_Name__c'=>'shippingMailingName',
                    'NAC_Account_Number__c' => 'accountNumber'
                    };
                        for (String webCartField : webCartFieldMap.keySet()) {
                            webCartFieldList.add(webCartField);
                        }
            String webCartFields = String.join(webCartFieldList,',');
            for (String webCartItemField : webCartItemFieldMap.keySet()) {
                webCartItemFieldList.add(webCartItemField);
            }
            String webCartItemFields = String.join(webCartItemFieldList,',');
            cartDetailList = Database.query('SELECT ' + webCartFields + ',(SELECT ' + webCartItemFields + ' FROM CartItems ORDER BY NAOCAP_Cart_Item_Number__c ASC) FROM WebCart WHERE Id = :cartId');
            if(!cartDetailList.isEmpty()){
                WebCart cartDetails = cartDetailList[0];
                if(!cartDetails.CartItems.isEmpty()){
                    List<NAC_Object_Mapping__mdt> orderMappingList = [SELECT Web_Cart__c, Order__c, Order_Summary__c, Is_Line_Item_Field__c FROM NAC_Object_Mapping__mdt WHERE Order__c != null AND Web_Cart__c != null];
                    Order ord = new Order();
                    for(NAC_Object_Mapping__mdt fieldMap : orderMappingList){
                        if(!fieldMap.Is_Line_Item_Field__c && webCartFieldMap.containsKey(fieldMap.Web_Cart__c)){
                            if(orderFieldMap.containsKey(fieldMap.Order__c)){
                                ord.put(fieldMap.Order__c,cartDetails.get(fieldMap.Web_Cart__c));
                            }
                        }
                    }
                    List<NAC_WareHouseData__mdt> warehouse = [Select Id,Warehouse_Number__c from NAC_WareHouseData__mdt Where API_VALUE__c =:cartDetails.Warehouse_selected__c];
                    if(warehouse.size()>0 && (warehouse[0].Warehouse_Number__c !=null || warehouse[0].Warehouse_Number__c !='' )){
                        ord.put('NAC_Order_Warehouse_Number__c',warehouse[0].Warehouse_Number__c);
                    }
                    for(String field : fieldtoObjectMap.keySet()){
                        if(orderFieldMap.containsKey(field)){                            
                                ord.put(field,(String)orderInformation.get(fieldtoObjectMap.get(field)));                       
                        }
                    }
                    if(orderInformation.containsKey('requestedDate') && orderInformation.get('requestedDate') != null && String.isNotBlank((String)orderInformation.get('requestedDate'))){
                        ord.NATT_Requested_Ship_Date__c = date.valueOf((String)orderInformation.get('requestedDate'));
                         system.debug('ord.NATT_Requested_Ship_Date__c=>>'+ord.NATT_Requested_Ship_Date__c);
                    }
                    if(orderInformation.containsKey('totalRushFee') && orderInformation.get('totalRushFee') != null){
                        ord.NAOCAP_Rush_Order_Charge__c = (Decimal)orderInformation.get('totalRushFee');
                    }
                    if(orderInformation.containsKey('shipComplete')){
                        ord.NAOCAP_Ship_Complete__c = (Boolean)orderInformation.get('shipComplete');
                    }
                    if(orderInformation.containsKey('orderType')){
                        Map<Object, Object> orderTypeMap = (Map<Object, Object>)orderInformation.get('orderType');
                        if(orderTypeMap.containsKey('value')){ 
                            ord.NAC_Order_Type__c = (String)orderTypeMap.get('value');
                            ord.NATT_JdeOrderType__c = (String)orderTypeMap.get('value');
                        }
                    }
                    if(orderInformation.containsKey('shippingMethod')){
                        Map<Object, Object> shippingMethodMap = (Map<Object, Object>)orderInformation.get('shippingMethod');
                        if(shippingMethodMap.containsKey('value')){
                            ord.NAC_Shipping_Method__c = (String)shippingMethodMap.get('value');
                            ord.NATT_Shipment_Method__c = (String)shippingMethodMap.get('value');
                        }
                    }
                    if(orderInformation.containsKey('deliveryTerm')){
                        Map<Object, Object> deliveryTermMap = (Map<Object, Object>)orderInformation.get('deliveryTerm');
                        if(deliveryTermMap.containsKey('value')){
                            ord.NAC_Billing_Delivery_Term__c = (String)deliveryTermMap.get('value');
                            ord.NATT_Shipment_Terms__c =(String)deliveryTermMap.get('value');
                        }
                    }
                    ord.Status = 'Draft';
                    ord.NATT_Order_Status__c = 'Pending Confirmation';
                    //ord.OrderedDate =  System.today();
                    ord.OrderedDate =  System.Now();
                    ord.EffectiveDate = System.today();
                    ord.RecordTypeId = Schema.SObjectType.Order.getRecordTypeInfosByDeveloperName().get('NAC').getRecordTypeId();
                    insert ord;
                    List<OrderItem> orderItemList = new List<OrderItem>();
                    for(CartItem webCartItemDetail : cartDetails.CartItems){
                        OrderItem ordItem = new OrderItem();
                        OrderItemSummary ordItemSum = new OrderItemSummary();
                        for(NAC_Object_Mapping__mdt fieldMap : orderMappingList){
                            if(fieldMap.Is_Line_Item_Field__c && webCartItemFieldMap.containsKey(fieldMap.Web_Cart__c)){
                                if(orderItemFieldMap.containsKey(fieldMap.Order__c)){
                                    ordItem.put(fieldMap.Order__c,webCartItemDetail.get(fieldMap.Web_Cart__c));
                                }
                            }
                        }
                        ordItem.Type = 'Order Product';
                        ordItem.OrderId = ord.Id;
                        orderItemList.add(ordItem);
                    }
                    insert orderItemList;
                    cartDetails.Status = 'Closed';
                    update cartDetails;
                    odrWrap.orderId = ord.Id;
                }else{
                    odrWrap.hasError = true;
                    odrWrap.errorMessage = 'Looks like this cart does not have any items. Please contact your system adminstrator for more details';
                }
            }else{
                odrWrap.hasError = true;
                odrWrap.errorMessage = 'The cartId is invalid. Please contact your system adminstrator for more details';
            }
        }catch(Exception e){
            Database.rollback(sp);
            odrWrap.hasError = true;
            odrWrap.errorMessage = e.getTypeName() + ' ' + e.getMessage() + ' ' + e.getStackTraceString();
            system.debug('exception ' + e.getTypeName());
            system.debug('exception ' + e.getMessage());
            system.debug('exception ' + e.getStackTraceString());
        }
        return odrWrap;
    }

    @AuraEnabled(cacheable=true)
    public static decimal getRushOrderCharge(String accountId){
        try {
            if(String.isNotBlank(accountId)){
                List<BuyerGroupMember> bgmList = new List<BuyerGroupMember>([SELECT Id,BuyerGroup.Name,BuyerGroup.NAC_Type__c FROM BuyerGroupMember WHERE BuyerId=:accountId]);
                Map<String,Decimal> bgMap = new Map<String,Decimal>();
                for(NAC_Rush_Free_Percentage__mdt rf : [SELECT MasterLabel,Rush_Fee_Percentage__c FROM NAC_Rush_Free_Percentage__mdt]){
                    bgMap.put(rf.MasterLabel,(rf.Rush_Fee_Percentage__c/100));
                }
                for(BuyerGroupMember bgm : bgmList){
                    if(bgMap.containsKey(bgm.BuyerGroup.NAC_Type__c)){
                        return bgMap.get(bgm.BuyerGroup.NAC_Type__c);
                    }
                }                
            }
            return 0.0;
        } catch (Exception e) {
            throw new AuraHandledException('getRushOrderCharge:'+e.getMessage());
        }
    }

    public class checkOutWrapper{
        @AuraEnabled public Contact userDetail;
        @AuraEnabled public List<ContactPointAddress> addressList;
        @AuraEnabled public picklistValueList orderTypeData;
        @AuraEnabled public picklistValueList shippingMethodData;
        @AuraEnabled public picklistValueList deliveryTermData;
        @AuraEnabled public Decimal totalNonCoreCartAmount;
        @AuraEnabled public string downloadLink;
        @AuraEnabled public string selectedBranchPlantWarehouse;
        @AuraEnabled public string customerType;
        @AuraEnabled public Boolean isCustomAddEnabled;
        @AuraEnabled public Map<String,List<NAC_Country_and_State_Picklist__mdt>> countryStatePicklistValue;
        checkOutWrapper(){
            userDetail = new Contact();
            addressList = new List<ContactPointAddress>();
            countryStatePicklistValue = new Map<String,List<NAC_Country_and_State_Picklist__mdt>>();
        }
    }
    
    public class picklistValueList{
        @AuraEnabled public Map<String, Integer> controllerValues;
        @AuraEnabled public Map<String, Integer> parentControllerValues;
        @AuraEnabled public picklistValue defaultValue;
        @AuraEnabled public List<picklistValue> values;
        picklistValueList(){
            values = new List<picklistValue>();
            controllerValues = new Map<String, Integer>();
            parentControllerValues = new Map<String, Integer>();
        }
    }
    
    public class picklistValue{
        @AuraEnabled public string label;
        @AuraEnabled public string value;
        @AuraEnabled public List<Integer> validFor;
        @AuraEnabled public List<Integer> childrenValidFor;
        picklistValue(){
            validFor = new List<Integer>();
            childrenValidFor = new List<Integer>();
        }
    }
    
    public class orderResultWrapper{
        @AuraEnabled public String orderId;
        @AuraEnabled public boolean hasError;
        @AuraEnabled public String errorMessage;
        orderResultWrapper(){
            hasError = false;
            errorMessage = '';
        }
    }
    
    public class orderLineList{
        public String id,name,label,description,originalId,originalName,originalLabel,originalDescription,brand,type,priceErrorMessage,quantity,totalPrice,supercessionProductName,substitutionProcductName,quantityErrorMessage,coreProcductName,effectiveDate,freightType,deliveryType;
        public integer price,quantityDesired,quantityAvailable,quantityReturned,quantityNum,totalPriceNum;
        public boolean hasPriceError,hasQuantityError,hasSupercession,hasSubstitution,hasCore,phasedOut,multiPack;
        public double taxrate,tax,freight,length,width,height,weight;
        public orderLineList(){
            id = '';
            name = '';
            label = '';
            description = '';
            originalId = '';
            originalName = '';
            originalLabel = '';
            originalDescription = '';
            brand = '';
            type = '';
            price = 0;
            hasPriceError = false;
            priceErrorMessage = '';
            quantityDesired = 0;
            quantityAvailable = 0;
            quantityReturned = 0;
            quantity = '';
            quantityNum = 0;
            totalPrice = '';
            totalPriceNum = 0;
            hasQuantityError = false;
            quantityErrorMessage = '';
            hasSupercession = false;
            supercessionProductName = '';
            hasSubstitution = false;
            substitutionProcductName = '';
            hasCore = false;
            coreProcductName = '';
            phasedOut = false;
            multiPack = false;
            effectiveDate = '';
            taxrate = 0;
            tax = 0;
            freight = 0;
            freightType = '';
            deliveryType = '';
            weight = 0;
            length = 0;
            width = 0;
            height = 0;
            id = '';
            name = '';
            label = '';
            description = '';
            originalId = '';
            originalName = '';
            originalLabel = '';
            originalDescription = '';
            brand = '';
            type = '';
            price = 0;
            hasPriceError = false;
            priceErrorMessage = '';
            quantityDesired = 0;
            quantityAvailable = 0;
            quantityReturned = 0;
            quantity = '';
            quantityNum = 0;
            totalPrice = '';
            totalPriceNum = 0;
            hasQuantityError = false;
            quantityErrorMessage = '';
            hasSupercession = false;
            supercessionProductName = '';
            hasSubstitution = false;
            substitutionProcductName = '';
            hasCore = false;
            coreProcductName = '';
            phasedOut = false;
            multiPack = false;
            effectiveDate = '';
            taxrate = 0;
            tax = 0;
            freight = 0;
            freightType = '';
            deliveryType = '';
            weight = 0;
            length = 0;
            width = 0;
            height = 0;
            id = '';
            name = '';
            label = '';
            description = '';
            originalId = '';
            originalName = '';
            originalLabel = '';
            originalDescription = '';
            brand = '';
            type = '';
            price = 0;
            hasPriceError = false;
            priceErrorMessage = '';
            quantityDesired = 0;
            quantityAvailable = 0;
            quantityReturned = 0;
            quantity = '';
            quantityNum = 0;
            totalPrice = '';
            totalPriceNum = 0;
            hasQuantityError = false;
            quantityErrorMessage = '';
            hasSupercession = false;
            supercessionProductName = '';
            hasSubstitution = false;
            substitutionProcductName = '';
            hasCore = false;
            coreProcductName = '';
            phasedOut = false;
            multiPack = false;
            effectiveDate = '';
            taxrate = 0;
            tax = 0;
            freight = 0;
            freightType = '';
            deliveryType = '';
            weight = 0;
            length = 0;
            width = 0;
            height = 0;
            id = '';
            name = '';
            label = '';
            description = '';
            originalId = '';
            originalName = '';
            originalLabel = '';
            originalDescription = '';
            brand = '';
            type = '';
            price = 0;
            hasPriceError = false;
            priceErrorMessage = '';
            quantityDesired = 0;
            quantityAvailable = 0;
            quantityReturned = 0;
            quantity = '';
            quantityNum = 0;
            totalPrice = '';
            totalPriceNum = 0;
            hasQuantityError = false;
            quantityErrorMessage = '';
            hasSupercession = false;
            supercessionProductName = '';
            hasSubstitution = false;
            substitutionProcductName = '';
            hasCore = false;
            coreProcductName = '';
            phasedOut = false;
            multiPack = false;
            effectiveDate = '';
            taxrate = 0;
            tax = 0;
            freight = 0;
            freightType = '';
            deliveryType = '';
            weight = 0;
            length = 0;
            width = 0;
            height = 0;
            id = '';
            name = '';
            label = '';
            description = '';
            originalId = '';
            originalName = '';
            originalLabel = '';
            originalDescription = '';
            brand = '';
            type = '';
            price = 0;
            hasPriceError = false;
            priceErrorMessage = '';
            quantityDesired = 0;
            quantityAvailable = 0;
            quantityReturned = 0;
            quantity = '';
            quantityNum = 0;
            totalPrice = '';
            totalPriceNum = 0;
            hasQuantityError = false;
            quantityErrorMessage = '';
            hasSupercession = false;
            supercessionProductName = '';
            hasSubstitution = false;
            substitutionProcductName = '';
            hasCore = false;
            coreProcductName = '';
            phasedOut = false;
            multiPack = false;
            effectiveDate = '';
            taxrate = 0;
            tax = 0;
            freight = 0;
            freightType = '';
            deliveryType = '';
            weight = 0;
            length = 0;
            width = 0;
            height = 0;
            id = '';
            name = '';
            label = '';
            description = '';
            originalId = '';
            originalName = '';
            originalLabel = '';
            originalDescription = '';
            brand = '';
            type = '';
            price = 0;
            hasPriceError = false;
            priceErrorMessage = '';
            quantityDesired = 0;
            quantityAvailable = 0;
            quantityReturned = 0;
            quantity = '';
            quantityNum = 0;
            totalPrice = '';
            totalPriceNum = 0;
            hasQuantityError = false;
            quantityErrorMessage = '';
            hasSupercession = false;
            supercessionProductName = '';
            hasSubstitution = false;
            substitutionProcductName = '';
            hasCore = false;
            coreProcductName = '';
            phasedOut = false;
            multiPack = false;
            effectiveDate = '';
            taxrate = 0;
            tax = 0;
            freight = 0;
            freightType = '';
            deliveryType = '';
            weight = 0;
            length = 0;
            width = 0;
            height = 0;
            id = '';
            name = '';
            label = '';
            description = '';
            originalId = '';
            originalName = '';
            originalLabel = '';
            originalDescription = '';
            brand = '';
            type = '';
            price = 0;
            hasPriceError = false;
            priceErrorMessage = '';
            quantityDesired = 0;
            quantityAvailable = 0;
            quantityReturned = 0;
            quantity = '';
            quantityNum = 0;
            totalPrice = '';
            totalPriceNum = 0;
            hasQuantityError = false;
            quantityErrorMessage = '';
            hasSupercession = false;
            supercessionProductName = '';
            hasSubstitution = false;
            substitutionProcductName = '';
            hasCore = false;
            coreProcductName = '';
            phasedOut = false;
            multiPack = false;
            effectiveDate = '';
            taxrate = 0;
            tax = 0;
            freight = 0;
            freightType = '';
            deliveryType = '';
            weight = 0;
            length = 0;
            width = 0;
            height = 0;
            id = '';
            name = '';
            label = '';
            description = '';
            originalId = '';
            originalName = '';
            originalLabel = '';
            originalDescription = '';
            brand = '';
            type = '';
            price = 0;
            hasPriceError = false;
            priceErrorMessage = '';
            quantityDesired = 0;
            quantityAvailable = 0;
            quantityReturned = 0;
            quantity = '';
            quantityNum = 0;
            totalPrice = '';
            totalPriceNum = 0;
            hasQuantityError = false;
            quantityErrorMessage = '';
            hasSupercession = false;
            supercessionProductName = '';
            hasSubstitution = false;
            substitutionProcductName = '';
            hasCore = false;
            coreProcductName = '';
            phasedOut = false;
            multiPack = false;
            effectiveDate = '';
            taxrate = 0;
            tax = 0;
            freight = 0;
            freightType = '';
            deliveryType = '';
            weight = 0;
            length = 0;
            width = 0;
            height = 0;
            id = '';
            name = '';
            label = '';
            description = '';
            originalId = '';
            originalName = '';
            originalLabel = '';
            originalDescription = '';
            brand = '';
            type = '';
            price = 0;
            hasPriceError = false;
            priceErrorMessage = '';
            quantityDesired = 0;
            quantityAvailable = 0;
            quantityReturned = 0;
            quantity = '';
            quantityNum = 0;
            totalPrice = '';
            totalPriceNum = 0;
            hasQuantityError = false;
            quantityErrorMessage = '';
            hasSupercession = false;
            supercessionProductName = '';
            hasSubstitution = false;
            substitutionProcductName = '';
            hasCore = false;
            coreProcductName = '';
            phasedOut = false;
            multiPack = false;
            effectiveDate = '';
            taxrate = 0;
            tax = 0;
            freight = 0;
            freightType = '';
            deliveryType = '';
            weight = 0;
            length = 0;
            width = 0;
            height = 0;
            id = '';
            name = '';
            label = '';
            description = '';
            originalId = '';
            originalName = '';
            originalLabel = '';
            originalDescription = '';
            brand = '';
            type = '';
            price = 0;
            hasPriceError = false;
            priceErrorMessage = '';
            quantityDesired = 0;
            quantityAvailable = 0;
            quantityReturned = 0;
            quantity = '';
            quantityNum = 0;
            totalPrice = '';
            totalPriceNum = 0;
            hasQuantityError = false;
            quantityErrorMessage = '';
            hasSupercession = false;
            supercessionProductName = '';
            hasSubstitution = false;
            substitutionProcductName = '';
            hasCore = false;
            coreProcductName = '';
            phasedOut = false;
            multiPack = false;
            effectiveDate = '';
            taxrate = 0;
            tax = 0;
            freight = 0;
            freightType = '';
            deliveryType = '';
            weight = 0;
            length = 0;
            width = 0;
            height = 0;
            id = '';
            name = '';
            label = '';
            description = '';
            originalId = '';
            originalName = '';
            originalLabel = '';
            originalDescription = '';
            brand = '';
            type = '';
            price = 0;
            hasPriceError = false;
            priceErrorMessage = '';
            quantityDesired = 0;
            quantityAvailable = 0;
            quantityReturned = 0;
            quantity = '';
            quantityNum = 0;
            totalPrice = '';
            totalPriceNum = 0;
            hasQuantityError = false;
            quantityErrorMessage = '';
            hasSupercession = false;
            supercessionProductName = '';
            hasSubstitution = false;
            substitutionProcductName = '';
            hasCore = false;
            coreProcductName = '';
            phasedOut = false;
            multiPack = false;
            effectiveDate = '';
            taxrate = 0;
            tax = 0;
            freight = 0;
            freightType = '';
            deliveryType = '';
            weight = 0;
            length = 0;
            width = 0;
            height = 0;
            id = '';
            name = '';
            label = '';
            description = '';
            originalId = '';
            originalName = '';
            originalLabel = '';
            originalDescription = '';
            brand = '';
            type = '';
            price = 0;
            hasPriceError = false;
            priceErrorMessage = '';
            quantityDesired = 0;
            quantityAvailable = 0;
            quantityReturned = 0;
            quantity = '';
            quantityNum = 0;
            totalPrice = '';
            totalPriceNum = 0;
            hasQuantityError = false;
            quantityErrorMessage = '';
            hasSupercession = false;
            supercessionProductName = '';
            hasSubstitution = false;
            substitutionProcductName = '';
            hasCore = false;
            coreProcductName = '';
            phasedOut = false;
            multiPack = false;
            effectiveDate = '';
            taxrate = 0;
            tax = 0;
            freight = 0;
            freightType = '';
            deliveryType = '';
            weight = 0;
            length = 0;
            width = 0;
            height = 0;
            id = '';
            name = '';
            label = '';
            description = '';
            originalId = '';
            originalName = '';
            originalLabel = '';
            originalDescription = '';
            brand = '';
            type = '';
            price = 0;
            hasPriceError = false;
            priceErrorMessage = '';
            quantityDesired = 0;
            quantityAvailable = 0;
            quantityReturned = 0;
            quantity = '';
            quantityNum = 0;
            totalPrice = '';
            totalPriceNum = 0;
            hasQuantityError = false;
            quantityErrorMessage = '';
            hasSupercession = false;
            supercessionProductName = '';
            hasSubstitution = false;
            substitutionProcductName = '';
            hasCore = false;
            coreProcductName = '';
            phasedOut = false;
            multiPack = false;
            effectiveDate = '';
            taxrate = 0;
            tax = 0;
            freight = 0;
            freightType = '';
            deliveryType = '';
            weight = 0;
            length = 0;
            width = 0;
            height = 0;
            id = '';
            name = '';
            label = '';
            description = '';
            originalId = '';
            originalName = '';
            originalLabel = '';
            originalDescription = '';
            brand = '';
            type = '';
            price = 0;
            hasPriceError = false;
            priceErrorMessage = '';
            quantityDesired = 0;
            quantityAvailable = 0;
            quantityReturned = 0;
            quantity = '';
            quantityNum = 0;
            totalPrice = '';
            totalPriceNum = 0;
            hasQuantityError = false;
            quantityErrorMessage = '';
            hasSupercession = false;
            supercessionProductName = '';
            hasSubstitution = false;
            substitutionProcductName = '';
            hasCore = false;
            coreProcductName = '';
            phasedOut = false;
            multiPack = false;
            effectiveDate = '';
            taxrate = 0;
            tax = 0;
            freight = 0;
            freightType = '';
            deliveryType = '';
            weight = 0;
            length = 0;
            width = 0;
            height = 0;
            id = '';
            name = '';
            label = '';
            description = '';
            originalId = '';
            originalName = '';
            originalLabel = '';
            originalDescription = '';
            brand = '';
            type = '';
            price = 0;
            hasPriceError = false;
            priceErrorMessage = '';
            quantityDesired = 0;
            quantityAvailable = 0;
            quantityReturned = 0;
            quantity = '';
            quantityNum = 0;
            totalPrice = '';
            totalPriceNum = 0;
            hasQuantityError = false;
            quantityErrorMessage = '';
            hasSupercession = false;
            supercessionProductName = '';
            hasSubstitution = false;
            substitutionProcductName = '';
            hasCore = false;
            coreProcductName = '';
            phasedOut = false;
            multiPack = false;
            effectiveDate = '';
            taxrate = 0;
            tax = 0;
            freight = 0;
            freightType = '';
            deliveryType = '';
            weight = 0;
            length = 0;
            width = 0;
            height = 0;
            id = '';
            name = '';
            label = '';
            description = '';
            originalId = '';
            originalName = '';
            originalLabel = '';
            originalDescription = '';
            brand = '';
            type = '';
            price = 0;
            hasPriceError = false;
            priceErrorMessage = '';
            quantityDesired = 0;
            quantityAvailable = 0;
            quantityReturned = 0;
            quantity = '';
            quantityNum = 0;
            totalPrice = '';
            totalPriceNum = 0;
            hasQuantityError = false;
            quantityErrorMessage = '';
            hasSupercession = false;
            supercessionProductName = '';
            hasSubstitution = false;
            substitutionProcductName = '';
            hasCore = false;
            coreProcductName = '';
            phasedOut = false;
            multiPack = false;
            effectiveDate = '';
            taxrate = 0;
            tax = 0;
            freight = 0;
            freightType = '';
            deliveryType = '';
            weight = 0;
            length = 0;
            width = 0;
            height = 0;
            id = '';
            name = '';
            label = '';
            description = '';
            originalId = '';
            originalName = '';
            originalLabel = '';
            originalDescription = '';
            brand = '';
            type = '';
            price = 0;
            hasPriceError = false;
            priceErrorMessage = '';
            quantityDesired = 0;
            quantityAvailable = 0;
            quantityReturned = 0;
            quantity = '';
            quantityNum = 0;
            totalPrice = '';
            totalPriceNum = 0;
            hasQuantityError = false;
            quantityErrorMessage = '';
            hasSupercession = false;
            supercessionProductName = '';
            hasSubstitution = false;
            substitutionProcductName = '';
            hasCore = false;
            coreProcductName = '';
            phasedOut = false;
            multiPack = false;
            effectiveDate = '';
            taxrate = 0;
            tax = 0;
            freight = 0;
            freightType = '';
            deliveryType = '';
            weight = 0;
            length = 0;
            width = 0;
            height = 0;
            id = '';
            name = '';
            label = '';
            description = '';
            originalId = '';
            originalName = '';
            originalLabel = '';
            originalDescription = '';
            brand = '';
            type = '';
            price = 0;
            hasPriceError = false;
            priceErrorMessage = '';
            quantityDesired = 0;
            quantityAvailable = 0;
            quantityReturned = 0;
            quantity = '';
            quantityNum = 0;
            totalPrice = '';
            totalPriceNum = 0;
            hasQuantityError = false;
            quantityErrorMessage = '';
            hasSupercession = false;
            supercessionProductName = '';
            hasSubstitution = false;
            substitutionProcductName = '';
            hasCore = false;
            coreProcductName = '';
            phasedOut = false;
            multiPack = false;
            effectiveDate = '';
            taxrate = 0;
            tax = 0;
            freight = 0;
            freightType = '';
            deliveryType = '';
            weight = 0;
            length = 0;
            width = 0;
            height = 0;
        }
    }
    
}