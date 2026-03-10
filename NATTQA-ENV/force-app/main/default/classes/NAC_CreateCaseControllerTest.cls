@IsTest
public class NAC_CreateCaseControllerTest {
    
    @IsTest
    static void getFieldsTest(){
        system.runAs(NAC_TestDataFactory.runAsNACUser()){
            Test.startTest();
            NAC_CreateCaseController.caseWrapper caseWrap = NAC_CreateCaseController.getCaseDetails('Case');
            Test.stopTest();
            System.assertNotEquals(caseWrap.coreFields, null, 'case creation failed');
            System.assertNotEquals(caseWrap.performancePartsFields, null, 'case creation failed');
        }
    }
    
    @IsTest
    static void createCoreReturnsTest(){
        Case cs = new Case();
        cs.RecordTypeId = Schema.SObjectType.Case.getRecordTypeInfosByName().get('NAOCAP Core Return').getRecordTypeId();
        cs.Status = 'New';
        cs.Type = 'Core Return';
        cs.NATT_Case_Reason__c = 'Core Return';
        insert cs;
        
        MAp<String,String> caseMap=new MAp<String,String>();
        String s=string.valueOfGmt(date.today());
        //Case cs=[SELECT Id, RecordTypeId, RecordType.Name FROM Case where RecordType.Name ='NAOCAP Core Return' LIMIT 1];
        caseMap.put('NATT_Date_of_Entry__c',s);
        List<MAp<String,sTring>> ListOfMap=new List<MAp<String,sTring>>();
        ListOfMap.add(caseMap);
        Test.startTest(); 
        NAC_CreateCaseController.resultWrapper resWrapper=NAC_CreateCaseController.createCoreReturns(caseMap,ListOfMap);
        NAC_CreateCaseController.resultWrapper resWrapperPfpart=NAC_CreateCaseController.createPerfPartReturns(caseMap,ListOfMap);
        NAC_CreateCaseController.resultWrapper returnedCreatePerfPartReturnInternal=NAC_CreateCaseController.createPerfPartReturnInternal(caseMap,ListOfMap,cs.id);
        Test.stopTest();
        System.assertNotEquals(resWrapper, null, 'case creation failed');
        System.assertNotEquals(resWrapperPfpart, null, 'case creation failed');
        System.assertNotEquals(returnedCreatePerfPartReturnInternal, null, 'case creation failed'); 
    }
    
    @IsTest
    static void fetchLookupData(){
        Test.startTest();
        list<sObject> sObjList=NAC_CreateCaseController.fetchLookupData('Test','ATL','Product2','test');
        Test.stopTest();
        System.assertNotEquals(sObjList.size(), null, 'case creation for a product failed'); 
    }
}