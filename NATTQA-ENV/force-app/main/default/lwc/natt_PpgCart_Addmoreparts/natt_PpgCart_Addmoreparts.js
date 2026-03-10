import { LightningElement, wire } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import URL_LABEL from '@salesforce/label/c.URL_LABEL';


export default class MyButton extends NavigationMixin(LightningElement) {

  navigateToPage() {
    this[NavigationMixin.Navigate]({
      type: 'standard__webPage',
      attributes: {
        url: URL_LABEL
      }
    });
  }
}