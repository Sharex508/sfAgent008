import { api, wire, track, LightningElement } from 'lwc';
import { NavigationMixin, CurrentPageReference } from 'lightning/navigation';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

import communityId from '@salesforce/community/Id';
import getCartItems from '@salesforce/apex/NAC_CartController.getCartItems';
import cartValidate from '@salesforce/apex/NAC_CartController.cartValidate';
import cartValidateDelete from '@salesforce/apex/NAC_CartController.cartValidateDelete';
import updateCartItem from '@salesforce/apex/NAC_CartController.updateCartItem';
import deleteCartItem from '@salesforce/apex/NAC_CartController.deleteCartItem';
import deleteCart from '@salesforce/apex/NAC_CartController.deleteCart';
import createCart from '@salesforce/apex/NAC_CartController.createCart';
import getProductCategory from '@salesforce/apex/NAC_B2BGetInfoController.getProductCategory';
import getCartAvailability from "@salesforce/apex/NAC_InventoryUtility.getCartAvailability";

import pleaseConfirmLabel from '@salesforce/label/c.nac_PleaseConfirmLabel';
import clearCartLabel from '@salesforce/label/c.nac_ClearCartLabel';
import cancelLabel from '@salesforce/label/c.nac_CancelLabel';
import okLabel from '@salesforce/label/c.nac_OkLabel';
import loadingCartItems from '@salesforce/label/c.nac_loadingCartItems';
import clearCartButton from '@salesforce/label/c.nac_clearCartButton';
import sortBy from '@salesforce/label/c.nac_sortBy';
import cartHeader from '@salesforce/label/c.nac_cartHeader';
import emptyCartHeaderLabel from '@salesforce/label/c.nac_emptyCartHeaderLabel';
import emptyCartBodyLabel from '@salesforce/label/c.nac_emptyCartBodyLabel';
import closedCartLabel from '@salesforce/label/c.nac_closedCartLabel';
import CreatedDateDesc from '@salesforce/label/c.nac_CreatedDateDesc';
import CreatedDateAsc from '@salesforce/label/c.nac_CreatedDateAsc';
import NameAsc from '@salesforce/label/c.nac_NameAsc';
import NameDesc from '@salesforce/label/c.nac_NameDesc';
import CheckoutLabel from '@salesforce/label/c.nac_checkout';
import getCartDetails from '@salesforce/apex/Nac_GetCustomSettingWareHouseData.getCartDetails';

import { fireEvent } from 'c/pubsub';
import { isCartClosed } from 'c/cartUtils';

// Event name constants
const CART_CHANGED_EVT = 'cartchanged';
const CART_ITEMS_UPDATED_EVT = 'cartitemsupdated';

// Locked Cart Status
const LOCKED_CART_STATUSES = new Set(['Processing', 'Checkout']);

/**
 * A sample cart contents component.
 * This component shows the contents of a buyer's cart on a cart detail page.
 * When deployed, it is available in the Builder under Custom Components as
 * 'B2B Sample Cart Contents Component'
 *
 * @fires CartContents#cartchanged
 * @fires CartContents#cartitemsupdated
 */

export default class CartContents extends NavigationMixin(LightningElement) {

    currentPageToken = null;
    nextPageToken = null;
    previousPageToken = null;
    hasMorePages = false;
    pageNumber = 1;
    pageSize = 1;
    showSpinner = false;
    showPageSize = false;
    @track pageSizeOptions = [
        { value: 10, selected: false },
        { value: 25, selected: false },
        { value: 50, selected: false },
        { value: 100, selected: true },
    ];

    /**
     * An event fired when the cart changes.
     * This event is a short term resolution to update the cart badge based on updates to the cart.
     *
     * @event CartContents#cartchanged
     *
     * @type {CustomEvent}
     *
     * @export
     */

    /**
     * An event fired when the cart items change.
     * This event is a short term resolution to update any sibling component that may want to update their state based
     * on updates in the cart items.
     *
     * In future, if LMS channels are supported on communities, the LMS should be the preferred solution over pub-sub implementation of this example.
     * For more details, please see: https://developer.salesforce.com/docs/component-library/documentation/en/lwc/lwc.use_message_channel_considerations
     *
     * @event CartContents#cartitemsupdated
     * @type {CustomEvent}
     *
     * @export
     */

    /**
     * A cart line item.
     *
     * @typedef {Object} CartItem
     *
     * @property {ProductDetails} productDetails
     *   Representation of the product details.
     *
     * @property {number} quantity
     *   The quantity of the cart item.
     *
     * @property {string} originalPrice
     *   The original price of a cart item.
     *
     * @property {string} salesPrice
     *   The sales price of a cart item.
     *
     * @property {string} totalPrice
     *   The total sales price of a cart item, without tax (if any).
     *
     * @property {string} totalListPrice
     *   The total original (list) price of a cart item.
     */

    /**
     * Details for a product containing product information
     *
     * @typedef {Object} ProductDetails
     *
     * @property {string} productId
     *   The unique identifier of the item.
     *
     * @property {string} sku
     *  Product SKU number.
     *
     * @property {string} name
     *   The name of the item.
     *
     * @property {ThumbnailImage} thumbnailImage
     *   The quantity of the item.
     */

    /**
     * Image information for a product.
     *
     * @typedef {Object} ThumbnailImage
     *
     * @property {string} alternateText
     *  Alternate text for an image.
     *
     * @property {string} id
     *  The image's id.
     *
     * @property {string} title
     *   The title of the image.
     *
     * @property {string} url
     *   The url of the image.
     */

    /**
     * Representation of a sort option.
     *
     * @typedef {Object} SortOption
     *
     * @property {string} value
     * The value for the sort option.
     *
     * @property {string} label
     * The label for the sort option.
     */

    /**
     * The recordId provided by the cart detail flexipage.
     *
     * @type {string}
     */
    @api
    recordId;

    /**
     * The effectiveAccountId provided by the cart detail flexipage.
     *
     * @type {string}
     */
    @api
    effectiveAccountId;

    /**
     * An object with the current PageReference.
     * This is needed for the pubsub library.
     *
     * @type {PageReference}
     */
    @wire(CurrentPageReference)
    pageRef;

    /**
     * Total number of items in the cart
     * @private
     * @type {Number}
     */
    _cartItemCount = 0;

    /**
     * A list of cartItems.
     *
     * @type {CartItem[]}
     */
    cartItems;

    /**
     * A list of sortoptions useful for displaying sort menu
     *
     * @type {SortOption[]}
     */
    sortOptions = [
        { value: 'CreatedDateDesc', label: this.labels.CreatedDateDesc },
        { value: 'CreatedDateAsc', label: this.labels.CreatedDateAsc },
        { value: 'NameAsc', label: this.labels.NameAsc },
        { value: 'NameDesc', label: this.labels.NameDesc }
    ];

    /**
     * Specifies the page token to be used to view a page of cart information.
     * If the pageParam is null, the first page is returned.
     * @type {null|string}
     */
    pageParam = null;

    /**
     * Sort order for items in a cart.
     * The default sortOrder is 'CreatedDateDesc'
     *    - CreatedDateAsc—Sorts by oldest creation date
     *    - CreatedDateDesc—Sorts by most recent creation date.
     *    - NameAsc—Sorts by name in ascending alphabetical order (A–Z).
     *    - NameDesc—Sorts by name in descending alphabetical order (Z–A).
     * @type {string}
     */
    sortParam = 'CreatedDateDesc';

    /**
     * Is the cart currently disabled.
     * This is useful to prevent any cart operation for certain cases -
     * For example when checkout is in progress.
     * @type {boolean}
     */
    isCartClosed = false;

    /**
     * The ISO 4217 currency code for the cart page
     *
     * @type {string}
     */
    currencyCode;

    @track ClickedWarehouse;

    @track ClickedWarehouseName;

    /**
     * for getting warehouse stamped value
     */

    @track showWarehouseDetails;
    @track showModalOnLoadIfNotSelected;
    /**
     * for hide and show warehouse details 
     */
    /**
     * Gets whether the cart item list is empty.
     *
     * @type {boolean}
     * @readonly
     */
    get isCartEmpty() {
        // If the items are an empty array (not undefined or null), we know we're empty.
        return Array.isArray(this.cartItems) && this.cartItems.length === 0;
    }

    /**
     * The labels used in the template.
     * To support localization, these should be stored as custom labels.
     *
     * To import labels in an LWC use the @salesforce/label scoped module.
     * https://developer.salesforce.com/docs/component-library/documentation/en/lwc/create_labels
     *
     * @type {Object}
     * @private
     * @readonly
     */
    get labels() {
        return {
            loadingCartItems,
            clearCartButton,
            sortBy,
            cartHeader,
            emptyCartHeaderLabel,
            emptyCartBodyLabel,
            closedCartLabel,
            CreatedDateDesc,
            CreatedDateAsc,
            NameAsc,
            NameDesc,
            pleaseConfirmLabel,
            clearCartLabel,
            cancelLabel,
            okLabel,
            CheckoutLabel
        };
    }

    /**
     * Gets the cart header along with the current number of cart items
     *
     * @type {string}
     * @readonly
     * @example
     * 'Cart (3)'
     */
    get cartHeader() {
        return `${this.labels.cartHeader} (${this._cartItemCount})`;
    }

    /**
     * Gets whether the item list state is indeterminate (e.g. in the process of being determined).
     *
     * @returns {boolean}
     * @readonly
     */
    get isCartItemListIndeterminate() {
        return !Array.isArray(this.cartItems);
    }

    /**
     * Gets the normalized effective account of the user.
     *
     * @type {string}
     * @readonly
     * @private
     */
    get resolvedEffectiveAccountId() {
        const effectiveAccountId = this.effectiveAccountId || '';
        let resolved = null;
        if (
            effectiveAccountId.length > 0 &&
            effectiveAccountId !== '000000000000000'
        ) {
            resolved = effectiveAccountId;
        }
        return resolved;
    }

    /**
     * This lifecycle hook fires when this component is inserted into the DOM.
     */

    connectedCallback() {
        // Initialize 'cartItems' list as soon as the component is inserted in the DOM.
        this.getWareHouseDetails();
        this.updateCartItems();

    }
    /**
     * This method is used to check and allow the option to change the ware house from the cart page
     * NOTE :- The changes will reflect eveyrhwere and the inventory will reflect likewise
     */
    getWareHouseDetails() {
        try {
            getCartDetails({ communityId: communityId, effectiveAccountId: this.resolvedEffectiveAccountId, activeCartOrId: 'active' })
                .then(result => {
                    this.ClickedWarehouse = result;
                    //Validate Cart

                    this.checkCartValidity();
                    if (this.ClickedWarehouse != null) {
                        this.showWarehouseDetails = true;

                    }
                    else {
                        this.showWarehouseDetails = false;
                        this.openWarehouseModal = true;
                    }
                })
                .catch(error => {
                    this.error = error;
                });
        } catch (e) {
            console.log(e);
        }

    }

    /**
     * Check the Validity on load of Cart Page/change of Warehouse.
     */
    @track validateMapData = [];
    @track resultMapData;
    checkCartValidity() {
        try {
            cartValidate({
                communityId: communityId,
                effectiveAccountId: this.resolvedEffectiveAccountId,
                activeCartOrId: this.recordId,
                pageParam: this.pageParam,
                sortParam: this.sortParam,
                selectedWarehouse: this.ClickedWarehouse
            })
                .then((result) => {
                    if (result) {
                        if(result.cartItemCount){
                            this._cartItemCount = result.cartItemCount
                            this.pageSize = this.pageSizeOptions.find(element => element.selected).value;
                        }
                        this.resultMapData = result.invalidCartItems;
                        for (let key in result.invalidCartItems) {
                            this.validateMapData.push({ value: result.invalidCartItems[key], key: key });
                        }
                        this.ClickedWarehouseName = this.ClickedWarehouse == 'ANA' ? 'USA - Anaheim' : this.ClickedWarehouse == 'PAN' ? 'Panama' : this.ClickedWarehouse == 'CHI' ? 'Chile' : 'USA - Atlanta';
                        if (this.validateMapData.length > 0) {
                            this.openCartValidateModal = true;
                        }

                    }
                    //get all list of invalid Cart Item product to show on pop -up and delete it on click of Ok
                }

                )
                .catch((error) => {
                    console.log('erorrr--' + JSON.stringify(error));
                    //  const errorMessage = error.body.message;
                    // this.cartItems = undefined;
                    // this.isCartClosed = isCartClosed(errorMessage);
                });
        } catch (e) {
            console.log(JSON.stringify(e));
        }
    }

    removeInvalidCartItems() {
        try {
            this.showLoadingSpinner = true;
            this.openCartValidateModal = false;
            cartValidateDelete({
                communityId: communityId,
                effectiveAccountId: this.resolvedEffectiveAccountId,
                activeCartOrId: this.recordId,
                cartItemToDelete: this.resultMapData

            })
                .then((result) => {
                    this.showLoadingSpinner = false;
                    if (result) {
                        this.dispatchEvent(
                            new CustomEvent('cartchanged', {
                                bubbles: true,
                                composed: true
                            })
                        );

                    } else {
                        this.dispatchEvent(
                            new ShowToastEvent({
                                title: 'Error',
                                message: 'Error Occured while Updating Cart.Please contact system administrator.',
                                variant: 'error',
                                mode: 'dismissable'
                            })
                        );
                    }
                    this.therefreshPage();

                })
                .catch((error) => {
                    console.log(JSON.stringify(error));
                });
        } catch (e) {
            console.log(JSON.stringify(e));
        }
    }

    /**
     * Change WareHouse and subsequently close the modal , the below 2 methods do the same
     **/
    @api openWarehouseModal;

    /**
     * Check validity of the cart items
     **/
    @track openCartValidateModal;

    /**These Methods the 3 methods are just refreshing and closing the modal pop up when our operation
     * from childwarehouse modal is done
     */
    closeModal() {
        this.openWarehouseModal = false;
    }
    handleChangeWarehouse() {
        this.openWarehouseModal = true;
    }
    therefreshPage() {
        setTimeout(() => {
            eval("$A.get('e.force:refreshView').fire();");
        }, 1000);
    }
    /**
     * Get a list of cart items from the server via imperative apex call
     */
    updateCartItems() {
        // Call the 'getCartItems' apex method imperatively        
        window.scrollTo({ top: 0, behavior: 'smooth' });
        this.pageSize = this.pageSizeOptions.find(element => element.selected).value;
        this.showSpinner = true;
        getCartItems({
            communityId: communityId,
            effectiveAccountId: this.resolvedEffectiveAccountId,
            activeCartOrId: this.recordId,
            pageSize : this.pageSizeOptions.find(element => element.selected).value,
            pageParam: this.pageParam,
            sortParam: this.sortParam
        })
            .then((result) => {
                this.showSpinner = false;
                this.cartItems = result.cartItems;
                this.currentPageToken = result.currentPageToken;
                this.nextPageToken = result.nextPageToken;
                this.previousPageToken = result.previousPageToken;
                if (!this.nextPageToken && !this.previousPageToken) {
                    this.hasMorePages = false;
                } else {
                    this.hasMorePages = true;
                }
                let nonCoreItems = [];
                let coreItems = {};
                let processedCoreItems = [];
                let sortedItems = [];
                this.cartItems.forEach(item => {
                    if (item.cartItem.productDetails.fields.NATT_Core__c == "true") {
                        coreItems[item.cartItem.productDetails.fields.ProductCode] = item;
                    } else {
                        nonCoreItems.push(item);
                    }
                });
                if (nonCoreItems.length > 0) {
                    nonCoreItems.forEach(item => {
                        sortedItems.push(item);
                        if (item.cartItem.productDetails.fields.NATT_CoreItem_P_N__c != null && !processedCoreItems.includes(item.cartItem.productDetails.fields.NATT_CoreItem_P_N__c) && coreItems[item.cartItem.productDetails.fields.NATT_CoreItem_P_N__c]) {
                            sortedItems.push(coreItems[item.cartItem.productDetails.fields.NATT_CoreItem_P_N__c]);
                            processedCoreItems.push(item.cartItem.productDetails.fields.NATT_CoreItem_P_N__c);
                        }
                    });
                    this.cartItems = sortedItems;
                }
                //Get the availability for cart items
                this.getAvailability(result.cartItems);
                this.currencyCode = result.cartSummary.currencyIsoCode;
                this.isCartDisabled = LOCKED_CART_STATUSES.has(
                    result.cartSummary.status
                );
            })
            .catch((error) => {
                this.showSpinner = false;
                const errorMessage = error.body.message;
                this.cartItems = undefined;
                this.isCartClosed = isCartClosed(errorMessage);
            });
    }

    availabilityMap = [];
    //Method created to fetch inventory for all the cart items in bulk
    getAvailability(cartItems) {
        let productIds = [];
        cartItems.forEach((ci) => {
            productIds.push(ci.cartItem.productId);
        });
        getCartAvailability({
            productIds: productIds,
            warehouse: this.ClickedWarehouse
        }).then((result) => {
            this.availabilityMap = result;
        });
    }
    /**
     * Handles a "click" event on the sort menu.
     *
     * @param {Event} event the click event
     * @private
     */
    handleChangeSortSelection(event) {
        this.sortParam = event.target.value;
        // After the sort order has changed, we get a refreshed list
        this.pageParam = null;
        this.pageNumber = 1;
        this.updateCartItems();
    }

    /**
     * Helper method to handle updates to cart contents by firing
     *  'cartchanged' - To update the cart badge
     *  'cartitemsupdated' - To notify any listeners for cart item updates (Eg. Cart Totals)
     *
     * As of the Winter 21 release, Lightning Message Service (LMS) is not available in B2B Commerce for Lightning.
     * These samples make use of the [pubsub module](https://github.com/developerforce/pubsub).
     * In the future, when LMS is supported in the B2B Commerce for Lightning, we will update these samples to make use of LMS.
     *
     * @fires CartContents#cartchanged
     * @fires CartContents#cartitemsupdated
     *
     * @private
     */
    handleCartUpdate() {
        // Update Cart Badge
        this.dispatchEvent(
            new CustomEvent(CART_CHANGED_EVT, {
                bubbles: true,
                composed: true
            })
        );
        // Notify any other listeners that the cart items have updated
        fireEvent(this.pageRef, CART_ITEMS_UPDATED_EVT);
    }

    /**
     * Handler for the 'quantitychanged' event fired from cartItems component.
     *
     * @param {Event} evt
     *  A 'quanitychanged' event fire from the Cart Items component
     *
     * @private
     */

    handleQuantityChanged(evt) {
        const cartItemId = evt.detail.cId;
        const quantity = evt.detail.qty;
        //const { cartItemId, quantity } = evt.detail;
        this.showLoadingSpinner = true;
        updateCartItem({
            communityId,
            effectiveAccountId: this.effectiveAccountId,
            activeCartOrId: this.recordId,
            cartItemId,
            cartItem: { quantity }
        })
            .then((cartItem) => {
                this.updateCartItems();
                this.updateCartItemInformation(cartItem);
                this.showLoadingSpinner = false;
            })
            .catch((e) => {
                // Handle quantity update error properly
                // For this sample, we can just log the error
                console.log(e);
                this.showLoadingSpinner = false;
            });
    }

    /**
     * Handler for the 'singlecartitemdelete' event fired from cartItems component.
     *
     * @param {Event} evt
     *  A 'singlecartitemdelete' event fire from the Cart Items component
     *
     * @private
     */
    @api showLoadingSpinner;

    handleCartItemDelete(evt) {
        const { cartItemId } = evt.detail;
        const quantity = evt.detail.qty;
        this.showLoadingSpinner = evt.detail.bool;
        deleteCartItem({
            communityId,
            effectiveAccountId: this.effectiveAccountId,
            activeCartOrId: this.recordId,
            cartItemId,
            cartItem: { quantity }
        })
            .then((listoDelete) => {
                //this.removeCartItem(cartItemId);
                this.removeCartItem(listoDelete);
                this.showLoadingSpinner = false;
            })
            .catch((e) => {
                // Handle cart item delete error properly
                // For this sample, we can just log the error
                console.log(e);
                this.showLoadingSpinner = false;
            });
    }

    navigateAllProducts() {
        getProductCategory({ communityId: communityId })
            .then(result => {
                try {
                    this[NavigationMixin.Navigate]({
                        type: 'standard__webPage',
                        attributes: {
                            url: '/category/Products/' + result.topMostParentCategoryId
                        }
                    });
                }
                catch (error) {
                    console.log(JSON.stringify(error.message));
                }
            })
            .catch(error => {
                console.log('Error' + JSON.stringify(error));
            });
    }

    navigateCheckout() {
        if (this.ClickedWarehouse == null) {
            this.openWarehouseModal = true;
        }
        else {
            try {
                sessionStorage.setItem("recordId", this.recordId);
                sessionStorage.setItem("effectiveAccountId", this.effectiveAccountId);
                this[NavigationMixin.Navigate]({
                    type: 'standard__webPage',
                    attributes: {
                        url: '/check-out?recordId=' + this.recordId
                    }
                });
            }
            catch (error) {
                console.log(JSON.stringify(error.message));
            }
        }
    }
    /**
     * Handler for the 'click' event fired from 'Clear Cart' button
     * We want to delete the current cart, create a new one,
     * and navigate to the newly created cart.
     *
     * @private
     */
    @api showAllDelModal;

    handleClearCartAll() {
        this.showAllDelModal = true;
    }
    handleClearCartButtonClicked() {
        // Step 1: Delete the current cart
        this.showAllDelModal = false;
        deleteCart({
            communityId,
            effectiveAccountId: this.effectiveAccountId,
            activeCartOrId: this.recordId
        })
            .then(() => {
                // Step 2: If the delete operation was successful,
                // set cartItems to undefined and update the cart header
                this.cartItems = undefined;
                this._cartItemCount = 0;
            })
            .then(() => {
                // Step 3: Create a new cart
                return createCart({
                    communityId,
                    effectiveAccountId: this.effectiveAccountId
                });
            })
            .then((result) => {
                // Step 4: If create cart was successful, navigate to the new cart
                this.navigateToCart(result.cartId);
                this.handleCartUpdate();
            })
            .catch((e) => {
                // Handle quantity any errors properly
                // For this sample, we can just log the error
                console.log(e);
            });
    }
    hideModalBox() {
        this.showAllDelModal = false;
    }

    /**
     * Given a cart id, navigate to the record page
     *
     * @private
     * @param{string} cartId - The id of the cart we want to navigate to
     */
    navigateToCart(cartId) {
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: {
                recordId: cartId,
                objectApiName: 'WebCart',
                actionName: 'view'
            }
        });
    }

    /**
     * Given a cartItem id, remove it from the current list of cart items.
     *
     * @private
     * @param{string} cartItemId - The id of the cart we want to navigate to
     */
    removeCartItem(listoDelete) {
        listoDelete.forEach(record => {
            const removedItem = (this.cartItems || []).filter(
                (item) => item.cartItem.cartItemId === record

            );

            const quantityOfRemovedItem = removedItem

                ? record.quantity
                : 0;
            const updatedCartItems = (this.cartItems || []).filter(
                (item) => item.cartItem.cartItemId !== record
            );
            this.cartItems = updatedCartItems;
            this._cartItemCount -= 1;
        });
        if (listoDelete.length <= 1) {
            eval("$A.get('e.force:refreshView').fire();");
        }
        this.handleCartUpdate();
    }

    /**
     * Given a cartItem id, remove it from the current list of cart items.
     *
     * @private
     * @param{CartItem} cartItem - An updated cart item
     */
    updateCartItemInformation(cartItem) {
        // Get the item to update the product quantity correctly.
        let count = 0;

        const updatedCartItems = (this.cartItems || []).map((item) => {
            // Make a copy of the cart item so that we can mutate it
            let updatedItem = { ...item };
            cartItem.forEach(record => {
                if (updatedItem.cartItem.cartItemId === record.cartItemId) {
                    updatedItem.cartItem = record;
                }
            });
            count += Number(updatedItem.cartItem.quantity);
            return updatedItem;
        });


        // Update the cartItems List with the change
        this.cartItems = updatedCartItems;
        // Update the Cart Header with the new count
        //this._cartItemCount = count;
        // Update the cart badge and notify any components interested with this change
        this.handleCartUpdate();
    }

    handlePreviousPage(evt) {
        evt.stopPropagation();
        this.pageNumber = this.pageNumber - 1;
        this.pageParam = this.previousPageToken;
        this.currentPageToken = null;
        this.nextPageToken = null;
        this.previousPageToken = null;
        this.updateCartItems();
    }

    handleNextPage(evt) {
        evt.stopPropagation();
        this.pageNumber = this.pageNumber + 1;
        this.pageParam = this.nextPageToken;
        this.currentPageToken = null;
        this.nextPageToken = null;
        this.previousPageToken = null;
        this.updateCartItems();
    }

    handleChangePageSize(event) {
        this.pageSizeOptions.forEach(option => {
            if (option.value == event.currentTarget.dataset.value) {
                option.selected = true;
            } else {
                option.selected = false;
            }
        });
        this.pageParam = null;
        this.pageNumber = 1;
        this.updateCartItems();
    }
}