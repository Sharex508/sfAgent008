public class NattOrderSummaryFormController{
    
    public Order OrderList{get; private set;}
    public Order OriginalOrderList{get; private set;}
    public Order recentOrderList{get; private set;}
    public String createdDate {get;set;}
    public String modifiedDate {get;set;}
    public List<WrapReqShipQtyAndDate> WrapReqShipQtyAndDateList {get;set;}
    //public List<WrapShipQtyAndDate> WrapShipQtyAndDateList {get;set;}
    //public List<WrapShip> wsqs{get;set;}
    public Integer unitQty{get;set;}
    public Decimal listPrice{get;set;}
    public Decimal unitPrice{get;set;}
    public Decimal totalPrice{get;set;}
    public Decimal discPerc{get;set;}
    public Decimal discAmt{get;set;}
    public Decimal custPrice{get;set;}
    
    public Integer totalUnitQtySetter{get;set;}
    public Decimal TotalListPriceSetter{get;set;}
    public Decimal TotalUnitPriceSetter{get;set;}
    public Decimal totalTotalPriceSetter{get;set;}
    public Decimal TotalDiscPercSetter{get;set;}
    public Decimal TotalDiscAmtSetter{get;set;}
    public Decimal TotalCustPriceSetter{get;set;}
    
    public Boolean isDealer{get;set;}
    public String quoteId{get;set;}
    public Decimal quoteDomPrice{get;set;}
    public Boolean isFreight{get;set;}
    public Integer NoOfCols{get;set;}
    public Boolean IsUnitrecordType{get;set;}
    
    public Integer BETotalQty {get;set;}
    public Decimal BEQty {get;set;}
    public Decimal BETotalListPrice {get;set;}
    public Decimal BETotalUnitPrice {get;set;}
    public Decimal BETotalTotalPrice {get;set;}
    public Decimal BEListPrice {get;set;}
    public Decimal BEUnitPrice {get;set;}
    public Decimal BETotalPrice {get;set;}
    public Decimal BECustPrice {get;set;}
    public Decimal BETotalCustPrice {get;set;}
    public Decimal BETotalDiscRate {get;set;}
    public Decimal BETotalDiscAmt {get;set;}
    
    public String Approver1 {get;set;}
    public String Aprvd1 {get;set;}
    public String ApprovalDate1 {get;set;}
    
    public String Approver2 {get;set;}
    public String Aprvd2 {get;set;}
    public String ApprovalDate2 {get;set;}
    
    public String Approver3 {get;set;}
    public String Aprvd3 {get;set;}
    public String ApprovalDate3 {get;set;}
    
    public String Approver4 {get;set;}
    public String Aprvd4 {get;set;}
    public String ApprovalDate4 {get;set;}
    
    public String Approver5 {get;set;}
    public String Aprvd5 {get;set;}
    public String ApprovalDate5 {get;set;}
    
    public String Approver6 {get;set;}
    public String Aprvd6 {get;set;}
    public String ApprovalDate6 {get;set;}
    
    public String FinalApprovalDate {get;set;}
    public String SalesRep{get;set;}
    public String ApprovalStatus{get;set;}
    
    public String bluEdgeId{get;set;}
    public Date bluEdgeExpDate{get;set;}
    
    public List<Dealer_Override__c> domDealers{get;set;}
    public List<WrapFieldHistory> QuoteFldHistory{get;set;}
    
    public List<WrapComments> DealerComments{get;set;}
    public List<WrapComments> MFDIComments{get;set;}
    public List<WrapComments> InternalComments{get;set;}
    public List<WrapComments> InternalDiscussion{get;set;}
    public List<WrapComments> ChangeOrder{get;set;}
    public List<WrapComments> ChangeOrderComments{get;set;}
    public List<WrapComments> ApprovalComments{get;set;}
    
    
    public List<WrapStandardOrderItems> WrapStandardOptions {get;set;}
    public List<WrapStandardOrderItems> WrapStandardOptionsTotal {get;set;}
    
    // Lynx Fleet
    public List<WrapLynxFleetOrderItems> WrapLynxFleets {get;set;}
    public List<WrapLynxFleetOrderItems> WrapLynxFleetsTotals {get;set;}

    
    public List<WrapOrderItems> WrapNonStandardOptions {get;set;}
    public List<WrapOrderItems> WrapNonStandardOptionsTotal {get;set;}
    
    public List<WrapSpecialOptions> WrapSpecialOptions{get;set;}
    public List<WrapSpecialOptions> WrapSpecialOptionsTotal{get;set;}
    
    public List<WrapOtherOptions> WrapOtherOptions{get;set;}
    public List<WrapOtherOptions> WrapOtherOptionsTotal{get;set;}
    
    public List<WrapOrderItems> DealerInvoiceDetails {get;set;}
    public decimal allOrderItemsDiscRateSum {get;set;}
    
    public List<WrapOrderSummary> orderSummaryList{get;set;}
    public List<NATT_Change_Log__c> lstRSDChangeLogs{get;set;}
    
    public static List<Integer> listofQtys=new List<Integer>();
    
    public NattOrderSummaryFormController(ApexPages.StandardController controller){
        OrderList = [SELECT Id, Name, BillingCountry, BillingPostalCode, BillingState, BillingCity, BillingStreet,
                     ShippingCountry, ShippingPostalCode, ShippingState, ShippingCity, ShippingStreet,LastModifiedDate,CreatedDate,NATT_Configured_Unit_Code__c,
                     OriginalOrderId,NATT_Original_Order__c,NATT_Original_Order_Id__c, NATT_Unit__c ,RecordType.name 
                     FROM Order WHERE Id =:controller.getId() LIMIT 1
                    ]; 
        
        Id OrderId = controller.getId();
        String originalOrderId;
        String orderRecentUnit;
        IsUnitrecordType = false;
        NoOfCols = 1;
        system.debug('OrderList.RecordType.name-'+ OrderList.RecordType.name);
        if(OrderList.RecordType.name == 'NATT Units Order'){
            IsUnitrecordType = true;
            NoOfCols = 2;
        }
        
        
        originalOrderId = OrderList.NATT_Original_Order_Id__c ;
        system.debug('Original Id2===>'+originalOrderId);
        //}
        lstRSDChangeLogs = new List<NATT_Change_Log__c>();
        originalOrderId = OrderList.NATT_Original_Order_Id__c ;
        Map<String, String> monthsMap = new Map<String, String>{
            'January'  => '1',
                'February' => '2',
                'March' => '3',
                'April' => '4',
                'May' => '5',
                'June' => '6',
                'July' => '7',
                'August' => '8',
                'September' => '9',
                'October' => '10',
                'November' => '11',
                'December' => '12'
                };
                    for(NATT_Change_Log__c cl : [SELECT Id, NATT_Unit__c, NATT_Original_Value__c, NATT_New_Value__c, NATT_Order__r.NATT_Original_Order_Id__c
                                                 FROM NATT_Change_Log__c 
                                                 WHERE NATT_Order__r.NATT_Original_Order_Id__c =: originalOrderId AND NATT_Change_Type__c = 'Requested Ship Date Change'
                                                 ORDER BY CreatedDate DESC]){
                                                     if (cl.NATT_Order__r.NATT_Original_Order_Id__c == originalOrderId) {

                            // Updated the logic for US - 3240 AC-Point no 4
                            if (String.isNotBlank(cl.NATT_Original_Value__c)) {
                                List<String> oValueList = cl.NATT_Original_Value__c.split(' ');
                                if (oValueList.size() >= 3) {
                                    String oValueMonth = monthsMap.get(oValueList[0]);
                                    cl.NATT_Original_Value__c = oValueMonth + '/' + 
                                                                oValueList[1].removeEnd(',') + '/' + 
                                                                oValueList[2];
                                }
                            }
                        
                            // Updated the logic for US - 3240 AC-Point no 4
                            if (String.isNotBlank(cl.NATT_New_Value__c)) {
                                List<String> nValueList = cl.NATT_New_Value__c.split(' ');
                                if (nValueList.size() >= 3) {
                                    String nValueMonth = monthsMap.get(nValueList[0]);
                                    cl.NATT_New_Value__c = nValueMonth + '/' + 
                                                           nValueList[1].removeEnd(',') + '/' + 
                                                           nValueList[2];
                                }
                            }
                        
                            lstRSDChangeLogs.add(cl);
                        }
                                                 }
        OriginalOrderList = [SELECT Id, Name, BillingCountry, BillingPostalCode, BillingState, BillingCity, BillingStreet,
                             ShippingCountry, ShippingPostalCode, ShippingState, ShippingCity, ShippingStreet,LastModifiedDate,CreatedDate,NATT_Configured_Unit_Code__c,
                             OriginalOrderId,NATT_Original_Order__c,NATT_Original_Order_Id__c,NATT_Shipping_Address__r.NATT_JDE_Alpha_Name__c,NATT_Market_Segment2__c,NATT_JDE_Sales_Order_Number__c,
                             NATT_Purchase_Order__c,NATT_Shipment_Method__c, SBQQ__Quote__c, SBQQ__Quote__r.NATT_Override_Credit_Amount_Total__c, Is_Direct_Sales__c
                             FROM Order WHERE Id =:originalOrderId
                            ]; 
        
        DateTime createdDt = OriginalOrderList.CreatedDate;
        String monthCreated = String.valueOf(OriginalOrderList.CreatedDate.month());
        String yearCreated = String.valueOf(OriginalOrderList.CreatedDate.year());
        String dayCreated = String.valueOf(OriginalOrderList.CreatedDate.day());
        createdDate = monthCreated+'/'+dayCreated+'/'+yearCreated;
        
        Order getLatestOrder = new Order();
        for(Order order : [Select Id,SBQQ__Quote__c,NATT_Original_Order_Id__c, Name, BillingCountry, BillingPostalCode, BillingState, BillingCity, BillingStreet,
                           ShippingCountry, ShippingPostalCode, ShippingState, ShippingCity, ShippingStreet,LastModifiedDate,CreatedDate,NATT_Configured_Unit_Code__c,
                           OriginalOrderId,NATT_Original_Order__c,Owner.Email, SBQQ__Quote__r.SBQQ__PrimaryContact__r.Email, SBQQ__Quote__r.SBQQ__PrimaryContact__r.Phone,
                           Account.Name,Account.Phone,Account.WOD_2_Email__c,NATT_End_Customer__c,NATT_Market_Segment2__c,
                           NATT_Dealer_AR_Code__c,Account.NATT_AR_Code_JDE_AR_Code__c,NATT_Purchase_Order__c,NATT_JDE_Sales_Order_Number__c,
                           NATT_Shipment_Method__c,NATT_Shipping_Address__r.NATT_JDE_Alpha_Name__c, NATT_Unit__c, NATT_Standard_Features__c, 
                           SBQQ__Quote__r.NATT_Override_Credit_Amount_Total__c, Is_Direct_Sales__c, SBQQ__Quote__r.NATT_Has_Freight__c
                           From Order 
                           Where NATT_Original_Order_Id__c=:OriginalOrderId order by createddate ASC]){
                               if(order.NATT_Original_Order_Id__c.equals(OriginalOrderId)){
                                   getLatestOrder = order;
                                   recentOrderList = order;
                               }
                           }
        orderRecentUnit = recentOrderList.NATT_Unit__c ;
        quoteId = OriginalOrderList.SBQQ__Quote__c;
        quoteDomPrice = OriginalOrderList.SBQQ__Quote__r.NATT_Override_Credit_Amount_Total__c;
        isDealer = OriginalOrderList.Is_Direct_Sales__c;        
        isFreight = recentOrderList.SBQQ__Quote__r.NATT_Has_Freight__c;
        
        DateTime modifiedDt =recentOrderList.LastModifiedDate;
        String month = String.valueOf(recentOrderList.LastModifiedDate.month());
        String year = String.valueOf(recentOrderList.LastModifiedDate.year());
        String day = String.valueOf(recentOrderList.LastModifiedDate.day());
        modifiedDate = month+'/'+day+'/'+year;
        
        totalUnitQtySetter=0;
        totalListPriceSetter=0;
        totalUnitPriceSetter=0;
        totalTotalPriceSetter=0;
        totalDiscPercSetter=0;
        totalDiscAmtSetter=0;
        totalCustPriceSetter=0.0;
        allOrderItemsDiscRateSum=0.0;
        custPrice=0.0;
        
        displayOptions(originalOrderId, orderRecentUnit);
        displayBlueEdgeLines(originalOrderId, orderRecentUnit);
        
        displayQuoteApprovers(originalOrderId,getLatestOrder);
        displayQuoteHistory(originalOrderId,getLatestOrder);
        displayComments(originalOrderId);
        displayCompleteOrderSummary(originalOrderId);
        
        processReqQtyDateForOriginalOrder1(originalOrderId, orderRecentUnit); 
        //processShipQtyDateForOriginalOrder2(originalOrderId);
        
        unitQty = calculateTotalUnitQty(listofQtys,originalOrderId, orderRecentUnit);
        
        //boolean checkReqShipQtyandDate=WrapReqShipQtyAndDateList.isEmpty();
        
        totalUnitQtySetter=null;
        totalListPriceSetter=totalListPriceSetter+listPrice;
        totalUnitPriceSetter=totalUnitPriceSetter+unitPrice;
        totalTotalPriceSetter=totalTotalPriceSetter+totalPrice;
        //TotalDiscPercSetter=(allOrderItemsDiscRateSum + discPerc)/(decimal)(listSize1 + listSize2 +listSize3);
        //TotalDiscPercSetter=null;
        
        totalDiscAmtSetter=(TotalDiscAmtSetter != null && discAmt != null) ? (TotalDiscAmtSetter + discAmt) : 0;
        totalDiscPercSetter=(TotalDiscAmtSetter/TotalListPriceSetter)*100;
        totalCustPriceSetter=(TotalCustPriceSetter == null ? 0 : TotalCustPriceSetter) +(custPrice == null ? 0 : custPrice) ;
        
        domDealers = [Select Id, Quote__c, Dealer__r.Name, Quote__r.NATT_Override_Credit_Amount_Total__c, Override_Credit_Amount__c from Dealer_Override__c where Quote__c =: quoteId];
        if(domDealers.size()>0){
            Decimal TotalDealerOverride=domDealers[0].Quote__r.NATT_Override_Credit_Amount_Total__c;
            totalListPriceSetter+=TotalDealerOverride;
            totalUnitPriceSetter+=TotalDealerOverride;
            totalTotalPriceSetter+=TotalDealerOverride;
        }    
    }
    
    public void processReqQtyDateForOriginalOrder1(String originalOrderId, String orderRecentUnit){
        WrapReqShipQtyAndDateList = new list<WrapReqShipQtyAndDate>();
        list<Order> amendedOrderList= [select Id from order where NATT_Original_Order__c=:originalOrderId];
        list<OrderItem> allAmendedOrderItems=[Select Id,NATT_Unit_Name__c, NATT_Requested_Ship_Date__c,NATT_Scheduled_Pick_Date__c,NATT_Ship_Date__c,
                                              SBQQ__QuotedQuantity__c,SBQQ__RevisedOrderProduct__c, Order.Scheduled_Pick_Date__c
                                              from OrderItem 
                                              where OrderId in:amendedOrderList 
                                              and NATT_Is_Base_Unit__c=true AND NATT_Unit_Name__c =: orderRecentUnit 
                                              Order By NATT_Requested_Ship_Date__c
                                              //and NATT_Ship_Date__c=null
                                             ];
        system.debug('allAmendedOrderItems==>'+allAmendedOrderItems);
        
        list<Id> amendedOrderItemsIdsToRemove=new list<Id>();
        list<OrderItem> OriginalOrderItems=[Select Id,NATT_Requested_Ship_Date__c,NATT_Scheduled_Pick_Date__c,NATT_Ship_Date__c,
                                            SBQQ__QuotedQuantity__c,Order.Scheduled_Pick_Date__c 
                                            from OrderItem 
                                            where OrderId=:originalOrderId 
                                            and NATT_Is_Base_Unit__c=true Order By NATT_Requested_Ship_Date__c
                                            //and NATT_Ship_Date__c=null
                                           ];
        system.debug('OriginalOrderItems==>'+OriginalOrderItems);
        
        for(OrderItem OrgItm:OriginalOrderItems){
            list<OrderItem> amnededOrderItm=[Select Id,NATT_Requested_Ship_Date__c,NATT_Scheduled_Pick_Date__c,NATT_Ship_Date__c,
                                             SBQQ__QuotedQuantity__c,SBQQ__RevisedOrderProduct__c,Order.Scheduled_Pick_Date__c
                                             from OrderItem where SBQQ__RevisedOrderProduct__c=:OrgItm.Id];
            system.Debug('amnededOrderItm for originalItm==>'+OrgItm.Id+'===>'+amnededOrderItm);
            if(!amnededOrderItm.isEmpty()){
                Integer qty=0;
                
                system.debug('OrgItm==>'+OrgItm.id);
                
                
                String ReqDate=formatDate(OrgItm.NATT_Requested_Ship_Date__c);
                String schDate=formatDate(OrgItm.Order.Scheduled_Pick_Date__c);
                
                for(OrderItem amdItm:amnededOrderItm){
                    system.debug('amdItm==> '+amdItm.id+'Qty==> '+amdItm.SBQQ__QuotedQuantity__c);
                    qty+=qty + Integer.valueOf(amdItm.SBQQ__QuotedQuantity__c);
                    system.debug('Qty1==>'+qty+'==>amdItm'+amdItm.id);
                    amendedOrderItemsIdsToRemove.add(amdItm.Id);
                }
                qty=qty+Integer.valueOf(OrgItm.SBQQ__QuotedQuantity__c);
                system.debug('Final Qty==>'+qty);
                if(qty != 0){
                    WrapReqShipQtyAndDateList.add(new WrapReqShipQtyAndDate(qty,ReqDate,schDate));
                }   
            }
            else{
                system.debug('Insdide else');
                if(Integer.valueOf(OrgItm.SBQQ__QuotedQuantity__c) != 0){
                    String ReqDate=formatDate(OrgItm.NATT_Requested_Ship_Date__c);
                    String schDate= formatDate(OrgItm.Order.Scheduled_Pick_Date__c);
                    WrapReqShipQtyAndDateList.add(new WrapReqShipQtyAndDate(Integer.valueOf(OrgItm.SBQQ__QuotedQuantity__c),ReqDate,schDate));
                }  
            }
        }
        
        list<OrderItem>FinalAmdLIst=new list<OrderItem>();
        
        for(OrderItem amdItm:allAmendedOrderItems){
            if(!amendedOrderItemsIdsToRemove.contains(amdItm.Id)){
                FinalAmdLIst.add(amdItm); 
            }
        }
        
        set<Id> repeatingIdsToExclude=new set<Id>();
        for(OrderItem finalAmdItmsToCheck:FinalAmdLIst){
            
            if(!repeatingIdsToExclude.contains(finalAmdItmsToCheck.Id)){
                list<OrderItem> amnededOrderItm=[Select Id,NATT_Requested_Ship_Date__c,NATT_Scheduled_Pick_Date__c,NATT_Ship_Date__c,
                                                 SBQQ__QuotedQuantity__c,SBQQ__RevisedOrderProduct__c,Order.Scheduled_Pick_Date__c
                                                 from OrderItem where SBQQ__RevisedOrderProduct__c=:finalAmdItmsToCheck.id];
                if(!amnededOrderItm.isEmpty()){
                    Integer qty=Integer.valueOf(finalAmdItmsToCheck.SBQQ__QuotedQuantity__c);
                    
                    String ReqDate=formatDate(finalAmdItmsToCheck.NATT_Requested_Ship_Date__c);
                	String schDate=formatDate(finalAmdItmsToCheck.Order.Scheduled_Pick_Date__c);
                    for(OrderItem amdItm:amnededOrderItm){
                        qty+=qty + Integer.valueOf(amdItm.SBQQ__QuotedQuantity__c);
                        repeatingIdsToExclude.add(amdItm.Id);
                    }
                    WrapReqShipQtyAndDateList.add(new WrapReqShipQtyAndDate(qty,ReqDate,schDate)); 
                }
                else{    
                    String ReqDate=formatDate(finalAmdItmsToCheck.NATT_Requested_Ship_Date__c);
                    String schDate=formatDate(finalAmdItmsToCheck.Order.Scheduled_Pick_Date__c);
                    WrapReqShipQtyAndDateList.add(new WrapReqShipQtyAndDate(Integer.valueOf(finalAmdItmsToCheck.SBQQ__QuotedQuantity__c),ReqDate,schDate));   
                }
            }     
        }
        system.debug('WrapReqShipQtyAndDateList==>'+WrapReqShipQtyAndDateList);  
    }
    /*
public void processShipQtyDateForOriginalOrder2(String originalOrderId){

WrapShipQtyAndDateList=new list<WrapShipQtyAndDate>();
wsqs=new list<WrapShip>();

list<Order> amendedOrderList= [select Id from order where NATT_Original_Order__c=:originalOrderId];

list<OrderItem> allAmendedOrderItems=[Select Id,NATT_Requested_Ship_Date__c,NATT_Scheduled_Pick_Date__c,NATT_Ship_Date__c,SBQQ__QuotedQuantity__c,SBQQ__RevisedOrderProduct__c 
from OrderItem 
where OrderId in:amendedOrderList 
and NATT_Is_Base_Unit__c = true 
and NATT_Scheduled_Pick_Date__c <> null 
Order By NATT_Scheduled_Pick_Date__c
]; 
//and NATT_Requested_Ship_Date__c=null];
system.debug('allAmendedOrderItems==>'+allAmendedOrderItems);

list<Id> amendedOrderItemsIdsToRemove=new list<Id>();

list<OrderItem> OriginalOrderItems=[Select Id,NATT_Requested_Ship_Date__c,NATT_Scheduled_Pick_Date__c,NATT_Ship_Date__c,SBQQ__QuotedQuantity__c 
from OrderItem 
where OrderId=:originalOrderId 
and NATT_Is_Base_Unit__c = true
and NATT_Scheduled_Pick_Date__c <> null 
Order By NATT_Scheduled_Pick_Date__c
];
//and NATT_Ship_Date__c <> null];
//and NATT_Requested_Ship_Date__c=null];
system.debug('OriginalOrderItems==>'+OriginalOrderItems);

for(OrderItem OrgItm:OriginalOrderItems){
list<OrderItem> amnededOrderItm=[Select Id,NATT_Requested_Ship_Date__c,NATT_Scheduled_Pick_Date__c,NATT_Ship_Date__c,SBQQ__QuotedQuantity__c,SBQQ__RevisedOrderProduct__c
from OrderItem 
where SBQQ__RevisedOrderProduct__c=:OrgItm.Id 
and NATT_Scheduled_Pick_Date__c <> null
];
system.Debug('amnededOrderItm for originalItm==>'+OrgItm.Id+'===>'+amnededOrderItm);
if(!amnededOrderItm.isEmpty()){
Integer qty=0;

system.debug('OrgItm==>'+OrgItm.id);


//String ReqDate=formatDate(OrgItm.NATT_Scheduled_Pick_Date__c);

for(OrderItem amdItm:amnededOrderItm){
system.debug('amdItm==> '+amdItm.id+'Qty==> '+amdItm.SBQQ__QuotedQuantity__c);
qty+=qty + Integer.valueOf(amdItm.SBQQ__QuotedQuantity__c);
system.debug('Qty1==>'+qty+'==>amdItm'+amdItm.id);
amendedOrderItemsIdsToRemove.add(amdItm.Id);
}
qty=qty+ Integer.valueOf(OrgItm.SBQQ__QuotedQuantity__c);
system.debug('Final Qty==>'+qty);
//WrapShipQtyAndDateList.add(new WrapShipQtyAndDate(qty,ReqDate));
wsqs.add(new WrapShip(qty,ReqDate));
}
else{
if(OrgItm.NATT_Scheduled_Pick_Date__c!=null)//level 1 order items
{
system.debug('Insdide original items else');

//String ReqDate=formatDate(OrgItm.NATT_Scheduled_Pick_Date__c);
system.debug('OrgItm.SBQQ__QuotedQuantity__c==>'+OrgItm.SBQQ__QuotedQuantity__c);
decimal quantity= Integer.valueOf(OrgItm.SBQQ__QuotedQuantity__c);
//WrapShipQtyAndDateList.add(new WrapShipQtyAndDate(OrgItm.SBQQ__QuotedQuantity__c,ReqDate));
wsqs.add(new WrapShip(Integer.valueOf(OrgItm.SBQQ__QuotedQuantity__c),ReqDate));
}

}

}

list<OrderItem>FinalAmdLIst=new list<OrderItem>();

for(OrderItem amdItm:allAmendedOrderItems)
{
if(!amendedOrderItemsIdsToRemove.contains(amdItm.Id))
{
FinalAmdLIst.add(amdItm); 
}
}
system.debug('FinalAmdLIst==>'+FinalAmdLIst);
set<Id> repeatingIdsToExclude=new set<Id>();

if(!FinalAmdLIst.isEmpty()){
for(OrderItem finalAmdItmsToCheck:FinalAmdLIst){
system.debug('Inside final amd loop==>');
if(!repeatingIdsToExclude.contains(finalAmdItmsToCheck.Id)){
list<OrderItem> amnededOrderItm=[Select Id,NATT_Requested_Ship_Date__c,NATT_Ship_Date__c,SBQQ__QuotedQuantity__c,SBQQ__RevisedOrderProduct__c
from OrderItem where SBQQ__RevisedOrderProduct__c=:finalAmdItmsToCheck.id];

system.debug('amnededOrderItm123==>'+amnededOrderItm);
if(!amnededOrderItm.isEmpty())
{
Integer qty= Integer.valueOf(finalAmdItmsToCheck.SBQQ__QuotedQuantity__c);

String ReqDate=formatDate(finalAmdItmsToCheck.NATT_Scheduled_Pick_Date__c);

for(OrderItem amdItm:amnededOrderItm)
{
qty+=qty + Integer.valueOf(amdItm.SBQQ__QuotedQuantity__c);
repeatingIdsToExclude.add(amdItm.Id);
}
//WrapShipQtyAndDateList.add(new WrapShipQtyAndDate(qty,ReqDate));
wsqs.add(new WrapShip(qty,ReqDate));
system.debug('Here 1');

}
else
{


String shipDate=formatDate(finalAmdItmsToCheck.NATT_Scheduled_Pick_Date__c);
system.debug('Ship Date==>'+shipDate);
system.debug('finalAmdItmsToCheck.SBQQ__QuotedQuantity__c==>'+finalAmdItmsToCheck.SBQQ__QuotedQuantity__c);
//WrapShipQtyAndDateList.add(new WrapShipQtyAndDate(finalAmdItmsToCheck.SBQQ__QuotedQuantity__c,shipDate));
wsqs.add(new WrapShip(Integer.valueOf(finalAmdItmsToCheck.SBQQ__QuotedQuantity__c),shipDate));   
system.debug('Here 2');
}
} 

}
}
system.debug(' wsqs==>'+wsqs); 
//system.debug('WrapShipQtyAndDateList==>'+WrapShipQtyAndDateList);
} */
    
    public String formatDate(Date dateToFormat){
        if(dateToFormat !=null){
            String month=String.valueOf(dateToFormat.month());
            String year=String.valueOf(dateToFormat.year());
            String day=String.valueOf(dateToFormat.day());
            
            String FormatedDated =month+'/'+day+'/'+year;
            return FormatedDated;
        }
        else return null;   
    }
    
    public Integer calculateTotalUnitQty(list<Integer>listofQtys, String originalOrderId, String orderRecentUnit){
        Integer TotalUnitQty=0;
        system.debug('Inside calculateTotalUnitQty ===>');
        OrderItem recentBaseUnitList = new OrderItem();  
        Boolean runOnce = true;
        for(OrderItem oi :[select id,SBQQ__QuoteLine__r.SBQQ__ListPrice__c,UnitPrice,TotalPrice, SBQQ__QuotedQuantity__c, NATT_Original_Order_Id__c, NATT_End_Customer_Price__c,
                           SBQQ__QuoteLine__r.SBQQ__TotalDiscountRate__c,
                           SBQQ__QuoteLine__r.NATT_Discount_Amount_Per_Unit__c, NATT_Product_Name__c
                           from OrderItem 
                           where NATT_Is_Base_Unit__c=true 
                           and NATT_Original_Order_Id__c=:originalOrderId AND NATT_Unit_Name__c =:orderRecentUnit 
                           ORDER BY createdDate Desc]){
                               if(oi.NATT_Original_Order_Id__c.equals(originalOrderId)){
                                   TotalUnitQty+=integer.valueOf(oi.SBQQ__QuotedQuantity__c);
                                   if(runOnce){
                                       recentBaseUnitList = oi;
                                       system.debug('results of recentBaseUnitList=>'+recentBaseUnitList);
                                       runOnce = false;
                                   }   
                               }
                           }
        listPrice=recentBaseUnitList.SBQQ__QuoteLine__r.SBQQ__ListPrice__c;
        system.debug('results of listPrice=>'+listPrice);
        unitPrice=recentBaseUnitList.UnitPrice;
        system.debug('results of unitPrice11=>'+unitPrice);
        totalPrice=recentBaseUnitList.UnitPrice * TotalUnitQty;
        discPerc=recentBaseUnitList.SBQQ__QuoteLine__r.SBQQ__TotalDiscountRate__c;
        system.debug('results of Disc'+discPerc);
        discAmt=recentBaseUnitList.SBQQ__QuoteLine__r.NATT_Discount_Amount_Per_Unit__c;
        system.debug('results of discAmt1'+discAmt);
        custPrice=recentBaseUnitList.NATT_End_Customer_Price__c;
        system.debug('results of custPrice'+custPrice);
        runOnce = false;
        return TotalUnitQty;
    }
    
    public void displayOptions(String originalOrderId, String orderRecentUnit ){
        List<OrderItem>positiveQtyOrderItems = new  List<OrderItem>();
        if(Test.isRunningTest()){
            positiveQtyOrderItems = [SELECT id,createdDate,Product2.Name,SBQQ__QuoteLine__r.SBQQ__ListPrice__c,SBQQ__QuotedListPrice__c,UnitPrice,TotalPrice,SBQQ__QuotedQuantity__c,NATT_End_Customer_Price__c,
                                     SBQQ__QuoteLine__r.SBQQ__TotalDiscountRate__c,
                                     SBQQ__QuoteLine__r.NATT_Discount_Amount_Per_Unit__c, NATT_Original_Order_Id__c,
                                     SBQQ__QuoteLine__r.NATT_Special_Request_Notes__c,Product2.Id, NATT_Feature_Category__c,
                                     SBQQ__QuoteLine__r.SBQQ__ProductOption__r.NATT_Bundled_Unit_Name__c, NATT_Product_Name__c,Lynx_Fleet_Prepayment_Terms__c
                                     FROM OrderItem 
                                     WHERE NATT_Original_Order_Id__c =: originalOrderId
                                     //AND SBQQ__QuotedQuantity__c > 0
                                     AND NATT_Is_Base_Unit__c=false
                                    ];
        }
        else{
            positiveQtyOrderItems = [SELECT id,createdDate,Product2.Name,SBQQ__QuoteLine__r.SBQQ__ListPrice__c,SBQQ__QuotedListPrice__c,UnitPrice,TotalPrice,SBQQ__QuotedQuantity__c,NATT_End_Customer_Price__c,
                                     SBQQ__QuoteLine__r.SBQQ__TotalDiscountRate__c,
                                     SBQQ__QuoteLine__r.NATT_Discount_Amount_Per_Unit__c, NATT_Original_Order_Id__c,
                                     SBQQ__QuoteLine__r.NATT_Special_Request_Notes__c,Product2.Id, NATT_Feature_Category__c,
                                     SBQQ__QuoteLine__r.SBQQ__ProductOption__r.NATT_Bundled_Unit_Name__c, NATT_Product_Name__c,Lynx_Fleet_Prepayment_Terms__c
                                     FROM OrderItem 
                                     WHERE NATT_Original_Order_Id__c =: originalOrderId 
                                     //AND SBQQ__QuoteLine__r.SBQQ__ProductOption__r.NATT_Bundled_Unit_Name__c =:orderRecentUnit //AND SBQQ__QuotedQuantity__c > 0 
                                     AND NATT_Is_Base_Unit__c=false ORDER BY createdDate DESC
                                    ];
        }
        Map<String, List<Decimal>> mapProductIdtoOrderItemDetails = new Map<String, List<Decimal>>();
        Map<String, String> mapProductIdtoProductName = new Map<String, String>();
        if(positiveQtyOrderItems.size() >0){
            for(OrderItem so : positiveQtyOrderItems){
                if(so.NATT_Original_Order_Id__c.equals(originalOrderId)){
                    String prodId = so.Product2.Id;
                    if(so.NATT_Feature_Category__c == 'Special Options'){
                        prodId = so.Product2.Id + so.SBQQ__QuoteLine__r.NATT_Special_Request_Notes__c;
                        System.debug('XXX: '+ prodId);
                    }
                    if(mapProductIdtoOrderItemDetails.containsKey(prodId)){
                        Decimal totalQty = mapProductIdtoOrderItemDetails.get(prodId).get(1) + so.SBQQ__QuotedQuantity__c;
                        Decimal totalQuotedPrice = mapProductIdtoOrderItemDetails.get(prodId).get(2) + so.TotalPrice;
                        
                        mapProductIdtoOrderItemDetails.get(prodId).set(1, totalQty);
                        mapProductIdtoOrderItemDetails.get(prodId).set(2, totalQuotedPrice);
                        //itearation of the ordersitems few items not considering so adding the condition
                       /*if( so.SBQQ__QuoteLine__r.SBQQ__TotalDiscountRate__c>mapProductIdtoOrderItemDetails.get(prodId).get(5)){
                            mapProductIdtoOrderItemDetails.get(prodId).set(5, so.SBQQ__QuoteLine__r.SBQQ__TotalDiscountRate__c);
                            mapProductIdtoOrderItemDetails.get(prodId).set(6, so.SBQQ__QuoteLine__r.NATT_Discount_Amount_Per_Unit__c);
                            mapProductIdtoOrderItemDetails.get(prodId).set(4, so.UnitPrice);
                        }*/
                        System.debug('IF: '+ prodId);
                    }
                    
                    else{
                        
                        List<Decimal> lstOI = new List<Decimal>();
                        String prodName = '';
                        Decimal featureCat = 0.0;
                        Decimal listPrice = 0.0;
                        Decimal custPrice = 0.0;
                        
                        prodName = so.Product2.Name;
                        listPrice = so.SBQQ__QuoteLine__r.SBQQ__ListPrice__c; 
                        if(so.NATT_Feature_Category__c ==  'Related Options' || so.NATT_Feature_Category__c == 'Standard Sales Options'){
                            featureCat = 10.0;
                        }
                        
                        else if(so.NATT_Feature_Category__c == 'Non-Standard Sales Options'){
                            featureCat = 20.0;
                        }
                        
                        else if(so.NATT_Feature_Category__c == 'Special Options'){
                            prodName = so.Product2.Name + ' - ' + so.SBQQ__QuoteLine__r.NATT_Special_Request_Notes__c;
                            featureCat = 30.0;
                            listPrice = so.SBQQ__QuotedListPrice__c;
                        }
                        // Lynx Fleet 
                         else if(so.NATT_Feature_Category__c == 'Lynx Fleet'){
                           prodName= (so.SBQQ__QuoteLine__r.NATT_Special_Request_Notes__c != null ? so.Product2.Name + ' - ' + so.SBQQ__QuoteLine__r.NATT_Special_Request_Notes__c : so.Product2.Name) + (so.Lynx_Fleet_Prepayment_Terms__c != null ? ' / (Term- ' + so.Lynx_Fleet_Prepayment_Terms__c + ')' : '');
                           // prodName =so.SBQQ__QuoteLine__r.NATT_Special_Request_Notes__c!=null? so.Product2.Name +  ' - ' + so.SBQQ__QuoteLine__r.NATT_Special_Request_Notes__c:so.Product2.Name;
                            featureCat = 50.0;
                            listPrice = so.SBQQ__QuotedListPrice__c;
                        }
                        
                        else if( so.NATT_Product_Name__c == 'FREIGHT-CHARGED'){
                            featureCat = 40.0;
                        }
                        
                        lstOI.add(featureCat); //0
                        lstOI.add(so.SBQQ__QuotedQuantity__c); //1
                        lstOI.add(so.TotalPrice); //2
                        lstOI.add(listPrice); //3
                        lstOI.add(so.UnitPrice); //4
                        lstOI.add(so.SBQQ__QuoteLine__r.SBQQ__TotalDiscountRate__c); //5
                        lstOI.add(so.SBQQ__QuoteLine__r.NATT_Discount_Amount_Per_Unit__c); //6
                        System.debug('lstOI==>'+lstOI);
                        if(so.NATT_End_Customer_Price__c == null){
                            lstOI.add(custPrice); //7
                        }
                        else{
                            lstOI.add(so.NATT_End_Customer_Price__c); //7
                        }
                        
                        mapProductIdtoOrderItemDetails.put(prodId, lstOI);
                        mapProductIdtoProductName.put(prodId, prodName);
                        System.debug('ELSE: '+ prodId);
                    }
                }
                
            }
        }
        System.debug('MapMapMap: ' + mapProductIdtoOrderItemDetails);
        System.debug('MapMapMap111: ' + mapProductIdtoProductName);
        WrapStandardOptions = new list<WrapStandardOrderItems>(); 
        WrapStandardOptionsTotal = new list<WrapStandardOrderItems>();
        WrapNonStandardOptions=new list<WrapOrderItems>();
        WrapNonStandardOptionsTotal=new list<WrapOrderItems>();
        WrapSpecialOptions=new list<WrapSpecialOptions>();
        WrapSpecialOptionsTotal=new list<WrapSpecialOptions>();
        WrapOtherOptions=new list<WrapOtherOptions>();
        WrapOtherOptionsTotal=new list<WrapOtherOptions>();
        // lynx fleet 
        WrapLynxFleets = new List<WrapLynxFleetOrderItems>();
        WrapLynxFleetsTotals = new List<WrapLynxFleetOrderItems>();
        
       
        
        Decimal TotalListPriceSO=0;
        Decimal TotalUnitPriceSO=0;
        Decimal TotalPriceSO=0;
        Decimal TotalDiscRateSO=0;
        Decimal TotalDiscAmtSO=0;
        Decimal discRateAvgSO=0;
        Decimal counterSO=0;
        Decimal TotalCustPriceSO=0;
        
        //Lynx Fleet 
        Decimal TotalListPriceLFSO=0;
        Decimal TotalUnitPriceLFSO=0;
        Decimal TotalPriceLFSO=0;
        Decimal TotalDiscRateLFSO=0;
        Decimal TotalDiscAmtLFSO=0;
        Decimal discRateAvgLFSO=0;
        Decimal counterLFSO=0;
        Decimal TotalCustPriceLFSO=0;
        
        Decimal TotalListPriceNSO=0;
        Decimal TotalUnitPriceNSO=0;
        Decimal TotalPriceNSO=0;
        Decimal TotalDiscRateNSO=0;
        Decimal TotalDiscAmtNSO=0;
        Decimal discRateAvgNSO=0;
        Decimal counterNSO=0;
        Decimal TotalCustPriceNSO=0;
        
        Decimal TotalListPriceSPO=0;
        Decimal TotalUnitPriceSPO=0;
        Decimal TotalPriceSPO=0;
        Decimal TotalDiscRateSPO=0;
        Decimal TotalDiscAmtSPO=0;
        Decimal discRateAvgSPO=0;
        Decimal counterSPO=0;
        Decimal TotalCustPriceSPO=0;

        Decimal TotalListPriceFr=0;
        Decimal TotalUnitPriceFr=0;
        Decimal TotalPriceFr=0;
        Decimal TotalDiscRateFr=0;
        Decimal TotalDiscAmtFr=0;
        Decimal discRateAvgFr=0;
        Decimal counterFr=0;
        Decimal TotalCustPriceFr=0;
        
      
        
        for(String prodId : mapProductIdtoOrderItemDetails.keySet()){
            if(mapProductIdtoOrderItemDetails.get(prodId).get(0) == 10.0){
                if(mapProductIdtoOrderItemDetails.get(prodId).get(1) != 0){
                    TotalListPriceSO += mapProductIdtoOrderItemDetails.get(prodId).get(3); //ListPrice
                    TotalUnitPriceSO += mapProductIdtoOrderItemDetails.get(prodId).get(4); //UnitPrice
                    TotalPriceSO += mapProductIdtoOrderItemDetails.get(prodId).get(2); //TotalPrice
                    TotalCustPriceSO += mapProductIdtoOrderItemDetails.get(prodId).get(7); //NATT_End_Customer_Price__c
                    if(mapProductIdtoOrderItemDetails.get(prodId).get(5) != 0){
                        TotalDiscRateSO += mapProductIdtoOrderItemDetails.get(prodId).get(5); //SBQQ__QuoteLine__r.SBQQ__TotalDiscountRate__c
                        allOrderItemsDiscRateSum += TotalDiscRateSO;
                        counterSO += 1;
                        //discRateAvgSO = (TotalDiscRateSO/(decimal)counterSO).setScale(2);
                        
                    }
                    TotalDiscAmtSO += mapProductIdtoOrderItemDetails.get(prodId).get(6); //SBQQ__QuoteLine__r.NATT_Discount_Amount_Per_Unit__c
                    discRateAvgSO = TotalListPriceSO <> 0 ? (TotalDiscAmtSO/TotalListPriceSO) * 100 : 0;
                }
                
                WrapStandardOptions.add(new WrapStandardOrderItems(mapProductIdtoProductName.get(prodId),
                                                                   mapProductIdtoOrderItemDetails.get(prodId).get(3), //ListPrice
                                                                   mapProductIdtoOrderItemDetails.get(prodId).get(4), //UnitPrice
                                                                   mapProductIdtoOrderItemDetails.get(prodId).get(2), //TotalPrice
                                                                   mapProductIdtoOrderItemDetails.get(prodId).get(7), //NATT_End_Customer_Price__c                                                                 
                                                                   mapProductIdtoOrderItemDetails.get(prodId).get(5), //SBQQ__QuoteLine__r.SBQQ__TotalDiscountRate__c
                                                                   mapProductIdtoOrderItemDetails.get(prodId).get(6), //SBQQ__QuoteLine__r.NATT_Discount_Amount_Per_Unit__c
                                                                   Integer.valueOf(mapProductIdtoOrderItemDetails.get(prodId).get(1)))); //SBQQ__QuotedQuantity__c
                
            }   
            
            // Lynx Fleet 
            else if(mapProductIdtoOrderItemDetails.get(prodId).get(0) == 50.0){
                if(mapProductIdtoOrderItemDetails.get(prodId).get(1) != 0){
                    TotalListPriceLFSO += mapProductIdtoOrderItemDetails.get(prodId).get(3); //ListPrice
                    TotalUnitPriceLFSO += mapProductIdtoOrderItemDetails.get(prodId).get(4); //UnitPrice
                    TotalPriceLFSO += mapProductIdtoOrderItemDetails.get(prodId).get(2); //TotalPrice
                    TotalCustPriceLFSO += mapProductIdtoOrderItemDetails.get(prodId).get(7); //NATT_End_Customer_Price__c
                    if(mapProductIdtoOrderItemDetails.get(prodId).get(5) != 0){
                        TotalDiscRateLFSO += mapProductIdtoOrderItemDetails.get(prodId).get(5); //SBQQ__QuoteLine__r.SBQQ__TotalDiscountRate__c
                        allOrderItemsDiscRateSum += TotalDiscRateLFSO;
                        counterLFSO += 1;
                        //discRateAvgNSO = (TotalDiscRateNSO/(decimal)counterNSO).setScale(2);
                    }
                    TotalDiscAmtLFSO += mapProductIdtoOrderItemDetails.get(prodId).get(6); //SBQQ__QuoteLine__r.NATT_Discount_Amount_Per_Unit__c
                    discRateAvgLFSO = TotalListPriceLFSO <> 0 ? (TotalDiscAmtLFSO/TotalListPriceLFSO ) * 100 : 0;
                }
                
                WrapLynxFleets.add(new WrapLynxFleetOrderItems(mapProductIdtoProductName.get(prodId),
                                                              mapProductIdtoOrderItemDetails.get(prodId).get(3), //ListPrice
                                                              mapProductIdtoOrderItemDetails.get(prodId).get(4), //UnitPrice
                                                              mapProductIdtoOrderItemDetails.get(prodId).get(2), //TotalPrice
                                                              mapProductIdtoOrderItemDetails.get(prodId).get(7), //NATT_End_Customer_Price__c
                                                              mapProductIdtoOrderItemDetails.get(prodId).get(5), //SBQQ__QuoteLine__r.SBQQ__TotalDiscountRate__c
                                                              mapProductIdtoOrderItemDetails.get(prodId).get(6), //SBQQ__QuoteLine__r.NATT_Discount_Amount_Per_Unit__c
                                                              Integer.valueOf(mapProductIdtoOrderItemDetails.get(prodId).get(1)))); //SBQQ__QuotedQuantity__c
            }
            
            else if(mapProductIdtoOrderItemDetails.get(prodId).get(0) == 20.0){
                if(mapProductIdtoOrderItemDetails.get(prodId).get(1) != 0){
                    TotalListPriceNSO += mapProductIdtoOrderItemDetails.get(prodId).get(3); //ListPrice
                    TotalUnitPriceNSO += mapProductIdtoOrderItemDetails.get(prodId).get(4); //UnitPrice
                    TotalPriceNSO += mapProductIdtoOrderItemDetails.get(prodId).get(2); //TotalPrice
                    TotalCustPriceNSO += mapProductIdtoOrderItemDetails.get(prodId).get(7); //NATT_End_Customer_Price__c
                    if(mapProductIdtoOrderItemDetails.get(prodId).get(5) != 0){
                        TotalDiscRateNSO += mapProductIdtoOrderItemDetails.get(prodId).get(5); //SBQQ__QuoteLine__r.SBQQ__TotalDiscountRate__c
                        allOrderItemsDiscRateSum += TotalDiscRateNSO;
                        counterNSO += 1;
                        //discRateAvgNSO = (TotalDiscRateNSO/(decimal)counterNSO).setScale(2);
                    }
                    TotalDiscAmtNSO += mapProductIdtoOrderItemDetails.get(prodId).get(6); //SBQQ__QuoteLine__r.NATT_Discount_Amount_Per_Unit__c
                    discRateAvgNSO = TotalListPriceNSO <> 0 ? (TotalDiscAmtNSO/TotalListPriceNSO ) * 100 : 0;
                }
                
                WrapNonStandardOptions.add(new WrapOrderItems(mapProductIdtoProductName.get(prodId),
                                                              mapProductIdtoOrderItemDetails.get(prodId).get(3), //ListPrice
                                                              mapProductIdtoOrderItemDetails.get(prodId).get(4), //UnitPrice
                                                              mapProductIdtoOrderItemDetails.get(prodId).get(2), //TotalPrice
                                                              mapProductIdtoOrderItemDetails.get(prodId).get(7), //NATT_End_Customer_Price__c
                                                              mapProductIdtoOrderItemDetails.get(prodId).get(5), //SBQQ__QuoteLine__r.SBQQ__TotalDiscountRate__c
                                                              mapProductIdtoOrderItemDetails.get(prodId).get(6), //SBQQ__QuoteLine__r.NATT_Discount_Amount_Per_Unit__c
                                                              Integer.valueOf(mapProductIdtoOrderItemDetails.get(prodId).get(1)))); //SBQQ__QuotedQuantity__c
            }
            
            else if(mapProductIdtoOrderItemDetails.get(prodId).get(0) == 30.0){
                if(mapProductIdtoOrderItemDetails.get(prodId).get(1) != 0){
                    TotalListPriceSPO += mapProductIdtoOrderItemDetails.get(prodId).get(3); //ListPrice
                    TotalUnitPriceSPO += mapProductIdtoOrderItemDetails.get(prodId).get(4); //UnitPrice
                    system.debug('results of TotalUnitPriceSPO=>'+TotalUnitPriceSPO);
                    TotalPriceSPO += mapProductIdtoOrderItemDetails.get(prodId).get(2); //TotalPrice
                    TotalCustPriceSPO += mapProductIdtoOrderItemDetails.get(prodId).get(7); //NATT_End_Customer_Price__c
                    if(mapProductIdtoOrderItemDetails.get(prodId).get(5) != 0){
                        TotalDiscRateSPO += mapProductIdtoOrderItemDetails.get(prodId).get(5); //SBQQ__QuoteLine__r.SBQQ__TotalDiscountRate__c
                        allOrderItemsDiscRateSum += TotalDiscRateSPO;
                        counterSPO += 1;
                        //discRateAvgSPO = (TotalDiscRateSPO/(decimal)counterSPO).setScale(2);
                    }
                    TotalDiscAmtSPO += mapProductIdtoOrderItemDetails.get(prodId).get(6); //SBQQ__QuoteLine__r.NATT_Discount_Amount_Per_Unit__c
                    discRateAvgSPO = TotalListPriceSPO <> 0 ? (TotalDiscAmtSPO/TotalListPriceSPO ) * 100 : 0;
                }
                
                WrapSpecialOptions.add(new WrapSpecialOptions(mapProductIdtoProductName.get(prodId),
                                                              mapProductIdtoOrderItemDetails.get(prodId).get(3), //ListPrice
                                                              mapProductIdtoOrderItemDetails.get(prodId).get(4), //UnitPrice
                                                              mapProductIdtoOrderItemDetails.get(prodId).get(2), //TotalPrice
                                                              mapProductIdtoOrderItemDetails.get(prodId).get(7), //NATT_End_Customer_Price__c 
                                                              mapProductIdtoOrderItemDetails.get(prodId).get(5), //SBQQ__QuoteLine__r.SBQQ__TotalDiscountRate__c
                                                              mapProductIdtoOrderItemDetails.get(prodId).get(6), //SBQQ__QuoteLine__r.NATT_Discount_Amount_Per_Unit__c
                                                              Integer.valueOf(mapProductIdtoOrderItemDetails.get(prodId).get(1)))); //SBQQ__QuotedQuantity__c
            }
            
            else if(mapProductIdtoOrderItemDetails.get(prodId).get(0) == 40.0){
                if(mapProductIdtoOrderItemDetails.get(prodId).get(1) != 0){
                    TotalListPriceFr += mapProductIdtoOrderItemDetails.get(prodId).get(3); //ListPrice
                    TotalUnitPriceFr += mapProductIdtoOrderItemDetails.get(prodId).get(4); //UnitPrice
                    TotalPriceFr += mapProductIdtoOrderItemDetails.get(prodId).get(2); //TotalPrice
                    TotalCustPriceFr += mapProductIdtoOrderItemDetails.get(prodId).get(7); //NATT_End_Customer_Price__c
                    if(mapProductIdtoOrderItemDetails.get(prodId).get(5) != 0){
                        TotalDiscRateFr += mapProductIdtoOrderItemDetails.get(prodId).get(5); //SBQQ__QuoteLine__r.SBQQ__TotalDiscountRate__c
                        allOrderItemsDiscRateSum += TotalDiscRateSO;
                        counterFr += 1;
                        //discRateAvgSO = (TotalDiscRateSO/(decimal)counterSO).setScale(2);
                        
                    }
                    TotalDiscAmtFr += mapProductIdtoOrderItemDetails.get(prodId).get(6); //SBQQ__QuoteLine__r.NATT_Discount_Amount_Per_Unit__c
                    discRateAvgFr = TotalListPriceFr <> 0 ? (TotalDiscAmtFr/TotalListPriceFr) * 100 : 0;
                }
                
                WrapOtherOptions.add(new WrapOtherOptions(mapProductIdtoProductName.get(prodId),
                                                                   mapProductIdtoOrderItemDetails.get(prodId).get(3), //ListPrice
                                                                   mapProductIdtoOrderItemDetails.get(prodId).get(4), //UnitPrice
                                                                   mapProductIdtoOrderItemDetails.get(prodId).get(2), //TotalPrice
                                                                   mapProductIdtoOrderItemDetails.get(prodId).get(7), //NATT_End_Customer_Price__c                                                                 
                                                                   mapProductIdtoOrderItemDetails.get(prodId).get(5), //SBQQ__QuoteLine__r.SBQQ__TotalDiscountRate__c
                                                                   mapProductIdtoOrderItemDetails.get(prodId).get(6), //SBQQ__QuoteLine__r.NATT_Discount_Amount_Per_Unit__c
                                                                   Integer.valueOf(mapProductIdtoOrderItemDetails.get(prodId).get(1)))); //SBQQ__QuotedQuantity__c
                
            }   
        }
        
        totalListPriceSetter+=totalListPriceSO;
        totalUnitPriceSetter+=totalUnitPriceSO;
        totalTotalPriceSetter+=totalPriceSO;
        totalDiscPercSetter+=discRateAvgSO;
        totalDiscAmtSetter+=totalDiscAmtSO;
        totalCustPriceSetter+=totalCustPriceSO;
        
        
        totalListPriceSetter+=totalListPriceNSO;
        totalUnitPriceSetter+=totalUnitPriceNSO;
        totalTotalPriceSetter+=totalPriceNSO;
        totalDiscPercSetter+=discRateAvgNSO;
        totalDiscAmtSetter+=totalDiscAmtNSO;
        totalCustPriceSetter+=totalCustPriceNSO;
        
        //Lynx Fleet
         totalListPriceSetter+=totalListPriceLFSO;
        totalUnitPriceSetter+=totalUnitPriceLFSO;
        totalTotalPriceSetter+=totalPriceLFSO;
        totalDiscPercSetter+=discRateAvgLFSO;
        totalDiscAmtSetter+=totalDiscAmtLFSO;
        totalCustPriceSetter+=totalCustPriceLFSO;
        
        totalListPriceSetter+=totalListPriceSPO;
        totalUnitPriceSetter+=totalUnitPriceSPO;
        totalTotalPriceSetter+=totalPriceSPO;
        totalDiscPercSetter+=discRateAvgSPO;
        totalDiscAmtSetter+=totalDiscAmtSPO;
        totalCustPriceSetter+=totalCustPriceSPO;

        totalListPriceSetter+=totalListPriceFr;
        totalUnitPriceSetter+=totalUnitPriceFr;
        totalTotalPriceSetter+=totalPriceFr;
        totalDiscPercSetter+=discRateAvgFr;
        totalDiscAmtSetter+=totalDiscAmtFr;
        totalCustPriceSetter+=totalCustPriceFr;
        
        WrapStandardOptionsTotal.add(new WrapStandardOrderItems('Standard Options Total',TotalListPriceSO,TotalUnitPriceSO,TotalPriceSO,TotalCustPriceSO,discRateAvgSO,TotalDiscAmtSO,null));
        WrapNonStandardOptionsTotal.add(new WrapOrderItems('Non Standard Options Total',TotalListPriceNSO,TotalUnitPriceNSO,TotalPriceNSO,TotalCustPriceNSO,discRateAvgNSO,TotalDiscAmtNSO,null) );
        //Lynx Fleet 
               WrapLynxFleetsTotals.add(new WrapLynxFleetOrderItems('Lynx Fleet Options Total',TotalListPriceLFSO,TotalUnitPriceLFSO,TotalPriceLFSO,TotalCustPriceLFSO,discRateAvgLFSO,TotalDiscAmtLFSO,null) );
        WrapSpecialOptionsTotal.add(new WrapSpecialOptions('Special Options Total',TotalListPriceSPO,TotalUnitPriceSPO,TotalPriceSPO,TotalCustPriceSPO,discRateAvgSPO,TotalDiscAmtSPO,null) );
        WrapOtherOptionsTotal.add(new WrapOtherOptions('Other Options Total',TotalListPriceFr,TotalUnitPriceFr,TotalPriceFr,TotalCustPriceFr,discRateAvgFr,TotalDiscAmtFr,null) );
        
    }
    
    public void displayBlueEdgeLines(String OriginalOrderId, String orderRecentUnit){
        list<OrderItem> BlueEdgeItems= new list<OrderItem>();
        if(Test.isRunningTest()){
            BlueEdgeItems = [Select id,product2.Name, Quantity, SBQQ__QuotedListPrice__c,UnitPrice,TotalPrice,NATT_End_Customer_Price__c,
                             SBQQ__QuoteLine__r.SBQQ__TotalDiscountRate__c,
                             SBQQ__QuoteLine__r.NATT_Discount_Amount_Per_Unit__c,
                             SBQQ__QuoteLine__r.NATT_Special_Request_Notes__c, NATT_Original_Order_Id__c, NATT_Unit_Name__c 
                             from OrderItem where NATT_Original_Order_Id__c=:OriginalOrderId
                             and NATT_EMCC__c=true ORDER BY CreatedDate DESC];
        }
        else{
            BlueEdgeItems = [Select id,product2.Name, Quantity, SBQQ__QuotedListPrice__c,UnitPrice,TotalPrice,NATT_End_Customer_Price__c,
                             SBQQ__QuoteLine__r.SBQQ__TotalDiscountRate__c,
                             SBQQ__QuoteLine__r.NATT_Discount_Amount_Per_Unit__c,
                             SBQQ__QuoteLine__r.NATT_Special_Request_Notes__c, NATT_Original_Order_Id__c, NATT_Unit_Name__c 
                             from OrderItem where NATT_Original_Order_Id__c=:OriginalOrderId and product2.Name = 'BluEdge Core' //NATT_Unit_Name__c =: orderRecentUnit
                             and NATT_EMCC__c=true ORDER BY CreatedDate DESC];
        }
        
        BETotalListPrice=0.00;
        BETotalUnitPrice=0.00;
        BETotalTotalPrice=0.00;
        BETotalCustPrice=0.00;
        BECustPrice=0.00;
        BETotalDiscRate=0.00;
        BEListPrice=0.00;
        BEUnitPrice=0.00;
        BETotalPrice=0.00;
        Integer BECount = 0;
        decimal  BETotalDiscRateSum=0.0;
        BETotalDiscAmt=0.00;
        BETotalQty=null;
        BEQty = 0.00;
        //for negative quantity blueedge core
        Decimal BEQCount = 0;
        Decimal BEQQuotedPrice = 0.00;
        Decimal amendmentPrice = 0.00;
        if(!BlueEdgeItems.isEmpty()){
            Order bluEdgeIdValue=[select id,NATT_BluEdge_Id__c, NATT_Legacy_BluEdge_Expiration_Date__c  from Order where id=:OriginalOrderId];
            if(bluEdgeIdValue.NATT_BluEdge_Id__c <> null)
                bluEdgeId=bluEdgeIdValue.NATT_BluEdge_Id__c + ' ';
            bluEdgeExpDate=bluEdgeIdValue.NATT_Legacy_BluEdge_Expiration_Date__c;
        }
        
        integer bluEdgeListSize=BlueEdgeItems.size();
        for (OrderItem bedge:BlueEdgeItems){
            BEQty += bedge.Quantity;
        }
        System.debug('BEQty: '+BEQty);
        
        if(BEQty > 0){
            for(OrderItem bedge:BlueEdgeItems){
                if(bedge.NATT_Original_Order_Id__c.equals(OriginalOrderId)){
                    System.debug('bedge.SBQQ__QuotedListPrice__c: '+bedge.SBQQ__QuotedListPrice__c);
                    if(bedge.SBQQ__QuotedListPrice__c > 0){
                        BECount += 1;
                        BEQQuotedPrice = bedge.SBQQ__QuotedListPrice__c;
                    } else {
                        BEQCount += bedge.Quantity;
                    }
                    System.debug('BECount: '+BECount);
                    System.debug('bedge.UnitPrice: '+bedge.UnitPrice);
                    System.debug('bedge.SBQQ__QuotedListPrice__c: '+bedge.SBQQ__QuotedListPrice__c);
                    BEListPrice += bedge.SBQQ__QuotedListPrice__c;
                    BEUnitPrice += bedge.UnitPrice;
                    //BEUnitPrice = bedge.UnitPrice;
                    BETotalListPrice +=bedge.SBQQ__QuotedListPrice__c * bedge.Quantity;
                    BETotalUnitPrice +=bedge.UnitPrice * bedge.Quantity;
                    BETotalTotalPrice +=bedge.UnitPrice * bedge.Quantity;
                    if(bedge.NATT_End_Customer_Price__c != null){
                        BECustPrice += bedge.NATT_End_Customer_Price__c;
                        BETotalCustPrice += bedge.NATT_End_Customer_Price__c*bedge.Quantity;
                    }
                    BETotalDiscRateSum += bedge.SBQQ__QuoteLine__r.SBQQ__TotalDiscountRate__c;
                    BETotalDiscAmt += bedge.SBQQ__QuotedListPrice__c * bedge.SBQQ__QuoteLine__r.SBQQ__TotalDiscountRate__c;
                    System.debug('BETotalListPrice: '+BETotalListPrice);
                    System.debug('BETotalUnitPrice: '+BETotalUnitPrice);
                    System.debug('BETotalTotalPrice: '+BETotalTotalPrice);
                    System.debug('============================');
                }             
            }
        }
        System.debug('BEQCount:'+BEQCount);
        System.debug('BEQQuotedPrice:'+BEQQuotedPrice);
        IF(BECount > 0){
            BEListPrice = BEListPrice/(decimal) BECount;
            BEUnitPrice = BEUnitPrice/(decimal) BECount;
            BECustPrice = BECustPrice/(decimal) BECount;
            BETotalDiscAmt = BEListPrice - BEUnitPrice;
        }
        if(BEQCount < 0){
            amendmentPrice =  BEQCount * BEQQuotedPrice;
            System.debug('pricee :'+amendmentPrice);
            BETotalTotalPrice  = BETotalTotalPrice + (amendmentPrice);
        }
        System.debug('BEListPrice:'+BEListPrice);
        System.debug('BEUnitPrice:'+BEUnitPrice);
        System.debug('BECustPrice:'+BECustPrice);
        BETotalDiscRate = bluEdgeListSize > 0 ? BETotalDiscRateSum /(decimal) bluEdgeListSize : BETotalDiscRateSum;
        BETotalCustPrice += BECustPrice;
    }
    
    public void displayQuoteApprovers(String OriginalOrderId, Order getLatestOrder){
        try{
            
            
            SBQQ__Quote__c QuoteApproversList=[select NATT_Approver_1__r.Name,NATT_Approver_1_Approval_Date__c,NATT_Approver_1_Approved__c,
                                               NATT_Approver_2__r.Name,NATT_Approver_2_Approval_Date__c,NATT_Approver_2_Approved__c,
                                               NATT_Approver_3__r.Name,NATT_Approver_3_Approval_Date__c,NATT_Approver_3_Approved__c,
                                               NATT_Approver_4__r.Name,NATT_Approver_4_Approval_Date__c,NATT_Approver_4_Approved__c,
                                               NATT_Approver_5__r.Name,NATT_Approver_5_Approval_Date__c,NATT_Approver_5_Approved__c,
                                               NATT_Approver_6__r.Name,NATT_Approver_6_Approval_Date__c,NATT_Approver_6_Approved__c,
                                               SBQQ__SalesRep__r.Name,NATT_Final_Approval_Date__c,SBQQ__Status__c
                                               from SBQQ__Quote__c where id=:getLatestOrder.SBQQ__Quote__c and SBQQ__Primary__c=true
                                              ]; 
            
            system.debug('QuoteApproversList==>'+QuoteApproversList);
            if(QuoteApproversList !=null){
                
                Approver1=QuoteApproversList.NATT_Approver_1__r.Name; 
                Aprvd1=QuoteApproversList.NATT_Approver_1_Approved__c;
                //ApprovalDate1=QuoteApproversList.NATT_Approver_1_Approval_Date__c;
                ApprovalDate1=formatDate(QuoteApproversList.NATT_Approver_1_Approval_Date__c);
                
                Approver2=QuoteApproversList.NATT_Approver_2__r.Name; 
                Aprvd2=QuoteApproversList.NATT_Approver_2_Approved__c;
                //ApprovalDate2=QuoteApproversList.NATT_Approver_2_Approval_Date__c;
                ApprovalDate2=formatDate(QuoteApproversList.NATT_Approver_2_Approval_Date__c);
                
                Approver3=QuoteApproversList.NATT_Approver_3__r.Name; 
                Aprvd3=QuoteApproversList.NATT_Approver_3_Approved__c;
                //ApprovalDate3=QuoteApproversList.NATT_Approver_3_Approval_Date__c;
                ApprovalDate3=formatDate(QuoteApproversList.NATT_Approver_3_Approval_Date__c);
                
                Approver4=QuoteApproversList.NATT_Approver_4__r.Name; 
                Aprvd4=QuoteApproversList.NATT_Approver_4_Approved__c;
                //ApprovalDate4=QuoteApproversList.NATT_Approver_4_Approval_Date__c;
                ApprovalDate4=formatDate(QuoteApproversList.NATT_Approver_4_Approval_Date__c);     
                
                Approver5=QuoteApproversList.NATT_Approver_5__r.Name; 
                Aprvd5=QuoteApproversList.NATT_Approver_5_Approved__c;
                //ApprovalDate5=QuoteApproversList.NATT_Approver_5_Approval_Date__c;
                ApprovalDate5=formatDate(QuoteApproversList.NATT_Approver_5_Approval_Date__c);
                
                Approver6=QuoteApproversList.NATT_Approver_6__r.Name; 
                Aprvd6=QuoteApproversList.NATT_Approver_6_Approved__c;
                //ApprovalDate6=QuoteApproversList.NATT_Approver_6_Approval_Date__c;
                ApprovalDate6=formatDate(QuoteApproversList.NATT_Approver_6_Approval_Date__c);
                
                //FinalApprovalDate=QuoteApproversList.NATT_Final_Approval_Date__c;
                FinalApprovalDate=formatDate(QuoteApproversList.NATT_Final_Approval_Date__c);
                SalesRep=QuoteApproversList.SBQQ__SalesRep__r.Name;
                ApprovalStatus=QuoteApproversList.SBQQ__Status__c;
            }
        }
        catch(exception ex){
            system.debug('Exception in displaying approvers==>'+ex);
        }
    }
    
    public void displayQuoteHistory(String OriginalOrderId,Order getLatestOrder){
        QuoteFldHistory=new list<WrapFieldHistory>();
        
        list<SBQQ__Quote__c> quoteIdsList=[select Id from SBQQ__Quote__c where NATT_Original_Order_Id__c=:OriginalOrderId and SBQQ__Primary__c=true ];
        
        list<Id> qList=new list<Id>();
        
        for(SBQQ__Quote__c quote:quoteIdsList){
            qList.add(quote.Id); 
        }
        qList.add(getLatestOrder.SBQQ__Quote__c);
        
        list<SBQQ__Quote__History> FieldHistoryList=[ select parentId, OldValue, NewValue, Field, CreatedBy.Name,CreatedDate From SBQQ__Quote__History where parentId in:qList and (Field='SBQQ__Status__c'or Field='created') order by CreatedDate desc limit 10];
        
        for(SBQQ__Quote__History qh:FieldHistoryList){
            String HistoryString=String.valueOf(formatDate(Date.valueOf(qh.CreatedDate)) +' - '+ qh.CreatedBy.Name+' - '+ getLabelsFromApi(qh.Field) +' to '+ qh.NewValue);
            system.debug('HistoryString==>'+HistoryString);
            
            QuoteFldHistory.add(new WrapFieldHistory(HistoryString)); 
        } 
    }
    
    public string getLabelsFromApi(String fieldName){
        if(fieldName=='created') 
            
            return 'Created';
        
        String type='SBQQ__Quote__c';
        
        Map<String, Schema.SObjectType> schemaMap = Schema.getGlobalDescribe();
        Schema.SObjectType leadSchema = schemaMap.get(type);
        Map<String, Schema.SObjectField> fieldMap = leadSchema.getDescribe().fields.getMap();
        
        System.debug('Field API Name===>'+fieldName);
        
        String label=fieldMap.get(fieldName).getDescribe().getLabel();
        
        return label;   
    }
    
    public void displayComments(String OriginalOrderId){
        DealerComments=new list<WrapComments>();
        InternalComments=new list<WrapComments>();
        ChangeOrderComments=new list<WrapComments>();
        ChangeOrder=new list<WrapComments>();
        ApprovalComments=new list<WrapComments>();
        MFDIComments=new list<WrapComments>();  
        
        List<Order> OrigOrdQuote = [Select SBQQ__Quote__c, NATT_Dealer_Comments__c,
                                    SBQQ__Quote__r.SBQQ__Opportunity2__r.Name,
                                    SBQQ__Quote__r.NATT_Dealer_Comments__c,
                                    SBQQ__Quote__r.NATT_Internal_Comments__c,
                                    SBQQ__Quote__r.NATT_Change_Order__c,
                                    SBQQ__Quote__r.NATT_Change_Order_Comments__c,
                                    SBQQ__Quote__r.NATT_Approval_Comments__c,
                                    SBQQ__Quote__r.NATT_Mark_For_Special_Delivery_Instructi__c  
                                    from Order where id=:OriginalOrderId and SBQQ__Quote__r.SBQQ__Primary__c=true];
        
        if(OrigOrdQuote.isEmpty()) return;
        if(OriginalOrderId <> null){
            List<Order> orderDealerComment = [Select SBQQ__Quote__c, NATT_Dealer_Comments__c, SBQQ__Quote__r.SBQQ__Opportunity2__r.Name from Order where NATT_Original_Order_Id__c  =:OriginalOrderId Order by Createddate desc];
            for(Order ord : orderDealerComment ){
                if(ord.NATT_Dealer_Comments__c <> null){
                    String dc1 = ord.NATT_Dealer_Comments__c.replaceAll('</p><p>', '<br/>');
                    String dc2 = dc1.replaceAll('<p>', '');
                    DealerComments.add(new WrapComments(dc2,ord.SBQQ__Quote__r.SBQQ__Opportunity2__r.Name));
                    break;
                }
            }
        }
        /*if(OrigOrdQuote[0].NATT_Dealer_Comments__c <> null){
String dc1 = OrigOrdQuote[0].NATT_Dealer_Comments__c.replaceAll('</p><p>', '<br/>');
String dc2 = dc1.replaceAll('<p>', '');
DealerComments.add(new WrapComments(dc2,OrigOrdQuote[0].SBQQ__Quote__r.SBQQ__Opportunity2__r.Name));
}*/
        
        if(OrigOrdQuote[0].SBQQ__Quote__r.NATT_Mark_For_Special_Delivery_Instructi__c <> null){ 
            String dc1 = OrigOrdQuote[0].SBQQ__Quote__r.NATT_Mark_For_Special_Delivery_Instructi__c.replaceAll('</p><p>', '<br/>'); 
            String dc2 = dc1.replaceAll('<p>', ''); 
            MFDIComments.add(new WrapComments(dc2,OrigOrdQuote[0].SBQQ__Quote__r.SBQQ__Opportunity2__r.Name));  
        }
        if(OrigOrdQuote[0].SBQQ__Quote__r.NATT_Internal_Comments__c <> null) 
            InternalComments.add(new WrapComments(OrigOrdQuote[0].SBQQ__Quote__r.NATT_Internal_Comments__c,OrigOrdQuote[0].SBQQ__Quote__r.SBQQ__Opportunity2__r.Name));
        
        if(OrigOrdQuote[0].SBQQ__Quote__r.NATT_Change_Order__c <> null)
            ChangeOrder.add(new WrapComments(OrigOrdQuote[0].SBQQ__Quote__r.NATT_Change_Order__c,OrigOrdQuote[0].SBQQ__Quote__r.SBQQ__Opportunity2__r.Name));
        
        if(OrigOrdQuote[0].SBQQ__Quote__r.NATT_Change_Order_Comments__c <> null)
            ChangeOrderComments.add(new WrapComments(OrigOrdQuote[0].SBQQ__Quote__r.NATT_Change_Order_Comments__c,OrigOrdQuote[0].SBQQ__Quote__r.SBQQ__Opportunity2__r.Name));
        
        if(OrigOrdQuote[0].SBQQ__Quote__r.NATT_Approval_Comments__c <> null){
            String AppCom= OrigOrdQuote[0].SBQQ__Quote__r.NATT_Approval_Comments__c;
            //AppCom=AppCom.replaceAll(';','/n');
            system.debug('AppCom1==>'+AppCom);
            
            ApprovalComments.add(new WrapComments(AppCom,OrigOrdQuote[0].SBQQ__Quote__r.SBQQ__Opportunity2__r.Name));
        }
        
        
        
        list<SBQQ__Quote__c> QuoteList=[select Id,NATT_Mark_For_Special_Delivery_Instructi__c,NATT_Dealer_Comments__c,NATT_Internal_Comments__c,NATT_Change_Order__c,NATT_Change_Order_Comments__c,NATT_Approval_Comments__c,SBQQ__Opportunity2__r.Name 
                                        from SBQQ__Quote__c where NATT_Original_Order_Id__c=:OriginalOrderId and SBQQ__Primary__c=true order by lastModifiedDate asc ];
        
        for(SBQQ__Quote__c ql:QuoteList){ 
            if(ql.NATT_Dealer_Comments__c <> null)
                DealerComments.add(new WrapComments(ql.NATT_Dealer_Comments__c,ql.SBQQ__Opportunity2__r.Name));
            if(ql.NATT_Mark_For_Special_Delivery_Instructi__c <> null)  
                MFDIComments.add(new WrapComments(ql.NATT_Mark_For_Special_Delivery_Instructi__c,ql.SBQQ__Opportunity2__r.Name));
            if(ql.NATT_Internal_Comments__c <> null)
                InternalComments.add(new WrapComments(ql.NATT_Internal_Comments__c,ql.SBQQ__Opportunity2__r.Name));
            if(ql.NATT_Change_Order__c <> null)
                ChangeOrder.add(new WrapComments(ql.NATT_Change_Order__c,ql.SBQQ__Opportunity2__r.Name));
            if(ql.NATT_Change_Order_Comments__c <> null)
                ChangeOrderComments.add(new WrapComments(ql.NATT_Change_Order_Comments__c,ql.SBQQ__Opportunity2__r.Name));
            if(ql.NATT_Approval_Comments__c <> null)
            {
                String AppCom2= ql.NATT_Approval_Comments__c;
                //AppCom2=AppCom2.replaceAll(';','/n');
                system.debug('AppCom2==>'+AppCom2);
                ApprovalComments.add(new WrapComments(AppCom2,ql.SBQQ__Opportunity2__r.Name));
            }            
        }
    }
    
    public void displayCompleteOrderSummary(String OriginalOrderId){
        orderSummaryList=new list<WrapOrderSummary>();
        
        list<orderItem>allOrderItems=[Select product2.Name, createdDate,lastModifiedDate,SBQQ__QuotedQuantity__c, NATT_Original_Order_Id__c,
                                      Order.OrderNumber,Order.Type,NATT_Feature_Category__c,NATT_Product_Name__c, SBQQ__QuoteLine__r.NATT_Special_Request_Notes__c
                                      from OrderItem
                                      where NATT_Original_Order_Id__c=:OriginalOrderId];
        
        for(OrderItem ordItm:allOrderItems){
            if(ordItm.NATT_Original_Order_Id__c.equals(OriginalOrderId)){
                String productName = ordItm.product2.Name;
                if(ordItm.NATT_Feature_Category__c == 'Special Options'){
                    productName = ordItm.product2.Name + ' - ' + ordItm.SBQQ__QuoteLine__r.NATT_Special_Request_Notes__c;
                }
                system.debug('12345 here');
                orderSummaryList.add(new WrapOrderSummary(productName,formatDate(Date.valueOf(ordItm.createdDate)),ordItm.Order.OrderNumber,Integer.valueOf(ordItm.SBQQ__QuotedQuantity__c),ordItm.Order.Type));
            }
            
        }
        
        system.debug('orderSummaryList==>'+orderSummaryList);
    }
    
    public class WrapOrderSummary {
        public String ProdName {get; set;} 
        public String createdDate {get; set;}
        public String OrderNumber {get; set;}
        public decimal qty {get; set;}
        public String OrderType {get; set;}
        
        
        public WrapOrderSummary(String name ,String createdDate1,String OrdNo,decimal qty1,String ordType) {
            ProdName=name;
            createdDate=createdDate1;
            OrderNumber=OrdNo;
            qty=qty1;
            OrderType=ordType;
            
        }
    }
    
    public class WrapComments{
        public String Comments {get; set;} 
        public String OppName {get; set;} 
        
        
        public WrapComments(String com,String opp){
            if(com !=null)
                
                Comments=com;
            OppName=opp;
            
        }
    }
    
    public class WrapFieldHistory{
        public String historyInfo {get; set;} 
        
        
        public WrapFieldHistory(String history){
            if(history !=null)
                
                historyInfo=history;
        }
    }
    
    public class WrapStandardOrderItems {
        public String productName {get; set;} 
        public decimal listPrice {get; set;} 
        public decimal unitPrice {get; set;} 
        public decimal totalPrice {get; set;}
        public decimal custPrice {get; set;} 
        public decimal discPerc {get; set;} 
        public decimal discAmt {get; set;}
        public decimal Qty{get;set;}
        
        public WrapStandardOrderItems(String prodName1,decimal listPrice1, decimal unitPrice1,decimal totalPrice1,decimal custPrice1,decimal discPerc1,decimal discAmt1,decimal qty1){
            system.debug('Inside WrapStandardOrderItems===');
            productName = prodName1;
            listPrice = listPrice1;
            unitPrice = unitPrice1;
            totalPrice = totalPrice1;
            custPrice = custPrice1;
            discPerc = discPerc1;
            discAmt = discAmt1;
            Qty=qty1;
            
        }
    }
    // lynx fleet 
     public class WrapLynxFleetOrderItems {
        public String productName {get; set;} 
        public decimal listPrice {get; set;} 
        public decimal unitPrice {get; set;} 
        public decimal totalPrice {get; set;}
        public decimal custPrice {get; set;} 
        public decimal discPerc {get; set;} 
        public decimal discAmt {get; set;}
        public decimal Qty{get;set;}
        
        public WrapLynxFleetOrderItems(String prodName1,decimal listPrice1, decimal unitPrice1,decimal totalPrice1,decimal custPrice1,decimal discPerc1,decimal discAmt1,decimal qty1){
            system.debug('Inside WrapLynxFleetOrderItems===');
            productName = prodName1;
            listPrice = listPrice1;
            unitPrice = unitPrice1;
            totalPrice = totalPrice1;
            custPrice = custPrice1;
            discPerc = discPerc1;
            discAmt = discAmt1;
            Qty=qty1;
            
        }
    }
    
    public class WrapOrderItems {
        public String productName {get; set;} 
        public decimal listPrice {get; set;} 
        public decimal unitPrice {get; set;} 
        public decimal totalPrice {get; set;}
        public decimal custPrice {get; set;} 
        public decimal discPerc {get; set;} 
        public decimal discAmt {get; set;}
        public decimal Qty{get;set;}
        
        
        public WrapOrderItems(String prodName1,decimal listPrice1, decimal unitPrice1,decimal totalPrice1,decimal custPrice1,decimal discPerc1,decimal discAmt1,decimal qty1) {
            system.debug('Inside Non Standard WrapOrderItems===');
            productName = prodName1;
            listPrice = listPrice1;
            unitPrice = unitPrice1;
            totalPrice = totalPrice1;
            custPrice = custPrice1;
            discPerc = discPerc1;
            discAmt = discAmt1;
            Qty=qty1;
            
        }
    }
    
    public class WrapSpecialOptions{
        public String productName {get; set;} 
        public decimal listPrice {get; set;} 
        public decimal unitPrice {get; set;} 
        public decimal totalPrice {get; set;}
        public decimal custPrice {get; set;}         
        public decimal discPerc {get; set;} 
        public decimal discAmt {get; set;}
        public decimal Qty{get;set;}
        
        public WrapSpecialOptions(String prodName1,decimal listPrice1, decimal unitPrice1,decimal totalPrice1,decimal custPrice1,decimal discPerc1,decimal discAmt1,decimal qty1) {
            system.debug('Inside Non Standard WrapOrderItems===');
            productName = prodName1;
            listPrice = listPrice1;
            system.debug('listPrice==='+listPrice);
            unitPrice = unitPrice1;
            system.debug('unitPrice==='+unitPrice);
            totalPrice = totalPrice1;
            custPrice = custPrice1;            
            discPerc = discPerc1;
            discAmt = discAmt1;
            Qty=qty1;
            
        }
    }
   
        public class WrapOtherOptions {
        public String productName {get; set;} 
        public decimal listPrice {get; set;} 
        public decimal unitPrice {get; set;} 
        public decimal totalPrice {get; set;}
        public decimal custPrice {get; set;} 
        public decimal discPerc {get; set;} 
        public decimal discAmt {get; set;}
        public decimal Qty{get;set;}
        
        public WrapOtherOptions(String prodName1,decimal listPrice1, decimal unitPrice1,decimal totalPrice1,decimal custPrice1,decimal discPerc1,decimal discAmt1,decimal qty1){
            system.debug('Inside WrapStandardOrderItems===');
            productName = prodName1;
            listPrice = listPrice1;
            unitPrice = unitPrice1;
            totalPrice = totalPrice1;
            custPrice = custPrice1;
            discPerc = discPerc1;
            discAmt = discAmt1;
            Qty=qty1;
            
        }
    }
    
    public class WrapReqShipQtyAndDate {
        public Integer ReqQty {get; set;}
        public String ReqshipDate {get; set;} 
        public String SchShipDate {get; set;} 
        //Constructor method 
        public WrapReqShipQtyAndDate(Integer qty,String sdate,String schPickDate) {
            ReqQty = qty;
            ReqshipDate = sdate;
            SchShipDate = schPickDate;
            if(ReqQty !=null)
                listofQtys.add(ReqQty);
            System.debug('Here in Req Wrapper===');
        }
        public WrapReqShipQtyAndDate(String schPickDate) {
            SchPickDate = schPickDate;
        }
    }
    
    /*public class WrapShipQtyAndDate 
{
public Integer Qty {get; set;}
public String ShipDate {get; set;} 
//Constructor method 
public WrapShipQtyAndDate(Integer qty,String sdate) 
{
Qty = qty;
ShipDate = sdate;
System.debug('Here in Ship wrapper===');
system.debug('Ship Wrapper Qty==>'+Qty);
if(Qty !=null)
listofQtys.add(Qty);

}
}
public class WrapShip 
{
public Integer quantity {get; set;}
public String ShipDt {get; set;} 
//Constructor method 
public WrapShip(Integer qty,String sdate) 
{
quantity = qty;
ShipDt = sdate;
System.debug('Here in Ship wrapper===');
system.debug('Ship Wrapper Qty==>'+Qty);
if(Qty !=null)
listofQtys.add(Qty);
}
}*/   
}