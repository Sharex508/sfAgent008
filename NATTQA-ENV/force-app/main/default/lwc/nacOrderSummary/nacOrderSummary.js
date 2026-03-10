import { api, LightningElement } from 'lwc';

import communityId from '@salesforce/community/Id';
import getCartSummary from '@salesforce/apex/NAC_CartController.getCartSummary';

import { getLabelForOriginalPrice, displayOriginalPrice } from 'c/cartUtils';


export default class NacOrderSummary extends LightningElement {

    @api recordId;

    @api effectiveAccountId;

    @api shippingCharges;

    @api orderInformation;

    

    get labels() {
        return {
            cartSummaryHeader: 'Cart Total',
            total: 'Total',
            totalRushFee :'Total Rush Fee'
        };
    }

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

    get prices() {
        
        return {
            originalPrice: this.cartSummary && this.cartSummary.totalListPrice,
            finalPrice: this.cartSummary && this.cartSummary.totalProductAmount,
            rushFee:  this.orderInformation && this.orderInformation.totalRushFee,
            rushPercentage: this.orderInformation && this.orderInformation.rushFee * 100,
            totalPrice: this.orderInformation.totalAmount ,
            canReceiveRushOrderCharge : this.orderInformation.canReceiveRushOrderCharge,
            selectedBranchplant : this.orderInformation && this.orderInformation.selectedBranchPlantWarehouse
        };
    }

    /**
     * The ISO 4217 currency code for the cart page
     *
     * @type {String}
     */
    get currencyCode() {
        return (this.cartSummary && this.cartSummary.currencyIsoCode) || 'USD';
    }

    /**
     * Representation for Cart Summary
     *
     * @type {object}
     * @readonly
     * @private
     */
    cartSummary;

    connectedCallback() {
        // Initialize 'cartsummary' as soon as the component is inserted in the DOM  by
        // calling getCartSummary imperatively.
        
        this.getUpdatedCartSummary();
        
    
    }

    /**
     * Get cart summary from the server via imperative apex call
     */
    getUpdatedCartSummary() {
        getCartSummary({
            communityId: communityId,
            activeCartOrId: this.recordId,
            effectiveAccountId: this.resolvedEffectiveAccountId
        })
            .then((cartSummary) => {
                this.cartSummary = cartSummary;
                this.shippingCharges = 20;
               
                let orderInfo = JSON.parse(JSON.stringify(this.orderInformation));
                orderInfo.totalAmount = this.cartSummary.totalProductAmount;
                orderInfo.totalAmountOriginal = this.cartSummary.totalProductAmount;
                
                this.orderInformation = orderInfo;
                this.notifyAction();
            })
            .catch((e) => {
                // Handle cart summary error properly
                // For this sample, we can just log the error
                console.log(e);
            });
    }

    notifyAction() {
        this.dispatchEvent(
            new CustomEvent('orderinfo', {
                bubbles: true,
                composed: true,
                detail: this.orderInformation
            })
        );
    }

    /**
     * Should the original price be shown
     * @returns {boolean} true, if we want to show the original (strikethrough) price
     * @private
     */
    get showOriginal() {
        return displayOriginalPrice(
            true,
            true,
            this.prices.finalPrice,
            this.prices.originalPrice
        );
    }

    /**
     * Gets the dynamically generated aria label for the original price element
     * @returns {string} aria label for original price
     * @private
     */
    get ariaLabelForOriginalPrice() {
        return getLabelForOriginalPrice(
            this.currencyCode,
            this.prices.originalPrice
        );
    }
}