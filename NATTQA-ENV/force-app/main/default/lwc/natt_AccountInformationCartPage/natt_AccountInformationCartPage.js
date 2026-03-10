import { LightningElement ,api, wire, track} from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import getCartList from '@salesforce/apex/Natt_AccountInformationCartPageHandler.getCartList';
import makePrimary from '@salesforce/apex/Natt_AccountInformationCartPageHandler.makePrimary';
import newCart from '@salesforce/apex/Natt_AccountInformationCartPageHandler.newCartApi';
import checkoutCartCheck from '@salesforce/apex/Natt_AccountInformationCartPageHandler.checkForCheckoutCart';
import UserId from '@salesforce/user/Id';
import CommunityId from "@salesforce/community/Id";
import getUserAccount from "@salesforce/apex/B2BUtils.getUserAccount";
import deleteCart from '@salesforce/apex/Natt_AccountInformationCartPageHandler.deleteCarts';
import renameCart from '@salesforce/apex/Natt_AccountInformationCartPageHandler.renameCarts';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
/**Custom Label Imports */
import CartNameLabel from '@salesforce/label/c.NATT_Carts_Cart_Name';
import CartItemsLabel from '@salesforce/label/c.NATT_Carts_Cart_Items';
import TotalAmountLabel from '@salesforce/label/c.NATT_Carts_Total_Amount';
import PrimaryLabel from '@salesforce/label/c.NATT_Carts_Primary';
import LastModifiedLabel from '@salesforce/label/c.NATT_Carts_Last_Modified';
import StatusLabel from '@salesforce/label/c.NATT_Carts_Status';
import RenameCartLabel from '@salesforce/label/c.NATT_Carts_Rename_Cart';
import MakePrimaryLabel from '@salesforce/label/c.NATT_Carts_Make_Primary';
import DeleteCartLabel from '@salesforce/label/c.NATT_Carts_Delete_Cart';
import CartsTitleLabel from '@salesforce/label/c.NATT_Carts_Carts_Title';
import CreateNewCartLabel from '@salesforce/label/c.NATT_Carts_Create_New_Cart';
import SaveCurrentCartLabel from '@salesforce/label/c.NATT_Carts_Save_your_Current_Cart_Create_a_New_Cart';
import SaveAndCreateNewCartLabel from '@salesforce/label/c.NATT_Carts_Save_Create_New_Cart';
import EnterANameLabel from '@salesforce/label/c.NATT_Carts_Enter_a_Name';
import CancelLabel from '@salesforce/label/c.NATT_Carts_Cancel';
import DeleteLabel from '@salesforce/label/c.NATT_Carts_Delete';
import CannotDeletePrimaryCartLabel from '@salesforce/label/c.NATT_Carts_Cannot_delete_a_primary_cart';
import CannotMakeSelectedCartPrimaryLabel from '@salesforce/label/c.NATT_Carts_Cannot_Make_Selected_Cart_Primary';
import FailedToDeleteCartLabel from '@salesforce/label/c.NATT_Carts_Failed_to_Delete_Cart';
import CompleteCheckoutProcessLabel from '@salesforce/label/c.NATT_Carts_Complete_Checkout_Process';
import SelectedCartAlreadyPrimaryLabel from '@salesforce/label/c.NATT_Carts_The_selected_cart_is_already_the_primary_cart';
import ThereIsACartInCheckoutProcessLabel from '@salesforce/label/c.NATT_Carts_There_is_a_cart_in_the_checkout_process';
import SaveLabel from '@salesforce/label/c.NATT_Carts_Save';
import CloseLabel from '@salesforce/label/c.NATT_Carts_Close';
import PleaseEnterNameLabel from '@salesforce/label/c.NATT_Carts_Please';
import FailedToCreateCartLabel from '@salesforce/label/c.NATT_Carts_Failed_to_Create_a_New_Cart';
import EnterANewNameLabel from '@salesforce/label/c.NATT_Carts_Enter_a_New_Name_Below';

// import USER_ID from '@salesforce/schema/Account.Id';
const actions = [
    { label: RenameCartLabel, name: 'RenameCart' },
    { label: MakePrimaryLabel, name: 'MakePrimary' },
    { label: DeleteCartLabel, name: 'DeleteCart' },
];
export default class Natt_AccountInformationCartPage extends LightningElement {
    //Custom Label for Translations
    label = {
        CartsTitleLabel,
        CreateNewCartLabel,
        SaveCurrentCartLabel,
        SaveAndCreateNewCartLabel,
        EnterANameLabel,
        CancelLabel,
        DeleteLabel,
        CannotDeletePrimaryCartLabel,
        CannotMakeSelectedCartPrimaryLabel,
        FailedToDeleteCartLabel,
        CompleteCheckoutProcessLabel,
        SelectedCartAlreadyPrimaryLabel,
        ThereIsACartInCheckoutProcessLabel,
        CartNameLabel,
        SaveLabel,
        CloseLabel,
        PleaseEnterNameLabel,
        FailedToCreateCartLabel,
        EnterANewNameLabel,
        RenameCartLabel
    };

    @api recordId;
    @wire(getUserAccount)
    cartNameValue;
    cartRenameValue;
    primaryCartName;
    _userInfo;
    isPrimary;
    cartIdForRename;
    //variable for error toast (ex. cannot delete primary cart)
    _title = FailedToDeleteCartLabel;
    message = CannotDeletePrimaryCartLabel;
    variant = 'error';

    //variable for warning toast (ex. cart already primary)
    _titlePrimary = CannotMakeSelectedCartPrimaryLabel;
    messagePrimary = SelectedCartAlreadyPrimaryLabel;
    variantPrimary = 'warning';

    //variables for warning toast - checkout (ex. cart already primary)
    _titleCheckout = CompleteCheckoutProcessLabel;
    messageCheckout = ThereIsACartInCheckoutProcessLabel;
    variantPrimary = 'warning';
    @track isloading = false;

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
    
    @track columns = [
    {
        label: CartNameLabel,
        fieldName: 'Name',
        type: 'text'
    },
    {
        label: CartItemsLabel,
        fieldName: 'TotalProductCount',
        type: 'number',
        cellAttributes: { alignment: 'left' },
    },
    {
        label: TotalAmountLabel,
        fieldName: 'TotalAmount',
        type: 'currency',
        cellAttributes: { alignment: 'left' },
    },
    {
        label: PrimaryLabel,
        fieldName: 'NATT_Is_Cart_Primary__c',
        type: 'boolean'
    },
    {
        label: LastModifiedLabel,
        fieldName: 'LastModifiedDate',
        type: 'date',
        typeAttributes:{
            year: "numeric",
            month: "long",
            day: "2-digit",
            hour: "2-digit",
            minute: "2-digit"
        }
    },
    {
        label: StatusLabel,
        fieldName: 'NATT_Translated_Status__c',
        type: 'Text'
    },
    {
        type: 'action',
        typeAttributes: { rowActions: actions },
    },
    ];

    @track error;
    @track cartList ;
    @track isCheckout = false;
    connectedCallback(){
        console.log('Effective Account ID: ' + this._effectiveAccountId);
        console.log('UserID: ' + UserId);
        getCartList( {UserId:UserId, CommunityId:CommunityId, EffectiveAccountId:this._effectiveAccountId})
            .then(result => {
                console.log('getCartList Success');
                this.cartList = result;
                result.forEach(WebCart => {
                    if (WebCart.NATT_Is_Cart_Primary__c == true){
                        this.primaryCartName = WebCart.Name;
                    }
                    // WebCart.Status = 'Active';
                });
                this.error = undefined;
            })
            .catch(error => {
                console.log('Change FAILED: ' + error.body.message);
                this.error = error;
                this.accounts = undefined;
            })

        checkoutCartCheck({UserId:UserId, CommunityId:CommunityId})
            .then(result =>{
                if (result == true){
                    console.log('THERE IS A CHECKOUT CART');
                    this.isCheckout = true;
                }else{
                }
            })  
    }
    callRowAction(event ) {   
        const recId =  event.detail.row.Id;  
        const isPrimary = event.detail.row.NATT_Is_Cart_Primary__c;
        this.cartRenameValue = event.detail.row.Name;
        const actionName = event.detail.action.name; 
        
        if ( actionName === 'MakePrimary' ) {  
           if(this.isCheckout == true){
                const evt = new ShowToastEvent({
                    title: this._titleCheckout,
                    message: this.messageCheckout,
                    variant: this.variantPrimary,
                });
                this.dispatchEvent(evt);
                return;
           }
            if(isPrimary == true){
                const evt = new ShowToastEvent({
                    title: this._titlePrimary,
                    message: this.messagePrimary,
                    variant: this.variantPrimary,
                });
                this.dispatchEvent(evt);
                return;
            }
            
            makePrimary({WebCartId: recId, UserId:UserId, CommunityId : CommunityId, EffectiveAccountId:this._effectiveAccountId})
            .then(result => {
                console.log('Change Success');
                this.cartList = result;
                window.location.reload();
                this.isloading = true;
            })
            .catch(error => {
                console.log('Change FAILED: ' + error.body.message);
                this.error = error;
                this.accounts = undefined;

            })
            
        } else if (actionName == 'DeleteCart'){
            if(isPrimary == true){
                const evt = new ShowToastEvent({
                    title: this._title,
                    message: this.message,
                    variant: this.variant,
                });
                this.dispatchEvent(evt);
                return;
            }
            deleteCart({WebCartId: recId, UserId:UserId, EffectiveAccountId:this._effectiveAccountId})
            .then(result => {
                this.cartList = result;
                this.error = undefined;
                window.location.reload();
                this.isloading = true;
            })
            .catch(error => {
                console.log('Delete FAILED: ' + error.body.message);
                this.error = error;
                this.accounts = undefined;

            })
        } else if (actionName == 'RenameCart'){
            this.cartIdForRename = recId,
            this.isRenameModalOpen = true;
        }
    }

    handleClick(){
        var inp = this.template.querySelector("lightning-input");
        if(this.isCheckout == true){
            const evt = new ShowToastEvent({
                title: this._titleCheckout,
                message: this.messageCheckout,
                variant: this.variantPrimary,
            });
            this.dispatchEvent(evt);
            return;
       }
        console.log('inp value: ' + inp.value); 
        if(inp.value == null || inp.value == ''){
            console.log('No New');
            const evt = new ShowToastEvent({
                title: FailedToCreateCartLabel,
                message: PleaseEnterNameLabel,
                variant: this.variant,
            });
            this.dispatchEvent(evt);
            return;
        }

        

        console.log('comunity value: ' + CommunityId);
        newCart({UserId : UserId, CartName :  inp.value, CommunityId : CommunityId, EffectiveAccountId: this._effectiveAccountId})
        .then(result => {
            console.log('New Cart Created');
            this.isModalOpen = false;
            this.cartList = result;
            window.location.reload();
            this.isloading = true;
        })
        .catch(error => {
            console.log('Cart Creation Failure: ' + error.body.message);
            this.error = error;
            this.accounts = undefined;
        })
    }

    handleRename(){
        var renameInp = this.template.querySelector("lightning-input");
        console.log('Cart Rename: ' + renameInp.value);
        // console.log('Cart Id: ' + cartIdForRename);
        renameCart({WebCartId: this.cartIdForRename, UserId : UserId, newName :  renameInp.value, EffectiveAccountId:this._effectiveAccountId})
        .then(result => {
            console.log('Renamed Cart');
            this.isModalOpen = false;
            this.cartList = result;
            console.log('result');
            this.isRenameModalOpen = false;
            window.location.reload();
            this.isloading = true;
        })
        .catch(error => {
            console.log('Cart Creation Failure: ' + error.body.message);
            this.error = error;
        })
    }


    @track isRenameModalOpen = false;
    openRenameModal() {
        // Opens Rename Cart Modal
        this.isRenameModalOpen = true;
    }
    closeRenameModal() {
        // to close Rename Cart modal set isRenameModalOpen tarck value as false
        this.isRenameModalOpen = false;
    }

    @track isModalOpen = false;
    openModal() {
        // Opens Create New Cart Modal
        console.log('Cart Name Value: ' + this.primaryCartName);
        this.cartNameValue = this.primaryCartName;
        this.isModalOpen = true;
    }
    closeModal() {
        // to close Create New Cart modal set isModalOpen tarck value as false
        this.isModalOpen = false;
    }

}