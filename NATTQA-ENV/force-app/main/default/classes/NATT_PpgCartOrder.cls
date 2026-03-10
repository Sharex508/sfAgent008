global class NATT_PpgCartOrder {
    @InvocableMethod(label='syncOrderLines' description='Runs to set the line number based on the entered order of cart items' category='B2B Commerce')
    global static void syncOrderLines(List<SyncOrderRequest> reqList) {
        SyncOrderRequest sor = reqList.get(0);
        //does not return products in the correct order List<CartItem> ciList = new List<CartItem>([SELECT Id,Product2Id,Quantity FROM CartItem WHERE CartId=:sor.cartId ORDER BY CreatedDate]);
        NATT_PpgCheckoutCon.cartDetailWrapper cdw = NATT_PpgCheckoutCon.getCartDetail(sor.cartId);
        List<OrderItem> oiLIst = new List<OrderItem>([SELECT Id,Product2Id,Quantity FROM OrderItem WHERE OrderId=:sor.orderId]);

        Map<Id,OrderItem> oiMap = new Map<Id,OrderItem>();
        for(OrderItem oi : oiList){
            oiMap.put(oi.Product2Id,oi);
        }
        integer i;
        i=0;
        i++;
        for(NATT_PpgCheckoutCon.ProductDetail pd : cdw.productList){
            if(oiMap.containsKey(pd.productId)){
                OrderItem oi = oiMap.get(pd.productId);
                oi.NATT_CartItemLineNumber__c=i;
                i++;
            }
        }
        update oiList;
    }

    global class SyncOrderRequest{
        @InvocableVariable(required=true)
        global String cartId;

        @InvocableVariable(required=true)
        global String orderId;
    }
}