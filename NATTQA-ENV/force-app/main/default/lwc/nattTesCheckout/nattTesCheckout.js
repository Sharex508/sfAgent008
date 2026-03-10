import { LightningElement,api,wire,track } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { ShowToastEvent } from 'lightning/platformShowToastEvent'
import getCartSummary from '@salesforce/apex/NATT_TesCheckoutCon.getCartSummary';
import getDeliveryOptions from '@salesforce/apex/NATT_TesCheckoutCon.getAvailableDeliveryGroupMethods';
import updateWebCart from '@salesforce/apex/NATT_TesCheckoutCon.updateWebCart';
import getWebCart from '@salesforce/apex/NATT_TesCheckoutCon.getWebCart';
import getAddressList from '@salesforce/apex/NATT_TesCheckoutCon.getAddressList';
import getContactPointAddressRt from '@salesforce/apex/NATT_TesCheckoutCon.getContactPointAddressRt';
import { FlowAttributeChangeEvent, FlowNavigationNextEvent } from 'lightning/flowSupport';
import CART_OBJECT from '@salesforce/schema/WebCart';
import { refreshApex } from '@salesforce/apex';
import getCartDetail from '@salesforce/apex/NATT_TesCheckoutCon.getCartDetail';
import doAuth from '@salesforce/apex/NattTesAuthorizeDotNet.doAuth';
import getPaymentOptionList from '@salesforce/apex/NATT_TesCheckoutCon.getPaymentOptionList';
import getUserInfo from '@salesforce/apex/NATT_TesCheckoutCon.getUserInfo';
import userId from '@salesforce/user/Id';
import getTaxAmount from '@salesforce/apex/NattTesAvalaraTax.getTaxAmount';

//import updateDelivery from '@salesforce/apex/NATT_TesCheckoutCon.updateDelivery';
//import getCanReceiveRushOrderCharge from '@salesforce/apex/NATT_TesCheckoutBuyerGroup.getCanReceiveRushOrderCharge';
//import createRushFeeCartItem from '@salesforce/apex/NATT_TesCheckoutCon.createRushFeeCartItem';
// /*** Salesforce Community Imports ***/
// import communityId from "@salesforce/community/Id";
//import MailingPostalCode from '@salesforce/schema/Contact.MailingPostalCode';

export default class NattTesCheckout extends NavigationMixin(LightningElement) {
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
    userContact;
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
    cartDetail;
    shippingMethodLabel;
    isStep1=true;
    isStep2=false;
    isStep3=false;
    ccVisible=true;
    ccNameOnCard;
    ccCardType;
    ccCardNumber;
    ccCvv;
    ccExpiryMonth;
    ccExpiryYear;
    wtVisible=false;
    invoiceVisible=false;
    countryFieldValue;
    stateFieldValue;
    stateDisabled = false;
    estimatedTax=0;
    taxPercent=0;
    
    @track pmOptions=[];

    connectedCallback(){
        console.log('Cart ID: ' + this.cartId);
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
        this.getUserInfoJs();
        console.log('getUserInfoJs complete');
    }
/*
     @wire(getUserInfo,{userId:userId})        
     wiredUserInfo({error,data}){            
        this.userContact=data;
        console.log('Name: ' + this.userContact.Name);        
     }*/

        
    getUserInfoJs(){
        console.log('User Id: ' + userId);
        getUserInfo({userId:userId})
        .then(result => {
            this.userContact=result;
            console.log('Name: ' + this.userContact.Name);            
            this.cartObject.NATT_Order_Contact__c = this.userContact.Name;
            this.cartObject.NATT_Order_Contact_Email__c = this.userContact.Email;
            this.cartObject.NATT_Order_Contact_Phone__c = this.userContact.Phone;
            this.cartObject.BillingStreet = this.userContact.Account.NATT_Address_Physical__r.NATT_Street__c;
            this.cartObject.BillingCity = this.userContact.Account.NATT_Address_Physical__r.NATT_City__c;
            this.cartObject.BillingState = this.userContact.Account.NATT_Address_Physical__r.NATT_State_Province__c;
            this.cartObject.BillingPostalCode = this.userContact.Account.NATT_Address_Physical__r.NATT_Zip_Postal_Code__c;
            this.cartObject.BillingCountry = this.userContact.Account.NATT_Address_Physical__r.NATT_Country__c;
        })
        .catch(error => {
            console.log('getUserInfoJs FAILED load: ' + error.body.message);
            this.error = error;
        })
    }

    @wire(getAddressList,{accountId:'$accountId',refreshVariable:'$refreshVariable'})        
        wiredAddress({error,data}){            
            this.deliveryAddressOptions=[];
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
    
    @wire(getPaymentOptionList,{accountId:'$accountId'})
        wiredPm({error,data}){
            if(data){
                this.pmOptions = data;               
                console.log(JSON.stringify(this.pmOptions));
            }else if(error){
                console.log('getPaymentOptionlist:'+JSON.stringify(error));
            }
        }        

    @wire(getWebCart,{cartId:'$cartId'})        
        wiredCart({error,data}){            
            if(data){                 
                this.b2bWebCart = data;
                if(data.BillingStreet && data.BillingCity && data.BillingState && data.BillingPostalCode){ 
                    this.cartObject.BillingStreet=data.BillingStreet;
                    this.cartObject.BillingCity=data.BillingCity;
                    this.cartObject.BillingState=data.BillingState;
                    this.cartObject.BillingPostalCode=data.BillingPostalCode;
                    this.cartObject.BillingCountry=data.BillingCountry;
                }
                this.cartObject.NATT_Payment_Instruction__c=data.NATT_Payment_Instruction__c;
                if(!this.cartObject.NATT_Payment_Instruction__c){
                    this.cartObject.NATT_Payment_Instruction__c='Credit Card';
                }
                this.accountId = data.AccountId;
                this.error=undefined;         

                //console.log('calledWith:'+JSON.stringify(data));
                //console.log('called:'+this.cartObject.BillingStreet);
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
              console.log('error getCartSummary:'+error);
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
    get grandTotalAmountWithRushFeeAndTax(){
        
        return (parseFloat(this.grandTotalAmount)+parseFloat(this.rushFee)+parseFloat(this.estimatedTax));
    }
    handleGoNext(){
        if(this.isStep1){
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
                getTaxAmount({amount:this.grandTotalAmountWithRushFee,street: this.cartObject.NATT_Shipping_Street__c,city: this.cartObject.NATT_Shipping_City__c,
                    state: this.cartObject.NATT_Shipping_State__c,postalCode: this.cartObject.NATT_Shipping_Postal_Code__c,
                    country: this.cartObject.NATT_Shipping_Country__c})
                .then(result=>{
                    console.log('result: '+JSON.stringify(result));
                    if(result && result.error){
                        console.log('getTaxAmount error: '+result.error.message);
                    }else{
                        
                        console.log('estimatedTax: '+result.totalTax);
                        this.estimatedTax=result.totalTax;
                        if(this.grandTotalAmountWithRushFee!=0 && this.estimatedTax!=0){
                            this.cartObject.NATT_TaxPercent__c=(this.estimatedTax/this.grandTotalAmountWithRushFee);
                        }
                    }
                });
                this.isStep1=false;
                this.isStep2=true;
                this.isStep3=false;
            }
        }else if(this.isStep2){
            let isValid=false;
            const address = this.template.querySelector('lightning-input-address');
            isValid = address.reportValidity();
            //if(this.cartObject.BillingStreet==''||this.cartObject.BillingCity==''||this.cartObject.BillingCity==''||this.cartObject.BillingState==''||this.cartObject.BillingPostalCode==''){
            if(!isValid){
                return;
            }
            if(this.cartObject.NATT_Payment_Instruction__c=='Credit Card'){
                const ccInfo = this.template.querySelector('c-natt_-tes-card-payment-method');
                isValid = ccInfo.reportValidity();

                if(isValid){
                    this.ccNameOnCard=ccInfo.cardHolderName;
                    this.ccCardType=ccInfo.cardType;
                    this.ccCardNumber=ccInfo.cardNumber;
                    this.ccCvv=ccInfo.cvv;
                    this.ccExpiryMonth=ccInfo.expiryMonth;
                    this.ccExpiryYear=ccInfo.expiryYear;

                    console.log('isValid:'+this.ccNameOnCard+' cardType:'+this.ccCardType+' cardNumber:'+this.ccCardNumber+' ccv:'+this.ccCvv+' expiry: '+this.ccExpiryYear+'-'+this.ccExpiryMonth);
                }
            }
            if(isValid){
                this.isStep1=false;
                this.isStep2=false;
                this.isStep3=true;
            }
        }else if(this.isStep3){
            
        }
    }

    handleGoPrevious(){
        if(this.isStep1){

        }else if(this.isStep2){
            this.isStep1=true;
            this.isStep2=false;
            this.isStep3=false;
        }else if(this.isStep3){
            this.error=null;
            this.isStep1=false;
            this.isStep2=true;
            this.isStep3=false;
        }
    }
    
    handleFinish(){        
        if(this.cartObject.NATT_Payment_Instruction__c=='Credit Card'){
            this.doCompleteCreditCardOrder();
        }else{
            this.doCompleteOrder();
        }           
    }

    doCompleteCreditCardOrder(){
        this.error=null;
        doAuth({email:this.cartObject.NATT_Order_Contact_Email__c,amount:this.grandTotalAmountWithRushFee,cardNumber:this.ccCardNumber,expirationDate:this.ccExpiryYear+'-'+this.ccExpiryMonth,cvv:this.ccCvv})
            .then(authResult=>{
                console.log('AuthResult:'+JSON.stringify(authResult));
                if(authResult && !authResult.hasError){
                    this.cartObject.NATT_Transaction_Id__c=authResult.transactionId;
                    this.cartObject.NATT_Transaction_Payment_Id__c=authResult.paymentProfileId;                    
                    this.doCompleteOrder();
                }else{
                    this.error=authResult.errorMessage;
                }
            });        
    }

    doCompleteOrder(){
        console.log('doCompleteOrder:'+this.error);
        if(this.error){            
            return;
        }
        updateWebCart({cartId:this.cartId,webCartJson:JSON.stringify(this.cartObject),deliveryMethodSelected:this.deliveryMethodSelected})
        .then(()=>{
            this.doNav();
        }).catch(error =>{
            console.log('error:'+JSON.stringify(error));
            //this.error=error.body?.pageErrors[0].message;
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
        let cPointAddress = this.deliveryMap.get(this.deliveryAddressSelected);
        this.cartObject.NATT_Shipping_Street__c=cPointAddress.Street;
        this.cartObject.NATT_Shipping_City__c=cPointAddress.City;
        this.cartObject.NATT_Shipping_State__c=cPointAddress.State;
        this.cartObject.NATT_Shipping_Postal_Code__c=cPointAddress.PostalCode;
        this.cartObject.NATT_Shipping_Country__c=cPointAddress.Country;    
        this.cartObject.NATT_Shipping_Address_Id__c=cPointAddress.NATT_Address__c;    
        this.cartObject.NATT_Contact_Point_Address__c=cPointAddress.Id;
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
        fields.Country=this.countryFieldValue;
        fields.State=this.stateFieldValue;
        console.log('Country Value: ' +  fields.Country);
        console.log('State Value: ' +  fields.State);
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

    handlePmChange(event){
        this.cartObject.NATT_Payment_Instruction__c=event.target.value;
        if(this.cartObject.NATT_Payment_Instruction__c=='Credit Card'){
            this.ccVisible=true;
            this.invoiceVisible=false;
            this.wtVisible=false;
        }else if(this.cartObject.NATT_Payment_Instruction__c=='Wire Transfer'){
            this.ccVisible=false;
            this.invoiceVisible=false;
            this.wtVisible=true;
        }else if(this.cartObject.NATT_Payment_Instruction__c=='Terms'){
            this.ccVisible=false;
            this.invoiceVisible=true;
            this.wtVisible=false;
        }
    }

    handleBillingAddressChange(event){
        console.log('called');
        this.cartObject.BillingStreet=event.target.street;
        this.cartObject.BillingCity=event.target.city;
        this.cartObject.BillingState=event.target.state;
        this.cartObject.BillingPostalCode=event.target.postalCode;
        this.cartObject.Billingountry=event.target.country;
        console.log('billing address: '+this.cartObject.BillingPostalCode);
    }

    // handleSubmit(event){
    //     console.log('handle submit');
    //     event.preventDefault();       // stop the form from submitting
    //     const fields = event.detail.fields;
    //     console.log('Country: ' + this.countryFieldValue);
    //     fields.Country = this.countryFieldValue;
    //     this.template.querySelector('ContactPointAddress').submit(fields);
    // }
    handleSucess(event){
        const updatedRecord = event.detail.id;
        console.log('onsuccess: ', updatedRecord);
     }
    handleCountryChange(event){
        this.countryFieldValue = event.target.value;
    }
    handleStateChange(event){
        // if(event.target.dataset.id === 'stateField'){
            console.log('State Value: ' +  event.target.value);
        this.stateFieldValue = event.target.value;
    }

    get choicesState() {
        return this.states.map(s => ({ label: s[1], value: s[0] }));
    }

    get states() {
        return [
            ['AL','Alabama'], ['AK','Alaska'], ['AZ','Arizona'], ['AR','Arkansas'], ['CA','California'], ['CO','Colorado'], ['CT','Connecticut'], 
            ['DE','Delaware'], ['DC','District of Columbia'], ['FL','Florida'], ['GA','Georgia'], ['HI','Hawaii'], ['ID','Idaho'], ['IL','Illinois'], 
            ['IN','Indiana'], ['IA','Iowa'], ['KS','Kansas'], ['KY','Kentucky'], ['LA','Louisiana'], ['ME','Maine'], ['MD','Maryland'], ['MA','Massachusetts'], 
            ['MI','Michigan'], ['MN','Minnesota'], ['MS','Mississippi'], ['MO','Missouri'], ['MT','Montana'], ['NE','Nebraska'], ['NV','Nevada'], ['NH','New Hampshire'], 
            ['NJ','New Jersey'], ['NM','New Mexico'], ['NY','New York'], ['NC','North Carolina'], ['ND','North Dakota'], ['OH','Ohio'], ['OK','Oklahoma'], ['OR','Oregon'], 
            ['PA','Pennsylvania'], ['PR','Puerto Rico'], ['RI','Rhode Island'], ['SC','South Carolina'], ['SD','South Dakota'], ['TN','Tennessee'], ['TX','Texas'], 
            ['VI','U.S. Virgin Islands'], ['UT','Utah'], ['VT','Vermont'], ['VA','Virginia'], ['WA','Washington'], ['WV','West Virginia'], ['WI','Wisconsin'], 
            ['WY','Wyoming']
        ];
    }

    get choicesCountry() {
        return this.countries.map(s => ({ label: s[1], value: s[0] }));
    }

    get countries(){
        return [
            ['US', 'United States'],['AF', 'Afghanistan'],['AL', 'Albania'],['DZ', 'Algeria'],['AS', 'American Samoa'],['AD', 'Andorra'],['AO', 'Angola'],['AI', 'Anguilla'],
            ['AQ', 'Antarctica'],['AG', 'Antigua and Barbuda'],['AR', 'Argentina'],['AM', 'Armenia'],['AW', 'Aruba'],['AU', 'Australia'],['AT', 'Austria'],['AZ', 'Azerbaijan'],
            ['BS', 'Bahamas'],['BH', 'Bahrain'],['BD', 'Bangladesh'],['BB', 'Barbados'],['BY', 'Belarus'],['BE', 'Belgium'],['BZ', 'Belize'],['BJ', 'Benin'],['BM', 'Bermuda'],
            ['BT', 'Bhutan'],['BO', 'Bolivia, Plurinational State of'],['BQ', 'Bonaire, Sint Eustatius and Saba'],['BA', 'Bosnia and Herzegovina'],['BW', 'Botswana'],['BV', 'Bouvet Island'],
            ['BR', 'Brazil'],['IO', 'British Indian Ocean Territory'],['BN', 'Brunei Darussalam'],['BG', 'Bulgaria'],['BF', 'Burkina Faso'],['BI', 'Burundi'],['KH', 'Cambodia'],['CM', 'Cameroon'],
            ['CA', 'Canada'],['CV', 'Cape Verde'],['KY', 'Cayman Islands'],['CF', 'Central African Republic'],['TD', 'Chad'],['CL', 'Chile'],['CN', 'China'],['CX', 'Christmas Island'],
            ['CC', 'Cocos (Keeling) Islands'],['CO', 'Colombia'],['KM', 'Comoros'],['CG', 'Congo'],['CD', 'Congo, the Democratic Republic of the'],['CK', 'Cook Islands'],['CR', 'Costa Rica'],
            ['CI', 'Cote d\'Ivoire'],['HR', 'Croatia'],['CU', 'Cuba'],['CW', 'Cura\u00e7ao'],['CY', 'Cyprus'],['CZ', 'Czech Republic'],['DK', 'Denmark'],['DJ', 'Djibouti'],['DM', 'Dominica'],
            ['DO', 'Dominican Republic'],['EC', 'Ecuador'],['EG', 'Egypt'],['SV', 'El Salvador'],['GQ', 'Equatorial Guinea'],['ER', 'Eritrea'],['EE', 'Estonia'],['ET', 'Ethiopia'],
            ['FK', 'Falkland Islands (Malvinas)'],['FO', 'Faroe Islands'],['FJ', 'Fiji'],['FI', 'Finland'],['FR', 'France'],['GF', 'French Guiana'],['PF', 'French Polynesia'],
            ['TF', 'French Southern Territories'],['GA', 'Gabon'],['GM', 'Gambia'],['GE', 'Georgia'],['DE', 'Germany'],['GH', 'Ghana'],['GI', 'Gibraltar'],['GR', 'Greece'],['GL', 'Greenland'],
            ['GD', 'Grenada'],['GP', 'Guadeloupe'],['GU', 'Guam'],['GT', 'Guatemala'],['GG', 'Guernsey'],['GN', 'Guinea'],['GW', 'Guinea-Bissau'],['GY', 'Guyana'],['HT', 'Haiti'],
            ['HM', 'Heard Island and McDonald Islands'],['VA', 'Holy See (Vatican City State)'],['HN', 'Honduras'],['HK', 'Hong Kong'],['HU', 'Hungary'],['IS', 'Iceland'],['IN', 'India'],
            ['ID', 'Indonesia'],['IR', 'Iran'],['IQ', 'Iraq'],['IE', 'Ireland'],['IM', 'Isle of Man'],['IL', 'Israel'],['IT', 'Italy'],['JM', 'Jamaica'],['JP', 'Japan'],
            ['JE', 'Jersey'],['JO', 'Jordan'],['KZ', 'Kazakhstan'],['KE', 'Kenya'],['KI', 'Kiribati'],['KP', 'Korea, Democratic People\'s Republic of'],['KR', 'Korea, Republic of'],['KW', 'Kuwait'],
            ['KG', 'Kyrgyzstan'],['LA', 'Lao People\'s Democratic Republic'],['LV', 'Latvia'],['LB', 'Lebanon'],['LS', 'Lesotho'],['LR', 'Liberia'],['LY', 'Libya'],['LI', 'Liechtenstein'],
            ['LT', 'Lithuania'],['LU', 'Luxembourg'],['MO', 'Macao'],['MK', 'Macedonia, the Former Yugoslav Republic of'],['MG', 'Madagascar'],['MW', 'Malawi'],['MY', 'Malaysia'],['MV', 'Maldives'],
            ['ML', 'Mali'],['MT', 'Malta'],['MH', 'Marshall Islands'],['MQ', 'Martinique'],['MR', 'Mauritania'],['MU', 'Mauritius'],['YT', 'Mayotte'],['MX', 'Mexico'],['FM', 'Micronesia, Federated States of'],
            ['MD', 'Moldova, Republic of'],['MC', 'Monaco'],['MN', 'Mongolia'],['ME', 'Montenegro'],['MS', 'Montserrat'],['MA', 'Morocco'],['MZ', 'Mozambique'],['MM', 'Myanmar'],['NA', 'Namibia'],
            ['NR', 'Nauru'],['NP', 'Nepal'],['NL', 'Netherlands'],['NC', 'New Caledonia'],['NZ', 'New Zealand'],['NI', 'Nicaragua'],['NE', 'Niger'],['NG', 'Nigeria'],['NU', 'Niue'],['NF', 'Norfolk Island'],
            ['MP', 'Northern Mariana Islands'],['NO', 'Norway'],['OM', 'Oman'],['PK', 'Pakistan'],['PW', 'Palau'],['PS', 'Palestine, State of'],['PA', 'Panama'],['PG', 'Papua New Guinea'],['PY', 'Paraguay'],
            ['PE', 'Peru'],['PH', 'Philippines'],['PN', 'Pitcairn'],['PL', 'Poland'],['PT', 'Portugal'],['PR', 'Puerto Rico'],['QA', 'Qatar'],['RE', 'R\u00e9union'],['RO', 'Romania'],['RU', 'Russian Federation'],
            ['RW', 'Rwanda'],['LC', 'Saint Lucia'],['PM', 'Saint Pierre and Miquelon'],['VC', 'Saint Vincent and the Grenadines'],['WS', 'Samoa'],['SM', 'San Marino'],['ST', 'Sao Tome and Principe'],['SA', 'Saudi Arabia'],['SN', 'Senegal'],['RS', 'Serbia'],
            ['SC', 'Seychelles'],['SL', 'Sierra Leone'],['SG', 'Singapore'],['SX', 'Sint Maarten (Dutch part)'],['SK', 'Slovakia'],['SI', 'Slovenia'],['SB', 'Solomon Islands'],['SO', 'Somalia'],['ZA', 'South Africa'],
            ['GS', 'South Georgia and the South Sandwich Islands'],['SS', 'South Sudan'],['ES', 'Spain'],['LK', 'Sri Lanka'],['SD', 'Sudan'],['SR', 'Suriname'],['SJ', 'Svalbard and Jan Mayen'],['SZ', 'Swaziland'],['SE', 'Sweden'],
            ['CH', 'Switzerland'],['SY', 'Syrian Arab Republic'],['TW', 'Taiwan, Province of China'],['TJ', 'Tajikistan'],['TZ', 'Tanzania, United Republic of'],['TH', 'Thailand'],['TL', 'Timor-Leste'],['TG', 'Togo'],['TK', 'Tokelau'],
            ['TO', 'Tonga'],['TT', 'Trinidad and Tobago'],['TN', 'Tunisia'],['TR', 'Turkey'],['TM', 'Turkmenistan'],['TC', 'Turks and Caicos Islands'],['TV', 'Tuvalu'],['UG', 'Uganda'],['UA', 'Ukraine'],['AE', 'United Arab Emirates'],
            ['GB', 'United Kingdom'],['UM', 'United States Minor Outlying Islands'],['UY', 'Uruguay'],['UZ', 'Uzbekistan'],['VU', 'Vanuatu'],['VE', 'Venezuela, Bolivarian Republic of'],['VN', 'Viet Nam'],
            ['VG', 'Virgin Islands, British'],['VI', 'Virgin Islands, U.S.'],['WF', 'Wallis and Futuna'],['EH', 'Western Sahara'],['YE', 'Yemen'],['ZM', 'Zambia'],['ZW', 'Zimbabwe']
        ];
    }

    handlePoChange(event){
        this.cartObject.PoNumber=event.detail.value;
    }
}