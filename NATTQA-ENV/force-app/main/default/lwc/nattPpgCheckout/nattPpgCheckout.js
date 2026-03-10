import { LightningElement,api,wire,track } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getCartSummary from '@salesforce/apex/NATT_PpgCheckoutCon.getCartSummary';
import getDeliveryOptions from '@salesforce/apex/NATT_PpgCheckoutCon.getAvailableDeliveryGroupMethods';
import updateDelivery from '@salesforce/apex/NATT_PpgCheckoutCon.updateDelivery';
import updateWebCart from '@salesforce/apex/NATT_PpgCheckoutCon.updateWebCart';
import getWebCart from '@salesforce/apex/NATT_PpgCheckoutCon.getWebCart';
import getAddressList from '@salesforce/apex/NATT_PpgCheckoutCon.getAddressList';
import getContactPointAddressRt from '@salesforce/apex/NATT_PpgCheckoutCon.getContactPointAddressRt';
import getCanReceiveRushOrderCharge from '@salesforce/apex/NATT_PpgCheckoutBuyerGroup.getCanReceiveRushOrderCharge';
import createRushFeeCartItem from '@salesforce/apex/NATT_PpgCheckoutCon.createRushFeeCartItem';
/*** Salesforce Community Imports ***/
import communityId from "@salesforce/community/Id";
import { FlowAttributeChangeEvent, FlowNavigationNextEvent } from 'lightning/flowSupport';
import CART_OBJECT from '@salesforce/schema/WebCart';
import MailingPostalCode from '@salesforce/schema/Contact.MailingPostalCode';
import { refreshApex } from '@salesforce/apex';
import getCartDetail from '@salesforce/apex/NATT_PpgCheckoutCon.getCartDetail';
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
import ShippingMethodLabel from '@salesforce/label/c.NATT_Checkout_Shipping_Method';
import ShipmentTermsLabel from '@salesforce/label/c.NATT_Checkout_Shipment_Terms';
import StateProvinceLabel from '@salesforce/label/c.NATT_Checkout_State_Province';
import TelephoneLabel from '@salesforce/label/c.NATT_Checkout_Telephone';
import TotalLabel from '@salesforce/label/c.NATT_Checkout_Total';
import TotalProductsLabel from '@salesforce/label/c.NATT_Checkout_Total_Products';
import UOMLabel from '@salesforce/label/c.NATT_Checkout_UOM';
import UsePlaceOrderLabel from '@salesforce/label/c.NATT_Checkout_Use_Place_Order';
import { RefreshEvent } from 'lightning/refresh';


export default class NattPpgCheckout extends NavigationMixin(LightningElement) {

@api cartId;   
@api orderType;
@api poNumber;
cartSummary;
error;
@api availableActions = [];        
deliveryMethod = [];
deliveryMethodLoaded = false;
deliveryMethodSelected;
isCustomerRouting=false;
isDeliveryTermCollect=false;
billingDeliveryTermOptions=[{label: 'COL - Collect', value:'COL'},{label:'CPU - Customer Pickup',value:'CPU'}];
    
b2bWebCart = CART_OBJECT;    
@track cartObject = CART_OBJECT;
accountId;    
deliveryAddressSelected;
// dropshipAddresses=[];
// dropshipAddresses=[];
// partsShipToAddresses=[];
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
cartDetail;
shippingMethodLabel;
@track NameFieldValue;
@track nameFieldError = '';
@track shippingAddressName;


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
    AddressLabel,
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
    FreightAccountNumberLabel,
    NameLabel,
    NextLabel,
    OrderInformationLabel,
    OrderTotalLabel,
    OrderTypeLabel,
    PartDetailLabel,
    PartNumberLabel,
    PlaceOrderLabel,
    PleaseEnteraValidEmailLabel,
    POLabel,
    PriceLabel,
    QTYLabel,
    ReviewOrderLabel,
    RushFeeLabel,
    RushOrderFeeLabel,
    SelectShippingMethodLabel,
    ShippingAddressLabel,
    ShippingMethodLabel,
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
    //4=Stock, 1=UnitDown, 2=SameDay
    if(this.orderType!='4'){
        this.cartObject.NATT_Shipment_Terms__c='BIL';
    }else if(this.orderType=='4'){
        this.cartObject.NATT_Shipment_Terms__c='PPD';
    }
    console.log('NATT_Shipment_Terms__c:'+this.cartObject.NATT_Shipment_Terms__c);  
         
}


@wire(getCanReceiveRushOrderCharge,{accountId:'$accountId'})
    wiredRushOrder({error,data}){
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


/* @wire(getAddressList,{accountId:'$accountId',refreshVariable:'$refreshVariable'})        
    wiredAddress({error,data}){            
        this.deliveryAddressOptions=[];
        let partsShipToAddresses = [];
        console.log('parts' + partsShipToAddresses );

        let dropshipAddresses = [];
        console.log('drop'+ dropshipAddresses);

        if(data){                
            this.addressList = data;
            let optionLabel;
            let street;
            let city;
            let state;
            let postalCode
            for(let i=0;i<data.length;i++){
                this.deliveryMap.set(data[i].Id,data[i]);
                street = data[i].Street==null?'':data[i].Street;
                city = data[i].City==null?'':data[i].City;
                state = data[i].State==null?'':data[i].State;
                postalCode = data[i].PostalCode==null?'':data[i].PostalCode;
                optionLabel = data[i].Name+': ' +street +' '+city+' '+state+' '+postalCode;                    
                optionLabel+=data[i].NATT_B2B_Dropship__c?'(Dropship)':'';
                const option = { label: optionLabel, value: data[i].Id };
                if (data[i].NATT_B2B_Dropship__c) {
                    dropshipAddresses.push(option);
                    } else {
                    partsShipToAddresses.push(option);
                    }
        
                this.deliveryAddressOptions = [...partsShipToAddresses, ...dropshipAddresses];
                
            }
            this.error=undefined;  
            this.deliveryAddressLoaded=true;
        }else if(error){
            this.deliveryAddressLoaded=false;
            this.error=JSON.stringify(error);
            this.addressList=undefined;       
            console.log('error getAddressList:'+JSON.stringify(error));        
        }
            refreshApex(this.addressList);   

    } */

@wire(getWebCart,{cartId:'$cartId'})        
    wiredCart({error,data}){            
        if(data){                 
            this.b2bWebCart = data;
            this.accountId = data.AccountId;
            this.fetchAddressData();
            this.error=undefined;                
        }else if(error){
            this.error=JSON.stringify(error);
            this.b2bWebCart=undefined;       
            console.log('error getWebCart:'+JSON.stringify(error));        
        }
    }

@wire(getDeliveryOptions,{cartId:'$cartId',refreshVariable:'$timeVariable'})        
    wiredOptions({error,data}){            
        this.deliveryMethod=[];
        if(data){ 
            for(let i=0;i<data.length;i++){
                console.log('delivery option: ' + data[i].Name);
                const option = { label: data[i].Name, value: data[i].DeliveryMethodId };
                this.deliveryMethod = [...this.deliveryMethod,option];
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
    }
    

@wire(getCartSummary,{
        cartId: '$cartId'
        })
        wiredSummary({error,data}){   
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
    if(!this.deliveryMethodSelected){
        const event = new ShowToastEvent({
            "title": "Shipping method is required",
            "message": "Please select the shipping method."                
        });
        this.dispatchEvent(event);
        return;
    }

    if(!this.deliveryAddressSelected){
        const event = new ShowToastEvent({
            "title": "Deliver To Address is required",
            "message": "Please select the delivery address."                
        });
        this.dispatchEvent(event);
        return;
    }

    if(this.isInputValid()){
        this.handleShowSummary();
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
    console.log('calling update delivery with:'+this.cartId+':'+JSON.stringify(this.cartObject));  
    console.log('Delivery Method Order Complete: ' + this.deliveryMethodSelected);     
    
    updateWebCart({cartId:this.cartId,webCartJson:JSON.stringify(this.cartObject),deliveryMethodSelected:this.deliveryMethodSelected})
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
    }
    
}

handleDeliveryAddressChange(event){        
    this.deliveryAddressSelected = event.detail.value;
    console.log('Selected Address--'+ this.deliveryAddressSelected);
    let cPointAddress = this.deliveryMap.get(this.deliveryAddressSelected);
    console.log('Selected Address1--'+ JSON.stringify(cPointAddress));
    this.cartObject.NATT_Shipping_Street__c=cPointAddress.Street;
    this.cartObject.NATT_Shipping_City__c=cPointAddress.City;
    this.cartObject.NATT_Shipping_State__c=cPointAddress.State;
    this.cartObject.NATT_Shipping_Postal_Code__c=cPointAddress.PostalCode;
    this.cartObject.NATT_Shipping_Country__c=cPointAddress.Country;    
    this.cartObject.NATT_Shipping_Address_Id__c=cPointAddress.NATT_Address__c;    
    this.cartObject.NATT_Contact_Point_Address__c=cPointAddress.Id; 
    this.shippingAddressName = cPointAddress.Name;       
}

handleCreateDropShip(){
    this.contactPointAddressRtId = getContactPointAddressRt();
    this.isCreateDropShip=true;

}
handleAddressCreated(){
    this.isCreateDropShip=false;
    this.refreshVariable = new Date().getTime();
    this.fetchAddressData();
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
    const nameValue = fields.Name;
    //Added by rajsekharreddy Kotella for CCRN-1171 
    if (nameValue && nameValue.length > 40) {
        this.dispatchEvent(
            new ShowToastEvent({
                title: 'ERROR!',
                message: 'Name should not be greater than 40 characters.',
                variant: 'error'
            })
        );
        return;
    }
    this.template.querySelector('lightning-record-edit-form').submit(fields);
}
    handleDropShipSuccess(){
        this.refreshVariable=this.refreshVariable+'a';
        this.fetchAddressData();         
        const event = new ShowToastEvent({
            title: 'Success',
            message: 'Drop Ship created.',
            variant: 'success'
        });
            this.dispatchEvent(event);

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

    fetchAddressData() {
        this.deliveryAddressLoaded = false;
        getAddressList ({strAccountId: this.accountId, strRefreshVariable:this.refreshVariable})
        .then((result)=>{        
            this.deliveryAddressOptions=[];
            let partsShipToAddresses = [];
            let dropshipAddresses = [];
            
            this.addressList = result;
            let optionLabel;
            let street;
            let city;
            let state;
            let postalCode;

            for(let i=0;i<this.addressList.length;i++) {
                this.deliveryMap.set(this.addressList[i].Id,this.addressList[i]);
                street = this.addressList[i].Street==null?'':this.addressList[i].Street;
                city = this.addressList[i].City==null?'':this.addressList[i].City;
                state = this.addressList[i].State==null?'':this.addressList[i].State;
                postalCode = this.addressList[i].PostalCode==null?'':this.addressList[i].PostalCode;
                optionLabel = this.addressList[i].Name+': ' +street +' '+city+' '+state+' '+postalCode;                    
                optionLabel+=this.addressList[i].NATT_B2B_Dropship__c?'(Dropship)':'';
                const option = { label: optionLabel, value: this.addressList[i].Id };
                if (this.addressList[i].NATT_B2B_Dropship__c) {
                    dropshipAddresses.push(option);
                } else {
                    partsShipToAddresses.push(option);
                }
                
                this.deliveryAddressOptions = [...partsShipToAddresses, ...dropshipAddresses];                
            }
           

             setTimeout(() => {
                this.deliveryAddressLoaded = true;
            }, 0);
            //this.deliveryAddressLoaded = true;
            this.isCreateDropShip=false; 
        }).catch((error)=>{
            this.error = error;
            this.deliveryAddressLoaded = false;
            this.isCreateDropShip=false; 
            console.error('error in fetchAddressData ',JSON.stringify(error));
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

//Added by rajsekharreddy Kotella for CCRN-1171
get addressNameAndStreet() {
    const shipAddressName = this.shippingAddressName; 
    const name = (shipAddressName !== null && shipAddressName !== undefined) ? shipAddressName + ': ' : '';
    console.log('Street Address',+name);
    const street = this.cartObject ? this.cartObject.NATT_Shipping_Street__c : ''; 
    console.log('Street Address', `${name} ${street}`);
    return `${name} ${street}`; 
}


handleNameChange(event) {
    const nameFieldValue = event.target.value;
    console.log('nameFieldValue-'+ nameFieldValue);
    if (nameFieldValue && nameFieldValue.length > 40) {
        this.nameFieldError = 'Name should not be greater than 40 characters.';
    } else {
        this.nameFieldError = '';
    }
  }
}