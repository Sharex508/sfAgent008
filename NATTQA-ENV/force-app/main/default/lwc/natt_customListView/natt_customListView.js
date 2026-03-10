import { api, LightningElement, track, wire } from 'lwc';  
import fetchRecs from '@salesforce/apex/NATT_CustomListViewCon.fetchRecs';   
import getPersistentFilter from '@salesforce/apex/NATT_CustomListViewCon.getPersistentFilter';
import { NavigationMixin } from 'lightning/navigation';

import { getObjectInfo } from 'lightning/uiObjectInfoApi';
import ORDER_OBJECT from '@salesforce/schema/Order';
import NATTORDERSTATUS_FIELD from '@salesforce/schema/Order.NATT_Order_Status__c';
import { getPicklistValues } from 'lightning/uiObjectInfoApi';

import jdeSoNumberLabel from '@salesforce/label/c.NATT_CustSearch_JDE_SO_Number';
import lastModifiedLabel from '@salesforce/label/c.NATT_CustSearch_Last_Modified_Date';
import orderNumberLabel from '@salesforce/label/c.NATT_CustSearch_OrderNumber';
import orderAmountLabel from '@salesforce/label/c.NATT_CustSearch_Order_Amount';
import orderStartDateLabel from '@salesforce/label/c.NATT_CustSearch_Order_Start_Date';
import orderTypeLabel from '@salesforce/label/c.NATT_CustSearch_Order_Type';
import poNumberLabel from '@salesforce/label/c.NATT_CustSearch_PO_Number';
import performancePartsOrdersLabel from '@salesforce/label/c.NATT_CustSearch_PPO';
import statusLabel from '@salesforce/label/c.NATT_CustSearch_Status';
import clearLabel from '@salesforce/label/c.NATT_CustSearch_Clear';
import orderSearchLabel from '@salesforce/label/c.NATT_CustSearch_OrderSearch';
import customerNumberLabel from '@salesforce/label/c.NATT_CustSearch_CustomerNumber';
import accountNameLabel from '@salesforce/label/c.NATT_CustSearch_AccountName';
import poAccountNumberLabel from '@salesforce/label/c.NATT_CustSearch_PoAccountNumber';
import partNumberLabel from '@salesforce/label/c.NATT_CustSearch_PartNumber';
import fromLabel from '@salesforce/label/c.NATT_CustSearch_From';
import toLabel from '@salesforce/label/c.NATT_CustSearch_To';
import searchLabel from '@salesforce/label/c.NATT_CustSearch_Search';
import shipToAddressName from '@salesforce/label/c.NATT_CustSearch_ShipToName'
 
export default class natt_customListView extends NavigationMixin( LightningElement ) {  
 
    @track listRecs;  
    @track initialListRecs;
    @track error;  
    @track columns;  
    @api AccountId;
    @api RelatedObject;    
    @api RelatedField;
    
    sortedBy='CreatedDate';
    defaultSortDirection = 'DESC';
    sortDirection = 'DESC';
    
    carrierOrderNumber;
    poOrAccount;
    partNumber;
    status;
    fromDate;
    toDate;
    showSpinner=false;
    hasExecuted=false;
    partsOrderRecordType;
    statusValue;
    //holds the limit we can use for offset
    maxOffSetCount=2000;
    offSetCount = 0;
    targetDatatable;    
    loadMoreAvailable=false;

    filterDetail = {
        carrierOrderNumber:'', poOrAccount:'', partNumber:'', status:'', fromDate:'', toDate:'', sortedBy:'',sortDirection:''
    }

    label = {
        performancePartsOrdersLabel,
        clearLabel,
        orderSearchLabel,
        jdeSoNumberLabel,
        poAccountNumberLabel,
        partNumberLabel,
        fromLabel,
        toLabel,
        searchLabel,
        statusLabel
    }

    Fields='OrderNumber,NATT_Purchase_Order__c,NATT_JDE_Sales_Order_Number__c,NATT_JdeOrderTypeName__c,NATT_Order_Status__c,EffectiveDate,LastModifiedDate,TotalAmount,CurrencyIsoCode,NATT_CustomerBilltoCode__c,NATT_Account_Name__c,NATT_Billing_Address__r.name,AccountId';
    /*TableColumns='[ { label:performancePartsOrdersLabel,"fieldName":"OrderNumberId","type":"url","typeAttributes":{"label":{"fieldName":"OrderNumber"}}},'+
    '{"label":"PO #","fieldName":"NATT_Purchase_Order__c"}, {"label":"JDE Sales Order #","fieldName":"NATT_JDE_Sales_Order_Number__c"}, '+
    '{"label":"Order Type","fieldName":"NATT_JdeOrderTypeName__c"}, '+
    '{"label":"Status","fieldName":"NATT_Order_Status__c"}, '+
    '{"label":"Order Start Date","fieldName":"EffectiveDate","type":"date-local","typeAttributes":{"year": "numeric","month": "numeric","day": "numeric"}}, '+
    '{"label":"Last Modified Date","fieldName":"LastModifiedDate","type":"date","typeAttributes":{"year": "numeric","month": "2-digit","day": "2-digit","hour": "2-digit","minute": "2-digit"}}, '+
    '{"label":"Order Amount","fieldName":"TotalAmount", "type": "currency","typeAttributes":{"minimumFractionDigits" :"2","currencyCode": { "fieldName": "CurrencyIsoCode"},"currencyDisplayAs":"code"}}]';*/
    TableColumns= [{ label:orderNumberLabel,fieldName:"OrderNumberId",type:"url",typeAttributes:{label:{fieldName:"OrderNumber"}}, sortable: "true"},
    {label:poNumberLabel,fieldName:"NATT_Purchase_Order__c", sortable: "true"}, 
    {label:jdeSoNumberLabel,fieldName:"NATT_JDE_Sales_Order_Number__c", sortable: "true"}, 
    {label:orderTypeLabel,fieldName:"NATT_JdeOrderTypeName__c", sortable: "true"}, 
    {label:statusLabel,fieldName:"NATT_Order_Status__c", sortable: "true"}, 
    {label:orderStartDateLabel,fieldName:"EffectiveDate",type:"date-local",typeAttributes:{year:"numeric",month: "numeric",day: "numeric"}, sortable: "true"}, 
    {label:lastModifiedLabel,fieldName:"LastModifiedDate",type:"date",typeAttributes:{year: "numeric",month:"2-digit",day: "2-digit",hour: "2-digit",minute: "2-digit"}, sortable: "true"}, 
    {label:orderAmountLabel,fieldName:"TotalAmount", type: "currency",typeAttributes:{minimumFractionDigits :"2",currencyCode: { fieldName: "CurrencyIsoCode"},currencyDisplayAs:"code"}, sortable: "true"},
    {label:customerNumberLabel,fieldName:"NATT_CustomerBilltoCode__c", sortable: "true"},
    {label:accountNameLabel,fieldName:"AccountNameId",type:"url",typeAttributes:{label:{fieldName:"NATT_Account_Name__c"}}, sortable: "true"},
   // {label:shipToAddressName,fieldName:"NATT_Billing_Address__r.name", sortable: "true"}
];
    
    @track picklistValues;
    

    // GET OBJECT INFO
    @wire (getObjectInfo, {objectApiName: ORDER_OBJECT})
    objectInfo({ error, data }) {        
        if (data) {
            //console.log('data:'+JSON.stringify(data));
            const rtis = data.recordTypeInfos;
            Object.keys(rtis).forEach(element => {
                //console.log(rtis[element].name);
                if(rtis[element].name=='NATT Parts Order'){
                    this.partsOrderRecordType=rtis[element].recordTypeId;
                    //console.log('partsOrderRecordType:'+this.partsOrderRecordType);
                }
             });
        } else if (error) {
            console.log(error);
        }
    }  

    // GET PICKLIST VALUES 
    @wire (getPicklistValues, {recordTypeId: '$partsOrderRecordType', fieldApiName: NATTORDERSTATUS_FIELD})
    wiredPicklistValues({ error, data }) {
        // reset values to handle eg data provisioned then error provisioned
        this.picklistValues = undefined;
        if (data) {
            //console.log('picklistValus:'+JSON.stringify(data));
            this.picklistValues=data.values;
        } else if (error) {
            console.log(error);
        }
    }  

    connectedCallback() {
        this.columns = this.TableColumns;       
    }

    renderedCallback(){
        if(!this.hasExecuted){
            getPersistentFilter()
            .then(filter=>{
                console.log('filter on renderedCallback:'+JSON.stringify(filter));
                this.filterDetail = JSON.parse(filter.NATT_SearchFilter__c);
                console.log('filterDetail.carrierOrderNumber:'+this.filterDetail.carrierOrderNumber);
                console.log('filterDetail.fromDate:'+this.filterDetail.fromDate);
                this.template.querySelector('lightning-input[data-name="carrierOrderNumber"]').value=this.filterDetail.carrierOrderNumber;        
                this.template.querySelector('lightning-input[data-name="poOrAccount"]').value=this.filterDetail.poOrAccount;
                this.template.querySelector('lightning-input[data-name="partNumber"]').value=this.filterDetail.partNumber;
                //this.template.querySelector('lightning-input[data-name="status"]').value=this.filterDetail.statusValue;
                this.statusValue=this.filterDetail.status;
                this.template.querySelector('lightning-input[data-name="fromDate"]').value=this.filterDetail.fromDate;
                this.template.querySelector('lightning-input[data-name="toDate"]').value=this.filterDetail.toDate;                
                this.handleSearch();
                this.hasExecuted=true;
            });
        };
    }

    get vals() {  
        //console.log('vals called:'+this.AccountId);
        return this.RelatedObject + '-' + this.Fields + '-' +this.RelatedField + '-' + this.AccountId;
    }    
 
    handleKeyChange( event ) {            
        const searchKey = event.target.value.toLowerCase();  
        //console.log( 'Search Key is ' + searchKey ); 
        if ( searchKey ) {  
            this.listRecs = this.initialListRecs; 
             if ( this.listRecs ) {
                let recs = [];
                for ( let rec of this.listRecs ) {
                    //console.log( 'Rec is ' + JSON.stringify( rec ) );
                    let valuesArray = Object.values( rec );
                    //console.log( 'valuesArray is ' + valuesArray ); 
                    for ( let val of valuesArray ) {                        
                        if ( val.toLowerCase().includes( searchKey ) ) {
                            recs.push( rec );
                            break;                        
                        }
                    }                    
                }
                //console.log( 'Recs are ' + JSON.stringify( recs ) );
                this.listRecs = recs;
             } 
        }  else {
            this.listRecs = this.initialListRecs;
        } 
    }      

    onHandleSort( event ) {
        const { fieldName: sortedBy, sortDirection } = event.detail;        
        this.sortDirection = sortDirection;
        this.sortedBy = sortedBy;        
        this.handleSearch();        
    }

    sortBy( field, reverse, primer ) {
        const key = primer
            ? function( x ) {
                  return primer(x[field]);
              }
            : function( x ) {
                  return x[field];
              };

        return function( a, b ) {
            a = key(a);
            b = key(b);
            return reverse * ( ( a > b ) - ( b > a ) );
        };
    }

    handleRowAction( event ) {
        const actionName = event.detail.action.name;
        const row = event.detail.row;
        switch ( actionName ) {
            case 'view':
                this[NavigationMixin.GenerateUrl]({
                    type: 'standard__recordPage',
                    attributes: {
                        recordId: row.Id,
                        actionName: 'view',
                    },
                }).then(url => {
                     window.open(url);
                });
                break;
            case 'edit':
                this[NavigationMixin.Navigate]({
                    type: 'standard__recordPage',
                    attributes: {
                        recordId: row.Id,
                        objectApiName: this.RelatedObject,
                        actionName: 'edit'
                    }
                });
                break;
            default:
        }
    }

    createNew() {
        this[NavigationMixin.Navigate]({            
            type: 'standard__objectPage',
            attributes: {
                objectApiName: this.RelatedObject,
                actionName: 'new'                
            }
        });
    } 

    handleClearSearch(){        
        this.template.querySelector('lightning-input[data-name="carrierOrderNumber"]').value=null;        
        this.template.querySelector('lightning-input[data-name="poOrAccount"]').value=null;
        this.template.querySelector('lightning-input[data-name="partNumber"]').value=null;
        //this.template.querySelector('lightning-input[data-name="status"]').value=null;
        this.statusValue='';
        this.template.querySelector('lightning-input[data-name="fromDate"]').value=null;
        this.template.querySelector('lightning-input[data-name="toDate"]').value=null;
        this.carrierOrderNumber = null;        
        this.poOrAccount = null;
        this.partNumber = null;
        this.status = null;
        this.fromDate = null;
        this.toDate = null;     
        this.offSetCount=0;   
        if(this.targetDatatable){
            this.targetDatatable.enableInfiniteLoading=true;;
        }
        this.handleSearch();
    }

    handleSearch(){
        this.showSpinner=true;        
        this.offSetCount=0;
        this.carrierOrderNumber = this.template.querySelector('lightning-input[data-name="carrierOrderNumber"]').value;        
        this.poOrAccount = this.template.querySelector('lightning-input[data-name="poOrAccount"]').value;
        this.partNumber = this.template.querySelector('lightning-input[data-name="partNumber"]').value;
        //this.status = this.template.querySelector('lightning-input[data-name="status"]').value;
        this.status = this.statusValue;
        this.fromDate = this.template.querySelector('lightning-input[data-name="fromDate"]').value;
        this.toDate = this.template.querySelector('lightning-input[data-name="toDate"]').value;
        
        this.filterDetail = {
            carrierOrderNumber:this.carrierOrderNumber, poOrAccount:this.poOrAccount, partNumber:this.partNumber, status:this.status, fromDate:this.fromDate, toDate:this.toDate, sortedBy:this.sortedBy,sortDirection:this.sortDirection
        };

        console.log('filterDetail in handleSearch:'+JSON.stringify(this.filterDetail));
        let jsonString = JSON.stringify(this.filterDetail);

        fetchRecs({ listValues: this.vals, jsonFilter:jsonString,offSetCount:this.offSetCount})  
        .then( (data ) => {   
            if ( data ) {
                //console.log( 'Records are ' + JSON.stringify( data ) );
                let tempOrderList=[];                
                data.forEach((record)=>{
                    let tempOrderRec = Object.assign({},record);
                    tempOrderRec.OrderNumberId = '/ppg/s/order/'+tempOrderRec.Id+'/detail';
                    tempOrderRec.AccountNameId = '/ppg/s/detail/'+tempOrderRec.AccountId;
                    tempOrderList.push(tempOrderRec);
                })
                this.listRecs = tempOrderList;
                this.initialListRecs = tempOrderList;
                console.log('listRecs'+JSON.stringify(listRecs));
            } else {
                this.listRecs = null;
                this.initialListRecs = null;    
                console.log('else');            
            }        
            if(this.targetDatatable){
                this.targetDatatable.isLoading=false;
            }
            this.showSpinner=false;
        }).catch(error=>{
            this.error=JSON.stringify(error);
            this.showSpinner=false;
            console.log('error:'+this.error);
        });
    }

    handleEnter(event){        
        const isEnterKey = event.keyCode === 13;    
        if (isEnterKey) {
            this.handleSearch();
        }
    }

    handleStatusChange(event){
        this.statusValue = event.detail.value;
        this.handleSearch();
    }

    handleLoadMore(event){        
        event.preventDefault();
        this.offSetCount+=100;
        event.target.isLoading=true;
        this.targetDatatable=event.target;
        console.log('load more called'+this.offSetCount);        
        if(this.offSetCount>=this.maxOffSetCount){
            this.offSetCount=this.maxOffSetCount;
            this.showSpinner=false;
            this.targetDatatable.enableInfiniteLoading = false;
            this.targetDatatable.isLoading=false;
        }else{        
            this.filterDetail = {
                carrierOrderNumber:this.carrierOrderNumber, poOrAccount:this.poOrAccount, partNumber:this.partNumber, status:this.status, fromDate:this.fromDate, toDate:this.toDate, sortedBy:this.sortedBy,sortDirection:this.sortDirection
            };
            let jsonString = JSON.stringify(this.filterDetail);
            fetchRecs({ listValues: this.vals, jsonFilter:jsonString,offSetCount:this.offSetCount})  
            .then( (data ) => {        
                if ( data ) {
                    //console.log( 'load more Records are ' + JSON.stringify( data ) );
                    if(data.length==0){
                        this.offSetCount=this.maxOffSetCount;
                    }
                    let tempOrderList=[];
                    if(!this.listRecs){
                        this.listRecs = [];
                    }
                    data.forEach((record)=>{
                        let tempOrderRec = Object.assign({},record);
                        tempOrderRec.OrderNumberId = '/ppg/s/order/'+tempOrderRec.Id+'/detail';
                        tempOrderRec.AccountNameId = '/ppg/s/detail/'+tempOrderRec.AccountId;
                        tempOrderList.push(tempOrderRec);
                    })
                    this.listRecs = [...this.listRecs,...tempOrderList];
                    this.initialListRecs = tempOrderList;
                } else {                    
                    this.listRecs = null;
                    this.initialListRecs = null;
                    this.showSpinner=false;
                    console.log('no data');
                }        
                if(this.targetDatatable){
                    this.targetDatatable.isLoading=false;
                }
                this.showSpinner=false;
            }).catch(error=>{
                this.error=JSON.stringify(error);
                this.showSpinner=false;
                console.log('error in handleLoadMore:'+this.error);
            });
        }
    }
}