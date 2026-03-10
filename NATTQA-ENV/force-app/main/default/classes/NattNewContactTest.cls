@IsTest
private class NattNewContactTest {
	@IsTest
    private static void myUnitTest(){
        List<Account> aList = new List<Account>([SELECT Id,RecordType.DeveloperName FROM Account]);        
        for(Account a : aList){
            NattNewContact.getRtId(a.Id);
        }
    }
    
    @TestSetup
    private static void setupData(){
        List<Account> aList = new List<Account>();
        for(RecordType rt : [SELECT Id FROM RecordType WHERE SobjectType='Account' AND IsActive=true]){
            aList.add(new Account(Name='Test',RecordTypeId=rt.Id));
        }
        insert aList;
    }
}