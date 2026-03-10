import { LightningElement, api, track } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

import communityId from '@salesforce/community/Id';
import productSearch from '@salesforce/apex/NAC_B2BSearchController.productSearch';
import getCartSummary from '@salesforce/apex/NAC_B2BGetInfoController.getCartSummary';
import recentlyOrderdProducts from '@salesforce/apex/NAC_B2BGetInfoController.recentlyOrderdProducts';
import getCartDetails from '@salesforce/apex/Nac_GetCustomSettingWareHouseData.getCartDetails';
import getSortRule from '@salesforce/apex/NAC_B2BGetInfoController.getSortRule';
import addToCart from '@salesforce/apex/NAC_B2BGetInfoController.addToCart';
import { transformData } from './dataNormalizer';
import filterProducts from '@salesforce/label/c.nac_FilterProducts';
import noOrderMsg from '@salesforce/label/c.nac_NoOrderMsg';
import noResultsMsg from '@salesforce/label/c.nac_NoResultsMsg';
import invalidStockingTypeForNLO from '@salesforce/label/c.NAOCAP_NLO_PLP_Stocking_Type';

const homePage = {
    name: 'Home',
    type: 'standard__namedPage',
    attributes: {
        pageName: 'home'
    }
};

/**
 * A search resutls component that shows results of a product search or
 * category browsing.This component handles data retrieval and management, as
 * well as projection for internal display components.
 * When deployed, it is available in the Builder under Custom Components as
 * 'B2B Custom Search Results'
 */
export default class SearchResults extends NavigationMixin(LightningElement) {

    label = {
        filterProducts,
        noOrderMsg,
        noResultsMsg,
        invalidStockingTypeForNLO
    }
    displayType;
    showCategory = false;
    showSearchCategory = false;
    //CXREF-3320--->
    showFilter = false;
    sortOptions = [];
    showSort = false;
    showSortOption = false;
    sortValue;
    showPageSizeOption = true;
    pageSizeValue = 20;
    buttonLabel = 'Add to Cart';
    showLeftPannel = true;
    dataAvailable = true;
    dataAvailableForSearchPage = true;
    showBreadcrumbs = false;
    boolitem = false;
    isShowModal = false;
    selectedWarehouse;
    _resolvedCategoryPath = [];
    _resolveConnected;
    _connected = new Promise((resolve) => {
        this._resolveConnected = resolve;
    });

    @api
    get dispayCategories() {
        return this.showCategory;
    }
    set dispayCategories(value) {
        if (value) {
            this.showCategory = true;
        } else {
            this.showCategory = false;
        }
    }

    @api
    get dispaySearchCategories() {
        return this.showSearchCategory;
    }
    set dispaySearchCategories(value) {
        if (value) {
            this.showSearchCategory = true;
        } else {
            this.showSearchCategory = false;
        }
    }

    @api
    get dispayFilters() {
        return this.showFilter;
    }
    set dispayFilters(value) {
        if (value) {
            this.showFilter = true;
        } else {
            this.showFilter = false;
        }
    }

    @api
    get dispayPageSize() {
        return this.showPageSizeOption;
    }
    set dispayPageSize(value) {
        if (value) {
            this.showPageSizeOption = true;
        } else {
            this.showPageSizeOption = false;
        }
    }

    @api
    get dispaySorting() {
        return this.showSortOption;
    }
    set dispaySorting(value) {
        if (value) {
            this.showSortOption = true;
        } else {
            this.showSortOption = false;
        }
    }

    /**
     * Gets the effective account - if any - of the user viewing the product.
     *
     * @type {string}
     */
    @api
    get effectiveAccountId() {
        return this._effectiveAccountId;
    }

    /**
     * Sets the effective account - if any - of the user viewing the product
     * and fetches updated cart information
     */
    set effectiveAccountId(newId) {
        this._effectiveAccountId = newId;
        this.updateCartInformation();
        this.triggerProductSearch();
    }

    /**
     *  Gets or sets the unique identifier of a category.
     *
     * @type {string}
     */
    @api
    get recordId() {
        return this._recordId;
    }
    set recordId(value) {
        this._recordId = value;
        this._landingRecordId = value;
        this.triggerProductSearch();
    }

    /**
     *  Gets or sets the search term.
     *
     * @type {string}
     */
    @api
    get term() {
        return this._term;
    }
    set term(value) {
        this._term = value;
        if (value) {
            this.triggerProductSearch();
        }
    }

    /**
     *  Gets or sets fields to show on a card.
     *
     * @type {string}
     */
    @api
    get cardContentMapping() {
        return this._cardContentMapping;
    }
    set cardContentMapping(value) {
        this._cardContentMapping = value;
    }

    /**
     *  Gets or sets the layout of this component. Possible values are: grid, list.
     *
     * @type {string}
     */
    @api
    resultsLayout;

    /**
     *  Gets or sets whether the product image to be shown on the cards.
     *
     * @type {string}
     */
    @api
    showProductImage;

    @api
    get type() {
        return this.displayType;
    }
    set type(value) {
        this.displayType = value;
        if (value === 'displayRecentlyOrderedProducts') {
            this.triggerProductSearch();
            this.showLeftPannel = false;
            this.buttonLabel = 'Reorder now';
        }
    }


    disconnectedCallback() {
        this._connected = new Promise((resolve) => {
            this._resolveConnected = resolve;
        });
    }

    triggerProductSearch() {
        let searchQuery;
        let getField = ["ProductCode", "Name", "NATT_SignalCode__c", "NAOCAP_Not_Orderable__c", "NAOCAP_Not_Orderable_ANA__c", "NAOCAP_Not_Orderable_CHI__c", "NAOCAP_Not_Orderable_PAN__c", "NAOCAP_Signal_Code_ANA__c", "NAOCAP_Signal_Code_CHI__c", "NAOCAP_Signal_Code_PAN__c", "NATT_SignalCode__c", "NAOCAP_Stocking_Type_UTC_ANA__c", "NAOCAP_Stocking_Type_UTC_CHI__c", "NAOCAP_Stocking_Type_UTC_PAN__c", "NAC_Stocking_Type_UTC__c"];
        if (this.sortValue) {
            searchQuery = JSON.stringify({
                searchTerm: this.term,
                categoryId: this.recordId,
                refinements: this._refinements,
                sortRuleId: this.sortValue,
                fields: getField,
                page: this._pageNumber - 1,
                includePrices: true
            });
        } else {
            searchQuery = JSON.stringify({
                searchTerm: this.term,
                categoryId: this.recordId,
                refinements: this._refinements,
                pageSize: this.pageSizeValue,
                fields: getField,
                page: this._pageNumber - 1,
                includePrices: true
            });
        }
        this._isLoading = true;
        if (this.displayType === 'displayRecentlyOrderedProducts') {
            recentlyOrderdProducts({
                communityId: communityId,
                effectiveAccountId: this.resolvedEffectiveAccountId,
                categoryId: this.recordId
            })
                .then((result) => {
                    this.displayData = result;
                    this._isLoading = false;
                })
                .catch((error) => {
                    this.error = error;
                    this._isLoading = false;
                    console.log(error);
                });
        } else {
            productSearch({
                communityId: communityId,
                searchQuery: searchQuery,
                effectiveAccountId: this.resolvedEffectiveAccountId,
                categoryId: this.recordId,
            })
                .then((result) => {
                    this.displayData = this.validateProductResult(result.response);
                    this.showBreadcrumbs = false;
                    if (this.recordId && !this.term && result.categoryPath && result.categoryPath.path) {
                        const path = [homePage].concat(
                            result.categoryPath.path.map((level) => ({
                                name: level.name,
                                type: 'standard__recordPage',
                                attributes: {
                                    actionName: 'view',
                                    recordId: level.id
                                }
                            }))
                        );
                        this._connected.then(() => {
                            const levelsResolved = path.map((level) =>
                                this[NavigationMixin.GenerateUrl]({
                                    type: level.type,
                                    attributes: level.attributes
                                }).then((url) => ({
                                    name: level.name,
                                    url: url
                                }))
                            );
                            return Promise.all(levelsResolved);
                        })
                            .then((levels) => {
                                this._resolvedCategoryPath = levels;
                                this.showBreadcrumbs = true;
                            });
                    }
                    this._isLoading = false;
                })
                .catch((error) => {
                    this.error = error;
                    this._isLoading = false;
                    console.log(error);
                });
        }
    }

    validateProductResult(productResult){
        let clonnedProductResult = JSON.parse(JSON.stringify(productResult));
        let signalCodeField = this.selectedWarehouse == 'ANA' ? 'NAOCAP_Signal_Code_ANA__c' : this.selectedWarehouse == 'CHI' ? 'NAOCAP_Signal_Code_CHI__c' : this.selectedWarehouse == 'PAN' ? 'NAOCAP_Signal_Code_PAN__c' : 'NATT_SignalCode__c';
        let invalidStocking = this.label.invalidStockingTypeForNLO.split(',');
        let stockingTypeField = this.selectedWarehouse == 'ANA' ? 'NAOCAP_Stocking_Type_UTC_ANA__c' : this.selectedWarehouse == 'CHI' ? 'NAOCAP_Stocking_Type_UTC_CHI__c' : this.selectedWarehouse == 'PAN' ? 'NAOCAP_Stocking_Type_UTC_PAN__c' : 'NAC_Stocking_Type_UTC__c';
        if(clonnedProductResult.hasOwnProperty('productsPage') && clonnedProductResult.productsPage.hasOwnProperty('products') && clonnedProductResult.productsPage.products.length > 0){
            let validatedProducts = clonnedProductResult.productsPage.products.filter(prod => (!(prod.fields[signalCodeField].value == "NLO" && invalidStocking.includes(prod.fields[stockingTypeField].value))));
            clonnedProductResult.productsPage.products = validatedProducts;
        }
        return clonnedProductResult;
    }

    /**
     * Gets the normalized component configuration that can be passed down to
     *  the inner components.
     *
     * @type {object}
     * @readonly
     * @private
     */
    get config() {
        return {
            layoutConfig: {
                resultsLayout: this.resultsLayout,
                cardConfig: {
                    showImage: this.showProductImage,
                    resultsLayout: this.resultsLayout,
                    actionDisabled: this.isCartLocked
                }
            }
        };
    }

    /**
     * Gets or sets the normalized, displayable results for use by the display components.
     *
     * @private
     */
    get displayData() {
        return this._displayData || {};
    }
    set displayData(data) {
        this._displayData = transformData(data, this._cardContentMapping);
        if (this.displayType === 'displayRecentlyOrderedProducts') {
            if (this._displayData.layoutData.length > 0) {
                this.dataAvailable = true;
            } else {
                this.dataAvailable = false;
            }
        }
        else {
            if (this._displayData.layoutData.length > 0) {
                this.dataAvailableForSearchPage = true;
            }
            else {
                this.dataAvailableForSearchPage = false;
            }
        }
    }

    //CXREF-3320--->
    get sortingData() {
        return this._sortingData || {};
    }
    set sortingData(data) {
        this._sortingData = data;
        if (this._sortingData && Object.keys(this._sortingData).length > 0 && this._sortingData.hasOwnProperty('sortRules')) {
            this.showSort = true;
            this._sortingData.sortRules.forEach(rule => {
                this.sortOptions.push({ label: rule.label, value: rule.sortRuleId });
                if (rule.sortOrder == 1) {
                    this.sortValue = rule.sortRuleId;
                }
            });
        } else {
            this.showSort = false;
            this.sortOptions = [];
        }
    }
    //--->CXREF-3320

    get pageSizeOptions() {
        return [
            { label: '20 Result', value: 20 },
            { label: '50 Result', value: 50 },
            { label: '75 Result', value: 75 },
        ];
    }

    /**
     * Gets whether product search is executing and waiting for result.
     *
     * @type {Boolean}
     * @readonly
     * @private
     */
    get isLoading() {
        return this._isLoading;
    }

    /**
     * Gets whether results has more than 1 page.
     *
     * @type {Boolean}
     * @readonly
     * @private
     */
    get hasMorePages() {
        return this.displayData.total > this.displayData.pageSize;
    }

    /**
     * Gets the current page number.
     *
     * @type {Number}
     * @readonly
     * @private
     */
    get pageNumber() {
        return this._pageNumber;
    }

    /**
     * Gets the header text which shows the search results details.
     *
     * @type {string}
     * @readonly
     * @private
     */
    get headerText() {
        let text = '';
        if (this.displayType === 'displayRecentlyOrderedProducts') {
            text = 'Reorder Products';
        } else {
            const totalItemCount = this.displayData.total;
            const pageSize = this.displayData.pageSize;

            if (totalItemCount > 1) {
                const startIndex = (this._pageNumber - 1) * pageSize + 1;

                const endIndex = Math.min(
                    startIndex + pageSize - 1,
                    totalItemCount
                );

                text = `${startIndex} - ${endIndex} of ${totalItemCount} Items`;
            } else if (totalItemCount === 1) {
                text = '1 Result';
            }
        }


        return text;
    }

    /**
     * Gets the normalized effective account of the user.
     *
     * @type {string}
     * @readonly
     * @private
     */
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

    /**
     * Gets whether the cart is currently locked
     *
     * Returns true if the cart status is set to either processing or checkout (the two locked states)
     *
     * @readonly
     */
    get isCartLocked() {
        const cartStatus = (this._cartSummary || {}).status;
        return cartStatus === 'Processing' || cartStatus === 'Checkout';
    }

    /**
     * The connectedCallback() lifecycle hook fires when a component is inserted into the DOM.
     */
    connectedCallback() {
        this._resolveConnected();
        this.updateCartInformation();
        this.getSortingRule();
        this.getWarehouseData();
    }

    //CXREF-3320--->
    getSortingRule() {
        getSortRule
        getSortRule({
            communityId: communityId
        })
            .then((result) => {
                this.sortingData = result;
            })
            .catch((error) => {
                this.error = error;
                console.log(error);
            });
    }
    //--->CXREF-3320

    getWarehouseData() {
        getCartDetails({ communityId: communityId, effectiveAccountId: this.resolvedEffectiveAccountId, activeCartOrId: 'active' })
            .then(result => {
                this.selectedWarehouse = result;
                if (this.selectedWarehouse == null) {
                    this.isShowModal = true;
                    this.boolitem = true;
                } else {
                    this.isShowModal = false;
                    this.triggerProductSearch();
                }
            })
            .catch(error => {
                this.error = error;
            });
    }

    handlecloseModal() {
        this.isShowModal = false;
    }

    handleSelectedWarehouse(event) {
        this.selectedWarehouse = event.selectedWarehouse;
        this.triggerProductSearch();
    }

    handlePageRefresh() {     
        
        setTimeout(() => {
            this.isShowModal = false;           
            if (this.displayType === 'displayRecentlyOrderedProducts') {
                window.location.reload();
            }else{
                eval("$A.get('e.force:refreshView').fire();");
            }
        }, 300);
    }

    /**
     * Handles a user request to add the product to their active cart.
     *
     * @private
     */
    handleAction(event) {
        event.stopPropagation();
        this._isLoading = true;
        this.selectedWarehouse = event.detail.selectedWarehouse;
        if (this.validateProduct(event.detail.selectedWarehouse, event.detail.productId)) {
            this._isLoading = false;
            eval("$A.get('e.force:refreshView').fire();");
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
                    this._isLoading = false;
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
                    this._isLoading = false;
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
    }

    validateProduct(selectedWarehouse, productId) {
        let validProduct = true;
        if (this._displayData && this._displayData.hasOwnProperty('layoutData')) {
            this._displayData.layoutData.forEach(prod => {
                if (prod.id == productId && prod.hasOwnProperty('allfields')) {
                    if (selectedWarehouse == 'ANA') {
                        if (prod.allfields.hasOwnProperty('NAOCAP_Not_Orderable_ANA__c') && prod.allfields.NAOCAP_Not_Orderable_ANA__c.hasOwnProperty('value') && prod.allfields.NAOCAP_Not_Orderable_ANA__c.value == 'true') {
                            validProduct = false;
                        }
                    } else if (selectedWarehouse == 'CHI') {
                        if (prod.allfields.hasOwnProperty('NAOCAP_Not_Orderable_CHI__c') && prod.allfields.NAOCAP_Not_Orderable_CHI__c.hasOwnProperty('value') && prod.allfields.NAOCAP_Not_Orderable_CHI__c.value == 'true') {
                            validProduct = false;
                        }
                    } else if (selectedWarehouse == 'PAN') {
                        if (prod.allfields.hasOwnProperty('NAOCAP_Not_Orderable_PAN__c') && prod.allfields.NAOCAP_Not_Orderable_PAN__c.hasOwnProperty('value') && prod.allfields.NAOCAP_Not_Orderable_PAN__c.value == 'true') {
                            validProduct = false;
                        }
                    } else {
                        if (prod.allfields.hasOwnProperty('NAOCAP_Not_Orderable__c') && prod.allfields.NAOCAP_Not_Orderable__c.hasOwnProperty('value') && prod.allfields.NAOCAP_Not_Orderable__c.value == 'true') {
                            validProduct = false;
                        }
                    }
                }
            });
        }
        return !validProduct;
    }

    /**
     * Handles a user request to clear all the filters.
     *
     * @private
     */
    handleClearAll(/*evt*/) {
        this._refinements = [];
        this._recordId = this._landingRecordId;
        this._pageNumber = 1;
        this.template.querySelector('c-search-filter').clearAll();
        this.triggerProductSearch();
    }

    /**
     * Handles a user request to navigate to the product detail page.
     *
     * @private
     */
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

    handlePreviousPage(evt) {
        evt.stopPropagation();
        this._pageNumber = this._pageNumber - 1;
        this.triggerProductSearch();
    }

    handleNextPage(evt) {
        evt.stopPropagation();
        this._pageNumber = this._pageNumber + 1;
        this.triggerProductSearch();
    }

    handleFacetValueUpdate(evt) {
        evt.stopPropagation();
        this._refinements = evt.detail.refinements;
        this._pageNumber = 1;
        this.triggerProductSearch();
    }

    handleCategoryUpdate(evt) {
        evt.stopPropagation();

        this._recordId = evt.detail.categoryId;
        this._pageNumber = 1;
        this.triggerProductSearch();
    }

    updateCartInformation() {
        getCartSummary({
            communityId: communityId,
            effectiveAccountId: this.resolvedEffectiveAccountId
        })
            .then((result) => {
                this._cartSummary = result;
            })
            .catch((e) => {
                console.log(e);
            });
    }

    handleSortChange(event) {
        this.sortValue = event.detail.value;
        this.triggerProductSearch();
    }

    handlePageSizeChange(event) {
        this.pageSizeValue = event.detail.value;
        this.triggerProductSearch();
    }

    _displayData;
    _sortingData;
    _isLoading = false;
    _pageNumber = 1;
    _refinements = [];
    _term;
    _recordId;
    _landingRecordId;
    _cardContentMapping;
    _effectiveAccountId;
    _cartSummary;
}