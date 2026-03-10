import { LightningElement ,api, wire, track} from 'lwc';
import getFieldHistoryList from '@salesforce/apex/Dynamic_DataTable_Helper.getFieldHistoryList';
export default class LightningDatatableLWCExample extends LightningElement {
    @api recordId;
    @track columns = [{
            label: 'CreatedDate',
            fieldName: 'CreatedDate',
            type: "date",
            typeAttributes:{
                year: "numeric",
                month: "long",
                day: "2-digit",
                hour: "2-digit",
                minute: "2-digit"
            },
            sortable: true
        },
        {
            label: 'Field',
            fieldName: 'fieldLabel',
            type: 'text',
            sortable: true
        },
        {
            label: 'User',
            fieldName: 'User',
            type: 'text',
            sortable: true
        },
        {
            label: 'Original Value',
            fieldName: 'OldValue',
            type: 'text',
            sortable: true
        },
        {
            label: 'New Value',
            fieldName: 'NewValue',
            type: 'text',
            sortable: true
        }
        
    ];
 
    @track error;
    @track accList ;
    @wire(getFieldHistoryList, {recId: '$recordId'})
    wiredAccounts({
        error,
        data
    }) {
        if (data) {
            this.accList = data;
        } else if (error) {
            this.error = error;
        }
    }
}