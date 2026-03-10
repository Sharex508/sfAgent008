/********
Author : LTI
Description : 1) When non technician contact is deleted in NATT org, that same contact should be deleted in Tavant org also
2) When NATT_Refrigeration_Technician__c contact is deleted in NATT org, in TAVANT it should be marked as In Active and Email should be send to Admin.
Created date : 20 September 2021
*********/
public class ContactDeleteCallout {
    
    Public static Boolean firstcall = false;
    Private static final String calloutEndpoint = 'callout:UATCallout/services/apexrest/contactSync/'; 
    
    public static void contactDelete(List<SObject> trgNew){
        List<String> technicianCons = new List<String>();
        List<String> nonTechnicianCons = new List<String>();
        
        for (SObject contSobj : trgNew) {
            Contact con = (Contact) contSobj;
            
            if(con.NATT_Record_Type_Developer_Name__c  == 'NATT_Dealer'){
                if(con.NATT_Refrigeration_Technician__c){
                    technicianCons.add(con.NATT_Contact_Number__c);
                }
                else{
                    nonTechnicianCons.add(con.NATT_Contact_Number__c);
                }
            }
        }
        
        //Technician contacts to be set as Inactive and send email in destination org
        if(!technicianCons.isEmpty()){
            TechnicianContactWrapper wrap = new TechnicianContactWrapper();
            wrap.conNumber = technicianCons;
            String technicianJSONBody = System.JSON.serialize(wrap, true);
            doCallout(technicianJSONBody, 'Technician Payload');
        }
        
        //Non technician contacts to be deleted from destination org
        if(!nonTechnicianCons.isEmpty()){
            String nonTechnicianJSONBody = String.join(nonTechnicianCons,',');
            doCallout(nonTechnicianJSONBody, 'Non Technician Payload');
        }
    }
    
    @future(callout = true)
    public static void doCallout( String jsonBody, String payloadType){
        String jsonResponse;
        
        try{
            HttpResponse response = new HttpResponse();
            HttpRequest request = new HttpRequest();
            
            Http http = new Http();
            
            request.setHeader('Content-Type', 'application/json;charset=UTF-8');
            
            if(payloadType == 'Technician Payload'){
                System.debug('********************Technician Payload callout**************'+jsonBody);
                request.setEndpoint(calloutEndpoint);
                request.setMethod('PUT');
                request.setBody(jsonBody);
            }
            
            if(payloadType == 'Non Technician Payload'){
                System.debug('********************Non Technician Payload callout**************'+jsonBody);
                request.setEndpoint(calloutEndpoint+jsonBody);
                request.setMethod('DELETE');
            }
            
            request.setTimeout(120000);
            System.debug('--------------request------------ '+request.getBody());
            
            if(!Test.isRunningTest()){
                response = http.send(request);
            }
            else{
                //mock class response not required as no logic is performed on response received
            }
            
            if (response.getStatusCode() == 200) {
                jsonResponse = response.getBody();
                System.debug('-----------------jsonResponse--------------------- '+jsonResponse);
            }
        }
        catch(Exception e){
            System.debug('Error-' + e.getMessage());   
        }
    }
    
    public class TechnicianContactWrapper{
        public List<String> conNumber;
    }
}