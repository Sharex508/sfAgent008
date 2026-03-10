global class NATT_B2bDelivery {
    // This invocable method only expects one ID
    @InvocableMethod(callout=true label='Prepare the Delivery Method Options' description='Runs a synchronous version of delivery method preparation' category='B2B Commerce')
    global static void syncDelivery(List<SyncDeliveryActionRequest> reqList) {
        SyncDeliveryActionRequest req = reqList.get(0);
        // Validate the input
        if (String.isBlank(req.cartId) || String.isBlank(req.orderType)) {
            String errorMessage = 'A cart id and order type must be included to B2BSyncDelivery';
            saveCartValidationOutputError(errorMessage, '');
            throw new CalloutException (errorMessage);
        }
        startCartProcessSync(req.cartId,req.orderType);
    }

    private static void startCartProcessSync(Id cartId,String orderType) {
        try {
            System.debug('called with order type:'+orderType);
            // We need to get the ID of the cart delivery group in order to create the order delivery groups.
            Id cartDeliveryGroupId = [SELECT Id FROM CartDeliveryGroup WHERE CartId = :cartId WITH SECURITY_ENFORCED][0].Id;

            // Get shipping options, including aspects like rates and carriers, from the external service. 
            ShippingOptionsAndRatesFromExternalService[] shippingOptionsAndRatesFromExternalService = getShippingOptions(orderType);
            System.debug('shippingOptionsAndRates:'+shippingOptionsAndRatesFromExternalService);
            // On re-entry of the checkout flow delete all previous CartDeliveryGroupMethods for the given cartDeliveryGroupId
            delete [SELECT Id FROM CartDeliveryGroupMethod WHERE CartDeliveryGroupId = :cartDeliveryGroupId WITH SECURITY_ENFORCED];
            
            // Create orderDeliveryMethods given your shipping options or fetch existing ones. 2 should be returned.
            List<Id> orderDeliveryMethodIds = getOrderDeliveryMethods(shippingOptionsAndRatesFromExternalService);

            // Create a CartDeliveryGroupMethod record for every shipping option returned from the external service
            Integer i = 0;
            for (Id orderDeliveryMethodId: orderDeliveryMethodIds) {
               populateCartDeliveryGroupMethodWithShippingOptions(shippingOptionsAndRatesFromExternalService[i],
                                                                  cartDeliveryGroupId,
                                                                  orderDeliveryMethodId,
                                                                  cartId);
                i+=1;
            }
        } catch (CalloutException e) {
            throw e;
        // For testing purposes, this example treats exceptions as user errors, which means they are displayed to the buyer user.
        // In production you probably want this to be an admin-type error. In that case, throw the exception here
        // and make sure that a notification system is in place to let the admin know that the error occurred.
        // See the readme section about error handling for details about how to create that notification.
        } catch (DmlException de) {
            // Catch any exceptions thrown when trying to insert the shipping charge to the CartItems
            Integer numErrors = de.getNumDml();
            String errorMessage = 'There were ' + numErrors + ' errors when trying to insert the charge in the CartItem: ';
            for(Integer errorIdx = 0; errorIdx < numErrors; errorIdx++) {
                errorMessage += 'Field Names = ' + de.getDmlFieldNames(errorIdx);
                errorMessage += 'Message = ' + de.getDmlMessage(errorIdx);
                errorMessage += ' , ';
            }

            saveCartValidationOutputError(errorMessage, cartId);
            throw new CalloutException (errorMessage);
        } catch(Exception e) {
            String errorMessage = 'An exception of type ' + e.getTypeName() + ' has occurred: ' + e.getMessage();
            saveCartValidationOutputError(errorMessage, cartId);
            throw new CalloutException (errorMessage);
        }
    }

    private static ShippingOptionsAndRatesFromExternalService[] getShippingOptions (String orderType) {    
        System.debug('orderType in getShippingOptions:'+orderType);
        List<ShippingOptionsAndRatesFromExternalService> shippingOptions = new List<ShippingOptionsAndRatesFromExternalService>();
        for(NATT_B2B_Shipping_Option__c so : [SELECT Id,Name,NATT_Order_Type__c,NATT_Shipping_Method__c FROM NATT_B2B_Shipping_Option__c WHERE NATT_Order_Type__c includes (:orderType) ORDER BY NATT_Sort_Order__c ASC]){
            shippingOptions.add( new ShippingOptionsAndRatesFromExternalService(
                so.Name,
                so.NATT_Shipping_Method__c,
                0.0,
                0.0,
                so.Name
            ));
        }        
        return shippingOptions;
    }
    
    // Structure to store the shipping options retrieved 
    Class ShippingOptionsAndRatesFromExternalService {
        private String name;
        private String provider;
        private Decimal rate;
        private Decimal otherCost;
        private String serviceName;

        public ShippingOptionsAndRatesFromExternalService(String someName, String someProvider, Decimal someRate, Decimal someOtherCost, String someServiceName) {
            name = someName;
            provider = someProvider;
            rate = someRate;
            otherCost = someOtherCost;
            serviceName = someServiceName;
        }

        public String getProvider() {
            return provider;
        }

        public Decimal getRate() {
            return rate;
        }

        public Decimal getOtherCost() {
            return otherCost;
        }

        public String getServiceName() {
            return serviceName;
        }

        public String getName() {
            return name;
        }
    }

    // Create a CartDeliveryGroupMethod record for every shipping option returned from the external service
    private static void populateCartDeliveryGroupMethodWithShippingOptions(ShippingOptionsAndRatesFromExternalService shippingOption,
                                                                  Id cartDeliveryGroupId,
                                                                  Id deliveryMethodId,
                                                                  Id webCartId){
        // When inserting a new CartDeliveryGroupMethod, the following fields have to be populated:
        // CartDeliveryGroupId: Id of the delivery group of this shipping option
        // DeliveryMethodId: Id of the delivery method for this shipping option
        // ExternalProvider: Unique identifier of shipping provider
        // Name: Name of the CartDeliveryGroupMethod record
        // ShippingFee: The cost of shipping for the delivery group
        // WebCartId: Id if the cart that the delivery group belongs to
        CartDeliveryGroupMethod cartDeliveryGroupMethod = new CartDeliveryGroupMethod(
            CartDeliveryGroupId = cartDeliveryGroupId,
            DeliveryMethodId = deliveryMethodId,
            ExternalProvider = shippingOption.getProvider(),
            Name = shippingOption.getName(),
            ShippingFee = shippingOption.getRate(),
            WebCartId = webCartId
        );
        insert(cartDeliveryGroupMethod);
    }

    private static void saveCartValidationOutputError(String errorMessage, Id cartId) {
            // In order for the error to be propagated to the user, we need to add a new CartValidationOutput record.
            // The following fields must be populated:
            // BackgroundOperationId: Foreign Key to the BackgroundOperation
            // CartId: Foreign key to the WebCart that this validation line is for
            // Level (required): One of the following - Info, Error, or Warning
            // Message (optional): Message displayed to the user
            // Name (required): The name of this CartValidationOutput record. For example CartId:BackgroundOperationId
            // RelatedEntityId (required): Foreign key to WebCart, CartItem, CartDeliveryGroup
            // Type (required): One of the following - SystemError, Inventory, Taxes, Pricing, Shipping, Entitlement, Other
            CartValidationOutput cartValidationError = new CartValidationOutput(
                CartId = cartId,
                Level = 'Error',
                Message = errorMessage.left(255),
                Name = (String)cartId,
                RelatedEntityId = cartId,
                Type = 'Shipping'
            );
            insert(cartValidationError);
    }

    private static Id getShippingChargeProduct2Id(Id orderDeliveryMethodId) {
        // The Order Delivery Method should have a Product2 associated with it, because we added that in getDefaultOrderDeliveryMethod if it didn't exist.
        List<OrderDeliveryMethod> orderDeliveryMethods = [SELECT ProductId FROM OrderDeliveryMethod WHERE Id = :orderDeliveryMethodId WITH SECURITY_ENFORCED];
        return orderDeliveryMethods[0].ProductId;
    }

    private static List<Id> getOrderDeliveryMethods(List<ShippingOptionsAndRatesFromExternalService> shippingOptions) {
        String defaultDeliveryMethodName = 'Delivery Method ';
        Id product2IdForThisDeliveryMethod = getDefaultShippingChargeProduct2Id();

        // Check to see if a default OrderDeliveryMethod already exists.
        // If it doesn't exist, create one.
        List<Id> orderDeliveryMethodIds = new List<Id>();
        List<OrderDeliveryMethod> orderDeliveryMethods = new List<OrderDeliveryMethod>();
        Integer i = 1;
        for (ShippingOptionsAndRatesFromExternalService shippingOption: shippingOptions) {
            String shippingOptionNumber = String.valueOf(i);
            String name = shippingOption.serviceName;
            List<OrderDeliveryMethod> odms = [SELECT Id, ProductId, Carrier, ClassOfService FROM OrderDeliveryMethod WHERE Name = :name WITH SECURITY_ENFORCED];
            // This is the case in which an Order Delivery method does not exist.
            if (odms.isEmpty()) {
                OrderDeliveryMethod defaultOrderDeliveryMethod = new OrderDeliveryMethod(
                    Name = shippingOption.serviceName,
                    Carrier = shippingOption.serviceName,
                    isActive = true,
                    ProductId = product2IdForThisDeliveryMethod,
                    ClassOfService = shippingOption.provider
                );
                insert(defaultOrderDeliveryMethod);
                orderDeliveryMethodIds.add(defaultOrderDeliveryMethod.Id);
            }
            else {
                // This is the case in which an Order Delivery method exists.
                // If the OrderDeliveryMethod doesn't have a Product2 associated with it, assign one
                // We can always pick the 0th orderDeliveryMethod since we queried based off the name.
                OrderDeliveryMethod existingodm = odms[0];
                // This is for reference implementation purposes only.
                // This is the if statement that checks to make sure that there is a product carrier and class of service
                // associated to the order delivery method.
                if (existingodm.ProductId == null || existingodm.Carrier == null || existingodm.ClassOfService == null) {
                    existingodm.ProductId = product2IdForThisDeliveryMethod;
                    existingodm.Carrier = shippingOption.serviceName;
                    existingodm.ClassOfService = shippingOption.provider;
                    update(existingodm);
                }
                orderDeliveryMethodIds.add(existingodm.Id);
            }
            i+=1;
        }
        return orderDeliveryMethodIds;
    }

    private static Id getDefaultShippingChargeProduct2Id() {
        // In this example we will name the product representing shipping charges 'Shipping Charge for this delivery method'.
        // Check to see if a Product2 with that name already exists.
        // If it doesn't exist, create one.
        String shippingChargeProduct2Name = 'Freight Charge';
        List<Product2> shippingChargeProducts = [SELECT Id FROM Product2 WHERE NATT_P_N__c = 'Freight-PPG' WITH SECURITY_ENFORCED];
        if (shippingChargeProducts.isEmpty()) {
            Product2 shippingChargeProduct = new Product2(
                isActive = true,
                Name = shippingChargeProduct2Name,
                NATT_P_N__c='Freight-PPG'
            );
            insert(shippingChargeProduct);
            return shippingChargeProduct.Id;
        }
        else {
            return shippingChargeProducts[0].Id;
        }
    }

    global class SyncDeliveryActionRequest{
        @InvocableVariable(required=true)
        global String cartId;

        @InvocableVariable(required=true)
        global String orderType;
    }
}