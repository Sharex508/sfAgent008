import { LightningElement, api, track } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import communityId from '@salesforce/community/Id';
import Id from '@salesforce/user/Id';
import getCheckOutDetails from '@salesforce/apex/NAC_CheckoutController.getCheckOutDetails';
import createOrders from '@salesforce/apex/NAC_CheckoutController.createOrders';
import CheckoutLabel from '@salesforce/label/c.nac_CheckoutLabel';
import ShippingInformationLabel from '@salesforce/label/c.nac_ShippingInformationLabel';
import OrderReviewLabel from '@salesforce/label/c.nac_OrderReviewLabel';
import Payment from '@salesforce/label/c.nac_Payment';
import OrderComplete from '@salesforce/label/c.nac_OrderComplete';
import Continue from '@salesforce/label/c.nac_Continue';
import ProceedtoPay from '@salesforce/label/c.nac_ProceedtoPay';
import SubmitOrder from '@salesforce/label/c.nac_SubmitOrder';

const STAGE1LABEL = ShippingInformationLabel;
const STAGE2LABEL = OrderReviewLabel;
const STAGE3LABEL = Payment;
const STAGE4LABEL = OrderComplete;
const STAGE1NEXTBUTTONLABEL = Continue;
const STAGE2NEXTBUTTONLABEL = ProceedtoPay;
const STAGE3NEXTBUTTONLABEL = SubmitOrder;
const staticResourceName = 'NAC_Terms_and_conditions';

export default class Nac_CheckOutComponent extends NavigationMixin(LightningElement) {

    title = CheckoutLabel;
    userId = Id;
    @api effectiveAccountId;
    @api recordId;
    stages = [STAGE1LABEL, STAGE2LABEL, STAGE3LABEL, STAGE4LABEL];
    currentStage = STAGE1LABEL;
    step1 = true;
    step2 = false;
    step3 = false;
    step4 = false;
    disableNextButton = true;
    showSpinner = false;
    showBackButton = false;
    showBacktoCartButton = true;
    nextButtonLabel = STAGE1NEXTBUTTONLABEL;
    shippingAddressOptions = [];
    shippingAddressIndex;
    showChangeAddressButton = true;
    orderId;
    downloadLink = '';
    @api rushFee = 0.0;

    @track orderInformation = {
        phone: '',
        email: '',
        name: '',
        isActive: '',
        selectedSection: '',
        shippingNATTAddressId: '',
        shippingAddressValue: '',
        shippingStreetValue: '',
        shippingCityValue: '',
        shippingStateValue: '',
        shippingPostalCodeValue: '',
        shippingCountryDisplayValue: '',
        shippingCountryValue: '',
        billingNATTAddressId: '',
        billingAddressValue: '',
        billingStreetValue: '',
        billingCityValue: '',
        billingStateValue: '',
        billingPostalCodeValue: '',
        billingCountryValue: '',
        orderType: {},
        shippingMethod: {},
        deliveryTerm: {},
        shipComplete: false,
        shippingMethodData: [],
        shippingMethodOptions: [],
        deliveryTermData: [],
        deliveryTermOptions: [],
        orderTypeOptions: [],
        requestedDate: '',
        purchaseOrderNo: '',
        freightAccountNumber: '',
        showAccountNumberfield: false,
        acceptedTerms: false,
        rushFee: 0.0,
        totalNonCoreCartAmount: 0.0,
        totalRushFee: 0.0,
        totalAmount: 0.0,
        totalAmountOriginal: 0.0,
        canReceiveRushOrderCharge: false,
        selectedBranchPlantWarehouse: '',
        customerType: '',
        isCustomAddEnabled: false,
        countryListOption: [],
        countyStateMapping: [],
        stateListOptions : [],
        shippingMailingName :''
    }
    todayDate;

    connectedCallback() {
        let yourDate = new Date()
        yourDate.toISOString().split('T')[0];
        const offset = yourDate.getTimezoneOffset();
        yourDate = new Date(yourDate.getTime() - (offset * 60 * 1000));
        this.todayDate = yourDate.toISOString().split('T')[0];
        this.showSpinner = true;
        this.recordId = sessionStorage.getItem("recordId");
        this.effectiveAccountId = sessionStorage.getItem("effectiveAccountId");
        getCheckOutDetails({ userId: this.userId, communityId: communityId, resourceName: staticResourceName, effectiveAccountId: this.resolvedEffectiveAccountId })
            .then(result => {
                this.showSpinner = false;
                try {
                    //Address Information
                    let shippingAddressList = result.addressList.filter(address => address.AddressType == 'Shipping');
                    let billingAddressList = result.addressList.filter(address => address.AddressType == 'Billing');
                    shippingAddressList.forEach(data => {
                        let address = '';
                        if (data.Street) address += data.Street;
                        if (data.City) address += ' ' + data.City;
                        if (data.State) address += ' ' + data.State;
                        if (data.PostalCode) address += ' ' + data.PostalCode;
                        if (data.Country) address += ' ' + data.Country;
                        this.shippingAddressOptions.push({
                            label: address,
                            value: data.Id,
                            street: data.Street,
                            city: data.City,
                            state: data.State,
                            postalcode: data.PostalCode,
                            country: data.Country,
                            shippingNATTAddressId: data.NATT_Address__c != '' ? data.NATT_Address__c : ''
                        });
                        if (data.IsDefault) {
                            this.orderInformation.shippingNATTAddressId = data.NATT_Address__c != '' ? data.NATT_Address__c : '';
                            this.orderInformation.shippingAddressValue = address;
                            this.orderInformation.shippingStreetValue = data.Street;
                            this.orderInformation.shippingCityValue = data.City;
                            this.orderInformation.shippingStateValue = data.State;
                            this.orderInformation.shippingPostalCodeValue = data.PostalCode;
                            this.orderInformation.shippingCountryValue = data.Country;
                            this.shippingAddressIndex = data.Id;
                        }
                    });
                    billingAddressList.forEach(data => {
                        if (data.IsDefault) {
                            let address = '';
                            if (data.Street) address += data.Street;
                            if (data.City) address += ' ' + data.City;
                            if (data.State) address += ' ' + data.State;
                            if (data.PostalCode) address += ' ' + data.PostalCode;
                            if (data.Country) address += ' ' + data.Country;
                            this.orderInformation.billingNATTAddressId = data.NATT_Address__c != '' ? data.NATT_Address__c : '';
                            this.orderInformation.billingAddressValue = address;
                            this.orderInformation.billingStreetValue = data.Street;
                            this.orderInformation.billingCityValue = data.City;
                            this.orderInformation.billingStateValue = data.State;
                            this.orderInformation.billingPostalCodeValue = data.PostalCode;
                            this.orderInformation.billingCountryValue = data.Country;
                        }
                    });
                    //User Information
                    this.orderInformation.name = result.userDetail.Name;
                    this.orderInformation.phone = result.userDetail.Phone;
                    this.orderInformation.email = result.userDetail.Email;

                    this.downloadLink = result.downloadLink;
                    this.orderInformation.orderTypeOptions = result.orderTypeData.values;
                    this.orderInformation.orderType = result.orderTypeData.defaultValue;
                    
                    if (JSON.stringify(this.orderInformation.orderType).includes("Stock order") ) {
                        var someDate = new Date(new Date().getTime()+(2*24*60*60*1000)); //added 2 days to todays date
                         var futureDate= someDate.toISOString();
                      this.orderInformation.requestedDate = futureDate;
                     }
                     else if(JSON.stringify(this.orderInformation.orderType).includes("DS")){
                           let rightNow = new Date();
                           // Adjust for the user's time zone
                           rightNow.setMinutes(
                            new Date().getMinutes() - new Date().getTimezoneOffset()
                           );
                           // Return the date in "YYYY-MM-DD" format
                           let setTodayDate = rightNow.toISOString().slice(0,10);
                           this.orderInformation.requestedDate=setTodayDate;
                     }
                    this.orderInformation.shippingMethodData = result.shippingMethodData;
                    this.orderInformation.shippingMethodOptions = this.orderInformation.shippingMethodData.values.filter(opt => opt.validFor.includes(this.orderInformation.shippingMethodData.controllerValues[this.orderInformation.orderType.value]));
                    this.orderInformation.shippingMethod = result.shippingMethodData.defaultValue;
                    this.orderInformation.deliveryTermData = result.deliveryTermData;
                    this.orderInformation.deliveryTermOptions = this.orderInformation.deliveryTermData.values.filter(opt => opt.validFor.includes(this.orderInformation.deliveryTermData.controllerValues[this.orderInformation.shippingMethod.value]) && opt.childrenValidFor.includes(this.orderInformation.deliveryTermData.parentControllerValues[this.orderInformation.orderType.value]));
                    this.orderInformation.deliveryTerm = result.deliveryTermData.defaultValue;
                    this.orderInformation.totalNonCoreCartAmount = result.totalNonCoreCartAmount;
                    this.orderInformation.selectedBranchPlantWarehouse = result.selectedBranchPlantWarehouse;
                    this.orderInformation.customerType = result.customerType;
                    this.orderInformation.isCustomAddEnabled = result.isCustomAddEnabled;
                    //State and Country Picklist value
                    if (result.countryStatePicklistValue) {
                        for (let key in result.countryStatePicklistValue) {
                            this.orderInformation.countryListOption.push({ label: key, value: result.countryStatePicklistValue[key][0].nac_Country_Code__c });
                            let stateList = [];
                            for (let key2 in result.countryStatePicklistValue[key]) {
                                if (key2 == 0) stateList = [];
                                stateList.push({
                                    label: result.countryStatePicklistValue[key][key2].nac_State__c,
                                    value: result.countryStatePicklistValue[key][key2].nac_State_Code__c
                                })
                            }
                            stateList.sort((a, b) => a.label.localeCompare(b.label));
                            this.orderInformation.countyStateMapping.push({
                                key: result.countryStatePicklistValue[key][0].nac_Country_Code__c,
                                value: stateList
                            });
                        }
                    }
                }
                catch (error) {
                    console.log(JSON.stringify(error.message));
                }
            })
            .catch(error => {
                this.showSpinner = false;
                console.log('Error' + JSON.stringify(error));
            });

    }

    get resolvedEffectiveAccountId() {
        const effectiveAcocuntId = this.effectiveAccountId || '';
        let resolved = null;
        if (
            effectiveAcocuntId.length > 0 &&
            effectiveAcocuntId !== '000000000000000'
        ) {
            resolved = effectiveAcocuntId;
        }
        return resolved;
    }

    handleClickNext() {

        switch (this.currentStage) {
            case STAGE1LABEL:
                // this.orderInformation.requestedDate 
                if (this.orderInformation.requestedDate && this.orderInformation.requestedDate < this.todayDate) {
                    //Do nothing 
                }
                else {
                    this.currentStage = STAGE2LABEL;
                    this.nextButtonLabel = STAGE2NEXTBUTTONLABEL;
                    this.showBackButton = true;
                    this.disableNextButton = false;
                    this.showBacktoCartButton = true;
                    this.step1 = false;
                    this.step2 = true;
                    this.step3 = false;
                    this.step4 = false;
                }
                break;

            case STAGE2LABEL:
                this.currentStage = STAGE3LABEL;
                this.nextButtonLabel = STAGE3NEXTBUTTONLABEL;
                this.showBackButton = true;
                this.showBacktoCartButton = true;
                this.step1 = false;
                this.step2 = false;
                this.step3 = true;
                this.step4 = false;
                if (this.orderInformation.acceptedTerms && this.orderInformation.purchaseOrderNo && this.orderInformation.purchaseOrderNo !== '' && this.orderInformation.purchaseOrderNo.trim().length > 0) {
                    this.disableNextButton = false;
                } else {
                    this.disableNextButton = true;
                }
                break;
            case STAGE3LABEL:
                this.submitOrder();
                //this.handleFinish();
                break;
            default:
                this.currentStage = STAGE1LABEL;
                this.nextButtonLabel = STAGE1NEXTBUTTONLABEL;
                this.showBackButton = true;
                this.disableNextButton = false;
                this.showBacktoCartButton = true;
                this.step1 = true;
                this.step2 = false;
                this.step3 = false;
                this.step4 = false;
        }
    }

    handleClickBack() {
        switch (this.currentStage) {
            case STAGE3LABEL:
                this.currentStage = STAGE2LABEL;
                this.nextButtonLabel = STAGE2NEXTBUTTONLABEL;
                this.showBackButton = true;
                this.disableNextButton = false;
                this.showBacktoCartButton = true;
                this.step1 = false;
                this.step2 = true;
                this.step3 = false;
                this.step4 = false;
                break;
            case STAGE2LABEL:
                this.currentStage = STAGE1LABEL;
                this.nextButtonLabel = STAGE1NEXTBUTTONLABEL;
                this.showBackButton = false;
                this.disableNextButton = false;
                this.showBacktoCartButton = true;
                this.step1 = true;
                this.step2 = false;
                this.step3 = false;
                this.step4 = false;
                break;
            default:
                this.currentStage = STAGE1LABEL;
                this.nextButtonLabel = STAGE1NEXTBUTTONLABEL;
                this.showBackButton = true;
                this.disableNextButton = false;
                this.showBacktoCartButton = true;
                this.step1 = true;
                this.step2 = false;
                this.step3 = false;
                this.step4 = false;
        }
    }

    handleBacktoCart() {
        this[NavigationMixin.Navigate]({
            type: 'standard__webPage',
            attributes: {
                url: '/cart/' + this.recordId
            }
        });
    }
    disableContinue() {

        this.disableNextButton = true;
    }
    handleOrderDataChange(event) {
        this.orderInformation = event.detail;
        if (this.step1) {
            this.disableNextButton = true;
            if (this.orderInformation.shippingMethod && this.orderInformation.shippingMethod.value !== '' && this.orderInformation.deliveryTerm && this.orderInformation.deliveryTerm.value !== '' && this.orderInformation.shippingAddressValue && this.orderInformation.shippingAddressValue != '') {
                this.disableNextButton = false;
            }

        }
        if (this.step3) {
            if (this.orderInformation.acceptedTerms && this.orderInformation.purchaseOrderNo && this.orderInformation.purchaseOrderNo !== '' && this.orderInformation.purchaseOrderNo.trim().length > 0) {
                this.disableNextButton = false;
            } else {
                this.disableNextButton = true;
            }
        }
    }

    submitOrder() {
        this.showSpinner = true;
        createOrders({ cartId: this.recordId, orderInformation: this.orderInformation })
            .then(result => {
                this.showSpinner = false;
                try {

                    if (result.hasError) {
                        this.dispatchEvent(
                            new ShowToastEvent({
                                title: 'Error',
                                message: result.errorMessage,
                                variant: 'error',
                                mode: 'dismissable'
                            })
                        );
                    } else {
                        this.orderId = result.orderId;
                        this[NavigationMixin.Navigate]({
                            type: 'standard__webPage',
                            attributes: {
                                url: '/orderconfirmation?recordId=' + this.orderId
                            }
                        });
                    }
                }
                catch (error) {
                    console.log(JSON.stringify(error.message));
                }
            })
            .catch(error => {
                this.showSpinner = false;
                console.log('Error' + JSON.stringify(error));
            });
    }
}