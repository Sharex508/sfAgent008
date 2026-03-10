import { LightningElement } from 'lwc';
import { NavigationMixin } from "lightning/navigation";
export default class Nac_ContactPointAddressRedeirect extends NavigationMixin(LightningElement) {

    handleNavigate() {
        const config = {
            type: 'standard__webPage',
            attributes: {
                url: '/lightning/o/ContactPointAddress/home'
            }
        };
        this[NavigationMixin.Navigate](config);
      }

      connectedCallback(){
        this.handleNavigate();
      }

}