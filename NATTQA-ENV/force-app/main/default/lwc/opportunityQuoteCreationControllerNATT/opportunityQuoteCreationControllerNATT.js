import { LightningElement, api, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getRecordTypes from '@salesforce/apex/OpportunityQuoteCreationController.getRecordTypes';
//import { getRecord } from 'lightning/uiRecordApi';
import USER_ID from '@salesforce/user/Id';
//import PROFILE_NAME from '@salesforce/schema/User.Profile.Name';

export default class OpportunityQuoteCreationControllerNATT extends LightningElement {
    @api recordId;
    @api objectApiName;
    recordTypes =[];
    selectedRecordTypeId = '';
    selectedRecordTypeName = '';
    isLoadingChild = false;
    isLoading = false;
    USER_ID = USER_ID;
    userProfileName;
    //isNattFullAccess = false;

    get objName() {
        return this.objectApiName === 'Account'? 'Opportunity' : this.objectApiName === 'Opportunity' ? 'SBQQ__Quote__c' : 'Not Applicable';
    }
    get titleName() {
        return this.objectApiName === 'Account'? 'Create Opportunity' : 'Create Quote'
    }
    get isOpportunity() {
        return this.objectApiName === 'Account';
    }
    get isQuote() {
        return this.objectApiName === 'Opportunity';
    }
    get isNotQuoteOpp() {
        return (this.objectApiName !== 'Opportunity' && this.objectApiName !== 'Account');
    }   

    
        @wire(getRecordTypes, { objName: '$objName',recordId: '$recordId' })
        allRecordTypes({ error, data }) {
            if (data) {
                // Map the record types to label and value pairs
                this.recordTypes = data.map(recordType => ({ label: recordType.Name, value: recordType.Id }));
        
                // Log the recordTypes to ensure proper mapping
                console.log('recordTypes--', this.recordTypes);
        
                // Find the 'Units' record type
                const recordTypeCondition = this.recordTypes.find(recordType => 
                recordType.label === 'Units' || recordType.label === 'NATT Direct Sales' ||  recordType.label === 'MX Units'
                );
        
                // Set the selected record type ID and name, or handle null values if not found
                this.selectedRecordTypeId = recordTypeCondition ? recordTypeCondition.value : null;
                this.selectedRecordTypeName = recordTypeCondition ? recordTypeCondition.label : null;
        
                // Optionally, log the selected values for debugging
                console.log('selectedRecordTypeId: ', this.selectedRecordTypeId);
                console.log('selectedRecordTypeName: ', this.selectedRecordTypeName);
        
            } else if (error) {
                // Show an error toast and stop loading
              //  this.showToast('Error', error.message, 'error'); // modified
                console.error('Wire error:', JSON.stringify(error, null, 2));

    // Show a toast with more details
    this.showToast('Error', this.reduceErrors(error).join(', '), 'error');
                this.isLoading = false;
            }
        }
        

    showToast(title, message, type) {
        const event = new ShowToastEvent({
            title: title,
            message: message,
            variant: type
        });
        this.dispatchEvent(event);
    }
    handleRecordTypeChange(event){
        this.selectedRecordTypeId = event.detail.value;
        console.log('recordType'+event.detail.value);
        this.selectedRecordTypeName = event.detail.label;
    }
    handleNext(){
        console.log('insideCreate-->'+this.selectedRecordTypeId);
        this.isLoadingChild = true;
    }
}