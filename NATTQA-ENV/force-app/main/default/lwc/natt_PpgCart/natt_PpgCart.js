import { api, wire, LightningElement } from "lwc";
import { NavigationMixin, CurrentPageReference } from "lightning/navigation";

import communityId from "@salesforce/community/Id";
import getCartItems from "@salesforce/apex/NATT_PpgCartController.getCartItems";
import updateCartItem from "@salesforce/apex/NATT_PpgCartController.updateCartItem";
import deleteCartItem from "@salesforce/apex/NATT_PpgCartController.deleteCartItem";
import deleteCart from "@salesforce/apex/NATT_PpgCartController.deleteCart";
import createCart from "@salesforce/apex/NATT_PpgCartController.createCart";
import getCartAvailability from "@salesforce/apex/NATT_PpgCartController.getCartAvailability";

import { fireEvent } from "c/pubsub";
import { isCartClosed } from "c/natt_cartUtils";

import { publish, MessageContext} from "lightning/messageService"; 
import cartChanged from "@salesforce/messageChannel/lightning__commerce_cartChanged";

// Event name constants
const CART_CHANGED_EVT = "cartchanged";
const CART_ITEMS_UPDATED_EVT = "cartitemsupdated";

// Locked Cart Status
//const LOCKED_CART_STATUSES = new Set(['Processing', 'Checkout']);
const LOCKED_CART_STATUSES = new Set();

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
  @wire(MessageContext)
  messageContext;
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

  // /**
  //  * The effectiveAccountId provided by the cart detail flexipage.
  //  *
  //  * @type {string}
  //  */
  // @api
  // effectiveAccountId;

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
    { value: "CreatedDateAsc", label: this.labels.CreatedDateAsc },
    { value: "CreatedDateDesc", label: this.labels.CreatedDateDesc },
    { value: "NameAsc", label: this.labels.NameAsc },
    { value: "NameDesc", label: this.labels.NameDesc }
  ];

  /**
   * Specifies the page token to be used to view a page of cart information.
   * If the pageParam is null, the first page is returned.
   * @type {null|string}
   */
  pageParam = null;

  /**
   * Sort order for items in a cart.
   * The default sortOrder is 'CreatedDateAsc'
   *    - CreatedDateAsc—Sorts by oldest creation date
   *    - CreatedDateDesc—Sorts by most recent creation date.
   *    - NameAsc—Sorts by name in ascending alphabetical order (A–Z).
   *    - NameDesc—Sorts by name in descending alphabetical order (Z–A).
   * @type {string}
   */
  sortParam = "CreatedDateAsc";

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

  availabilityMap = [];

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
      loadingCartItems: "Loading Cart Items",
      clearCartButton: "Clear Cart",
      sortBy: "Sort By",
      cartHeader: "Cart",
      emptyCartHeaderLabel: "Your cart’s empty",
      emptyCartBodyLabel:
        "Search or browse products, and add them to your cart. Your selections appear here.",
      closedCartLabel: "The cart that you requested isn't available.",
      CreatedDateDesc: "Date Added - Newest First",
      CreatedDateAsc: "Date Added - Oldest First",
      NameAsc: "Name - A to Z",
      NameDesc: "Name - Z to A"
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
   * This lifecycle hook fires when this component is inserted into the DOM.
   */
  connectedCallback() {
    // Initialize 'cartItems' list as soon as the component is inserted in the DOM.
    this.updateCartItems();
  }

  /**
   * Get a list of cart items from the server via imperative apex call
   */
  updateCartItems() {
    //this.recordId='0a6P0000000CatkIAC';
    //this.effectiveAccountId='001P000001oRGnlIAG';
    console.log(
      "called communityId:" +
        communityId +
        " effAccountId:" +
        this.resolvedEffectiveAccountId +
        " cart:" +
        this.recordId +
        " pageParam:" +
        this.pageParam +
        " sortParam:" +
        this.sortParam
    );
    // Call the 'getCartItems' apex method imperatively
    getCartItems({
      communityId: communityId,
      effectiveAccountId: this.resolvedEffectiveAccountId,
      activeCartOrId: this.recordId,
      pageParam: this.pageParam,
      sortParam: this.sortParam
    })
      .then((result) => {
        console.log("result: " + JSON.stringify(result));
        this.getAvailability(result.cartItems);
        this.cartItems = result.cartItems;
        this._cartItemCount = Number(result.cartSummary.totalProductCount);
        this.currencyCode = result.cartSummary.currencyIsoCode;
        this.isCartDisabled = LOCKED_CART_STATUSES.has(
          result.cartSummary.status
        );
        this.processCoreItems(this.cartItems);
      })
      .catch((error) => {
        console.log(error);
        const errorMessage = error.body.message;
        this.cartItems = undefined;
        this.isCartClosed = isCartClosed(errorMessage);
      });
  }

  getAvailability(cartItems) {
    let productIds = [];
    cartItems.forEach((ci) => {
      productIds.push(ci.cartItem.productId);
    });
    getCartAvailability({
      productIds: productIds
    }).then((result) => {
      this.availabilityMap = result;
      console.log("availabilityMap: " + JSON.stringify(this.availabilityMap));
    });
  }

  processCoreItems() {
    var cartItemsByPartNumber = new Map();
    var corePartNumbers = new Set();

    this.cartItems.forEach((cartItemEntry) => {
      cartItemsByPartNumber.set(
        cartItemEntry.cartItem.productDetails.fields.NATT_P_N__c,
        cartItemEntry.cartItem
      );
    });

    this.cartItems.forEach((cartItemEntry) => {
      if (
        cartItemsByPartNumber.has(
          cartItemEntry.cartItem.productDetails.fields.NATT_CoreItem_P_N__c
        )
      ) {
        cartItemEntry.coreItem = cartItemsByPartNumber.get(
          cartItemEntry.cartItem.productDetails.fields.NATT_CoreItem_P_N__c
        );
        corePartNumbers.add(
          cartItemEntry.cartItem.productDetails.fields.NATT_CoreItem_P_N__c
        );
      }
    });

    this.cartItems.forEach((cartItemEntry, index, coreItems) => {
      if (
        corePartNumbers.has(
          cartItemEntry.cartItem.productDetails.fields.NATT_P_N__c
        )
      ) {
        coreItems.splice(index, 1);
      }
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
    /*
    // Update Cart Badge
    this.dispatchEvent(
      new CustomEvent(CART_CHANGED_EVT, {
        bubbles: true,
        composed: true
      })
    );
    // Notify any other listeners that the cart items have updated
    fireEvent(this.pageRef, CART_ITEMS_UPDATED_EVT);*/
    publish(this.messageContext, cartChanged);
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
    const { cartItemId, quantity, cartItemCoreId } = evt.detail;
    updateCartItem({
      communityId,
      effectiveAccountId: this.effectiveAccountId,
      activeCartOrId: this.recordId,
      cartItemId,
      cartItem: { quantity }
    })
      .then((cartItem) => {
        console.log('inside cart item');
        if (cartItemCoreId !== undefined) {
          console.log('has core item'+cartItemCoreId);
          updateCartItem({
            communityId,
            effectiveAccountId: this.effectiveAccountId,
            activeCartOrId: this.recordId,
            cartItemId: cartItemCoreId,
            cartItem: { quantity }
          }).catch((error) => {
            // Handle quantity update error properly
            // For this sample, we can just log the error
            console.log('updateCartItem:'+JSON.stringify(error));
          });
        }
        this.updateCartItemInformation(cartItem);
      })
      .catch((error) => {
        // Handle quantity update error properly
        // For this sample, we can just log the error
        console.log('natt_PpgCart.handleQuantityChange error:'+JSON.stringify(error));
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
  handleCartItemDelete(evt) {
    const { cartItemId, cartItemCoreId } = evt.detail;
    deleteCartItem({
      communityId,
      effectiveAccountId: this.effectiveAccountId,
      activeCartOrId: this.recordId,
      cartItemId
    })
      .then(() => {
        if (cartItemCoreId !== undefined) {
          deleteCartItem({
            communityId,
            effectiveAccountId: this.effectiveAccountId,
            activeCartOrId: this.recordId,
            cartItemId: cartItemCoreId
          }).catch((e) => {
            console.log(e);
          });
        }
        this.removeCartItem(cartItemId);
      })
      .catch((e) => {
        // Handle cart item delete error properly
        // For this sample, we can just log the error
        console.log(e);
      });
  }

  /**
   * Handler for the 'click' event fired from 'Clear Cart' button
   * We want to delete the current cart, create a new one,
   * and navigate to the newly created cart.
   *
   * @private
   */
  handleClearCartButtonClicked() {
    // Step 1: Delete the current cart
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

  /**
   * Given a cart id, navigate to the record page
   *
   * @private
   * @param{string} cartId - The id of the cart we want to navigate to
   */
  navigateToCart(cartId) {
    this[NavigationMixin.Navigate]({
      type: "standard__recordPage",
      attributes: {
        recordId: cartId,
        objectApiName: "WebCart",
        actionName: "view"
      }
    });
  }

  /**
   * Given a cartItem id, remove it from the current list of cart items.
   *
   * @private
   * @param{string} cartItemId - The id of the cart we want to navigate to
   */
  removeCartItem(cartItemId) {
    const removedItem = (this.cartItems || []).filter(
      (item) => item.cartItem.cartItemId === cartItemId
    )[0];
    const quantityOfRemovedItem = removedItem
      ? removedItem.cartItem.quantity
      : 0;
    const updatedCartItems = (this.cartItems || []).filter(
      (item) => item.cartItem.cartItemId !== cartItemId
    );
    // Update the cartItems with the change
    this.cartItems = updatedCartItems;
    // Update the Cart Header with the new count
    this._cartItemCount -= Number(quantityOfRemovedItem);
    // Update the cart badge and notify any other components interested in this change
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
      
      if (updatedItem.cartItem.cartItemId === cartItem.cartItemId) {
      
        updatedItem.cartItem = cartItem;
        // Returned cart item doesn't have Part Number so need to add
        // it back so that it's rendered correctly        
        updatedItem.cartItem.productDetails.fields.NATT_P_N__c = item.cartItem.productDetails.fields.NATT_P_N__c;        
        updatedItem.cartItem.productDetails.fields.QuantityUnitOfMeasure = item.cartItem.productDetails.fields.QuantityUnitOfMeasure;
        updatedItem.cartItem.productDetails.fields.NATT_UOM_Conversion__c = item.cartItem.productDetails.fields.NATT_UOM_Conversion__c;
        
        if (updatedItem.coreItem) {            
            updatedItem.coreItem.quantity = cartItem.quantity;
            updatedItem.coreItem.totalPrice =
            updatedItem.coreItem.unitAdjustedPrice * cartItem.quantity;
        }
      }
      count += Number(updatedItem.cartItem.quantity);      
      return updatedItem;
    });
    // Update the cartItems List with the change
    this.cartItems = updatedCartItems;
    // Update the Cart Header with the new count
    this._cartItemCount = count;
    // Update the cart badge and notify any components interested with this change
    this.handleCartUpdate();
  }
}