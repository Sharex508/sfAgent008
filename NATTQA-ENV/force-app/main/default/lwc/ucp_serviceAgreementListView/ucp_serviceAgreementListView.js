import { LightningElement,track } from 'lwc';
import getServiceAgreementRecord from '@salesforce/apex/ucp_serviceAgreement.getServiceAgreementRecord';
import { NavigationMixin } from 'lightning/navigation';


export default class Ucp_serviceAgreementListView extends NavigationMixin (LightningElement){
    @track serviceAgreementRecords;

    connectedCallback() {
        getServiceAgreementRecord()
        .then(result=> {
            if(result.length>0){
                this.serviceAgreementRecords = result;
                this.serviceAgreementRecords = result.map((record, index) => {
                    return {
                        ...record, // Spread existing record properties
                        sequenceNumber: index + 1  // Add sequence number
                    };
                });
        
                // Set account name and ID from the first record
                if(result[0]) {
                    this.strAccountName = result[0].Account__r.Name;
                    this.strAccountId = result[0].Account__c;
                }
                /*this.serviceAgreementVisible = true;
                this.blnNoRecordSA = false;
                this.isLoading = false;*/
            }
            else{
               /* this.serviceAgreementVisible = false;
                this.blnNoRecordSA = true;
                this.isLoading = false;*/
            }
        })
        .catch(error=> {
           // this.isLoading = false;
            console.error('Error fetching record:', error);
        });
    }

    handleServiceAgreementPage(event){
        const recordId = event.target.dataset.id;
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: {
                recordId: recordId,
                objectApiName: 'CONTAINER_Service_Agreement__c', 
                actionName: 'view'
            }
        });
    }

    handleAccountPage(event){
        const recordId = event.target.dataset.id;
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: {
                recordId: recordId,
                objectApiName: 'Account', 
                actionName: 'view'
            }
        });
    }
}