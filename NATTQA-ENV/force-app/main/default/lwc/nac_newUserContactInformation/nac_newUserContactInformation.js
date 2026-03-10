import { LightningElement,api } from 'lwc';
import getAccountNumberDetails from '@salesforce/apex/NAC_UserSignUp.getAccountNumberDetails';

const DELAY = 300;

export default class Nac_newUserContactInformation extends LightningElement {
    @api signupInformation;
    delayTimeout;
    showSpinner = false;
    @api effectiveAccountId;

    connectedCallback() { 
        getAccountNumberDetails()
        .then(result => {
            try{
            this.showSpinner = false;
            console.log(JSON.stringify(result));                    
            let signupInfo = JSON.parse(JSON.stringify(this.signupInformation));
            signupInfo.accountNumber = this.effectiveAccountId;
            if(result!=''){                        
                signupInfo.accountName = result; 
                this.signupInformation = signupInfo; 
                this.notifyAction();
            }
        }catch(exception){
            this.showSpinner = false;
            console.log('Error' + JSON.stringify(exception));
        }
        }).catch(error => {
            this.showSpinner = false;
            console.log('Error' + JSON.stringify(error));
        });

    }
   
    handleContactFirstNamechange(event){
        let signupInfo = JSON.parse(JSON.stringify(this.signupInformation));
        signupInfo.contactFirstName = event.target.value;
        this.delayTimeout = setTimeout(() => {
            this.signupInformation = signupInfo;
            this.notifyAction();
        }, DELAY);   
    }

    handleContactLastNamechange(event){
        let signupInfo = JSON.parse(JSON.stringify(this.signupInformation));
        signupInfo.contactLastName = event.target.value;
        this.delayTimeout = setTimeout(() => {
            this.signupInformation = signupInfo;
            this.notifyAction();
        }, DELAY);   
    }

    handleJobTitlechange(event){
        let signupInfo = JSON.parse(JSON.stringify(this.signupInformation));
        signupInfo.jobTitle = event.target.value;
        this.delayTimeout = setTimeout(() => {
            this.signupInformation = signupInfo;
            this.notifyAction();
        }, DELAY);   
    }

    contactTypevalue='';
    get options() {
        return [
            { label: 'Parts Ordering', value: 'Parts Ordering' },
            { label: 'Finance', value: 'Finance' },            
        ];
    }
    handleContactTypeChange(event) {
        this.contactTypevalue = event.detail.value;
        let signupInfo = JSON.parse(JSON.stringify(this.signupInformation));
        signupInfo.contactType = this.contactTypevalue;
        this.delayTimeout = setTimeout(() => {
            this.signupInformation = signupInfo;
            this.notifyAction();
        }, DELAY);  
    }

  
    handleEmailValidation(event){        
        const emailRegex = /^(([^<>()\[\]\\.,;:\s@"]+(\.[^<>()\[\]\\.,;:\s@"]+)*)|(".+"))@((\[[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}])|(([a-zA-Z\-0-9]+\.)+[a-zA-Z]{2,}))$/;
        let emailVal = event.target.value;
        let email = this.template.querySelector('lightning-input[data-id=email]'); 
        let signupInfo = JSON.parse(JSON.stringify(this.signupInformation));
        if(emailVal.match(emailRegex)){
            email.setCustomValidity("");            
            signupInfo.email = event.target.value;
            this.delayTimeout = setTimeout(() => {
                this.signupInformation = signupInfo;
                this.notifyAction();
            }, DELAY);
        }else{
            signupInfo.email='';
            email.setCustomValidity("Please enter valid email");
            this.delayTimeout = setTimeout(() => {
                this.signupInformation = signupInfo;
                this.notifyAction();
            }, DELAY);
        }
        email.reportValidity();
    
       
    }

    /** handlePhoneNumberchange(event){           
            const phoneRegex = /^[0-9]{10,15}$/;
            let phoneVal = event.target.value;
            let phone = this.template.querySelector('lightning-input[data-id=phonenum]'); 
            let signupInfo = JSON.parse(JSON.stringify(this.signupInformation));
            if(phoneVal.match(phoneRegex)){
                phone.setCustomValidity("");            
                signupInfo.phoneNumber = event.target.value;
                this.delayTimeout = setTimeout(() => {
                    this.signupInformation = signupInfo;
                    this.notifyAction();
                }, DELAY);
            }else{
                signupInfo.phoneNumber='';
                phone.setCustomValidity("Please enter a valid phone number(10-15 digits)");
                this.delayTimeout = setTimeout(() => {
                    this.signupInformation = signupInfo;
                    this.notifyAction();
                }, DELAY);
            }
            phone.reportValidity();    
    }**/

    handlePhoneNumberchange(event){
        let signupInfo = JSON.parse(JSON.stringify(this.signupInformation));
        signupInfo.phoneNumber = event.target.value;
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