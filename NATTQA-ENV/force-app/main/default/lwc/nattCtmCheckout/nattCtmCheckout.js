import { LightningElement,api,wire,track } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { ShowToastEvent } from 'lightning/platformShowToastEvent'
import getCartSummary from '@salesforce/apex/NATT_PpgCheckoutCon.getCartSummary';
import getDeliveryOptions from '@salesforce/apex/NATT_PpgCheckoutCon.getAvailableDeliveryGroupMethods';
import updateDelivery from '@salesforce/apex/NATT_PpgCheckoutCon.updateDelivery';
import updateWebCart from '@salesforce/apex/NATT_PpgCheckoutCon.updateWebCart';
import getWebCart from '@salesforce/apex/NATT_PpgCheckoutCon.getWebCart';
// import getAddressList from '@salesforce/apex/NATT_PpgCheckoutCon.getAddressList';
import getAddressList from '@salesforce/apex/NATT_CtmCheckoutCon.getAddressList';

import getContactPointAddressRt from '@salesforce/apex/NATT_PpgCheckoutCon.getContactPointAddressRt';
import getCanReceiveRushOrderCharge from '@salesforce/apex/NATT_PpgCheckoutBuyerGroup.getCanReceiveRushOrderCharge';
import createRushFeeCartItem from '@salesforce/apex/NATT_PpgCheckoutCon.createRushFeeCartItem';
import getOrderDeliveryMethod from '@salesforce/apex/NATT_CtmCheckoutCon.getOrderDeliveryMethod';
import getAccountRegion from '@salesforce/apex/NATT_CtmCheckoutCon.getAccountRegion';
/*** Salesforce Community Imports ***/
import communityId from "@salesforce/community/Id";
import { FlowAttributeChangeEvent, FlowNavigationNextEvent } from 'lightning/flowSupport';
import CART_OBJECT from '@salesforce/schema/WebCart';
import MailingPostalCode from '@salesforce/schema/Contact.MailingPostalCode';
import { refreshApex } from '@salesforce/apex';
// import getCartDetail from '@salesforce/apex/NATT_PpgCheckoutCon.getCartDetail';
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
import ProyectoFinal from '@salesforce/label/c.NATT_Proyecto_Final';
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

//import { getRecord } from 'lightning/uiRecordApi';
import USER_ID from '@salesforce/user/Id';
import getUserprofile from '@salesforce/apex/NATT_CtmCheckoutCon.getUserProfile';

import SeaItineraryLabel from '@salesforce/label/c.NATT_Checkout_Sea_Itinerary';//	NATT_Checkout_Freight_Company_Information
export default class NattCtmCheckout extends NavigationMixin(LightningElement) {
    @api cartId;   
    @api orderType;
    @api poNumber;
    cPoNumber;
    cartSummary;
    error;
    @api availableActions = [];        
    deliveryMethod = [];
    deliveryMethodLoaded = false;
    deliveryMethodSelected;
    deliveryMethodId;
    isCustomerRouting=false;
    isDeliveryTermCollect=false;
    billingDeliveryTermOptions=[{label: 'COL - Collect', value:'COL'},{label:'CPU - Customer Pickup',value:'CPU'}];
    incotermValue = 'FCA';
    userId=USER_ID;
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
    rushOrderPercent=0;
    timeVariable = new Date().getTime();
    showSummary=false;
    shippingMethodLabel;
    showAirFields=false;
    showPickupFields=false;
    showSeaFields=false;
    showGroundFields=false;
    itinerary='';
    shippingMethodName;
    showShippingMethod = false;
    showMexicoRegion = false;
    shippingMethodSelected = false;
    region;
    mexicoRegion;
    ProfileName;

    // Added as part of CTM Panama Warehouse
    @track cartDetail;
    @track warehouse;
    @track warehouseSelected;
    ctmMexicoAcc;
    accName;
    warehouseLabel;
    //  /**
    //  * Gets the effective account - if any - of the user viewing the product.
    //  *
    //  */
    //   @api
    //   get effectiveAccountId() {
    //     return this._effectiveAccountId;
    //   }
  
    //   set effectiveAccountId(value) {
    //     this._effectiveAccountId = value;
    //   }

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
        ProyectoFinal,
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
        this.cartObject.Cliente_Proyecto_Final__c='';
        this.cartObject.Client_Final_Project__c='';
        this.cartObject.NATT_Incoterm__c='FCA';
        // this.showShippingMethod = false;
        //assigns default Shipping Method to complete order if no method is selected
        this.cartObject.NATT_Shipping_Method__c = 'LTL';
        this.cartObject.NATT_CTM_Itinerary__c='';
        this.cartObject.NATT_CTM_Reason_for_Shipment_Method__c='';
        this.cartObject.NATT_CTM_Serial_Number__c='';
        this.cartObject.NATT_CTM_Freight_Company_Information__c='';
        //this.cartObject.NATT_Warehouse__c = '';
        //default value from FCA Incoterm so user does not have to manually select FCA
        //add in cart field to capture 
        this.cartObject.NATT_JdeOrderType__c = '4';
        //4=Stock, 1=UnitDown, 2=SameDay
        if(this.orderType!='4'){
            this.cartObject.NATT_Shipment_Terms__c='BIL';
        }else if(this.orderType=='4'){
            this.cartObject.NATT_Shipment_Terms__c='PPD';
        }
        
        //payment terms
        this.cartObject.NATT_CTM_Payment_Terms__c='60 días (si requiere un cambio en los términos favor de contactar a su representante de Servicio a Clientes)';
        console.log('NATT_Shipment_Terms__c:'+this.cartObject.NATT_Shipment_Terms__c);
    }

    //Fetch User Profile Details
    @wire(getUserprofile,{userId:'$userId'})
       wiredData({error,data}){
        if(data){
            this.ProfileName=data.Profile.Name;
            console.log('get User Profile Name:'+data.Profile.Name);
            console.log('get User Profile details:'+JSON.stringify(data));
        }
        else if(error){
            console.log('error in user Profile Details: '+JSON.stringify(error));
       }
    }
    //Gets Region of the User's Account to determine correct Warehouse
    @wire(getAccountRegion,{accountId:'$accountId'})
        wiredAccount({error,data}){
            if(data){                
                // console.log('Account Region:'+JSON.stringify(data));
                this.region = data.NATT_Region__c;
                this.accName = data.Name;
                console.log('REGION: ' + this.region);
                this.cartObject.NATT_Incoterm__c = 'FCA';
                if(this.region === 'Latin America'){
                    this.showMexicoRegion=false;
                    this.showShippingMethod = true;
                }else if(this.region === 'Mexico'){
                    this.mexicoRegion=this.region;
                    this.showMexicoRegion=true;
                    this.showShippingMethod = false;
                }

                // this.error=undefined;
                console.log('Finish Wired Account');
            }else if(error){
                this.error=JSON.stringify(error);                 
                console.log('error in getAccountRegion: '+JSON.stringify(error));        
            }
        }

    @wire(getCanReceiveRushOrderCharge,{accountId:'$accountId'})
        wiredRushOrder({error,data}){
            console.log('Wired Rush Order');
            if(data){                
                console.log('canReceiveRushOrderCharge:'+JSON.stringify(data));
                this.rushOrderPercent = data;
                if(this.rushOrderPercent>0){
                    this.canReceiveRushOrderCharge = true;                
                }
                this.error=undefined;
            }else if(error){
                this.canReceiveRushOrderCharge=false;
                this.error=JSON.stringify(error);                 
                console.log('error in getCanReceiveRushOrderCharge: '+JSON.stringify(error));        
            }
        }

    @wire(getAddressList,{accountId:'$accountId',refreshVariable:'$refreshVariable'})        
        wiredAddress({error,data}){      
            console.log('Address List');      
            this.deliveryAddressOptions=[];
            if(data){  
                console.log('address data: ' + data.toString());         
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
                this.error=undefined;  
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

    // @wire(getDeliveryOptions,{cartId:'$cartId',refreshVariable:'$timeVariable'})        
    //     wiredOptions({error,data}){            
    //         this.deliveryMethod=[];
    //         if(data){ 
    //             for(let i=0;i<data.length;i++){
    //                 console.log('delivery option: ' + data[i].Name);
    //                 const option = { label: data[i].Name, value: data[i].DeliveryMethodId };
    //                 this.deliveryMethod = [...this.deliveryMethod,option];
    //             }
    //             this.deliveryMethodSelected=data[0].DeliveryMethodId;
    //             this.cartObject.NATT_Shipping_Method__c=data[0].Name.substring(0,data[0].Name.indexOf(' '));
    //             this.shippingMethodLabel=data[0].Name;
    //             this.deliveryMethodLoaded=true;
    //             this.error=undefined;                
    //         }else if(error){
    //             this.error=JSON.stringify(error);
    //             this.deliveryMethod=undefined;       
    //             console.log('error getDeliveryOptions:'+JSON.stringify(error));        
    //         }
    //     } 

    @wire(getCartSummary,{
            cartId: '$cartId'
          })
            wiredSummary({error,data}){   
                //console.log('cart Summary'+ this.cartId); 
            if(data){                
              this.cartSummary = data;
              getCartDetail({cartId:this.cartId})
                .then((result)=>{
                    this.cartDetail=result;
                    console.log('cartDetail:'+JSON.stringify(this.cartDetail));
                    this.warehouseSelected = this.cartDetail?.wc?.NATT_Warehouse__c || '';
                    this.cartObject.NATT_Warehouse__c = this.warehouseSelected;
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
        if(this.ProfileName='CTM Full Access Community'){
            
        if((!this.cartObject.Client_Final_Project__c.length=='0') && !this.poNumber.length=='0'   ){
        if(!this.deliveryMethodSelected){
            this.deliveryMethodSelected = 'BW1 - BESTWAY';
        }
        
        if(!this.deliveryAddressSelected){
            console.log('NO ADDRESS SELECTED');
            const event = new ShowToastEvent({
                "title": "Deliver To Address is required",
                "message": "Please selt the delivery address."                
            });
            this.dispatchEvent(event);
            return;
        }

        //logic to get OrderDelvieryMethod
        getOrderDeliveryMethod({shippingMethodName: this.deliveryMethodSelected})
        .then(result => {
            console.log('Shipping Method Selected: ' + result);
            this.deliveryMethodId = result;
        })
        .catch(error => {
            console.log('Shipping Method Grab FAILED: ' + error.body.message);
            this.error = error;

        })
        if(this.isInputValid()){
            this.handleShowSummary();
        }
        }
        else{
            const event = new ShowToastEvent({
                "title": "Mandatory Field Required.",
                "message": "Please fill all Mandatory fields."                
            });
            this.dispatchEvent(event);
            return;
        }
    }
    else {
       // console.log('I am in the LATIM Block');
        //Delivery Method Selection assigned so this component will work with existing checkout flow
        //console.log('delivery method: '+this.deliveryMethodSelected);
         
         if(!this.deliveryMethodSelected){
             this.deliveryMethodSelected = 'BW1 - BESTWAY';
 
         }
         console.log('Delivery Method Selected: ' + this.deliveryMethodSelected);
         console.log('Delivery Address Selected: ' + this.deliveryAddressSelected);
         if(!this.deliveryAddressSelected){
             console.log('NO ADDRESS SELECTED');
             const event = new ShowToastEvent({
                 "title": "Deliver To Address is required",
                 "message": "Please select the delivery address."                
             });
             this.dispatchEvent(event);
             return;
         }
 
         //logic to get OrderDelvieryMethod
         getOrderDeliveryMethod({shippingMethodName: this.deliveryMethodSelected})
         .then(result => {
             console.log('Shipping Method Selected: ' + result);
             this.deliveryMethodId = result;
         })
         .catch(error => {
             console.log('Shipping Method Grab FAILED: ' + error.body.message);
             this.error = error;
 
         })
         if(this.isInputValid()){
             this.handleShowSummary();
         }
    }
    }
    handleFinish(){
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
        console.log('COMPLETE ORDER - calling update delivery with:'+this.cartId+':'+JSON.stringify(this.cartObject));  
        console.log('COMPLETE ORDER - Cart Id: ' + this.cartId);  
        console.log('COMPLETE ORDER - Stringify Id: ' + JSON.stringify(this.cartObject)); 
        console.log('COMPLETE ORDER - Delivery Method Order Complete: ' + this.deliveryMethodId);     
        updateWebCart({cartId:this.cartId,webCartJson:JSON.stringify(this.cartObject),deliveryMethodSelected:this.deliveryMethodId})
        .then(()=>{
            this.doNav();
        }).catch(error =>{
            this.error=error.body?.pageErrors[0].message;
            console.log('called update delivery failed:'+JSON.stringify(error));
        })
    }
    doNav(){
        if (this.availableActions.find(action => action === 'NEXT')) {            
            const navigateNextEvent = new FlowNavigationNextEvent();
            this.dispatchEvent(navigateNextEvent);
        }
    }
    handleDeliveryChange(event){
        this.isCustomerRouting=false;
        this.deliveryMethodSelected=event.detail.value;        
        this.shippingMethodLabel = event.target.options.find(opt => opt.value === event.detail.value).label;        
        if(this.shippingMethodLabel === 'CR1 - CUSTOMER ROUTING'){            
            this.isCustomerRouting=true;
        }else{
            this.cartObject.NATT_Freight_Account_Number__c='';
            if(this.orderType!='4'){
                this.cartObject.NATT_Shipment_Terms__c='BIL';
            }else if(this.orderType=='4'){
                this.cartObject.NATT_Shipment_Terms__c='PPD';
            }
            this.isDeliveryTermCollect=false;
        }
        this.cartObject.NATT_Shipping_Method__c=this.shippingMethodLabel.substring(0,this.shippingMethodLabel.indexOf(' '));
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
        }else if(field==='incoterm'){
            this.assignWarehouse(event);
        }else if(field==='cCliente/Proyecto'){
            console.log('New Field Logic: ' + event.target.value);
            this.cartObject.Client_Final_Project__c=event.target.value;
        }

        // else if(field==='itinerary'){
        //     this.itinerary = event.target.value;
        //     console.log('Itinerary Value: ' + this.itinerary);
        //     this.cartObject.NATT_CTM_Itinerary__c=event.target.value;
        // }else if(field==='shipmentReason'){
        //     console.log('shipmentReason: ' + event.target.value);
        //     this.cartObject.NATT_CTM_Reason_for_Shipment_Method__c=event.target.value;
        // }else if(field==='serialNumber'){
        //     console.log('serialValue: ' + event.target.value);
        //     this.cartObject.NATT_CTM_Serial_Number__c=event.target.value;        
        // }else if(field==='freightCompanyInformation'){
        //     console.log('freight info: ' + event.target.value);
        //     this.cartObject.NATT_CTM_Freight_Company_Information__c=event.target.value;
        // }
    }

    //Assign Warehouse value based on Incoterm & Region
    assignWarehouse(event){
        console.log('incoterm: ' + event.target.value);
        this.cartObject.NATT_Incoterm__c=event.target.value;
        this.orderType = '4';
        this.cartObject.NATT_JdeOrderType__c = '4';
        if(this.region == 'Mexico'){
            if(event.target.value == 'FCA'){
                this.mexicoRegion=this.region;
                console.log('MEXICO FCA');
               // this.warehouse = 'MEX';
                this.shippingMethodSelected = false;
                //allow for address selection
                this.cartObject.NATT_Warehouse__c='MEX';
            }else if(event.target.value == 'EXW'){
                this.mexicoRegion=this.region;
                console.log('MEXICO EXW');
                this.warehouse = 'MEX';
                //this.cartObject.NATT_Warehouse__c='MEX';
                this.shippingMethodSelected = false;
                this.deliveryMethodSelected = '';
                //ship to Ryder
            }
        }
        if(this.region == 'Latin America'){
            if(event.target.value == 'FCA'){
                console.log('Latin America FCA');
                this.showShippingMethod = true;
                this.shippingMethodSelected = true;
                //this.warehouse = 'MIA';
                //this.cartObject.NATT_Warehouse__c='MIA';
                //allow for address selection
            }else if(event.target.value == 'EXW'){
                console.log('Latin America EXW');
                this.showShippingMethod = false;
                this.shippingMethodSelected = false;
                //this.warehouse = 'MIA';
                //this.cartObject.NATT_Warehouse__c='MIA';
                this.deliveryMethodSelected = '';
                //ship to Ryder
            }
        }
    }

    //Handles Shipping Method selection to trigger different required fields
    handleShippingMethodChange(event){
        console.log('handle ship method change');
        const field = event.target.value;
        console.log('Field Value: ' + field);
        this.shippingMethodName = field;
        // if(field == '2DmP0000000CaWZKA0'){
        if(field == 'AF - AIR FREIGHT'){
            this.cartObject.NATT_Shipping_Method__c = 'AF';
            this.shippingMethodSelected = true;
            // this.showAirFields = true;
            // this.showSeaFields = false;
            // this.showPickupFields = false;
            // this.showGroundFields = false;
            this.orderType=='4';
        }else if(field == 'OF - OCEAN FREIGHT'){
            this.cartObject.NATT_Shipping_Method__c = 'OF';
            this.shippingMethodSelected = true;

            // this.showAirFields = false;
            // this.showSeaFields = true;
            // this.showPickupFields = false;
            // this.showGroundFields = false;
            this.orderType=='4';
        }else if(field == 'LTL - LTL GROUND'){
            this.cartObject.NATT_Shipping_Method__c = 'LTL';
            this.shippingMethodSelected = true;

            // this.showAirFields = false;
            // this.showSeaFields = false;
            // this.showPickupFields = false;
            // this.showGroundFields = true;
            this.orderType=='2';
        }else{
            this.shippingMethodSelected = false;

            // this.showAirFields = false;
            // this.showSeaFields = false;
            // this.showPickupFields = false;
            // this.showGroundFields = false;
        }
        this.deliveryMethodSelected=event.target.value;
        // this.cartObject.NATT_Shipping_Method__c = 'AF';
    }


    getShippingInfo(){
        
        getDeliveryOptions( {UserId:UserId, CommunityId:CommunityId, EffectiveAccountId:this._effectiveAccountId})
            .then(result => {
                console.log('getCartList Success');
                this.cartList = result;
                result.forEach(WebCart => {
                    if (WebCart.NATT_Is_Cart_Primary__c == true){
                        this.primaryCartName = WebCart.Name;
                    }
                    // WebCart.Status = 'Active';
                });
                this.error = undefined;
            })
            .catch(error => {
                console.log('Change FAILED: ' + error.body.message);
                this.error = error;
                this.accounts = undefined;
            })
        }

    handleDeliveryAddressChange(event){        
        this.deliveryAddressSelected = event.detail.value;
        let cPointAddress = this.deliveryMap.get(this.deliveryAddressSelected);
        // this.cartObject.NATT_Shipping_Street__c=cPointAddress.Street;
        // this.cartObject.NATT_Shipping_City__c=cPointAddress.City;
        // this.cartObject.NATT_Shipping_State__c=cPointAddress.State;
        // this.cartObject.NATT_Shipping_Postal_Code__c=cPointAddress.PostalCode;
        // this.cartObject.NATT_Shipping_Country__c=cPointAddress.Country;    
        // this.cartObject.NATT_Shipping_Address_Id__c=cPointAddress.NATT_Address__c;    
        // this.cartObject.NATT_Contact_Point_Address__c=cPointAddress.Id;
        this.cartObject.NATT_Shipping_Street__c=cPointAddress.NATT_Street__c;
        this.cartObject.NATT_Shipping_City__c=cPointAddress.NATT_City__c;
        this.cartObject.NATT_Shipping_State__c=cPointAddress.NATT_State_Province__c;
        this.cartObject.NATT_Shipping_Postal_Code__c=cPointAddress.NATT_Zip_Postal_Code__c;
        this.cartObject.NATT_Shipping_Country__c=cPointAddress.NATT_Country__c;    
        this.cartObject.NATT_Shipping_Address_Id__c=cPointAddress.Id;    
        // this.cartObject.NATT_Contact_Point_Address__c=cPointAddress.Id;
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

    get incotermOptions() {
        return [
            { label: 'FCA', value: 'FCA' },
            { label: 'EXW', value: 'EXW' }
        ];
    }

    get shippingMethodOptions() {
        return [
            // { label: 'AF - AIR FREIGHT', value: '2DmP0000000CaWZKA0' },
            { label: AirLabel, value: 'AF - AIR FREIGHT' },
            { label: GroundLabel, value: 'LTL - LTL GROUND' },
            { label: SeaLabel, value: 'OF - OCEAN FREIGHT' }
            // ,
            // { label: PickupLabel, value: 'WCL - WILL CALL' } //PKU
        ];
    }

    refreshCartSummary() {
        this.cartId = this.cartId; // This triggers the wire function to refresh
    }
    
}