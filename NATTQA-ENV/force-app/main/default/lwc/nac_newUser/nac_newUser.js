import { LightningElement,track,api } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import createContact from '@salesforce/apex/NAC_UserSignUp.createContact';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import isguest from '@salesforce/user/isGuest';

const STAGE1LABEL = 'Contact Details';
const STAGE2LABEL = 'Address Details';
const STAGE1NEXTBUTTONLABEL = 'Submit';
//const STAGE2NEXTBUTTONLABEL = 'Submit';


export default class Nac_Create_Account extends NavigationMixin(LightningElement) {
    currentStage = STAGE1LABEL;
    stages = [STAGE1LABEL, STAGE2LABEL];
    isGuestUser = isguest;
    
    step1 = true;
    step2 = false;
    step3 = false;
    shippingAddressOptions = [];
    isContactCreated=false;
    
    nextButtonLabel = STAGE1NEXTBUTTONLABEL;
    disableNextButton = true;
    showBackButton = true;
    showSubmitButton = true;
    @api effectiveAccountId;

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

    

    @track signupInformation = {
        accountNumber: '',
        accountName: '',
        contactFirstName: '',
        contactLastName: '',
        jobTitle: '',
        phoneNumber: '',
        email: '',
        contactType:'',
        addressDetails: '',
        selectedAddressLabel: '',
        selectedAddressStreet: '',
        selectedAddressCity:'',
        selectedAddressState:'',
        selectedAddressCountry:'',
        selectedAddressZipCode:''
    }


    handleClickNext() {
        switch (this.currentStage) {
            case STAGE1LABEL:
                this.createUser(); 
                /**this.currentStage = STAGE2LABEL;
                this.nextButtonLabel = STAGE2NEXTBUTTONLABEL;
                this.showBackButton = true;
                this.disableNextButton = true;                 
                this.step2 = true;
                this.step3 = false;
                this.step1 = false;
                **/
                // CXREF- 4664 Added 
                this.step1 = false;
                this.step3 = true;
                this.showBackButton = false;
                this.disableNextButton = true;
                this.showSubmitButton = false; 
                break;
            case STAGE2LABEL:
               /**this.createUser();              
                this.step1 = false;
                this.step2 = false;
                this.step3 = true;
                this.showBackButton = false;
                this.disableNextButton = true;
                this.showSubmitButton = false;   **/            
                break;
                
            default:
                this.currentStage = STAGE1LABEL;
                this.nextButtonLabel = STAGE1NEXTBUTTONLABEL;
                this.showBackButton = true;
                this.disableNextButton = false;
                this.step1 = true;
                this.step2 = false;
                this.step3 = false;
                     

        }
    }

    handleClickBack() {
        
        switch (this.currentStage) {
            case STAGE2LABEL:
              /**  this.currentStage = STAGE1LABEL;
                this.nextButtonLabel = STAGE1NEXTBUTTONLABEL;
                this.showBackButton = true;
                this.disableNextButton = false;                
                this.step1 = true;
                this.step2 = false;                
                break; */
            case STAGE1LABEL:
               
            if(this.isGuestUser){
                this[NavigationMixin.Navigate]({
                    type: 'standard__webPage',
                    attributes: {
                        url: '/sign-up'
                    }
                }); 
            }else{
                window.history.back();
            }
                 
                break;
             default:
                this.currentStage = STAGE1LABEL;
                this.nextButtonLabel = STAGE1NEXTBUTTONLABEL;
                this.showBackButton = true;
                this.disableNextButton = true;               
                this.step1 = true;
                this.step2 = false;
                  
        }
    }

    handlesignUpDataChange(event) {
        this.signupInformation = event.detail;
        if (this.step1) {
            if( this.signupInformation.accountName &&
                this.signupInformation.contactFirstName && this.signupInformation.contactLastName && 
                this.signupInformation.jobTitle && this.signupInformation.phoneNumber && this.signupInformation.email){
                    this.disableNextButton = false;
            }else{                
                     this.disableNextButton = true;
            }
        }
      
    }

    createUser() {                
        createContact({ contactData: this.signupInformation})
                .then(result => {                                        
                    if(!result){
                            this.dispatchEvent(
                            new ShowToastEvent({
                                title: 'Error',
                                message: 'Error Occurred in creating user',
                                variant: 'error',
                                mode: 'dismissable'
                            })
                        );                       

                    }else{
                        this.isContactCreated=true;
                        this.dispatchEvent(
                            new ShowToastEvent({
                                title: 'Success',
                                message: 'The contact creation request has been submitted for approval. You will be notified once this is approved',
                                variant: 'success',
                                mode: 'dismissable'
                            })
                        );

                    }
                    

                }).catch(error => {
                    this.showSpinner = false;
                    console.log('Error' + JSON.stringify(error));
                });
    }

    isInputValid() {
        let isValid = true;
        let inputFields = this.template.querySelectorAll('lightning-input');      
        
        inputFields.forEach(inputField => {
            if(!inputField.checkValidity()) {
                inputField.reportValidity();
                isValid = false;                
            }
            
        });
        return isValid;
    }

}