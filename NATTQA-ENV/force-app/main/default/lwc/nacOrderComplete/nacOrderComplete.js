import { LightningElement,api } from 'lwc';
import { NavigationMixin} from 'lightning/navigation';
import fetchOrderData from '@salesforce/apex/NAC_CheckoutController.fetchOrderData';
import getProductCategory from '@salesforce/apex/NAC_B2BGetInfoController.getProductCategory';
import communityId from '@salesforce/community/Id';
export default class NacOrderComplete extends NavigationMixin(LightningElement)  {

    @api recordId;
    @api checkoutWrapper;
    ordersData;
    //Address fields
    shippingstreet;
    shippingcity;
    shippingstate;
    shippingcountry;
    shippingzipCode;

    //BillingAddress
    billingstreet;
    billingcity;
    billingstate;
    billingcountry;
    billingzipCode;

    //Transactional fields
    paymentMethod;
    purchaseOrderNumber;
    orderNumber;
    orderDate;
    shippingMethod;
    OrderType;
    OrderRefcap;
    requestedDate;
    BillingDelivery;
    totalRushCharge;
    showRushCharge = false;
    
  
    connectedCallback(){
        this.dispatchEvent(
            new CustomEvent('cartchanged', {
                bubbles: true,
                composed: true
            })
        );
        fetchOrderData({
            orderId: this.recordId,
        })
            .then((result) => {
                this.ordersData = result;
                this.shippingstreet = result.ShippingStreet;
                this.shippingcity = result.ShippingCity;
                this.shippingstate = result.ShippingState;
                this.shippingcountry = result.ShippingCountry;
                this.shippingzipCode = result.ShippingPostalCode;
                this.OrderRefcap = result.NAOCAP_Order_Ref__c;
                
                if(result.NATT_Requested_Ship_Date__c != null){
                   this.requestedDate = result.NATT_Requested_Ship_Date__c;
                   //this.requestedDate = new Date(result.NATT_Requested_Ship_Date__c).toDateString();
                }else{
                    this.requestedDate = result.NATT_Requested_Ship_Date__c;
                }
                this.billingstreet = result.BillingStreet;
                this.billingcity = result.BillingCity;
                this.billingstate = result.BillingState;
                this.billingcountry = result.BillingCountry;
                this.billingzipCode = result.BillingPostalCode;
                //Formatting date to not show datetime
                
                let orderFrmDate = new Date(result.OrderedDate).toDateString();
                this.orderDate = orderFrmDate;
                
                this.orderAmount = result.TotalAmount;
                if(result.NAOCAP_Rush_Order_Charge__c > 0){
                    this.showRushCharge = true;
                    this.totalRushCharge = result.NAOCAP_Rush_Order_Charge__c;
                }

                this.purchaseOrderNumber = result.NATT_Purchase_Order__c;
                this.orderNumber = result.OrderNumber;

                this.shippingMethod = result.NAC_Shipping_Method__c;
                this.OrderType = result.NAC_Order_Type__c;
                this.BillingDelivery = result.NAC_Billing_Delivery_Term__c;
            })
            .catch((error) => {
                console.log(error);
            });
    }

    navigateAllProducts(){
        getProductCategory({communityId:communityId})
            .then(result => {
                try {
                    this[NavigationMixin.Navigate]({
                        type: 'standard__webPage',
                        attributes: {
                            url: '/category/Products/'+result.topMostParentCategoryId
                      }
                    });
                }
                catch (error) {
                    console.log(JSON.stringify(error.message));
                }
            })
            .catch(error => {
                console.log('Error' + JSON.stringify(error));
            });
    }
}