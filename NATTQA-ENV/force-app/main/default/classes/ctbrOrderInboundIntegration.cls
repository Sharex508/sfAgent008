/*Author: LTI
* Created Date: 13th October 2022
* Class Name: ctbrOrderInboundIntegration
* Description: This class is used to send CTBR Units Orders from salesforce via GET , Update Salesforce via PUT.
* Last modified Date - 19/10/2022 - Dharani 
*/
@RestResource(urlMapping='/retrieveOrders/*')
global without sharing class ctbrOrderInboundIntegration {
    // this method is used to fetch all the CTBR Orders records requested from SAP
    @HttpGet
    global static List<OrderWrapper> getOrderandQuote() {
        try{
            List<Order> OrderandQuote = new List<Order>();
            List<OrderWrapper> DraftOrderLst = new List<OrderWrapper>();
            List<Order> getOrderRec = [SELECT id,recordtype.name,Sent_to_SAP__c,Status,ordernumber,NATT_Ship_Date__c,CreatedDate,SBQQ__Quote__c FROM Order WHERE recordtype.name = 'CTBR Units Order' AND Status = 'Activated'];  // changed to Status = Activated 10/11..AND Sent_to_SAP__c = FALSE..temp commenting.
            for(Order orderobj : getOrderRec){
                OrderWrapper orderWrapperObj = new OrderWrapper();
                orderWrapperObj.status = orderObj.Status;
                //orderWrapperObj.orderShipDate = orderobj.NATT_Ship_Date__c;
                orderWrapperObj.createdDate = dateformat(orderobj.CreatedDate); //19/10
                orderWrapperObj.orderexternalid = orderObj.id;
                orderWrapperObj.QuoteId = orderobj.SBQQ__Quote__c;
                orderObj.Sent_to_SAP__c = true; //13/10
                //  orderWrapperObj.orderdate = orderobj.ordereddate;
                //  orderWrapperObj.quote = storeQuote(orderObj.SBQQ__Quote__r);
                DraftOrderLst.add(orderWrapperObj);
                OrderandQuote.add(orderObj);//13/0
            }
            if(!OrderandQuote.isempty()){	
                update OrderandQuote; //13/10 Sent to SAP flag is updated on Order.
            }
            return DraftOrderLst;
        }catch(Exception ex){
            system.debug('getting into catch');
            ctbrUtility.LogException(ex, 'ctbrgetOrderandQuote', 'getOrderandQuote');
            return null;
        }
    }
    
    // this method is used to update all the CTBR Orders records sent from SAP (this can be reused for updating Parts Orders)
    @HttpPut
    global static string updateOrder(List<OrderWrapper> sapOrderLst) {
        try{ 
            if(sapOrderLst !=null && !sapOrderLst.isempty()){
                if(sapOrderLst.size() > 300)
            	{
                	return 'Too many Orders in Request: ' +sapOrderLst.size()+', please limit the Batch size to 300 Orders';
            	}
                List<Order> orderLst = new List<Order>();
                for(OrderWrapper OrderWrapperObj : sapOrderLst) {
                    Order ordertoUpdate = new Order();
                    //ordertoupdate.NATT_Ship_Date__c = orderwrapperobj.orderShipDate;
                    //Adding IF condition for the null check due to JSON structure issues in Order Parts.
                    if(OrderWrapperObj.status != null){       
                    	ordertoUpdate.status = OrderWrapperObj.status;
                    }
                    if(OrderWrapperObj.nattStatus != null)//2/13 to update Parts Order Status from SAP.
                    {
                        ordertoUpdate.NATT_Order_Status__c = OrderWrapperObj.nattStatus;
                    }
                    if(OrderWrapperObj.approvalComments != null){ 
                    	ordertoupdate.NATT_Approval_Comments__c = orderwrapperobj.approvalComments;  //19/10
                    }
                    if(OrderWrapperObj.deliverydate != null){ 
                    	ordertoupdate.CTBR_Delivery_Date__c = orderwrapperobj.deliverydate; //19/10
                    }
                    if(OrderWrapperObj.salesdraftNumber != null){ 
                    	ordertoupdate.CTBR_Sales_Order_Draft_Number__c = orderwrapperobj.salesdraftNumber; //19/10
                    }
                    ordertoUpdate.id = OrderWrapperObj.OrderExternalId;
                    orderLst.add(orderToUpdate);
                    // OrderWrapperObj.Response = 'Success';  //17/10
                }  
                Database.SaveResult[] orderResultLst = Database.update(orderLst, false);
                System.debug('resultLst&&&&' + orderResultLst); 
            }
            return 'All Orders successfully updated'; 
        }catch(Exception ex){
            system.debug('getting into catch');
            ctbrUtility.LogException(ex, 'ctbrOrderInboundIntegration', 'updateOrder');
            return 'Error in updating Orders: '+ex.getMessage() + ' : ' +ex.getStackTraceString();
        }
    }
    
    public static string dateformat(DateTime crDate){
        DateTime currentDate = (DateTime)crDate;
		//Date currentDate = myDateTime.date();
        //currentDate = date.newinstance(currentDate.month(), currentDate.day(), currentDate.year());
        string returnDate = currentDate.format('MM/dd/YYYY');
        return returnDate;
    }
    
    global class orderWrapper {
        public string OrderExternalId;
        public string QuoteId;
        public String Status;
        public string nattStatus;//2/13 for updating Parts Order Status from SAP.
        //public date OrderShipDate;
        public string createdDate; 
        public string approvalComments;  //19/10
        public date deliverydate;  //19/10
        public integer salesdraftNumber;  //19/10
        //   public double OrderAmount;
        //   public List<quoteWrapper> quote;
        //   public boolean SenttoSAP;  //13/10
    }
       
    global class ResponseSummary {
        //List of custom attributes that we want to check the status of the org
    }
}