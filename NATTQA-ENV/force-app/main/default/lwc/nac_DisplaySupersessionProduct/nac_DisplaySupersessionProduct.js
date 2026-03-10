import { LightningElement, api } from 'lwc';
import communityId from '@salesforce/community/Id';
import getSupersessionProducts from '@salesforce/apex/NAC_B2BGetInfoController.getSupersessionProducts';
import addToCart from '@salesforce/apex/NAC_B2BGetInfoController.addToCart';
import supersededMessage from '@salesforce/label/c.NAOCAP_No_Superseded_Product';
import { transformData } from './dataNormalizer';
import { NavigationMixin } from 'lightning/navigation';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

export default class Nac_DisplaySupersessionProduct extends NavigationMixin(LightningElement) {

    @api effectiveAccountId;
    @api showProductImage;
    @api cardContentMapping;
    @api resultsLayout;
    displayData = {};
    cartSummary;
    displayType;
    title = 'New Versions/ Models available now';
    isSuperseded = false;
    hasSupersededProducts = false;
    buttonLabel = 'Add to Cart';
    showSpinner = false;
    _recordId;

    label = {
        supersededMessage
    };

    @api
    get recordId() {
        return this._recordId;
    }
    set recordId(value) {
        this._recordId = value;
    }

    get config() {
        return {
            layoutConfig: {
                resultsLayout: this.resultsLayout,
                cardConfig: {
                    showImage: this.showProductImage,
                    resultsLayout: this.resultsLayout,
                    actionDisabled: false
                }
            }
        };
    }

    get resolvedEffectiveAccountId() {
        const effectiveAcocuntId = this.effectiveAccountId || '';
        let resolved = null;

        if (
            effectiveAcocuntId.length > 0 &&
            effectiveAcocuntId !== '000000000000000'
        ) {
            resolved = effectiveAcocuntId;
        }
        return resolved;
    }

    connectedCallback() {
        this.showSpinner = true;
        getSupersessionProducts({ communityId: communityId, effectiveAccountId: this.resolvedEffectiveAccountId, recordId: this._recordId })
            .then(result => {
                this.showSpinner = false;
                this.isSuperseded = result.isSuperseded;
                this.hasSupersededProducts = result.hasSupersededProducts;
                this.displayData = transformData(result.supersededProducts, this.cardContentMapping);

            })
            .catch(error => {
                this.showSpinner = false;
                console.log('Error' + JSON.stringify(error));
                this.isSuperseded = false;
                this.hasSupersededProducts = false;
            });
    }

    handleAction(evt) {
        evt.stopPropagation();
        this.showSpinner = true;
        if (isNaN(evt.detail.quantity) || evt.detail.quantity == '' || evt.detail.quantity == null) {
            this._isLoading = false;
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Error',
                    message: 'Enter a valid quanity!',
                    variant: 'error',
                    mode: 'dismissable'
                })
            );
        } else {
            addToCart({
                communityId: communityId,
                productId: evt.detail.productId,
                quantity: evt.detail.quantity,
                effectiveAccountId: this.resolvedEffectiveAccountId
            })
                .then(() => {
                    this.showSpinner = false;
                    this.dispatchEvent(
                        new CustomEvent('cartchanged', {
                            bubbles: true,
                            composed: true
                        })
                    );
                    this.dispatchEvent(
                        new ShowToastEvent({
                            title: 'Success',
                            message: 'Your cart has been updated.',
                            variant: 'success',
                            mode: 'dismissable'
                        })
                    );
                })
                .catch(() => {
                    this.showSpinner = false;
                    this.dispatchEvent(
                        new ShowToastEvent({
                            title: 'Error',
                            message:
                                '{0} could not be added to your cart at this time. Please try again later.',
                            messageData: [evt.detail.productName],
                            variant: 'error',
                            mode: 'dismissable'
                        })
                    );
                });
        }
    }

    handleShowDetail(evt) {
        evt.stopPropagation();
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: {
                recordId: evt.detail.productId,
                actionName: 'view'
            }
        });
    }

}