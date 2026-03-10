import { LightningElement } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';

const DELAY = 1718;

export default class Nac_CaseNewButton extends NavigationMixin(LightningElement) {

    displayButton = false;

    connectedCallback(){
        this.delayTimeout = setTimeout(() => {
            this.displayButton = true;
        }, DELAY);
    }

    handleClick(){
        this[NavigationMixin.Navigate]({
            type: 'comm__namedPage',
            attributes: {
                name: 'Create_Case__c'
            }
        });
    }
}