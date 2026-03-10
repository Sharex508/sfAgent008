import { LightningElement,api } from 'lwc';
import contactFirstNameLabel from '@salesforce/label/c.nac_ContactFirstName';
import contactLastNameLabel from '@salesforce/label/c.nac_ContactLastName';
import phoneNumberLabel from '@salesforce/label/c.nac_PhoneNumber1';
import emailAddressLabel from '@salesforce/label/c.nac_EmailAddress';


const DELAY = 300;
export default class Nac_ContactFinanceDetails extends LightningElement {

    
    @api signupInformation;
    delayTimeout;
    showSpinner = false;

    labels = {
        contactFirstNameLabel,
        contactLastNameLabel,
        phoneNumberLabel,
        emailAddressLabel
    }

    handleContactFirstNamechange(event){
        let signupInfo = JSON.parse(JSON.stringify(this.signupInformation));
        signupInfo.contactFinanceFirstName = event.target.value;
        this.delayTimeout = setTimeout(() => {
            this.signupInformation = signupInfo;
            this.notifyAction();
        }, DELAY);   
    }

    handleContactLastNamechange(event){
        let signupInfo = JSON.parse(JSON.stringify(this.signupInformation));
        signupInfo.contactFinanceLastName = event.target.value;
        this.delayTimeout = setTimeout(() => {
            this.signupInformation = signupInfo;
            this.notifyAction();
        }, DELAY);   
    }

    
    handlePhoneNumberchange(event){
        let signupInfo = JSON.parse(JSON.stringify(this.signupInformation));
        signupInfo.contactFinancePhoneNumber = event.target.value;
        this.delayTimeout = setTimeout(() => {
            this.signupInformation = signupInfo;
            this.notifyAction();
        }, DELAY);   
    }


    handleEmailValidation(event){        
       
        let signupInfo = JSON.parse(JSON.stringify(this.signupInformation));
        signupInfo.contactFinanceEmailAddress = event.target.value;
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