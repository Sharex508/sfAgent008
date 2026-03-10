import { LightningElement, api, track, wire } from 'lwc';
import getQuoteDetails from '@salesforce/apex/NATT_OrderedQuoteDetails.getOrderDetails';

export default class NattUnitsQuoteOrderedLatestPrice extends LightningElement {
    @api recordId; // Captures the Quote ID from the record page
    @track orderDetails;
    error;

    @wire(getQuoteDetails, { quoteId: '$recordId' })
    wiredQuote({ error, data }) {
        if (data) {
            console.log('data-' + JSON.stringify(data));
            this.orderDetails = data;
            console.log('this.orderDetails-' + JSON.stringify(this.orderDetails));

            this.error = undefined;
        } else if (error) {
            this.error = error;
            console.log('error-' + JSON.stringify(error));
            this.orderDetails = undefined;
        }
    }

    get getCreatedDate() {
        if (this.orderDetails?.CreatedDate) {
            return this.orderDetails.CreatedDate.split('T')[0]; // Extracts 'YYYY-MM-DD'
        }
        return ''; // Return empty if no date is found
    }
    get showNoOrdersMessage() {
        return !this.orderDetails && !this.error;
    }
    get formattedUnitPrice() {
        const amount = this.orderDetails?.SBQQ__Quote__r?.NATT_Total_Per_Unit_Without_EMCC_New__c;
        if (amount != null) {
            return `USD ${Number(amount).toLocaleString('en-US', { minimumFractionDigits: 2, maximumFractionDigits: 2 })}`;
        }
        return 'USD 0.00'; 
    }
}