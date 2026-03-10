import { LightningElement,api,track } from 'lwc';
import getAddressDetails from '@salesforce/apex/NAC_UserSignUp.getAddressDetails';

const DELAY = 300;
export default class Nac_NewUserAddressDetails extends LightningElement {
    @api signupInformation;
    
    @api selectedAccountNumber;
    @api selectedAddressIndex;

    shippingAddressOptions = [];
    @track billingAddressOptions =[];
    showSpinner = false;
    connectedCallback() {
        
        this.showSpinner = true;
        getAddressDetails({ userAccountNumber: this.signupInformation.accountNumber})
        .then(result => {
            this.showSpinner = false;
            console.log(JSON.stringify(result));
            try{
                let billingAddressList = result.addressList.filter(address => address.AddressType == 'Shipping');
                billingAddressList.forEach(data => {
                    let address = '';
                    if (data.Street) address += data.Street;
                        if (data.City) address += ' ' + data.City;
                        if (data.State) address += ' ' + data.State;
                        if (data.PostalCode) address += ' ' + data.PostalCode;
                        if (data.Country) address += ' ' + data.Country;
                        this.billingAddressOptions.push({
                            label: address,
                            value: data.Id,
                            street: data.Street,
                            city: data.City,
                            state: data.State,
                            postalcode: data.PostalCode,
                            country: data.Country,
                        });
                        this.billingAddressIndex = data.Id;
                       
                        if (data.IsDefault) {
                          /*  this.signupInformation.billingAddressValue = address;
                            this.signupInformation.billingStreetValue = data.Street;
                            this.signupInformation.billingCityValue = data.City;
                            this.signupInformation.billingStateValue = data.State;
                            this.signupInformation.billingPostalCodeValue = data.PostalCode;
                            this.signupInformation.billingCountryValue = data.Country;
                            this.billingAddressIndex = data.Id;**/
                        }
                });
                
            }catch (error) {
                console.log('In Error---');
                this.showSpinner = false;
                console.log(JSON.stringify(error.message));
            }
        })
        .catch(error => {
            this.showSpinner = false;
            console.log('Error' + JSON.stringify(error));
        });
    }

    handleSelectedAddressChange(event){
        this.selectedAddressIndex = event.detail.value; 
        let signupInfo = JSON.parse(JSON.stringify(this.signupInformation));
        let selectedAddDetails = this.billingAddressOptions.find(element => element.value == this.selectedAddressIndex);
        
        signupInfo.selectedAddressLabel= selectedAddDetails.label;
        signupInfo.selectedAddressStreet = selectedAddDetails.street;
        signupInfo.selectedAddressCity = selectedAddDetails.city;
        signupInfo.selectedAddressState = selectedAddDetails.state;
        signupInfo.selectedAddressZipCode = selectedAddDetails.postalcode;
        signupInfo.selectedAddressCountry = selectedAddDetails.country;
        this.signupInformation = signupInfo;
        this.notifyAction();
    }

    notifyAction() {
        this.dispatchEvent(
            new CustomEvent('signupinfo', {
                bubbles: true,
                composed: true,
                detail: this.signupInformation
            })
        );
    }

}