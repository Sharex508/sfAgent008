public with sharing class NattTesAvalaraTaxResponse {
    @AuraEnabled
    public Error error {get;set;} 
    public Integer id {get;set;} 
	public String code {get;set;} 
	public Integer companyId {get;set;} 
	public String date_Z {get;set;} // in json: date
	public String paymentDate {get;set;} 
	public String status {get;set;} 
	public String type {get;set;} 
	public String batchCode {get;set;} 
	public String currencyCode {get;set;} 
	public String exchangeRateCurrencyCode {get;set;} 
	public String customerUsageType {get;set;} 
	public String entityUseCode {get;set;} 
	public String customerVendorCode {get;set;} 
	public String customerCode {get;set;} 
	public String exemptNo {get;set;} 
	public Boolean reconciled {get;set;} 
	public String locationCode {get;set;} 
	public String reportingLocationCode {get;set;} 
	public String purchaseOrderNo {get;set;} 
	public String referenceCode {get;set;} 
	public String salespersonCode {get;set;} 
	public Double totalAmount {get;set;} 
	public Double totalExempt {get;set;} 
	public Double totalDiscount {get;set;} 
    @AuraEnabled    
	public Double totalTax {get;set;} 
	public Double totalTaxable {get;set;} 
	public Double totalTaxCalculated {get;set;} 
	public String adjustmentReason {get;set;} 
	public Boolean locked {get;set;} 
	public Integer version {get;set;} 
	public String exchangeRateEffectiveDate {get;set;} 
	public Double exchangeRate {get;set;} 
	public String modifiedDate {get;set;} 
	public Integer modifiedUserId {get;set;} 
	public String taxDate {get;set;} 
	public List<Lines> lines {get;set;} 
	public List<Addresses> addresses {get;set;} 
	public List<Summary> summary {get;set;} 

    public class Addresses {
		public Integer id {get;set;} 
		public Integer transactionId {get;set;} 
		public String boundaryLevel {get;set;} 
		public String line1 {get;set;} 
		public String line2 {get;set;} 
		public String line3 {get;set;} 
		public String city {get;set;} 
		public String region {get;set;} 
		public String postalCode {get;set;} 
		public String country {get;set;} 
		public Integer taxRegionId {get;set;} 
		public String latitude {get;set;} 
		public String longitude {get;set;} 

		public Addresses(JSONParser parser) {
			while (parser.nextToken() != System.JSONToken.END_OBJECT) {
				if (parser.getCurrentToken() == System.JSONToken.FIELD_NAME) {
					String text = parser.getText();
					if (parser.nextToken() != System.JSONToken.VALUE_NULL) {
						if (text == 'id') {
							id = parser.getIntegerValue();
						} else if (text == 'transactionId') {
							transactionId = parser.getIntegerValue();
						} else if (text == 'boundaryLevel') {
							boundaryLevel = parser.getText();
						} else if (text == 'line1') {
							line1 = parser.getText();
						} else if (text == 'line2') {
							line2 = parser.getText();
						} else if (text == 'line3') {
							line3 = parser.getText();
						} else if (text == 'city') {
							city = parser.getText();
						} else if (text == 'region') {
							region = parser.getText();
						} else if (text == 'postalCode') {
							postalCode = parser.getText();
						} else if (text == 'country') {
							country = parser.getText();
						} else if (text == 'taxRegionId') {
							taxRegionId = parser.getIntegerValue();
						} else if (text == 'latitude') {
							latitude = parser.getText();
						} else if (text == 'longitude') {
							longitude = parser.getText();
						} else {
							System.debug(LoggingLevel.WARN, 'Addresses consuming unrecognized property: '+text);
							consumeObject(parser);
						}
					}
				}
			}
		}
	}
	
	public class Details {
		public Integer id {get;set;} 
		public Integer transactionLineId {get;set;} 
		public Integer transactionId {get;set;} 
		public String country {get;set;} 
		public String region {get;set;} 
		public Double exemptAmount {get;set;} 
		public String jurisCode {get;set;} 
		public String jurisName {get;set;} 
		public String stateAssignedNo {get;set;} 
		public String jurisType {get;set;} 
		public String jurisdictionType {get;set;} 
		public Double nonTaxableAmount {get;set;} 
		public Double rate {get;set;} 
		public Double tax {get;set;} 
		public Double taxableAmount {get;set;} 
		public String taxType {get;set;} 
		public String taxSubTypeId {get;set;} 
		public String taxName {get;set;} 
		public Integer taxAuthorityTypeId {get;set;} 
		public Double taxCalculated {get;set;} 
		public String rateType {get;set;} 
		public String rateTypeCode {get;set;} 
		public String unitOfBasis {get;set;} 
		public Boolean isNonPassThru {get;set;} 
		public Boolean isFee {get;set;} 
		public Double reportingTaxableUnits {get;set;} 
		public Double reportingNonTaxableUnits {get;set;} 
		public Double reportingExemptUnits {get;set;} 
		public Double reportingTax {get;set;} 
		public Double reportingTaxCalculated {get;set;} 
		public String liabilityType {get;set;} 
        public String code {get;set;} 
		public Integer number_Z {get;set;} // in json: number
		public String message {get;set;} 
		public String description {get;set;} 
		public String faultCode {get;set;} 
		public String faultSubCode {get;set;} 
		public String helpLink {get;set;} 
		public String refersTo {get;set;} 
		public String severity {get;set;} 

		public Details(JSONParser parser) {
			while (parser.nextToken() != System.JSONToken.END_OBJECT) {
				if (parser.getCurrentToken() == System.JSONToken.FIELD_NAME) {
					String text = parser.getText();
					if (parser.nextToken() != System.JSONToken.VALUE_NULL) {
						if (text == 'id') {
							id = parser.getIntegerValue();
						} else if (text == 'transactionLineId') {
							transactionLineId = parser.getIntegerValue();
						} else if (text == 'transactionId') {
							transactionId = parser.getIntegerValue();
						} else if (text == 'country') {
							country = parser.getText();
						} else if (text == 'region') {
							region = parser.getText();
						} else if (text == 'exemptAmount') {
							exemptAmount = parser.getDoubleValue();
						} else if (text == 'jurisCode') {
							jurisCode = parser.getText();
						} else if (text == 'jurisName') {
							jurisName = parser.getText();
						} else if (text == 'stateAssignedNo') {
							stateAssignedNo = parser.getText();
						} else if (text == 'jurisType') {
							jurisType = parser.getText();
						} else if (text == 'jurisdictionType') {
							jurisdictionType = parser.getText();
						} else if (text == 'nonTaxableAmount') {
							nonTaxableAmount = parser.getDoubleValue();
						} else if (text == 'rate') {
							rate = parser.getDoubleValue();
						} else if (text == 'tax') {
							tax = parser.getDoubleValue();
						} else if (text == 'taxableAmount') {
							taxableAmount = parser.getDoubleValue();
						} else if (text == 'taxType') {
							taxType = parser.getText();
						} else if (text == 'taxSubTypeId') {
							taxSubTypeId = parser.getText();
						} else if (text == 'taxName') {
							taxName = parser.getText();
						} else if (text == 'taxAuthorityTypeId') {
							taxAuthorityTypeId = parser.getIntegerValue();
						} else if (text == 'taxCalculated') {
							taxCalculated = parser.getDoubleValue();
						} else if (text == 'rateType') {
							rateType = parser.getText();
						} else if (text == 'rateTypeCode') {
							rateTypeCode = parser.getText();
						} else if (text == 'unitOfBasis') {
							unitOfBasis = parser.getText();
						} else if (text == 'isNonPassThru') {
							isNonPassThru = parser.getBooleanValue();
						} else if (text == 'isFee') {
							isFee = parser.getBooleanValue();
						} else if (text == 'reportingTaxableUnits') {
							reportingTaxableUnits = parser.getDoubleValue();
						} else if (text == 'reportingNonTaxableUnits') {
							reportingNonTaxableUnits = parser.getDoubleValue();
						} else if (text == 'reportingExemptUnits') {
							reportingExemptUnits = parser.getDoubleValue();
						} else if (text == 'reportingTax') {
							reportingTax = parser.getDoubleValue();
						} else if (text == 'reportingTaxCalculated') {
							reportingTaxCalculated = parser.getDoubleValue();
						} else if (text == 'liabilityType') {
							liabilityType = parser.getText();
						} else if (text == 'code') {
							code = parser.getText();
						} else if (text == 'number') {
							number_Z = parser.getIntegerValue();
						} else if (text == 'message') {
							message = parser.getText();
						} else if (text == 'description') {
							description = parser.getText();
						} else if (text == 'faultCode') {
							faultCode = parser.getText();
						} else if (text == 'faultSubCode') {
							faultSubCode = parser.getText();
						} else if (text == 'helpLink') {
							helpLink = parser.getText();
						} else if (text == 'refersTo') {
							refersTo = parser.getText();
						} else if (text == 'severity') {
							severity = parser.getText();
						}else {
							System.debug(LoggingLevel.WARN, 'Details consuming unrecognized property: '+text);
							consumeObject(parser);
						}
					}
				}
			}
		}
	}

	public NattTesAvalaraTaxResponse(JSONParser parser) {
		while (parser.nextToken() != System.JSONToken.END_OBJECT) {
			if (parser.getCurrentToken() == System.JSONToken.FIELD_NAME) {
				String text = parser.getText();
				if (parser.nextToken() != System.JSONToken.VALUE_NULL) {
					if (text == 'id') {
						id = parser.getIntegerValue();
					} else if (text == 'code') {
						code = parser.getText();
					} else if (text == 'companyId') {
						companyId = parser.getIntegerValue();
					} else if (text == 'date') {
						date_Z = parser.getText();
					} else if (text == 'paymentDate') {
						paymentDate = parser.getText();
					} else if (text == 'status') {
						status = parser.getText();
					} else if (text == 'type') {
						type = parser.getText();
					} else if (text == 'batchCode') {
						batchCode = parser.getText();
					} else if (text == 'currencyCode') {
						currencyCode = parser.getText();
					} else if (text == 'exchangeRateCurrencyCode') {
						exchangeRateCurrencyCode = parser.getText();
					} else if (text == 'customerUsageType') {
						customerUsageType = parser.getText();
					} else if (text == 'entityUseCode') {
						entityUseCode = parser.getText();
					} else if (text == 'customerVendorCode') {
						customerVendorCode = parser.getText();
					} else if (text == 'customerCode') {
						customerCode = parser.getText();
					} else if (text == 'exemptNo') {
						exemptNo = parser.getText();
					} else if (text == 'reconciled') {
						reconciled = parser.getBooleanValue();
					} else if (text == 'locationCode') {
						locationCode = parser.getText();
					} else if (text == 'reportingLocationCode') {
						reportingLocationCode = parser.getText();
					} else if (text == 'purchaseOrderNo') {
						purchaseOrderNo = parser.getText();
					} else if (text == 'referenceCode') {
						referenceCode = parser.getText();
					} else if (text == 'salespersonCode') {
						salespersonCode = parser.getText();
					} else if (text == 'totalAmount') {
						totalAmount = parser.getDoubleValue();
					} else if (text == 'totalExempt') {
						totalExempt = parser.getDoubleValue();
					} else if (text == 'totalDiscount') {
						totalDiscount = parser.getDoubleValue();
					} else if (text == 'totalTax') {
						totalTax = parser.getDoubleValue();
					} else if (text == 'totalTaxable') {
						totalTaxable = parser.getDoubleValue();
					} else if (text == 'totalTaxCalculated') {
						totalTaxCalculated = parser.getDoubleValue();
					} else if (text == 'adjustmentReason') {
						adjustmentReason = parser.getText();
					} else if (text == 'locked') {
						locked = parser.getBooleanValue();
					} else if (text == 'version') {
						version = parser.getIntegerValue();
					} else if (text == 'exchangeRateEffectiveDate') {
						exchangeRateEffectiveDate = parser.getText();
					} else if (text == 'exchangeRate') {
						exchangeRate = parser.getDoubleValue();
					} else if (text == 'modifiedDate') {
						modifiedDate = parser.getText();
					} else if (text == 'modifiedUserId') {
						modifiedUserId = parser.getIntegerValue();
					} else if (text == 'taxDate') {
						taxDate = parser.getText();
					} else if (text == 'lines') {
						lines = arrayOfLines(parser);
					} else if (text == 'addresses') {
						addresses = arrayOfAddresses(parser);
					} else if (text == 'summary') {
						summary = arrayOfSummary(parser);
					} else if (text == 'error') {
						error = new Error(parser);
					} else {
						System.debug(LoggingLevel.WARN, 'NattTesAvalaraTaxResponse consuming unrecognized property: '+text);
						consumeObject(parser);
					}                    
				}
			}
		}
	}
	
	public class NonPassthroughDetails {

		public NonPassthroughDetails(JSONParser parser) {
			while (parser.nextToken() != System.JSONToken.END_OBJECT) {
				if (parser.getCurrentToken() == System.JSONToken.FIELD_NAME) {
					String text = parser.getText();
					if (parser.nextToken() != System.JSONToken.VALUE_NULL) {
						{
							System.debug(LoggingLevel.WARN, 'NonPassthroughDetails consuming unrecognized property: '+text);
							consumeObject(parser);
						}
					}
				}
			}
		}
	}
	
	public class Summary {
		public String country {get;set;} 
		public String region {get;set;} 
		public String jurisType {get;set;} 
		public String jurisCode {get;set;} 
		public String jurisName {get;set;} 
		public Integer taxAuthorityType {get;set;} 
		public String stateAssignedNo {get;set;} 
		public String taxType {get;set;} 
		public String taxSubType {get;set;} 
		public String taxName {get;set;} 
		public String rateType {get;set;} 
		public Double taxable {get;set;} 
		public Double rate {get;set;} 
		public Double tax {get;set;} 
		public Double taxCalculated {get;set;} 
		public Double nonTaxable {get;set;} 
		public Double exemption {get;set;} 

		public Summary(JSONParser parser) {
			while (parser.nextToken() != System.JSONToken.END_OBJECT) {
				if (parser.getCurrentToken() == System.JSONToken.FIELD_NAME) {
					String text = parser.getText();
					if (parser.nextToken() != System.JSONToken.VALUE_NULL) {
						if (text == 'country') {
							country = parser.getText();
						} else if (text == 'region') {
							region = parser.getText();
						} else if (text == 'jurisType') {
							jurisType = parser.getText();
						} else if (text == 'jurisCode') {
							jurisCode = parser.getText();
						} else if (text == 'jurisName') {
							jurisName = parser.getText();
						} else if (text == 'taxAuthorityType') {
							taxAuthorityType = parser.getIntegerValue();
						} else if (text == 'stateAssignedNo') {
							stateAssignedNo = parser.getText();
						} else if (text == 'taxType') {
							taxType = parser.getText();
						} else if (text == 'taxSubType') {
							taxSubType = parser.getText();
						} else if (text == 'taxName') {
							taxName = parser.getText();
						} else if (text == 'rateType') {
							rateType = parser.getText();
						} else if (text == 'taxable') {
							taxable = parser.getDoubleValue();
						} else if (text == 'rate') {
							rate = parser.getDoubleValue();
						} else if (text == 'tax') {
							tax = parser.getDoubleValue();
						} else if (text == 'taxCalculated') {
							taxCalculated = parser.getDoubleValue();
						} else if (text == 'nonTaxable') {
							nonTaxable = parser.getDoubleValue();
						} else if (text == 'exemption') {
							exemption = parser.getDoubleValue();
						} else {
							System.debug(LoggingLevel.WARN, 'Summary consuming unrecognized property: '+text);
							consumeObject(parser);
						}
					}
				}
			}
		}
	}
	
	public class Lines {
		public Integer id {get;set;} 
		public Integer transactionId {get;set;} 
		public String lineNumber {get;set;} 
		public String customerUsageType {get;set;} 
		public String entityUseCode {get;set;} 
		public Double discountAmount {get;set;} 
		public Double exemptAmount {get;set;} 
		public Integer exemptCertId {get;set;} 
		public String exemptNo {get;set;} 
		public Boolean isItemTaxable {get;set;} 
		public String itemCode {get;set;} 
		public Double lineAmount {get;set;} 
		public Double quantity {get;set;} 
		public String ref1 {get;set;} 
		public String ref2 {get;set;} 
		public String reportingDate {get;set;} 
		public Double tax {get;set;} 
		public Double taxableAmount {get;set;} 
		public Double taxCalculated {get;set;} 
		public String taxCode {get;set;} 
		public Integer taxCodeId {get;set;} 
		public String taxDate {get;set;} 
		public Boolean taxIncluded {get;set;} 
		public List<Details> details {get;set;} 
		public List<NonPassthroughDetails> nonPassthroughDetails {get;set;} 
		public String hsCode {get;set;} 
		public Double costInsuranceFreight {get;set;} 
		public String vatCode {get;set;} 
		public Integer vatNumberTypeId {get;set;} 

		public Lines(JSONParser parser) {
			while (parser.nextToken() != System.JSONToken.END_OBJECT) {
				if (parser.getCurrentToken() == System.JSONToken.FIELD_NAME) {
					String text = parser.getText();
					if (parser.nextToken() != System.JSONToken.VALUE_NULL) {
						if (text == 'id') {
							id = parser.getIntegerValue();
						} else if (text == 'transactionId') {
							transactionId = parser.getIntegerValue();
						} else if (text == 'lineNumber') {
							lineNumber = parser.getText();
						} else if (text == 'customerUsageType') {
							customerUsageType = parser.getText();
						} else if (text == 'entityUseCode') {
							entityUseCode = parser.getText();
						} else if (text == 'discountAmount') {
							discountAmount = parser.getDoubleValue();
						} else if (text == 'exemptAmount') {
							exemptAmount = parser.getDoubleValue();
						} else if (text == 'exemptCertId') {
							exemptCertId = parser.getIntegerValue();
						} else if (text == 'exemptNo') {
							exemptNo = parser.getText();
						} else if (text == 'isItemTaxable') {
							isItemTaxable = parser.getBooleanValue();
						} else if (text == 'itemCode') {
							itemCode = parser.getText();
						} else if (text == 'lineAmount') {
							lineAmount = parser.getDoubleValue();
						} else if (text == 'quantity') {
							quantity = parser.getDoubleValue();
						} else if (text == 'ref1') {
							ref1 = parser.getText();
						} else if (text == 'ref2') {
							ref2 = parser.getText();
						} else if (text == 'reportingDate') {
							reportingDate = parser.getText();
						} else if (text == 'tax') {
							tax = parser.getDoubleValue();
						} else if (text == 'taxableAmount') {
							taxableAmount = parser.getDoubleValue();
						} else if (text == 'taxCalculated') {
							taxCalculated = parser.getDoubleValue();
						} else if (text == 'taxCode') {
							taxCode = parser.getText();
						} else if (text == 'taxCodeId') {
							taxCodeId = parser.getIntegerValue();
						} else if (text == 'taxDate') {
							taxDate = parser.getText();
						} else if (text == 'taxIncluded') {
							taxIncluded = parser.getBooleanValue();
						} else if (text == 'details') {
							details = arrayOfDetails(parser);
						} else if (text == 'nonPassthroughDetails') {
							nonPassthroughDetails = arrayOfNonPassthroughDetails(parser);
						} else if (text == 'hsCode') {
							hsCode = parser.getText();
						} else if (text == 'costInsuranceFreight') {
							costInsuranceFreight = parser.getDoubleValue();
						} else if (text == 'vatCode') {
							vatCode = parser.getText();
						} else if (text == 'vatNumberTypeId') {
							vatNumberTypeId = parser.getIntegerValue();
						} else {
							System.debug(LoggingLevel.WARN, 'Lines consuming unrecognized property: '+text);
							consumeObject(parser);
						}
					}
				}
			}
		}
	}
		
	public class Error {
        @AuraEnabled
		public String code {get;set;} 
        @AuraEnabled
		public String message {get;set;}         
		public String target {get;set;} 
        @AuraEnabled
		public List<Details> details {get;set;} 

		public Error(JSONParser parser) {
			while (parser.nextToken() != System.JSONToken.END_OBJECT) {
				if (parser.getCurrentToken() == System.JSONToken.FIELD_NAME) {
					String text = parser.getText();
					if (parser.nextToken() != System.JSONToken.VALUE_NULL) {
						if (text == 'code') {
							code = parser.getText();
						} else if (text == 'message') {
							message = parser.getText();
						} else if (text == 'target') {
							target = parser.getText();
						} else if (text == 'details') {
							details = arrayOfDetails(parser);
						} else {
							System.debug(LoggingLevel.WARN, 'Error consuming unrecognized property: '+text);
							consumeObject(parser);
						}
					}
				}
			}
		}
	}

    private static List<Details> arrayOfDetails(System.JSONParser p) {
        List<Details> res = new List<Details>();
        if (p.getCurrentToken() == null) p.nextToken();
        while (p.nextToken() != System.JSONToken.END_ARRAY) {
            res.add(new Details(p));
        }
        return res;
    }
	
	
	public static NattTesAvalaraTaxResponse parse(String json) {
		System.JSONParser parser = System.JSON.createParser(json);
		return new NattTesAvalaraTaxResponse(parser);
	}
	
	public static void consumeObject(System.JSONParser parser) {
		Integer depth = 0;
		do {
			System.JSONToken curr = parser.getCurrentToken();
			if (curr == System.JSONToken.START_OBJECT || 
				curr == System.JSONToken.START_ARRAY) {
				depth++;
			} else if (curr == System.JSONToken.END_OBJECT ||
				curr == System.JSONToken.END_ARRAY) {
				depth--;
			}
		} while (depth > 0 && parser.nextToken() != null);
	}

    private static List<Lines> arrayOfLines(System.JSONParser p) {
        List<Lines> res = new List<Lines>();
        if (p.getCurrentToken() == null) p.nextToken();
        while (p.nextToken() != System.JSONToken.END_ARRAY) {
            res.add(new Lines(p));
        }
        return res;
    }

    private static List<Addresses> arrayOfAddresses(System.JSONParser p) {
        List<Addresses> res = new List<Addresses>();
        if (p.getCurrentToken() == null) p.nextToken();
        while (p.nextToken() != System.JSONToken.END_ARRAY) {
            res.add(new Addresses(p));
        }
        return res;
    }

    private static List<Summary> arrayOfSummary(System.JSONParser p) {
        List<Summary> res = new List<Summary>();
        if (p.getCurrentToken() == null) p.nextToken();
        while (p.nextToken() != System.JSONToken.END_ARRAY) {
            res.add(new Summary(p));
        }
        return res;
    }

    private static List<NonPassthroughDetails> arrayOfNonPassthroughDetails(System.JSONParser p) {
        List<NonPassthroughDetails> res = new List<NonPassthroughDetails>();
        if (p.getCurrentToken() == null) p.nextToken();
        while (p.nextToken() != System.JSONToken.END_ARRAY) {
            res.add(new NonPassthroughDetails(p));
        }
        return res;
    }
}