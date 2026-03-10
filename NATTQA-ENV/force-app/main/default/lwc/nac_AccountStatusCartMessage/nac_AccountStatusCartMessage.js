import { LightningElement , wire } from 'lwc';
import userId from '@salesforce/user/Id';
import { getRecord } from 'lightning/uiRecordApi';
import AccountId from '@salesforce/schema/User.AccountId';
import ACCOUNT_STATUS_VALUES from '@salesforce/label/c.NAC_AccountStatusValues';
import getPendingPaymentStatus from '@salesforce/apex/Nac_AccountStatusCartHelper.getPendingPaymentStatus';
import getAccountCartMessage from '@salesforce/label/c.NAC_AccountHoldCartMessage';
export default class Nac_AccountStatusCartMessage extends LightningElement {

    effectiveAccountId;
    accountStatus;
    checkStatus = false;
    cartMessage = getAccountCartMessage;

    statusList = {};
    constructor() {
        super();
        this.statusList = ACCOUNT_STATUS_VALUES.split(',').map(s => s.trim());
        console.log('Allowed status values:', this.statusList);
    }
    
   
    @wire(getRecord, { recordId: userId, fields : [AccountId]})
    wiredRecord({data,error}){
        if(data){
            this.effectiveAccountId = data.fields.AccountId.value;
            console.log('this.effectiveAccountId=>>'+this.effectiveAccountId);
            this.getAccountStatus();
        }
    }

    getAccountStatus(){
        
        getPendingPaymentStatus({ AccId : this.effectiveAccountId })
        .then(data =>{
                this.accountStatus = data;
                if(this.statusList.includes(this.accountStatus)){

                    console.log('in the loop check RH'+this.accountStatus);
                    this.checkStatus = true;
                }
                else{
                    this.checkStatus = false;
                }
            
            }).catch(error=>{
                console.log('error'+error);
            })
    }

}