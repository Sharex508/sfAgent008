import { LightningElement, track, wire, api } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import findNearbyStore from '@salesforce/apex/NAC_StoreLocatorController.findNearbyStore';
import locNearYouLabel from '@salesforce/label/c.nac_locnearyou';
import cityLabel from '@salesforce/label/c.nac_City';
import streetLabel from '@salesforce/label/c.nac_Street';
import phoneNumberLabel from '@salesforce/label/c.nac_PhoneNumber';
import zipCodeLabel from '@salesforce/label/c.nac_ZipCode';
import countryLabel from '@salesforce/label/c.nac_Country';
import searchRadiusLabel from '@salesforce/label/c.nac_searchRadius';
import locServiceCentreLabel from '@salesforce/label/c.nac_locServiceCentre';
import searchLocatorLabel from '@salesforce/label/c.nac_SearchLocator';
import { NavigationMixin } from 'lightning/navigation';

const DELAY = 700;

export default class Nac_StoreLocator extends NavigationMixin(LightningElement) {

    label = {
        findNearbyStore,
        locNearYouLabel,
        cityLabel,
        streetLabel,
        phoneNumberLabel,
        zipCodeLabel,
        countryLabel,
        searchRadiusLabel,
        locServiceCentreLabel,
        searchLocatorLabel
    };
    @api effectiveAccountId;
    value = '50';
    markersTitle = 'Store Nearby';
    @track searchRadiusOptions = [
        { value: '25', label: '25 Miles' },
        { value: '50', label: '50 Miles' },
        { value: '100', label: '100 Miles' },
        { value: '250', label: '250 Miles' },
        { value: '500', label: '500 Miles' }
    ];
    @track nearByStores;
    @track mapMarkers = [];
    @track searchKey = '';
    showMap = false;
    showSpinner = false;
    activeSections = [];

    get resolvedEffectiveAccountId() {
        const effectiveAcocuntId = this.effectiveAccountId || '';
        let resolved = null;
        if (effectiveAcocuntId.length > 0 && effectiveAcocuntId !== '000000000000000') {
            resolved = effectiveAcocuntId;
        }
        return resolved;
    }

    renderedCallback() {
        if (this.showMap && this.nearByStores) {
            let topDiv = this.template.querySelector('[data-id="topDiv"]');
            topDiv.scrollIntoView({ behavior: "smooth", block: "center", inline: "nearest" });
        }
    }

    @wire(findNearbyStore, { searchKey: '$searchKey', searchRadius: '$value' })
    wiredDistributors({ error, data }) {
        this.nearByStores = undefined;
        this.mapMarkers = [];
        if (data) {
            if(this.searchKey !== ''){
                this.showSpinner = false;
                this.nearByStores = data;
                this.nearByStores.forEach(store => {
                    store.distributorLocWrapList.forEach(marker =>{
                        this.mapMarkers.push(marker);
                    })
                })
                if (this.mapMarkers.length > 0) {
                    this.showMap = true;
                    this.activeSections.push(this.nearByStores[0].label);
                } else {
                    this.showMap = false;
                    this.nearByStores = undefined;
                    this.activeSections = [];
                    this.mapMarkers = [];
                    const evt = new ShowToastEvent({
                        title: 'Error',
                        message: 'Something went wrong. Please try a different search term.',
                        variant: 'error',
                        mode: 'dismissable'
                    });
                    this.dispatchEvent(evt);
                    window.clearTimeout(this.delayTimeout);
                }
            }
           
        } else if (error) {
            this.showSpinner = false;
            console.error(' ERROR FROM NAC_StoreLocatorController findNearbyStore() ERROR NAME :- '
                + error.name + ' ERROR MESSAGE :- ' + error.message);
            const evt = new ShowToastEvent({
                title: 'Error',
                message: 'Something went wrong. Please contact your system admin for more details.',
                variant: 'error',
                mode: 'dismissable'
            });
            this.dispatchEvent(evt);
            this.showMap = false;
            this.nearByStores = undefined;
            this.activeSections = [];
            this.mapMarkers = [];
        }
    }

    handleKeyChange(event) {
        try {
            window.clearTimeout(this.delayTimeout);
            const searchKey = event.target.value;
            this.delayTimeout = setTimeout(() => {
                if (this.searchKey === searchKey) {
                    this.searchKey = '';
                }
                this.searchKey = searchKey;
                if (searchKey === '') {
                    this.showMap = false;
                    this.showSpinner = false;
                } else {
                    this.showSpinner = true;
                }
            }, DELAY);
        } catch (error) {
            console.log(error);
        }

    }

    handleRadiusChange(event) {
        this.value = event.detail.value;
    }

    handleTileClick(event){
        console.log(event.currentTarget.dataset.item);
        if(event.currentTarget.dataset.item){
            this[NavigationMixin.Navigate]({
                type: 'standard__webPage',
                attributes: {
                    url: 'detail/' + event.currentTarget.dataset.item
                }
            });
        }
    }

}