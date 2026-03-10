/*Author: LTI
* Created Date: 31st October 2022
* Class Name: ctbrretrieveCancelledOrders_Parts
* Description: This class is used to send CTBR Cancelled Orders (Parts) from salesforce via GET.
* Last modified Date - 07/11/2022 - Dharani 
*/
@RestResource(urlMapping='/retrieveCancelledOrdersParts/*')
global without sharing class ctbrretrieveCancelledOrders_Parts { 
    // this method is used to fetch all the CTBR Orders records requested from SAP
    @HttpGet
    global static List<OrderWrp> getOrders() {
        try{
            List<Order> Orders = new List<Order>();
            List<OrderWrp> CancOrderLst = new List<OrderWrp>();
            List<Order> getOrderRec = [SELECT id,Status,OrderNumber,NATT_Order_Status__c, (select id,OrderItemNumber,CTBR_SapItemStatus__c,Product2Id,Quantity from OrderItems) FROM Order WHERE recordtype.name = 'CTBR Parts Order' AND NATT_Order_Status__c = 'Cancelled']; // 2/13 updated NATT_Order_Status__c AND Sent_to_SAP__c = FALSE..temp commenting.
                                  			//17/10 currently Cancelled value is not present in Status picklist, confirm on the correct field.
            for(Order orderobj : getOrderRec) {
                OrderWrp orderWrpObj = new OrderWrp();
                orderWrpObj.status = orderObj.NATT_Order_Status__c;//2/13 updated to NATT_Order_Status__c
                orderWrpObj.OrderExternalId = orderObj.id;
                orderWrpObj.OrderNumber = orderobj.OrderNumber;
                orderWrpObj.orderItemWrpLst = getOrderItem(orderobj.OrderItems);
                CancOrderLst.add(orderWrpObj);
                Orders.add(orderObj);  //13/0
            }
            if(!Orders.isempty()){	
                update Orders; //13/10 
            }
            return CancOrderLst;
        }catch(Exception ex){
            ctbrUtility.LogException(ex, 'ctbrgetCancOrderParts', 'getOrders');
            return null;
        }
    }
    
    public static List<orderItemWrp> getOrderItem(List<OrderItem> lstOrderItem){
		List<orderItemWrp> ordItmList = new List<orderItemWrp>();
        for(OrderItem orderItemObj : lstOrderItem){
            orderItemWrp orderItemWrpObj = new orderItemWrp();
            orderItemWrpObj.SAPItemStatus = orderItemObj.CTBR_SapItemStatus__c;
            orderItemWrpObj.orderItemExternalId = orderItemObj.OrderItemNumber;
            orderItemWrpObj.productId = orderItemObj.Product2Id;
            orderItemWrpObj.quantity = orderItemObj.Quantity;
            ordItmList.add(orderItemWrpObj);
        }
		return ordItmList; 
    }
    
	global class OrderWrp {
        public string OrderExternalId;
        public String Status;
        public String OrderNumber;
        public List<orderItemWrp> orderItemWrpLst;
    }
    
    global class orderItemWrp {
        public string SAPItemStatus;
		public String orderItemExternalId; 
        public string productId;
        public decimal quantity;
    }
    
    global class ResponseSummary {
        //List of custom attributes that we want to check the status of the org  
    }
    
}