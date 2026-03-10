import { LightningElement } from 'lwc';

export default class Natt_ppgStoreFooter extends LightningElement {
    currentYear = '';
    connectedCallback(){
        this.currentYear = new Date().getFullYear();
    } 
}