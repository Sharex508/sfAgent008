export default class nAC_BulkUploadEnchancedLineItem {


  // Formatter used to display listPrice() correctly in the "List Price" column
  _formatter = new Intl.NumberFormat("en-US", {
    style: "currency",
    currency: "USD"
  });

  /***
   * @type {ConnectApi.ProductSearchResults} from NACon_B2BGetInfo.productSearch */
  _product;
  /***
   * @type {List<NATT_ProductItem__c>} from NACon_PriceAvailabilityController.getAvailable */
  _available;
  /***
   * @type {List<ContentDocument>} from NACon_PriceAvailabilityController.getUserGuide */
  _userGuide;
  /***
   * @type {boolean} This is just to track whether a user has interacted with the row,
   *                 important because otherwise the Validation Status would be Invalid
   *                 for rows that are just added
   */
  _isEmpty;
  /***
   * @type {string} The part number that this part superceded (if there is one)
   */
  _supersededPartNumber;
  /***
   * @type {string} The Product2.Id of the Core Part (if there is one)
   */
  _corePartProductId;
  /***
   * @type {string} The NA Container  URL
   */
  _naContainerUrl;

  _productPrice;

  _coreProductPrice;

  _clickedWarehouse;

  _productMedia;

  _quickEntryProductNumber;

  set quickEntryProductNumber(value){
    this._quickEntryProductNumber = value;
  }

  get quickEntryProductNumber(){
    return this._quickEntryProductNumber;
  }



  constructor(
    product,
    available,
    history,
    userGuide,
    rowNumber,
    supersededPartNumber, // optional
    corePartProductId, // optional
    naContainerUrl,
    productPrice,
    coreProductPrice,
    clickedWarehouse
  ) {
    this._product = product;
    this._available = available;
    this._history = history;
    this._userGuide = userGuide;
    this._rowNumber = rowNumber;
    this._supersededPartNumber = supersededPartNumber;
    this._corePartProductId = corePartProductId;
    this._naContainerUrl = naContainerUrl;
    this._productPrice = productPrice;
    this._coreProductPrice = coreProductPrice;
    this._clickedWarehouse = clickedWarehouse;
    // _isEmpty should only be true for "empty" lines that are generated in nAC_BulkUploadEnchanced.js
    this._isEmpty =
      this._product == null && this._available == null && this._history == null;

      
    if(this._userGuide?.mediaGroups){
      this._userGuide.mediaGroups.forEach(mg=>{
        if(mg?.mediaItems){
          mg.mediaItems.forEach(mi=>{
            if(mi.alternateText==='Bulletin'){
              this._productMedia=mi;
            }
          })
        }
      })
    }
    
  }

  // Ensures that a product was found and a quantity provided unless line is empty (a.k.a. new)
  // (Used by Validation Status)
  get isInvalid() {
    return this.isEmpty
      ? false
      : !(this.validationStatus === "Valid Part" && this.quantity > 0);
  }

  // Used to identify an "empty" row so that
  // rows without input don't fail validation
  get isEmpty() {
    return this._isEmpty;
  }

  // Row Number just matters to show in the # column of the table
  _rowNumber;
  get rowNumber() {
    return this._rowNumber;
  }
  set rowNumber(rowNumber) {
    this._rowNumber = rowNumber;
  }

  // Determines whether or not the availability tooltip should show when the user hovers
  
  _showAvailability;
  get showAvailability() {
    return (
      !this.isEmpty &&
      this.available !== "Direct Delivery" &&
      Date.parse(this.availableDate) > new Date() &&
      this._showAvailability
    );
  }
  set showAvailability(value) {
    this._showAvailability = value;
  }
/*
  // Displayed in the "Availability" column
  get available() {
    return this._product?.fields?.NATT_DirectDelivery__c?.value === "true"
      ? "Direct Delivery"
      : this._product?.fields?.NATT_SignalCode__c?.value === "NSI"
      ? "NSI"
      : this._available?.NATT_AvailableQuantity__c;
  }*/
      get available() {
        console.log('this._product--'+ JSON.stringify(this._product));
        if (this._product?.fields?.NATT_DirectDelivery__c?.value === "true") {
            return "Direct Delivery";
        } else if (this._product?.fields?.NATT_SignalCode__c?.value === "NSI") {
            return this._available?.NATT_NSI_Availability__c?.match(/\((-?\d+)\)/)?.[0].replace('(', '\n').replace(')', '');
        } else {
            return this._available?.NATT_AvailableQuantity__c;
      }
    }
    

  // Displayed in the tooltip when user hovers mouse over "Availability" column value
  get availableDate() {
    return (
      "More Expected: <br />" +
      new Date(
        Date.parse(this._available?.NATT_AvailabilityDate__c)
      ).toLocaleDateString()
    );
  }

  // Value for History is passed in by NACon_PriceAvailabilityController.getHistory
  // Slice to remove the first record in the array (I think because it's always the same,
  // but I pulled this logic from the old component so not 100% sure)
  _history;
  get history() {
    return this.disableHistory ? null : this._history.slice(1);
  }

  // Product2.Id
  // This is used in most of the outgoing web service calls that take a Product2.Id parameter
  get id() {
    return this._product?.id;
  }

  // Product2.NATT_P_N__c
  // Data bound to the "Part Number" text input column
  get partNumber() {
    return this._product?.fields?.NATT_P_N__c?.value;
  }

  // Holds quantity the user entered,
  // Data bound to the "Quantity" text input column
  _quantity;
  get quantity() {
    return this._quantity;
  }
  set quantity(quantity) {
    this._quantity = quantity;
  }

  // Unit price from the searchProductResponse
  get unitPrice() {
    return this._product?.prices?.unitPrice
      ? this._formatter.format(this._product.prices.unitPrice)
      : "";
  }

  // List price from the searchProductResponse
  get listPrice() {
    return this._product?.prices?.listPrice
      ? this._formatter.format(this._product?.prices?.listPrice)
      : "";
  }


  // Product2.Name - Displayed in the "Description" column
  get description() {
    return this._product?.fields?.Name?.value;
  }


  get discountCode() {
    let returnValue = '';
    if (this._product) {
      returnValue=this._product?.fields?.NATT_Discount_Code__c?.value;
    }
    return returnValue;
  }

  // Product2.NATT_UOM_Conversion - i.e. 6
  // Product2.QuantityUnitOfMeasure - i.e. PK
  // Displayed in the "Unit of Measure" column
  get unitOfMeasure() {
    let returnValue = "";
    returnValue += this._product?.fields?.NATT_UOM_Conversion__c?.value
      ? parseInt(this._product?.fields?.NATT_UOM_Conversion__c?.value, 10)
      : "";
    returnValue += " ";
    returnValue += this._product?.fields?.QuantityUnitOfMeasure?.value
      ? this._product?.fields?.QuantityUnitOfMeasure?.value
      : "";

    return returnValue;
  }

  // Displayed in the "Validation Status" column
  get validationStatus() {
    return this.isEmpty
      ? ""
      : this.id === undefined
      ? "Invalid Part"
      : this.notOrderableValidationStatus=="true"
      ? "Invalid Part"
      : this.signalCodeValidationStatus !== ""
      ? this.signalCodeValidationStatus
      : this.salesCodeValidationStatus !== ""
      ? this.salesCodeValidationStatus
      : "Valid Part";
  }

  // Determines which CSS class to apply to the "Validation Status" column
  get validationStatusClass() {
    let returnStatus;
    switch (this.validationStatus) {
      case "Valid Part":
        returnStatus = "valStatusT";
        break;

      default:
        returnStatus = "valStatusF";
        break;
    }
    return returnStatus;
  }

  // Determines whether or not the Weights & Dimensions tooltip should show when the user hovers the mouse over it
  
  _showWeightAndDimensions;
  get showWeightAndDimensions() {
    return !this.isEmpty && this._showWeightAndDimensions;
  }
  set showWeightAndDimensions(value) {
    this._showWeightAndDimensions = value;
  }

  // Product2.NATT_Length__c
  // Product2.NATT_Width__c
  // Product2.NATT_Height__c
  // Product2.NATT_Weight__c
  // Displayed in the "Weight & Dimensions" column tooltip
  get weightAndDimensions() {
    var returnValue = [];

    if (this._product) {
      returnValue.push(
        "<p>Length: ",
        this._product.fields?.NATT_Length__c?.value,
        "</p>"
      );
      returnValue.push(
        "<p>Width: ",
        this._product.fields?.NATT_Width__c?.value,
        "</p>"
      );
      returnValue.push(
        "<p>Height: ",
        this._product.fields?.NATT_Height__c?.value,
        "</p>"
      );
      returnValue.push(
        "<p>Weight: ",
        this._product.fields?.NATT_Weight__c?.value,
        "</p>"
      );
    }

    return returnValue.join("");
  }

  // Referenced in nACBulkUploadEnchanced.html to determine if the
  // Part history icon should be clickable
  get disableHistory() {
    return this._history && this._history.length > 1 ? false : true;
  }

  // Referenced/Displayed in the Parts History modal in nACBulkUploadEnchanced.html
  get finalPartNumber() {
    return this.disableHistory ? "" : this._history[0]?.NATT_P_N__c;
  }

  // Determines if a part has been superceded
  // (if it is, then nACBulkUploadEnchanced.js reloads the line with alternative product)
  /*
  get isSuperseded() {
    
    let signalCode = this._product?.fields?.NATT_SignalCode__c?.value;
    console.log('signalCode=>>'+signalCode);
    if(signalCode && signalCode!='S1' ){
      return (
        this.partNumber !== "" &&
        this.finalPartNumber !== "" &&
        this.partNumber !== this.finalPartNumber
      );
    }else{
      return false;
    }
  }*/
 
      // Utility: get the warehouse-specific signal code by clicked warehouse
  _getWarehouseSignalCode() {
    const wh = this._clickedWarehouse;
    const fieldMap = {
      PAN: this._product?.fields?.NAOCAP_Signal_Code_PAN__c?.value,
      ANA: this._product?.fields?.NAOCAP_Signal_Code_ANA__c?.value,
      // Add more warehouses here if needed in future
    };
    return fieldMap[wh];
  }
// Getter: isSuperseded
get isSuperseded() {
  const warehouse = this._clickedWarehouse;
    const whSignalCode = this._getWarehouseSignalCode();
    const globalSignalCode = this._product?.fields?.NATT_SignalCode__c?.value;

    // True only if there is a genuine alternate
    const hasDifferentFinal =
      this.partNumber &&
      this.finalPartNumber &&
      this.partNumber !== this.finalPartNumber;

    // Warehouse-specific precedence for PAN/ANA:
    if (warehouse === "PAN" || warehouse === "ANA") {
      // PAN/ANA + S1 => normal product => never supersede
      if (whSignalCode === "S1") {
        return false;
      }
      // PAN/ANA + non-S1 => supersede only when the final part differs
      return !!whSignalCode && whSignalCode !== "S1" && hasDifferentFinal;
    }

    // Non-PAN/ANA: global rule
    const canSupersedeGlobally = !!globalSignalCode && globalSignalCode !== "S1";
    return canSupersedeGlobally && hasDifferentFinal;
   
}


  // Determines if a part was loaded as an alternative to a superseded part
  // (if it is, then the html will render the old part number in the description column)
  get isAlternativePart() {
    return this._supersededPartNumber !== undefined;
  }

  get supersededPartNumber() {
    return this._supersededPartNumber;
  }

  // Referenced in nACBulkUploadEnchanced.html to determine if the "Description"
  // column should include a link to a user guide
  get hasUserGuide() {
    console.log('productMedia:'+JSON.stringify(this._productMedia));
    return (this._productMedia!=undefined);
    //return this._userGuide?.length > 0 ? true : false;
  }

  // If hasUserGuide is true, this link is displayed in the "Description" column
  get userGuideURL() {
    
    return this.hasUserGuide ?  '/ppg/s/sfsites/c'+this._productMedia.url : "";
  }

  // If hasUserGuide is true, this text is used for link in userGuideUrl()
  get userGuideTitle() {
    return this.hasUserGuide ? this._productMedia.title : "";
  }

  // Product2.NATT_SignalCode__c - Mostly used to show specific messages in the "Description" column for edge cases
  
  get signalCode() {
    return this._product?.fields?.NATT_SignalCode__c?.value;
  }
  _signalCodeMessages = new Map([
    [
      "S2",
      {
        descriptionMessage:
          '<p>This Part has been Superseded</p>',
        validationStatus: "Superseded Part Not Setup"
      }
    ],
    [
      "NSU",
      {
        descriptionMessage:
        '',       
        validationStatus: "Blocked"
      }
    ]
  ]);
  get signalCodeMessage() {
    
    const warehouse = this._clickedWarehouse;
    const whSignalCode = this._getWarehouseSignalCode();

    // For PAN/ANA with S1, suppress message (treated as normal product)
    if ((warehouse === "PAN" || warehouse === "ANA") && whSignalCode === "S1") {
      return "";
    }


    if (this._signalCodeMessages.has(this.signalCode)) {
      //If NSU signal code, update description message with Invalid Part
      if(this.signalCode == 'NSU'){
        this._signalCodeMessages.get(this.signalCode).descriptionMessage = '<p>Invalid Part</p>';
        return this._signalCodeMessages.get(this.signalCode).descriptionMessage;
      }else{
        return this._signalCodeMessages.get(this.signalCode).descriptionMessage;
      }
    }
    return "";
  }
  get hasSignalCodeMessage() {
    return this._signalCodeMessages.has(this.signalCode);
  }
  get signalCodeValidationStatus() {
    // PAN/ANA + S1 should never show "Superseded" or "Blocked"
    const warehouse = this._clickedWarehouse;
    const whSignalCode = this._getWarehouseSignalCode();
    if ((warehouse === "PAN" || warehouse === "ANA") && whSignalCode === "S1") {
      return ""; // treat as normal product
    }


    if (this._signalCodeMessages.has(this.signalCode)) {
      return this._signalCodeMessages.get(this.signalCode).validationStatus;
    }

    return "";
  }

  // Product2.NATT_Sales_Code__c - Mostly used to show specific messages in the "Description" column for edge cases
  get salesCode() {
    return this._product?.fields?.NATT_Sales_Code__c?.value;
  }
  _salesCodeMessages = new Map([
    [
      "SB1",
      {
        descriptionMessage:
          '<p>Check again in 24 hours or Contact Customer service for availability</p>',
        validationStatus: "Valid Part"
      }
    ],
    [
      "SM1",
      {
        descriptionMessage:
          '<p>Check again in 24 hours or Contact Customer service for availability</p>',
        validationStatus: "Valid Part"
      }
    ],
    [
      "MC1",
      {
        descriptionMessage:
          "<p>Check again in 24 hours or Contact Customer service for availability</p>",
        validationStatus: "Blocked"
      }
    ]
  ]);
  get salesCodeMessage() {
    if (this._salesCodeMessages.has(this.salesCode)) {
      return this._salesCodeMessages.get(this.salesCode).descriptionMessage;
    }

    return "";
  }
  get hasSalesCodeMessage() {
    return this._salesCodeMessages.has(this.salesCode);
  }
  get salesCodeValidationStatus() {
    if (this._salesCodeMessages.has(this.salesCode)) {
      return this._salesCodeMessages.get(this.salesCode).validationStatus;
    }

    return "";
  }

  get notOrderableValidationStatus() {
    if (this.notOrderableCheck==="true" ) {
      return "true" ;
    }

    return "";
  }

  

  get hasCoreCharge() {
    //console.log('calling hasCoreCharge:'+this._product?.fields?.NATT_CoreCharge__c?.value);
    return this._product?.fields?.NATT_CoreCharge__c?.value === "true";
  }

  get corePrice() {
    if(this._coreProductPrice){
      return this._formatter.format(this._coreProductPrice);
    }else{
      return 0.00;
    }
  }

  get notOrderableCheck() {

    console.log(' Inside notOrderableCheck'+ this._clickedWarehouse);
      if(this._clickedWarehouse=== "ATL" && this._product?.fields?.NAOCAP_Not_Orderable__c?.value === "true"){
          
       
        return this._product?.fields?.NAOCAP_Not_Orderable__c?.value ;
     }
    else if (this._clickedWarehouse=== "ANA" && this._product?.fields?.NAOCAP_Not_Orderable_ANA__c?.value === "true") {
       
      return this._product?.fields?.NAOCAP_Not_Orderable_ANA__c?.value ; 

    }else if (this._clickedWarehouse=== "CHI" && this._product?.fields?.NAOCAP_Not_Orderable_CHI__c?.value === "true"){
    
      return this._product?.fields?.NAOCAP_Not_Orderable_CHI__c?.value ; 
     
    } else if(this._clickedWarehouse=== "PAN" && this._product?.fields?.NAOCAP_Not_Orderable_PAN__c?.value === "true"){
    
      
      return this._product?.fields?.NAOCAP_Not_Orderable_PAN__c?.value ; 
    } else {
       return "false" ;

    }
  }

  get coreItemPartNumber() {
    return this._product?.fields?.NATT_CoreItem_P_N__c?.value;
  }

  get hasPriceAdjustmentTiers(){
    //console.log('hasQuanityBreak:'+(this._product?.purchaseQuantityRule!=undefined));
    return (this._productPrice?.priceAdjustment?.priceAdjustmentTiers!=undefined);
  }

  get priceAdjustmentTiers(){    
    return this._productPrice?.priceAdjustment?.priceAdjustmentTiers;
  }
}