import { LightningElement, api, track, wire } from 'lwc';
import okLabel from '@salesforce/label/c.nac_OkLabel';
import cancelLabel from '@salesforce/label/c.nac_CancelLabel';
import shipCompleteLabel from '@salesforce/label/c.nac_ShipComplete';
import confirmLabel from '@salesforce/label/c.nac_PleaseConfirmLabel';
import shipConfirm from '@salesforce/label/c.nac_ShipConfirm';
import shipCountry from '@salesforce/label/c.nac_shipcountry';
import shipState from '@salesforce/label/c.nac_State';
import shipCity from '@salesforce/label/c.nac_City';
import shipZipCode from '@salesforce/label/c.nac_ZipCode';
import shipStreet from '@salesforce/label/c.nac_Street';
import getRushOrderCharge from '@salesforce/apex/NAC_CheckoutController.getRushOrderCharge';

export default class Nac_ShippingInformation extends LightningElement {
    @track showAccountNumberField = false; // controls visibility of Account Number field
    @api orderInformation;
    @api shippingAddressOptions;
    @api showChangeAddressButton;
    @api shippingAddressIndex;
    @api deliveryTermOptions;
    @api addressData = [];
    @api slectedSection;
    @track rushFeePercent;
    @track isActivesec;
    @track street;
    @track state;
    @track country;
    @track activeSections;
    @track mailingName;
    @track accountNumber;
    isCustomAddEnabled = false;
    showAddressesPopUp = false;
    showShipCompleteModal = false;
    todayDate;
    label = {
        okLabel,
        cancelLabel,
        shipCompleteLabel,
        confirmLabel,
        shipConfirm
    }
    
    _isCOL(deliveryTerm) {
        // deliveryTerm is expected to have .value and .label
        const val = (deliveryTerm?.value || '').toUpperCase();
        const lbl = (deliveryTerm?.label || '').toUpperCase();
        return val === 'COL' || lbl === 'COL';
    }


    handleOrderTypeChange(event) {
        try {
            this.showSpinner = true;
            let orderInfo = JSON.parse(JSON.stringify(this.orderInformation));
            orderInfo.shippingMethodOptions = orderInfo.shippingMethodData.values.filter(opt => opt.validFor.includes(orderInfo.shippingMethodData.controllerValues[event.detail.value]));
            if (orderInfo.shippingMethodOptions.length == 1) {
                orderInfo.shippingMethodOptions.forEach(options => {
                    orderInfo.shippingMethod.value = options.value;
                    orderInfo.shippingMethod.label = orderInfo.shippingMethodOptions.find(element => element.value == options.value).label;
                });
            }
            let validateShippingMethod = orderInfo.shippingMethodOptions.find(opt => opt.value == orderInfo.shippingMethod.value);
            if (validateShippingMethod == undefined) {
                orderInfo.shippingMethod.value = '';
                orderInfo.shippingMethod.label = '';
            }
            orderInfo.deliveryTermOptions = orderInfo.deliveryTermData.values.filter(opt => opt.validFor.includes(orderInfo.deliveryTermData.controllerValues[orderInfo.shippingMethod.value]) && opt.childrenValidFor.includes(orderInfo.deliveryTermData.parentControllerValues[event.detail.value]));
            if (orderInfo.deliveryTermOptions.length == 1) {
                orderInfo.deliveryTermOptions.forEach(options => {
                    orderInfo.deliveryTerm.value = options.value;
                    orderInfo.deliveryTerm.label = orderInfo.deliveryTermOptions.find(element => element.value == options.value).label;
                });
            }
            let validateDeliveryTerm = orderInfo.deliveryTermOptions.find(opt => opt.value == orderInfo.deliveryTerm.value);
            if (validateDeliveryTerm == undefined) {
                orderInfo.deliveryTerm.value = '';
                orderInfo.deliveryTerm.label = '';
            }
            orderInfo.orderType.value = event.detail.value;
            orderInfo.orderType.label = orderInfo.orderTypeOptions.find(element => element.value == event.detail.value).label;
            var selectedOrderType = event.detail.value;
            
            if (selectedOrderType.includes("1") || selectedOrderType.includes("2")) {
                
                let rightNow = new Date();
                    // Adjust for the user's time zone
                    rightNow.setMinutes(
                        new Date().getMinutes() - new Date().getTimezoneOffset()
                    );
                    // Return the date in "YYYY-MM-DD" format
                    let setTodayDate = rightNow.toISOString().slice(0,10);

                orderInfo.requestedDate=setTodayDate;
                orderInfo.canReceiveRushOrderCharge = true;
                orderInfo.totalAmount = orderInfo.totalAmountOriginal;
                this.fetchRushOrderCharge();
            }
            else {
                
                var someDate = new Date(new Date().getTime()+(2*24*60*60*1000)); //added 90 days to todays date
                var futureDate= someDate.toISOString();

                orderInfo.requestedDate=futureDate;
                orderInfo.canReceiveRushOrderCharge = false;
                orderInfo.rushFee = 0.0;
                orderInfo.totalRushFee = 0.0;
                //orderInfo.totalNonCoreCartAmount=0.0;
                orderInfo.totalAmount = orderInfo.totalAmountOriginal;
            }
            
                const isCOL = this._isCOL(orderInfo.deliveryTerm);
                this.showAccountNumberField = isCOL;

                if (!isCOL) {
                    this.accountNumber = '';
                    orderInfo.accountNumber = '';
                }

            this.orderInformation = orderInfo;
            this.notifyAction();
            this.showSpinner = false;
        } catch (error) {
            this.showSpinner = false;
            console.log(JSON.stringify(error.message));
        }

    }
    
    connectedCallback() {
        let orderInfo = JSON.parse(JSON.stringify(this.orderInformation));
        let yourDate = new Date()
        yourDate.toISOString().split('T')[0];
        const offset = yourDate.getTimezoneOffset();
        yourDate = new Date(yourDate.getTime() - (offset * 60 * 1000));
        this.todayDate = yourDate.toISOString().split('T')[0];

        //New Code Added
        
    const val = (this.orderInformation?.deliveryTerm?.value || '').toUpperCase();
    const lbl = (this.orderInformation?.deliveryTerm?.label || '').toUpperCase();
    const isCOL = val === 'COL' || lbl === 'COL';

    this.showAccountNumberField = isCOL;

    // Optional: hydrate local value if parent already provided one
    this.accountNumber = this.orderInformation?.accountNumber || '';


    }
    handleShippingMethodChange(event) {
        let orderInfo = JSON.parse(JSON.stringify(this.orderInformation));
        orderInfo.deliveryTermOptions = orderInfo.deliveryTermData.values.filter(opt => opt.validFor.includes(orderInfo.deliveryTermData.controllerValues[event.detail.value]) && opt.childrenValidFor.includes(orderInfo.deliveryTermData.parentControllerValues[orderInfo.orderType.value]));
        if (orderInfo.deliveryTermOptions.length == 1) {
            orderInfo.deliveryTermOptions.forEach(options => {
                orderInfo.deliveryTerm.value = options.value;
                orderInfo.deliveryTerm.label = orderInfo.deliveryTermOptions.find(element => element.value == options.value).label;
            });
        }
        orderInfo.shippingMethod.value = event.detail.value;
        orderInfo.shippingMethod.label = orderInfo.shippingMethodOptions.find(element => element.value == event.detail.value).label;
        
        const isCOL = this._isCOL(orderInfo.deliveryTerm);
        this.showAccountNumberField = isCOL;

        // Optional: clear value when not COL to avoid stale payloads
        if (!isCOL) {
            this.accountNumber = '';
            orderInfo.accountNumber = '';
        }

        this.orderInformation = orderInfo;
        this.notifyAction();
    }

    handleDeliveryTermChange(event) {
        let orderInfo = JSON.parse(JSON.stringify(this.orderInformation));
        orderInfo.deliveryTerm.value = event.detail.value;
        
        orderInfo.deliveryTerm.label = orderInfo.deliveryTermOptions.find(element => element.value == event.detail.value).label;
        
        const isCOL = this._isCOL(orderInfo.deliveryTerm);
        this.showAccountNumberField = isCOL;

        if (!isCOL) {
            this.accountNumber = '';
            orderInfo.accountNumber = '';
        }

    
        this.orderInformation = orderInfo;
        this.notifyAction();
    }

    handleAccountNumberChange(event){
        
    this.accountNumber = event.detail.value;

    let orderInfo = JSON.parse(JSON.stringify(this.orderInformation));
    orderInfo.accountNumber = this.accountNumber || '';

    this.orderInformation = orderInfo;
    this.notifyAction();
    }

    shipCompletePopUpTrigger(event) {
        if (event.target.checked) {
            this.showShipCompleteModal = true;
        }

    }
    handleShipCompleteChange(event) {
        let orderInfo = JSON.parse(JSON.stringify(this.orderInformation));
        if (event.target.title == okLabel) {
            orderInfo.shipComplete = true;
        }
        else {
            orderInfo.shipComplete = false;
            this.template.querySelector('.shipSelector').checked = false
        }
        this.orderInformation = orderInfo;
        this.notifyAction();
        this.showShipCompleteModal = false;
    }

    handleRequestedDateChange(event) {
        let orderInfo = JSON.parse(JSON.stringify(this.orderInformation));
        orderInfo.requestedDate = event.detail.value;
        this.orderInformation = orderInfo;
        this.notifyAction();
    }

    handleShippingAddressChange(event) {
        this.shippingAddressIndex = event.detail.value;
    }

    handleClickCancel() {
        this.showAddressesPopUp = false;
    }

    handleChangeAddress() {
        this.showAddressesPopUp = true;
        let orderInfo = JSON.parse(JSON.stringify(this.orderInformation));
        this.isActivesec = orderInfo.isActivesec;
        if(orderInfo.customerType == 'V1H' && orderInfo.shippingAddressOptions.length == 0){
            this.isActivesec = true;
        }
        if (this.isActivesec) {
            this.activeSections = ["New Address"];
            this.mailingName = orderInfo.shippingMailingName;
            this.street = orderInfo.shippingStreetValue;
            this.country = orderInfo.shippingCountryValue;
            this.state = orderInfo.shippingStateValue;
            this.zipCode = orderInfo.shippingPostalCodeValue;
            this.city = orderInfo.shippingCityValue;
        }else {
            this.activeSections = ["Existing Address"];
        }
    }

    handleSectionToggle(event) {
        this.slectedSection = event.detail.openSections;
    }

    isInputValid() {
        let isValid = true;
        let inputFields = this.template.querySelectorAll('.validate');
        inputFields.forEach(inputField => {
            if (!inputField.checkValidity()) {
                inputField.reportValidity();
                isValid = false;
            }
        });
        return isValid;
    }

    handleClickSubmit(event) {
        if (this.slectedSection == "New Address") {
            this.isActivesec = true;
            let orderInfo = JSON.parse(JSON.stringify(this.orderInformation));
            orderInfo.selectedSection = this.slectedSection;
            orderInfo.isActivesec = this.isActivesec;
            if (this.isInputValid()) {
                this.showAddressesPopUp = false;
                var inputRecieved = this.template.querySelectorAll("lightning-input");
                inputRecieved.forEach(function (element) {
                    if (element.name == "MailingName") {
                        orderInfo.shippingMailingName = element.value;
                    }
                    if (element.name == "Street") {
                        orderInfo.shippingStreetValue = element.value;
                    }
                    if (element.name == "City") {
                        orderInfo.shippingCityValue = element.value;
                    }
                    if (element.name == "ZipCode") {
                        orderInfo.shippingPostalCodeValue = element.value;
                    }
                    orderInfo.shippingStateValue = this.state;
                    orderInfo.shippingCountryValue = this.country;
                    orderInfo.shippingCountryDisplayValue = orderInfo.countryListOption.find(opt => opt.value == this.country).label;
                    orderInfo.shippingAddressValue = orderInfo.shippingMailingName + ',' +orderInfo.shippingStreetValue + ',' + orderInfo.shippingCityValue + ',' + orderInfo.shippingPostalCodeValue + ',' + orderInfo.shippingStateValue + ',' + orderInfo.shippingCountryDisplayValue;
                }, this);
                this.orderInformation = orderInfo;
                this.notifyAction();
            }
        }
        if (this.slectedSection == "Existing Address") {
            this.showAddressesPopUp = false;
            this.isActivesec = false;
            let orderInfo = JSON.parse(JSON.stringify(this.orderInformation));
            let shippingDetails = this.shippingAddressOptions.find(element => element.value == this.shippingAddressIndex);
            orderInfo.shippingNATTAddressId = shippingDetails.shippingNATTAddressId;
            orderInfo.shippingAddressValue = shippingDetails.label;
            orderInfo.shippingStreetValue = shippingDetails.street;
            orderInfo.shippingCityValue = shippingDetails.city;
            orderInfo.shippingStateValue = shippingDetails.state;
            orderInfo.shippingPostalCodeValue = shippingDetails.postalcode;
            orderInfo.shippingCountryValue = shippingDetails.country;
            orderInfo.selectedSection = this.slectedSection;
            orderInfo.isActivesec = this.isActivesec;
            this.orderInformation = orderInfo;
            this.notifyAction();
        }
    }

    fetchRushOrderCharge() {
        let effAccount = sessionStorage.getItem("effectiveAccountId");
        getRushOrderCharge({ accountId: effAccount })
            .then(result => {
                this.showSpinner = false;
                try {
                    if (result.hasError) {
                        this.dispatchEvent(
                            new ShowToastEvent({
                                title: 'Error',
                                message: 'Please contact system admin for more details',
                                variant: 'error',
                                mode: 'dismissable'
                            })
                        );
                    } else {
                        if (result > 0) {
                            let orderInfo = JSON.parse(JSON.stringify(this.orderInformation));
                            orderInfo.rushFee = result;
                            orderInfo.totalRushFee = orderInfo.totalNonCoreCartAmount * orderInfo.rushFee;
                            orderInfo.totalAmount = Number((parseFloat(orderInfo.totalAmount) + parseFloat(orderInfo.totalRushFee)).toFixed(2));
                            orderInfo.canReceiveRushOrderCharge = true;
                            this.orderInformation = orderInfo;
                            this.notifyAction();
                        } else {
                            let orderInfo = JSON.parse(JSON.stringify(this.orderInformation));
                            orderInfo.rushFee = 0.0;
                            orderInfo.totalRushFee = 0.0;
                            orderInfo.totalAmount = orderInfo.totalAmountOriginal;
                            orderInfo.canReceiveRushOrderCharge = false;
                            this.orderInformation = orderInfo;
                            this.notifyAction();
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

    handleCountryChange(event){
        this.country = event.detail.value;
        let orderInfo = JSON.parse(JSON.stringify(this.orderInformation));
        orderInfo.stateListOptions = orderInfo.countyStateMapping.find(opt => opt.key == this.country).value;
        if(orderInfo.stateListOptions.length == 1){
            this.state = orderInfo.stateListOptions[0].value;
        }else{
            this.state = '';
        }
        this.orderInformation = orderInfo;
    }

    handleStateChange(event){
        this.state = event.detail.value; 
    }

    notifyAction() {
        this.dispatchEvent(
            new CustomEvent('orderinfo', {
                bubbles: true,
                composed: true,
                detail: this.orderInformation
            })
        );
    }
}