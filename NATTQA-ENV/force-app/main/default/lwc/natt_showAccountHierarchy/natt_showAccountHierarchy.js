import { LightningElement, api, track, wire } from 'lwc';
import getAccountHierarchy from '@salesforce/apex/NATT_ShowAccountHierarchyController.getAccountHierarchy';
import getNewChildren from '@salesforce/apex/NATT_ShowAccountHierarchyController.getNewChildren';

export default class Natt_showAccountHierarchy extends LightningElement {

    @track showSpinner = true;
    @track gridExpandedRows = [];
    @track showData = false;

    @api recordId;

    gridColumns = [
        {
            type: 'url',
            fieldName: 'url',
            label: 'Account Name',
            initialWidth: 300,
            typeAttributes: {
                label: { fieldName: 'name' },
            },
            cellAttributes: {                
                iconName: {fieldName: 'iconName'},
                iconPosition: 'left'       
            }
        },
        {
            type: 'text',
            fieldName: 'cityState',
            label: 'City/State'
        },        
        {
            type: 'text',
            fieldName: 'primaryLocationType',
            label: 'Primary Location Type'
        },
        {
            type: 'text',
            fieldName: 'status',
            label: 'Status'
        }
    ];

    gridData;

    gridLoadingState = false;

    connectedCallback() {
        getAccountHierarchy({recordId: this.recordId})
            .then(result => {
                console.log(result.data);
                this.showData = result.data.length > 0 ? true : false;
                this.gridData = JSON.parse(JSON.stringify(result.data).replaceAll('ltChildren', '_children'));
                this.gridExpandedRows = result.ltExpandedRows;

                this.showSpinner = false;
            })
            .catch(error => {
                console.log('error is: ' + JSON.stringify(error));                
                this.showSpinner = false;
            });
    }

    handleRowToggle(event) {
        const rowName = event.detail.name;
        
        if (event.detail.row.position === 'below') {
            this.gridLoadingState = true;
            getNewChildren({accountName: rowName}).then(result => {
                this.gridData = this.addChildrenToRow(this.gridData, rowName, result.data[rowName]);
                
                this.gridLoadingState = false;
            });
        }

    }

    // add the new child rows at the desired location
    addChildrenToRow(data, rowName, children) {
        const newData = data.map(row => {
            let hasChildrenContent = false;

            if (
                row.hasOwnProperty('_children') &&
                Array.isArray(row._children) &&
                row._children.length > 0
            ) {
                hasChildrenContent = true;
            }

            if (row.name === rowName) {
                row._children = JSON.parse(JSON.stringify(children).replaceAll('ltChildren', '_children'));
            } else if (hasChildrenContent) {
                this.addChildrenToRow(row._children, rowName, children);
            }

            return row;
        });

        return newData;
    }

    checkPositionValue(data, rowName, children) {
        const newData = data.map(row => {
            let hasChildrenContent = false;

            if (
                row.hasOwnProperty('_children') &&
                Array.isArray(row._children) &&
                row._children.length > 0
            ) {
                hasChildrenContent = true;
            }

            if (row.name === rowName) {
                return row;
            } else if (hasChildrenContent) {
                this.checkPositionValue(row._children, rowName, children);
            }

        });

        return newData;
    }

}