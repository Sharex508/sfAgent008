import { LightningElement, wire } from 'lwc';
import { getRecord } from 'lightning/uiRecordApi';
import getDescriptionLabel from '@salesforce/label/c.Email_Verification_Display_Text';
import emailVerificationButton from '@salesforce/label/c.Email_Verification_Button';
import userId from '@salesforce/user/Id';
import getDetails from '@salesforce/schema/User.HasUserVerifiedEmail';
import sendVerificationEmail   from '@salesforce/apex/NATT_EmailVerifications.InitiateEmailVerification';
export default class Natt_emailVerifications extends LightningElement {
    data;
    verifiedEmail = true;
    verifyEmailButtonLabel = emailVerificationButton;
    emailDescriptionLabel = getDescriptionLabel;
    
        handleClick(){
            this.sendEmail();
        }

        @wire(getRecord, { recordId: userId, fields : [getDetails]})
        wiredRecord({data,error}){
            if(data){
                this.verifiedEmail = data.fields.HasUserVerifiedEmail.value;
                console.log('this.verifiedEmail=>>'+this.verifiedEmail);
            }
        }

        sendEmail(){
            sendVerificationEmail({ UserId : userId })
                    .then(data=> {
                    console.log('Email has been sent'+data);
                    }).catch(error=>{
                    console.log('Failed to sent Emails');
                    });
        }

    
}