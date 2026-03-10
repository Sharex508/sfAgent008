import { LightningElement,api,wire,track } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { ShowToastEvent } from 'lightning/platformShowToastEvent'
import getCartSummary from '@salesforce/apex/NATT_PpgCheckoutCon.getCartSummary';
import getDeliveryOptions from '@salesforce/apex/NATT_PpgCheckoutCon.getAvailableDeliveryGroupMethods';
import updateWebCart from '@salesforce/apex/NATT_PpgCheckoutCon.updateWebCart';
import getWebCart from '@salesforce/apex/NATT_PpgCheckoutCon.getWebCart';
// import getAddressList from '@salesforce/apex/NATT_PpgCheckoutCon.getAddressList';
import getAddressList from '@salesforce/apex/NATT_CtmCheckoutCon.getAddressList';
import createRushFeeCartItem from '@salesforce/apex/NATT_PpgCheckoutCon.createRushFeeCartItem';

import getContactPointAddressRt from '@salesforce/apex/NATT_PpgCheckoutCon.getContactPointAddressRt';
import getOrderDeliveryMethod from '@salesforce/apex/NATT_CtmCheckoutCon.getOrderDeliveryMethod';

/*** Salesforce Community Imports ***/
import communityId from "@salesforce/community/Id";
import { FlowAttributeChangeEvent, FlowNavigationNextEvent } from 'lightning/flowSupport';
import CART_OBJECT from '@salesforce/schema/WebCart';
import { refreshApex } from '@salesforce/apex';

import getCartDetail from '@salesforce/apex/NATT_CtmCheckoutCon.getCartDetail';
/*** Imports from Custom Labels ***/
import AddressLabel from '@salesforce/label/c.NATT_Checkout_Address';
import BackLabel from '@salesforce/label/c.NATT_Checkout_Back';
import BillingDeliveryTermsLabel from '@salesforce/label/c.NATT_Checkout_Billing_Delivery_Terms';
import CancelLabel from '@salesforce/label/c.NATT_Checkout_Cancel';
import CityLabel from '@salesforce/label/c.NATT_Checkout_City';
import ContactEmailLabel from '@salesforce/label/c.NATT_Checkout_Contact_Email';
import ContactNameLabel from '@salesforce/label/c.NATT_Checkout_Contact_Name';
import ContactPhoneLabel from '@salesforce/label/c.NATT_Checkout_Contact_Phone';
import CreateDropShipLabel from '@salesforce/label/c.NATT_Checkout_Create_Drop_Ship';
import CreateNewLabel from '@salesforce/label/c.NATT_Checkout_Create_New';
import CustomerLabel from '@salesforce/label/c.NATT_Checkout_Customer';
import CustomerInformationLabel from '@salesforce/label/c.NATT_Checkout_Customer_Information';
import CustomerNumberLabel from '@salesforce/label/c.NATT_Checkout_Customer_Number';
import DeliverToAddressLabel from '@salesforce/label/c.NATT_Checkout_Deliver_to_Address';
import DescriptionLabel from '@salesforce/label/c.NATT_Checkout_Description';
import EmailAddressLabel from '@salesforce/label/c.NATT_Checkout_Email_Address';
import ExtendedLabel from '@salesforce/label/c.NATT_Checkout_Extended';
import FreightAccountNumberLabel from '@salesforce/label/c.NATT_Checkout_Freight_Account_Number';
import NameLabel from '@salesforce/label/c.NATT_Checkout_Name';
import NextLabel from '@salesforce/label/c.NATT_Checkout_Next';
import OrderInformationLabel from '@salesforce/label/c.NATT_Checkout_Order_Information';
import OrderTotalLabel from '@salesforce/label/c.NATT_Checkout_Order_Total';
import OrderTypeLabel from '@salesforce/label/c.NATT_Checkout_Order_Type';
import PartDetailLabel from '@salesforce/label/c.NATT_Checkout_Part_Detail';
import PartNumberLabel from '@salesforce/label/c.NATT_Checkout_Part_Number';
import PlaceOrderLabel from '@salesforce/label/c.NATT_Checkout_Place_Order';
import PleaseEnteraValidEmailLabel from '@salesforce/label/c.NATT_Checkout_Please_enter_a_valid_email';
import POLabel from '@salesforce/label/c.NATT_Checkout_PO';
import PriceLabel from '@salesforce/label/c.NATT_Checkout_Price';
import QTYLabel from '@salesforce/label/c.NATT_Checkout_QTY';
import ReviewOrderLabel from '@salesforce/label/c.NATT_Checkout_Review_Order';
import RushFeeLabel from '@salesforce/label/c.NATT_Checkout_Rush_Fee';
import RushOrderFeeLabel from '@salesforce/label/c.NATT_Checkout_Rush_Order_Fee';
import ShippingAddressLabel from '@salesforce/label/c.NATT_Checkout_Shipping_Address';
import SelectShippingMethodLabel from '@salesforce/label/c.NATT_Checkout_Select_Shipping_Method';
import ShippingMethodNameLabel from '@salesforce/label/c.NATT_Checkout_Shipping_Method';
import ShipmentTermsLabel from '@salesforce/label/c.NATT_Checkout_Shipment_Terms';
import StateProvinceLabel from '@salesforce/label/c.NATT_Checkout_State_Province';
import TelephoneLabel from '@salesforce/label/c.NATT_Checkout_Telephone';
import TotalLabel from '@salesforce/label/c.NATT_Checkout_Total';
import TotalProductsLabel from '@salesforce/label/c.NATT_Checkout_Total_Products';
import UOMLabel from '@salesforce/label/c.NATT_Checkout_UOM';
import UsePlaceOrderLabel from '@salesforce/label/c.NATT_Checkout_Use_Place_Order';

import AirLabel from '@salesforce/label/c.NATT_Checkout_Air';
import GroundLabel from '@salesforce/label/c.NATT_Checkout_Ground';
import SeaLabel from '@salesforce/label/c.NATT_Checkout_Sea';
import PickupLabel from '@salesforce/label/c.NATT_Checkout_Pickup';
import ReasonForShippingMethodLabel from '@salesforce/label/c.NATT_Checkout_Reason_for_Shipment_Method';
import SerialNumberLabel from '@salesforce/label/c.NATT_Checkout_Serial_Number';
import FlightItineraryLabel from '@salesforce/label/c.NATT_Checkout_Flight_Itinerary';
import FreightCompanyInformationLabel from '@salesforce/label/c.NATT_Checkout_Freight_Company_Information';
import AdditionalInformationLabel from '@salesforce/label/c.NATT_Checkout_Additional_Information';

import SeaItineraryLabel from '@salesforce/label/c.NATT_Checkout_Sea_Itinerary';//	NATT_Checkout_Freight_Company_Information
export default class NattCtbrCheckout extends NavigationMixin(LightningElement) {
    @api cartId;   
    @api orderType;
    @api poNumber;
    cPoNumber;
    cartSummary;
    error;
    @api availableActions = [];        
    @track deliveryMethod = [];
    deliveryMethodLoaded = false;
    deliveryMethodSelected;
    deliveryMethodId;
    isCustomerRouting=false;
    isDeliveryTermCollect=false;
    billingDeliveryTermOptions=[{label: 'COL - Collect', value:'COL'},{label:'CPU - Customer Pickup',value:'CPU'}];
    incotermValue = 'FCA';

    b2bWebCart = CART_OBJECT;    
    @track cartObject = CART_OBJECT;
    accountId;    
    deliveryAddressSelected;
    deliveryAddressOptions=[];
    deliveryAddressLoaded=false;
    deliveryMap = new Map();
    isCreateDropShip=false;
    contactPointAddressRtId;
    @api addressList;
    refreshVariable='a';
    canReceiveRushOrderCharge=false;
    rushOrderPercent=.05;
    timeVariable = new Date().getTime();
    showSummary=false;
    cartDetail;
    shippingMethodLabel;
    itinerary='';
    shippingMethodName;
    showShippingMethod = false;
    shippingMethodSelected = false;
    region;
    warehouse;
    showRushFee = true;
    
    /**
   * Custom Label creation
   */
     label = {
        AdditionalInformationLabel,
        AddressLabel,
        AirLabel,
        BackLabel,
        BillingDeliveryTermsLabel,
        CancelLabel,
        CityLabel,
        ContactEmailLabel,
        ContactNameLabel,
        ContactPhoneLabel,
        CreateDropShipLabel,
        CreateNewLabel,
        CustomerLabel,
        CustomerInformationLabel,
        CustomerNumberLabel,
        DeliverToAddressLabel,
        DescriptionLabel,
        EmailAddressLabel,
        ExtendedLabel,
        FlightItineraryLabel,
        FreightAccountNumberLabel,
        FreightCompanyInformationLabel,
        GroundLabel,
        NameLabel,
        NextLabel,
        OrderInformationLabel,
        OrderTotalLabel,
        OrderTypeLabel,
        PartDetailLabel,
        PartNumberLabel,
        PickupLabel,
        PlaceOrderLabel,
        PleaseEnteraValidEmailLabel,
        POLabel,
        PriceLabel,
        QTYLabel,
        ReasonForShippingMethodLabel,
        ReviewOrderLabel,
        RushFeeLabel,
        RushOrderFeeLabel,
        SeaItineraryLabel,
        SeaLabel,
        SelectShippingMethodLabel,
        SerialNumberLabel,
        ShippingAddressLabel,
        ShippingMethodNameLabel,
        ShipmentTermsLabel,
        StateProvinceLabel,
        TelephoneLabel,
        TotalLabel,
        TotalProductsLabel,
        UOMLabel,
        UsePlaceOrderLabel
     }

    connectedCallback(){
        //ensure that variables are reset during reload
        this.cartObject.NATT_Shipping_Method__c='';        
        this.cartObject.NATT_Shipment_Terms__c='';
        this.cartObject.NATT_Freight_Account_Number__c='';
        this.cartObject.NATT_Order_Contact__c='';
        this.cartObject.NATT_Order_Contact_Phone__c='';
        this.cartObject.NATT_Order_Contact_Email__c='';
        this.cartObject.NATT_JdeOrderType__c='';
        this.cartObject.PoNumber='';        
        //add in cart field to capture 
        this.cartObject.NATT_JdeOrderType__c = '4';                
    }    
    

    @wire(getAddressList,{accountId:'$accountId',refreshVariable:'$refreshVariable'})        
        wiredAddress({error,data}){   
            this.deliveryAddressOptions=[];
            this.error=undefined;  
            console.log('called '+this.accountId+':'+JSON.stringify(data));
            if(data){       
                this.addressList = data;
                let optionLabel;
                let street;
                let city;
                let state;
                let postalCode
                for(let i=0;i<data.length;i++){
                    this.deliveryMap.set(data[i].Id,data[i]);
                    street = data[i].NATT_Street__c==null?'':data[i].NATT_Street__c;
                    city = data[i].NATT_City__c==null?'':data[i].NATT_City__c;
                    state = data[i].NATT_State_Province__c==null?'':data[i].NATT_State_Province__c;
                    postalCode = data[i].NATT_Zip_Postal_Code__c==null?'':data[i].NATT_Zip_Postal_Code__c;
                    optionLabel = data[i].Name+': ' +street +' '+city+' '+state+' '+postalCode;                    
                    optionLabel+=data[i].NATT_B2B_Dropship__c?'(Dropship)':'';
                    const option = { label: optionLabel, value: data[i].Id };
                    this.deliveryAddressOptions = [...this.deliveryAddressOptions,option];
                }
               
                this.deliveryAddressLoaded=true;
            }else if(error){
                this.deliveryAddressLoaded=false;
                this.error=JSON.stringify(error);
                this.addressList=undefined;       
                console.log('error getAddressList:'+JSON.stringify(error));        
            }
        }

    @wire(getWebCart,{cartId:'$cartId'})        
        wiredCart({error,data}){ 
            console.log('Get Webcart');            
            if(data){                 
                this.b2bWebCart = data;
                this.accountId = data.AccountId;
                this.error=undefined;                
            }else if(error){
                this.error=JSON.stringify(error);
                this.b2bWebCart=undefined;       
                console.log('error getWebCart:'+JSON.stringify(error));        
            }
        }    

    @wire(getCartSummary,{
            cartId: '$cartId'
          })
            wiredSummary({error,data}){   
                console.log('cart Summary'); 
            if(data){                
              this.cartSummary = data;
              getCartDetail({cartId:this.cartId})
                .then((result)=>{
                    this.cartDetail=result;
                    console.log('cartDetail:'+JSON.stringify(this.cartDetail));
                });
              this.error=undefined;           
            }else if(error){
              this.cartSummary=undefined;
              this.error=error;
              console.log('error getCartSummary:'+JSON.stringify(error));
            }
      }

     get grandTotalAmount(){
          return this.cartSummary.grandTotalAmount;
      }
     get totalProductCount(){
        return this.cartSummary.uniqueProductCount;
    }
    get showRushFee(){
        if((this.orderType=='1'||this.orderType=='2') && this.canReceiveRushOrderCharge){
            return true;
        }
        return false;
    }
    get rushFee(){
        if(this.showRushFee){
            return (this.cartSummary.grandTotalAmount*this.rushOrderPercent);
        }else{
            return 0;
        }
    }
    get grandTotalAmountWithRushFee(){
        console.log('grandTotalAmount:'+this.grandTotalAmount+' : '+this.rushFee);
        console.log('grandTotalAmount value:'+(parseFloat(this.grandTotalAmount)+parseFloat(this.rushFee)));
        return (parseFloat(this.grandTotalAmount)+parseFloat(this.rushFee));
    }
    handleGoNext(){
        // this.deliveryMethodSelected = 'LTL - LTL GROUND';
        console.log('delivery method: '+this.cartObject.CTBR_Shipment_Method__c);
             
        // if(!this.deliveryAddressSelected){       
        if(!this.cartObject.CTBR_Shipment_Method__c){      
            const event = new ShowToastEvent({
                "title": "Deliver To Address is required",
                "message": "Please select the delivery address."                
            });
            this.dispatchEvent(event);
            return;
        }else if(this.cartObject.CTBR_Shipment_Method__c =='Same Day'){
            console.log('Rush Fee Selected');
            this.showRushFee = true;
        }else{
            this.showRushFee = false;
        }

        if(this.isInputValid()){
            this.handleShowSummary();
        }
    }
    handleFinish(){
        // this.doCompleteOrder();  
        console.log('calling show rush fee:'+this.showRushFee);
        if(this.showRushFee){        
            createRushFeeCartItem({cartId:this.cartId,deliveryMethodId:this.deliveryMethodSelected,rushFee:this.rushFee})
            .then(()=>{
                this.doCompleteOrder();
            }).catch(error =>{
                this.error=JSON.stringify(error);
                console.log('called show rush fee:'+JSON.stringify(error));
            })            
        }else{
            this.doCompleteOrder();
        }      
    }

    doCompleteOrder(){        
        console.log('deliveryMethodSelected:'+this.deliveryMethodSelected);

        updateWebCart({cartId:this.cartId,webCartJson:JSON.stringify(this.cartObject),deliveryMethodSelected:this.deliveryMethodId})
        .then(()=>{
            this.error=undefined;
            this.doNav();
        }).catch(error =>{
            this.error=JSON.stringify(error);
            console.log('called update delivery failed:'+JSON.stringify(error));
        })
    }
    doNav(){
        if (this.availableActions.find(action => action === 'NEXT')) {            
            const navigateNextEvent = new FlowNavigationNextEvent();
            this.dispatchEvent(navigateNextEvent);
        }
    }
    
    
    handleTermChange(event){        
        this.cartObject.NATT_Shipment_Terms__c=event.detail.value;        
        console.log('termChange: '+this.cartObject.NATT_Shipment_Terms__c);
        if(this.cartObject.NATT_Shipment_Terms__c==='COL'){
            this.isDeliveryTermCollect=true;
        }else{
            this.isDeliveryTermCollect=false;
            this.cartObject.NATT_Freight_Account_Number__c='';            
            if(this.cartObject.NATT_Shipment_Terms__c!='CPU'){
                if(this.orderType!='4'){
                    this.cartObject.NATT_Shipment_Terms__c='BIL';
                }else if(this.orderType=='4'){
                    this.cartObject.NATT_Shipment_Terms__c='PPD';
                }
            }
        }
    }

    handleChange(event){
        const field = event.target.name;
        if(field==='cName'){            
            this.cartObject.NATT_Order_Contact__c=event.target.value;
        }else if(field==='cPhone'){
            this.cartObject.NATT_Order_Contact_Phone__c=event.target.value;
        }else if(field==='cEmail'){
            this.cartObject.NATT_Order_Contact_Email__c=event.target.value;
        }else if(field==='freightAccountNumber'){
            this.cartObject.NATT_Freight_Account_Number__c=event.target.value;            
        }else if(field==='cPoNumber'){
            console.log('handle PO: ' + event.target.value);
            this.cartObject.PoNumber=event.target.value;   
            this.poNumber=event.target.value;         
        }else if(field==='shippingMethod'){
            this.deliveryMethodSelected=event.target.value;
            this.cartObject.NATT_Shipping_Method__c = 'AF';
            console.log('Delivery Method select: ' + this.deliveryMethodSelected);
        }else if(field==='freightPayment'){
            console.log('Freight Payment: ' + event.target.value);
            this.cartObject.CTBR_Freight_Payment__c =  event.target.value;
        }else if(field==='shipmentMethod'){
            console.log('Shipment Method: ' + event.target.value);
            this.cartObject.CTBR_Shipment_Method__c=this.deliveryMethodSelected=event.target.value;
            this.invokeDeliveryMethod();
             //this.shippingMethodLabel = event.target.options.find(opt => opt.value === event.target.value).label;
            //this.cartObject.CTBR_Shipment_Method__c =  event.target.value;
            //this.cartObject.CTBR_Shipment_Method__c=this.shippingMethodLabel.substring(0,this.shippingMethodLabel.indexOf(' '));
        }else if(field==='dealerComments'){
            console.log('Dealer Comments: ' + event.target.value);
            this.cartObject.NATT_Dealer_Comments__c =  event.target.value;
        }
    }   
    
    async invokeDeliveryMethod(){
        console.log('Inside delivery Methid')
        await getOrderDeliveryMethod({shippingMethodName: this.deliveryMethodSelected})
        .then(result => {
            console.log('Shipping Method Selected: ' + result);
            this.deliveryMethodId = result;
            //this.cartObject.NATT_Shipping_Method__c=this.deliveryMethodSelected;
        })
        .catch(error => {
            console.log('Shipping Method Grab FAILED: ' + error.body.message);
            this.error = error;

        })
    }
    //Handles Shipping Method selection to trigger different required fields
   /*handleShippingMethodChange(event){
        console.log('Shipping method is ----'+event.target.value);
        this.deliveryMethodSelected=event.target.value;         
        this.shippingMethodLabel = event.target.options.find(opt => opt.value === event.detail.value).label;
        this.cartObject.NATT_Shipping_Method__c=this.shippingMethodLabel.substring(0,this.shippingMethodLabel.indexOf(' '));        
    }*/


   /* @wire(getDeliveryOptions,{cartId:'$cartId',refreshVariable:'$timeVariable'})        
        wiredOptions({error,data}){            
            this.deliveryMethod=[];
            if(data){  
                for(let i=0;i<data.length;i++){
                    console.log('delivery option: ' + data[i].Name);
                    const option = { label: data[i].Name, value: data[i].DeliveryMethodId };
                    this.deliveryMethod = [...this.deliveryMethod,option];
                    console.log('inside for loop delivery methos is'+this.deliveryMethod);
                }
                this.deliveryMethodSelected=data[0].DeliveryMethodId;
                this.cartObject.NATT_Shipping_Method__c=data[0].Name.substring(0,data[0].Name.indexOf(' '));
                this.shippingMethodLabel=data[0].Name;
                this.deliveryMethodLoaded=true;
                this.error=undefined;                
            }else if(error){
                this.error=JSON.stringify(error);
                this.deliveryMethod=undefined;       
                console.log('error getDeliveryOptions:'+JSON.stringify(error));        
            }
        }*/

    handleDeliveryAddressChange(event){        
        this.deliveryAddressSelected = event.detail.value;
        let cPointAddress = this.deliveryMap.get(this.deliveryAddressSelected);        
        this.cartObject.NATT_Shipping_Street__c=cPointAddress.NATT_Street__c;
        this.cartObject.NATT_Shipping_City__c=cPointAddress.NATT_City__c;
        this.cartObject.NATT_Shipping_State__c=cPointAddress.NATT_State_Province__c;
        this.cartObject.NATT_Shipping_Postal_Code__c=cPointAddress.NATT_Zip_Postal_Code__c;
        this.cartObject.NATT_Shipping_Country__c=cPointAddress.NATT_Country__c;    
        this.cartObject.NATT_Shipping_Address_Id__c=cPointAddress.Id;
    }

    handleCreateDropShip(){
        this.contactPointAddressRtId = getContactPointAddressRt();
        this.isCreateDropShip=true;
    }
    handleCancelCreateDropShip(){
        this.isCreateDropShip=false;
    }
    handleDropShipSubmit(event){
        event.preventDefault();       // stop the form from submitting
        const fields = event.detail.fields;
        fields.ParentId=this.accountId;
        fields.AddressType='Shipping';
        fields.NATT_B2B_Dropship__c=true;
        this.template.querySelector('lightning-record-edit-form').submit(fields);
    }
    handleDropShipSuccess(){
        this.refreshVariable=this.refreshVariable+'a';
        refreshApex(this.addressList);
        const event = new ShowToastEvent({
            title: 'Success',
            message: 'Drop Ship created.',
            variant: 'success'
        });
        this.dispatchEvent(event);
        this.isCreateDropShip=false;        
    }

    handleDropShipError(event){
        //console.log('error:'+JSON.stringify(event));
        this.template.querySelectorAll('lightning-input-field').forEach(element => element.reportValidity());
    }

    handleCancel(){
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: {
                recordId: this.cartId,
                objectApiName: CART_OBJECT.objectApiName,
                actionName: 'view'
            }
        });
    }

    isInputValid() {
        let isValid = true;
        let inputFields = this.template.querySelectorAll('.validate');
        inputFields.forEach(inputField => {
            if(!inputField.checkValidity()) {
                inputField.reportValidity();
                isValid = false;
            }            
        });
        console.log('isValid:'+isValid);
        return isValid;
    }

    handleShowSummary(){        
        this.showSummary=true;
        console.log('this.showSummary:'+this.showSummary);
    }
    handleHideSummary(){
        this.showSummary=false;
        console.log('this.showSummary:'+this.showSummary);
    }    
     //4=Stock, 1=UnitDown, 2=SameDay
    get orderTypeLabel(){        
        if(this.orderType=='1'){
            return 'Unit Down';
        }else if(this.orderType=='2'){
            return 'Same Day';
        }else if(this.orderType=='4'){
            return 'Stock';
        }else{
            return 'Unknown';
        }
    }

    get shipmentTermLabel(){
        if(this.cartObject.NATT_Shipment_Terms__c=='BIL'){
            return 'Bill to Customer';
        }else if(this.cartObject.NATT_Shipment_Terms__c=='PPD'){
            return 'Prepaid Freight';
        }else if(this.cartObject.NATT_Shipment_Terms__c=='COL'){
            return 'Collect';
        }else if(this.cartObject.NATT_Shipment_Terms__c=='CPU'){
            return 'Customer Pickup';
        }else{
            return 'Unknown';
        }
    }

    get frieghtPaymentOptions(){
        return [
            { label: 'CIF', value: 'CIF' },
            { label: 'FOB', value: 'FOB' }
        ];
    }

    get shipmentMethodOptions(){
        return [
            { label: 'Air', value: 'Air' },
            { label: 'Road', value: 'Road' },
            { label: 'Same Day', value: 'Same Day' }
        ];
    }
}