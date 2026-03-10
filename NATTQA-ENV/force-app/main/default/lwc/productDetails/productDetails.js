import { LightningElement, wire, api, track } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import communityId from '@salesforce/community/Id';
import getProduct from '@salesforce/apex/NAC_B2BGetInfoController.getProduct';
import getCustomerSpecificPriceBookEntryId from '@salesforce/apex/NAC_B2BGetInfoController.getCustomerSpecificPriceBookEntryId';
import getCartSummary from '@salesforce/apex/NAC_B2BGetInfoController.getCartSummary';
import addToCart from '@salesforce/apex/NAC_B2BGetInfoController.addToCart';
import createAndAddToList from '@salesforce/apex/NAC_B2BGetInfoController.createAndAddToList';
import getProductPrice from '@salesforce/apex/NAC_B2BGetInfoController.getProductPrice';
import supersededMessage from '@salesforce/label/c.NAC_ProductDisplay_Superseded_Message';
import directDeliveryLabel from '@salesforce/label/c.NAC_ProductDisplay_Direct_Delivery_Message';
import refrigerantLabel from '@salesforce/label/c.NAC_ProductDisplay_Refrigerant_Message';
import customerSpecificPriceLabel from '@salesforce/label/c.NAC_ProductDisplay_Special_Pricing_Message';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { resolve } from 'c/cmsResourceResolver';

/**
 * A detailed display of a product.
 * This outer component layer handles data retrieval and management, as well as projection for internal display components.
 */
export default class ProductDetails extends NavigationMixin(LightningElement) {

    label = {
        supersededMessage,
        directDeliveryLabel,
        refrigerantLabel,
        customerSpecificPriceLabel
    };

    _resolvedCategoryPath = [];
    recordPageUrl;
    showCategory = false;
    showS2Banner = false;
    isDirectDelivery = false;
    isPriceGroup123 = false;
    notOrderable = false;
    customerSpecificPriceBookEntryId = '';
    @track isCustomerPrice = false;
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
    }

    /**
     * Gets or sets the unique identifier of a product.
     *
     * @type {string}
     */
    @api
    recordId;

    /**
     * Gets or sets the Product Code of a product.
     *
     * @type {string}
     */
    @api
    productcode;

    @api
    directDelivery;




    /**
     * Gets or sets the custom fields to display on the product
     * in a comma-separated list of field names
     *
     * @type {string}
     */
    @api
    customDisplayFields;

    /**
     * The cart summary information
     *
     * @type {ConnectApi.CartSummary}
     * @private
     */
    cartSummary;

    /**
     * The stock status of the product, i.e. whether it is "in stock."
     *
     * @type {Boolean}
     * @private
     */
    // @wire(checkProductIsInStock, {
    //     productId: '$recordId'
    // })
    inStock = true;

    /**
     * The full product information retrieved.
     *
     * @type {ConnectApi.ProductDetail}
     * @private
     */
    @wire(getProduct, {
        communityId: communityId,
        productId: '$recordId',
        effectiveAccountId: '$resolvedEffectiveAccountId'
    })
    product;


    _productPrice;

    /**
     * The price of the product for the user, if any.
     *
     * @type {ConnectApi.ProductPrice}
     * @private
     */

    @wire(getProductPrice, {
        communityId: communityId,
        productId: '$recordId',
        effectiveAccountId: '$resolvedEffectiveAccountId'
    })
    productPrice({ error, data }) {
        if (data) {
            this._productPrice = data;
        }
    }

    /**
     * The connectedCallback() lifecycle hook fires when a component is inserted into the DOM.
     */
    connectedCallback() {
        this.updateCartInformation();
        getCustomerSpecificPriceBookEntryId({ productId: this.recordId })
            .then(result => {
                this.customerSpecificPriceBookEntryId = result;
                this.isCustomerPrice = this._productPrice.unitPrice ? (this._productPrice.pricebookEntryId == this.customerSpecificPriceBookEntryId ? true : false) : false;
            })
            .catch(error => {
                console.log('Error' + JSON.stringify(error));
            });
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
     * Gets whether product information has been retrieved for display.
     *
     * @type {Boolean}
     * @readonly
     * @private
     */
    get hasProduct() {
        return this.product.data !== undefined;
    }

    /**
     * Gets the normalized, displayable product information for use by the display components.
     *
     * @readonly
     */
    get displayableProduct() {
        var imageObject = [];
        this.product.data.mediaGroups.forEach(mediaGroup => {
            if (mediaGroup.developerName == 'productDetailImage') {
                let index = 0
                mediaGroup.mediaItems.forEach(mediaItem => {
                    let classList = mediaItem.sortOrder === 0 ? "slds-carousel__indicator-action slds-is-active" : "slds-carousel__indicator-action";
                    imageObject.push({
                        url: resolve(mediaItem.url),
                        title: mediaItem.url,
                        index: index,
                        classList: classList
                    });
                    index++
                });

            }
        });
        this[NavigationMixin.GenerateUrl]({
            type: 'standard__recordPage',
            attributes: {
                actionName: 'view',
                recordId: this.product.data.id
            }
        }).then((url) => {
            this.recordPageUrl = url;
        });
        this.isDirectDelivery = this.product.data.fields.NATT_DirectDelivery__c == "true" ? true : false;
        this.isPriceGroup123 = this.product.data.fields.NATT_ItemPriceGroup__c == "123" ? true : false;

        return {
            categoryPath: this.product.data.primaryProductCategoryPath.path.map(
                (category) => ({
                    id: category.id,
                    name: category.name
                })
            ),
            description: this.product.data.fields.Description,
            directDelivery: this.isDirectDelivery,
            image: imageObject /* {
                alternativeText: this.product.data.defaultImage.alternativeText,
                url: resolve(this.product.data.defaultImage.url)
            } */,
            inStock: this.inStock.data === true,
            name: this.product.data.fields.Name,
            productcode: this.product.data.fields.ProductCode,
            price: {
                currency: (this._productPrice || {}).currencyIsoCode,
                negotiated: (this._productPrice || {}).unitPrice,
                strikeThroughPrice: (this._productPrice || {}).listPrice,
            },
            sku: this.product.data.fields.StockKeepingUnit,
            id: this.product.data.id,
            quantityunitofmeasure: this.product.data.fields.QuantityUnitOfMeasure,
            coreProduct: this.product.data.fields.NATT_Core__c,
            fields: Object.entries(
                this.product.data.fields || Object.create(null)
            ).map(([key, value]) => ({ name: key, value })),
            customFields: Object.entries(
                this.product.data.fields || Object.create(null)
            ).filter(([key]) =>
                (this.customDisplayFields || '').includes(key)
            ).map(([key, value]) => ({ name: key, value }))
        };
    }



    /**
     * Gets whether the cart is currently locked
     *
     * Returns true if the cart status is set to either processing or checkout (the two locked states)
     *
     * @readonly
     */
    get _isCartLocked() {
        const cartStatus = (this.cartSummary || {}).status;
        return cartStatus === 'Processing' || cartStatus === 'Checkout';
    }

    /**
     * Handles a user request to add the product to their active cart.
     * On success, a success toast is shown to let the user know the product was added to their cart
     * If there is an error, an error toast is shown with a message explaining that the product could not be added to the cart
     *
     * Toast documentation: https://developer.salesforce.com/docs/component-library/documentation/en/lwc/lwc.use_toast
     *
     * @private
     */
    addToCart(event) {
        addToCart({
            communityId: communityId,
            productId: this.recordId,
            quantity: event.detail.quantity,
            effectiveAccountId: this.resolvedEffectiveAccountId
        })
            .then(() => {
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
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Error',
                        message:
                            '{0} could not be added to your cart at this time. Please try again later.',
                        messageData: [this.displayableProduct.name],
                        variant: 'error',
                        mode: 'dismissable'
                    })
                );
            });
    }

    /**
     * Handles a user request to add the product to a newly created wishlist.
     * On success, a success toast is shown to let the user know the product was added to a new list
     * If there is an error, an error toast is shown with a message explaining that the product could not be added to a new list
     *
     * Toast documentation: https://developer.salesforce.com/docs/component-library/documentation/en/lwc/lwc.use_toast
     *
     * @private
     */
    createAndAddToList() {
        let listname = this.product.data.primaryProductCategoryPath.path[0]
            .name;
        createAndAddToList({
            communityId: communityId,
            productId: this.recordId,
            wishlistName: listname,
            effectiveAccountId: this.resolvedEffectiveAccountId
        })
            .then(() => {
                this.dispatchEvent(new CustomEvent('createandaddtolist'));
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Success',
                        message: '{0} was added to a new list called "{1}"',
                        messageData: [this.displayableProduct.name, listname],
                        variant: 'success',
                        mode: 'dismissable'
                    })
                );
            })
            .catch(() => {
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Error',
                        message:
                            '{0} could not be added to a new list. Please make sure you have fewer than 10 lists or try again later',
                        messageData: [this.displayableProduct.name],
                        variant: 'error',
                        mode: 'dismissable'
                    })
                );
            });
    }

    /**
     * Ensures cart information is up to date
     */
    updateCartInformation() {

        getCartSummary({
            communityId: communityId,
            effectiveAccountId: this.resolvedEffectiveAccountId
        })
            .then((result) => {
                this.cartSummary = result;
            })
            .catch((e) => {
                // Handle cart summary error properly
                // For this sample, we can just log the error
                console.log(e);
            });
    }

    handleResolvedCategoryPath(event) {
        try {
            this._resolvedCategoryPath = event.detail;
            if (this._resolvedCategoryPath && this.recordPageUrl) {
                var updatedName = (this.displayableProduct.name).replace(/&quot;/g, '\"');
                this._resolvedCategoryPath.push({
                    name: updatedName.replaceAll(/&#39;/g, '\''),
                    url: this.recordPageUrl
                });
            }
        } catch (e) {
            console.log(e);
        }
    }

    notorderableinfo(event) {
        this.notOrderable = event.detail;
    }
    handleShowBanner(event) {
        this.showS2Banner = event.detail;
    }
}