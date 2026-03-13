import { LightningElement, api, wire, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { NavigationMixin } from 'lightning/navigation';
import { getRecord, createRecord, updateRecord } from 'lightning/uiRecordApi';
import getRecordTypes from '@salesforce/apex/OpportunityQuoteCreationController.getRecordTypes';
import getScheduledPickDates from '@salesforce/apex/OpportunityQuoteCreationController.getScheduledPickDates'; // Import new Apex method
import getOpportunityProducts from '@salesforce/apex/OpportunityQuoteCreationController.getOpportunityProducts'; // Import new Apex method
import { refreshApex } from '@salesforce/apex';
import addressFromAccount from '@salesforce/apex/OpportunityQuoteCreationController.addressFromAccount';
import trackUiEvent from '@salesforce/apex/SfRepoAiUiCaptureController.trackUiEvent';
//Added by khushmeet
import getUserInfo from '@salesforce/apex/OpportunityQuoteCreationController.getUserInfo';
//End

import OPPORTUNITY_NAME from '@salesforce/schema/Opportunity.Name';
import OPPORTUNITY_ACCOUNT from '@salesforce/schema/Opportunity.AccountId';
import OPPORTUNITY_STOCK from '@salesforce/schema/Opportunity.NATT_Stock__c';
import OPPORTUNITY_END_CUSTOMER from '@salesforce/schema/Opportunity.NATT_End_Customer__c';
import OPPORTUNITY_STAGE from '@salesforce/schema/Opportunity.StageName';

import OPPORTUNITY_SHIPPINGADDRESS from '@salesforce/schema/Opportunity.NATT_Shipping_Address__c';
import OPPORTUNITY_BILLINGADDRESS from '@salesforce/schema/Opportunity.NATT_Billing_Address__c';


import QUOTE_OBJECT from '@salesforce/schema/SBQQ__Quote__c';


export default class CreateNattQuoteLwc extends NavigationMixin(LightningElement) {
    isInternalUser = false;

    @api recordId;
    @api objectApiName;
    createdRecordId;
    isOpportunityLoaded = false;
    @track quote = {};
    @track accountId;
    @track endCustomer;
    @track stock;
    @track oppName;
    @track containerFreight;
    @track purchaseOrder;
    @track markForLocationState;
    @track markForLocationCity;
    @track markForLocationCountry;
    /*Shipping Address Fields*/
    @track shippingAddress;

    @track showPONumber = false;;

    /*Billing  Address Fields*/
    @track billingAddress;
    @track billToAddressOptions = []; // Stores billing address options
    @track unitShipToAddressOptions = []; // Stores shipping address options
    @track filteredBillingAddresses;
    @track filteredShippingAddresses;

    @track predefinedOptions = [
        { label: 'Main Office - NY', value: '0011A00001ABC123' },
        { label: 'Branch - LA', value: '0011A00001XYZ999' },
        { label: 'Warehouse - TX', value: '0011A00001DEF456' }
    ];

    @track isRecordTypeSelection = true;
    @track selectedRecordTypeId;
    @track recordTypeOptions;
    @track showSpinner = true; // Initialize as true if loading data
    selectedRecordTypeName;
    opportunityStage = '';
    hasScheduledPickDate = false;
    hasOpportuntiyProducts = false;
    @track scheduledPickDates = [];
    @track opportunityProducts = [];
    addressMap;
    @track scheduledPickDatesResult;
    @track opportunityProductsResult;
    // Define columns for lightning-datatable
    columns = [
        { label: 'Name', fieldName: 'Name' },
        { label: 'Scheduled Date', fieldName: 'Scheduled_Date__c', type: 'date' }
    ];

    trackUi(eventType, actionName, elementLabel, details = {}) {
        trackUiEvent({
            eventType,
            componentName: 'c:createNattQuoteLwc',
            actionName,
            elementLabel,
            pageUrl: window.location.href,
            recordId: this.recordId,
            detailsJson: JSON.stringify(details || {})
        }).catch(() => {});
    }

    /* 
    Wire Adapter to Fetch Record Types for SBQQ__Quote__c Object
    */
    connectedCallback() {
        this.trackUi('LWC_CONNECTED', 'connectedCallback', 'Create Quote page', {
            recordId: this.recordId,
            objectApiName: this.objectApiName
        });
        console.log('isRecordTypeSelection'+this.isRecordTypeSelection);
        console.log('selectedRecordTypeId'+this.selectedRecordTypeId);
        console.log('objectApiName'+this.objectApiName);
        // Refresh as soon as component is initialized
        // Use setTimeout to ensure wire service has assigned wiredResult
        setTimeout(() => {
            if (this.scheduledPickDatesResult || this.opportunityProductsResult) {
                refreshApex(this.scheduledPickDatesResult);
                refreshApex(this.opportunityProductsResult);
            }
        }, 0);
    }

    @wire(getRecordTypes, { objName: 'SBQQ__Quote__c',recordId: '$recordId' })
    allRecordTypes({ error, data }) {
        if (data) {
            this.recordTypeOptions = data.map(recordType => ({
                label: recordType.Name,
                value: recordType.Id
            }));
            if(this.recordTypeOptions.find(recordType => recordType.label === 'NATT Direct Sales')){
                this.showPONumber = true;
            }
            // Automatically select 'NATT Units Quote' Record Type if available
            const unitRecordType = this.recordTypeOptions.find(recordType => recordType.label === 'NATT Units Quote' || recordType.label === 'NATT Direct Sales' || recordType.label==='CTM Units Quote');
            this.selectedRecordTypeId = unitRecordType ? unitRecordType.value : null;
            this.selectedRecordTypeName = unitRecordType ? unitRecordType.label : null;
        } else if (error) {
            this.showToast('Error', error.body.message || 'Error fetching record types', 'error');
            console.error('Error fetching record types:', JSON.stringify(error, null, 2));
        }
    }

    /* 
    Wire Adapter to Fetch Opportunity Record
    */
    @wire(getRecord, {
        recordId: '$recordId',
        fields: [OPPORTUNITY_NAME, OPPORTUNITY_ACCOUNT, OPPORTUNITY_STOCK, OPPORTUNITY_END_CUSTOMER, OPPORTUNITY_STAGE, OPPORTUNITY_SHIPPINGADDRESS, OPPORTUNITY_BILLINGADDRESS]
    })
    opportunity({ error, data }) {
        if (data) {
            this.oppName = data.fields.Name.value;
            this.accountId = data.fields.AccountId.value;
            this.endCustomer = data.fields.NATT_End_Customer__c.value;
            this.stock = data.fields.NATT_Stock__c.value;
            this.opportunityStage = data.fields.StageName.value;
            this.shippingAddress = data.fields.NATT_Shipping_Address__c.value;
            this.billingAddress = data.fields.NATT_Billing_Address__c.value;
            this.quote['NATT_Shipping_Address__c'] = this.shippingAddress ? this.shippingAddress : '';
            this.quote['NATT_Billing_Address__c'] = this.billingAddress ? this.billingAddress : '';

            this.showSpinner = false;
        } else if (error) {
            this.showToast('Error', 'Error fetching Opportunity data', 'error');
            this.showSpinner = false;
            console.error('Error fetching Opportunity data:', JSON.stringify(error, null, 2));
        }
    }

    /* 
    Wire Adapter to Fetch Related Opportunity_Scheduled_Pick_Date__c Records
    */
    @wire(getScheduledPickDates, { opportunityId: '$recordId' })
    wiredScheduledPickDates(result) {
        this.scheduledPickDatesResult = result; // <- This should be the whole result object

        const { data, error } = result;
        if (data) {
            console.log('Scheduled Pick Dates Data:', JSON.stringify(data, null, 2));
            this.scheduledPickDates = data.map(record => ({
                Id: record.Id,
                Name: record.Name,
                Scheduled_Date__c: record.Scheduled_Date__c
            }));
            this.hasScheduledPickDate = this.scheduledPickDates.length > 0;
        } else if (error) {
            console.error('Error fetching scheduled pick dates:', JSON.stringify(error, null, 2));
            this.showToast('Error', `Error fetching scheduled pick dates: ${error.body.message || 'Unknown error'}`, 'error');
            this.hasScheduledPickDate = false;
        }
    }

    /* 
   Wire Adapter to Fetch Related OpportunityProducts Records
   */
  

@wire(getOpportunityProducts, { opportunityId: '$recordId' })
wiredOpportuntiyProducts(result) {
    this.opportunityProductsResult = result; // <- Save the whole wire result

    const { data, error } = result;
    if (data) {
        console.log('OpportuntiyProducts Data:', JSON.stringify(data, null, 2));
        this.opportunityProducts = data.map(record => ({
            Id: record.Id,
            Name: record.Name,
            // Scheduled_Date__c: record.Scheduled_Date__c
        }));
        this.hasOpportuntiyProducts = this.opportunityProducts.length > 0;
    } else if (error) {
        console.error('Error fetching opportunity products:', JSON.stringify(error, null, 2));
        this.showToast('Error', `Error fetching opportunity products: ${error.body.message || 'Unknown error'}`, 'error');
        this.hasOpportuntiyProducts = false;
    }
}





    @wire(addressFromAccount, { accountId: '$accountId' })
    wiredAddressFromAccount({ error, data }) {
        if (data) {
            console.log('Address Data:', JSON.stringify(data));

            this.addressMap = new Map();
            data.forEach(item => {
                this.addressMap.set(item.Id, item);
            });

            this.billToAddressOptions = [
                { label: 'Select an option', value: '' },
                ...data.filter(item => item.NATT_Type__c === 'Billing')
                    .map(item => ({ label: item.Name, value: item.Id }))
            ];

            this.unitShipToAddressOptions = [
                { label: 'Select an option', value: '' },
                ...data.filter(item => item.NATT_Type__c === 'Units Ship To')
                    .map(item => ({ label: item.Name, value: item.Id }))
            ];
            const isBillingAddressValid = this.billToAddressOptions.some(opt => opt.value === this.billingAddress);
            if (!isBillingAddressValid) {
                this.billingAddress = ''; // Reset if not found
                this.quote['NATT_Billing_Address__c'] = '';
            }

            // Check if existing shippingAddress is in the dropdown options
            const isShippingAddressValid = this.unitShipToAddressOptions.some(opt => opt.value === this.shippingAddress);
            if (!isShippingAddressValid) {
                this.shippingAddress = ''; // Reset if not found
                this.quote['NATT_Shipping_Address__c'] = '';
            }
        } else if (error) {
            console.error('Error fetching address details:', JSON.stringify(error, null, 2));
        }
        console.log('Quote-' + JSON.stringify(this.quote));
    }



    /* 
    Handler for Input Field Changes
    */
    handleInputChange(event) {
        const field = event.target.dataset.field;
        this.quote[field] = event.target.value;
        console.log('Edit Quote-' + JSON.stringify(this.quote));
        if (field === 'NATT_Has_Freight__c') {
            this.containerFreight = event.target.value; // Update containerFreight value
        } else if (field === 'NATT_Purchase_Order__c') {
            this.purchaseOrder = event.target.value; // Update purchaseOrder value
        }
        else if( field === 'Mark_For_Location_State__c'){
            this.markForLocationState = event.target.value; // Update markForLocationState value
        }
        else if( field === 'Mark_For_Location_City__c'){
            this.markForLocationCity = event.target.value; // Update markForLocationCity value
        }
        else if( field === 'Mark_For_Location_Country__c'){
            this.markForLocationCountry = event.target.value; // Update markForLocationCountry value 
        }       
    }

    /* 
    Handler for 'Next' Button Click
    */
    handleNextClick() {
        this.trackUi('BUTTON_CLICK', 'Next', 'Next', {
            selectedRecordTypeId: this.selectedRecordTypeId
        });
        if (this.selectedRecordTypeId) {
            this.showSpinner = true;
            this.isRecordTypeSelection = false;
            this.isOpportunityLoaded = true;
            // Simulate loading delay
            setTimeout(() => {
                this.showSpinner = false;
            }, 4000);
        } else {
            this.showToast('Error', 'Please select a Record Type before proceeding.', 'error');
        }
    }

    /* 
    Handler for 'Back' Button Click
    */
    handleBackClick() {
        this.trackUi('BUTTON_CLICK', 'Back', 'Back');
        if (this.selectedRecordTypeId) {
            this.isOpportunityLoaded = false;
            this.isRecordTypeSelection = true;
        }
    }
    /*check if the logged in user is internal user or not*/
     @wire(getUserInfo , { opportunityId: '$recordId' })
    wiredUserType({ error, data }) {
        if (data) {
            // Check if UserType is 'Standard' (indicating internal user)
            this.isInternalUser = data === 'Standard'; // 'Standard' means internal user
        } else if (error) {
            console.error('Error fetching user type: ', error);
        }
    }
    /* 
    Handler for 'Submit' Button Click
    */
    handleSubmit(event) {
        this.trackUi('BUTTON_CLICK', 'Submit for Approval', 'Submit', {
            selectedRecordTypeId: this.selectedRecordTypeId,
            opportunityStage: this.opportunityStage
        });
        this.showSpinner = true;
        event.preventDefault();

        // Validation: Opportunity Stage must be 'Quoting'
        if (this.opportunityStage !== 'Quoting') {
            this.showToast('Error', 'You cannot create a quote unless the Opportunity stage is "Quoting".', 'error');
            this.showSpinner = false;
            return;
        }

        // Validation: Must have at least one Scheduled Pick Date
        if (!this.hasScheduledPickDate) {
            this.showToast('Error', 'You cannot create a quote without Opportunity requested ship dates.', 'error');
            this.showSpinner = false;
            return;
        }
        // Validation: Must have at least one Scheduled Pick Date
        if (!this.hasOpportuntiyProducts) {
            this.showToast('Error', 'You cannot create a quote without Opportunity Products.', 'error');
            this.showSpinner = false;
            return;
        }

        // Prepare fields for Quote record
        const fields = { ...this.quote };
       
        fields.SBQQ__Account__c = this.accountId;
         fields.SBQQ__Primary__c = true;
        fields.SBQQ__Opportunity2__c = this.recordId;
        fields.NATT_Stock__c = this.stock;
        fields.RecordTypeId = this.selectedRecordTypeId;
        fields.NATT_End_Customer__c = this.endCustomer;
        fields.QUO_Quote_Short_Description__c = this.oppName;
        fields.NATT_Has_Freight__c = this.containerFreight;
        fields.NATT_Purchase_Order__c = this.purchaseOrder;
        fields.Mark_For_Location_City__c = this.markForLocationCity;
        fields.Mark_For_Location_State__c = this.markForLocationState;
        fields.Mark_For_Location_Country__c = this.markForLocationCountry;
        if (this.isInternalUser) {
            fields.NATT_Quote_Record_Type_Developer_Name__c = 'NATT_Direct_Sales';
        }

        const recordInput = { apiName: QUOTE_OBJECT.objectApiName, fields };

        // Create Quote Record
        createRecord(recordInput)
            .then(quote => {
                this.createdRecordId = quote.id;
                this.trackUi('UI_STATE_CHANGE', 'Quote Created', 'Quote created', {
                    createdRecordId: quote.id
                });
                this.showToast('Success', 'Quote created successfully!', 'success');
                // Navigate to the record page after a short delay
                setTimeout(() => {
                    this.navigateToRecordPage();
                    // After navigation, perform a dummy update on the record.
                    // Note: Since navigation may unload this component, the update may not always run.
                    // Use window.setTimeout to delay the update call further.
                    window.setTimeout(() => {
                        const updateFields = { Id: quote.id };
                        const updateRecordInput = { fields: updateFields };
                        updateRecord(updateRecordInput)
                            .then(() => {
                                console.log('Dummy update performed after navigation.');
                            })
                            .catch(error => {
                                this.showToast('Error', `Error updating Quote: ${error.body.message || 'Unknown error'}`, 'error');
                                this.showSpinner = false;
                                console.error('Error updating Quote:', JSON.stringify(error, null, 2));
                            });
                    }, 500); // 500 ms delay for dummy update
                }, 1000);
            })
            .catch(error => {
                this.showToast('Error', `Error creating Quote: ${error.body.message || 'Unknown error'}`, 'error');
                this.showSpinner = false;
                console.error('Error creating Quote:', JSON.stringify(error, null, 2));
            });
    }

    /* 
    Utility Method to Show Toast Messages
    */
    showToast(title, message, variant) {
        const event = new ShowToastEvent({
            title,
            message,
            variant
        });
        this.dispatchEvent(event);
    }

    /* 
    Utility Method to Navigate to a Record Page
    */
    navigateToRecordPage() {
        this.showSpinner = false;
        this.trackUi('NAVIGATE', 'Navigate To Record', 'Quote record page', {
            createdRecordId: this.createdRecordId,
            objectApiName: this.objectApiName
        });
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: {
                recordId: this.createdRecordId,
                objectApiName: this.objectApiName,
                actionName: 'view'
            }
        });
    }

    getFullStreet(address) {
        let fullStreet = '';
        if (address.NATT_Street__c) fullStreet += address.NATT_Street__c;
        if (address.NATT_Street_2__c) fullStreet += ' ' + address.NATT_Street_2__c;
        if (address.NATT_Street_3__c) fullStreet += ' ' + address.NATT_Street_3__c;
        if (address.NATT_Street_4__c) fullStreet += ' ' + address.NATT_Street_4__c;
        return fullStreet.trim();
    }

}
