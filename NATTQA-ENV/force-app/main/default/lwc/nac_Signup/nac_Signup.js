import { LightningElement } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import alreadyAccountLabel from '@salesforce/label/c.nac_AlreadyAccountLabel';
import signUp from '@salesforce/label/c.nac_SignUp1'; 
import chooseAccountType from '@salesforce/label/c.nac_ChooseAccountType'; 
import createNewCustomerAccount from '@salesforce/label/c.nac_CreateNewCustomerAccount';  
import oRLabel from '@salesforce/label/c.nac_OR'; 
import clickHereToLogin from '@salesforce/label/c.nac_ClickHereToLogin'; 


export default class Nac_Signup extends NavigationMixin(LightningElement) {

    labels={
        alreadyAccountLabel,
        signUp,
        chooseAccountType,
        createNewCustomerAccount,
        oRLabel,
        clickHereToLogin
    }


    navigateToLoginPage() {     
        try{          
            this[NavigationMixin.Navigate]({
                type: 'standard__webPage',
                attributes: {
                    url: '/login'
                }
            });                       
        }
        catch (error) {
            console.log(JSON.stringify(error.message));
        }
    }

    navigateToCreateNewAccountPage() {     
        try{          
            this[NavigationMixin.Navigate]({
                type: 'standard__webPage',
                attributes: {
                    url: '/new-customer-account'
                }
            });                       
        }
        catch (error) {
            console.log(JSON.stringify(error.message));
        }
    }

    navigateToCreateNewUser() {     
        try{          
            this[NavigationMixin.Navigate]({
                type: 'standard__webPage',
                attributes: {
                    url: '/new-user'
                }
            });                       
        }
        catch (error) {
            console.log(JSON.stringify(error.message));
        }
    }

}