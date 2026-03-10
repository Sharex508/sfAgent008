import { LightningElement ,api, wire, track} from 'lwc';
import getQuoteSummary from '@salesforce/apex/CONTAINER_Quote_Summary_Page_Helper.getQuoteSummary';

export default class CONTAINER_Quote_Summary_Page extends LightningElement {
    @api recordId;
    @track columns = [{
        label: 'Product Description',
        fieldName: 'Product_Description',
        type: 'text',
        sortable: true
        },
        {
        label: 'Net Unit Price',
        fieldName: 'Net_Unit_Price',
        type: "text",
        cellAttributes: { alignment: 'left' },
        sortable: true
        },
    ];
 
    @track error;
    @track qLineItemList ;
    @wire(getQuoteSummary, {recId: '$recordId'})
    wiredAccounts({
        error,
        data
    }) {
        if (data) {
            this.qLineItemList = data;
        } else if (error) {
            this.error = error;
        }
    }
}