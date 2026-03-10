/*
* NAME         : CustomerSummaryController
* DESCRIPTION  : Controller Class for customerSummary Component.
* Test Class   : CustomerSummaryControllerTest                   
* @AUTHOR : Prem Ranjan
* @DATE   : 05-May-2023 
* 
* MODIFICATION LOG:  
* -------------------------------------------------------------------------------------------------------------------------------------------------------------
* DEVELOPER                DATE                DESCRIPTION 
* --------------------------------------------------------------------------------------------------------------------------------------------------------------
*
*
*/
/**
* @description - CustomerSummaryController class
*/
public with sharing class CustomerSummaryController {
    private static final string  FUEL_TANK = 'Fuel Tank';
    private static final string  RELATED_OPTIONS = 'Related Options';
    private static final string  STANDARD_OPTIONS = 'Standard Sales Options';
    private static final string  NON_STANDARD_OPTIONS = 'Non-Standard Sales Options';
    private static final Decimal DECIMAL_ZERO = 0.00;
    public static Boolean isPortalUser;

    /** 
    * @description - get/return all Quote/quote associated with record id. Takes a Record Id and object api name as argument
    * @param recordId 
    * @param objName 
    * @return String Value 
    */ 
    @AuraEnabled(cacheable=true)
    public static String getRecordDetails(String recordId, String objName){
        list<User> loggedInUser = [SELECT Id, IsPortalEnabled FROM User WHERE Id =:Userinfo.getUserId()];
        isPortalUser = loggedInUser[0].IsPortalEnabled;
        if(objName == 'SBQQ__Quote__c') {
            return getQuoteRecordDetails(recordId);
        } else if(objName  == 'Order' ) {
            return getOrderRecordDetails(recordId);
        } else {
            return '';
        }
    }
    /** 
    * @description - get/return Quote details associated with quote id to update the record. Takes a quote Record Id as argument
    * @param quoteId 
    * @return String Value 
    */
    public static String getQuoteRecordDetails(String quoteId){
        String qlFuelTank = '';
        String qlFactorySuppliedOptions = '';
        String qlNonStandardOptions = '';
        SBQQ__Quote__c quoteRecord = [SELECT Id, Name, NATT_Created_Date__c, NATT_Customer_Contact__c, NATT_Customer_Contact__r.Name, 
                                    NATT_End_Customer_Company__c, NATT_End_Customer__c,
                                    NATT_End_Customer__r.NATT_Address_Billing__r.NATT_Street__c, NATT_End_Customer__r.NATT_Address_Billing__r.NATT_Country__c, NATT_End_Customer__r.NATT_Address_Billing__r.NATT_Street_2__c,
                                    NATT_End_Customer__r.NATT_Address_Billing__r.NATT_City__c, NATT_End_Customer__r.NATT_Address_Billing__r.NATT_State_Province__c,
                                    NATT_End_Customer__r.NATT_Address_Billing__r.NATT_Zip_Postal_Code__c, EC_Dealer_Comments__c,
                                    SBQQ__ExpirationDate__c, SBQQ__PrimaryContact__c, SBQQ__PrimaryContact__r.Name, NATT_Unit__c, 
                                    NATT_Standard_Features__c,
                                    EC_Unit__c, EC_Dealer_Supplied_Options__c, EC_Warranty__c, EC_Performance_Data__c, EC_Dealer_Installed_Options__c,
                                    EC_Fuel__c, EC_Non_Standard_Options__c, EC_Miscellaneous_Prep__c, EC_Installation__c, EC_Applicable_Taxes__c, EC_Total_Installed_Packages__c
                                    FROM SBQQ__Quote__c 
                                    WHERE Id = :quoteId limit 1];
        for(SBQQ__QuoteLine__c quoteLine : [SELECT Id, SBQQ__Product__r.name ,SBQQ__ProductOption__r.SBQQ__Feature__r.name, 
                                            NATT_Feature_Category__c
                                            FROM SBQQ__QuoteLine__c 
                                            WHERE SBQQ__Quote__c =:quoteId]) {
            if(quoteLine.SBQQ__ProductOption__r.SBQQ__Feature__r.name == FUEL_TANK){
                qlFuelTank = qlFuelTank ==''? quoteLine.SBQQ__Product__r.name : qlFuelTank +',' +'\r\n' +quoteLine.SBQQ__Product__r.name;
            } else if(quoteLine.NATT_Feature_Category__c == RELATED_OPTIONS || quoteLine.NATT_Feature_Category__c == STANDARD_OPTIONS) {
                qlFactorySuppliedOptions = qlFactorySuppliedOptions ==''? quoteLine.SBQQ__Product__r.name : qlFactorySuppliedOptions +',' +'\r\n' +quoteLine.SBQQ__Product__r.name;           
            } else if(quoteLine.NATT_Feature_Category__c == NON_STANDARD_OPTIONS) {
                qlNonStandardOptions = qlNonStandardOptions ==''? quoteLine.SBQQ__Product__r.name : qlNonStandardOptions +',' +'\r\n' +quoteLine.SBQQ__Product__r.name;
            
            }
        }
                DataOutputWrapper quoteWrapper = new DataOutputWrapper();
                quoteWrapper.isPortalUser = isPortalUser;
                quoteWrapper.id = quoteRecord.Id;
                quoteWrapper.createdDate = quoteRecord.NATT_Created_Date__c;
                quoteWrapper.customerContact = quoteRecord.NATT_Customer_Contact__r.Name;
                quoteWrapper.customerCompany = quoteRecord.NATT_End_Customer_Company__c;
                quoteWrapper.address1 = quoteRecord.NATT_End_Customer__r.NATT_Address_Billing__r.NATT_Street__c;
                quoteWrapper.address2 = quoteRecord.NATT_End_Customer__r.NATT_Address_Billing__r.NATT_Street_2__c;
                quoteWrapper.city = quoteRecord.NATT_End_Customer__r.NATT_Address_Billing__r.NATT_City__c;
                quoteWrapper.state = quoteRecord.NATT_End_Customer__r.NATT_Address_Billing__r.NATT_State_Province__c;
                quoteWrapper.code = quoteRecord.NATT_End_Customer__r.NATT_Address_Billing__r.NATT_Zip_Postal_Code__c;
                quoteWrapper.dealerComment = quoteRecord.EC_Dealer_Comments__c;
                quoteWrapper.quoteNumber = quoteRecord.Name;
                quoteWrapper.quoteExpires = quoteRecord.SBQQ__ExpirationDate__c;
                quoteWrapper.dealerContact = quoteRecord.SBQQ__PrimaryContact__r.Name;
                quoteWrapper.model = quoteRecord.NATT_Unit__c;
                quoteWrapper.standardFeatures = quoteRecord.NATT_Standard_Features__c;
                quoteWrapper.fuelTank = qlFuelTank;
                quoteWrapper.factorySuppliedOption = qlFactorySuppliedOptions;
                quoteWrapper.dealerSuppliedOption = quoteRecord.EC_Dealer_Supplied_Options__c;
                quoteWrapper.nonStandardSuppliedOption = qlNonStandardOptions;
                quoteWrapper.warranty = quoteRecord.EC_Warranty__c;
                quoteWrapper.performanceData = quoteRecord.EC_Performance_Data__c;
                quoteWrapper.unit = (quoteRecord.EC_Unit__c == null) ? DECIMAL_ZERO : quoteRecord.EC_Unit__c;
                quoteWrapper.dealerInstalledOptions = (quoteRecord.EC_Dealer_Installed_Options__c == null) ? DECIMAL_ZERO : quoteRecord.EC_Dealer_Installed_Options__c;
                quoteWrapper.fuel = (quoteRecord.EC_Fuel__c == null) ? DECIMAL_ZERO : quoteRecord.EC_Fuel__c;
                quoteWrapper.nonStandardOptions = (quoteRecord.EC_Non_Standard_Options__c == null) ? DECIMAL_ZERO : quoteRecord.EC_Non_Standard_Options__c;
                quoteWrapper.miscellaneousPrep = (quoteRecord.EC_Miscellaneous_Prep__c == null) ? DECIMAL_ZERO : quoteRecord.EC_Miscellaneous_Prep__c;
                quoteWrapper.installation = (quoteRecord.EC_Installation__c == null) ? DECIMAL_ZERO : quoteRecord.EC_Installation__c;
                quoteWrapper.applicableTaxes = (quoteRecord.EC_Applicable_Taxes__c == null) ? DECIMAL_ZERO : quoteRecord.EC_Applicable_Taxes__c;
                quoteWrapper.totalInstalledPackages = (quoteRecord.EC_Total_Installed_Packages__c == null) ? DECIMAL_ZERO : quoteRecord.EC_Total_Installed_Packages__c;

        return JSON.serialize(quoteWrapper);
    }
    /** 
    * @description - get/return Order details associated with order id to update the record. Takes a order Record Id as argument
    * @param orderId 
    * @return String Value 
    */
    public static String getOrderRecordDetails(String orderId){
        String qlFuelTank = '';
        String qlFactorySuppliedOptions = '';
        String qlNonStandardOptions = '';
        Order orderRecord = [SELECT Id, SBQQ__Quote__r.Name, SBQQ__Quote__r.NATT_Created_Date__c, NATT_CustomerName__c , 
                            NATT_End_Customer__r.NATT_Company_Legal_name__c,NATT_End_Customer__c, SBQQ__Quote__r.NATT_Customer_Contact__r.Name,
                            NATT_End_Customer__r.NATT_Address_Billing__r.NATT_Street__c, NATT_End_Customer__r.NATT_Address_Billing__r.NATT_Country__c, NATT_End_Customer__r.NATT_Address_Billing__r.NATT_Street_2__c,
                            NATT_End_Customer__r.NATT_Address_Billing__r.NATT_City__c, NATT_End_Customer__r.NATT_Address_Billing__r.NATT_State_Province__c,
                            NATT_End_Customer__r.NATT_Address_Billing__r.NATT_Zip_Postal_Code__c, EC_Dealer_Comments__c,
                            SBQQ__Quote__r.SBQQ__ExpirationDate__c, SBQQ__Quote__r.SBQQ__PrimaryContact__c, SBQQ__Quote__r.SBQQ__PrimaryContact__r.Name, NATT_Unit__c, 
                            NATT_Standard_Features__c,
                            EC_Unit__c, EC_Dealer_Supplied_Options__c, EC_Warranty__c, EC_Performance_Data__c, EC_Dealer_Installed_Options__c,
                            EC_Fuel__c, EC_Non_Standard_Options__c, EC_Miscellaneous_Prep__c, EC_Installation__c, EC_Applicable_Taxes__c, EC_Total_Installed_Packages__c
                            FROM Order 
                            WHERE Id = :orderId limit 1 ];

        for(OrderItem orderLine : [SELECT Id, NATT_Product_Name__c, NATT_Feature_Category__c, 
                                        SBQQ__QuoteLine__r.SBQQ__ProductOption__r.SBQQ__Feature__r.name  
                                        FROM OrderItem 
                                        WHERE OrderId =:orderId]) {
            if(orderLine.SBQQ__QuoteLine__r.SBQQ__ProductOption__r.SBQQ__Feature__r.name == FUEL_TANK){
                qlFuelTank = qlFuelTank ==''? orderLine.NATT_Product_Name__c : qlFuelTank +',' +'\r\n' +orderLine.NATT_Product_Name__c;
            } else if(orderLine.NATT_Feature_Category__c == RELATED_OPTIONS || orderLine.NATT_Feature_Category__c == STANDARD_OPTIONS) {
                qlFactorySuppliedOptions = qlFactorySuppliedOptions ==''? orderLine.NATT_Product_Name__c : qlFactorySuppliedOptions +',' +'\r\n' +orderLine.NATT_Product_Name__c;           
            } else if(orderLine.NATT_Feature_Category__c == NON_STANDARD_OPTIONS) {
                qlNonStandardOptions = qlNonStandardOptions ==''? orderLine.NATT_Product_Name__c : qlNonStandardOptions +',' +'\r\n' +orderLine.NATT_Product_Name__c;
            
            }
        }

                DataOutputWrapper orderWrapper = new DataOutputWrapper();
                orderWrapper.isPortalUser = isPortalUser;
                orderWrapper.id = orderRecord.Id;
                orderWrapper.createdDate = orderRecord.SBQQ__Quote__r.NATT_Created_Date__c;
                orderWrapper.customerContact = orderRecord.SBQQ__Quote__r.NATT_Customer_Contact__r.Name;
                orderWrapper.customerCompany = orderRecord.NATT_End_Customer__r.NATT_Company_Legal_name__c;
                orderWrapper.address1 = orderRecord.NATT_End_Customer__r.NATT_Address_Billing__r.NATT_Street__c;
                orderWrapper.address2 = orderRecord.NATT_End_Customer__r.NATT_Address_Billing__r.NATT_Street_2__c;
                orderWrapper.city = orderRecord.NATT_End_Customer__r.NATT_Address_Billing__r.NATT_City__c;
                orderWrapper.state = orderRecord.NATT_End_Customer__r.NATT_Address_Billing__r.NATT_State_Province__c;
                orderWrapper.code = orderRecord.NATT_End_Customer__r.NATT_Address_Billing__r.NATT_Zip_Postal_Code__c;
                orderWrapper.dealerComment = orderRecord.EC_Dealer_Comments__c;
                orderWrapper.quoteNumber = orderRecord.SBQQ__Quote__r.Name;
                orderWrapper.quoteExpires = orderRecord.SBQQ__Quote__r.SBQQ__ExpirationDate__c;
                orderWrapper.dealerContact = orderRecord.SBQQ__Quote__r.SBQQ__PrimaryContact__r.Name;
                orderWrapper.model = orderRecord.NATT_Unit__c;
                orderWrapper.standardFeatures = orderRecord.NATT_Standard_Features__c;
                orderWrapper.fuelTank = qlFuelTank;
                orderWrapper.factorySuppliedOption = qlFactorySuppliedOptions;
                orderWrapper.dealerSuppliedOption = orderRecord.EC_Dealer_Supplied_Options__c;
                orderWrapper.nonStandardSuppliedOption = qlNonStandardOptions;
                orderWrapper.warranty = orderRecord.EC_Warranty__c;
                orderWrapper.performanceData = orderRecord.EC_Performance_Data__c;
                orderWrapper.unit = (orderRecord.EC_Unit__c == null) ? DECIMAL_ZERO : orderRecord.EC_Unit__c;
                orderWrapper.dealerInstalledOptions = (orderRecord.EC_Dealer_Installed_Options__c == null) ? DECIMAL_ZERO : orderRecord.EC_Dealer_Installed_Options__c;
                orderWrapper.fuel = (orderRecord.EC_Fuel__c == null) ? DECIMAL_ZERO : orderRecord.EC_Fuel__c;
                orderWrapper.nonStandardOptions = (orderRecord.EC_Non_Standard_Options__c == null) ? DECIMAL_ZERO : orderRecord.EC_Non_Standard_Options__c;
                orderWrapper.miscellaneousPrep = (orderRecord.EC_Miscellaneous_Prep__c == null) ? DECIMAL_ZERO : orderRecord.EC_Miscellaneous_Prep__c;
                orderWrapper.installation = (orderRecord.EC_Installation__c == null) ? DECIMAL_ZERO : orderRecord.EC_Installation__c;
                orderWrapper.applicableTaxes = (orderRecord.EC_Applicable_Taxes__c == null) ? DECIMAL_ZERO : orderRecord.EC_Applicable_Taxes__c;
                orderWrapper.totalInstalledPackages = (orderRecord.EC_Total_Installed_Packages__c == null) ? DECIMAL_ZERO : orderRecord.EC_Total_Installed_Packages__c;

        return JSON.serialize(orderWrapper);
    }

    /** 
    * @description - updates the details associated with respectinve object. Takes a order Record Id, object JSON string and Object api name as argument
    * @param objJSON 
    * @param objName 
    */
    @AuraEnabled
    public static void updateRecord( String objJSON, String objName){
        //system.debug('objJSON--->'+objJSON);
        //system.debug('objName--->'+objName);
        if(objName == 'SBQQ__Quote__c') {
            SBQQ__Quote__c finalRecordToUpdate = (SBQQ__Quote__c)JSON.deserialize(objJSON,SBQQ__Quote__c.class);
            updateQuoteRecordDetails(finalRecordToUpdate);
        } else if(objName  == 'Order' ) {
            Order finalRecordToUpdate = (Order)JSON.deserialize(objJSON,Order.class);
            updateOrderRecordDetails(finalRecordToUpdate);
        }

    }

    /** 
    * @description - update Quote details. Takes a quote Record Id and Quote object as argument
    * @param quoteRecord 
    */
    public static void updateQuoteRecordDetails(SBQQ__Quote__c quoteRecord){
        //system.debug('quoteId--->'+quoteId);
        //system.debug('quoteRecord--->'+quoteRecord);
        if(quoteRecord != null && Schema.sObjectType.SBQQ__Quote__c.isUpdateable()){
            update quoteRecord;
        }

    }

    /** 
    * @description - update Order details. Takes a Order Record Id and Quote object as argument
    * @param orderRecord 
    */
    public static void updateOrderRecordDetails(Order orderRecord){
        //system.debug('quoteId--->'+orderId);
        //system.debug('quoteRecord--->'+orderRecord);
        if(orderRecord != null && Schema.sObjectType.Order.isUpdateable()){
            update orderRecord;
        }

    }

    /** 
    * @description - wrapper class with @AuraEnabled and {get;set;} properties  
    */
    public class DataOutputWrapper{
        /**
        * @description - gets/sets isPortalUser
        */
        @AuraEnabled public Boolean isPortalUser{ get; set; }
        /**
        * @description - gets/sets id
        */
        @AuraEnabled public string id{ get; set; }
        /**
        * @description - gets/sets createdDate
        */
        @AuraEnabled public Date createdDate{ get; set; }
        /**
        * @description - gets/sets customerContact
        */
        @AuraEnabled public string customerContact{ get; set; }
        /**
        * @description - gets/sets customerCompany
        */
        @AuraEnabled public string customerCompany{ get; set; }
        /**
        * @description - gets/sets address1
        */
        @AuraEnabled public string address1{ get; set; }
        /**
        * @description - gets/sets address2
        */
        @AuraEnabled public string address2{ get; set; }
        /**
        * @description - gets/sets city
        */
        @AuraEnabled public string city{ get; set; }
        /**
        * @description - gets/sets state
        */
        @AuraEnabled public string state{ get; set; }
        /**
        @description - gets/sets code
        */
        @AuraEnabled public string code{ get; set; }
        /**
        * @description - gets/sets dealerComment
        */
        @AuraEnabled public string dealerComment{ get; set; }
        /**
        * @description - gets/sets quoteNumber
        */
        @AuraEnabled public string quoteNumber{ get; set; }
        /**
        * @description - gets/sets quoteExpires
        */
        @AuraEnabled public Date quoteExpires{ get; set; }
        /**
        * @description - gets/sets dealerContact
        */
        @AuraEnabled public string dealerContact{ get; set; }
        /**
        * @description - gets/sets model
        */
        @AuraEnabled public string model{ get; set;}
        /**
        * @description - gets/sets standardFeatures
        */
        @AuraEnabled public string standardFeatures{ get; set; }
        /**
        * @description - gets/sets fuelTank
        */
        @AuraEnabled public string fuelTank{ get; set; }
        /**
        * @description - gets/sets factorySuppliedOption
        */
        @AuraEnabled public string factorySuppliedOption{ get; set; }
        /**
        * @description - gets/sets dealerSuppliedOption
        */
        @AuraEnabled public string dealerSuppliedOption{ get; set; }
        /**
        * @description - gets/sets nonStandardSuppliedOption
        */
        @AuraEnabled public string nonStandardSuppliedOption{ get; set; }
        /**
        * @description - gets/sets warranty
        */
        @AuraEnabled public string warranty{ get; set; }
        /**
        * @description - gets/sets performanceData
        */
        @AuraEnabled public string performanceData{ get; set; } 
        /**
        * @description - gets/sets unit
        */
        @AuraEnabled public Decimal unit{ get; set; }
        /**
        * @description - gets/sets dealerInstalledOptions
        */
        @AuraEnabled public Decimal dealerInstalledOptions{ get; set; }
        /**
        * @description - gets/sets fuel
        */
        @AuraEnabled public Decimal fuel{ get; set; }
        /**
        * @description - gets/sets nonStandardOptions
        */
        @AuraEnabled public Decimal nonStandardOptions{ get; set; }
        /**
        * @description - gets/sets miscellaneousPrep
        */
        @AuraEnabled public Decimal miscellaneousPrep{ get; set; }
        /**
        * @description - gets/sets applicableTaxes
        */
        @AuraEnabled public Decimal installation{ get; set; }
        /**
        * @description - gets/sets applicableTaxes
        */
        @AuraEnabled public Decimal applicableTaxes{ get; set; }
        /**
        * @description - gets/sets totalInstalledPackages
        */
        @AuraEnabled public Decimal totalInstalledPackages{ get; set; }
    }
}