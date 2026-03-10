import { LightningElement } from 'lwc';
/**Custom Label Imports */
import PrivacyNoticeLabel from '@salesforce/label/c.Privacy_Notice';
import TermsOfUseLabel from '@salesforce/label/c.NATT_Terms_of_Use_Link';
import ContactSupportLabel from '@salesforce/label/c.NATT_Contact_Support_Link';

export default class Natt_ctmStoreFooter extends LightningElement {
    label = {
        PrivacyNoticeLabel,
        TermsOfUseLabel,
        ContactSupportLabel
    };
}