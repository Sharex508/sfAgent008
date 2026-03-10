import { LightningElement, api,track } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';

import { resolve } from 'c/cmsResourceResolver';
import { getLabelForOriginalPrice, displayOriginalPrice } from 'c/cartUtils';

const QUANTITY_CHANGED_EVT = 'quantitychanged';
const SINGLE_CART_ITEM_DELETE = 'singlecartitemdelete';

import listPriceLabel from '@salesforce/label/c.nac_ListPriceLabel';
import netPriceLabel from '@salesforce/label/c.nac_NetPriceLabel';
import totalPriceLabel from '@salesforce/label/c.nac_TotalPriceLabel';
import qty from '@salesforce/label/c.nac_qty';
import originalPrice from '@salesforce/label/c.nac_OriginalPrice';
import quantityErrorText from '@salesforce/label/c.nac_0QtyErrorText';


/**
 * A non-exposed component to display cart items.
 *
 * @fires Items#quantitychanged
 * @fires Items#singlecartitemdelete
 */
export default class CartItems extends NavigationMixin(LightningElement) {

    labelstr = {
        listPriceLabel,
        netPriceLabel,
        totalPriceLabel,
        qty,
        originalPrice,
        quantityErrorText
    }

    /**
     * An event fired when the quantity of an item has been changed.
     *
     * Properties:
     *   - Bubbles: true
     *   - Cancelable: false
     *   - Composed: true
     *
     * @event Items#quantitychanged
     * @type {CustomEvent}
     *
     * @property {string} detail.itemId
     *   The unique identifier of an item.
     *
     * @property {number} detail.quantity
     *   The new quantity of the item.
     *
     * @export
     */

    /**
     * An event fired when the user triggers the removal of an item from the cart.
     *
     * Properties:
     *   - Bubbles: true
     *   - Cancelable: false
     *   - Composed: true
     *
     * @event Items#singlecartitemdelete
     * @type {CustomEvent}
     *
     * @property {string} detail.cartItemId
     *   The unique identifier of the item to remove from the cart.
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
     * @property {string} originalPrice
     *   The original price of a cart item.
     *
     * @property {number} quantity
     *   The quantity of the cart item.
     *
     * @property {string} totalPrice
     *   The total sales price of a cart item.
     *
     * @property {string} totalListPrice
     *   The total original (list) price of a cart item.
     *
     * @property {string} unitAdjustedPrice
     *   The cart item price per unit based on tiered adjustments.
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
     *   The image of the cart line item
     *
     */

    /**
     * Image information for a product.
     *
     * @typedef {Object} ThumbnailImage
     *
     * @property {string} alternateText
     *  Alternate text for an image.
     *
     * @property {string} title
     *   The title of the image.
     *
     * @property {string} url
     *   The url of the image.
     */

    /**
     * The ISO 4217 currency code for the cart page
     *
     * @type {string}
     */
    @api
    currencyCode;

    /**
     * Whether or not the cart is in a locked state
     *
     * @type {Boolean}
     */
    @api
    isCartDisabled = false;
     /* put your bool flag in html*/
    /**
     * A list of CartItems
     *
     * @type {CartItem[]}
     */

     /**
     * Modal Varaibles
     **/
      @api showModal;
      @api clickedId;
      @api showLoadingSpinner = false;
      @api availabilityMap;
      @api warehouseSelected;
      showCore;
      coreItemId;
      greyOut;

    @api
    get cartItems() {
        return this._providedItems;
        //this.showLoadingSpinner=false;
        //window.setTimeout(() => { this.showLoadingSpinner = false;}, 2000);
    }
    set cartItems(items) {

        this._providedItems = items;
        const generatedUrls = [];
        this._items = (items || []).map((item) => {
            const newItem = { ...item };
            newItem.productCode = '';
            newItem.productCode = item.cartItem.productDetails.fields.ProductCode;                       
            newItem.directdelivery=item.cartItem.productDetails.fields.NATT_DirectDelivery__c == "true"? true : false; 
            newItem.isPriceGroup123=item.cartItem.productDetails.fields.NATT_ItemPriceGroup__c == "123"? true : false; 
            newItem.isDDANDPG123 = item.cartItem.productDetails.fields.NATT_ItemPriceGroup__c == "123" && item.cartItem.productDetails.fields.NATT_DirectDelivery__c == "true" ? true :false;
            if(newItem.isDDANDPG123){
                newItem.isDDANDPG123Content= "Direct Delivery product from our supplier – you may not see inventory on hand. "+
                "Can only be shipped to a location within the US.";             
                
            }
            if(typeof(item.cartItem.productDetails.fields.NATT_Core__c)){

            }          
            if( item.cartItem.productDetails.fields.NATT_Core__c === 'true'){
                newItem.greyOut=true;
                newItem.liStyling='slds-p-vertical_small slds-m-bottom_x-small yellowColor';
            }
            else{
                newItem.greyOut=false;
                newItem.liStyling='slds-p-vertical_small slds-m-bottom_x-small';
            }
            newItem.productUrl = '';
            newItem.productImageUrl = resolve(
                item.cartItem.productDetails.thumbnailImage.url
            );
            newItem.productImageAlternativeText =
                item.cartItem.productDetails.thumbnailImage.alternateText || '';
            const urlGenerated = this._canResolveUrls
                .then(() =>
                    this[NavigationMixin.GenerateUrl]({
                        type: 'standard__recordPage',
                        attributes: {
                            recordId: newItem.cartItem.productId,
                            objectApiName: 'Product2',
                            actionName: 'view'
                        }
                    })
                )
                .then((url) => {
                    newItem.productUrl = url;
                });
            generatedUrls.push(urlGenerated);
            return newItem;
        });

        // When we've generated all our navigation item URLs, update the list once more.
        Promise.all(generatedUrls).then(() => {
            this._items = Array.from(this._items);
        });
    }

    /**
     * A normalized collection of items suitable for display.
     *
     * @private
     */
    _items = [];

    /**
     * A list of provided cart items
     *
     * @private
     */
    _providedItems;

    /**
     * A Promise-resolver to invoke when the component is a part of the DOM.
     *
     * @type {Function}
     * @private
     */
    _connectedResolver;

    /**
     * A Promise that is resolved when the component is connected to the DOM.
     *
     * @type {Promise}
     * @private
     */
    _canResolveUrls = new Promise((resolved) => {
        this._connectedResolver = resolved;
    });

    /**
     * This lifecycle hook fires when this component is inserted into the DOM.
     */
    connectedCallback() {
        // Once connected, resolve the associated Promise.
        this._connectedResolver();
    }

    /**
     * This lifecycle hook fires when this component is removed from the DOM.
     */
    disconnectedCallback() {
        // We've beeen disconnected, so reset our Promise that reflects this state.
        this.showLoadingSpinner = false;
        this._canResolveUrls = new Promise((resolved) => {
            this._connectedResolver = resolved;
        });
    }

    /**
     * Gets the sequence of cart items for display.
     * This getter allows us to incorporate properties that are dependent upon
     * other component properties, like price displays.
     *
     * @private
     */
    get displayItems() {
        return this._items.map((item) => {
            // Create a copy of the item that we can safely mutate.
            //this.showCore=newItem.isCore;
            const newItem = { ...item };
            // Set whether or not to display negotiated price
            newItem.showNegotiatedPrice =
                this.showNegotiatedPrice &&
                (newItem.cartItem.totalPrice || '').length > 0;
               
            // Set whether or not to display original price
            newItem.showOriginalPrice = displayOriginalPrice(
                this.showNegotiatedPrice,
                this.showOriginalPrice,
                newItem.cartItem.totalPrice,
                newItem.cartItem.totalListPrice
            );
            // get the label for original price to provide to the aria-label attr for screen readers
            newItem.originalPriceLabel = getLabelForOriginalPrice(
                this.currencyCode,
                newItem.cartItem.totalListPrice
            );

            //Check if the product is present in availability map passed from parent
            //If yes then stamp the value
            //newItem.availableCount = 'Available: 0';
            newItem.isCore=item.cartItem.productDetails.fields.NATT_Core__c;
            newItem.directdelivery=item.cartItem.productDetails.fields.NATT_DirectDelivery__c=="true"?true:false;
            if(newItem.isCore == "true"){
                //newItem.availableCount = 'Available: NSI';
               // newItem.availableCount = 'Available: '+ this.availabilityMap[newItem.cartItem.productDetails.productId].NATT_AvailableQuantity__c;
            }
            else if(newItem.directdelivery){
                newItem.availableCount = 'Available: Direct Delivery';
            }
            else{
                if(newItem.cartItem.productDetails.productId && this.availabilityMap[newItem.cartItem.productDetails.productId]){
                    //If the product is NSI in ATL and warehouse is ATL
                    if(this.availabilityMap[newItem.cartItem.productDetails.productId].NATT_ProductItem__r.NATT_SignalCode__c=='NSI' && this.warehouseSelected == 'ATL'){
                        //newItem.availableCount='Available: NSI';
                        newItem.availableCount = 'Available: '+ this.availabilityMap[newItem.cartItem.productDetails.productId].NATT_AvailableQuantity__c;
                    }
                    //If the product is NSI in ANA and warehouse is ANA
                    else if(this.availabilityMap[newItem.cartItem.productDetails.productId].NATT_ProductItem__r.NAOCAP_Signal_Code_ANA__c=='NSI' && this.warehouseSelected == 'ANA'){
                        newItem.availableCount='Available: NSI';
                    }
                    //If the product is NSI in CHI and warehouse is CHI
                    else if(this.availabilityMap[newItem.cartItem.productDetails.productId].NATT_ProductItem__r.NAOCAP_Signal_Code_CHI__c=='NSI' && this.warehouseSelected == 'CHI'){
                        newItem.availableCount = 'Available: ' + this.availabilityMap[newItem.cartItem.productDetails.productId].NATT_ProductItem__r.NAOCAP_Signal_Code_CHI__c;
                    }
                    //If the product is NSI in PAN and warehouse is PAN
                    else if(this.availabilityMap[newItem.cartItem.productDetails.productId].NATT_ProductItem__r.NAOCAP_Signal_Code_PAN__c=='NSI' && this.warehouseSelected == 'PAN'){
                        newItem.availableCount = 'Available: ' + this.availabilityMap[newItem.cartItem.productDetails.productId].NATT_ProductItem__r.NAOCAP_Signal_Code_PAN__c;
                    }             
                    //If the product has quantity available then show the quantity   
                    else if(Number(this.availabilityMap[newItem.cartItem.productDetails.productId].NATT_AvailableQuantity__c) > 0){
                        newItem.availableCount = 'Available: ' + this.availabilityMap[newItem.cartItem.productDetails.productId].NATT_AvailableQuantity__c;
                    }
                    //if the quantity is 0 or less than 0 then show the available date
                    else if(Number(this.availabilityMap[newItem.cartItem.productDetails.productId].NATT_AvailableQuantity__c) <= 0 && this.availabilityMap[newItem.cartItem.productDetails.productId].NATT_AvailabilityDate__c){
                        newItem.availableCount= 'Availability Date: ' + this.availabilityMap[newItem.cartItem.productDetails.productId].NATT_AvailabilityDate__c;
                    }
                }
            }
            return newItem;
        });
    }

    /**
     * Gets the available labels.
     *
     * @type {Object}
     *
     * @readonly
     * @private
     */
    get labels() {
        return {
            quantity: this.labelstr.qty,
            originalPriceCrossedOut: this.labelstr.originalPrice
        };
    }

    /**
     * Handler for the 'click' event fired from 'contents'
     *
     * @param {Object} evt the event object
     */
    handleProductDetailNavigation(evt) {
        evt.preventDefault();
        const productId = evt.target.dataset.productid;
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: {
                recordId: productId,
                actionName: 'view'
            }
        });
    }

    /**
     * Fires an event to delete a single cart item
     * @private
     * @param {ClickEvent} clickEvt A click event.
     * @fires Items#singlecartitemdelete
     */
    /*handleDelte(){
        this.template.querySelector('c-nac-delete-modal').connectedCallback();
    }*/
    //Gavish--> Please remove all the commented code
    /*handlecallDelte(){
        this.template.querySelector('c-nac_-delete-modal').connectedCallback();
    }*/
    quan_tity;
    handleDeleteCartItem(clickEvt) {
        var cartItemId = clickEvt.target.dataset.cartitemid;
        this.quan_tity=clickEvt.target.dataset.qtity;
        this.clickedId = cartItemId;
        this.showModal = true;
    }
    handleDelete(evt) {
        this.showLoadingSpinner = true;
        var bool = this.showLoadingSpinner;
        var qty=this.quan_tity;
        //var quan_tity = evt.detail;
        var cartItemId = this.clickedId;
        this.dispatchEvent(
            new CustomEvent(SINGLE_CART_ITEM_DELETE, {
                bubbles: true,
                composed: true,
                cancelable: false,
                detail: {
                    cartItemId,
                    bool,
                    qty
                }
            })
        );
        this.showModal = false;
        this.showLoadingSpinner = false;
    }
    hideModalBoxxx() {
        this.showModal = false;
    }

    /**
     * Fires an event to update the cart item quantity
     * @private
     * @param {FocusEvent} blurEvent A blur event.
     * @fires Items#quantitychanged
     */
     showAddmore = false;
    @track cartItemId;
    @track quantity;

    handleQuantitySelectorBlur(blurEvent) {
        //Stop the original event since we're replacing it.
        try{
            blurEvent.stopPropagation();
        // Get the item ID off this item so that we can add it to a new event.
        this.cartItemId = blurEvent.target.dataset.itemId;
        // Get the quantity off the control, which exposes it.
        this.quantity = blurEvent.target.value;
        this.showAddmore = true;
        }
        catch(ex){
           console.log('@@'+ex);
        }
    }
    handleAddMore(blurEvent){
        try{
            const qty=this.quantity ;
            const cId=this.cartItemId;
            let searchText = '[data-item-id="' + this.cartItemId + '"]';
            let field = this.template.querySelector(searchText);
            if (field) {
                if (this.quantity == 0) {
                    field.setCustomValidity(this.labelstr.quantityErrorText);
                    field.reportValidity();
                } else {
                    field.setCustomValidity('');
                    field.reportValidity();
                }
            }
             //;this.showAddmore = false
            //--->CXREF-3337
            // Fire a new event with extra data.

            this.dispatchEvent(
                new CustomEvent(QUANTITY_CHANGED_EVT, {
                    bubbles: true,
                    composed: true,
                    cancelable: false,
                    detail: {
                        cId,
                        qty
                    }
                })
            );
            this.showAddmore = false;
            }
            catch(ex){
               console.log('@@'+ex);
               this.showAddmore = false;
            }
    }
    hideModalBox(){
        this.showAddmore = false;
    }

    /**
     * Handles a click event on the input element.
     *
     * @param {ClickEvent} clickEvent
     *  A click event.
     */
    handleQuantitySelectorClick(clickEvent) {
        /*
      Firefox is an oddity in that if the user clicks the "spin" dial on the number
      control, the input control does not gain focus. This means that users clicking the
      up or down arrows won't trigger our change events.

      To keep the user interactions smooth and prevent a notification on every up / down arrow click
      we simply pull the focus explicitly to the input control so that our normal event handling takes care of things properly.
    */
        //this.showLoadingSpinner=true;
        clickEvent.target.focus();
    }
}