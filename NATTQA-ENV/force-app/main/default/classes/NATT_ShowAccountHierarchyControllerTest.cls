@IsTest
public class NATT_ShowAccountHierarchyControllerTest {
    
    @TestSetup
    static void makeData(){
        
        Account currentAccount = NATT_DataFactory.createSimpleAccount();
        
        Account parentOneCurrentAccount = NATT_DataFactory.createSimpleAccount();
        
        currentAccount.ParentId = parentOneCurrentAccount.Id;
        Update currentAccount;
        
        Account brotherCurrentAccount = NATT_DataFactory.createSimpleAccount();
        brotherCurrentAccount.ParentId = parentOneCurrentAccount.Id;
        Update brotherCurrentAccount;
        
        Account childOneBrotherCurrentAccount = NATT_DataFactory.createSimpleAccount();
        childOneBrotherCurrentAccount.ParentId = brotherCurrentAccount.Id;
        Update childOneBrotherCurrentAccount;

        Account childCurrentAccount = NATT_DataFactory.createAccountWithParent(currentAccount.Id);
        
        Account parentTwoCurrentAccount = NATT_DataFactory.createSimpleAccount();        
        parentOneCurrentAccount.ParentId = parentTwoCurrentAccount.Id;
        Update parentOneCurrentAccount;
        
        Account parentThreeCurrentAccount = NATT_DataFactory.createSimpleAccount();        
        parentTwoCurrentAccount.ParentId = parentThreeCurrentAccount.Id;
        Update parentTwoCurrentAccount;
        
        Account parentFourCurrentAccount = NATT_DataFactory.createSimpleAccount();
        parentThreeCurrentAccount.ParentId = parentFourCurrentAccount.Id;
        Update parentThreeCurrentAccount;
        
        Account parentFiveCurrentAccount = NATT_DataFactory.createSimpleAccount();
        parentFourCurrentAccount.ParentId = parentFiveCurrentAccount.Id;
        Update parentFourCurrentAccount;
        
    }

    @IsTest
    static void getAccountHierarchyTest() {
        
        Account current = [SELECT Id, Name, NATT_City_State__c, NATT_Status__c, NATT_Dealer_Principal__r.Name, Owner.Name, NATT_Primary_Location_Type__c FROM Account ORDER BY CreatedDate ASC LIMIT 1];
        
        Test.startTest();
            Map<String, Object> mpReturn = NATT_ShowAccountHierarchyController.getAccountHierarchy(current.Id);
        	Map<String, Object> mpReturnError = NATT_ShowAccountHierarchyController.getAccountHierarchy(NULL);

            System.assertEquals(true, mpReturn.get('success'));
            System.assertEquals(true, mpReturn.get('data') != null);
        
        	System.assertEquals(false, mpReturnError.get('success'));        	
        Test.stopTest();
        
    }

    @IsTest
    static void fetchAccountHierarchyTest() {
        
        Account current = [SELECT Id, Name, NATT_City_State__c, NATT_Status__c, NATT_Dealer_Principal__r.Name, Owner.Name, NATT_Primary_Location_Type__c FROM Account ORDER BY CreatedDate ASC LIMIT 1];
        
        Test.startTest();
            System.assertEquals(true, !NATT_ShowAccountHierarchyController.fetchAccountHierarchy(current.Id).isEmpty());
        Test.stopTest();
        
    }

    @IsTest
    static void getAccountHierarchyObjectTest() {
        
        Account accCurrent = [SELECT Id, Name, NATT_City_State__c, NATT_Status__c, NATT_Dealer_Principal__r.Name, Owner.Name, NATT_Primary_Location_Type__c FROM Account ORDER BY CreatedDate ASC LIMIT 1];
        
        Test.startTest();
        	NATT_ShowAccountHierarchyController.AccountHierarchy accountHierarchy = NATT_ShowAccountHierarchyController.getAccountHierarchyObject(accCurrent, true, '', null);
        	System.assertEquals(accountHierarchy.name, accCurrent.name);
			System.assert(accountHierarchy.isCurrent);        
        Test.stopTest();
        
    }

    @IsTest
    static void buildMapChildrenByFatherTest() {
        
        Account current = [SELECT Id, Name FROM Account ORDER BY CreatedDate ASC LIMIT 1];
        
        List<Account> ltChilds = [SELECT Id, Name, NATT_City_State__c, NATT_Status__c, NATT_Dealer_Principal__r.Name, Owner.Name, NATT_Primary_Location_Type__c FROM Account WHERE ParentId =: current.Id];
        
        Account stepSon = NATT_DataFactory.createAccountWithParent(ltChilds.get(0).Id);
        
        Set<Id> stChildIds = (new Map<Id,Account>(ltChilds)).keySet().clone();
        
        Test.startTest();
            Map<Id, List<Account>> mpChildsByFather = NATT_ShowAccountHierarchyController.buildMapChildrenByFather(stChildIds);
        	System.assert(!mpChildsByFather.get(ltChilds.get(0).Id).isEmpty());
        Test.stopTest();
        
    }

    @IsTest
    static void getNewChildsTest() {
        
        Account current = [SELECT Id, Name, NATT_City_State__c, NATT_Status__c, NATT_Dealer_Principal__r.Name, Owner.Name, NATT_Primary_Location_Type__c FROM Account ORDER BY CreatedDate ASC LIMIT 1];
        current.Name = 'Account For Test Updated';
        
        Update current;
        
        Test.startTest();
            Map<String, Object> mpReturn = NATT_ShowAccountHierarchyController.getNewChildren(current.Name);
        	System.assertEquals(true, mpReturn.get('success'));
        	System.assert(mpReturn.get('data') != null);
        Test.stopTest();
        
    }

}