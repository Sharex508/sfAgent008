/**************
Author: LTI
Description: Callout to UAT org to fetch unit information and related details in source org
Created date: 10 September 2021
**************/
global without sharing class UnitInformationCallout{
    public List<UnitResponse> responseFinal{set;get;}    
    public string serialNum{set;get;}
    public string modalNum{set;get;}
    public string contNum{set;get;}
    public string vinNum{set;get;}
    public string ownerName{set;get;}
    public date installDate{set;get;}
    
    public List<FieldAction> fieldActionList{set;get;}
    public List<Claim> claimList {set;get;}
    public List<WarrantyCoverage> warrantyList{set;get;}
    public List<upcomingSchedule> upcomingSchList{get;set;}
    public List<MajorComponent> majorCompList{get;set;}
    
    public void GeneratePdf(){
        String searchKey1 = apexpages.currentpage().getparameters().get('searchKeyValue1');
        List<UnitResponse> responseFinal = doCallout(searchKey1);
        
        system.debug('this response'+responseFinal);
        if(responseFinal.size() != 0){
            UnitResponse unitResponse = responseFinal[0]; 
            Unit unit = unitResponse.unit;
            
            serialNum = unit.unitSerialNumber;
            modalNum = unit.unitModelNumber;
            contNum = unit.containerNumber;
            vinNum = unit.vinNumber;
            ownerName = unit.ownerName;
            installDate = unit.installDate;
            
            fieldActionList = unitResponse.fieldActions;    
            warrantyList = unitResponse.warrantyCoverages;
            List<WarrantyEndDateSort> wList = new List<WarrantyEndDateSort>();
            for(WarrantyCoverage wc : warrantyList){
                wList.add(new WarrantyEndDateSort(wc));
            }
            wList.sort();
            
            for(Integer i = 0; i < warrantyList.size(); i++){
              warrantyList[i] = wList[i].wc;
            }
            
            upcomingSchList = unitResponse.upcomingSchedules;
            majorCompList = unitResponse.majorComponents;
            claimList = unitResponse.claims;
        }
    }
    public class WarrantyEndDateSort implements Comparable{
        public WarrantyCoverage wc;
        public WarrantyEndDateSort(WarrantyCoverage wCov) {
            wc = wCov;
        }
        public Integer compareTo(Object objToCompare) {
            WarrantyEndDateSort wc1 = (WarrantyEndDateSort)objToCompare;
            if (this.wc.warrantyEndDate < wc1.wc.warrantyEndDate){
                return -1;
            } else if (this.wc.warrantyEndDate > wc1.wc.warrantyEndDate) {
                return 1;
            } else {
                return 0;
            }
        }
    }
    
    //callout method
    @AuraEnabled
    public static List<UnitResponse> doCallout(String searchKey){        
        final String calloutEndpoint = 'callout:UATCallout/services/apexrest/unitLookUpGeneral/*';
        List<UnitResponse> respLst = new List<UnitResponse>();
        RestUnitRequest req = new RestUnitRequest();
        req.serialContainerNumber = searchKey.trim(); //60968374 ,NAX91300170
        
        try{
            HttpResponse response = new HttpResponse();
            HttpRequest request = new HttpRequest();
            Http http = new Http();
            
            request.setHeader('Content-Type', 'application/json;charset=UTF-8');
            request.setEndpoint(calloutEndpoint);
            request.setMethod('POST');
            request.setTimeout(120000);
            request.setBody(System.JSON.serialize(req, true));
            
            if(!Test.isRunningTest()){
                response = http.send(request); // call out action
            }
            else{
                response = UnitInformationCalloutMock.getResp();
            }
            
            if (response.getStatusCode() == 200) {
                respLst = (List<UnitResponse>)JSON.deserialize(response.getBody(), List<UnitResponse>.class);
                system.debug('respLst::'+respLst);
            }
        }
        catch(Exception e){
            System.debug('Error-' + e.getMessage());   
        }   
        //return resposne
        return respLst;
    }
    
    public class UnitResponse {       
        @AuraEnabled public Unit unit {get;set;}
        @AuraEnabled public List<WarrantyCoverage> warrantyCoverages {get;set;}
        @AuraEnabled public List<FieldAction> fieldActions {get;set;}
        @AuraEnabled public List<MajorComponent> majorComponents {get;set;}
        @AuraEnabled public List<Claim> claims{get;set;}
        @AuraEnabled public List<upcomingSchedule> upcomingSchedules{get;set;}
    }  
    
    public class Unit {
        @AuraEnabled public String unitSerialNumber {get;set;}
        @AuraEnabled public String unitModelNumber {get;set;}
        @AuraEnabled public String ownerName {get;set;}
        @AuraEnabled public String containerNumber {get;set;}
        @AuraEnabled public String vinNumber {get;set;}
        @AuraEnabled public Date installDate{get;set;}
    }
    
    public class WarrantyCoverage {
        @AuraEnabled public String description{get;set;}
        @AuraEnabled public Decimal months{get;set;}
        @AuraEnabled public Date warrantyStartDate{get;set;}
        @AuraEnabled public Date warrantyEndDate{get;set;}
        @AuraEnabled public String warrantyType{get;set;} 
        @AuraEnabled public Decimal usage{get;set;}
        @AuraEnabled public Double deductibles{get;set;}
    } 
    
    public class FieldAction {
        @AuraEnabled public String serviceFieldAction{get;set;}
        @AuraEnabled public String status{get;set;}
        @AuraEnabled public String fieldActionStatus{get;set;}
        @AuraEnabled public String fieldActionDescription{get;set;}
    } 
    
    
    public class MajorComponent {
        @AuraEnabled public String partDescription{get;set;}
        @AuraEnabled public String modelPartInformation{get;set;}
        @AuraEnabled public String serialNumber{get;set;}
    }
    
    public with sharing class Claim{
        @AuraEnabled public String claimNumber{get;set;}
        @AuraEnabled public Date dateOfFailure{get;set;}
        @AuraEnabled public String casualPartDescription{get;set;}
        @AuraEnabled public String claimType{get;set;}
    }
    
    public with sharing class upcomingSchedule{
        @AuraEnabled public String contractMaintenance{get;set;}
        @AuraEnabled public String claim{get;set;}
        @AuraEnabled public String inventoryName{get;set;}
        @AuraEnabled public String status{get;set;}
    }
    
    public class RestUnitRequest {
        public String serialContainerNumber;
    }
}