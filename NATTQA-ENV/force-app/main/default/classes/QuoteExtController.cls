public with sharing class QuoteExtController {
	public Id quoteId;
    public String errormessage {get;set;}
    public SBQQ__Quote__c quote{get;set;}
    public SBAA__Approval__c[] approvals{get;set;}
	public QuoteExtController(ApexPages.StandardController stdController) {
		quoteId = stdController.getId();
        system.debug('quoteId'+quoteId);
		errormessage = '';
	}
	public PageReference onSubmit() {
        quote = [SELECT Id, Name, ApprovalStatus__c, CONTAINER_Model_Number__c, CONTAINER_Cost_Contract_Price__c, CONTAINER_Payment_Terms__c, CONTAINER_Payment_Terms_GENSET__c, CONTAINER_Method_of_Shipment__c,
                CONTAINER_Method_of_Shipment_GENSET__c, CONTAINER_Freight_Terms__c, CONTAINER_Freight_Terms_GENSET__c, CONTAINER_Sum_Requested_Ship_Dates_Qty__c, CONTAINER_Qty__c, CONTAINER_Type__c FROM SBQQ__Quote__c WHERE Id = :quoteId LIMIT 1];
        if(quote.ApprovalStatus__c == ContainerConstants.APPROVED_STATUS){
            system.debug('Already approved');
            errormessage = ContainerConstants.APPROVED_QUOTE_ERROR_MSG;
            ApexPages.addmessage(new ApexPages.message(ApexPages.severity.ERROR,ContainerConstants.APPROVED_QUOTE_ERROR_MSG));  
            return null;
        }
        else if(quote.ApprovalStatus__c == ContainerConstants.SUBMITTED_STATUS){
            system.debug('Already submitted');
            errormessage = ContainerConstants.SUBMITTED_QUOTE_ERROR_MSG;
            ApexPages.addmessage(new ApexPages.message(ApexPages.severity.ERROR,ContainerConstants.SUBMITTED_QUOTE_ERROR_MSG));  
            return null;
        }
        
        else if(quote.CONTAINER_Model_Number__c == null || (quote.CONTAINER_Cost_Contract_Price__c == null && quote.CONTAINER_Type__c == 'End Customer Quote') || (quote.CONTAINER_Payment_Terms__c == null && quote.CONTAINER_Payment_Terms_GENSET__c == null)
               ||(quote.CONTAINER_Method_of_Shipment__c == null && quote.CONTAINER_Method_of_Shipment_GENSET__c == null)
               ||(quote.CONTAINER_Freight_Terms__c == null && quote.CONTAINER_Freight_Terms_GENSET__c == null)
               || (quote.CONTAINER_Freight_Terms__c == null && quote.CONTAINER_Freight_Terms_GENSET__c == null)
               || (quote.CONTAINER_Sum_Requested_Ship_Dates_Qty__c == null)
               ||(quote.CONTAINER_Qty__c != quote.CONTAINER_Sum_Requested_Ship_Dates_Qty__c) ) {
            //string errormessage = '';
                   if(quote.CONTAINER_Model_Number__c == null){
            errormessage = errormessage + ContainerConstants.Model_Number_Blank + '\n';
                   }
           // ApexPages.addmessage(new ApexPages.message(ApexPages.severity.ERROR,ContainerConstants.Model_Number_Blank));
            
            if(quote.CONTAINER_Cost_Contract_Price__c == null && quote.CONTAINER_Type__c == 'End Customer Quote') {
            	errormessage = errormessage + ContainerConstants.Contract_Price + '\n';
                //ApexPages.addmessage(new ApexPages.message(ApexPages.severity.ERROR,ContainerConstants.Contract_Price));
          	
        }
            if(quote.CONTAINER_Payment_Terms__c == null && quote.CONTAINER_Payment_Terms_GENSET__c == null) {
            	errormessage = errormessage + ContainerConstants.Payment_terms_Field_Blank + '\n';
                //ApexPages.addmessage(new ApexPages.message(ApexPages.severity.ERROR,ContainerConstants.Payment_terms_Field_Blank));
        	
        }
            
             if(quote.CONTAINER_Method_of_Shipment__c == null && quote.CONTAINER_Method_of_Shipment_GENSET__c == null) {
            	errormessage = errormessage + ContainerConstants.Method_of_shipment_field_blank + '\n';
                 //ApexPages.addmessage(new ApexPages.message(ApexPages.severity.ERROR,ContainerConstants.Method_of_shipment_field_blank));
        	
        }
             if(quote.CONTAINER_Freight_Terms__c == null && quote.CONTAINER_Freight_Terms_GENSET__c == null) {
            	errormessage = errormessage + ContainerConstants.Freight_Terms_Field_Blank + '\n';
                 //ApexPages.addmessage(new ApexPages.message(ApexPages.severity.ERROR,ContainerConstants.Freight_Terms_Field_Blank));
        
        }
            if(quote.CONTAINER_Sum_Requested_Ship_Dates_Qty__c == null) {
           		errormessage = errormessage + ContainerConstants.Requested_Ship_Dates_Null_Records + '\n';
                //ApexPages.addmessage(new ApexPages.message(ApexPages.severity.ERROR,ContainerConstants.Requested_Ship_Dates_Null_Records));
        	
        }
             if(quote.CONTAINER_Qty__c != quote.CONTAINER_Sum_Requested_Ship_Dates_Qty__c) {
            	errormessage = errormessage + ContainerConstants.Quantity_Not_Equal_To_RequestedShipDate_Quantity + '\n';
                 //ApexPages.addmessage(new ApexPages.message(ApexPages.severity.ERROR,ContainerConstants.Quantity_Not_Equal_To_RequestedShipDate_Quantity));
        	
        }
            ApexPages.addmessage(new ApexPages.message(ApexPages.severity.ERROR,errormessage));
            return null;
        }     
        
		else if (quoteId != null) {
            system.debug('inside approval call');
			SBAA.ApprovalAPI.submit(quoteId, SBAA__Approval__c.Quote__c);
            list<sbaa__Approval__c>lstApp = [select id from sbaa__Approval__c where Quote__c=:quoteId];
            system.debug('applist'+lstApp);
		}
		return new PageReference('/' + quoteId);
	}
	public PageReference onRecall() {
		if (quoteId != null) {
			SBAA.ApprovalAPI.recall(quoteId, SBAA__Approval__c.Quote__c);
		}
		return new PageReference('/' + quoteId);
	}
    public PageReference onPreview() {
		if (quoteId != null) {
			approvals = SBAA.ApprovalAPI.Preview(quoteId, SBAA__Approval__c.Quote__c);
		}
		return null;
	}
    public PageReference returnToQuote() {
		if (quoteId != null) {
			return new PageReference('/' + quoteId);
		}
		return null;
	}
    
}