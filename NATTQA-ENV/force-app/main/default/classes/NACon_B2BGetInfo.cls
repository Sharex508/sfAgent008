public with sharing class NACon_B2BGetInfo {

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
    System.debug(products);
    // Lookup the webstore ID associated with the community
    String webstoreId = B2BUtils.resolveCommunityIdToWebstoreId(communityId);

    List<ConnectApi.BatchInput> cartItems = new List<ConnectApi.BatchInput>();
    for (String[] product : products) {
      ConnectApi.CartItemInput cartInput = new ConnectApi.CartItemInput();
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
      'NATT_Discount_Code__c',
      'RecordTypeId',
      'NAOCAP_Not_Orderable__c',
      'NAOCAP_Not_Orderable_ANA__c',
      'NAOCAP_Not_Orderable_CHI__c',
      'NAOCAP_Not_Orderable_PAN__c',
      'NATT_Branch_Plant_Warehouse__c',
      'ProductCode',
      'NAOCAP_Signal_Code_PAN__c' ,
      'NAOCAP_Signal_Code_ANA__c'    
                
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
    
      /**
     * Gets webstore being accessed. 
     * - Webstore determines which columns will get displayed
     */
    @AuraEnabled
    public static String getWebstore(String communityId){
        String webstoreId = B2BUtils.resolveCommunityIdToWebstoreId(communityId);
        WebStore ws = [SELECT Id,Name FROM WebStore WHERE Id = :webstoreId];
        return ws.Name;
    }
    
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
    
    
}