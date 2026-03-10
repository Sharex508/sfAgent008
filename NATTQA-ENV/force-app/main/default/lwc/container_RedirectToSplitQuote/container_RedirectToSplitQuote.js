import { LightningElement,api } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';

export default class Container_RedirectToSplitQuote extends NavigationMixin(LightningElement) {

    @api recordId;
    
    //Navigate to new created Split Quote
    connectedCallback() {
        
        window.open('/lightning/r/SBQQ__Quote__c/' + this.recordId + '/view',"_top");
    }
}