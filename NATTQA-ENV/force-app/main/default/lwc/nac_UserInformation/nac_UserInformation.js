import { LightningElement,api } from 'lwc';
import legalCompanyNameLabel from '@salesforce/label/c.nac_LegalCompanyName';
import phoneNumberLabel from '@salesforce/label/c.nac_PhoneNumber1';
import emailAddressLabel from '@salesforce/label/c.nac_EmailAddress';
import webpageLabel from '@salesforce/label/c.nac_Webpage';


const DELAY = 300;

export default class Nac_UserInformation extends LightningElement {

    @api signupInformation;
    delayTimeout;
    showSpinner = false;

    labels={
        legalCompanyNameLabel,
        phoneNumberLabel,
        emailAddressLabel,
        webpageLabel
    }
    
    handlePhoneNumberchange(event){
        let signupInfo = JSON.parse(JSON.stringify(this.signupInformation));
        signupInfo.accountPhoneNumber = event.target.value;
        this.delayTimeout = setTimeout(() => {
            this.signupInformation = signupInfo;
            this.notifyAction();
        }, DELAY);   
    }

    handleCompanyNamechange(event){    
           
        let signupInfo = JSON.parse(JSON.stringify(this.signupInformation));
        signupInfo.legalCompanyName = event.target.value;
        this.delayTimeout = setTimeout(() => {
            this.signupInformation = signupInfo;
            this.notifyAction();
        }, DELAY);
          
    }

    handleEmailchange(event){
        let signupInfo = JSON.parse(JSON.stringify(this.signupInformation));
        signupInfo.accountEmailAddress = event.target.value;
        this.delayTimeout = setTimeout(() => {
            this.signupInformation = signupInfo;
            this.notifyAction();
        }, DELAY);   
    }

    handleWebsitechange(event){
        let signupInfo = JSON.parse(JSON.stringify(this.signupInformation));
        signupInfo.accountWebpage = event.target.value;
        this.delayTimeout = setTimeout(() => {
            this.signupInformation = signupInfo;
            this.notifyAction();
        }, DELAY);   
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