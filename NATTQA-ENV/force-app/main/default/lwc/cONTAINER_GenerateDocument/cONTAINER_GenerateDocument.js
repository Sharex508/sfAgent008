import { LightningElement,api } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
// importing Custom Label
import GenerateDocURL from '@salesforce/label/c.CONTAINER_GenerateDocURL';

export default class CONTAINER_GenerateDocument extends NavigationMixin(LightningElement) {

    siteURL;
    @api recordId;
    
    //Navigate to visualforce page
    connectedCallback() {
        
        window.open('/' + this.recordId,"_top");
    }
}