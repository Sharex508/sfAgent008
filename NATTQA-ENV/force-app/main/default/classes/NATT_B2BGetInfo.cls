public with sharing class NATT_B2BGetInfo {
    @AuraEnabled
    public static ConnectApi.CartSummary getCartSummary(
        String communityId,
        String effectiveAccountId
    ) {
        // Lookup the webstore ID associated with the community
        String webstoreId = B2BUtils.resolveCommunityIdToWebstoreId(communityId);
        
        //'current' is available in version 50.0 and later and indicates a cart with a status that isn’t Closed or PendingDelete
        //This is important for the product detail page since we are using the cart summary to check if the status is "Processing" or "Checkout"
        String activeCartOrId = 'current';
        
        // https://developer.salesforce.com/docs/atlas.en-us.apexcode.meta/apexcode/apex_ConnectAPI_CommerceCart_static_methods.htm
        return ConnectApi.CommerceCart.getCartSummary(
            webstoreId,
            effectiveAccountId,
            activeCartOrId
        );
    }
    
    @AuraEnabled
    public static List<ConnectApi.BatchResult> addItemsToCart(
        String communityId,
        String effectiveAccountId,
        List<String[]> products
    ) {
        //System.debug(products);
        // Lookup the webstore ID associated with the community
        String webstoreId = B2BUtils.resolveCommunityIdToWebstoreId(communityId);
        
        List<ConnectApi.BatchInput> cartItems = new List<ConnectApi.BatchInput>();
        for (String[] product : products) {
            //system.debug('Raj-product-'+product);
            ConnectApi.CartItemInput cartInput = new ConnectApi.CartItemInput();
            //system.debug('Raj-cartInput-'+cartInput);
            cartInput.productId = product[0];
            cartInput.quantity = product[1];
            cartInput.type = ConnectApi.CartItemType.PRODUCT;
            cartItems.add(new ConnectApi.BatchInput(cartInput));
        }
        
        // https://developer.salesforce.com/docs/atlas.en-us.apexcode.meta/apexcode/apex_ConnectAPI_CommerceCart_static_methods.htm#apex_ConnectAPI_CommerceCart_static_methods
        return ConnectApi.CommerceCart.addItemsToCart(
            webstoreId,
            effectiveAccountId,
            'current',
            cartItems
        );
    }
    
    @AuraEnabled
    public static ConnectApi.ProductSearchResults productSearch(
        String communityId,
        String partNumber,
        String effectiveAccountId
    ) {
        // Lookup the webstore ID associated with the community
        String webstoreId = B2BUtils.resolveCommunityIdToWebstoreId(communityId);
        
        ConnectApi.ProductSearchInput productSearchInput = new ConnectApi.ProductSearchInput();
        productSearchInput.includePrices = true;
        productSearchInput.searchTerm = partNumber;
        productSearchInput.fields = new List<String>{
            'Id',
                'NATT_P_N__c',
                'NATT_Weight__c',
                'NATT_Length__c',
                'NATT_Width__c',
                'NATT_Height__c',
                'Description',
                'QuantityUnitOfMeasure',
                'Name',
                'StockKeepingUnit',
                'NATT_ItemPriceGroup__c',
                'NATT_CoreCharge__c',
                'NATT_CorePrice__c',
                'NATT_CoreItem_P_N__c',
                'NATT_SignalCode__c',
                'NATT_UOM_Conversion__c',
                'NATT_Sales_Code__c',
                'NATT_DirectDelivery__c',
                'NATT_UnitCost__c',
                'NATT_Discount_Code__c'
                };
                    
                    ConnectApi.ProductSearchResults productSearchResults;
        try {
            productSearchResults = ConnectApi.CommerceSearch.searchproducts(
                webstoreId,
                effectiveAccountId,
                productSearchInput
            );
        } catch (Exception ex) {
            System.debug(ex);
            throw ex;
        }
        //system.debug('Raj--'+productSearchResults);
        return productSearchResults;
    }
    
    @AuraEnabled
    public static ConnectApi.ProductSearchResults quickProductSearch(
        String communityId,
        String partNumber,
        String effectiveAccountId
    ) {
        // Lookup the webstore ID associated with the community
        String webstoreId = B2BUtils.resolveCommunityIdToWebstoreId(communityId);
        
        ConnectApi.ProductSearchInput productSearchInput = new ConnectApi.ProductSearchInput();
        productSearchInput.includePrices = false;
        productSearchInput.searchTerm = partNumber;
        productSearchInput.fields = new List<String>{
            'Id',
                'NATT_P_N__c',      
                'Name'
                };
                    
                    ConnectApi.ProductSearchResults productSearchResults;
        try {
            productSearchResults = ConnectApi.CommerceSearch.searchproducts(
                webstoreId,
                effectiveAccountId,
                productSearchInput
            );
        } catch (Exception ex) {
            System.debug(ex);
            throw ex;
        }
        
        return productSearchResults;
    }
    
    @AuraEnabled
    public static ConnectApi.ProductPrice getProductPrice(String communityId,String productId,String effectiveAccountId) {
        // Lookup the webstore ID associated with the community
        String webstoreId = B2BUtils.resolveCommunityIdToWebstoreId(communityId);
        ConnectApi.ProductPrice pPrice;
        try {
            pPrice = ConnectApi.CommerceStorePricing.getProductPrice(webstoreId,productId,effectiveAccountId);
        } catch (Exception ex) {
            System.debug(ex);
            throw ex;
        }
        return pPrice;
    }
    
    @AuraEnabled
    public static ConnectApi.ProductDetail getProductDetail(String communityId,String productId,String effectiveAccountId) {
        String webstoreId = B2BUtils.resolveCommunityIdToWebstoreId(communityId);
        ConnectApi.ProductDetail productDetail;
        try {
            productDetail = ConnectApi.CommerceCatalog.getProduct(
                webstoreId,
                productId,
                effectiveAccountId,
                new List<String>(),
                true,
                new List<String>(),
                false,
                false,
                false);
        } catch (Exception ex) {
            System.debug(ex);
            throw ex;
        }
        
        return productDetail;
    }
    @AuraEnabled
    public static void updateWebCart(Id cartId, String warehouseVal) {
        try{
            system.debug('warehouseVal-'+warehouseVal +' CartID-'+cartId );
            WebCart CartToUpdate = [SELECT Id, NATT_Warehouse__c FROM WebCart WHERE Id = :cartId LIMIT 1];
            CartToUpdate.NATT_Warehouse__c = warehouseVal; 
            update CartToUpdate;
        }
        catch(exception e){
            system.debug(e);
            throw e;
        }
    }
    @AuraEnabled
    public static void updateBuyerGroup(String AccountID, String Warehouse) {
        CtmBuyerGroupMemberUpdate.updateBuyerGroup(AccountID, Warehouse);
    }
    @AuraEnabled
    public static string getCartWarehouse(string CartID, string AccountID) {
        try{
            string warehouse ='';
            Webcart cart = new Webcart();
            cart = [select Id, name, NATT_Warehouse__c from WebCart where id =: CartID ];
            if(cart != null && cart.NATT_Warehouse__c !=null ){
                warehouse = cart.NATT_Warehouse__c;
            }
            else{
                BuyerGroupMember bgm = new BuyerGroupMember();
                map<string, string> cartWarehouseBuyergroupMap = new map<string,string>();
                cartWarehouseBuyergroupMap.put('CTM PAN Parts Buyer Group','PAN');
                cartWarehouseBuyergroupMap.put('CTM MIA Parts Buyer Group','MIA');
                cartWarehouseBuyergroupMap.put('CTM LATM Parts Buyer Group','LATAM');
                
                bgm  = CtmBuyerGroupMemberUpdate.getBuyerGroupMember(AccountID, cartWarehouseBuyergroupMap);
                warehouse = bgm != null  ? cartWarehouseBuyergroupMap.get(bgm.BuyerGroup.name) : '';
            }
            return warehouse ;   
        }
        catch(exception e){
            system.debug('error'+ e);
            return '';
        }
    }
     //Added bY Rajasekharreddy Kotella
    @AuraEnabled
    //public static ConnectApi.CartItemCollection getCartItems(
    public static ConnectApi.CartItem updateCartItem(String communityId, String effectiveAccountId, String activeCartOrId)
    {
        Map<Id, Integer> cartItemsQtyMap = new Map<Id, Integer>();
        String webstoreId = B2BUtils.resolveCommunityIdToWebstoreId(communityId);
        list<ConnectApi.CartItemInput> CartItemList = new  List<ConnectApi.CartItemInput>();
        system.debug('Cart Summary Log-- '+ ConnectApi.CommerceCart.getCartSummary(webstoreId, effectiveAccountId, 'current'));
        return null;
    }
    
}