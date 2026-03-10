@IsTest
private class AddressTriggerHandlerNATTTest {

    @TestSetup
    static void makeData() {
        Account accMailing              = NATT_DataFactory.createAccountWithName('Account Mailing');
        Account accHeadquarters         = NATT_DataFactory.createAccountWithName('Account Headquarters');
        Account accPhysical         	= NATT_DataFactory.createAccountWithName('Account Physical');
        NATT_Address__c addMailing      = NATT_DataFactory.createNATTAddress(accMailing, NATT_Constants.NATT_ADDRESS_TYPE_MAILING, 'jde alpha mailing');
        NATT_Address__c addHeadquarters = NATT_DataFactory.createNATTAddress(accHeadquarters, NATT_Constants.NATT_ADDRESS_TYPE_HEADQUARTERS, 'jde alpha headquarters');
        NATT_Address__c addPhysical 	= NATT_DataFactory.createNATTAddress(accPhysical, NATT_Constants.NATT_ADDRESS_TYPE_PHYSICAL, null);
    }

    @IsTest
    public static void handleBeforeInsertTest() {
        NATT_Address__c add = [SELECT Id, Name, NATT_City__c, NATT_State_Province__c, NATT_JDE_Alpha_Name__c, NATT_Type__c  FROM NATT_Address__c WHERE NATT_Type__c = :NATT_Constants.NATT_ADDRESS_TYPE_MAILING LIMIT 1];

        Test.startTest();
            System.assertEquals(add.NATT_Type__c + ' - ' + add.NATT_JDE_Alpha_Name__c + ' - ' + add.NATT_City__c + ' - ' + add.NATT_State_Province__c, add.Name);
        Test.stopTest();
        
        delete add;
    }
    
    @IsTest
    public static void testAddressTypeChange() {
        NATT_Address__c add = [SELECT Id, Name, NATT_City__c, NATT_State_Province__c, NATT_JDE_Alpha_Name__c, NATT_Type__c  FROM NATT_Address__c WHERE NATT_Type__c = :NATT_Constants.NATT_ADDRESS_TYPE_MAILING LIMIT 1];
        add.NATT_Type__c='Other Mailing';
        update add;
    }

    @IsTest
    public static void handleAfterInsertTest() {
        NATT_Address__c add = [SELECT Id FROM NATT_Address__c WHERE NATT_Type__c = :NATT_Constants.NATT_ADDRESS_TYPE_MAILING LIMIT 1];
        Account acc = [SELECT Id, Name, NATT_Address_Mailing__c FROM Account WHERE Name = 'Account Mailing' LIMIT 1];

        Test.startTest();
            System.assertEquals(add.Id, acc.NATT_Address_Mailing__c);
        Test.stopTest();
    }

    @IsTest
    public static void handleBeforeUpdateTest() {
        NATT_Address__c add = [SELECT Id, NATT_JDE_Alpha_Name__c FROM NATT_Address__c WHERE NATT_Type__c = :NATT_Constants.NATT_ADDRESS_TYPE_MAILING LIMIT 1];
        
        add.NATT_JDE_Alpha_Name__c = 'jde alpha updated';
        Update add;
        
        NATT_Address__c addUpdated = [SELECT Id, Name, NATT_City__c, NATT_State_Province__c, NATT_JDE_Alpha_Name__c, NATT_Type__c FROM NATT_Address__c WHERE NATT_Type__c = :NATT_Constants.NATT_ADDRESS_TYPE_MAILING LIMIT 1];

        Test.startTest();
        	System.assertEquals(addUpdated.NATT_Type__c + ' - ' + addUpdated.NATT_JDE_Alpha_Name__c + ' - ' + addUpdated.NATT_City__c + ' - ' + addUpdated.NATT_State_Province__c, addUpdated.Name);
        Test.stopTest();
    }

    @IsTest
    public static void handleAfterUpdateTest() {
        NATT_Address__c add = [SELECT Id, NATT_Type__c FROM NATT_Address__c WHERE NATT_Type__c = :NATT_Constants.NATT_ADDRESS_TYPE_HEADQUARTERS LIMIT 1];
        Account acc = [SELECT Id, Name, NATT_Address_Physical__c FROM Account WHERE Name = 'Account Headquarters' LIMIT 1];
        
        add.NATT_Type__c = NATT_Constants.NATT_ADDRESS_TYPE_PHYSICAL;
        Update add;

        Account accUpdated = [SELECT Id, Name, NATT_Address_Physical__c FROM Account WHERE Name = 'Account Headquarters' LIMIT 1];

        Test.startTest();
            System.assertEquals(add.Id, accUpdated.NATT_Address_Physical__c);
        Test.stopTest();
    }
    
    @IsTest
    public static void addressWithoutJDEAlphaNameTest() {
        NATT_Address__c add = [SELECT Id, Name, NATT_Type__c, NATT_City__c, NATT_State_Province__c FROM NATT_Address__c WHERE NATT_Type__c = :NATT_Constants.NATT_ADDRESS_TYPE_PHYSICAL LIMIT 1];
        
        Test.startTest();
            System.assertEquals(add.NATT_Type__c + ' - ' + add.NATT_City__c + ' - ' + add.NATT_State_Province__c, add.Name);
        Test.stopTest();
    }

}