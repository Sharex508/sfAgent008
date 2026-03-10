import { LightningElement, api, wire } from "lwc";
import { NavigationMixin } from "lightning/navigation";
import fetchAccountDetails from '@salesforce/apex/NATT_AccountInformationHelper.grabEffectiveAccount';

/**Custom Label Imports */
import AccountNameLabel from '@salesforce/label/c.NATT_Account_Details_Account_Name';
import AccountDetailsLabel from '@salesforce/label/c.NATT_Account_Details_Account_Details';
import DivisionLabel from '@salesforce/label/c.NATT_Account_Details_Division';
import DealerPrincipalLabel from '@salesforce/label/c.NATT_Account_Details_Dealer_Principal';
import DealerPrincipalEmailLabel from '@salesforce/label/c.NATT_Account_Details_Dealer_Principal_Email';
import PhysicalAddressLabel from '@salesforce/label/c.NATT_Account_Details_Physical_Address';
import MailingAddressLabel from '@salesforce/label/c.NATT_Account_Details_Mailing_Address';
import JDEPartsBillToCodeLabel from '@salesforce/label/c.NATT_Account_Details_JDE_Parts_Bill_to_Code';
import PrimaryLocationType from '@salesforce/label/c.NATT_Account_Details_Primary_Location_Type';

export default class Natt_accountinformation_address extends NavigationMixin(LightningElement) {
    //Custom Label Creation
    label = {
        AccountNameLabel,
        AccountDetailsLabel,
        DivisionLabel,
        DealerPrincipalLabel,
        DealerPrincipalEmailLabel,
        PhysicalAddressLabel,
        MailingAddressLabel,
        JDEPartsBillToCodeLabel,
        PrimaryLocationType
    };
    
    @api objectApiName;
    currentUserId;
    currentAccountId;
    dealerPrincipalEmail;
    error;
    hasLoaded=false;

    @api
    get effectiveAccountId() {
      return this._effectiveAccountId;
    }

    set effectiveAccountId(value) {
      this._effectiveAccountId = value;
    }

    connectedCallback() {
      console.log('start');
      console.log('Effective Acct Id check: ' + this._effectiveAccountId);
      fetchAccountDetails({acctId:this._effectiveAccountId})
        .then(result => {
          console.log('Queried Result: ' + JSON.stringify(result));      
          this.accountName = result.Name;       
          console.log('Name: ' + this.accountName); 
          this.dealerPrincipalEmail = result.NATT_Dealer_Principal__r?.Email; 
          if(this.dealerPrincipalEmail == null || this.dealerPrincipalEmail == ''){
            this.dealerPrincipalEmail = '_';
          }           
          this.accountId = result.Id;
          this.hasLoaded=true;
          console.log('end of assignment');
        })
        .catch(error => {
          console.log('price file failed to load: ' + error.body.message);
          this.error = error;
        })
    }
}