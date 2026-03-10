import { LightningElement,api, wire, track } from 'lwc';
import newCartCreate from '@salesforce/apex/NATT_TesCartPageHandler.newCartApi';
// import getCartItems from "@salesforce/apex/NATT_TesCartPageHandler.getCartItems";
import CommunityId from "@salesforce/community/Id";
import UserId from '@salesforce/user/Id';
import { NavigationMixin } from 'lightning/navigation';
import { isCartClosed } from "c/natt_cartUtils";
import {
    publish,
    MessageContext
   } from "lightning/messageService";
import cartChanged from "@salesforce/messageChannel/lightning__commerce_cartChanged";


export default class Natt_TesNewCartButton extends NavigationMixin (LightningElement){

//       /**
//    * Gets the normalized effective account of the user.
//    *
//    * @type {string}
//    * @readonly
//    * @private
//    */
//   get resolvedEffectiveAccountId() {
//     const effectiveAccountId = this.effectiveAccountId || "";
//     let resolved = null;
//     if (
//       effectiveAccountId.length > 0 &&
//       effectiveAccountId !== "000000000000000"
//     ) {
//       resolved = effectiveAccountId;
//     }
//     return resolved;
//   }

//   /**
//    * Specifies the page token to be used to view a page of cart information.
//    * If the pageParam is null, the first page is returned.
//    * @type {null|string}
//    */
//    pageParam = null;

//      /**
//    * Sort order for items in a cart.
//    * The default sortOrder is 'CreatedDateAsc'
//    *    - CreatedDateAsc—Sorts by oldest creation date
//    *    - CreatedDateDesc—Sorts by most recent creation date.
//    *    - NameAsc—Sorts by name in ascending alphabetical order (A–Z).
//    *    - NameDesc—Sorts by name in descending alphabetical order (Z–A).
//    * @type {string}
//    */
//   sortParam = "CreatedDateAsc";

//     /**
//    * Is the cart currently disabled.
//    * This is useful to prevent any cart operation for certain cases -
//    * For example when checkout is in progress.
//    * @type {boolean}
//    */
//      isCartClosed = false;

    @track error;
    @track cartList ;
    @track newCartId;
    @track isloading = false;
    @wire(MessageContext)
    messageContext;
    handleClick(event) {
        // console.log('Handle Click Event');
        // var inp = this.template.querySelector("lightning-input");
        // console.log('inp value: ' + inp.value);
        // newCartCreate({UserId : UserId, CartName :  inp.value, CommunityId:CommunityId})
        // .then(result => {
        //     console.log('New Cart Created');
        //     this.isModalOpen = false;
        //     this.cartList = result;
            
            this[NavigationMixin.Navigate]({
                type: 'standard__webPage',
                attributes: {
                    url: '/tes/s/comm-my-account?tabset-90c5b=7e475'
                }
            });
            this.isloading = true;
            // window.location.reload();
        // })
        // .catch(error => {
        //     console.log('Cart Creation Failure: ' + error.body.message);
        //     this.error = error;
        //     this.accounts = undefined;
        // })
    }
    navigateToCarts(event) {
        this[NavigationMixin.Navigate]({
            type: 'standard__webPage',
            attributes: {
                url: '/tes/s/comm-my-account?tabset-90c5b=7e475'
            }
        });
        // this.isloading = true;
    }
     
    newCart(event) {
        console.log('Handle Click Event');
        this.isloading = true;
        var inp = this.template.querySelector("lightning-input");
        console.log('inp value: ' + inp.value);
         newCartCreate({UserId : UserId, CartName :  inp.value, CommunityId:CommunityId})
        .then(result => {
            // this.isloading = true;
            console.log('New Cart Created: ' + result);
            this.isModalOpen = false;
            this.newCartId = result;
            console.log('newCartId: ' + this.newCartId );

            this[NavigationMixin.Navigate]({
                type: 'standard__webPage',
                attributes: {
                    url: '/tes/s/cart/' + this.newCartId
                }
            });
            console.log('after nav');

            publish(this.messageContext, cartChanged);

            console.log('after add');
            // window.location.reload();
            // console.log('after reload');
            // this.updateCartItems();
         })
        .catch(error => {
            console.log('Cart Creation Failure: ' + error.body.message);
            this.error = error;
            this.accounts = undefined;
        })
    }

    // updateCartItems() {
    //     //this.recordId='0a6P0000000CatkIAC';
    //     //this.effectiveAccountId='001P000001oRGnlIAG';
    //     console.log('update Cart Items START');
    //     console.log(
    //       "called communityId:" +
    //       CommunityId +
    //         " effAccountId:" +
    //         this.resolvedEffectiveAccountId +
    //         " cart:" +
    //         this.recordId +
    //         " pageParam:" +
    //         this.pageParam +
    //         " sortParam:" +
    //         this.sortParam
    //     );
    //     // Call the 'getCartItems' apex method imperatively
    //     getCartItems({
    //       communityId: CommunityId,
    //       effectiveAccountId: this.resolvedEffectiveAccountId,
    //       activeCartOrId: this.recordId,
    //       pageParam: this.pageParam,
    //       sortParam: this.sortParam
    //     })
    //       .then((result) => {
    //         console.log("result: " + JSON.stringify(result));
    //         this.getAvailability(result.cartItems);
    //         this.cartItems = result.cartItems;
    //         this._cartItemCount = Number(result.cartSummary.totalProductCount);
    //         this.currencyCode = result.cartSummary.currencyIsoCode;
    //         this.isCartDisabled = LOCKED_CART_STATUSES.has(
    //           result.cartSummary.status
    //         );
    //         this.processCoreItems(this.cartItems);
    //       })
    //       .catch((error) => {
    //         console.log(error);
    //         const errorMessage = error.body.message;
    //         this.cartItems = undefined;
    //         this.isCartClosed = isCartClosed(errorMessage);
    //       });
    //   }
    

    @track isModalOpen = false;
    openModal() {
        // to open modal set isModalOpen tarck value as true
        this.isModalOpen = true;
    }
    closeModal() {
        // to close modal set isModalOpen tarck value as false
        this.isModalOpen = false;
    }

}