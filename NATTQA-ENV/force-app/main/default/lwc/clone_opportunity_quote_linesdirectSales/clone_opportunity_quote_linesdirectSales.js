import { LightningElement, wire, api, track } from 'lwc';
import { CurrentPageReference } from 'lightning/navigation';
import cloneOpportunityWithQuote from '@salesforce/apex/CloneOpportunityQuoteDirectSales.cloneOpportunityWithQuote';
import isQuoteApproved from '@salesforce/apex/CloneOpportunityQuoteDirectSales.isQuoteApproved';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { CloseActionScreenEvent } from 'lightning/actions';
import { NavigationMixin } from 'lightning/navigation';
import DIRECT_SALES_ALLOWED_STAGES from '@salesforce/label/c.DirectSalesAllowedOppStages';

export default class CloneDirectSaleQuote extends NavigationMixin(LightningElement) {
    @api recordId; // Opportunity Id (source)
    @track isLoading = false;
    @track isApproved = false;
    @track checked = false;
    label = {DIRECT_SALES_ALLOWED_STAGES};
    @wire(CurrentPageReference)
    getPageReference(pageRef) {
        if (!this.recordId) {
            this.recordId = pageRef?.state?.recordId;
        }
         if (this.recordId) {
            this.checkApproval();
        }
    }
    async checkApproval() {
        try {
            this.isLoading = true;
             const now = new Date();
            this.lastCheckedTime = now.toLocaleString();
            // Convert JS time → Apex Datetime format
            const apexFormattedTime = now.toISOString(); 
            this.isApproved = await isQuoteApproved({ opportunityId: this.recordId,clientTime: apexFormattedTime });
            this.checked = true;
        } catch (error) {
            this.toast('Error', 'Unable to check quote approval status.', 'error');
            console.error(error);
        } finally {
            this.isLoading = false;
        }
    }

    async handleClone() {
        if (!this.recordId) {
            this.toast('Error', 'Record ID not found in URL.', 'error');
            return;
        }

        try {
            this.isLoading = true;

            const result = await cloneOpportunityWithQuote({ opportunityId: this.recordId });

            // result: { success, message, newOpportunityId, newQuoteId, newQLICount }
            if (result?.success) {
                this.toast('Success', result.message || 'Cloned successfully.', 'success');

                // If a new Quote exists, navigate to it; else to the new Opportunity
                const targetId = result.newQuoteId || result.newOpportunityId;
                if (targetId) {
                    this[NavigationMixin.Navigate]({
                        type: 'standard__recordPage',
                        attributes: {
                            recordId: targetId,
                            actionName: 'view'
                        }
                    });
                }

                this.closeQuickAction();
            } else {
                this.toast('Error', result?.message || 'Cloning failed.', 'error');
            }
        } catch (error) {
            // Friendly error parsing
            let message = 'An unknown error occurred.';
            if (error?.body?.message) {
                message = error.body.message;
            } else if (error?.message) {
                message = error.message;
            }
            this.toast('Error', message, 'error');
            // console for admins
            // eslint-disable-next-line no-console
            console.error('Clone error:', JSON.stringify(error));
        } finally {
            this.isLoading = false;
        }
    }

    closeQuickAction() {
        this.dispatchEvent(new CloseActionScreenEvent());
    }

    toast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
    get errorMessage() {
        return `⚠️ Can be cloned only from the source Opportunity at ${this.label.DIRECT_SALES_ALLOWED_STAGES} stage.`;
    }
}