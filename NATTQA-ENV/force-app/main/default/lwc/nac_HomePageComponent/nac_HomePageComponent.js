import { LightningElement } from 'lwc';
import isguest from '@salesforce/user/isGuest';

export default class Nac_HomePageComponent extends LightningElement {
    isGuestUser = isguest;
}