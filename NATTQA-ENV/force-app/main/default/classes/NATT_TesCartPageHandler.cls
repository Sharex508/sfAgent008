public with sharing class NATT_TesCartPageHandler {
    /**
     * Method used for New Cart creation on Carts screen. Called from [Create New Cart] button
     */
    @AuraEnabled
    // public static List<WebCart> newCartApi(Id UserId, String CartName, String CommunityId){
    public static Id newCartApi(Id UserId, String CartName, String CommunityId){
        String webStoreId = B2BUtils.resolveCommunityIdToWebstoreId(CommunityId);

        User userRecord = [SELECT ContactId FROM User WHERE Id = :UserId];
        Contact userContact = [SELECT AccountId FROM Contact WHERE Id = :userRecord.ContactId];
        String webStoreValue = null;

        List<WebCart> WebCartList = [SELECT Id, Name, AccountId, IsSecondary,TotalProductAmount,TotalAmount, Status, NATT_Is_Cart_Primary__c, LastModifiedDate, TotalProductCount, UniqueProductCount
                                        FROM WebCart
                                        WHERE (Status = 'Checkout') AND (OwnerId = :UserId) AND (WebStoreId = :webStoreId)
        ];
        List<WebCart>checkoutToActiveList = new List<WebCart>();
        for (WebCart cart : WebCartList){
            if (cart.Status == 'Checkout'){
            // makeCartPrimary
                cart.Status = 'Active';
                checkoutToActiveList.add(cart);
            } 
        }
        update checkoutToActiveList;
        
        /**
         * Updates current cart with New name and set to secondary to prepare for new cart
         */
        WebCart currentCartToRename = [
            SELECT Name, WebStoreId, isSecondary 
            FROM WebCart 
            WHERE (NATT_Is_Cart_Primary__c = true) AND (Status = 'Active' OR Status = 'Checkout') AND (OwnerId = :UserId) AND (WebStoreId = :webstoreId)
        ];
        currentCartToRename.isSecondary = true;
        webStoreValue = currentCartToRename.WebStoreId;
        update currentCartToRename;

        ConnectApi.CartInput newCart = new ConnectApi.CartInput();
        newCart.isSecondary = false;
        Date todayDate = date.today();
        // newCart.name = 'New Cart ' + todayDate.format();
        newCart.name = CartName;

        ConnectApi.CartSummary newCartSummary = ConnectApi.CommerceCart.createCart(
            webStoreValue, 
            newCart);
        
        return newCartSummary.cartId;
    }

}