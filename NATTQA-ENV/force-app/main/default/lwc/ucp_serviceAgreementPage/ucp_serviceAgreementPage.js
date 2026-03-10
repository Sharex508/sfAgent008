import { LightningElement,track,api } from 'lwc';
import verifyUserDetails from '@salesforce/apex/ucp_serviceAgreement.verifyUserDetails';
import getServiceAgreementRecord from '@salesforce/apex/ucp_serviceAgreement.getServiceAgreementRecord';
import { NavigationMixin } from 'lightning/navigation';

export default class Ucp_serviceAgreementPage extends NavigationMixin(LightningElement)  {
    @track recordId;
    @track serviceAgreementRecords;
    @api isLoading = false;
    serviceAgreementVisible;
    blnNoRecordSA;
    error = false;
    strAccountName;
    strAccountId;
    noAccessMessage = 'You don\'t have access to this page, Please contact System Administrator for more details';
    
    connectedCallback() {
        this.isLoading = true;
        verifyUserDetails()
            .then(result=> {
                if(result == true){
                    this.getServiceAgreementRecord();
                }
                else{
                    this.error = true;
                }
                this.isLoading = false;
            })
            .catch(error=> {
                this.error = true;
                this.isLoading = false;
                console.error('Error fetching record ID:');
            });
       
    }
   

    getServiceAgreementRecord(){
        this.isLoading = true;
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
                this.serviceAgreementVisible = true;
                this.blnNoRecordSA = false;
                this.isLoading = false;
            }
            else{
                this.serviceAgreementVisible = false;
                this.blnNoRecordSA = true;
                this.isLoading = false;
            }
        })
        .catch(error=> {
            this.isLoading = false;
            console.error('Error fetching record:', error);
        });
    }

    handleAccountDetailPage(){
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: {
                recordId: this.strAccountId,
                objectApiName: 'Account', 
                actionName: 'view'
            }
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
}