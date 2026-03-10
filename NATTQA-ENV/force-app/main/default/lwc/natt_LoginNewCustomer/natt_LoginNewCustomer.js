import { LightningElement } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';

export default class Natt_LoginNewCustomer  extends NavigationMixin (LightningElement) { 
   
    createAccount() {
        console.log('button click');
        this[NavigationMixin.Navigate]({
            type: 'comm__namedPage',
            attributes: {
                name:'New_User_Registration__c'
            }
        });
    }

}