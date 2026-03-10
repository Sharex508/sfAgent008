/**************
Author: LTI
Description: Mock class for UnitInformationCallout
Created date: 10 September 2021
**************/
@isTest
public class UnitInformationCalloutMock {
    
    public static HTTPResponse getResp(){
        
        HttpResponse response = new HttpResponse();
        response.setHeader('Content-Type', 'application/json');
        
        response.setBody(' [{ '+
                         ' "warrantyCoverages" : [ { ' +
                         ' "warrantyType" : "Standard", ' +
                         ' "warrantyStartDate" : "2020-05-22", ' +
                         ' "warrantyEndDate" : "2021-05-22", ' +
                         ' "usage" : 9999999.00, ' +
                         ' "months" : "12", ' +
                         ' "deductibles" : "12.00", ' +
                         ' "description" : "Unit" ' +
                         ' }, { ' +
                         ' "warrantyType" : "Standard", ' +
                         ' "warrantyStartDate" : "2020-05-22", ' +
                         ' "warrantyEndDate" : "2023-05-22", ' +
                         ' "usage" : 9999999.00, ' +
                         ' "months" : "36", ' +
                         ' "deductibles" : "12.00", ' +
                         ' "description" : "Compressor" ' +
                         ' }], ' +
                         
                         ' "unit" : { ' +
                         ' "unitSerialNumber" : "60968374", ' +
                         ' "ownerName" : "Pride Transport Inc", ' +
                         ' "vinNumber" : "6876", ' +
                         ' "unitPrefix" : "TSW", ' +
                         ' "unitModelNumber" : "69NT40561500", ' +
                         ' "pId" : "NT3003", ' +
                         ' "containerPrefix" : "SEGU", ' +
                         ' "containerNumber" : "9862704", ' +
                         ' "containerGensetId" : "9862704" ' +
                         ' }, ' +
                         
                         ' "majorComponents" : [ { ' +
                         ' "serialNumber" : "19J6248DT", ' +
                         ' "modelPartInformation" : "18-00091-05", ' +
                         ' "installDate" : "2020-05-22", ' +
                         ' "partDescription" : "COMPRESSOR SCROLL", ' +
                         ' "componentName" : "19J6248DT" ' +
                         ' }, {  '+
                         ' "serialNumber" : "04606619", ' +
                         ' "modelPartInformation" : "18-00091-05", ' +
                         ' "installDate" : "2020-05-22", ' +
                         ' "partDescription" : "MICRO,ML3,UNCONFGRD,(SCROLL)", ' +
                         ' "componentName" : "04606619" ' +
                         ' }], ' + 
                         
                         ' "fieldActions" : [ { ' + 
                         ' "status" : "Pending", ' + 
                         ' "serviceFieldAction" : "R-924", ' + 
                         ' "fieldActionStatus" : "Active", ' + 
                         ' "fieldActionDescription" : "APX Recall" ' + 
                         ' }, { ' + 
                         ' "status" : "Completed", ' + 
                         ' "serviceFieldAction" : "R-937", ' + 
                         ' "fieldActionStatus" : "Active", ' + 
                         ' "fieldActionDescription" : "X4 Wiring Harness Support Rod" ' + 
                         ' } ], ' + 
                         
                         ' "upcomingSchedules": [{ ' +
                         ' "status" : "Completed", ' +
                         ' "inventoryName" : "Test_TT_16", ' +
                         ' "contractMaintenance" : "TestTTContractMain123", ' +
                         ' "claim" : "A1575750" ' +
                         ' } ], ' + 
                         
                         ' "claims" : [ {  ' + 
                         ' "dateOfFailure" : "2017-02-23", ' + 
                         ' "claimType" : "unit", ' + 
                         ' "claimNumber" : "17D160001", ' + 
                         ' "casualPartNumber" : "CN" ' + 
                         ' }, { ' + 
                         ' "dateOfFailure" : "2014-12-19", ' + 
                         ' "claimType" : "unit", ' + 
                         ' "claimNumber" : "A0028793", ' + 
                         ' "casualPartDescription" : "25-15568-00SV" ' + 
                         ' } ] ' +
                         ' } ] '); 
        
        response.setStatusCode(200);
        return response; 
    }
}