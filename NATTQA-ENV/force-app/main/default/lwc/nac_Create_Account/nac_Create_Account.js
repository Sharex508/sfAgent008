import { LightningElement,track,api } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import createAccount from '@salesforce/apex/NAC_UserSignUp.createAccount';
import fetchCountryandStates from '@salesforce/apex/NAC_UserSignUp.fetchCountryandStates';
import companyDetailsLabel from '@salesforce/label/c.nac_CompanyDetails';
import billingDetailsLabel from '@salesforce/label/c.nac_BillingDetails';
import shippingDetailsLabel from '@salesforce/label/c.nac_ShippingDetails';
import partsContactDetailsLabel from '@salesforce/label/c.nac_PartsContactDetails';
import financeContactDetailsLabel from '@salesforce/label/c.nac_FinanceContactDetails';
import continueLabel from '@salesforce/label/c.nac_Continue';
import submitLabel from '@salesforce/label/c.nac_Submit';
import signUpPathLabel from '@salesforce/label/c.nac_SignUpPath';
import signUpLabel from '@salesforce/label/c.nac_SignUp';

const STAGE1LABEL = companyDetailsLabel;
const STAGE2LABEL = billingDetailsLabel;
const STAGE3LABEL = shippingDetailsLabel;
const STAGE4LABEL = partsContactDetailsLabel;
const STAGE5LABEL = financeContactDetailsLabel;
const STAGE1NEXTBUTTONLABEL = continueLabel;
const STAGE2NEXTBUTTONLABEL = continueLabel;
const STAGE3NEXTBUTTONLABEL = continueLabel;
const STAGE4NEXTBUTTONLABEL = continueLabel;
const STAGE5NEXTBUTTONLABEL = submitLabel;

export default class Nac_Create_Account extends NavigationMixin(LightningElement) {

    labels={
        companyDetailsLabel,
        billingDetailsLabel,
        shippingDetailsLabel,
        partsContactDetailsLabel,
        financeContactDetailsLabel,
        continueLabel,
        submitLabel,
        signUpPathLabel,
        signUpLabel
    }

    currentStage = STAGE1LABEL;
    stages = [STAGE1LABEL, STAGE2LABEL, STAGE3LABEL, STAGE4LABEL, STAGE5LABEL];

    currentStage = STAGE1LABEL;
    step1 = true;
    step2 = false;
    step3 = false;
    step4 = false;
    step5 = false;
    step6 = false;

    disableNextButton = true;
    showBackButton = true;
    nextButtonLabel = STAGE1NEXTBUTTONLABEL;
    showSubmitButton = true;

    @track signupInformation = {
        legalCompanyName: '',
        accountPhoneNumber: '',
        accountEmailAddress: '',
        accountWebpage: '',
        accountBillingStreetAddress: '',
        accountBillingCity: '',
        accountBillingZipCode: '',
        accountBillingState: '',
        accountBillingCountry: '',
        accountShippingStreetAddress: '',
        accountShippingCity: '',
        accountShippingZipCode: '',
        accountShippingState: '',
        accountShippingCountry: '',
        contactPartsFirstName:'',
        contactPartsLastName:'',
        contactPartsPhoneNumber:'',
        contactPartsEmailAddress:'',
        contactFinanceFirstName:'',
        contactFinanceLastName:'',
        contactFinancePhoneNumber:'',
        contactFinanceEmailAddress:''

    }

    handleClickNext() {        
        
        switch (this.currentStage) {
            case STAGE1LABEL:
                this.currentStage = STAGE2LABEL;
                this.nextButtonLabel = STAGE2NEXTBUTTONLABEL;
                this.showBackButton = true;
                if(this.signupInformation.accountBillingStreetAddress && this.signupInformation.accountBillingCity &&
                    this.signupInformation.accountBillingZipCode && this.signupInformation.accountBillingState && 
                    this.signupInformation.accountBillingCountry){                    
                        this.disableNextButton = false;
                    }else{
                        this.disableNextButton = true;
                }
                this.step1 = false;
                this.step2 = true;
                this.step3 = false;
                this.step4 = false;
                this.step5 = false;
                this.step6 = false;
                break;
            case STAGE2LABEL:
                
                this.currentStage = STAGE3LABEL;
                this.nextButtonLabel = STAGE3NEXTBUTTONLABEL;
                this.showBackButton = true;
                if(this.signupInformation.accountShippingStreetAddress && this.signupInformation.accountShippingCity &&
                    this.signupInformation.accountShippingZipCode && this.signupInformation.accountShippingState && 
                    this.signupInformation.accountShippingCountry){                    
                        this.disableNextButton = false;
                    }else{
                        this.disableNextButton = true;
                }
                this.step1 = false;
                this.step2 = false;
                this.step3 = true;
                this.step4 = false;
                this.step5 = false;
                this.step6 = false;
                break;
            case STAGE3LABEL:
                this.currentStage = STAGE4LABEL;
                this.nextButtonLabel = STAGE4NEXTBUTTONLABEL;
                this.showBackButton = true;
                if(this.signupInformation.contactPartsFirstName && this.signupInformation.contactPartsLastName &&
                    this.signupInformation.contactPartsPhoneNumber  && this.signupInformation.contactPartsEmailAddress){                    
                        this.disableNextButton = false;
                    }else{
                        this.disableNextButton = true;
                }
                this.step1 = false;
                this.step2 = false;
                this.step3 = false;
                this.step4 = true;
                this.step5 = false;
                this.step6 = false;
                break;
            case STAGE4LABEL:   
                this.currentStage = STAGE5LABEL;
                this.nextButtonLabel = STAGE5NEXTBUTTONLABEL;
                this.showBackButton = true;
                if(this.signupInformation.contactFinanceFirstName && this.signupInformation.contactFinanceLastName &&
                    this.signupInformation.contactFinancePhoneNumber && this.signupInformation.contactFinanceEmailAddress){                        
                        this.disableNextButton = false;
                    }else{
                        this.disableNextButton = true;
                }
                this.step1 = false;
                this.step2 = false;
                this.step3 = false;
                this.step4 = false;
                this.step5 = true;
                this.step6 = false;
            break;
            case STAGE5LABEL:                             
                this.signupAccount();              
                this.step1 = false;
                this.step2 = false;
                this.step3 = false;
                this.step4 = false;
                this.step5 = false;
                this.step6 = true;
                this.showBackButton = false;
                this.disableNextButton = false;                
                this.showSubmitButton = false;               
                break;              
                
            default:
                this.currentStage = STAGE1LABEL;
                this.nextButtonLabel = STAGE1NEXTBUTTONLABEL;
                this.showBackButton = true;
                this.disableNextButton = false;
                this.step1 = true;
                this.step2 = false;
                this.step3 = false;
                this.step4 = false;
                this.step5 = false;
        }
    }

    handleClickBack() {
        switch (this.currentStage) {
            case STAGE5LABEL:                
                this.currentStage = STAGE4LABEL;            
                this.step1 = false;
                this.step2 = false;
                this.step3 = false;
                this.step4 = true;
                this.step5 = false;
                this.step6 = false;
                this.showBackButton = true;
                this.disableNextButton = false;
                this.showSubmitButton = true;               
                break;                
            case STAGE4LABEL:
                this.currentStage = STAGE3LABEL;
                this.nextButtonLabel = STAGE3NEXTBUTTONLABEL;
                this.showBackButton = true;
                this.disableNextButton = false;
                this.step1 = false;
                this.step2 = false;
                this.step3 = true;
                this.step4 = false;
                this.step5 = false;
                this.step6 = false;
                break;
            case STAGE3LABEL:                
                this.currentStage = STAGE2LABEL;
                this.nextButtonLabel = STAGE2NEXTBUTTONLABEL;
                this.showBackButton = true;
                this.disableNextButton = false;
                this.step1 = false;
                this.step2 = true;
                this.step3 = false;
                this.step4 = false;
                this.step5 = false;
                this.step6 = false;
                break;
            case STAGE2LABEL:
                this.currentStage = STAGE1LABEL;
                this.nextButtonLabel = STAGE1NEXTBUTTONLABEL;
                this.showBackButton = false;
                this.disableNextButton = false;
                this.step1 = true;
                this.step2 = false;
                this.step3 = false;
                this.step4 = false;
                this.step5 = false;
                this.step6 = false;
                
                break;
            case STAGE1LABEL:
                this[NavigationMixin.Navigate]({
                type: 'standard__webPage',
                    attributes: {
                        url: label.signUpLabel
                    }
                }); 
                break;    
            default:
                this.currentStage = STAGE1LABEL;
                this.nextButtonLabel = STAGE1NEXTBUTTONLABEL;
                this.showBackButton = true;
                this.disableNextButton = false;
                this.step1 = true;
                this.step2 = false;
                this.step3 = false;
                this.step4 = false;
                this.step5 = false;
                this.step6 = false;
        }
    }

    handlesignUpDataChange(event){
        this.signupInformation = event.detail;       
        if (this.step1) {
            if(this.signupInformation.legalCompanyName && this.signupInformation.accountPhoneNumber &&
                this.signupInformation.accountPhoneNumber && this.signupInformation.accountWebpage){
                    this.disableNextButton = false;
            }else{
                     this.disableNextButton = true;
            }
        }
        if (this.step2) {
         
            if(this.signupInformation.accountBillingStreetAddress && this.signupInformation.accountBillingCity &&
                this.signupInformation.accountBillingZipCode && this.signupInformation.accountBillingState && 
                this.signupInformation.accountBillingCountry){                    
                    this.disableNextButton = false;
                }else{
                    this.disableNextButton = true;
                }
        }

        if (this.step3) {
    
            if(this.signupInformation.accountShippingStreetAddress && this.signupInformation.accountShippingCity &&
                this.signupInformation.accountShippingZipCode && this.signupInformation.accountShippingState && 
                this.signupInformation.accountShippingCountry){                    
                    this.disableNextButton = false;
                }else{
                    this.disableNextButton = true;
                }
        }

        if (this.step4) {   
            if(this.signupInformation.contactPartsFirstName && this.signupInformation.contactPartsLastName &&
                this.signupInformation.contactPartsPhoneNumber  && this.signupInformation.contactPartsEmailAddress){                    
                    this.disableNextButton = false;
                }else{
                    this.disableNextButton = true;
                }
        }
        if (this.step5) {
                if(this.signupInformation.contactFinanceFirstName && this.signupInformation.contactFinanceLastName &&
                    this.signupInformation.contactFinancePhoneNumber && this.signupInformation.contactFinanceEmailAddress){                        
                        this.disableNextButton = false;
                    }else{
                        this.disableNextButton = true;
                    }
            }
     }

     signupAccount(){        
        createAccount({ accountData: this.signupInformation})
            .then(result => {
                if(result==true){
                    this.isContactCreated=true;
                    this.dispatchEvent(
                        new ShowToastEvent({
                            title: 'Success',
                            message: 'The Account creation request has been submitted for approval. You will be notified once this is approved',
                            variant: 'success',
                            mode: 'dismissable'
                        })
                    );

                }
            }).catch(error => {
                this.showSpinner = false;
                console.log('Error' + JSON.stringify(error));
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Error',
                        message: JSON.stringify(error),
                        variant: 'error',
                        mode: 'dismissable'
                    })
                );
            });
     } 


    @track mapData= [];
    @track contList=[];
    @track resultMap;
    @track countryProvinceMapNew=[];
    @api stateListOptions=[];
    @api shippingStateListOptions =[];
    
    connectedCallback(){
    
       try{       
        //fetch all country and state picklist
        fetchCountryandStates()
            .then(result => {                
                this.resultMap = result;
                if(result){                   
                    for (let key in result) {
                        this.mapData.push({value:result[key], key:key});
                        this.contList.push({label: key , value : result[key][0].nac_Country_Code__c});
                        let statelist=[];
                        let conCode= result[key][0].nac_Country_Code__c;
                        for(let key2 in result[key]){
                            if(key2 == 0){
                                statelist=[];                               
                            }
                            var state= result[key][key2].nac_State__c;
                            var stateCode= result[key][key2].nac_State_Code__c;
                            statelist.push({label: state, value:stateCode})
                            
                        }
                        statelist.sort((a,b)=>a.label.localeCompare(b.label));
                        this.countryProvinceMapNew.push({value:statelist, key:conCode});
                       
                     }
                     
                }
                
            })
            .catch(error => {
                this.showSpinner = false;                
                console.log('Error' + JSON.stringify(error));
            });

        }catch(ex){
            console.log(ex);
    
        }
    }

}