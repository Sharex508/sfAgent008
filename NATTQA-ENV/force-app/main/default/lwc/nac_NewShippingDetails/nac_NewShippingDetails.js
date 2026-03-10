import { LightningElement,api } from 'lwc';
import addressesLabel from '@salesforce/label/c.nac_addresses';
import cityLabel from '@salesforce/label/c.nac_city1';
import zipCodeLabel from '@salesforce/label/c.nac_ZipCode1';
import stateLabel from '@salesforce/label/c.nac_State';
import countryLabel from '@salesforce/label/c.nac_Country';
import sameAsBillingAddLabel from '@salesforce/label/c.nac_SameAsBillingAddLabel';


const DELAY = 300;
export default class Nac_NewShippingDetails extends LightningElement {

    @api signupInformation;
    delayTimeout;
    @api countryProvinceMapNew;
    @api contList;
    showSpinner = false;
    @api shippingStateListOptions;

    labels = {
        addressesLabel,
        cityLabel,
        zipCodeLabel,
        stateLabel,
        countryLabel,
        sameAsBillingAddLabel
    }


    handleSameBillingAddress(event){
        let signupInfo = JSON.parse(JSON.stringify(this.signupInformation));
        
        signupInfo.accountShippingStreetAddress = signupInfo.accountBillingStreetAddress;
        signupInfo.accountShippingCity = signupInfo.accountBillingCity;
        signupInfo.accountShippingState = signupInfo.accountBillingState;
        signupInfo.accountShippingCountry = signupInfo.accountBillingCountry;
        signupInfo.accountShippingZipCode = signupInfo.accountBillingZipCode;
        this.signupInformation = signupInfo;
        this.notifyAction();
        //Shipping State Picklist value autopopulate        
        if(signupInfo.accountBillingState){
            if(signupInfo.accountBillingCountry){
                for(let key in this.countryProvinceMapNew){
                    if(this.countryProvinceMapNew[key].key == signupInfo.accountBillingCountry){
                        this.shippingStateListOptions = this.countryProvinceMapNew[key].value;
                    }
                }
                

            }
        }
        
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

    handleCountryChange(event){
        let selectedCountry= event.detail.value;
        console.log(selectedCountry);
        console.log(JSON.stringify(this.countryProvinceMapNew));
        for(let key in this.countryProvinceMapNew){
            if(this.countryProvinceMapNew[key].key == selectedCountry){
                this.shippingStateListOptions = this.countryProvinceMapNew[key].value;
            }
        }
        
        let signupInfo = JSON.parse(JSON.stringify(this.signupInformation));
        signupInfo.accountShippingCountry = event.detail.value; 
        signupInfo.accountShippingState = ''; 
        this.signupInformation = signupInfo;
        this.notifyAction();
    }

    handleStateChange(event){
        let signupInfo = JSON.parse(JSON.stringify(this.signupInformation));
        signupInfo.accountShippingState = event.detail.value; 
        this.signupInformation = signupInfo;
        this.notifyAction();

    }

    handleZipChange(event){
        let signupInfo = JSON.parse(JSON.stringify(this.signupInformation));
        signupInfo.accountShippingZipCode = event.detail.value; 
        this.signupInformation = signupInfo;
        this.notifyAction();

    }

    handleCityChange(event){
        let signupInfo = JSON.parse(JSON.stringify(this.signupInformation));
        signupInfo.accountShippingCity = event.detail.value; 
        this.signupInformation = signupInfo;
        this.notifyAction();

    }

    handleStreetChange(event){
        let signupInfo = JSON.parse(JSON.stringify(this.signupInformation));
        signupInfo.accountShippingStreetAddress = event.detail.value; 
        this.signupInformation = signupInfo;
        this.notifyAction();

    }

    connectedCallback(){
        //Shipping State Picklist value autopopulate
        let signupInfo = JSON.parse(JSON.stringify(this.signupInformation));
        if(signupInfo.accountBillingState){
            if(signupInfo.accountBillingCountry){
                for(let key in this.countryProvinceMapNew){
                    if(this.countryProvinceMapNew[key].key == signupInfo.accountShippingCountry){
                        this.shippingStateListOptions = this.countryProvinceMapNew[key].value;
                    }
                }

            }
        }

    }
}