import { LightningElement, api, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { CloseActionScreenEvent } from 'lightning/actions';
import { NavigationMixin } from 'lightning/navigation';
import updatePricebookOnOpportunity from '@salesforce/apex/OpportunityQuoteCreationController.updatePricebookOnOpportunity';
import getAddresses from '@salesforce/apex/AccountDetailsBillingShippingController.getRelatedAddresses';
import trackUiEvent from '@salesforce/apex/SfRepoAiUiCaptureController.trackUiEvent';

import getAccountDetails from '@salesforce/apex/AccountDetailsBillingShippingController.getAccountInfo';
import OPPORTUNITY_OBJECT from '@salesforce/schema/Opportunity';
import STAGE_FIELD from '@salesforce/schema/Opportunity.StageName';
import { createRecord } from 'lightning/uiRecordApi';

export default class CreateNattOppLwc extends NavigationMixin(LightningElement) {
    @api recordId;
    @api recordTypeId;
    @api recordTypeName;
    @api objectApiName;

    // Flag to determine if the component should be shown
    @track hasAccess = true;

    @track opportunity = {};
    //@track billingAddressId = '';
    //@track shippingAddressId = '';
    @track accountID = '';
    @track isStock = false;
    @track isShippingRequired = true;

    @track billingAddress;
    @track shippingAddress;
    @track billToAddressOptions = []; // Stores billing address options
    @track unitShipToAddressOptions = []; // Stores shipping address options

    createdRecordId;

    trackUi(eventType, actionName, elementLabel, details = {}) {
        trackUiEvent({
            eventType,
            componentName: 'c:createNattOppLwc',
            actionName,
            elementLabel,
            pageUrl: window.location.href,
            recordId: this.recordId,
            detailsJson: JSON.stringify(details || {})
        }).catch(() => {});
    }

   connectedCallback() {
    this.trackUi('LWC_CONNECTED', 'connectedCallback', 'Create Opportunity page', {
        recordId: this.recordId,
        objectApiName: this.objectApiName
    });
    this.opportunity[STAGE_FIELD.fieldApiName] = 'Prospecting';
    if (this.recordId) {
        getAccountDetails({ accountId: this.recordId })
            .then(account => {
                console.log('response-- '+ JSON.stringify(account));
                const recordType = account.RecordType?.Name;

                if (recordType === 'Dealer') {
                    // Set dealer as Account
                    this.opportunity.AccountId = account.Id;
                    this.accountID = account.Id;

                    // Fetch addresses from Dealer directly
                    this.fetchRelatedAddresses(account.Id);
                } else if (recordType === 'Customer') {
                    // Use the dealer's account as Opportunity.AccountId
                    const dealerId = account.NATT_Dealership__c;

                    this.opportunity.AccountId = dealerId;
                    this.accountID = dealerId;

                    // End customer is the original record
                    this.opportunity.NATT_End_Customer__c = account.Id;

                    // Fetch addresses from the Dealer
                    this.fetchRelatedAddresses(dealerId);
                }
                else{
                     this.fetchRelatedAddresses(this.recordId);
                }
                console.log('response opp-- '+ JSON.stringify(this.opportunity));
            })
            .catch(error => {
                console.error('Error fetching account info:', error);
                this.showToast('Error', 'Failed to load account info', 'error');
            });
        }
    }



    handleInputChange(event) {
        const field = event.target.dataset.field;
        this.opportunity[field] = event.target.value;
        const stockInput = this.template.querySelector('.inputStock');
        const isStock = stockInput ? stockInput.value : null;
        this.isShippingRequired = !isStock;
    }

    handleAccountChange(event) {
        const accountId = event.target.value;
        this.opportunity.AccountId = accountId;
        if (accountId) {
            this.fetchRelatedAddresses(accountId);
        }
    }

     fetchRelatedAddresses(accountId) {
        getAddresses({ accountId })
            .then(addresses => {
                console.log('Apex method returned data:', addresses);
                // Reset address fields
                // CCRN-2872 Filter Criteria for Billing and Ship To Address fields- Added by Rajasekhar
                this.billingAddress = '';
                this.shippingAddress = '';
                console.log('Address Data:', JSON.stringify(addresses));

                this.billToAddressOptions = [
                    { label: 'Select an option', value: '' },
                    ...addresses.filter(item => item.NATT_Type__c === 'Billing')
                        .map(item => ({ label: item.Name, value: item.Id }))
                ];

                this.unitShipToAddressOptions = [
                    { label: 'Select an option', value: '' },
                    ...addresses.filter(item => item.NATT_Type__c === 'Units Ship To')
                        .map(item => ({ label: item.Name, value: item.Id }))
                ];
                if (this.billToAddressOptions.length > 1) {
                    this.billingAddress = this.billToAddressOptions[1].value; // first actual option
                    this.opportunity.NATT_Billing_Address__c = this.billingAddress;
                    console.log('Billing Address ID:', this.billingAddress);
                }

                if (this.unitShipToAddressOptions.length > 1) {
                    this.shippingAddress = this.unitShipToAddressOptions[1].value;
                    this.opportunity.NATT_Shipping_Address__c = this.shippingAddress;
                    console.log('Shipping Address ID:', this.shippingAddress);
                }
            })
            .catch(error => {
                console.error('Error fetching related addresses:', error);
                this.showToast('Error', 'Failed to fetch related addresses', 'error');
            });
    }



    handleSubmit(event) {
        this.trackUi('BUTTON_CLICK', 'Submit', 'Create Opportunity', {
            accountId: this.recordId,
            recordTypeId: this.recordTypeId
        });
        // Prevent default form submission
        event.preventDefault();

        const stockField = this.opportunity.NATT_Stock__c;
        const endCustomerField = this.opportunity.NATT_End_Customer__c;
        const billingAddress = this.opportunity.NATT_Billing_Address__c;
        const shippingAddress = this.opportunity.NATT_Shipping_Address__c;

        // Validate required fields
        if (!stockField && !endCustomerField) {
            this.showToast('Error', 'Please provide either Stock or End Customer.', 'error');
            return;
        }
        if (!shippingAddress || !billingAddress) {
            this.showToast('Error', 'Both Shipping Address and Billing Address are required.', 'error');
            return;
        }

        const fields = {
            Name: this.opportunity.Name,
            OwnerId: this.opportunity.OwnerId,
            AccountId: this.recordId,
            StageName: this.opportunity.StageName,
            CloseDate: this.opportunity.CloseDate,
            Product__c: this.opportunity.Product__c,
            RecordTypeId: this.recordTypeId,
            NATT_Stock__c: this.opportunity.NATT_Stock__c,
            Total_Quantity__c: this.opportunity.Total_Quantity__c,
            Expected_Revenue__c: this.opportunity.Expected_Revenue__c,
            NATT_End_Customer__c: this.opportunity.NATT_End_Customer__c,
            NATT_Billing_Address__c: this.opportunity.NATT_Billing_Address__c,
            NATT_Shipping_Address__c: this.opportunity.NATT_Shipping_Address__c

        };

        const recordInput = {
            apiName: 'Opportunity',
            fields: fields
        };
console.log('before Save--'+ JSON.stringify(recordInput));
        createRecord(recordInput)
            .then((record) => {
                this.createdRecordId = record.id;
                console.log('Opportunity created with Id: ', record.id);
                this.handleSuccess();
            })
            .catch((error) => {
                console.error('Error creating opportunity: ', error);

                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Error',
                        message: error.body.message,
                        variant: 'error'
                    })
                );
            });

    }

    handleSuccess() {
        this.trackUi('UI_STATE_CHANGE', 'Create Success', 'Opportunity created', {
            createdRecordId: this.createdRecordId
        });

        updatePricebookOnOpportunity({ oppId: this.createdRecordId, recordTypeId: this.recordTypeId })
            .then(result => {
                console.log('Pricebook update result: ' + result);
                // Close the quick action modal before navigating
                this.dispatchEvent(new CloseActionScreenEvent());
                this.navigateToRecordPage();
                console.log('this.objectApiName-' + this.objectApiName);
                this.showToast(
                    'Success',
                    this.objectApiName === 'SBQQ__Quote__c'
                        ? 'Quote created successfully'
                        : `${this.objectApiName} created successfully`,
                    'success'
                );
            })
            .catch(error => {
                // If the error indicates no access to the Apex class, show error and close component
                if (
                    error &&
                    error.body &&
                    error.body.message &&
                    error.body.message.includes("You do not have access to the Apex class named")
                ) {
                    this.showToast('Error', error.body.message, 'error');
                    this.closeComponent();
                } else {
                    this.showToast('Error', 'Error creating Quote: ' + error.body.message, 'error');
                }
            });
    }

    navigateToRecordPage() {
        this.trackUi('NAVIGATE', 'Navigate To Record', 'Opportunity record page', {
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

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({
            title,
            message,
            variant
        }));
    }

    closeComponent() {
        // Hide the component UI by updating the flag.
        this.hasAccess = false;
        // Optionally, dispatch an event to inform the parent component.
        this.dispatchEvent(new CustomEvent('close'));
    }
}
