@RestResource(urlMapping='/retrieveApprovedPartsOrders/*')
global without sharing class ctbrOrderInboundApproved_Parts {
/*Author: LTI
* Created Date: 18th Nov 2022
* Class Name: ctbrOrderInboundApproved_Parts
* Description: This class is used to send CTBR Approved Parts Orders from salesforce via GET 
* */
  // this method is used to fetch all the Approved CTBR Parts Orders records requested from SAP
    @HttpGet
    global static List<GetOrderWrapper> getOrderandOrdItem(){
        try{
            List<Order> OrderandOrdItem = new List<Order>();
            List<GetOrderWrapper> DraftOrderLst = new List<GetOrderWrapper>();
          	// List<Order> getOrderRec = [SELECT id,recordtype.name,NATT_Payment_Terms__c,NATT_Dealer_Comments__c,Sent_to_SAP__c,Status,ordereddate,ordernumber,NATT_Ship_Date__c,CreatedDate, 
            //                          SBQ__Quote__c,(select id, Product2Id,NATT_Product_Name__c,OrderItemNumber,Quantity,UnitPrice,TotalPrice from orderitems) FROM Order WHERE recordtype.name = 'CTBR Parts Order' AND Status = 'Draft'];  // AND Sent_to_SAP__c = FALSE..temp commenting.
            for(Order orderobj : [SELECT id,recordtype.name,/*NATT_Payment_Terms__c*/CTBR_TaxObservation__c,NATT_Dealer_Comments__c,Sent_to_SAP__c,Status,NATT_Order_Status__c,CTBR_JDE_Billing_Address_Id__c,CTBR_JDE_Shipping_Address_Id__c,
                                  			ordereddate,ordernumber,NATT_Ship_Date__c,CreatedDate,SBQQ__Quote__c,NATT_Shipment_Method__c,CTBR_Shipment_Method__c,CTBR_Freight_Payment__c,NATT_Shipment_Terms__c,
                                  			(select id,Product2Id,CTBR_SapItemStatus__c,Purchase_Order_Number__c,Part_Number__c,NATT_Product_Name__c,OrderItemNumber,Quantity,
                                             UnitPrice,ListPrice,TotalPrice from orderitems) FROM Order WHERE recordtype.name = 'CTBR Parts Order' AND NATT_Order_Status__c = 'Customer Approved']){                                               // AND Sent_to_SAP__c = FALSE..temp commenting.
                if(!orderobj.orderitems.isEmpty()){
                    //This assumes that Products are always present under a CTBR Parts Order
                    GetOrderWrapper orderWrapperObj = new GetOrderWrapper();
                    orderWrapperObj.status = orderObj.NATT_Order_Status__c;//11/18
                    orderWrapperObj.BillToLocation = orderobj.CTBR_JDE_Billing_Address_Id__c;//8/12
                    orderWrapperObj.ShipToLocation = orderobj.CTBR_JDE_Shipping_Address_Id__c;//8/12
                    orderwrapperobj.taxObservation = orderobj.CTBR_TaxObservation__c;
                    orderWrapperObj.OrderNumber = orderObj.OrderNumber;
                    //Commented just for migration NATT_Payment_Terms__c,CTBR_SapQuoteId__c,CTBR_FixedPayment__c,CTBR_Taxation__c,CTBR_Has_Global_Price_List__c,CTBR_Payment_Condition_Code__c,CTBR_Global_Price_List_Code__c
                    //orderWrapperObj.paymentTerms = orderObj.NATT_Payment_Terms__c;
                    orderWrapperObj.dealerComments = orderObj.NATT_Dealer_Comments__c;
                    orderWrapperObj.ShipmentMethod = orderobj.CTBR_Shipment_Method__c;// 2/13 changed to CTBR_Shipment_Method__c
                    orderWrapperObj.ShipmentCompany = orderobj.NATT_Shipment_Method__c;// 2/13 changed to NATT_Shipment_Method__c
                    orderWrapperObj.freightTerms = orderobj.NATT_Shipment_Terms__c;
                    orderWrapperObj.freightPayment = orderobj.CTBR_Freight_Payment__c;//added 2/13.
                    orderWrapperObj.createdDate = dateformat(orderobj.CreatedDate); //19/10
                    orderWrapperObj.orderexternalid = orderObj.id;
                    orderObj.Sent_to_SAP__c = true; //13/10
                    //orderWrapperObj.QuoteId = orderobj.SBQQ__Quote__c;
                    //orderWrapperObj.orderdate = orderobj.ordereddate;
                    //orderWrapperObj.orderShipDate = orderobj.NATT_Ship_Date__c;
                    orderWrapperObj.orderItem = storeOrderItem(orderObj.orderitems);
                    DraftOrderLst.add(orderWrapperObj);
                    OrderandOrdItem.add(orderObj);  //13/0
                }
            }
            if(!OrderandOrdItem.isempty()){	
                update OrderandOrdItem;         //13/10 Sent to SAP flag is updated on Order.
            }
            return DraftOrderLst;
        }catch(Exception ex){
            ctbrUtility.LogException(ex, 'ctbrgetOrderandOrdItem', 'getOrderandOrdItem');
            return null;
        }
    }
    
	public static List<OrdItemWrapper> storeOrderItem(List<OrderItem> lstOrderItem){
		List<OrdItemWrapper> ordItmList = new List<OrdItemWrapper>();
		for(OrderItem  OrderItemObj: lstOrderItem){
			OrdItemWrapper OrdItemWrapperObj = new OrdItemWrapper();
			OrdItemWrapperObj.orderItemExternalId = OrderItemObj.id;
			OrdItemWrapperObj.productId = OrderItemObj.Product2Id;
			OrdItemWrapperObj.productName = OrderItemObj.NATT_Product_Name__c;
			OrdItemWrapperObj.orderItemNumber= OrderItemObj.OrderItemNumber;
			OrdItemWrapperObj.quantity = OrderItemObj.Quantity;
            OrdItemWrapperObj.partNumber = OrderItemObj.Part_Number__c;
			OrdItemWrapperObj.unitPrice = OrderItemObj.UnitPrice;
            OrdItemWrapperObj.listPrice = OrderItemObj.ListPrice;
			OrdItemWrapperObj.totalPrice = OrderItemObj.TotalPrice;
        //    OrdItemWrapperObj.sapItemStatus = OrderItemObj.CTBR_SapItemStatus__c;
            OrdItemWrapperObj.purchaseNumber = OrderItemObj.Purchase_Order_Number__c;
          //OrdItemWrapperObj.unitOfMeasurement = OrderItemObj.NATT_QuantityUOM__c;
            ordItmList.add(OrdItemWrapperObj);
		}
		return ordItmList; 
    }
    
    // this method is used to update all the CTBR Orders records sent from SAP (this can be reused for updating Parts Orders)
   /* @HttpPut
    global static string updateOrder(List<putOrderWpr> sapOrderLst){
        try{ 
            List<Order> orderLst = new List<Order>();
        	List<OrderItem> orderLineItemsLst = new List<OrderItem>();
            if(sapOrderLst !=null && !sapOrderLst.isempty()){
                if(sapOrderLst.size() > 300){
                    return 'Too many Orders in Request: ' +sapOrderLst.size()+', please limit the Batch size to 300 Orders';
                }
                for(putOrderWpr OrderWrapperObj : sapOrderLst) {
                    Order ordertoUpdate = new Order();
                    //ordertoupdate.NATT_Ship_Date__c = orderwrapperobj.orderShipDate;
                    
                    ordertoUpdate.id = OrderWrapperObj.OrderExternalId;
                    ordertoUpdate.Status = OrderWrapperObj.OrderStatus;
                    if(OrderWrapperObj.freightPrice != null){
                    	ordertoUpdate.CTBR_FreightPrice__c = OrderWrapperObj.freightPrice;
                    }
                    if(OrderWrapperObj.salesordNumber != null)// 9/11
                    {
                        ordertoUpdate.NATT_JDE_Sales_Order_Number__c = OrderWrapperObj.salesordNumber;
                    }
                    if(OrderWrapperObj.sapQuoteId != null)// 9/11
                    {
                        ordertoUpdate.CTBR_SapQuoteId__c = OrderWrapperObj.sapQuoteId;
                    }
                    if(OrderWrapperObj.salesordDraftNumber != null)// 7/11
                    {
                        ordertoUpdate.CTBR_Sales_Order_Draft_Number__c = OrderWrapperObj.salesordDraftNumber;
                    }
                    if(OrderWrapperObj.subtotalICMS != null){
                    	ordertoUpdate.CTBR_SubtotalICMS__c = OrderWrapperObj.subtotalICMS;
                    }
                    if(OrderWrapperObj.totalICMS != null){
                    	ordertoUpdate.CTBR_TotalICMS__c = OrderWrapperObj.totalICMS;
                    }
                    if(OrderWrapperObj.totalICMSST != null){
                    	ordertoUpdate.CTBR_TotalICMSST__c = OrderWrapperObj.totalICMSST;
                    }
                    if(OrderWrapperObj.totalIPI != null){
                    	ordertoUpdate.CTBR_TotalIPI__c = OrderWrapperObj.totalIPI;
                    }
                    if(OrderWrapperObj.totalPayable != null){
                    	ordertoUpdate.CTBR_TotalPayable__c = OrderWrapperObj.totalPayable;
                    }
                    if(OrderWrapperObj.approvalComments != null){
                    	ordertoupdate.NATT_Approval_Comments__c = OrderWrapperObj.approvalComments;  //19/10
                    }
                    if(OrderWrapperObj.deliverydate != null){
                    	ordertoupdate.CTBR_Delivery_Date__c = OrderWrapperObj.deliverydate; //19/10
                    }
                    if(OrderWrapperObj.billToLocation != null){
                    	ordertoupdate.CTBR_BillToLocation__c = OrderWrapperObj.billToLocation; //19/10
                    }
                    if(OrderWrapperObj.shipToLocation != null){
                    	ordertoupdate.CTBR_ShipToLocation__c = OrderWrapperObj.shipToLocation; //19/10
                    }
                    
                    //OrderItem List
                    for(putOrdItemWrapper OrderItemWrpObj: OrderWrapperObj.orderItemLst){
                        OrderItem ordItemObj = new OrderItem();
                        ordItemObj.CTBR_SapItemStatus__c = OrderItemWrpObj.sapItemStatus;
                        ordItemObj.id = OrderItemWrpObj.OrderItemExternalId;
                        if(OrderItemWrpObj.freightPrice != null){
                        	ordItemObj.CTBR_FreightPrice__c = OrderItemWrpObj.freightPrice;
                        }
                        if(OrderItemWrpObj.subtotalICMS != null){
                        	ordItemObj.CTBR_SubtotalICMS__c = OrderItemWrpObj.subtotalICMS;
                        }
                        if(OrderItemWrpObj.totalICMS != null){
                        	ordItemObj.CTBR_TotalICMS__c = OrderItemWrpObj.totalICMS;
                        }
                        if(OrderItemWrpObj.totalICMSST != null){
                        	ordItemObj.CTBR_TotalICMSST__c = OrderItemWrpObj.totalICMSST;
                        }
                        if(OrderItemWrpObj.totalIPI != null){
                        	ordItemObj.CTBR_TotalIPI__c = OrderItemWrpObj.totalIPI;
                        }
                        if(OrderItemWrpObj.totalPayable != null){
                        	ordItemObj.CTBR_TotalPayable__c = OrderItemWrpObj.totalPayable;
                        }
                       if(OrderItemWrpObj.fixedPayment != null){
                        	ordItemObj.CTBR_FixedPayment__c = OrderItemWrpObj.fixedPayment;
                        }
                        if(OrderItemWrpObj.taxation != null){
                        	ordItemObj.CTBR_Taxation__c = OrderItemWrpObj.taxation;
                        }
                        if(OrderItemWrpObj.globalpriceLstcode != null){
                        	ordItemObj.CTBR_Global_Price_List_Code__c = OrderItemWrpObj.globalpriceLstcode;
                        }
                        if(OrderItemWrpObj.hasGlobalPriceLst != null){
                        	ordItemObj.CTBR_Has_Global_Price_List__c = OrderItemWrpObj.hasGlobalPriceLst;
                        }
                        if(OrderItemWrpObj.paymentconditionCode != null){
                        	ordItemObj.CTBR_Payment_Condition_Code__c = OrderItemWrpObj.paymentconditionCode;
                        }
                        if(OrderItemWrpObj.quantity !=null)//7/11
                        {
                            ordItemObj.Quantity = OrderItemWrpObj.quantity;
                        }
                        if(OrderItemWrpObj.quantityAvailable !=null)//7/11
                        {
                            ordItemObj.CTBR_QuantityAvailable__c = OrderItemWrpObj.quantityAvailable;
                        }
                        orderLineItemsLst.add(ordItemObj);
                    }
                    orderLst.add(orderToUpdate);
                    // OrderWrapperObj.Response = 'Success';  //17/10
                }  
                Database.SaveResult[] orderResultLst = Database.update(orderLst, false);
                Database.SaveResult[] orderItemResultLst = Database.update(orderLineItemsLst,false);
                System.debug('resultLst&&&&' + orderResultLst); 
            }
            return 'All Orders successfully updated'; 
        }catch(Exception ex){
            ctbrUtility.LogException(ex, 'ctbrOrderInboundIntegration_Parts', 'updateOrder');
            return 'Error in updating Orders: '+ex.getMessage() + ' : ' +ex.getStackTraceString();
        }
    }*/
    
    public static string dateformat(DateTime crDate){
        DateTime currentDate = (DateTime)crDate;
		//Date currentDate = myDateTime.date();
        //currentDate = date.newinstance(currentDate.month(), currentDate.day(), currentDate.year());
        string returnDate = currentDate.month()+'/'+currentDate.day()+'/'+currentDate.year();
        return returnDate;
    }
    /*
    global class putOrderWpr{
        public string OrderExternalId;
        public String OrderStatus;
        public String SAPOrderStatus;// this will contain plain text like Approved Sales Order.
        public integer salesordDraftNumber;//7/11
        public integer sapQuoteId;//9/11.
        public string salesordNumber;//11/9
        public decimal freightPrice;
        public decimal subtotalICMS;
        public decimal totalICMS;
        public decimal totalIPI;
        public decimal totalICMSST;
        public decimal totalPayable;
        public string approvalComments;  
        public date deliverydate; 
        public string billToLocation;
        public string shipToLocation;
        public List<putOrdItemWrapper> orderItemLst;
    }
    
    global class putOrdItemWrapper{
        public string OrderItemExternalId;
        public string OrderNumber;
        public string sapItemStatus;
        public string SAPQuoteId;
        public decimal freightPrice;
        public decimal subtotalICMS;
        public decimal totalICMS;
        public decimal totalIPI;
        public decimal totalICMSST;
        public decimal totalPayable;
        public decimal fixedPayment;
        public decimal taxation;
        public integer globalpriceLstcode;
        public boolean hasGlobalPriceLst;
        public integer paymentconditionCode;
        public decimal quantityAvailable;
        public decimal quantity;//7/11
        
        //public List<OrdItemWrapper> orderItem;
        //	 public date OrderShipDate;
        //   public double OrderAmount;
        //   public boolean SenttoSAP;  //13/10
    }*/
    
    global class GetOrderWrapper{       //Wrapper class just for the GET Request.
        public string OrderExternalId;
        public string OrderNumber;
        public string BillToLocation;//8/12 returns JDE Address Id of Bill to location selected
        public string ShipToLocation;//8/12 returns JDE Address Id of Ship to location selected
        public String Status;
        public String ShipmentMethod;
        public String ShipmentCompany;// Added 2/13. 
        public string createdDate; 
        public string taxObservation;
        public string paymentTerms;
        public string dealerComments;
        public string freightTerms;
        public string freightPayment;//added 2/13.
        public List<OrdItemWrapper> orderItem;
        //	public date OrderShipDate;
        //  public boolean SenttoSAP;  //13/10
    }
    
    global class OrdItemWrapper{
    //    public string sapItemStatus;
        public String orderItemExternalId;
		public string productId;
		public string productName; 
		public string orderItemNumber;
		public double unitPrice;
		public decimal quantity;
		public double totalPrice;
        public double listPrice;
        public string partNumber;
        public string purchaseNumber;
      //public string unitOfMeasurement;
    }
    
    global class ResponseSummary{
        //List of custom attributes that we want to check the status of the org
    }
}