import { LightningElement, api } from 'lwc';
import communityId from '@salesforce/community/Id';
import getProducts from '@salesforce/apex/NAC_B2BGetInfoController.getProducts';
import addToCart from '@salesforce/apex/NAC_B2BGetInfoController.addToCart';
import getCartDetails from '@salesforce/apex/Nac_GetCustomSettingWareHouseData.getCartDetails';
import { transformData } from './dataNormalizer';
import { NavigationMixin } from 'lightning/navigation';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

export default class Nac_displayProducts extends NavigationMixin(LightningElement) {

    @api numofTiles;
    @api effectiveAccountId;
    @api showProductImage;
    @api cardContentMapping;
    @api resultsLayout;
    displayData = {};
    cartSummary;
    displayType;
    title;
    showProducts = false;
    buttonLabel = 'Reorder now';
    showSpinner = false;
    selectedWarehouse;

    @api
    get type() {
        return this.displayType;
    }

    set type(value) {
        this.displayType = value;
        if (this.displayType == 'displayRecentlyOrderedProducts') {
            this.title = 'Reorder Products';
        }

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
        getProducts({ communityId: communityId, effectiveAccountId: this.resolvedEffectiveAccountId, displayType: this.displayType, numofTiles: this.numofTiles, categoryId: null })
            .then(result => {
                this.showSpinner = false;
                try {
                    if (result) {
                        this.showProducts = true;
                    }
                    this.displayData = transformData(result, this.cardContentMapping);
                    this.getWarehouseData();
                }
                catch (error) {
                    console.log(JSON.stringify(error.message));
                    this.showProducts = false;
                }
            })
            .catch(error => {
                this.showSpinner = false;
                console.log('Error' + JSON.stringify(error));
                this.showProducts = false;
            });
    }

    getWarehouseData() {
        getCartDetails({ communityId: communityId, effectiveAccountId: this.resolvedEffectiveAccountId, activeCartOrId: 'active' })
            .then(result => {
                this.selectedWarehouse = result;
            })
            .catch(error => {
                this.error = error;
            });
    }

    handleViewAll() {
        if (this.displayType == 'displayRecentlyOrderedProducts') {
            try {
                this[NavigationMixin.Navigate]({
                    type: 'standard__webPage',
                    attributes: {
                        url: '/recently-ordered-product'
                    }
                });
            }
            catch (error) {
                console.log(JSON.stringify(error.message));
            }
        }
    }

    handleAction(event) {
        event.stopPropagation();
        this.showSpinner = true;
        this.selectedWarehouse = event.detail.selectedWarehouse;
        //CXREF-3319--->
        if (this.validateProduct(event.detail.selectedWarehouse, event.detail.productId)) {
            this._isLoading = false;
            this.showSpinner = false;
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Error',
                    message: 'This product is not orderable at this warehouse',
                    variant: 'error',
                    mode: 'dismissable'
                })
            );
        } else if (isNaN(event.detail.quantity) || event.detail.quantity == '' || event.detail.quantity == null) {
            this._isLoading = false;
            this.showSpinner = false;
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
                productId: event.detail.productId,
                quantity: event.detail.quantity,
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
                            messageData: [event.detail.productName],
                            variant: 'error',
                            mode: 'dismissable'
                        })
                    );
                });
        }
        //--->CXREF-3319
    }

    validateProduct(selectedWarehouse, productId) {
        let validProduct = true;
        if (this.displayData && this.displayData.hasOwnProperty('layoutData')) {
            this.displayData.layoutData.forEach(prod => {
                if (prod.id == productId && prod.hasOwnProperty('allfields')) {
                    if (selectedWarehouse == 'ANA') {
                        if (prod.allfields.hasOwnProperty('NAOCAP_Not_Orderable_ANA__c') && prod.allfields.NAOCAP_Not_Orderable_ANA__c == 'true') {
                            validProduct = false;
                        }
                    } else if (selectedWarehouse == 'CHI') {
                        if (prod.allfields.hasOwnProperty('NAOCAP_Not_Orderable_CHI__c') && prod.allfields.NAOCAP_Not_Orderable_CHI__c == 'true') {
                            validProduct = false;
                        }
                    } else if (selectedWarehouse == 'PAN') {
                        if (prod.allfields.hasOwnProperty('NAOCAP_Not_Orderable_PAN__c') && prod.allfields.NAOCAP_Not_Orderable_PAN__c == 'true') {
                            validProduct = false;
                        }
                    } else {
                        if (prod.allfields.hasOwnProperty('NAOCAP_Not_Orderable__c') && prod.allfields.NAOCAP_Not_Orderable__c == 'true') {
                            validProduct = false;
                        }
                    }
                }
            });
        }
        return !validProduct;
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