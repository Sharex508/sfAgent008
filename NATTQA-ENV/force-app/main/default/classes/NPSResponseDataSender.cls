/**
 * @description Sends NPS-related Case data to Qualtrics, including additional
 *              info and closure status, via authenticated HTTP callouts.
 *              Provides Flow-invocable entry and helper utilities.
 */
public without sharing class NPSResponseDataSender {

    public static final String INTERFACE_NAME_ADDITIONAL_INFO = 'QualtricsSurveys_AdditionalInfo';
    public static final String INTERFACE_NAME_CASECLOSURE_INFO = 'QualtricsSurveys_CaseClosureInfo';    
    public static final Integer HTTP_STATUS_CODE = 200;
    public static final String HTTP_METHOD_PUT = 'PUT';
    public static final String APPLICATION_JSON = 'application/json';
    private static Map<String,Schema.SObjectField> mapSobjectFields;
    
    /**
     * @method initiateQualtricsCallout
     * @description Flow-invocable entry that triggers Qualtrics callout for the
     *              first Case Id provided. Sends additional info and then closure info.
     * @param lstCaseId List of Case Ids; only the first is used.
     * @return void
     * @see provideAddtionalInfoDataToQualtrics
     */
    @InvocableMethod(label='Send Case Closure Info To Qualtrics' description='Send Case Closure Info To Qualtrics' category='Callout')
    public static void initiateQualtricsCallout(List<Id> lstCaseId) { 

        system.debug('@@@initiateQualtricsCallout ' +lstCaseId.get(0));       
        provideAddtionalInfoDataToQualtrics(lstCaseId.get(0));
    }

    /**
     * @method provideAddtionalInfoDataToQualtrics
     * @description Sends Case additional information to Qualtrics for the given Case Id
     *              and upon success triggers sending Case closure status.
     * @param strCaseId The Case Id for which to send additional info.
     * @return void
     * @throws CalloutException If the HTTP callout fails at runtime.
     */
    @future(callout = true)
    public static void provideAddtionalInfoDataToQualtrics(Id strCaseId) {
        Case objCase = [
            SELECT Id, CLF_PCI__c,CLF_AT__c, Status, nps_Ticket_Number__c, Internal_Comments__c
            FROM Case 
            WHERE Id = :strCaseId 
        ];
        
        System.debug('ProvideAddtionalInfoDataToQualtrics called');
        System.debug('Ticket Number ::: '+objCase.nps_Ticket_Number__c);

        if(objCase.nps_Ticket_Number__c == null ) { return; }
        // Get auth settings details from Custom Metadata
        Qualtrics_Surveys_Auth_Setting__mdt authSetting = Qualtrics_Surveys_Auth_Setting__mdt.getInstance(INTERFACE_NAME_ADDITIONAL_INFO);        
        String strEndPoint = authSetting.Endpoint__c + '/'+ objCase.nps_Ticket_Number__c + '/ticketAdditionalData' ;
        String strApiKey = authSetting.ApiKey__c;
        
        // callout body data
        String strCalloutBody = getBodyForAdditionalInfoCallout(objCase);
        System.debug('strcalloutbody for additional Info ::: '+strCalloutBody);

        // HTTP request 
        HttpRequest reqToken = new HttpRequest();
        reqToken.setMethod(HTTP_METHOD_PUT);
        reqToken.setEndpoint(strEndPoint);        
        reqToken.setHeader('Content-Type', APPLICATION_JSON);
        reqToken.setHeader('X-API-TOKEN', strApiKey);
        reqToken.setBody(strCalloutBody);
        reqToken.setTimeout(120000);

        // perform the callout here
        Http http = new Http();        
        HttpResponse response = http.send(reqToken);

        System.debug('Case Additional info status code ::: '+response.getStatusCode());
        // Response
        if (response.getStatusCode() == HTTP_STATUS_CODE) {            
            System.debug('Case Additional info successfully sent to Qualtrics, preparing to send Case Closure information now...');
            
         //    if(objCase.Status == 'Closed') {
           //     System.debug('Preparing to send Case Closure information now...');
                sendCaseClosureInfoToQualtrics(objCase);
         //   } else {
         //       System.debug('Case status is not closed, skipping Case Closure information callout.');
         //   }
        }
    }
    
    /**
     * @method sendCaseClosureInfoToQualtrics
     * @description Sends Case closure status mapping to Qualtrics using the Case's
     *              current Status. Maps Status to a numeric code expected by Qualtrics.
     * @param objCase Case record with Status and nps_Ticket_Number__c populated.
     * @return void
     * @throws CalloutException If the HTTP callout fails at runtime.
     */
    public static void sendCaseClosureInfoToQualtrics(Case objCase) {
        System.debug('sendCaseClosureInfoToQualtrics called');
        System.debug('Ticket Number ::: '+objCase.nps_Ticket_Number__c);
        if(objCase.nps_Ticket_Number__c == null ) { return; }
        
        // Get auth settings details from Custom Metadata
        Qualtrics_Surveys_Auth_Setting__mdt authSetting = Qualtrics_Surveys_Auth_Setting__mdt.getInstance(INTERFACE_NAME_CASECLOSURE_INFO);        
        String strEndPoint = authSetting.Endpoint__c + '/'+ objCase.nps_Ticket_Number__c ;
        String strApiKey = authSetting.ApiKey__c;
        
        // Mapping of status values to their corresponding numerical values
        Map<String, Integer> statusMapping = new Map<String, Integer> {
            'New' => 0,
            'Escalated' => 3,
            'In Progress' => 1,
            'Overdue' => 4,
            'Closed' => 2
        };
        
        // Get the numerical value for the current status or default to 1
        Integer statusValue = statusMapping.containsKey(objCase.Status) ? statusMapping.get(objCase.Status) : 1;
        
        Map<String, Object> mapStringToFieldValue = new Map<String, Object>();
        // Set status value dynamically based on the current status
        mapStringToFieldValue.put('status', statusValue); 
        
        // callout body data
        String strCalloutBody = JSON.serialize(mapStringToFieldValue);
        System.debug('strcalloutbody for case closure Info ::: '+strCalloutBody);

        // HTTP request 
        HttpRequest reqToken = new HttpRequest();
        reqToken.setMethod(HTTP_METHOD_PUT);
        reqToken.setEndpoint(strEndPoint);        
        reqToken.setHeader('Content-Type', APPLICATION_JSON);
        reqToken.setHeader('X-API-TOKEN', strApiKey);
        reqToken.setBody(strCalloutBody);
        reqToken.setTimeout(120000);

        // perform the callout here
        Http http = new Http();        
        HttpResponse response = http.send(reqToken);
        
        System.debug('Case Closure info status code ::: '+response.getStatusCode());
        // Response
        if (response.getStatusCode() == HTTP_STATUS_CODE) {
            String responseJson = response.getBody();
            System.debug('Case Closure information sent to Qualtrics successfully');
        }
    }
    
   
    /**
     * @method getBodyForAdditionalInfoCallout
     * @description Builds the JSON body for the additional info Qualtrics callout,
     *              converting Case picklist API values to labels as Qualtrics expects labels.
     * @param objCase Case record containing CLF_PCI__c, CLF_AT__c, and Internal_Comments__c.
     * @return String JSON string for the Qualtrics additional info payload.
     */
    public static string getBodyForAdditionalInfoCallout(Case objCase) {
        
        // Below logic is written to extract label instead of picklist value as Qualtrics data holds label
        //To get picklist entries
        String strObjectName = 'Case';
        String strPrimaryCustomerIssue = String.isBlank(objCase.CLF_PCI__c) ? '': getPicklistLabelMapForSObjectFields(strObjectName,'CLF_PCI__c')?.get(objCase.CLF_PCI__c);
        String strActionTaken = String.isBlank(objCase.CLF_AT__c) ? '': getPicklistLabelMapForSObjectFields(strObjectName,'CLF_AT__c')?.get(objCase.CLF_AT__c);
        String strInternalComments = String.isBlank(objCase.Internal_Comments__c) ? '' : objCase.Internal_Comments__c;

        Elements objPCIElement = new Elements();        
        objPCIElement.key = 'Primary Customer Issue';
        objPCIElement.value = strPrimaryCustomerIssue;
        
        
        Elements objATElement = new Elements();        
        objATElement.key = 'Action Taken'; 
        objATElement.value = strActionTaken;
        
        Elements objCommentsElement = new Elements();
        objCommentsElement.key = 'Internal Comments';
        objCommentsElement.value = strInternalComments;

        TicketAdditionalData objTicketAdditionalData = new TicketAdditionalData();
        List<Elements> lstElements = new List<Elements>();
        lstElements.add(objPCIElement);
        lstElements.add(objATElement);
        lstElements.add(objCommentsElement);
        objTicketAdditionalData.elements = lstElements;

        CaseDataSenderWrapper objWrapper = new CaseDataSenderWrapper();
        objWrapper.ticketAdditionalData = objTicketAdditionalData;
        
        return JSON.serialize(objWrapper);
    }

    /**
     * @method getPicklistLabelMapForSObjectFields
     * @description Returns a Map of picklist API value to picklist label for a given SObject field.
     * @param strObjectType API name of the SObject (e.g., 'Case').
     * @param strFieldApiName API name of the picklist field (e.g., 'Status').
     * @return Map<String, String> Mapping of picklist value => label.
     */
    public static Map<String, String> getPicklistLabelMapForSObjectFields(String strObjectType,String strFieldApiName) { 
        Map<String,String> statusApiToLabelMap = new Map<String,String>();       
        Map<String,Schema.SObjectField> fields = getFieldsMapForSObject(strObjectType) ;
        Schema.DescribeFieldResult fieldResult = fields.get(strFieldApiName).getDescribe();
        List<Schema.PicklistEntry> ple = fieldResult.getPicklistValues();

        for(Schema.PicklistEntry pickListVal : ple){
            statusApiToLabelMap.put(pickListVal.getValue(),pickListVal.getLabel());   
        }
        return statusApiToLabelMap;
    }

    /**
     * @method getFieldsMapForSObject
     * @description Returns (and caches) the field API-name to field token map for a given SObject.
     * @param strObjectName API name of the SObject (e.g., 'Case').
     * @return Map<String, Schema.SObjectField> Field map for the SObject; cached statically.
     */
    public static Map<String,Schema.SObjectField> getFieldsMapForSObject(String strObjectName) {
        if(mapSobjectFields != null && !mapSobjectFields.isEmpty()) {
            return mapSobjectFields;
        } else {
            Schema.SObjectType schemaSobjectType = Schema.getGlobalDescribe().get(strObjectName);
            Schema.DescribeSObjectResult result = schemaSobjectType.getDescribe();
            mapSobjectFields = result.fields.getMap();     
            return mapSobjectFields;               
        }         
    }

    /**
     * @description Wrapper to store client credential responses.
     */
    public class ClientCredentialResponse {
        public String access_token;
        public String expires_in;
        public String ext_expires_in;
        public String token_type;
    }
    
    /**
     * @description Wrapper to store simple key/value pairs for Qualtrics elements.
     */
    public class Elements {
        public String key;
        public String value;
    }

    /**
     * @description Wrapper to store ticket additional data as a list of elements.
     */
    public class TicketAdditionalData {
        public List<Elements> elements;
    }

    /**
     * @description Wrapper for the Qualtrics ticketAdditionalData payload.
     */
    public class CaseDataSenderWrapper {
        public TicketAdditionalData ticketAdditionalData;
    }
}