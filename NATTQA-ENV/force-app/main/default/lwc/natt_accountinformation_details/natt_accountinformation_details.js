/*** Standard LWC Imports ***/
import { LightningElement, api, track, wire } from "lwc";
import { NavigationMixin } from "lightning/navigation";
import { ShowToastEvent } from "lightning/platformShowToastEvent";

/*** Salesforce Community Imports ***/
import communityId from "@salesforce/community/Id";

/*** Imports from B2B Libraries ***/
import productSearch from "@salesforce/apex/NATT_B2BGetInfo.productSearch";
import getCartSummary from "@salesforce/apex/NATT_B2BGetInfo.getCartSummary";
import getUserAccount from "@salesforce/apex/B2BUtils.getUserAccount";
import addItemsToCart from "@salesforce/apex/NATT_B2BGetInfo.addItemsToCart";
import getLoginURL from "@salesforce/apex/B2BUtils.getLoginURL";
import getProductPrice from "@salesforce/apex/NATT_B2BGetInfo.getProductPrice";
import getProductDetail from "@salesforce/apex/NATT_B2BGetInfo.getProductDetail";

/*** Imports from NATT_PriceAvailabilityController ***/
import getAvailable from "@salesforce/apex/NATT_PriceAvailabilityController.getAvailable";
import getHistory from "@salesforce/apex/NATT_PriceAvailabilityController.getHistory";
//import getUserGuide from "@salesforce/apex/NATT_PriceAvailabilityController.getUserGuide";
import getCommunityUrl from "@salesforce/apex/NATT_PriceAvailabilityController.getSolutionCenterURL";
import getQuantityBreakListPrices from "@salesforce/apex/NATT_PriceAvailabilityController.getQuantityBreakListPrices";


/*** Imports internal to component ***/
// import natt_priceAvailabilityLineItem from "./natt_priceAvailabilityLineItem";

import { publish, MessageContext } from "lightning/messageService";
import cartChanged from "@salesforce/messageChannel/lightning__commerce_cartChanged";
import makePrimary from "@salesforce/apex/Natt_AccountInformationCartPageHandler.makePrimary";

export default class Natt_accountinformation_details extends LightningElement {

    @wire(MessageContext)
    messageContext;
    /*** @type {boolean} - displays a spinner overlay when true */
    @track showSpinner = false;
    /*** @type {boolean} - displays the Add To Cart modal when true */
    @track showAddToCart = false;
    /*** @type {boolean} - displays Part History modal when true */
    @track showHistory = false;
    /*** @type {boolean} - ID of the current shopping cart */
    @track cartId;
    // /** @type {natt_priceAvailabilityLineItem} - Holds the Line Item that will be displayed in the Part History modal */
    // @track historyLineItem;
    /*** @type {boolean} - displays show Quantity modal when true */
    @track showQuantityCheck = false;
  
    accountIdValue;
    solutionCenterUrl;
    showTiers = false;
    currentPriceAdjustmentTiers;
    stageQuantityBreakListPrice = new Map();
    showQuickEntry=false;
  
    /**
     * The connectedCallback() lifecycle hook fires when a component is inserted into the DOM.
     */
    connectedCallback() {
        console.log('New Page Load');
        console.log('Acct ChecK: ' + this.resolvedEffectiveAccountId);
        console.log('New Page Load End');
        this.getAccountInfo();
    }
  
    acctIdCheck() {
      console.log('communityId:' + communityId);
      console.log('accountId:' + this.resolvedEffectiveAccountId);
    }

    getAccountInfo(){
        getUserAccount()
            .then((result) => {
                console.log('Get Acct Info Run');       
                this.accountIdValue = result.Contact.AccountId;
                console.log('ACcount Id Value: ' + this.accountIdValue);
            }) 
            .catch((e) => {
                // Handle cart summary error properly
                // For this sample, we can just log the error
                console.log(e);
            });
    }
  
    /**
     * Gets the effective account - if any - of the user viewing the product.
     *
     * @returns {string}
     */
    @wire(getUserAccount) _effectiveAccountInfo;
  
    @api
    get effectiveAccountId() {
      return this._effectiveAccountInfo?.data?.Contact?.AccountId;
    }

    set effectiveAccountId(value) {
      if (this._effectiveAccountId !== value) {
        this._effectiveAccountId = value;
      }
    }
  
    /**
     * Gets the normalized effective account of the user.
     *
     * @type {string}
     * @readonly
     */
    get resolvedEffectiveAccountId() {
      const effectiveAccountId = this.effectiveAccountId || "";
      let resolved = null;
  
      if (
        effectiveAccountId.length > 0 &&
        effectiveAccountId !== "000000000000000"
      ) {
        resolved = effectiveAccountId;
      }
      return resolved;
    }
  

}