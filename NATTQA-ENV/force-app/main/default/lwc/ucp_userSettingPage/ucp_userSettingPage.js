import { LightningElement, wire } from 'lwc';
import { getRecord } from 'lightning/uiRecordApi';
import FIRST_NAME_FIELD from '@salesforce/schema/User.FirstName';
import MIDDLE_NAME_FIELD from '@salesforce/schema/User.MiddleName';
import LAST_NAME_FIELD from '@salesforce/schema/User.LastName';
import EMAIL_FIELD from '@salesforce/schema/User.Email';

export default class UserInfo extends LightningElement {
    userId;
    user;
    error;
    email;

    connectedCallback() {
        const path = window.location.pathname;
        const pathParts = path.split('/');
        this.userId = pathParts[pathParts.length - 1];
    }

    @wire(getRecord, { recordId: '$userId', fields: [FIRST_NAME_FIELD, MIDDLE_NAME_FIELD, LAST_NAME_FIELD, EMAIL_FIELD] })
    userRecord({ error, data }) {
        if (data) {
            this.user = data.fields;
            this.email = this.user.Email.value;
            this.error = undefined;
        } else if (error) {
            this.error = 'Error fetching user details';
            this.user = undefined;
        }
    }

    get fullName() {
        const { FirstName, MiddleName, LastName } = this.user || {};
        return `${FirstName?.value || ''} ${MiddleName?.value || ''} ${LastName?.value || ''}`.trim();
    }
    get Email() {
        return this.user.Email;  // Access the Email field directly
    }
    
}