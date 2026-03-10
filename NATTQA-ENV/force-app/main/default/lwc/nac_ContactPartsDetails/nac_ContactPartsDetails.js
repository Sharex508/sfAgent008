import { LightningElement,api } from 'lwc';
import contactFirstNameLabel from '@salesforce/label/c.nac_ContactFirstName';
import contactLastNameLabel from '@salesforce/label/c.nac_ContactLastName';
import phoneNumberLabel from '@salesforce/label/c.nac_PhoneNumber1';
import emailAddressLabel from '@salesforce/label/c.nac_EmailAddress';

const DELAY = 300;
export default class Nac_ContactPartsDetails extends LightningElement {

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
        signupInfo.contactPartsFirstName = event.target.value;
        this.delayTimeout = setTimeout(() => {
            this.signupInformation = signupInfo;
            this.notifyAction();
        }, DELAY);   
    }

    handleContactLastNamechange(event){
        let signupInfo = JSON.parse(JSON.stringify(this.signupInformation));
        signupInfo.contactPartsLastName = event.target.value;
        this.delayTimeout = setTimeout(() => {
            this.signupInformation = signupInfo;
            this.notifyAction();
        }, DELAY);   
    }

    
    handlePhoneNumberchange(event){
        let signupInfo = JSON.parse(JSON.stringify(this.signupInformation));
        signupInfo.contactPartsPhoneNumber = event.target.value;
        this.delayTimeout = setTimeout(() => {
            this.signupInformation = signupInfo;
            this.notifyAction();
        }, DELAY);   
    }


    handleEmailValidation(event){        
       
        let signupInfo = JSON.parse(JSON.stringify(this.signupInformation));
        signupInfo.contactPartsEmailAddress = event.target.value;
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