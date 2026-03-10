@isTest
public class Dynamic_DataTable_Helper_Test 
{
    static testMethod void testName()
    {
        Test.startTest();
        id recTypeID = Schema.SobjectType.Account.getRecordTypeInfosByName().get('CONTAINER Customer').getRecordTypeId();
        Account acc = new Account();
        acc.Name = 'Test Acc1'; 
        acc.RecordTypeId = recTypeID;
        
        insert acc; 
        //Datetime yesterday = Datetime.now().addDays(-1);
        //Test.setCreatedDate(acc.Id, Datetime.now().addDays(-60));
        
        acc.Name = 'testchange';
        acc.CONTAINER_BaaN_Bill_To_Code__c = 'test';
        update acc;
        
        string str= acc.Id;
        List<Dynamic_DataTable_Helper.DataWrapper> wrapperList = Dynamic_DataTable_Helper.getFieldHistoryList(str);
        FieldHistoryArchive objFieldHistoryArchive = new FieldHistoryArchive();
        //objFieldHistoryArchive.ArchiveFieldName ='test';
        Dynamic_DataTable_Helper.DataWrapper newDataWrap = new Dynamic_DataTable_Helper.DataWrapper(new FieldHistoryArchive());
        newDataWrap.fieldLabel='test';
        newDataWrap.createdDate = system.now();
        test.stopTest();
    }
    
}