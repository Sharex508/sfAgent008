import { LightningElement,api,track } from 'lwc';
import addressesLabel from '@salesforce/label/c.nac_addresses';
import cityLabel from '@salesforce/label/c.nac_city1';
import zipCodeLabel from '@salesforce/label/c.nac_ZipCode1';
import stateLabel from '@salesforce/label/c.nac_State';
import countryLabel from '@salesforce/label/c.nac_Country';



const DELAY = 300;
export default class Nac_NewBillingDetails extends LightningElement {

    @api signupInformation;
    @api countryProvinceMapNew;
    @api contList;
    delayTimeout;
    @api stateListOptions;
    showSpinner = false;

    labels = {
        addressesLabel,
        cityLabel,
        zipCodeLabel,
        stateLabel,
        countryLabel
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
                this.stateListOptions = this.countryProvinceMapNew[key].value;
            }
        }
        let signupInfo = JSON.parse(JSON.stringify(this.signupInformation));
        signupInfo.accountBillingCountry = event.detail.value; 
        signupInfo.accountBillingState = ''; 
        this.signupInformation = signupInfo;
        this.notifyAction();
    }

    handleStateChange(event){
        let signupInfo = JSON.parse(JSON.stringify(this.signupInformation));
        signupInfo.accountBillingState = event.detail.value; 
        this.signupInformation = signupInfo;
        this.notifyAction();

    }

    handleZipChange(event){
        let signupInfo = JSON.parse(JSON.stringify(this.signupInformation));
        signupInfo.accountBillingZipCode = event.detail.value; 
        this.signupInformation = signupInfo;
        this.notifyAction();

    }

    handleCityChange(event){
        let signupInfo = JSON.parse(JSON.stringify(this.signupInformation));
        signupInfo.accountBillingCity = event.detail.value; 
        this.signupInformation = signupInfo;
        this.notifyAction();

    }

    handleStreetChange(event){
        let signupInfo = JSON.parse(JSON.stringify(this.signupInformation));
        signupInfo.accountBillingStreetAddress = event.detail.value; 
        this.signupInformation = signupInfo;
        this.notifyAction();

    }

    
    connectedCallback(){
        //State Picklist value autopopulate
        let signupInfo = JSON.parse(JSON.stringify(this.signupInformation));
        if(signupInfo.accountBillingState){
            if(signupInfo.accountBillingCountry){
                for(let key in this.countryProvinceMapNew){
                    if(this.countryProvinceMapNew[key].key == signupInfo.accountBillingCountry){
                        this.stateListOptions = this.countryProvinceMapNew[key].value;
                    }
                }
                

            }
        }

    }
    
    
}