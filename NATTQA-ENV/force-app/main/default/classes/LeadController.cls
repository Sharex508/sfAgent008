/*
@name: LeadController
@description: This class is used for Lead object
@date: 08 Aug 2020
@author: LTI
@changes:
*/
global class LeadController {
    
    //constants
    public static final String BLANK = '';
    public static final String SPACE = ' ';
    public static final String COMMA = ',';
    public static final String NAMED_CREDENTIAL = 'NAMED_CREDENTIAL';
    public static final String INTEGRATION_SENDLEAD = 'SendLead';
    public static final String INTEGRATION_QUERYEXTDATA = 'QueryExternalData';
    public static final String ERROR_START = 'Error: ';
    public static final String RESPONSE_NULL = 'No Response Received';
    public static final String STATUS_NEW = 'New';
    public static final String STATUS_ACCEPTED = 'Accepted';
    public static final String STATUS_REJECTED = 'Rejected';
    public static final String STATUS_CONTACTED = 'Customer Contacted';
    public static final String STATUS_CONVERTED = 'Qualified';
    public static final String STATUS_OPP_WON = 'Won Booked';
    public static final String STATUS_Opp_LOST = 'Lost';
    public static final String CONTENT_TYPE = 'Content-Type';
    public static final String UTF_8 = 'UTF-8';
    public static final String STATUSREASON_BLANK = 'No Reason Specified';
    
    /*
    @name: createLead
    @description: This method is used by createLeadLWC to insert Lead records
    @date: 08 Aug 2020
    @author: LTI
    @changes:
    */
    @AuraEnabled
    global static String createLead(Lead objLeadRec){
        String strToReturn = BLANK;
        String errors = ERROR_START;
        try{
            Database.SaveResult saveRes = Database.insert(objLeadRec);
            if(saveRes.isSuccess()){
                sendandUpdateLead(objLeadRec.Id);
                strToReturn = objLeadRec.Id;
            }else{
                for(Database.Error objErr : saveRes.getErrors()) {
                    errors = errors + objErr.getMessage() + SPACE;
                }
                strToReturn = errors;
            }
        }catch(Exception ex){
            system.debug('Exception on line : '+ex.getLineNumber()+' Exception '+ex.getMessage());
            strToReturn = errors +ex.getMessage();
        }
        return strToReturn;
    }
    
    /*
    @name: sendandUpdateLead
    @description: This future method is used to send Lead record to respective orgs and store ext lead id or error in lead record
    @date: 08 Aug 2020
    @author: LTI
    @changes:
    */
    @future(callout=true)
    public static void sendandUpdateLead(String leadId){
        try{
            String sourceLeadId = BLANK;
            String errorOnLeadCreation = BLANK;
            String extRecordTypeName = BLANK;
            String extRecordTypeId = BLANK;
            String namedCred = BLANK;
            
            Lead leadRec = [SELECT Id, Sender_Name__c, Sender_Email__c, Sender_Phone__c, Sending_Business__c, Receiving_Business__c, Customer_Discussion_Date__c, LastName, FirstName, Salutation, MiddleName, Suffix, Name, Title, Company, Street, City, State, PostalCode, Country, Phone, MobilePhone, Email, Website, Status, LeadSource, Industry , Customer_Details__c, Contact_Details__c, Customer_Interest__c, Customer_Budget__c, Solutions_Interested__c FROM Lead where Id=:leadId];
            for(HBI_Leads_Mapping_By_Receiving_Business__mdt objMdt : [SELECT Id, Named_Credential__c, Industry__c, Org_Record_Type__c FROM HBI_Leads_Mapping_By_Receiving_Business__mdt WHERE MasterLabel = :leadRec.Receiving_Business__c Order By Industry__c]){
                if(String.isBlank(objMdt.Industry__c)){
                    extRecordTypeName = objMdt.Org_Record_Type__c;
                    namedCred = objMdt.Named_Credential__c;
                }else if(String.isNotBlank(objMdt.Industry__c) && leadRec.Industry == objMdt.Industry__c){
                    extRecordTypeName = objMdt.Org_Record_Type__c;
                    namedCred = objMdt.Named_Credential__c;
                }
            }
            
            if(String.isNotBlank(extRecordTypeName) && String.isNotBlank(namedCred)){
            	String queryToGetRecordType = 'SELECT Id, Name FROM RecordType where sObjectType=\'Lead\' AND Name=\''+extRecordTypeName+'\'';
                String respBody = calloutToQueryExtData(namedCred,queryToGetRecordType);
                if(String.isNotBlank(respBody)){
                    RecordTypeResp objResp = (RecordTypeResp) JSON.deserialize(respBody, RecordTypeResp.class);
                    List<RecordTypeWrap> objRecType = objResp.records;
                    for(RecordTypeWrap obj : objRecType){
                        extRecordTypeId = obj.Id;
                    }
                }
            }
            
            //update lead with ref id or error
            if(String.isNotBlank(extRecordTypeId)){
                String strBody = getExtLeadBody(extRecordTypeId,leadRec);
                ExtLeadWrap extLead = calloutToSendLead(namedCred, strBody);
                Lead objLead = new Lead(Id = leadId);
                if(String.isNotBlank(extLead.Id)){
                    objLead.Record_Reference_Id__c = extLead.Id;
                    objLead.HBI_Lead_Status__c = STATUS_NEW;
                }
                if(String.isNotBlank(extLead.Error)){
                    objLead.Errors_on_Sending_Record__c = extLead.Error;
                }
                Database.update(objLead); 
            }            
        }catch(Exception ex){
            system.debug('Exception on line : '+ex.getLineNumber()+' Exception '+ex.getMessage());
        }
    }
    
    /*
    @name: processDataFromAllOrgs
    @description: This method is called from HBILeadsBatch it get data from ext lead and updates lead records
    @date: 08 Aug 2020
    @author: LTI
    @changes:
    */
    public static void processDataFromAllOrgs(List<Lead> lstLead){
        
        List<Lead> lstLeadToUpdate = new List<Lead>();
        Map<String, List<Lead>> mapOfLeadByOrg = new Map<String, List<Lead>>();
        Set<String> setOfRecBusiness = new Set<String>();
        Map<String,String> mapOrgByRecBusiness = new Map<String,String>();
        Set<String> setOfOrgs = new Set<String>();
        Map<String,HBI_Leads_Mapping_By_Org__mdt> mapOfMdtByOrg = new Map<String,HBI_Leads_Mapping_By_Org__mdt>();

        for(Lead objLead : lstLead){
            setOfRecBusiness.add(objLead.Receiving_Business__c);
        }
        if(!setOfRecBusiness.isEmpty()){
            for(HBI_Leads_Mapping_By_Receiving_Business__mdt obj : [SELECT MasterLabel, Named_Credential__c FROM HBI_Leads_Mapping_By_Receiving_Business__mdt WHERE MasterLabel IN :setOfRecBusiness AND Industry__c = :BLANK]){
                mapOrgByRecBusiness.put(obj.MasterLabel,obj.Named_Credential__c);
                setOfOrgs.add(obj.Named_Credential__c);
            }
        }
        
        for(Lead objLead :lstLead){
            String receivingOrg = BLANK;
            if(!mapOrgByRecBusiness.isEmpty() && mapOrgByRecBusiness.containsKey(objLead.Receiving_Business__c)){
                receivingOrg = mapOrgByRecBusiness.get(objLead.Receiving_Business__c);
            }
            if(String.isNotBlank(receivingOrg)){
                if(mapOfLeadByOrg.containsKey(receivingOrg)){
                    mapOfLeadByOrg.get(receivingOrg).add(objLead);
                }else{
                    mapOfLeadByOrg.put(receivingOrg ,new List<Lead>{objLead});
                }
            }
        }
        
        if(!setOfOrgs.isEmpty()){
            for(HBI_Leads_Mapping_By_Org__mdt objMdt : [SELECT MasterLabel, Lead_Reason_Field__c, Opportunity_Reason_Field__c, Status_Accepted__c, Status_Customer_Contacted__c, Status_Rejected__c, Status_Won__c, Status_Lost__c FROM HBI_Leads_Mapping_By_Org__mdt WHERE Masterlabel IN :setOfOrgs ]){
                mapOfMdtByOrg.put(objMdt.MasterLabel,objMdt);
            }
        }
        
        Map<Id,OpportunityWrap> mapOfExtOppByExtOppId = new Map<Id,OpportunityWrap>();
        Map<Id,LeadWrap> mapOfExtLeadByLeadId = new Map<Id,LeadWrap>();
        
        for(String receivingOrg : mapOfLeadByOrg.keySet()){
            if(mapOfLeadByOrg.get(receivingOrg) != null && !mapOfLeadByOrg.get(receivingOrg).isEmpty()){
                String leadReasonField = BLANK;
                String oppReasonField = BLANK;
                if(!mapOfMdtByOrg.isEmpty() && mapOfMdtByOrg.containsKey(receivingOrg)){
                    if(String.isNotBlank(mapOfMdtByOrg.get(receivingOrg).Lead_Reason_Field__c)){
                        leadReasonField = mapOfMdtByOrg.get(receivingOrg).Lead_Reason_Field__c;
                    }
                    if(String.isNotBlank(mapOfMdtByOrg.get(receivingOrg).Opportunity_Reason_Field__c)){
                        oppReasonField = mapOfMdtByOrg.get(receivingOrg).Opportunity_Reason_Field__c;
                    }
                }
                
                String strExtLeadIds = '('; 
                String strFailedLeadIds = '('; 
                for(Lead objLead : mapOfLeadByOrg.get(receivingOrg)){
                    if(String.isNotBlank(objLead.Record_Reference_Id__c)){
                        strExtLeadIds = strExtLeadIds +'\''+ objLead.Record_Reference_Id__c + '\',';
                    }else{
                        strFailedLeadIds = strFailedLeadIds + '\''+ objLead.Id + '\',';
                    }
                }
                strExtLeadIds = strExtLeadIds.removeEnd(',');
                strExtLeadIds = strExtLeadIds + ')';
                strFailedLeadIds = strFailedLeadIds.removeEnd(',');
                strFailedLeadIds = strFailedLeadIds + ')';
                
                String queryToGetLeadRecs = 'SELECT Id, HBI_HQ_Lead_Id__c, Owner.Name, Owner.Email, IsConverted, Status, ConvertedOpportunityId FROM Lead WHERE LeadSource=\'Healthy Buildings - SPIFF\'';
                if(String.isNotBlank(leadReasonField)){
                    queryToGetLeadRecs = 'SELECT Id, HBI_HQ_Lead_Id__c, Owner.Name, Owner.Email, '+leadReasonField+', IsConverted, Status, ConvertedOpportunityId FROM Lead WHERE LeadSource=\'Healthy Buildings - SPIFF\'';
                }
                if(strExtLeadIds != '()' && strFailedLeadIds!='()'){
                    queryToGetLeadRecs = queryToGetLeadRecs + ' AND (Id IN'+strExtLeadIds+' OR HBI_HQ_Lead_Id__c IN'+strFailedLeadIds+')';
                }else if(strExtLeadIds != '()' && strFailedLeadIds=='()'){
                    queryToGetLeadRecs = queryToGetLeadRecs + ' AND Id IN'+strExtLeadIds;
                }else if(strExtLeadIds == '()' && strFailedLeadIds!='()'){
                    queryToGetLeadRecs = queryToGetLeadRecs + ' AND HBI_HQ_Lead_Id__c IN'+strFailedLeadIds;
                }
                List<String> convOppIds = new List<String>();
                String respLeadBody = calloutToQueryExtData(receivingOrg,queryToGetLeadRecs);
                if(String.isNotBlank(respLeadBody)){
                    if(String.isNotBlank(leadReasonField)){
                        respLeadBody = respLeadBody.replaceAll(leadReasonField, 'StatusReason');
                    }
                    respLeadBody = respLeadBody.replaceAll('HBI_HQ_Lead_Id__c', 'LeadReferenceId');
                    
                    LeadResp objLeadResp = (LeadResp) JSON.deserialize(respLeadBody, LeadResp.class);
                    for(LeadWrap obj : objLeadResp.records){
                        mapOfExtLeadByLeadId.put(obj.LeadReferenceId,obj);
                        if(obj.ConvertedOpportunityId !=null){
                            convOppIds.add(obj.ConvertedOpportunityId);
                        }
                    }
                }
                if(!convOppIds.isEmpty()){
                    String oppIds = '(';
                    for(String oid : convOppIds){
                        oppIds = oppIds +'\''+ oid + '\',';
                    }
                    oppIds = oppIds.removeEnd(',');
                    oppIds = oppIds + ')';
                    String queryToGetOppRecs = BLANK;
                    if(String.isBlank(oppReasonField)){
                        queryToGetOppRecs = 'SELECT Id, Amount, StageName, isWon, isClosed, Owner.Name, Owner.Email FROM Opportunity WHERE Id IN '+oppIds;
                    }else{
                        queryToGetOppRecs = 'SELECT Id, Amount, StageName, isWon, isClosed, Owner.Name, Owner.Email,'+oppReasonField+' FROM Opportunity WHERE Id IN '+oppIds;
                    }
                    String respOppBody = calloutToQueryExtData(receivingOrg,queryToGetOppRecs);
                    if(String.isNotBlank(respOppBody)){
                        if(String.isNotBlank(oppReasonField)){
                            respLeadBody = respLeadBody.replaceAll(oppReasonField, 'StageReason');
                        }
                        OpportunityResp opptyResp = (OpportunityResp) JSON.deserialize(respOppBody, OpportunityResp.class);
                        for(OpportunityWrap opp : opptyResp.records){
                            mapOfExtOppByExtoppId.put(opp.Id, opp);
                        }
                    }
                }
            }
        }
        system.debug('mapOfExtOppByExtOppId'+mapOfExtOppByExtOppId.size());
        system.debug('mapOfExtLeadByLeadId'+mapOfExtLeadByLeadId.size());
        
        //update lead status from external Leads
        if(!mapOfExtLeadByLeadId.isEmpty()){
            for(Lead objLead :lstLead){
                if(mapOfExtLeadByLeadId.containsKey(objLead.Id)){
                    LeadWrap objextLead = mapOfExtLeadByLeadId.get(objLead.Id);
                    Lead objLeadToUpdate = new Lead(Id = objLead.Id);
                    HBI_Leads_Mapping_By_Org__mdt objMdt;
                    if(!mapOrgByRecBusiness.isEmpty() && mapOrgByRecBusiness.containsKey(objLead.Receiving_Business__c) && !mapOfMdtByOrg.isEmpty() && mapOfMdtByOrg.containsKey(mapOrgByRecBusiness.get(objLead.Receiving_Business__c))){
                    	objMdt = mapOfMdtByOrg.get(mapOrgByRecBusiness.get(objLead.Receiving_Business__c));
                    }
                    if(String.isBlank(objLead.Record_Reference_Id__c)){
                        objLeadToUpdate.Record_Reference_Id__c = objextLead.Id;
                        objLeadToUpdate.HBI_Lead_Status__c = STATUS_NEW;
                    }
                    if(objExtLead.Owner != null){
                        objLeadToUpdate.Lead_Owner_Name__c = objExtLead.Owner.Name;
                        objLeadToUpdate.Lead_Owner_Email__c = objExtLead.Owner.Email;
                    }
                    if(objExtLead.IsConverted){
                        objLeadToUpdate.HBI_Lead_Status__c = STATUS_CONVERTED;
                        objLeadToUpdate.Opportunity_Reference_Id__c = objExtLead.ConvertedOpportunityId;
              
                        if(mapOfExtOppByExtoppId!=null && objExtLead.ConvertedOpportunityId!=null && mapOfExtOppByExtoppId.containsKey(objExtLead.ConvertedOpportunityId)){
                            OpportunityWrap objExtOpp = mapOfExtOppByExtoppId.get(objExtLead.ConvertedOpportunityId);
                            if(objExtOpp.Amount !=null && !objExtOpp.IsWon){
                                objLeadToUpdate.Opportunity_Pipeline_Value_Est__c = objExtOpp.Amount;
                            }
                            if(objExtOpp.Owner != null){
                                objLeadToUpdate.Opportunity_Owner_Name__c = objExtOpp.Owner.Name;
                                objLeadToUpdate.Opportunity_Owner_Email__c = objExtOpp.Owner.Email;
                            }
                            if(objMdt!=null){
                                if(objMdt.Status_Won__c.split(COMMA).contains(objExtLead.Status)){
                                    objLeadToUpdate.HBI_Lead_Status__c = STATUS_OPP_WON;
                                    objLeadToUpdate.Estimated_Payout__c = 500;
                                    objLeadToUpdate.Opportunity_Value_Won_Act__c = objExtOpp.Amount;
                                }else if(objMdt.Status_Lost__c.split(COMMA).contains(objExtLead.Status)){
                                    objLeadToUpdate.HBI_Lead_Status__c = STATUS_OPP_LOST;
                                    objLeadToUpdate.Status_Reason__c = String.isNotBlank(objExtOpp.StageReason) ? objExtOpp.StageReason : STATUSREASON_BLANK;
                                }
                            }
                        }
                    }else if(String.isNotBlank(objExtLead.Status)){
                        if(objMdt!=null){
                            if(objMdt.Status_Rejected__c.split(COMMA).contains(objExtLead.Status)){
                                objLeadToUpdate.HBI_Lead_Status__c = STATUS_REJECTED;
                                objLeadToUpdate.Status_Reason__c = String.isNotBlank(objExtLead.StatusReason) ? objExtLead.StatusReason : STATUSREASON_BLANK;
                            }else if(objMdt.Status_Customer_Contacted__c.split(COMMA).contains(objExtLead.Status)){
                            	objLeadToUpdate.HBI_Lead_Status__c = STATUS_CONTACTED;
                            	objLeadToUpdate.Estimated_Payout__c = 100;
                            }else if(objMdt.Status_Accepted__c.split(COMMA).contains(objExtLead.Status)){
                            	objLeadToUpdate.HBI_Lead_Status__c = STATUS_ACCEPTED;
                            }
                        }
                    }
                    lstLeadToUpdate.add(objLeadToUpdate);
                }
            }
        }
        if(lstLeadToUpdate!=null && !lstLeadToUpdate.isEmpty()){
            Database.update(lstLeadToUpdate);
        }
    }
    
    /*
    @name: calloutToQueryExtData
    @description: This method takes named credential name and query to get data from external org
    @date: 08 Aug 2020
    @author: LTI
    @changes:
    */
    public static String calloutToQueryExtData(String namedCred, String strQuery){
        String responseBody = BLANK;
        try{
                Integration__c csQueryExtData = Integration__c.getValues(INTEGRATION_QUERYEXTDATA);
            String strEndpoint = csQueryExtData.Endpoint__c;
            strEndpoint = strEndpoint.replace(NAMED_CREDENTIAL,namedCred);
            String strMethod = csQueryExtData.Method__c;
            Integer intTimeOut = Integer.valueOf(csQueryExtData.Timeout__c);
            String strHeaderContentType = csQueryExtData.Content_Type__c;

            String strEnQuery = EncodingUtil.urlEncode(strQuery,UTF_8);
            String strCompleteEndpoint =  strEndpoint + strEnQuery;
            
            HTTPResponse response = getCalloutResponse(strCompleteEndpoint, strMethod, intTimeOut, null, null);
            if(response!=null && response.getStatusCode() == 200){
                responseBody = response.getBody();
            }else{
                if(response!=null){
                    system.debug(ERROR_START + response.getBody());
                }else{
                    system.debug(ERROR_START + RESPONSE_NULL);
                }
            }
            
        }catch(Exception ex){
            system.debug('Exception on line : '+ex.getLineNumber()+' Exception '+ex.getMessage());
        }
        return responseBody;
    }
    
    /*
    @name: calloutToSendLead
    @description: This method takes named credential name and json body to send lead to external org
    @date: 08 Aug 2020
    @author: LTI
    @changes:
    */
    public static ExtLeadWrap calloutToSendLead(String namedCred, String strBody){
        ExtLeadWrap extLead = new ExtLeadWrap();
        try{
            Integration__c csSendLead = Integration__c.getValues(INTEGRATION_SENDLEAD);
            String strMethod = csSendLead.Method__c;
            Integer intTimeOut = Integer.valueOf(csSendLead.Timeout__c);
            String strHeaderContentType = csSendLead.Content_Type__c;
            String strEndpoint = csSendLead.Endpoint__c;
            strEndpoint = strEndpoint.replace(NAMED_CREDENTIAL, namedCred);
            
            HTTPResponse response = getCalloutResponse(strEndpoint, strMethod, intTimeOut, strBody, strHeaderContentType);            
            if(response!=null && Response.getStatusCode() == 201){
                SendLead_Response objResp = (SendLead_Response)JSON.deserialize(response.getBody(), SendLead_Response.class);
                if(objResp.success){
                    extLead.Id = objResp.id;
                }else{
                    extLead.Error = Response.getBody();
                }
            }else if(response!=null){
                extLead.Error = Response.getBody();
            }else{
                extLead.Error = RESPONSE_NULL;
            }
        }catch(Exception ex){
            system.debug('Exception on line : '+ex.getLineNumber()+' Exception '+ex.getMessage());
        }
        return extLead;
    }
    
    /*
    @name: getCalloutResponse
    @description: This method does callout and returns response
    @date: 08 Aug 2020
    @author: LTI
    @changes:
    */
    public static HTTPResponse getCalloutResponse(String strEndpoint, String strMethod, Integer intTimeOut, String strBody, String strHeaderContentType){
        HTTPResponse response = null;
        try{
            HttpRequest request = new HttpRequest();
            if(String.isNotBlank(strEndpoint)){
                request.setEndpoint(strEndpoint);
            }
            if(String.isNotBlank(strMethod)){
                request.setMethod(strMethod);
            }
            if(intTimeOut!=null){
                request.setTimeout(intTimeOut);
            }
            if(String.isNotBlank(strHeaderContentType)){
                request.setHeader(CONTENT_TYPE, strHeaderContentType);
            }
            if(String.isNotBlank(strBody)){
                request.setBody(strBody);
            }
            Http http = new Http();
            response = http.send(request);
            system.debug('Request: '+request);
        	system.debug('Response: '+response);
        }catch(Exception ex){
            system.debug('Exception on line : '+ex.getLineNumber()+' Exception '+ex.getMessage());
        }
        return response;
    }
    
    /*
    @name: getExtLeadBody
    @description: This method creates external Lead record as Json
    @date: 08 Aug 2020
    @author: LTI
    @changes:
    */
    public static String getExtLeadBody(String extRecTypeId, Lead leadRec){
        String jsonLead = '';
        try{
            jsonLead = '{';
            if(String.isNotBlank(extRecTypeId)){
                jsonLead = jsonLead + '"RecordTypeId" : "'+extRecTypeId+'",';
            }
            if(String.isNotBlank(leadRec.Id)){
                jsonLead = jsonLead + '"HBI_HQ_Lead_Id__c" : "'+leadRec.Id+'",';
            }    
            if(String.isNotBlank(leadRec.Sender_Name__c)){
                jsonLead = jsonLead + '"Sender_Name__c" : "'+leadRec.Sender_Name__c+'",';
            }
            if(String.isNotBlank(leadRec.Sender_Email__c)){
                jsonLead = jsonLead + '"Sender_Email__c" : "'+leadRec.Sender_Email__c+'",';
            }
            if(String.isNotBlank(leadRec.Sender_Phone__c)){
                jsonLead = jsonLead + '"Sender_Phone__c" : "'+leadRec.Sender_Phone__c+'",';
            }
            if(String.isNotBlank(leadRec.Sending_Business__c)){
                jsonLead = jsonLead + '"Sending_Business__c" : "'+leadRec.Sending_Business__c+'",';
            }
            if(String.isNotBlank(leadRec.Receiving_Business__c)){
                jsonLead = jsonLead + '"Receiving_Business__c" : "'+leadRec.Receiving_Business__c+'",';
            }
            if(leadRec.Customer_Discussion_Date__c != null){
                String month = String.valueOf(leadRec.Customer_Discussion_Date__c.month()).leftPad(2, '0');
                String year = String.valueOf(leadRec.Customer_Discussion_Date__c.year());  
                String day = String.valueOf(leadRec.Customer_Discussion_Date__c.day()).leftPad(2, '0');
                String dateFormat = year+'-'+month+'-'+day;
                jsonLead = jsonLead + '"Customer_Discussion_Date__c" : "'+dateFormat+'",';
            }
            if(String.isNotBlank(leadRec.Company)){
                jsonLead = jsonLead + '"Company" : "'+leadRec.Company+'",'; 
            }
            if(String.isNotBlank(leadRec.Street)){
                jsonLead = jsonLead + '"Street" : "'+ leadRec.Street+'",';
            }
            if(String.isNotBlank(leadRec.Country)){
                jsonLead = jsonLead + '"Country" : "'+leadRec.Country+'",';
            }
            if(String.isNotBlank(leadRec.City)){
                jsonLead = jsonLead + '"City" : "'+leadRec.City+'",';
            }
            if(String.isNotBlank(leadRec.State)){
                jsonLead = jsonLead + '"State" : "'+leadRec.State+'",';
            }
            if(String.isNotBlank(leadRec.PostalCode)){
                jsonLead = jsonLead + '"PostalCode" : "'+leadRec.PostalCode+'",';
            }
            if(String.isNotBlank(leadRec.Industry)){
                jsonLead = jsonLead + '"Industry" : "'+leadRec.Industry+'",';
            }
            if(String.isNotBlank(leadRec.FirstName)){
                jsonLead = jsonLead + '"FirstName" : "'+leadRec.FirstName+'",';
            }
            if(String.isNotBlank(leadRec.LastName)){
                jsonLead = jsonLead + '"LastName" : "'+leadRec.LastName+'",';
            }
            if(String.isNotBlank(leadRec.Title)){
                jsonLead = jsonLead + '"Title" : "'+leadRec.Title+'",';
                if(leadRec.Receiving_Business__c == 'BSG' ||
                   leadRec.Receiving_Business__c == 'Commercial HVAC Equipment' ||
                   leadRec.Receiving_Business__c == 'Commercial HVAC Service' ||
                   leadRec.Receiving_Business__c == 'HVAC Controls'){
                    if(!leadRec.Title.contains('Other')){
                        jsonLead = jsonLead + '"Role__c" : "'+leadRec.Title+'",';
                    }else{
                        jsonLead = jsonLead + '"Role__c" : "Other",';
                    }
                }
            }
            if(String.isNotBlank(leadRec.Email)){
                jsonLead = jsonLead + '"Email" : "'+leadRec.Email+'",';
            }
            if(String.isNotBlank(leadRec.Phone)){
                jsonLead = jsonLead + '"Phone" : "'+leadRec.Phone+'",';
            }
            if(String.isNotBlank(leadRec.Customer_Details__c)){
                jsonLead = jsonLead + '"Customer_Details__c" : "'+leadRec.Customer_Details__c+'",';
            }
            if(String.isNotBlank(leadRec.Contact_Details__c)){
                jsonLead = jsonLead + '"Contact_Details__c" : "'+leadRec.Contact_Details__c+'",';
            }
            if(String.isNotBlank(leadRec.Customer_Interest__c)){
                jsonLead = jsonLead + '"Customer_Interest__c" : "'+leadRec.Customer_Interest__c+'",';
            }
            if(String.isNotBlank(leadRec.Customer_Budget__c)){
                jsonLead = jsonLead + '"Customer_Budget__c" : "'+leadRec.Customer_Budget__c+'",';
            }
            if(String.isNotBlank(leadRec.Solutions_Interested__c)){
                jsonLead = jsonLead + '"Solutions_Interested__c" : "'+leadRec.Solutions_Interested__c+'",';
            }
            if(String.isNotBlank(leadRec.LeadSource)){
                jsonLead = jsonLead + '"LeadSource" : "'+leadRec.LeadSource+'"';
            }
            jsonLead = jsonLead + '}';
        }catch(Exception ex){
            system.debug('Exception on line : '+ex.getLineNumber()+' Exception '+ex.getMessage());
        }
        return jsonLead;
    }
      
    //wrapper class
    public class SendLead_Response{
        public String id;
        public Boolean success;
    }
    public class RecordTypeResp{
        public Integer totalSize;	
        public boolean done;
        public RecordTypeWrap[] records; 
    }
    public class RecordTypeWrap{
        public String Name;
        public String Id;
    }
    public class ExtLeadWrap{
        public String Id;
        public String Error;
    }
    public class LeadResp{
        public Integer totalsize;
        public Boolean done;
        public List<LeadWrap> records;
    }
    public class LeadWrap{
        public String Id;
        public Boolean IsConverted;
        public String Status;
        public String StatusReason;
        public String ConvertedOpportunityId;
        public String LeadReferenceId;
        public OwnerWrap Owner;
    }
    public class OpportunityResp{
        public Integer totalSize;	
        public boolean done;
        public OpportunityWrap[] records; 
    }
    public class OpportunityWrap {
        public String Id;	
        public Decimal Amount;
        public String StageName;
        public String StageReason;
        public Boolean IsWon;
        public Boolean IsClosed;
        public OwnerWrap Owner;
    }
    public class OwnerWrap{
        public String Name;
        public String Email;
    }
}