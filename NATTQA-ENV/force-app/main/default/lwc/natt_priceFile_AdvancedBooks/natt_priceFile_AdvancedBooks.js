/*** Standard LWC Imports ***/
import {  api,  LightningElement,  wire,  track} from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import UserId from '@salesforce/user/Id';

/*** Imports from NATT_PriceFileController ***/
import fetchPriceFiles from '@salesforce/apex/NATT_PriceFileController.grabPriceFileDetails';
import fetchCustomerPriceGroup from '@salesforce/apex/NATT_PriceFileController.getCustomerPriceGroup'

/**Custom Label Imports */
import PKGLabel from '@salesforce/label/c.NATT_Price_File_PKG';
import SupersedureLabel from '@salesforce/label/c.NATT_Price_File_Supersedure';
import BasisPriceLabel from '@salesforce/label/c.NATT_Price_File_Basis_Price';
import EachPriceLabel from '@salesforce/label/c.NATT_Price_File_Each_Price';
import TransferPriceLabel from '@salesforce/label/c.NATT_Price_File_Transfer_Price';
import ExchCoreLabel from '@salesforce/label/c.NATT_Price_File_EXCH_CORE';
import CoreReferenceLabel from '@salesforce/label/c.NATT_Price_File_Core_Reference';
import SignalCodeLabel from '@salesforce/label/c.NATT_Price_File_Signal_Code';
import DiscountCodeLabel from '@salesforce/label/c.NATT_Price_File_Discount_Code';
import WeightLabel from '@salesforce/label/c.NATT_Price_File_Weight';
import LengthLabel from '@salesforce/label/c.NATT_Price_File_Length';
import WidthLabel from '@salesforce/label/c.NATT_Price_File_Width';
import HeightLabel from '@salesforce/label/c.NATT_Price_File_Height';
import AdvancedBooksLabel from '@salesforce/label/c.NATT_Price_File_Advanced_Books';
import CompletePriceFilesLabel from '@salesforce/label/c.NATT_Price_File_Complete_Price_Files';
import DescriptionLabel from '@salesforce/label/c.NATT_Price_File_Description';
import EffectiveDateLabel from '@salesforce/label/c.NATT_Price_File_Effective_Date';
import PartNumberLabel from '@salesforce/label/c.NATT_Price_File_Part_Number';
import PriceChangesLabel from '@salesforce/label/c.NATT_Price_File_Price_Changes';
import OfLabel from '@salesforce/label/c.NATT_Price_File_Of';
import PageLabel from '@salesforce/label/c.NATT_Price_File_Page';
import FirstLabel from '@salesforce/label/c.NATT_Price_File_First';
import PreviousLabel from '@salesforce/label/c.NATT_Price_File_Previous';
import NextLabel from '@salesforce/label/c.NATT_Price_File_Next';
import LastLabel from '@salesforce/label/c.NATT_Price_File_Last';
import NoCustomerPriceGroupFoundLabel from '@salesforce/label/c.NATT_Price_File_Select_Amount_of_Time_Since_Update';
import NoCustomerPriceGroupAssigned from '@salesforce/label/c.NATT_Price_File_No_Price_Changes_found';
import PleaseUpdateYourAccountLabel from '@salesforce/label/c.NATT_Price_File_Select_Amount';
import NoAdvancedBooksFoundLabel from '@salesforce/label/c.NATT_Price_File_No_Advanced_Books_found';
import DownloadAsCsvLabel from '@salesforce/label/c.NATT_Price_File_Download_as_CSV';
import ProductCategoryLabel from '@salesforce/label/c.NATT_Price_File_Product_Category';
import ProductSubCategoryLabel from '@salesforce/label/c.NATT_Price_File_Product_Sub_Category';
import PriceTierCodeLabel from '@salesforce/label/c.NATT_Price_File_Price_Tier_Code';
export default class Natt_priceFile_AdvancedBooks extends LightningElement {
   /**
   * Custom Label creation
   */
    label = {
        CompletePriceFilesLabel,
        AdvancedBooksLabel,
        PriceChangesLabel,
        PageLabel,
        OfLabel,
        FirstLabel,
        PreviousLabel,
        NextLabel,
        LastLabel,
        DownloadAsCsvLabel,
        NoCustomerPriceGroupFoundLabel,
        NoCustomerPriceGroupAssigned,
        PleaseUpdateYourAccountLabel,
        NoAdvancedBooksFoundLabel
    }


    //Defines column values for External Customers
     @track columns = [
        { label: PartNumberLabel, fieldName: 'PartNumber', type: 'text', initialWidth: 125,},
        { label: DescriptionLabel, fieldName: 'Description', type: 'text', initialWidth: 200,},
        { label: PKGLabel, fieldName: 'PKG', type: 'number'},
        
        
        { label: EffectiveDateLabel, fieldName: 'EffectiveDate', type: 'date', initialWidth: 125, typeAttributes: {
            day: "numeric",
            month: "numeric",
            year: "numeric",
            timeZone: "UTC"
        }},

        { label: SupersedureLabel, fieldName: 'Supersedure', type: 'text'},
        { label: BasisPriceLabel, fieldName: 'BasisPrice', type: 'currency'},
        { label: EachPriceLabel, fieldName: 'EachPrice', type: 'currency'},
        { label: ExchCoreLabel, fieldName: 'ExchCore', type: 'text'},
        { label: CoreReferenceLabel, fieldName: 'CoreReference', type: 'text', initialWidth: 125,},
        { label: SignalCodeLabel, fieldName: 'SignalCode', type: 'text'},
        { label: DiscountCodeLabel, fieldName: 'DiscountCode', type: 'text'},
        // { label: 'Line of Business', fieldName: 'LineOfBusiness', type: 'text'},
        { label: WeightLabel, fieldName: 'Weight', type: 'text'},
        { label: LengthLabel, fieldName: 'Length', type: 'text'},
        { label: WidthLabel, fieldName: 'Width', type: 'text'},
        { label: HeightLabel, fieldName: 'Height', type: 'text'},

        { label: ProductCategoryLabel, fieldName: 'ProductCategory', type: 'text', initialWidth: 125},
        { label: ProductSubCategoryLabel, fieldName: 'ProductSubCategory', type: 'text', initialWidth: 125},
        { label: PriceTierCodeLabel, fieldName: 'PriceTierCode', type: 'text', initialWidth: 125},

        // { label: 'Core Flag', fieldName: 'CoreFlag', type: 'text'}
      ];

    //Defines column values for Internal Customers
    @track columnsInternal = [
        { label: PartNumberLabel, fieldName: 'PartNumber', type: 'text', initialWidth: 125,},
        { label: DescriptionLabel, fieldName: 'Description', type: 'text', initialWidth: 200,},
        { label: PKGLabel, fieldName: 'PKG', type: 'number'},        
       
        { label: EffectiveDateLabel, fieldName: 'EffectiveDate', type: 'date', initialWidth: 125, typeAttributes: {
            day: "numeric",
            month: "numeric",
            year: "numeric",
            timeZone: "UTC"
        }},

        { label: SupersedureLabel, fieldName: 'Supersedure', type: 'text'},
        { label: BasisPriceLabel, fieldName: 'BasisPrice', type: 'currency'},
        { label: EachPriceLabel, fieldName: 'EachPrice', type: 'currency'},
        { label: TransferPriceLabel, fieldName: 'TransferPrice', type: 'currency'},
        { label: ExchCoreLabel, fieldName: 'ExchCore', type: 'text'},
        { label: CoreReferenceLabel, fieldName: 'CoreReference', type: 'text', initialWidth: 125,},
        { label: SignalCodeLabel, fieldName: 'SignalCode', type: 'text'},
        { label: DiscountCodeLabel, fieldName: 'DiscountCode', type: 'text'},
        // { label: 'Line of Business', fieldName: 'LineOfBusiness', type: 'text'},
        { label: WeightLabel, fieldName: 'Weight', type: 'text'},
        { label: LengthLabel, fieldName: 'Length', type: 'text'},
        { label: WidthLabel, fieldName: 'Width', type: 'text'},
        { label: HeightLabel, fieldName: 'Height', type: 'text'},

        { label: ProductCategoryLabel, fieldName: 'ProductCategory', type: 'text', initialWidth: 100},
        { label: ProductSubCategoryLabel, fieldName: 'ProductSubCategory', type: 'text', initialWidth: 100},
        { label: PriceTierCodeLabel, fieldName: 'PriceTierCode', type: 'text', initialWidth: 100},

        // { label: 'Core Flag', fieldName: 'CoreFlag', type: 'text'}
      ];


    //Used to hold Price File list values
    priceFileLines;
    @track priceFileList;
    @track priceFileListHold;
    @track priceFileListDownload;
    fixedWidth = "width:16rem;";
    dayValue = 90;
    @track value;
    @track error;
    @track data;
    @api sortedDirection = 'asc';
    @api sortedBy = 'Name';
    @api partNumSearchKey;
    @api partNumberSearch;
    @api descriptionSearchKey;
    result;
    
    //Variables for Navigation settings
    @track page = 1; 
    @track items = []; 
    @track data = []; 

    @track startingRecord = 1;
    @track endingRecord = 0; 
    @track pageSize = 25; 
    @track totalRecountCount = 0;
    @track totalPage = 0;
    @track disableFirstButton = true;
    @track disablePreviousButton = true;
    @track disableNextButton = false;
    @track disableLastButton = false;
    @track disableDownloadButton = false;
    @track errorText;
    @track customerPriceGroup;
    @track limitValueAdvanced;

    //runs upon page load
    connectedCallback(){
        this.grabCustomerPriceGroup();
    }

    //Grab Customer Price Group value and use to find Price Files
    grabCustomerPriceGroup(){
        fetchCustomerPriceGroup({UserId:UserId})
        .then(result => {
            console.log('Customer Price Group Advanced: ' + result);
            this.customerPriceGroup = result;
            //Check to see if Customer is Internal, if so, assign Column set that has Transfer Price

            if(this.customerPriceGroup == null || this.customerPriceGroup == '' ){
                this.errorText = NoCustomerPriceGroupFoundLabel;
                console.log('No CPG assigned to user. Will return Net Prices as blank/0');
                const evt = new ShowToastEvent({
                    title: NoCustomerPriceGroupAssigned,
                    message: PleaseUpdateYourAccountLabel,
                    variant: 'warning',
                });
                console.log('After toast creation');

                this.dispatchEvent(evt);
                console.log('After evt dispatch');

                //disables the loading spinner (spinner is usually displayed until Price Files are queried)
                this.priceFileList = NoCustomerPriceGroupFoundLabel;
                //disables download button (and triggers No CPG text to appear)
                this.disableDownloadButton = true;
                //disable navigation buttons
                this.disablePreviousButton = true;
                this.disableFirstButton = true;
                this.disableNextButton = true;
                this.disableLastButton = true;
            }else{
                if(this.customerPriceGroup.startsWith('V1')){
                    this.columns = this.columnsInternal;
                }
                this.loadPriceFiles();
            }
        })
        .catch(error => {
            console.log('PriceFiles FAILED load: ' + error.body.message);
            this.error = error;
        })
    }

    //main method used to query products
    loadPriceFiles() {
        this.limitValueAdvanced = null;
        fetchPriceFiles({customerPriceGroup:this.customerPriceGroup, limitValue: this.limitValueAdvanced, lastRecordId : null, lastRecordName:null, nextOrPrevious: null, dayValue : null, advancedDate : this.dayValue})
        .then(result => {
            let preparedPricefileList = [];
            result.priceFiles.forEach(PriceFileEntry => {
                let preparedPriceFile = {};
                // preparedPriceFile.Id = PriceFileEntry.Id;
                preparedPriceFile.PartNumber = PriceFileEntry.PartNumber;
                preparedPriceFile.Description = PriceFileEntry.Description;
                preparedPriceFile.PKG = PriceFileEntry.PKG;
                preparedPriceFile.Supersedure = PriceFileEntry.Supersedure;
                preparedPriceFile.BasisPrice = PriceFileEntry.BasisPrice;
                preparedPriceFile.EachPrice = PriceFileEntry.EachPrice;
                if(this.customerPriceGroup.startsWith('V1')){
                    preparedPriceFile.TransferPrice = PriceFileEntry.TransferPrice;
                }
                preparedPriceFile.ExchCore = PriceFileEntry.ExchCore;
                preparedPriceFile.CoreReference = PriceFileEntry.CoreReference;
                preparedPriceFile.SignalCode = PriceFileEntry.SignalCode;
                preparedPriceFile.DiscountCode = PriceFileEntry.DiscountCode;
                preparedPriceFile.Weight = PriceFileEntry.Weight;
                preparedPriceFile.Length = PriceFileEntry.Length;
                preparedPriceFile.Width = PriceFileEntry.Width;
                preparedPriceFile.Height = PriceFileEntry.Height;
                // preparedPriceFile.CoreFlag = PriceFileEntry.CoreFlag;
                preparedPriceFile.EffectiveDate = PriceFileEntry.EffectiveDate;

                preparedPriceFile.ProductCategory = PriceFileEntry.ProductCategory;
                preparedPriceFile.ProductSubCategory = PriceFileEntry.ProductSubCategory;
                preparedPriceFile.PriceTierCode = PriceFileEntry.PriceTierCode;
                
                preparedPricefileList.push(preparedPriceFile);

            });
            //assign to priceFileListDownload to allow download of entire table, not just current page
            this.priceFileListDownload = preparedPricefileList;
            console.log('Table Size: ' + preparedPricefileList.length);
            if(preparedPricefileList.length == 0){
                this.errorText = NoAdvancedBooksFoundLabel;
                this.disableDownloadButton = true;
            }else{
                this.disableDownloadButton = false;
            }
            this.items = preparedPricefileList;
            this.totalRecountCount = preparedPricefileList.length; 
            this.totalPage = Math.ceil(this.totalRecountCount / this.pageSize);
            if(this.totalPage == 0){
                this.totalPage = 1;
            }
            this.priceFileList = this.items.slice(0,this.pageSize); 
            this.endingRecord = this.pageSize;
            // this.columns = columns;

            this.error = undefined;
            this.disableOrEnableButtons();
        })
        .catch(error => {
            console.log('Invoice FAILED: ' + error.body.message);
            this.error = error;
        })
    }

    //check to see if navigation buttons should be disabled or not
    disableOrEnableButtons(){
        //disables or enables next & last buttons
        if(this.page == this.totalPage || this.totalPage == 0){
            this.disableNextButton = true;
            this.disableLastButton = true;
        }else{
            this.disableNextButton = false;
            this.disableLastButton = false;
        }

        //disables or enables previous & first buttons
        if(this.page == 1){
            this.disablePreviousButton = true;
            this.disableFirstButton = true;
        } else{
            this.disablePreviousButton = false;
            this.disableFirstButton = false;
        }
    }

    //clicking on first button returns table to first page
    handleFirst() {
        this.page = 1; //set to first page
        this.displayRecordPerPage(this.page);
        this.disableOrEnableButtons();
    }

    //clicking on previous button this method will be called
    previousHandler() {
        if (this.page > 1) {
            this.page = this.page - 1; //decrease page by 1
            this.displayRecordPerPage(this.page);
        }
        this.disableOrEnableButtons();
    }

    //clicking on next button this method will be called
    nextHandler() {
        if((this.page<this.totalPage) && this.page !== this.totalPage){
            this.page = this.page + 1; //increase page by 1
            this.displayRecordPerPage(this.page);            
        }  
        this.disableOrEnableButtons();       
    }

    //clicking on last button sets table to final page
    handleLast() {
        this.page = this.totalPage; //set to last page
        this.displayRecordPerPage(this.page);            
        this.disableOrEnableButtons();
    }
    //this method displays records page by page
    displayRecordPerPage(page){

        this.startingRecord = ((page -1) * this.pageSize) ;
        this.endingRecord = (this.pageSize * page);

        this.endingRecord = (this.endingRecord > this.totalRecountCount) 
                            ? this.totalRecountCount : this.endingRecord; 

        this.priceFileList = this.items.slice(this.startingRecord, this.endingRecord);

        this.startingRecord = this.startingRecord + 1;
    }    

    //converts records into CSV when [Download as CSV] is clicked
    downloadCSVFile() {   
        let rowEnd = '\n';
        let csvString = '';
        // this set elminates the duplicates if have any duplicate keys
        let rowData = new Set();
    
        // getting keys from data
        this.priceFileListDownload.forEach(function (record) {
            Object.keys(record).forEach(function (key) {
                rowData.add(key);
            });
        });
    
        // Array.from() method returns an Array object from any object with a length property or an iterable object.
        rowData = Array.from(rowData);
        
         // splitting using ','
        // Adds Column Headings based on Field name (not column w/ custom label name)
        // csvString += rowData.join(',');

        // Adds column headings manually to use custom label name.
        // Change column headings here if you need to change which headings are included in CSV
        csvString = [PartNumberLabel, DescriptionLabel, PKGLabel, SupersedureLabel, BasisPriceLabel, EachPriceLabel, ExchCoreLabel, CoreReferenceLabel, SignalCodeLabel, DiscountCodeLabel, WeightLabel, LengthLabel, WidthLabel, HeightLabel, EffectiveDateLabel,ProductCategoryLabel, ProductSubCategoryLabel, PriceTierCodeLabel ];
        csvString += rowEnd;
    
        // main for loop to get the data based on key value
        for(let i=0; i < this.priceFileListDownload.length; i++){
            let colValue = 0;
    
            // validating keys in data
            for(let key in rowData) {
                if(rowData.hasOwnProperty(key)) {
                    // Key value 
                    // Ex: Id, Name
                    let rowKey = rowData[key];
                    // add , after every value except the first.
                    if(colValue > 0){
                        csvString += ',';
                    }
                    // If the column is undefined, it as blank in the CSV file.
                    // let value = this.priceFileListDownload[i][rowKey] === undefined ? '' : this.priceFileListDownload[i][rowKey];
                    let value = this.priceFileListDownload[i][rowKey] === undefined ? '' : this.priceFileListDownload[i][rowKey];
                    if(colValue == 1 || colValue % 18 == 0){
                        if(value == ''){
                            value='"'+value+'"';
                        }else if(value.startsWith('\-')){                                
                            //if((!value.startsWith('\-\-') && value.startsWith('\-')) && value.includes('\-\-')){                                
                                 value ='="' + value+'"';
                        }
                    }
                    if (value == 'PartNumber'){
                        console.log('Part Number Found: ' + value);
                        value = PartNumberLabel;
                    }
                    if(rowKey == 'ProductCategory' || rowKey == 'ProductSubCategory' ){
                        value = '"' + value + '"';
                    }
                    csvString+=value;
                    colValue++;
                }
            }
            csvString += rowEnd;
        }

    // Creating anchor element to download
    let downloadElement = document.createElement('a');

    // This  encodeURI encodes special characters, except: , / ? : @ & = + $ # (Use encodeURIComponent() to encode these characters).
    // downloadElement.href = 'data:text/csv;charset=utf-8,' + encodeURI(csvString);
    downloadElement.href = 'data:text/csv;charset=utf-8,' + encodeURIComponent(csvString);
    downloadElement.target = '_self';
    // CSV File Name
    downloadElement.download = 'Advanced Books.csv';
    // below statement is required if you are using firefox browser
    document.body.appendChild(downloadElement);
    // click() Javascript function to download CSV file
    downloadElement.click(); 
  }

    
}