import { LightningElement, wire, track } from 'lwc';
import { getRecord } from 'lightning/uiRecordApi';
import NAME_FIELD from '@salesforce/schema/Account.Name';
import { CurrentPageReference } from 'lightning/navigation';

export default class Ucp_accountDetail extends LightningElement {
    @track recordId;
    @track accountDetail;
    @track recordName;
    @track error;

    @wire(CurrentPageReference)
    getPageReference(pageRef) {
        if (pageRef && pageRef.state) {
            this.recordId = pageRef.attributes.recordId || null; // Adjust as per your URL structure
        }
    }

    @wire(getRecord, { recordId: '$recordId', fields: [NAME_FIELD] })
    accountRecord({ error, data }) {
        if (data) {
            this.accountDetail = data.fields;
            this.recordName = this.accountDetail.Name.value; // Correct field access
            this.error = undefined;
        } else if (error) {
            console.error('Error:', error); // Debugging
            this.error = 'Error fetching account details';
            this.recordName = null;
        }
    }

    connectedCallback() {
        console.log('Component initialized. Record ID:', this.recordId);
    }
}