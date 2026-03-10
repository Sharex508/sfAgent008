import { LightningElement, api, track } from 'lwc';
import isguest from '@salesforce/user/isGuest';
import communityId from '@salesforce/community/Id';
import yourPriceLabel from '@salesforce/label/c.nac_yourPrice';
import netPriceLabel from '@salesforce/label/c.NAC_Net_Price_Label';
import priceUnavailableLabel from '@salesforce/label/c.nac_PriceUnavailable';
import getCartDetails from '@salesforce/apex/Nac_GetCustomSettingWareHouseData.getCartDetails';
/**
 * An organized display of a single product card.
 *
 * @fires SearchCard#calltoaction
 * @fires SearchCard#showdetail
 */
export default class SearchCard extends LightningElement {

    label = {
        yourPriceLabel,
        netPriceLabel,
        priceUnavailableLabel
    };
    isGuestUser = isguest;
    @api buttonLabel;
    @api selectedWarehouse;
    showSpinner = false;
    /**
     * An event fired when the user clicked on the action button. Here in this
     *  this is an add to cart button.
     *
     * Properties:
     *   - Bubbles: true
     *   - Composed: true
     *   - Cancelable: false
     *
     * @event SearchLayout#calltoaction
     * @type {CustomEvent}
     *
     * @property {String} detail.productId
     *   The unique identifier of the product.
     *
     * @export
     */

    /**
     * An event fired when the user indicates a desire to view the details of a product.
     *
     * Properties:
     *   - Bubbles: true
     *   - Composed: true
     *   - Cancelable: false
     *
     * @event SearchLayout#showdetail
     * @type {CustomEvent}
     *
     * @property {String} detail.productId
     *   The unique identifier of the product.
     *
     * @export
     */

    /**
     * A result set to be displayed in a layout.
     * @typedef {object} Product
     *
     * @property {string} id
     *  The id of the product
     *
     * @property {string} name
     *  Product name
     *
     * @property {Image} image
     *  Product Image Representation
     *
     * @property {object.<string, object>} fields
     *  Map containing field name as the key and it's field value inside an object.
     *
     * @property {Prices} prices
     *  Negotiated and listed price info
     */

    /**
     * A product image.
     * @typedef {object} Image
     *
     * @property {string} url
     *  The URL of an image.
     *
     * @property {string} title
     *  The title of the image.
     *
     * @property {string} alternativeText
     *  The alternative display text of the image.
     */

    /**
     * Prices associated to a product.
     *
     * @typedef {Object} Pricing
     *
     * @property {string} listingPrice
     *  Original price for a product.
     *
     * @property {string} negotiatedPrice
     *  Final price for a product after all discounts and/or entitlements are applied
     *  Format is a raw string without currency symbol
     *
     * @property {string} currencyIsoCode
     *  The ISO 4217 currency code for the product card prices listed
     */

    /**
     * Card layout configuration.
     * @typedef {object} CardConfig
     *
     * @property {Boolean} showImage
     *  Whether or not to show the product image.
     *
     * @property {string} resultsLayout
     *  Products layout. This is the same property available in it's parent
     *  {@see LayoutConfig}
     *
     * @property {Boolean} actionDisabled
     *  Whether or not to disable the action button.
     */

    /**
     * Gets or sets the display data for card.
     *
     * @type {Product}
     */
    @api
    displayData;

    /**
     * Gets or sets the card layout configurations.
     *
     * @type {CardConfig}
     */
    @api
    config;

    /**
     * Gets the product image.
     *
     * @type {Image}
     * @readonly
     * @private
     */
    get image() {
        return this.displayData.image || {};
    }

    /**
     * Gets the product fields.
     *
     * @type {object.<string, object>[]}
     * @readonly
     * @private
     */
    get fields() {
        return (this.displayData.fields || []).map(({ name, value }, id) => ({
            id: id + 1,
            tabIndex: id === 0 ? 0 : -1,
            // making the first field bit larger
            class: id
                //? 'slds-truncate slds-text-heading_small'
                ? this.config.resultsLayout === 'grid' ? 'slds-text-align_center slds-text-body_small slds-line-clamp_x-small' : 'slds-text-body_small'
                : 'slds-truncate slds-text-heading_medium selling-price',
            // making Name and Description shows up without label
            // Note that these fields are showing with apiName. When builder
            // can save custom JSON, there we can save the display name.
            value:
                name === 'Name' || name === 'ProductCode' || name === 'Description'
                    ? value
                    : `${name}: ${value}`
        }));
    }

    /**
     * Whether or not the product image to be shown on card.
     *
     * @type {Boolean}
     * @readonly
     * @private
     */
    get showImage() {
        return !!(this.config || {}).showImage;
    }

    /**
     * Whether or not disable the action button.
     *
     * @type {Boolean}
     * @readonly
     * @private
     */
    get actionDisabled() {
        let disableButton = false;
        if (this.displayData && this.displayData.hasOwnProperty('allfields')) {
            if (this.selectedWarehouse && this.selectedWarehouse == 'ANA') {
                if (this.displayData.allfields.hasOwnProperty('NAOCAP_Not_Orderable_ANA__c') && (this.displayData.allfields.NAOCAP_Not_Orderable_ANA__c == 'true' || (this.displayData.allfields.NAOCAP_Not_Orderable_ANA__c && this.displayData.allfields.NAOCAP_Not_Orderable_ANA__c.hasOwnProperty('value') && this.displayData.allfields.NAOCAP_Not_Orderable_ANA__c.value == 'true'))) {
                    disableButton = true;
                }
            } else if (this.selectedWarehouse && this.selectedWarehouse == 'CHI') {
                if (this.displayData.allfields.hasOwnProperty('NAOCAP_Not_Orderable_CHI__c') && (this.displayData.allfields.NAOCAP_Not_Orderable_CHI__c == 'true' || (this.displayData.allfields.NAOCAP_Not_Orderable_CHI__c && this.displayData.allfields.NAOCAP_Not_Orderable_CHI__c.hasOwnProperty('value') && this.displayData.allfields.NAOCAP_Not_Orderable_CHI__c.value == 'true'))) {
                    disableButton = true;
                }
            } else if (this.selectedWarehouse && this.selectedWarehouse == 'PAN') {
                if (this.displayData.allfields.hasOwnProperty('NAOCAP_Not_Orderable_PAN__c') && (this.displayData.allfields.NAOCAP_Not_Orderable_PAN__c == 'true' || (this.displayData.allfields.NAOCAP_Not_Orderable_PAN__c && this.displayData.allfields.NAOCAP_Not_Orderable_PAN__c.hasOwnProperty('value') && this.displayData.allfields.NAOCAP_Not_Orderable_PAN__c.value == 'true'))) {
                    disableButton = true;
                }
            } else if (this.displayData.allfields.hasOwnProperty('NAOCAP_Not_Orderable__c') && (this.displayData.allfields.NAOCAP_Not_Orderable__c == 'true' || (this.displayData.allfields.NAOCAP_Not_Orderable__c && this.displayData.allfields.NAOCAP_Not_Orderable__c.hasOwnProperty('value') && this.displayData.allfields.NAOCAP_Not_Orderable__c.value == 'true'))) {
                disableButton = true;
            }
        }
        return (!!(this.config || {}).actionDisabled || disableButton);
    }

    /**
     * Gets the product price.
     *
     * @type {string}
     * @readonly
     * @private
     */
    get price() {
        const prices = this.displayData.prices;
        return prices.negotiatedPrice;
    }


    /**
     * Gets the original price for a product, before any discounts or entitlements are applied.
     *
     * @type {string}
     */
    get listingPrice() {
        return this.displayData.prices.listingPrice;
    }

    /**
     * Gets the currency for the price to be displayed.
     *
     * @type {string}
     * @readonly
     * @private
     */
    get currency() {
        return this.displayData.prices.currencyIsoCode;
    }

    /**
     * Gets the container class which decide the innter element styles.
     *
     * @type {string}
     * @readonly
     * @private
     */
    get cardContainerClass() {
        return this.config.resultsLayout === 'grid'
            ? 'card-layout-grid slds-card'
            : 'card-layout-list slds-card';
    }

    /**
     * Emits a notification that the user wants to add the item to their cart.
     *
     * @fires SearchCard#calltoaction
     * @private
     */

    isShowModal = false;
    @api ClickedWarehouse;
    @api effectiveAccountId;

    effectiveAccountId = this.effectiveAccountId;
    get labels() {
        return {
            quantity: 'QTY',
            originalPriceCrossedOut: 'Original price (crossed out):'
        };
    }

    @track selectedProduct;
    /**
     * This method is called as aresult of user trying to add any product to cart
     * here also we are enforcing a warehouse selection to keep track of inventory for each product
     */
    notifyAction() {
        this.isShowModal = false;
        this.showSpinner = true;
        this.selectedProduct = this.displayData.id;
        getCartDetails({ communityId: communityId, effectiveAccountId: this.effectiveAccountId, activeCartOrId: 'active', productId: this.displayData.id })
            .then(result => {
                this.ClickedWarehouse = result;
                this.showSpinner = false;
                //this.selectedWareHouse=result[0].WarehouseStamped;
                if (this.ClickedWarehouse == null) {
                    this.isShowModal = true;
                }
                else {
                    this.dispatchEvent(
                        new CustomEvent('calltoaction', {
                            bubbles: true,
                            composed: true,
                            detail: {
                                productId: this.displayData.id,
                                productName: this.displayData.name,
                                quantity: this.qty,
                                selectedWarehouse: this.selectedWarehouse
                            }
                        })
                    );
                }
            })
            .catch(error => {
                this.showSpinner = false;
                this.error = error;
            });
    }
    /**
     * This method catches the evnet and add the product to cart symaltaneously after selecting a warehouse
     */
    catchSelectionAndaddTocart(event) {
        this.selectedWarehouse = event.detail.selectedWarehouse;
        this.dispatchEvent(
            new CustomEvent('calltoaction', {
                bubbles: true,
                composed: true,
                detail: {
                    productId: this.displayData.id,
                    productName: this.displayData.name,
                    quantity: this.qty,
                    selectedWarehouse: this.selectedWarehouse
                }
            })
        )
    }

    /**
     * Emits a notification that the user indicates a desire to view the details of a product.
     *
     * @fires SearchCard#showdetail
     * @private
     */
    notifyShowDetail(evt) {
        evt.preventDefault();

        this.dispatchEvent(
            new CustomEvent('showdetail', {
                bubbles: true,
                composed: true,
                detail: { productId: this.displayData.id }
            })
        );
    }
    /**
        * to handle quantity change of a product.
        *
        */
    @api qty = 1;

    handleqtychange(evt) {
        this.qty = evt.target.value;
    }
}