import { LightningElement, api } from 'lwc';
import communityId from '@salesforce/community/Id';
import isguest from '@salesforce/user/isGuest';
import { NavigationMixin } from 'lightning/navigation';
import getEffectiveAccountId from '@salesforce/apex/NAC_B2BGetInfoController.getEffectiveAccountId';
import fetchSearchData from '@salesforce/apex/NAC_B2BGetInfoController.fetchSearchData';
import searchPlaceholderlabel from '@salesforce/label/c.nac_searchPlaceholderlabel';
import searchDelay from '@salesforce/label/c.NAOCAP_Search_Delay';

const DELAY = 700;

export default class Nac_LWCSeachComponent extends NavigationMixin(LightningElement) {

    label = {
        searchPlaceholderlabel
    }

    @api placeholder = this.label.searchPlaceholderlabel;
    lstResult = [];
    searchKey = '';
    delayTimeout;
    isGuestUser = isguest;
    selectedRecord = {};
    effectiveAccountId;



    connectedCallback() {
        getEffectiveAccountId({ isGuestUser: this.isGuestUser })
            .then(result => {
                console.log(result);
                try {
                    if (result) {
                        this.effectiveAccountId = result;
                    }
                }
                catch (error) {
                    console.log(JSON.stringify(error.message));
                }
            })
            .catch(error => {
                console.log('Error' + JSON.stringify(error));
            });
    }

    handleKeyChange(event) {
        console.log(event.target.value);
        window.clearTimeout(this.delayTimeout);
        this.lstResult = [];
        this.searchKey = event.target.value;
        let timeOut;
        try {
            timeOut = parseInt(searchDelay);
        } catch (e) {
            timeOut = DELAY;
        }
        if (this.searchKey != '') {
            //If user hits enter then search with that term
            if (event.keyCode === 13) {
                this.handleSearch();
            }
            this.delayTimeout = setTimeout(() => {
                fetchSearchData({ communityId: communityId, effectiveAccountId: this.effectiveAccountId, searchKey: this.searchKey })
                    .then(result => {
                        console.log('$$$$$$');
                        console.log(result);
                        try {
                            if (result) {
                                this.lstResult = JSON.parse(JSON.stringify(result));
                            }
                        }
                        catch (error) {
                            console.log(JSON.stringify(error.message));
                        }
                    })
                    .catch(error => {
                        console.log('Error' + JSON.stringify(error));
                    });
            }, timeOut);
        }
    }

    toggleResult(event) {
        const lookupInputContainer = this.template.querySelector('.lookupInputContainer');
        const clsList = lookupInputContainer.classList;
        const whichEvent = event.target.getAttribute('data-source');
        switch (whichEvent) {
            case 'searchInputField':
                clsList.add('slds-is-open');
                break;
            case 'lookupContainer':
                clsList.remove('slds-is-open');
                break;
        }
    }

    handelSelectedRecord(event) {
        console.log(event.target.dataset.item);
        this.selectedRecord = event.target.dataset.item;
        this.searchKey = this.selectedRecord;
        this.template.querySelector('.lookupInputContainer').classList.remove('slds-is-open');
    }

    handleSearch() {
        if (this.searchKey && this.searchKey != null && this.searchKey != undefined) {
            this[NavigationMixin.Navigate]({
                type: 'standard__webPage',
                attributes: {
                    url: '/global-search/' + encodeURIComponent(this.searchKey)
                }
            });
        }
    }

}