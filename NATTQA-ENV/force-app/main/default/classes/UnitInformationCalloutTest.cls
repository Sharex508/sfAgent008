/**************
Author: LTI
Description: Test class for UnitInformationCallout
Created date: 10 September 2021
**************/
@isTest
public class UnitInformationCalloutTest {
    
    static testmethod void doCalloutTest(){
        Test.startTest();
        List<UnitInformationCallout.UnitResponse> respLst = new List<UnitInformationCallout.UnitResponse>();
        respLst = UnitInformationCallout.doCallout('60968374');
        Test.stopTest();
        
        //Assertion check
        
        UnitInformationCallout.Unit unitObj = respLst[0].unit;
        system.assertEquals(unitObj.unitSerialNumber, '60968374');
        system.assertEquals(unitObj.vinNumber, '6876');
        system.assertEquals(unitObj.ownerName, 'Pride Transport Inc');
        system.assertEquals(unitObj.unitModelNumber, '69NT40561500');
        system.assertEquals(unitObj.containerNumber, '9862704');
        
        List<UnitInformationCallout.WarrantyCoverage> warrantyCoverages = respLst[0].warrantyCoverages;
        system.assertEquals(warrantyCoverages.size(), 2);
        
        for(UnitInformationCallout.WarrantyCoverage coverage : warrantyCoverages){
            if(coverage.description == 'Unit'){
                system.assertEquals(coverage.description, 'Unit');
                system.assertEquals(coverage.usage, 9999999.00);
                system.assertEquals(coverage.warrantyType, 'Standard');
                system.assertEquals(coverage.months, 12);
                system.assertEquals(coverage.deductibles, 12.00);
            }
        }
        
        List<UnitInformationCallout.FieldAction> fieldActions = respLst[0].fieldActions;
        system.assertEquals(fieldActions.size(), 2);
        
        for(UnitInformationCallout.FieldAction fieldAction : fieldActions){
            if(fieldAction.fieldActionDescription == 'APX Recall'){
                System.assertEquals(fieldAction.fieldActionDescription, 'APX Recall');
                System.assertEquals(fieldAction.fieldActionStatus, 'Active');
                System.assertEquals(fieldAction.serviceFieldAction, 'R-924');
                System.assertEquals(fieldAction.status, 'Pending');
            }
        }
        
        List<UnitInformationCallout.MajorComponent> majorComponents = respLst[0].majorComponents;
        system.assertEquals(majorComponents.size(), 2);
        
        for(UnitInformationCallout.MajorComponent majorCmp : majorComponents){
            if(majorCmp.partDescription == 'COMPRESSOR SCROLL'){
                system.assertEquals(majorCmp.modelPartInformation, '18-00091-05');
                system.assertEquals(majorCmp.serialNumber, '19J6248DT');
            }
        }
        
        List<UnitInformationCallout.Claim> claims = respLst[0].claims;
        system.assertEquals(claims.size(), 2);
        
        for(UnitInformationCallout.Claim claimObj : claims){
            if(claimObj.claimNumber == 'A0028793'){
                system.assertEquals(claimObj.claimType, 'unit');
                system.assertEquals(claimObj.claimNumber, 'A0028793');
                system.assertEquals(claimObj.casualPartDescription, '25-15568-00SV');
            }
        }
        
        List<UnitInformationCallout.upcomingSchedule> upcomingSchedules = respLst[0].upcomingSchedules;
        system.assertEquals(upcomingSchedules.size(), 1);
        
        for(UnitInformationCallout.upcomingSchedule upcmngSchedule : upcomingSchedules){
            system.assertEquals(upcmngSchedule.contractMaintenance, 'TestTTContractMain123');
            system.assertEquals(upcmngSchedule.claim, 'A1575750');
            system.assertEquals(upcmngSchedule.inventoryName, 'Test_TT_16');
            system.assertEquals(upcmngSchedule.status, 'Completed');
        }
    }
    
    static testmethod void GeneratePdfTest(){
                
        Test.startTest();
        ApexPages.currentPage().getParameters().put('searchKeyValue1','60968374');
		List<UnitInformationCallout.UnitResponse> respLst = new List<UnitInformationCallout.UnitResponse>();
        respLst = UnitInformationCallout.doCallout('60968374');
		UnitInformationCallout uic = new UnitInformationCallout();
        UnitInformationCallout.Unit unit1 = new UnitInformationCallout.Unit();
        unit1 = respLst[0].Unit;
        uic.responseFinal = respLst;
        uic.serialNum = '60968374';
        uic.modalNum = '69NT40561500';
        uic.contNum = '9862704';
        uic.vinNum = '6876';
        uic.ownerName = 'Pride Transport Inc';
        uic.fieldActionList = respLst[0].fieldActions;
		uic.claimList = respLst[0].claims;
        uic.warrantyList = respLst[0].warrantyCoverages;
        uic.upcomingSchList = respLst[0].upcomingSchedules;
        uic.majorCompList = respLst[0].majorComponents;
        uic.installDate = System.today() - 5;
        uic.GeneratePdf();
        system.assertEquals(uic.serialNum, '60968374');
        Test.stopTest();                
        
    }
}