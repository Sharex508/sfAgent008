import { LightningElement, wire, track } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import fetchListCatalog from '@salesforce/apex/NAC_B2BGetInfoController.fetchListCatalog';
import fetchPriceBookGuideData from '@salesforce/apex/NAC_B2BGetInfoController.fetchPriceBookGuideData';
import fetchPriceListChangeData from '@salesforce/apex/NAC_B2BGetInfoController.fetchPriceListChangeData';
import SelectFileLabel from '@salesforce/label/c.nac_SelectFileLabel';
import DownloadGlobalPBLabel from '@salesforce/label/c.nac_DownloadGlobalPBLabel';
import DownloadCSVLabel from '@salesforce/label/c.nac_DownloadCSVLabel';
import DownloadPDFLabel from '@salesforce/label/c.nac_DownloadPDFLabel';
import DownloadPBLabel from '@salesforce/label/c.nac_DownloadPBLabel';
import descriptionTextLabel from '@salesforce/label/c.nac_CatalogDownload';
import staticResourcelabelName from '@salesforce/label/c.NAOCAP_Price_Book_Guide_Static_resource_name';
import pdfDownloadURL from '@salesforce/label/c.NAOCAP_Downlaod_PriceBook_PDF_URL';
import { getRecord } from 'lightning/uiRecordApi';
import USER_ID from '@salesforce/user/Id';
import USERTYPE from '@salesforce/schema/User.UserType';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
/*Added by Khushmeet*/
import UCPREGION_FIELD from '@salesforce/schema/User.UCP_Region__c';

const staticResourceName = 'NAC_Terms_and_conditions';




export default class CatalogDownload extends NavigationMixin(LightningElement) {
    @track pData = {};
    @track changePriceData = {};
    @track counterPrice = 0;
    @track errorcountPrice = 0;
    columnHeader = ['Part Number', 'Description', 'Pkg', 'Supersedure', 'Price ', 'Each Price', 'Exch/Core', 'Core Reference#', 'Core List Price', 'Total List Price W/Core', 'SignalCode', 'Line Of Business', 'Weight', 'Length', 'Width', 'Height', 'COO', 'HTSUS'];
   // columnHeaderChangePricing = ['Part Number', 'New Price', 'Old Price', 'Date of Change', 'Description', 'PKG', 'Supersedure', 'Price ', 'Each_price', 'EXCH/CORE', 'CORE REFRENCE#', 'CORE LIST PRICE', 'TOTAL LIST PRICE W/CORE', 'SignalCode', 'Line Of Business', 'Weight', 'Length', 'Width', 'Height', 'COO', 'HTSUS'];
   columnHeaderChangePricing = ['Part Number', 'Description', 'Pkg', 'Supersedure', 'Price ','Each Price', 'Exch/Core', 'Core Reference#', 'Core List Price', 'Total List Price W/Core', 'SignalCode', 'Line Of Business', 'Weight', 'Length', 'Width', 'Height', 'COO', 'HTSUS','Date of Change'];
   @track counter = 0;
    @track errorcount = 0;
    @track isCartItemListIndeterminate;
    showSpinner = false;
    sfUserType;
    ucpRegion;
    @wire(fetchListCatalog)
    wiredData({ error, data }) {
        this.showSpinner = true;
        try {
            if (data) {
                this.pData = data;
                this.showSpinner = false;
            } else if (error) {
                console.error('Error:', error);
            }
        }
        catch (err) {
            console.log('Error ' + err);
        }
    }
    @wire(getRecord, { recordId: USER_ID, fields: [USERTYPE,UCPREGION_FIELD] })
    userDetails({ error, data }) {
        if (data) {
            this.sfUserType = data.fields.UserType.value;
            this.ucpRegion = data.fields.UCP_Region__c.value;
            console.log(JSON.stringify(this.ucpRegion));
        }
    }
    label = {
        SelectFileLabel,
        DownloadGlobalPBLabel,
        DownloadCSVLabel,
        DownloadPDFLabel,
        DownloadPBLabel,
        descriptionTextLabel
    }

    connectedCallback() {
        // CXREF 3819 : Changes Starts
        this.exportPriceBookGuideData();
        // CXREF 3819 : Changes Ends
    }

    exportProductData() {
        let yourDate = new Date()
        yourDate.toISOString().split('T')[0];
        const offset = yourDate.getTimezoneOffset();
        yourDate = new Date(yourDate.getTime() - (offset * 60 * 1000));
        let splityourDate = yourDate.toISOString().split('T')[0];
        let doc = '<table>';
        // Add styles for the table
        doc += '<style>';
        doc += 'table, th, td {';
        doc += '    border: 1px solid black;';
        doc += '    border-collapse: collapse;';
        doc += '}';
        doc += '</style>';
        // Add all the Table Headers
        doc += '<tr>';
        this.columnHeader.forEach(element => {
            doc += '<th>' + element + '</th>'
        });
        doc += '</tr>'
        try {
            this.pData.forEach(record => {
                this.counter = this.counter + 1;
                doc += '<tr>';
                doc += '<td>' + record.PartNumber + '</td>';
                doc += '<td>' + record.Description + '</td>';
                doc += '<td>' + record.PKG + '</td>';
                doc += '<td>' + record.Superseded + '</td>';
                if(record.Price > 0){
                    doc += '<td>' + parseFloat(record.Price).toFixed(2) + '</td>';
                }else{
                    doc += '<td>' + record.Price + '</td>';
                }
                if(record.Each_price > 0){
                    doc += '<td>' + parseFloat(record.Each_price).toFixed(2) + '</td>';
                }else{
                    doc += '<td>' + record.Each_price + '</td>';
                }                
                doc += '<td>' + record.EXCH_CORE + '</td>';
                doc += '<td>' + record.core_Reference + '</td>';
                if(record.coreListPrice > 0){
                    doc += '<td>' + parseFloat(record.coreListPrice).toFixed(2) + '</td>';
                }else{
                    doc += '<td>' + record.coreListPrice + '</td>';
                }                
                if (record.totalproductPrice) {
                    doc += '<td>' + parseFloat(record.totalproductPrice).toFixed(2) + '</td>';
                } else {
                    doc += '<td></td>';
                }               
                doc += '<td>' + record.SignalCode + '</td>';
                doc += '<td>' + record.lineOfBusiness + '</td>';
                doc += '<td>' + record.Weight + '</td>';
                doc += '<td>' + record.Length + '</td>';
                doc += '<td>' + record.Width + '</td>';
                doc += '<td>' + record.Height + '</td>';
                doc += '<td>' + record.COO + '</td>';
                doc += '<td>' + record.HTSUS + '</td>';
                doc += '</tr>';
            });
        } catch (err) {
            this.errorcount = this.errorcount + 1;
            console.log('Error ' + err);
        }
        var element = 'data:application/vnd.ms-excel,' + encodeURIComponent(doc);
        let downloadElement = document.createElement('a');
        downloadElement.href = element;
        downloadElement.target = '_self';
        // use .csv as extension on below line if you want to export data as csv
        downloadElement.download = 'Container List Price Book' + ' ' + splityourDate + '.xls';
        //downloadElement.download = 'Container List Price Book';
        document.body.appendChild(downloadElement);
        downloadElement.click();
    }

    redirectVf() {

        let urlToNavigate;

        if (this.sfUserType === 'Standard') {
            urlToNavigate = '/apex/NAC_CatalogPDFGenerator';
        } else if (this.ucpRegion === 'Americas') {
            urlToNavigate = pdfDownloadURL;
        } else if (this.ucpRegion) {
            urlToNavigate = '/NAContainersMarketplace/apex/NAC_CatalogPDFGenerator';
        } else {
            urlToNavigate = pdfDownloadURL;
        }
        
        this[NavigationMixin.GenerateUrl || NavigationMixin.Navigate]({
            type: 'standard__webPage',
            attributes: { url: urlToNavigate }
        }).then(generatedUrl => {
            if (generatedUrl) window.open(generatedUrl);
        });
        
    }

    exportProducPriceChangeData() {
        this.showSpinner = true;
        fetchPriceListChangeData()
            .then(result => {
                this.showSpinner = false;
                this.changePriceData = result;
                if (this.changePriceData.length > 0) {
                    this.prepareCSVProductPriceChange();
                    this.dispatchEvent(
                        new ShowToastEvent({
                            title: 'Success',
                            message: 'The Container Price Change File is succesfully downloaded!',
                            variant: 'success',
                            mode: 'dismissable'
                        })
                    );
                } else {
                    this.dispatchEvent(
                        new ShowToastEvent({
                            title: 'Error',
                            message: 'Price change data is not available.',
                            variant: 'error',
                            mode: 'dismissable'
                        })
                    );

                }

            })
            .catch(error => {
                this.showSpinner = false;
                console.log('Error' + JSON.stringify(error));
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Error',
                        message: JSON.stringify(error),
                        variant: 'error',
                        mode: 'dismissable'
                    })
                );

            });

    }

    prepareCSVProductPriceChange() {
        let yourDate = new Date()
        yourDate.toISOString().split('T')[0];
        const offset = yourDate.getTimezoneOffset();
        yourDate = new Date(yourDate.getTime() - (offset * 60 * 1000));
        let splityourDate = yourDate.toISOString().split('T')[0];

        let doc = '<table>';
        // Add styles for the table
        doc += '<style>';
        doc += 'table, th, td {';
        doc += '    border: 1px solid black;';
        doc += '    border-collapse: collapse;';
        doc += '}';
        doc += '</style>';
        // Add all the Table Headers
        doc += '<tr>';
        this.columnHeaderChangePricing.forEach(element => {
            doc += '<th>' + element + '</th>'
        });
        doc += '</tr>'
        try {
            this.changePriceData.forEach(record => {                
                this.counterPrice = this.counterPrice + 1;
                doc += '<tr>';
                doc += '<td>' + record.PartNumber + '</td>';                
                doc += '<td>' + record.Description + '</td>';
                doc += '<td>' + record.PKG + '</td>';
                doc += '<td>' + record.Superseded + '</td>';
                if(record.Price > 0){
                    doc += '<td>' + parseFloat(record.Price).toFixed(2) + '</td>';
                }else{
                    doc += '<td>' + record.Price + '</td>';
                }
                if(record.Each_price > 0){
                    doc += '<td>' + parseFloat(record.Each_price).toFixed(2) + '</td>';
                }else{
                    doc += '<td>' + record.Each_price + '</td>';
                }
                doc += '<td>' + record.EXCH_CORE + '</td>';
                doc += '<td>' + record.core_Reference + '</td>';
                if(record.coreListPrice > 0){
                    doc += '<td>' + parseFloat(record.coreListPrice).toFixed(2) + '</td>';
                }else{
                    doc += '<td>' + record.coreListPrice + '</td>';
                }
                
                if (record.totalproductPrice) {
                    doc += '<td>' + parseFloat(record.totalproductPrice).toFixed(2) + '</td>';
                } else {
                    doc += '<td></td>';
                }
                doc += '<td>' + record.SignalCode + '</td>';
                doc += '<td>' + record.lineOfBusiness + '</td>';
                doc += '<td>' + record.Weight + '</td>';
                doc += '<td>' + record.Length + '</td>';
                doc += '<td>' + record.Width + '</td>';
                doc += '<td>' + record.Height + '</td>';
                doc += '<td>' + record.COO + '</td>';
                doc += '<td>' + record.HTSUS + '</td>';
                doc += '<td>' + new Date(record.DateChange).toDateString() + '</td>';
                doc += '</tr>';

            });
        } catch (err) {
            this.errorcountPrice = this.errorcountPrice + 1;
            console.log('error Occured ' + err);
        }
        var element = 'data:application/vnd.ms-excel,' + encodeURIComponent(doc);
        let downloadElement = document.createElement('a');
        downloadElement.href = element;
        downloadElement.target = '_self';
        // use .csv as extension on below line if you want to export data as csv
        downloadElement.download = 'Container Price Change File' + ' ' + splityourDate + '.xls';
        document.body.appendChild(downloadElement);
        downloadElement.click();

    }

    // CXREF 3819 : Changes Starts
    @track downloadLink;
    exportPriceBookGuideData() {
        this.showSpinner = true;
        fetchPriceBookGuideData({ staticResourceName: staticResourcelabelName })
            .then(result => {
                this.downloadLink = result;

            })
            .catch(error => {
                this.showSpinner = false;
                console.log('Error ' + JSON.stringify(error));
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Error',
                        message: JSON.stringify(error),
                        variant: 'error',
                        mode: 'dismissable'
                    })
                );

            });

    }

    openPopupModal() {
        window.open(this.downloadLink, 'popup', 'width=900,height=600'); return false;
    }
    // CXREF 3819 : Changes Ends
}