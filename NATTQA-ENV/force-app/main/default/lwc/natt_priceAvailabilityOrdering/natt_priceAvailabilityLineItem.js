import getCommunityUrl from "@salesforce/apex/NATT_PriceAvailabilityController.getSolutionCenterURL";


export default class natt_priceAvailabilityLineItem {

  // connectedCallback() {
  //   console.log('Connected Callback trigger');
  //   getCommunityUrl()
  //   .then((result) => {
  //    console.log('URL ADDRESS: ' + result);
  //   })
  // }

  // Formatter used to display listPrice() correctly in the "List Price" column
  _formatter = new Intl.NumberFormat("en-US", {
    style: "currency",
    currency: "USD"
  });

  /***
   * @type {ConnectApi.ProductSearchResults} from NATT_B2BGetInfo.productSearch */
  _product;
  /***
   * @type {List<NATT_ProductItem__c>} from NATT_PriceAvailabilityController.getAvailable */
  _available;
  /***
   * @type {List<ContentDocument>} from NATT_PriceAvailabilityController.getUserGuide */
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
   * @type {string} The Carrier SolutionCenter URL
   */
  _solutionCenterUrl;

  _productPrice;

  _coreProductPrice;

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
    solutionCenterUrl,
    productPrice,
    coreProductPrice
  ) {
    this._product = product;
    this._available = available;
    this._history = history;
    this._userGuide = userGuide;
    this._rowNumber = rowNumber;
    this._supersededPartNumber = supersededPartNumber;
    this._corePartProductId = corePartProductId;
    this._solutionCenterUrl = solutionCenterUrl;
    this._productPrice = productPrice;
    this._coreProductPrice = coreProductPrice;
    // _isEmpty should only be true for "empty" lines that are generated in natt_priceAvailabilityOrdering.js
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
  // This is manipulated in natt_priceAvailabilityOrdering.handleEnterAvailability and natt_priceAvailabilityOrdering.handleLeaveAvailability
  _showAvailability;
  /*get showAvailability() {
    return (
      !this.isEmpty &&
      this.available !== "Direct Delivery" &&
      Date.parse(this.availableDate) > new Date() &&
      this._showAvailability
    );
  }*/
  get showAvailability() {
    const currentDate = new Date();
    // Format date to yyyy-mm-dd
    const formattedDate = currentDate.toISOString().split('T')[0];
    return (
      !this.isEmpty &&
      this.available !== "Direct Delivery" &&
      (this.avlDate >= formattedDate || this.avlDate<=formattedDate)  &&
      this._showAvailability
    );
  }

  set showAvailability(value) {
    this._showAvailability = value;
  }

  // Displayed in the "Availability" column
  // Vinayanaparthisai NSI availability
/*  get available() {
    return this._product?.fields?.NATT_DirectDelivery__c?.value === "true"
      ? "Direct Delivery"
      : this._product?.fields?.NATT_SignalCode__c?.value === "NSI"
      //? this._available?.NATT_NSI_Availability__c
      ? this._available?.NATT_NSI_Availability__c.replace('(',`).replace(')','')
      : this._available?.NATT_AvailableQuantity__c;
  } */
  get available() {
    console.log('this._product--'+ JSON.stringify(this._product));
    if (this._product?.fields?.NATT_DirectDelivery__c?.value === "true") {
        return "Direct Delivery";
    } else if (this._product?.fields?.NATT_SignalCode__c?.value === "NSI") {
        return this._available?.NATT_NSI_Availability__c?.replace('(', '\n').replace(')', '');
    } else {
        return this._available?.NATT_AvailableQuantity__c;
  }
}

  get avlDate(){
    let availDate = this._available?.NATT_AvailabilityDate__c;
    const dateObject = new Date(availDate);
    return availDate;
  }


  // Displayed in the tooltip when user hovers mouse over "Availability" column value
// Displayed in the tooltip when user hovers mouse over "Availability" column value
get availableDate() {
  let AvailDate = new Date(Date.parse(this._available?.NATT_AvailabilityDate__c));
  let Difference_In_Time = AvailDate.getTime() - new Date().getTime();
  let TodaysDate = new Date();
  // Calculate the number of days between the current date and the availability date.
  let Difference_In_Days = Math.round(Difference_In_Time / (1000 * 3600 * 24));
  console.log("Difference_In_Days: " + Difference_In_Days);

  // Get the availability date as a string.
  let dateString = this._available?.NATT_AvailabilityDate__c;
  //console.log("Date: " + dateString);
  const dateObj = new Date(dateString);
  const formattedDate = `${("0" + (dateObj.getMonth() + 1)).slice(-2)}-${("0" + dateObj.getDate()).slice(-2)}-${dateObj.getFullYear()}`;
  //console.log("Formated Date: " + formattedDate);
  let message = '';

  if (this._available?.NATT_AvailableQuantity__c === 0 && Difference_In_Days > 45) {
      message = "<p>More Expected:</p><p>Call for availability</p>";
      console.log("No Stock with greater than 45 days");
  }
  else if(this._available?.NATT_AvailableQuantity__c != 0 && Difference_In_Days > 45){
    message = "<p>More Expected:</p><p>Call for availability</p>";
    console.log("No Stock with greater than 45 days");
  }
  else if(AvailDate < TodaysDate){
    message = "<p>More Expected:</p><p>Call for availability</p>";
    
  } else {
      console.log("Less than 45 days");
      message = `<p>More Expected:</p><p>${formattedDate}</p>`;
}

  console.log("Message: " + message);
  return message;
}



  // Value for History is passed in by NATT_PriceAvailabilityController.getHistory
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

  /* Unit cost from the searchProductResponse, used for transfer price for internal customers
  get transferPrice() {
    return this._product?.prices?.unitPrice
      ? this._formatter.format(this._product.prices.unitPrice)
      : "";
  }*/

  // Product2.Name - Displayed in the "Description" column
  get description() {
    return this._product?.fields?.Name?.value;
  }

  // This is a mapping from Product2.NATT_ItemPriceGroup__c to a display
  // value shown to the user in the "Discount Code" column
  /*get itemPriceGroup() {
    let returnValue = "";
    if (!this._product) {
      return returnValue;
    }
    switch (this._product?.fields?.NATT_ItemPriceGroup__c?.value) {
      case "114":
        returnValue = "C";
        break;
      case "111":
        returnValue = "D";
        break;
      case "112":
        returnValue = "E";
        break;
      case "226":
        returnValue = "E";
        break;
      case "110":
        returnValue = "G";
        break;
      case "115":
        returnValue = "G";
        break;
      case "116":
        returnValue = "G";
        break;
      case "123":
        returnValue = "N";
        break;
      case "129":
        returnValue = "N";
        break;
      default:
        returnValue = "A";
        break;
    }

    return returnValue;
  }*/

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
  // This is manipulated in natt_priceAvailabilityOrdering.handleEnterWeightsAndDimensions and natt_priceAvailabilityOrdering.handleLeaveWeightsAndDimensions
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

  // Referenced in natt_priceAvailabilityOrdering.html to determine if the
  // Part history icon should be clickable
  get disableHistory() {
    return this._history && this._history.length > 1 ? false : true;
  }

  // Referenced/Displayed in the Parts History modal in natt_priceAvailabilityOrdering.html
  get finalPartNumber() {
    return this.disableHistory ? "" : this._history[0]?.NATT_P_N__c;
  }

  // Determines if a part has been superceded
  // (if it is, then natt_priceAvailabilityOrder.js reloads the line with alternative product)
  get isSuperseded() {
    let signalCode = this._product?.fields?.NATT_SignalCode__c?.value;
    if(signalCode && signalCode!='S1'){
      return (
        this.partNumber !== "" &&
        this.finalPartNumber !== "" &&
        this.partNumber !== this.finalPartNumber
      );
    }else{
      return false;
    }
  }

  // Determines if a part was loaded as an alternative to a superseded part
  // (if it is, then the html will render the old part number in the description column)
  get isAlternativePart() {
    return this._supersededPartNumber !== undefined;
  }

  get supersededPartNumber() {
    return this._supersededPartNumber;
  }

  // Referenced in natt_priceAvailabilityOrdering.html to determine if the "Description"
  // column should include a link to a user guide
  get hasUserGuide() {
    console.log('productMedia:'+JSON.stringify(this._productMedia));
    return (this._productMedia!=undefined);
    //return this._userGuide?.length > 0 ? true : false;
  }

  // If hasUserGuide is true, this link is displayed in the "Description" column
  get userGuideURL() {
    //return this.hasUserGuide ? "/ppg/sfc/servlet.shepherd/document/download/" + this._userGuide[0]?.Id : "";
    //return this.hasUserGuide ?  "/ppg/sfc/servlet.shepherd/document/download/" +this._productMedia.contentVersionId : "";
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
          '<p>Please submit a Performance Parts Case for set-up.</p><p><a href="contactsupport" target="_blank">Request set-up</a></p>',
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
    if (this._signalCodeMessages.has(this.signalCode)) {
      //If NSU signal code, update description message with dynamic carrier solutionCenter URL
      if(this.signalCode == 'NSU'){
        this._signalCodeMessages.get(this.signalCode).descriptionMessage = '<p>Please submit a Case for current price quote.</p><p><a href="' + this._solutionCenterUrl + '/s/recordlist/Case/00BP0000006H42zMAC">Request Quote</a></p>';
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
          '<p>PowerRush Batteries should be ordered via the <a href="https://orders.interstatebatteries.com/b2binterstatebatterystorefront/b2binterstatebatteries/en/USD/login.">Interstate National Accounts website</a>. See PTS16-036 for Bulk Battery ordering instructions.</p>',
        validationStatus: "Blocked"
      }
    ],
    [
      "SM1",
      {
        descriptionMessage:
          '<p>Rebuild micros cannot be ordered online. Please use the <a href="https://transicold.force.com/carriersolutioncenter/s/article/8CAD6E091AEC7CDD852575AC004A3F0E">Electronics Repair Order Form</a></p>',
        validationStatus: "Blocked"
      }
    ],
    [
      "SK1",
      {
        descriptionMessage:
          '<p>Not available from Carrier Transicold. Please contact Vintage at 877-846-8243 or email "info@vpartsinc.com" to order</p>',
        validationStatus: "Blocked"
      }
    ],
    [
      "MC1",
      {
        descriptionMessage:
          "<p>Please contact Marine Customer Service for availability of compressor cores.</a></p>",
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
  // return this._product?.NATT_CorePrice__c;
    
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