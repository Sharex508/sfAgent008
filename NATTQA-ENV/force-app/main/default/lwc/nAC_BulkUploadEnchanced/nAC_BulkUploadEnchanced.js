/*** Standard LWC Imports ***/
import { LightningElement, api, track, wire } from "lwc";
import { NavigationMixin } from "lightning/navigation";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import getWebstore from '@salesforce/apex/NACon_B2BGetInfo.getWebstore';


/*** Salesforce Community Imports ***/
import communityId from "@salesforce/community/Id";

/*** Imports from B2B Libraries ***/
import productSearch from "@salesforce/apex/NACon_B2BGetInfo.productSearch";
import quickProductSearch from "@salesforce/apex/NACon_B2BGetInfo.quickProductSearch";
import getCartSummary from "@salesforce/apex/NACon_B2BGetInfo.getCartSummary";
import getUserAccount from "@salesforce/apex/B2BUtils.getUserAccount";
import addItemsToCart from "@salesforce/apex/NACon_B2BGetInfo.addItemsToCart";
import getLoginURL from "@salesforce/apex/B2BUtils.getLoginURL";
import getProductPrice from "@salesforce/apex/NACon_B2BGetInfo.getProductPrice";
import getProductDetail from "@salesforce/apex/NACon_B2BGetInfo.getProductDetail";
import getTemplateLink from '@salesforce/apex/NACon_B2BGetInfo.GetResourceURL';

/*** Imports from NACon_PriceAvailabilityController ***/
import getAvailable from "@salesforce/apex/NACon_PriceAvailabilityController.getAvailable";
import getHistory from "@salesforce/apex/NACon_PriceAvailabilityController.getHistory";
import getCommunityUrl from "@salesforce/apex/NACon_PriceAvailabilityController.getNAContainerURL";
import getQuantityBreakListPrices from "@salesforce/apex/NACon_PriceAvailabilityController.getQuantityBreakListPrices";
import getCartDetails from '@salesforce/apex/Nac_GetCustomSettingWareHouseData.getCartDetails';


/*** Imports internal to component ***/
import nAC_BulkUploadEnchancedLineItem from "./nAC_BulkUploadEnchancedLineItem";

import { publish, MessageContext } from "lightning/messageService";
import cartChanged from "@salesforce/messageChannel/lightning__commerce_cartChanged";


/*** Imports from Custom Labels ***/
import AddRowLabel from '@salesforce/label/c.NATT_PAO_Add_Rows';
import AddToCartLabel from '@salesforce/label/c.NATT_PAO_Add_to_Cart';
import AvailableLabel from '@salesforce/label/c.NATT_PAO_Available';
import ClearAllLabel from '@salesforce/label/c.NATT_PAO_Clear_All';
import ClearErrorsLabel from '@salesforce/label/c.NATT_PAO_Clear_Errors';
import DescriptionLabel from '@salesforce/label/c.NATT_PAO_Description';
import DiscountCodeLabel from '@salesforce/label/c.NATT_PAO_Discount_Code';
import ListPriceLabel from '@salesforce/label/c.NATT_PAO_List_Price';
import OrDropFilesLabel from '@salesforce/label/c.NATT_PAO_Or_drop_files';
import PartHistoryLabel from '@salesforce/label/c.NATT_PAO_Part_History';
import PartNumberLabel from '@salesforce/label/c.NATT_PAO_Part_Number';
import PriceAvailabilityOrderingLabel from '@salesforce/label/c.NATT_PAO_Price_Availability_and_Ordering';
import ProductQuickSearchLabel from '@salesforce/label/c.NATT_PAO_Product_Quick_Search';
import QuantityLabel from '@salesforce/label/c.NATT_PAO_Quantity';
import RemoveLabel from '@salesforce/label/c.NATT_PAO_Remove';
import RemoveRowLabel from '@salesforce/label/c.NATT_PAO_Remove_Row';
import SearchProductsLabel from '@salesforce/label/c.NATT_PAO_Search_Products';
import UOMLabel from '@salesforce/label/c.NATT_PAO_UOM';
import UploadFilesLabel from '@salesforce/label/c.NATT_PAO_Upload_Files';
import ValidationStatusLabel from '@salesforce/label/c.NATT_PAO_Validation_Status';
import WeightDimensionsLabel from '@salesforce/label/c.NATT_PAO_Weight_Dimensions';

import ContinueClearErrorsLabel from '@salesforce/label/c.NATT_PAO_Continue_Clear_Errors';
import WarningMessageLabel from '@salesforce/label/c.NATT_PAO_Warning_Message';
import WarningLabel from '@salesforce/label/c.NATT_PAO_Warning';
import QuantityPriceBreaksLabel from '@salesforce/label/c.NATT_PAO_Quantity_Price_Breaks';
import QuantityBreakLabel from '@salesforce/label/c.NATT_PAO_Quantity_Break';
import QuantityCheckLabel from '@salesforce/label/c.NATT_PAO_Quantity_Check';
import QuickEntryLabel from '@salesforce/label/c.NATT_PAO_Quick_Entry';
import ContinueShoppingLabel from '@salesforce/label/c.NATT_PAO_Continue_Shopping';
import ViewCartLabel from '@salesforce/label/c.NATT_PAO_View_Cart';
import CloseModalLabel from '@salesforce/label/c.NATT_PAO_Close_Modal';
import CloseLabel from '@salesforce/label/c.NATT_PAO_Close';
import SupersededPartLabel from '@salesforce/label/c.NATT_PAO_Superseded_Part';
import AllOfTheseOriginalLabel from '@salesforce/label/c.NATT_PAO_All_of_these_original';
import FinalPartLabel from '@salesforce/label/c.NATT_PAO_Final_Part';
import CoreLabel from '@salesforce/label/c.NATT_PAO_CORE';
import QTYPriceBreaksAvailableLabel from '@salesforce/label/c.NATT_PAO_QTY_Price_Breaks_Available';
import ViewDimensions from '@salesforce/label/c.NATT_PAO_View_Dimensions';
import ViewWeightsandDimensionsLabel from '@salesforce/label/c.NATT_PAO_View_Weights_and_Dimensions';
import ItemWasAddedToCartLabel from '@salesforce/label/c.NATT_PAO_Item_was_added_to_cart';
import AddToOrderLabel from '@salesforce/label/c.NATT_PAO_Add_to_Order';
import PleaseSelectLabel from '@salesforce/label/c.NATT_PAO_Please_select';
import TransferPriceLabel from '@salesforce/label/c.NATT_PAO_Transfer_Price';
import NACRecordTypeid from '@salesforce/label/c.NAC_Product_RecordTypeId';


const staticResourceName = 'NAC_Bulk_Upload_Template';

export default class NAC_BulkUploadEnchanced extends NavigationMixin(LightningElement) {

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
    /** @type {nAC_BulkUploadEnchancedLineItem} - Holds the Line Item that will be displayed in the Part History modal */
    @track historyLineItem;
    /*** @type {boolean} - displays show Quantity modal when true */
    @track showQuantityCheck = false;


    /**
     * Custom Label creation
     */
     label = {
      AddRowLabel,
      AddToCartLabel,
      AllOfTheseOriginalLabel,
      AvailableLabel,
      ClearAllLabel,
      ClearErrorsLabel,
      CloseLabel,
      CloseModalLabel,
      ContinueClearErrorsLabel,
      ContinueShoppingLabel,
      CoreLabel,
      DescriptionLabel,
      DiscountCodeLabel,
      FinalPartLabel,
      ItemWasAddedToCartLabel,
      ListPriceLabel,
      OrDropFilesLabel,
      PartHistoryLabel,
      PartNumberLabel,
      PriceAvailabilityOrderingLabel,
      ProductQuickSearchLabel,
      QTYPriceBreaksAvailableLabel,
      QuantityBreakLabel,
      QuantityCheckLabel,
      QuantityLabel,
      QuantityPriceBreaksLabel,
      QuickEntryLabel,
      RemoveLabel,
      RemoveRowLabel,
      SearchProductsLabel,
      SupersededPartLabel,
      UOMLabel,
      UploadFilesLabel,
      ValidationStatusLabel,
      ViewCartLabel,
      ViewDimensions,
      ViewWeightsandDimensionsLabel,
      WarningLabel,
      WarningMessageLabel,
      WeightDimensionsLabel,
      AddToOrderLabel,
      PleaseSelectLabel,
      TransferPriceLabel
     }
  
    naContainerUrl;
     @api clickedWarehouse;
    showTiers = false;
    currentPriceAdjustmentTiers;
    stageQuantityBreakListPrice = new Map();
    showQuickEntry=false;
    showPao=true;
    showProductSearchResult=false;
    currentCommunityId;
    productSearchTerm;
    hasProductSearchResults=false;
    @track productData;
    productColumns=[{
        label: this.label.DescriptionLabel,
        fieldName: 'Name',
        type: 'text',
        sortable: true
    },{
      label: this.label.PartNumberLabel,
      fieldName: 'NATT_P_N__c',
      type: 'text',
      sortable: true
    }];
    sortBy;
    sortDirection;
    isCtmStorefront = false;
    isCtbrStorefront = false;
    storefrontName = '';
    downloadLink = '';
  
    /***
     * Start out with 5 empty rows, these need to be hard-coded to show up, doesn't work if you move it to a function
     *
     * @type {nAC_BulkUploadEnchancedLineItem[]}
     */
    @track lineItems = [
      new nAC_BulkUploadEnchancedLineItem(null, null, null, null, 1),
      new nAC_BulkUploadEnchancedLineItem(null, null, null, null, 2),
      new nAC_BulkUploadEnchancedLineItem(null, null, null, null, 3),
      new nAC_BulkUploadEnchancedLineItem(null, null, null, null, 4),
      new nAC_BulkUploadEnchancedLineItem(null, null, null, null, 5)
    ];
  
    @track quickEntryLineItems = [
      new nAC_BulkUploadEnchancedLineItem(null, null, null, null, 1),
      new nAC_BulkUploadEnchancedLineItem(null, null, null, null, 2),
      new nAC_BulkUploadEnchancedLineItem(null, null, null, null, 3),
      new nAC_BulkUploadEnchancedLineItem(null, null, null, null, 4),
      new nAC_BulkUploadEnchancedLineItem(null, null, null, null, 5),
      new nAC_BulkUploadEnchancedLineItem(null, null, null, null, 6),
      new nAC_BulkUploadEnchancedLineItem(null, null, null, null, 7),
      new nAC_BulkUploadEnchancedLineItem(null, null, null, null, 8),
      new nAC_BulkUploadEnchancedLineItem(null, null, null, null, 9),
      new nAC_BulkUploadEnchancedLineItem(null, null, null, null, 10),
      new nAC_BulkUploadEnchancedLineItem(null, null, null, null, 11),
      new nAC_BulkUploadEnchancedLineItem(null, null, null, null, 12),
      new nAC_BulkUploadEnchancedLineItem(null, null, null, null, 13),
      new nAC_BulkUploadEnchancedLineItem(null, null, null, null, 14),
      new nAC_BulkUploadEnchancedLineItem(null, null, null, null, 15),
      new nAC_BulkUploadEnchancedLineItem(null, null, null, null, 16),
      new nAC_BulkUploadEnchancedLineItem(null, null, null, null, 17),
      new nAC_BulkUploadEnchancedLineItem(null, null, null, null, 18),
      new nAC_BulkUploadEnchancedLineItem(null, null, null, null, 19),
      new nAC_BulkUploadEnchancedLineItem(null, null, null, null, 20),
      new nAC_BulkUploadEnchancedLineItem(null, null, null, null, 21),
      new nAC_BulkUploadEnchancedLineItem(null, null, null, null, 22),
      new nAC_BulkUploadEnchancedLineItem(null, null, null, null, 23),
      new nAC_BulkUploadEnchancedLineItem(null, null, null, null, 24),
      new nAC_BulkUploadEnchancedLineItem(null, null, null, null, 25)
    ];
  
    /**
     * The connectedCallback() lifecycle hook fires when a component is inserted into the DOM.
     */
    connectedCallback() {
      this.currentCommunityId=communityId;
      this.getWebstoreName();
      console.log('Effective Account Id: ' + this.resolvedEffectiveAccountId);
      this.updateCartInformation();
      this.grabUrl();
      this.getQtyBreak();    
      //console.log('currentCommunityId:'+this.currentCommunityId);

      getTemplateLink({ resourceName: staticResourceName })
      .then(result => {
          try {
              this.downloadLink = result;
          }
          catch (error) {
              console.log(JSON.stringify(error.message));
          }
      })
      .catch(error => {
          console.log('Error' + JSON.stringify(error));
      });

      getCartDetails({ communityId: communityId, effectiveAccountId: this.resolvedEffectiveAccountId, activeCartOrId: 'active' })
      .then(result => {
         
          this.clickedWarehouse = result;
          console.log('clickedWarehouse:'+ this.clickedWarehouse);
      })
      .catch(error => {
          
          this.error = error;
      });
    }
  
    /***************************
     * Button Click Handlers
     ***************************/
  
    /***
     * Click handler for Remove button
     */
    handleRemoveLineItem(event) {
      var i;
      this.lineItems.splice(this.getIndex(event), 1);
      if (this.lineItems.length === 0) {
        this.handleClearAll();
      }
      for (i = 0; i < this.lineItems.length; i++) {
        this.lineItems[i].rowNumber = i + 1;
      }
    }
  
    /***
     * Click handler for Add to Cart button
     */  
    handleAddToCart() {
      if (this.isInvalid) {
        console.log('isInvalid = true');
        return;
      }
  
      let products = [];
      //console.log('lineItems:' + JSON.stringify(this.lineItems));
      this.lineItems.forEach((lineItem) => {
        if (!lineItem.isEmpty) {
          products.push([lineItem.id, lineItem.quantity]);
          if (lineItem.hasCoreCharge) {
            products.push([lineItem._corePartProductId, lineItem.quantity]);
          }
        }
      });
      
      this.showSpinner = true;
      this.handleUnsavedChanges(false);
      let effActId = this.resolvedEffectiveAccountId;
      
      this.batchItemsToCart({
        products
      })
        .then(() => {       
          this.cartId = this.cartSummary?.cartId;
          if(!this.cartId){         
            console.log('called with communityId:'+this.currentCommunityId);
            getCartSummary({
              communityId: this.currentCommunityId,
              effectiveAccountId: this.resolvedEffectiveAccountId
            })
              .then((result) => {
                this.cartSummary = result;
                this.cartId=this.cartSummary.cartId;
              })
              .catch((e) => {
                // Handle cart summary error properly
                // For this sample, we can just log the error
                console.log(e);
                this.error = e;
              });          
          }                
        })
        .catch((e) => {
          console.log(e);
          this.error = e;
        })
        .finally(() => {
          this.showAddToCart = true;
          this.showSpinner = false;
        });
    }
    
    async batchItemsToCart(products){     
      let chunks=[];
      let len = 100;
      let i=0;
      let n = products.products.length;
      let promises = [];
      while(i<n){
          chunks = (products.products.slice(i,i+=len));        
         await addItemsToCart({
            communityId: this.currentCommunityId,
            effectiveAccountId: this.resolvedEffectiveAccountId,
            products: chunks
          });
      }
      
      
      
    }
  
    splitArrayIntoChunksOfLen(arr, len) {
      var chunks = [], i = 0, n = arr.length;
      while (i < n) {
        chunks.push(arr.slice(i, i += len));
      }
      return chunks;
    }
  
    /***
     * Click handler for Add Row button
     * Adds 5 empty rows to the end of the lineItems list
     */
    handleAddRow() {
      let emptyLineItems = [];
      let lineItemIndex = this.lineItems ? this.lineItems.length + 1 : 0;
      let i;
      for (i = 0; i < 5; i++) {
        emptyLineItems.push(
          new nAC_BulkUploadEnchancedLineItem(
            null,
            null,
            null,
            null,
            lineItemIndex + i
          )
        );
      }
  
      if (this.lineItems === null) {
        this.lineItems = emptyLineItems;
      } else {
        this.lineItems = this.lineItems.concat(emptyLineItems);
      }
    }
  
    handleAddRowQuickEntry() {
      let emptyLineItems = [];
      let lineItemIndex = this.quickEntryLineItems ? this.quickEntryLineItems.length + 1 : 0;
      let i;
      for (i = 0; i < 25; i++) {
        emptyLineItems.push(
          new nAC_BulkUploadEnchancedLineItem(
            null,
            null,
            null,
            null,
            lineItemIndex + i
          )
        );
      }
  
      if (this.quickEntryLineItems === null) {
        this.quickEntryLineItems = emptyLineItems;
      } else {
        this.quickEntryLineItems = this.quickEntryLineItems.concat(emptyLineItems);
      }
    }
  
    /***
     * Click handler for Clear All button, adds 5 empty rows to get back to original state
     */
    handleClearAll() {
      this.lineItems = [
        new nAC_BulkUploadEnchancedLineItem(null, null, null, null, 1),
        new nAC_BulkUploadEnchancedLineItem(null, null, null, null, 2),
        new nAC_BulkUploadEnchancedLineItem(null, null, null, null, 3),
        new nAC_BulkUploadEnchancedLineItem(null, null, null, null, 4),
        new nAC_BulkUploadEnchancedLineItem(null, null, null, null, 5)
      ];
      this.handleUnsavedChanges(false);
    }
  
    /***
     * Click handler for Clear Errors button
     */
    handleClearErrors() {
      let lineItemsWithoutErrors = [];
      let rowNumber = 1;
      // Reset the row numbers
      this.lineItems.forEach((lineItem) => {
        if (!lineItem.isInvalid || lineItem.validationStatus == 'Valid Part') {
          lineItem.rowNumber = rowNumber++;
          lineItemsWithoutErrors.push(lineItem);
        }
      });
  
      this.lineItems = lineItemsWithoutErrors;
    }
  
    /***
     * Click handler for Part History
     */
    handleShowProductHistory(event) {
      this.historyLineItem = this.lineItems[this.getIndex(event)];
      this.showHistory = true;
    }
  
    handleShowTiers(event) {
      this.currentPriceAdjustmentTiers = this.lineItems[this.getIndex(event)];
      console.log('selected:' + JSON.stringify(this.currentPriceAdjustmentTiers));
      this.currentPriceAdjustmentTiers._productPrice.priceAdjustment.priceAdjustmentTiers.forEach(price => {
        // overriding the tier price to show the list price break from the staging table
        price.tierUnitPrice = this.stageQuantityBreakListPrice.get(this.currentPriceAdjustmentTiers._product.id + ':' + price.lowerBound);
      });
      this.showTiers = true;
    }
  
    /***
     * Click handler for Close modal buttons
     */
    handleCloseModal() {
      if (this.showHistory) {
        this.showHistory = false;
      }
      if (this.showAddToCart) {
        this.handleClearAll();
        this.showAddToCart = false;
        publish(this.messageContext, cartChanged);
        location.reload();
      }
  
      if (this.showQuantityCheck) {
        this.showQuantityCheck = false;
      }
  
      if (this.showTiers) {
        this.showTiers = false;
      }
    }
  
    /***
     * Click handler for View Cart button
     */
    handleViewCart() {
      this[NavigationMixin.Navigate]({
        type: "standard__recordPage",
        attributes: {
          recordId: this.cartId,
          objectApiName: "WebCart",
          actionName: "view"
        }
      });
  
      publish(this.messageContext, cartChanged);
    }
  
    /***
     * Click handler for clicking link for bulletin document
     */
    handleDownloadBulletin(event) {
      this[NavigationMixin.Navigate](
        {
          type: "standard__webPage",
          attributes: {
            url:
              this.getBaseUrl() +
              this.lineItems[this.getIndex(event)].userGuideURL
          }
        },
        false
      );
    }
  
    /***************************
     * Unsaved Changes
     ***************************/
  
    _dirty = false;
    handleUnsavedChanges(isDirty) {
      this._dirty = isDirty;
      const fieldChangeEvent = new CustomEvent("fieldchange", {
        detail: { isDirty }
      });
      this.dispatchEvent(fieldChangeEvent);
    }
  
    /***************************
     * Event Handlers
     ***************************/
  
    /***
     * OnBlur handler for when user leaves Part Number
     */
    async handlePartNumberBlur(event) {
      this.handleUnsavedChanges(true);
      let enteredPartNumber = event.target.value;
      console.log('enteredPartNumber:'+ enteredPartNumber);
      let rowIndex = parseInt(this.getIndex(event), 10);
      console.log('rowIndex:'+ rowIndex);
  
      if (enteredPartNumber === "") {
        this.lineItems[rowIndex] = new nAC_BulkUploadEnchancedLineItem(
          null,
          null,
          null,
          null,
          rowIndex + 1
        );

      } else if (enteredPartNumber !== this.lineItems[rowIndex].partNumber) {
        this.showSpinner = true;  
       /**  console.log(' else lineItems:'+ lineItems); */
        await this.updateProductAsync(enteredPartNumber, null, rowIndex);
        this.showSpinner = false;
      }
    }
  
    /**
     * OnChange handler for Quantity
     * Set the quantity on the correct Line Item
     *
     * @returns {void}
     */
    handleQuantityEntered(event) {
      let lineItem = this.lineItems[this.getIndex(event)];
      lineItem.quantity = event.detail.value;
      let rowIndex = parseInt(this.getIndex(event));
      this.lineItems.splice(this.getIndex(event), 1, lineItem);
    }
  
    /*************************************************
     * Handlers for showing/hiding tooltips on hover
     ************************************************/
    handleEnterWeightsAndDimensions(event) {
      let lineItem = this.lineItems[this.getIndex(event)];
      lineItem.showWeightAndDimensions = true;
      this.lineItems.splice(this.getIndex(event), 1, lineItem);
    }
  
    handleLeaveWeightsAndDimensions(event) {
      let lineItem = this.lineItems[this.getIndex(event)];
      lineItem.showWeightAndDimensions = false;
      this.lineItems.splice(this.getIndex(event), 1, lineItem);
    }
  
    handleEnterAvailability(event) {
      let lineItem = this.lineItems[this.getIndex(event)];
      lineItem.showAvailability = true;
      this.lineItems.splice(this.getIndex(event), 1, lineItem);
    }
  
    handleLeaveAvailability(event) {
      let lineItem = this.lineItems[this.getIndex(event)];
      lineItem.showAvailability = false;
      this.lineItems.splice(this.getIndex(event), 1, lineItem);
    }
    /****************************************************
     * End Handlers for showing/hiding tooltips on hover
     ****************************************************/
    
    /***
     *  Utility function that returns the row number for click
     *  events that occur within the table
     *
     *  @param {Event} event - Event that occurs within the table (loop)
     *  @returns {number} The index of the lineItem that sourced the event
     */
    getIndex(event) {
      return event.target
        .closest("[data-index]")
        .attributes.getNamedItem("data-index").value;
    }
  
    /***
     * Utility function that loops through array of
     * line items and sets the Row Number value correctly
     *
     *  @param {nAC_BulkUploadEnchancedLineItem[]} lineItemArray Array of line items to correct
     *  @returns {nAC_BulkUploadEnchancedLineItem[]} Original array with Row Numbers recalculatd
     */
    recalculateRowNumbers(lineItemArray) {
      var i;
      for (i = 0; i < this.lineItems.length; i++) {
        this.lineItems[i].rowNumber = i + 1;
      }
      return lineItemArray;
    }
  
    /***
     * Checks validity of all rows, the empty check
     * allows us to skip rows that are in the list but
     * haven't been touched by the user yet
     *
     * @returns {boolean} True if any line items are invalid, otherswise false
     */
    get isInvalid() {
      var invalid = false;
      var allEmpty = true;
      this.lineItems.forEach((lineItem) => {
        if (lineItem.isInvalid) {
          invalid = true;
        }
        if (!lineItem.isEmpty) {
          allEmpty = false;
        }
      });
  
      return invalid || allEmpty;
    }
  
    /***
     * Get the base URL, used for redirecting to Cart
     * @returns {string} The base URL for displaying Content Document
     */
    getBaseUrl() {
      let baseUrl = "https://" + location.host + "/";
      getLoginURL()
        .then((result) => {
          baseUrl = result;
        })
        .catch((error) => {
          console.error("Error: \n ", error);
        });
      return baseUrl;
    }
  
    /**
     * Gets the effective account - if any - of the user viewing the product.
     *
     * @returns {string}
     */
    @wire(getUserAccount) _effectiveAccountInfo;
  
    // @api
    // get effectiveAccountId() {
    //   return this._effectiveAccountInfo?.data?.Contact?.AccountId;
    // }
    /**
    * Gets the effective account - if any - of the user viewing the product.
    *
    */
     @api
     get effectiveAccountId() {
       return this._effectiveAccountId;
     }
   
     set effectiveAccountId(value) {
       this._effectiveAccountId = value;
     }
     
  
    get effectiveAccountRecordType() {
      return this._effectiveAccountInfo?.data?.Contact?.Account?.RecordType?.Name;
    }
  
    get isInternalCustomer() {
      return this.effectiveAccountRecordType === "Internal";
    }
  
    /**
     * The cart summary information
     *
     * @type {ConnectApi.CartSummary}
     * @private
     */
    cartSummary;
  
    /**
     * Gets the normalized effective account of the user.
     *
     * @type {string}
     * @readonly
     * @private
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
  
    /**
     * Ensures cart information is up to date
     *
     * @returns {void}
     */
    updateCartInformation() {
      console.log('getting cart with communityId:'+this.currentCommunityId);
      getCartSummary({
        communityId: this.currentCommunityId,
        effectiveAccountId: this.resolvedEffectiveAccountId
      })
        .then((result) => {
          this.cartSummary = result;
        })
        .catch((e) => {
          // Handle cart summary error properly
          // For this sample, we can just log the error
          console.log(e);
          this.error = e;
        });
    }
  
    /**
     * Grabs Community URL for NSU Request Quote link
     */
    grabUrl() {
      getCommunityUrl()
        .then(result => {
          console.log('NA Container Result: ' + result);
          this.naContainerUrl = result;
        })
        .catch(error => {
          console.log('URL Grab Failure: ' + error.body.message);
          this.error = error;
        });
    }
  
    /***
     * Show a toast event
     */
    showNotification(title, message, variant) {
      console.log('called showToast');
      const event = new ShowToastEvent({
        title: title,
        message: message,
        variant: variant
      });
      this.dispatchEvent(event);
    }
  
    getQtyBreak() {
      let key;
      getQuantityBreakListPrices()
        .then(result => {
          result.forEach(price => {
            console.log('price:' + JSON.stringify(price));
            key = price.NATT_Product__c + ':' + price.NATT_QuantityFrom__c.toString();
            console.log('key:' + key);
            this.stageQuantityBreakListPrice.set(key, price.NATT_ListPrice__c);
            console.log('stageQuantityBreakListPrice:' + JSON.stringify(this.stageQuantityBreakListPrice));
          });
        });
    }
  
    /************************************************/
    /******** Handle File Upload and Parsing ********/
    /************************************************/
    async handleFileUpload(event) {

      if (event.target.files.length === 1) {
        // Check for the various File API support.
        if (window.FileReader) {
          this.showSpinner = true;
          let promises = [];
          try{
            let csv = await this.readFileText(event.target.files[0]);
           let uploadedRecords = await this.processCsv(csv);
            for (let i = 0; i < uploadedRecords.length -1; i++) {

               promises.push(this.updateProductAsync(uploadedRecords[i][0], uploadedRecords[i][1], i));
  
              if((i+1)%10===0){
                await Promise.all(promises).then(() => {
                  console.log('10 records processed');
                });
                promises=[];
              } 
            

          }

            if(promises.length>0){
              await Promise.all(promises).then(() => {
                console.log('remaining records processed');
              });
            }        
          }catch(error){
            console.log('Error processing csv: ' + error.body.message);
            this.error = error;
            this.showSpinner = false;
          };
          this.showSpinner = false;
        } else {
          this.showNotification(
            "Unsupported",
            "This browser does not support this functionality",
            "error"
          );
        }
      }
    }
  
    async readFileText(fileToRead) {
      return new Promise((resolve, reject) => {
        var reader = new FileReader();
        // Handle errors load
        reader.onload = () => resolve(reader.result);
        reader.onerror = () => reject(reader.error);
        // Read file into memory as UTF-8
        reader.readAsText(fileToRead);
      });
    }
  
    async processCsv(csv) {
      var allTextLines = csv.split(/\r\n|\n/);
      var lines = [];
      var i;
      let delimiter = ',';
      if(this.storefrontName=='CTBR Storefront'){
        delimiter=';'
      }
      console.log('allTextLines.length'+ allTextLines.length);
      for (i = 1; i < allTextLines.length; i++) {

        let data = allTextLines[i].split(delimiter);
        
        let tempLine = [];
        let j;
        for (j = 0; j < data.length; j++) {

          console.log('data'+ data[j]);
         
          tempLine.push(data[j]);
          
        }
        lines.push(tempLine);
      }
  
      return lines;
    }
  
    async updateProductAsync(partNumber, quantity, rowIndex, supercededPartNumber) {

      var newLineItem;
      partNumber = partNumber.trim();
      let productSearchResult;    
      let coreProductSearchResult;
      let availabilityResult;
      let historyResult;
      let userGuideResult;    
      let productInfo;
      let coreProductId;
      let productPrice;
      let coreProductPrice;
      this.clickedWarehouse;
  
      const promises = [];
      try{
      productSearchResult = await productSearch({
        communityId: this.currentCommunityId,
        partNumber: partNumber,
        effectiveAccountId: this.resolvedEffectiveAccountId
      });
  
      console.log('productSearchResult:'+JSON.stringify(productSearchResult));
      console.log('clickedWarehouse:'+ this.clickedWarehouse);
      

      if (productSearchResult?.productsPage?.products) {
        console.log('products-->'+ productSearchResult.productsPage.products);
        productSearchResult.productsPage.products.forEach((product) => {
          if (partNumber.toLowerCase() === product.fields.NATT_P_N__c.value.toLowerCase()) {
            console.log('RecordTypeid'+ product.fields.RecordTypeId.value);  
           // console.log('branchplant warehouse:'+ product.fields.NATT_Branch_Plant_Warehouse__c.value);
             if(product.fields.RecordTypeId.value===NACRecordTypeid){
            productInfo = product;
            this.clickedWarehouse=this.clickedWarehouse;
             }
          }
        });
      }
      console.log('productInfo:' + JSON.stringify(productInfo));
      if (productInfo !== "undefined") {
        console.log('found product info and core charge is:' + productInfo.fields?.NATT_CoreCharge__c?.value);
        // If the part has a core charge, need to also find the core item
        if (productInfo.fields?.NATT_CoreCharge__c?.value === "true") {
          /** @type {ConnectApi.ProductSearchResults} **/
          console.log('looking for core part:' + productInfo.fields.NATT_CoreItem_P_N__c.value);
          coreProductSearchResult = await productSearch({
            communityId: this.currentCommunityId,
            partNumber: productInfo.fields.NATT_CoreItem_P_N__c.value,
            effectiveAccountId: this.resolvedEffectiveAccountId
          });
  
          // Loop through search results and find the one that matches the input part number
          if (coreProductSearchResult?.productsPage?.products) {
            coreProductSearchResult.productsPage.products.forEach((product) => {
              console.log('loop:' + JSON.stringify(product));
              if (productInfo.fields.NATT_CoreItem_P_N__c.value.toLowerCase() === product.fields.NATT_P_N__c.value.toLowerCase()) {
                coreProductId = product.id;
                coreProductPrice = product?.prices?.listPrice;
                console.log('coreProductId:' + coreProductId);
              }
            });
          }
        }
        console.log('received main product...loading promises');
        promises.push(getAvailable({ productId: productInfo.id, storefrontName: this.storefrontName, acctId: this.resolvedEffectiveAccountId }));
        promises.push(getHistory({ prodID: productInfo.id }));
        promises.push(getProductDetail({ communityId: this.currentCommunityId, productId: productInfo.id, effectiveAccountId: this.resolvedEffectiveAccountId }));
        promises.push(getProductPrice({ communityId: this.currentCommunityId, productId: productInfo.id, effectiveAccountId: this.resolvedEffectiveAccountId }));
  
        await Promise.all(promises).then(result => {
          console.log('all finished:' + JSON.stringify(result));
          availabilityResult = result[0];
          historyResult = result[1];
          userGuideResult = result[2];
          productPrice = result[3];
        });
  
        console.log('after all finished');
        newLineItem = new nAC_BulkUploadEnchancedLineItem(
          productInfo,
          availabilityResult,
          historyResult,
          userGuideResult,
          rowIndex + 1,
          supercededPartNumber,
          coreProductId,
          this.naContainerUrl,
          productPrice,
          coreProductPrice,
          this.clickedWarehouse
        );
        newLineItem.quantity = quantity;
        // Checking these because we want to replace if change is through the UI,
        // but push if coming through a file upload
        if (this.lineItems[rowIndex] !== null) {

          this.lineItems[rowIndex] = newLineItem;
        } else {
          this.lineItems.push(newLineItem);
        }
  
        if (newLineItem.isSuperseded) {
          console.log('product has been superseded:' + newLineItem.finalPartNumber + ' partNumber:' + partNumber);
          this.updateProductAsync(
            newLineItem.finalPartNumber,
            newLineItem.quantity,
            rowIndex,
            // Passing in partNumber here makes the supersedes message show up
            partNumber
          );
        }
      }else{
        newLineItem = new nAC_BulkUploadEnchancedLineItem(
          { fields: { NATT_P_N__c: { value: partNumber } } },
          null,
          null,
          null,
          rowIndex + 1
        );
        this.lineItems[rowIndex] = newLineItem;
      }
    }catch(error){
      console.log('error:'+JSON.stringify(error));
      newLineItem = new nAC_BulkUploadEnchancedLineItem(
        { fields: { NATT_P_N__c: { value: partNumber } } },
        null,
        null,
        null,
        rowIndex + 1
      );
      this.lineItems[rowIndex] = newLineItem;
    }
    }
    /****************************************************/
    /******** End Handle File Upload and Parsing ********/
    /****************************************************/
    handleShowQuickEntry(){
      this.showQuickEntry = true;
      this.showPao=false;
      this.showProductSearchResult=false;
    }
  
    handleHideQuickEntry(){
      this.showQuickEntry = false;
      this.showPao=true;
      this.showProductSearchResult=false;
    }
  
    handleCancelQuickEntry() {
      this.quickEntryLineItems = [
        new nAC_BulkUploadEnchancedLineItem(null, null, null, null, 1),
        new nAC_BulkUploadEnchancedLineItem(null, null, null, null, 2),
        new nAC_BulkUploadEnchancedLineItem(null, null, null, null, 3),
        new nAC_BulkUploadEnchancedLineItem(null, null, null, null, 4),
        new nAC_BulkUploadEnchancedLineItem(null, null, null, null, 5),
        new nAC_BulkUploadEnchancedLineItem(null, null, null, null, 6),
        new nAC_BulkUploadEnchancedLineItem(null, null, null, null, 7),
        new nAC_BulkUploadEnchancedLineItem(null, null, null, null, 8),
        new nAC_BulkUploadEnchancedLineItem(null, null, null, null, 9),
        new nAC_BulkUploadEnchancedLineItem(null, null, null, null, 10),
        new nAC_BulkUploadEnchancedLineItem(null, null, null, null, 11),
        new nAC_BulkUploadEnchancedLineItem(null, null, null, null, 12),
        new nAC_BulkUploadEnchancedLineItem(null, null, null, null, 13),
        new nAC_BulkUploadEnchancedLineItem(null, null, null, null, 14),
        new nAC_BulkUploadEnchancedLineItem(null, null, null, null, 15),
        new nAC_BulkUploadEnchancedLineItem(null, null, null, null, 16),
        new nAC_BulkUploadEnchancedLineItem(null, null, null, null, 17),
        new nAC_BulkUploadEnchancedLineItem(null, null, null, null, 18),
        new nAC_BulkUploadEnchancedLineItem(null, null, null, null, 19),
        new nAC_BulkUploadEnchancedLineItem(null, null, null, null, 20),
        new nAC_BulkUploadEnchancedLineItem(null, null, null, null, 21),
        new nAC_BulkUploadEnchancedLineItem(null, null, null, null, 22),
        new nAC_BulkUploadEnchancedLineItem(null, null, null, null, 23),
        new nAC_BulkUploadEnchancedLineItem(null, null, null, null, 24),
        new nAC_BulkUploadEnchancedLineItem(null, null, null, null, 25)
      ];
      this.handleHideQuickEntry();
    }
  
    async handlePartNumberBlurQuickEntry(event) {  
      
      
      let enteredPartNumber = event.target.value;
      let rowIndex = parseInt(this.getIndex(event), 10);
  
      if (enteredPartNumber === "") {
        this.quickEntryLineItems[rowIndex] = new nAC_BulkUploadEnchancedLineItem(
          null,
          null,
          null,
          null,
          rowIndex + 1
        );
      } else if (enteredPartNumber !== this.quickEntryLineItems[rowIndex].quickEntryProductNumber) {
        let lineItem = this.quickEntryLineItems[this.getIndex(event)];
        lineItem.quickEntryProductNumber = event.target.value;
        let rowIndex = parseInt(this.getIndex(event));
        this.quickEntryLineItems.splice(this.getIndex(event), 1, lineItem);
      }
    }
    
    handleQuantityEnteredQuickEntry(event) {
      let lineItem = this.quickEntryLineItems[this.getIndex(event)];
      lineItem.quantity = event.detail.value;
      let rowIndex = parseInt(this.getIndex(event));
      this.quickEntryLineItems.splice(this.getIndex(event), 1, lineItem);
    }
  
    async handleAddQuickEntryLines(){
      this.showSpinner = true;
      let promises = [];
      
      let validRecords=[];
      for(let i=0; i<this.quickEntryLineItems.length; i++){      
        if(this.quickEntryLineItems[i].quickEntryProductNumber){
          validRecords.push(this.quickEntryLineItems[i]);
        }
      }
      if(validRecords.length>0){
        try{
          let currentRowCount=0;
          if(this.lineItems.length>0){
            for(let i=0;i<this.lineItems.length; i++){
              if(this.lineItems[i].partNumber){
                currentRowCount++;
              }else{
                break;
              }
            };
          }
          console.log('valid records:'+JSON.stringify(validRecords));
          for (let i = 0; i < validRecords.length; i++) {
            promises.push(this.updateProductAsync(validRecords[i].quickEntryProductNumber, validRecords[i].quantity, i+currentRowCount));
  
            if((i+1)%10===0){
              await Promise.all(promises).then(() => {
                console.log('10 records processed');
              });
              promises=[];
            }          
          }
          if(promises.length>0){
            await Promise.all(promises).then(() => {
              console.log('remaining records processed');
            });
          }
          this.handleCancelQuickEntry();
        }catch(error){
          console.log('Error processing quick entry: ' + error.body.message);
          this.error = error;
          this.showSpinner = false;
        };    
      }    
      this.showSpinner = false;
    }
  
    async handleSearchKeyUp(event){ 
      this.hasProductSearchResults=false;
      const isEnterKey = event.keyCode === 13;
      this.productSearchTerm = event.target.value;
  
      if (isEnterKey && this.productSearchTerm.length>2) {
        this.showSpinner=true;
        this.productData = [];
        //console.log('called: '+this.currentCommunityId+':'+this.productSearchTerm+':'+this.resolvedEffectiveAccountId);
        let productSearchResult =  await quickProductSearch({
          communityId: this.currentCommunityId,
          partNumber: this.productSearchTerm,
          effectiveAccountId: this.resolvedEffectiveAccountId
        });
        //console.log('psr:'+JSON.stringify(productSearchResult));
        if (productSearchResult?.productsPage?.products) {        
          let tempMap;
          let temp = [];
          productSearchResult.productsPage.products.forEach((product) => {          
            tempMap = new Map();
            tempMap.set('Id',product.id);
            tempMap.set('Name',product.fields.Name.value);
            tempMap.set('NATT_P_N__c',product.fields.NATT_P_N__c.value)
            temp.push( Object.fromEntries(tempMap.entries()) );          
          });
          this.productData = temp;
          this.showProductSearchResult=true;
          this.showQuickEntry = false;
          this.showPao=false;
        }      
        this.showSpinner=false;
        //console.log(JSON.stringify(this.productData));
      }
    }
  
    handleCancelProductSearch(){
      this.productData=null;
      this.showQuickEntry = false;
      this.showPao=true;
      this.showProductSearchResult=false;
      this.showSpinner=false;
    }
  
    async handleProductSearchAdd(){    
      let selectedRows = this.template.querySelector('lightning-datatable').getSelectedRows();
      if(selectedRows.length==0){
        this.showNotification(
          this.label.WarningLabel,
          this.label.PleaseSelectLabel,
          "warning"
        );
  
        return;
      }
      this.showSpinner = true;
      let promises = [];
      try{
        let currentRowCount=0;
        if(this.lineItems.length>0){
          for(let i=0;i<this.lineItems.length; i++){
            if(this.lineItems[i].partNumber){
              currentRowCount++;
            }else{
              break;
            }
          };
        }
        console.log('valid records:'+JSON.stringify(selectedRows));
        for (let i = 0; i < selectedRows.length; i++) {
          promises.push(this.updateProductAsync(selectedRows[i].NATT_P_N__c, 1, i+currentRowCount));
  
          if((i+1)%10===0){
            await Promise.all(promises).then(() => {
              console.log('10 records processed');
            });
            promises=[];
          }          
        }
        if(promises.length>0){
          await Promise.all(promises).then(() => {
            console.log('remaining records processed');
          });
        }
        this.handleCancelProductSearch();
      }catch(error){
        console.log('Error processing product search: ' + error.body.message);
        this.error = error;
        this.showSpinner = false;
      };
      
    }
  
    doSorting(event) {
      this.sortBy = event.detail.fieldName;
      this.sortDirection = event.detail.sortDirection;
      this.sortData(this.sortBy, this.sortDirection);
  }
  
  sortData(fieldname, direction) {
      let parseData = JSON.parse(JSON.stringify(this.productData));
      // Return the value stored in the field
      let keyValue = (a) => {
          return a[fieldname];
      };
      // cheking reverse direction
      let isReverse = direction === 'asc' ? 1: -1;
      // sorting data
      parseData.sort((x, y) => {
          x = keyValue(x) ? keyValue(x) : ''; // handling null values
          y = keyValue(y) ? keyValue(y) : '';
          // sorting values based on direction
          return isReverse * ((x > y) - (y > x));
      });
      this.productData = parseData;
  }
  
  getWebstoreName(){
    getWebstore({communityId : communityId})
    .then(result => {      
        if(result == 'CTM Storefront'){
          this.isCtmStorefront = true;
        }else if(result=='CTBR Storefront'){
          this.isCtbrStorefront=true;
        }
        this.storefrontName=result;      
    })
    .catch(error => {
        console.log('Storefront Name failed to load: ' + error.body.message);
        this.error = error;
    })      
  }
  
  get showWeightAndDimensions(){  
    let showWandD=true;
    if(this.storefrontName=='CTBR Storefront' || this.storefrontName=='CTM Storefront'){
      showWandD=false;
    }
    return showWandD;
  }
  get showAvailability(){
    let showAvailability=true;
    if(this.storefrontName=='CTBR Storefront'){
      showAvailability=false;
    }
    return showAvailability;
  }

  downloadTemplate() {
    this[NavigationMixin.Navigate]({
        type: 'standard__webPage',
        attributes: {
            url: this.downloadLink
        }
    });
}

 

}