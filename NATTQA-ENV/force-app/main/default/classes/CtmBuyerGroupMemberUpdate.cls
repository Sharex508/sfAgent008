public without sharing class CtmBuyerGroupMemberUpdate {

    public static void updateBuyerGroup(String AccountID, String Warehouse) {
        try {
            map<string, string> cartWarehouseBuyergroupMap = new map<string,string>();
            cartWarehouseBuyergroupMap.put('MEX','CTM MEX Parts Buyer Group');
            cartWarehouseBuyergroupMap.put('PAN','CTM PAN Parts Buyer Group');
            cartWarehouseBuyergroupMap.put('MIA','CTM MIA Parts Buyer Group');
            cartWarehouseBuyergroupMap.put('LATAM','CTM LATM Parts Buyer Group');
            
            List<BuyerGroupMember> BGMList  =[select id,name,Buyer.Name,BuyerId,  BuyerGroup.name
                                              from BuyerGroupMember
                                              where BuyerGroup.name =:  cartWarehouseBuyergroupMap.values()
                                              and BuyerId =:AccountID ];
            if(BGMList.size()>0){
                delete BGMList;
            }
            system.debug('Warehouse-'+Warehouse);
            system.debug('cartWarehouseBuyergroupMap.get(Warehouse)-'+cartWarehouseBuyergroupMap.get(Warehouse));
            BuyerGroup BG = [select id,name from BuyerGroup where name =: cartWarehouseBuyergroupMap.get(Warehouse) limit 1 ];
            
            Account acc = [select Id,Name from Account where id =:AccountID];
            system.debug('acc-'+acc);
            BuyerGroupMember BGMr = new BuyerGroupMember();
            
            BGMr.BuyerId = acc.Id;
            BGMr.BuyerGroupId = BG.Id;
            system.debug('BGMr-'+BGMr);
            insert BGMr;

        } catch (Exception e) {
            // Handle exception
            system.debug('Error: Line- '+ e.getLineNumber() + e.getMessage());
            throw new AuraHandledException('Error: Line- '+ e.getMessage());
        }
    }
    public static BuyerGroupMember getBuyerGroupMember(String AccountID, Map<String, String> partsBuyerGroupMap ) {
        try {
            system.debug('AccountID-'+AccountID);
            return [ select Id , Name, BuyerGroup.name, BuyerId, Buyer.name from BuyerGroupMember 
                    where BuyerId =: AccountID and BuyerGroup.name =: partsBuyerGroupMap.keySet()  limit 1 ];
        } catch (Exception e) {
            system.debug('Error: Line- '+ e.getLineNumber() + e.getMessage());
            return null;
        }
    }
        @AuraEnabled
    public static void clearCart(Id cartId) {
        // Logic to clear the cart items
        List<CartItem> cartItems = [SELECT Id FROM CartItem WHERE CartId = :cartId];
        delete cartItems;
    }
}