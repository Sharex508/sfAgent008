import { LightningElement, api, track } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import isguest from '@salesforce/user/isGuest';
import skuLabel from '@salesforce/label/c.nac_SKU';
import yourPriceLabel from '@salesforce/label/c.nac_yourPrice';
import netPriceLabel from '@salesforce/label/c.NAC_Net_Price_Label';
import priceUnavailableLabel from '@salesforce/label/c.nac_PriceUnavailable';
import qtyLabel from '@salesforce/label/c.nac_qty';
import availableLabel from '@salesforce/label/c.nac_invAvailable';
import quantityUnit from '@salesforce/label/c.nac_QuantityUnit';
import communityId from '@salesforce/community/Id';
import getCartDetails from '@salesforce/apex/Nac_GetCustomSettingWareHouseData.getCartDetails';
import getProductInventory from '@salesforce/apex/NAC_InventoryUtility.getProductAvailability';
import displayMessage from '@salesforce/label/c.nac_Display_Message';

// A fixed entry for the home page.
const homePage = {
    name: 'Home',
    type: 'standard__namedPage',
    attributes: {
        pageName: 'home'
    }
};

/**
 * An organized display of product information.
 *
 * @fires ProductDetailsDisplay#addtocart
 * @fires ProductDetailsDisplay#createandaddtolist
 */
export default class ProductDetailsDisplay extends NavigationMixin(LightningElement) {
    
    label = {
        skuLabel,
        yourPriceLabel,
        netPriceLabel,
        priceUnavailableLabel,
        qtyLabel,
        availableLabel,
        quantityUnit,
        displayMessage
    };
    dispatched = false;
    isGuestUser = isguest;
    @track _price;
    @track isDisabled=false;
    showSpinner= false;
    
    /**
     * An event fired when the user indicates the product should be added to their cart.
     *
     * Properties:
     *   - Bubbles: false
     *   - Composed: false
     *   - Cancelable: false
     *
     * @event ProductDetailsDisplay#addtocart
     * @type {CustomEvent}
     *
     * @property {string} detail.quantity
     *  The number of items to add to cart.
     *
     * @export
     */

    /**
     * An event fired when the user indicates the product should be added to a new wishlist
     *
     * Properties:
     *   - Bubbles: false
     *   - Composed: false
     *   - Cancelable: false
     *
     * @event ProductDetailsDisplay#createandaddtolist
     * @type {CustomEvent}
     *
     * @export
     */

    /**
     * A product image.
     * @typedef {object} Image
     *
     * @property {string} url
     *  The URL of an image.
     *
     * @property {string} alternativeText
     *  The alternative display text of the image.
     */

    /**
     * A product category.
     * @typedef {object} Category
     *
     * @property {string} id
     *  The unique identifier of a category.
     *
     * @property {string} name
     *  The localized display name of a category.
     */

    /**
     * A product price.
     * @typedef {object} Price
     *
     * @property {string} negotiated
     *  The negotiated price of a product.
     *
     * @property {string} currency
     *  The ISO 4217 currency code of the price.
     */

    /**
     * A product field.
     * @typedef {object} CustomField
     *
     * @property {string} name
     *  The name of the custom field.
     *
     * @property {string} value
     *  The value of the custom field.
     */

    /**
     * An iterable Field for display.
     * @typedef {CustomField} IterableField
     *
     * @property {number} id
     *  A unique identifier for the field.
     */

    /**
     * Gets or sets which custom fields should be displayed (if supplied).
     *
     * @type {CustomField[]}
     */
    @api
    customFields;


    /**
     * Gets or sets whether the cart is locked
     *
     * @type {boolean}
     */
    @api
    cartLocked;

    /**
     * Gets or sets the name of the product.
     *
     * @type {string}
     */
    @api
    description;
    //Variable to get the product ID and pass it for warehouse inventory calculation
    @api productId;
    /**
     * Gets or sets the product image.
     *
     * @type {Image}
     */

    @track imageDataSet;
    showImageIndicator = true;
    carouselStyle = "transform:translateX(-0%)";

    @api
    get image() {
        return this.imageDataSet;
    }
    set image(value) {
        this.imageDataSet = value;

        console.log(JSON.stringify(this.imageDataSet));
        if (this.imageDataSet.length > 1) {
            this.showImageIndicator = true;
        } else {
            this.showImageIndicator = false;
        }
    }

    /**
     * Gets or sets whether the product is "in stock."
     *
     * @type {boolean}
     */
    @api
    inStock = false;

    /**
     * Gets or sets the name of the product.
     *
     * @type {string}
     */
    @api
    name;

    /**
     * Gets or sets the price - if known - of the product.
     * If this property is specified as undefined, the price is shown as being unavailable.
     *
     * @type {Price}
     */
    @api
    get price() {
        return this._price;
    }
    set price(value) {
        this._price = value;
         // CXREF- 4641 - Need block on non-priced items
         if(!(this._price != null && this._price.negotiated != null && Number(this._price.negotiated)>0)){
            this.disableProduct = true;
            this.showDisplayMessage =true;
            this.displayMessagelabel = displayMessage;
        }else if(!this.isDisabled){
            this.disableProduct = false;
            this.showDisplayMessage =false;
            this.displayMessagelabel = '';

        }
    }

    /**
     * Gets or sets teh stock keeping unit (or SKU) of the product.
     *
     * @type {string}
     */
    @api
    sku;

    /**
     * Gets or sets productCode of the product.
     *
     * @type {string}
     */
    @api
    productcode;


    @api quantityunitofmeasure;
    @api fields;
    @api coreProduct;
    @api directDelivery;

    _invalidQuantity = false;
    _quantityFieldValue = 1;
    _categoryPath;
    inventoryAvailable;

    // A bit of coordination logic so that we can resolve product URLs after the component is connected to the DOM,
    // which the NavigationMixin implicitly requires to function properly.
    _resolveConnected;
    _connected = new Promise((resolve) => {
        this._resolveConnected = resolve;
    });

    @track clickedWarehouse;
    @track isShowModal;
    @api effectiveAccountId;
    /**
     * Having a warehouse selection check in the beginning only before allow the user to make a add to cart choice
     * this helps us to calculate the inventory and reflect the availability of the item
     */
    @api boolitem;
    @api notOrderable;
    disableProduct = false;
    displayMessagelabel = '';
    showDisplayMessage = false;

    connectedCallback() {
        this._resolveConnected();
        if (this.quantityunitofmeasure == 'Each' || this.quantityunitofmeasure == 'EA') {
            this.quantityunitofmeasure = '1';
        }
        
        getCartDetails({ communityId: communityId, effectiveAccountId: this.effectiveAccountId, activeCartOrId: 'active' })
            .then(result => {
                this.clickedWarehouse = result;
                console.log('Direct Delivery');
                console.log(this.directDelivery);
                if (this.clickedWarehouse == null) {
                    this.isShowModal = true;
                    this.boolitem = true;
                }
                else {
                    this.isShowModal = false;
                    if (this.coreProduct == "true") {
                        //this.inventoryAvailable = 'Available: NSI';
                        this.inventoryAvailable = 'Available: ' + result.NATT_AvailableQuantity__c;
                    }
                    else if(this.directDelivery){                       
                        this.inventoryAvailable = 'Available: Direct Delivery';
                    }
                    else {
                        this.inventoryAvailable = 'Available: 0';
                        //Inventory piece
                        getProductInventory({ productId: this.productId, warehouse: this.clickedWarehouse })
                            .then(result => {
                                try {
                                    if (result.NATT_ProductItem__r.NATT_SignalCode__c == 'NSI' && this.clickedWarehouse == 'ATL') {
                                        //this.inventoryAvailable = 'Available: NSI';
                                        this.inventoryAvailable = 'Available: ' + result.NATT_AvailableQuantity__c;
                                    }
                                    else if (result.NATT_ProductItem__r.NAOCAP_Signal_Code_ANA__c == 'NSI' && this.clickedWarehouse == 'ANA') {
                                        this.inventoryAvailable = 'Available: NSI';
                                    }
                                    else if (result.NATT_ProductItem__r.NAOCAP_Signal_Code_CHI__c == 'NSI' && this.clickedWarehouse == 'CHI') {
                                        this.inventoryAvailable = 'Available: NSI';
                                    }
                                    else if (result.NATT_ProductItem__r.NAOCAP_Signal_Code_PAN__c == 'NSI' && this.clickedWarehouse == 'PAN') {
                                        this.inventoryAvailable = 'Available: NSI';
                                    }
                                    else if (result.NATT_AvailableQuantity__c !== undefined && Number(result.NATT_AvailableQuantity__c) > 0) {
                                        this.inventoryAvailable = 'Available: ' + result.NATT_AvailableQuantity__c;
                                    }
                                    else if (result.NATT_AvailableQuantity__c !== undefined && Number(result.NATT_AvailableQuantity__c) <= 0 && result.NATT_AvailabilityDate__c != null) {
                                        this.inventoryAvailable = 'Availability Date: ' + result.NATT_AvailabilityDate__c;
                                    }
                                } catch (error) {

                                }

                            })
                            .catch(error => {

                            });
                    }
                }
                if (this.fields) {
                    let notOrderableField = this.clickedWarehouse == 'ANA' ? 'NAOCAP_Not_Orderable_ANA__c' : this.clickedWarehouse == 'CHI' ? 'NAOCAP_Not_Orderable_CHI__c' : this.clickedWarehouse == 'PAN' ? 'NAOCAP_Not_Orderable_PAN__c' : 'NAOCAP_Not_Orderable__c';
                    let signalCodeField = this.clickedWarehouse == 'ANA' ? 'NAOCAP_Signal_Code_ANA__c' : this.clickedWarehouse == 'CHI' ? 'NAOCAP_Signal_Code_CHI__c' : this.clickedWarehouse == 'PAN' ? 'NAOCAP_Signal_Code_PAN__c' : 'NATT_SignalCode__c';
                    let isSuperseded = false;
                    let notOrderable = false;
                    let displayMsgChanged = false;
                    this.fields.forEach(field => {
                        if (field.name == signalCodeField && field.value == 'S2') {
                            this.showDisplayMessage = false;
                            isSuperseded = true;
                            this.disableProduct = true ;
                            notOrderable = true;
                            displayMsgChanged = true;
                            this.isDisabled =true;
                        }
                        else if (field.name == 'NATT_Core__c' && field.value == 'true') {
                            this.showDisplayMessage = false;
                            this.disableProduct = true;
                            notOrderable = true;
                            displayMsgChanged = true;
                            this.isDisabled =true;
                        }
                        
                        else if (field.name == notOrderableField && field.value == 'true' && displayMsgChanged == false) {
                            this.showDisplayMessage = displayMsgChanged == false ?( this.directDelivery ? false : true):false;
                            this.disableProduct = true;
                            notOrderable = true;
                            this.displayMessagelabel = displayMessage;
                            this.isDisabled =true;
                            

                        }



                    });
                    this.dispatchEvent(
                        new CustomEvent('notorderableinfo', {
                            detail: notOrderable
                        })
                    );
                    this.dispatchEvent(
                        new CustomEvent('showbanner', {
                            detail: isSuperseded
                        })
                    );
                }

            })
            .catch(error => {
                this.error = error;
            });
           
    }


    /**
     * This below 2 methods is getting called by event cathcing, does the same check as of connected callback 
     * and the other one just closes the modal box
     */
    closeModal() {
        this.isShowModal = false;
        let quantity = this._quantityFieldValue;
        this.dispatchEvent(
            new CustomEvent('addtocart', {
                detail: {
                    quantity
                }
            })
        );
    }

    simplyclose(event) {
        this.isShowModal = false;
        this.clickedWarehouse = event.selectedWarehouse;
        if (this.fields) {
            let notOrderableField = this.clickedWarehouse == 'ANA' ? 'NAOCAP_Not_Orderable_ANA__c' : this.clickedWarehouse == 'CHI' ? 'NAOCAP_Not_Orderable_CHI__c' : this.clickedWarehouse == 'PAN' ? 'NAOCAP_Not_Orderable_PAN__c' : 'NAOCAP_Not_Orderable__c';
            let signalCodeField = this.clickedWarehouse == 'ANA' ? 'NAOCAP_Signal_Code_ANA__c' : this.clickedWarehouse == 'CHI' ? 'NAOCAP_Signal_Code_CHI__c' : this.clickedWarehouse == 'PAN' ? 'NAOCAP_Signal_Code_PAN__c' : 'NATT_SignalCode__c';

            this.fields.forEach(field => {
                if (field.name == notOrderableField && field.value == 'true') {
                    this.disableProduct = true;
                    this.notOrderable = true;
                    this.displayMessagelabel = displayMessage;
                    this.isDisabled =true;
                }

                this.dispatchEvent(
                    new CustomEvent('notorderableinfo', {
                        detail: notOrderable
                    })
                );
                //this.notifynotOrderableAction();

                let isSuperseded = false;
                if (field.name == signalCodeField && field.value == 'S2') {
                    isSuperseded = true;
                }
                this.dispatchEvent(
                    new CustomEvent('showbanner', {
                        detail: isSuperseded
                    })
                );
            });
        }
    }

    closeIfselectedRedirectedWarehouse() {
        this.isShowModal = false;
    }

    therefreshPage() {
        setTimeout(() => {
            eval("$A.get('e.force:refreshView').fire();");
        }, 300);
    }

    disconnectedCallback() {
        this._connected = new Promise((resolve) => {
            this._resolveConnected = resolve;
        });
    }

    /**
     * Gets or sets the ordered hierarchy of categories to which the product belongs, ordered from least to most specific.
     *
     * @type {Category[]}
     */
    @api
    get categoryPath() {
        return this._categoryPath;
    }

    set categoryPath(newPath) {
        this._categoryPath = newPath;
        this.resolveCategoryPath(newPath || []);
    }

    

    
    
    /**
     * Gets whether add to cart button should be displabled
     *
     * Add to cart button should be disabled if quantity is invalid,
     * if the cart is locked, or if the product is not in stock
     */
    get _isAddToCartDisabled() {
        return this._invalidQuantity || this.cartLocked || !this.inStock;
    }

    handleQuantityChange(event) {
        if (event.target.validity.valid && event.target.value) {
            this._invalidQuantity = false;
            this._quantityFieldValue = event.target.value;
        } else {
            this._invalidQuantity = true;
        }
    }

    /**
     * Emits a notification that the user wants to add the item to their cart.
     *
     * @fires ProductDetailsDisplay#addtocart
     * @private
     */


    notifyAddToCart() {
        this.showSpinner= true;
        getCartDetails({ communityId: communityId, effectiveAccountId: this.effectiveAccountId, activeCartOrId: 'active' })
            .then(result => {
                this.showSpinner= false;
                this.clickedWarehouse = result;
                if (this.clickedWarehouse == null) {
                    this.isShowModal = true;
                    this.boolitem = false;
                }
                else {
                    this.isShowModal = false;
                    let quantity = this._quantityFieldValue;
                    this.dispatchEvent(
                        new CustomEvent('addtocart', {
                            detail: {
                                quantity
                            }
                        })
                    );
                }
            })
            .catch(error => {
                this.showSpinner= false;
                this.error = error;
            });
    }

    /**
     * Emits a notification that the user wants to add the item to a new wishlist.
     *
     * @fires ProductDetailsDisplay#createandaddtolist
     * @private
     */
    notifyCreateAndAddToList() {
        this.dispatchEvent(new CustomEvent('createandaddtolist'));
    }

    /**
     * Updates the breadcrumb path for the product, resolving the categories to URLs for use as breadcrumbs.
     *
     * @param {Category[]} newPath
     *  The new category "path" for the product.
     */
    resolveCategoryPath(newPath) {
        const path = [homePage].concat(
            newPath.map((level) => ({
                name: level.name,
                type: 'standard__recordPage',
                attributes: {
                    actionName: 'view',
                    recordId: level.id
                }
            }))
        );

        this._connected
            .then(() => {
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
                if (!this.dispatched) {
                    this.dispatchEvent(
                        new CustomEvent('resolvedcategorypath', {
                            bubbles: true,
                            composed: true,
                            detail: levels
                        })
                    );
                    this.dispatched = true;
                }
            });
    }

    /**
     * Gets the iterable fields.
     *
     * @returns {IterableField[]}
     *  The ordered sequence of fields for display.
     *
     * @private
     */
    get _displayableFields() {
        // Enhance the fields with a synthetic ID for iteration.
        return (this.customFields || []).map((field, index) => ({
            ...field,
            id: index
        }));
    }

    handleCarouselChange(event) {
        console.log(event.target.dataset.item);
        try {
            let tempimageDataSet = JSON.parse(JSON.stringify(this.imageDataSet));
            tempimageDataSet.forEach(mediaItem => {
                if (mediaItem.index == event.target.dataset.item) {
                    mediaItem.classList = "slds-carousel__indicator-action slds-is-active";
                    this.carouselStyle = "transform:translateX(-" + 100 * event.target.dataset.item + "%)";
                } else {
                    mediaItem.classList = "slds-carousel__indicator-action";
                }
            });
            this.imageDataSet = tempimageDataSet;
        } catch (e) {
            console.log(e);
        }
    }
}