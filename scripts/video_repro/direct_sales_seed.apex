// Direct-sales repro seed script from manual video analysis.
// This file is execute-anonymous compatible.

String captureId = '__CAPTURE_ID__';
if (captureId == '__CAPTURE_ID__') {
    captureId = 'VIDEO_REPRO_' + Datetime.now().formatGMT('yyyyMMdd_HHmmss');
}
System.debug('PROCESS_CAPTURE_ID=' + captureId);
Map<String, Schema.SObjectType> gd = Schema.getGlobalDescribe();

// 1) Account
Account acc;
List<Account> accs = [SELECT Id, Name FROM Account WHERE Name = 'Test Direct Sales Account' LIMIT 1];
if (accs.isEmpty()) {
    acc = new Account(Name = 'Test Direct Sales Account');
    insert acc;
} else {
    acc = accs[0];
}

// 2) Opportunity (stage quoting gate observed in video)
Id stdPbId = [SELECT Id FROM Pricebook2 WHERE IsStandard = true LIMIT 1].Id;
Opportunity opp = new Opportunity(
    Name = 'Nicole Fleming - VideoRepro - ' + captureId,
    AccountId = acc.Id,
    CloseDate = Date.today().addDays(30),
    StageName = 'Quoting',
    Pricebook2Id = stdPbId
);
// Optional custom fields if present in org
if (gd.containsKey('Opportunity')) {
    Map<String, Schema.SObjectField> oppFields = gd.get('Opportunity').getDescribe().fields.getMap();
    if (oppFields.containsKey('End_Customer__c') && oppFields.get('End_Customer__c').getDescribe().isCreateable()) {
        opp.put('End_Customer__c', acc.Id);
    }
    if (oppFields.containsKey('Direct_Sales_Units__c') && oppFields.get('Direct_Sales_Units__c').getDescribe().isCreateable()) {
        opp.put('Direct_Sales_Units__c', 5);
    }
}
insert opp;

// 3) Product line (Vector 8600 - System 16) if product + pricebook entry exists
List<Product2> prod = [SELECT Id, Name, IsActive FROM Product2 WHERE Name = 'Vector 8600 - System 16' LIMIT 1];
if (!prod.isEmpty()) {
    Product2 p = prod[0];
    if (!p.IsActive) {
        p.IsActive = true;
        update p;
    }

    List<PricebookEntry> pbes = [
        SELECT Id, UnitPrice, IsActive
        FROM PricebookEntry
        WHERE Product2Id = :p.Id AND Pricebook2Id = :stdPbId
        LIMIT 1
    ];
    if (!pbes.isEmpty()) {
        PricebookEntry pbe = pbes[0];
        if (!pbe.IsActive) {
            pbe.IsActive = true;
            update pbe;
        }
        OpportunityLineItem oli = new OpportunityLineItem(
            OpportunityId = opp.Id,
            PricebookEntryId = pbe.Id,
            Quantity = 5,
            UnitPrice = pbe.UnitPrice
        );
        insert oli;
    } else {
        System.debug('No pricebook entry found for Vector 8600 - System 16 in Standard Price Book.');
    }
} else {
    System.debug('Product not found: Vector 8600 - System 16');
}

// 4) Opportunity requested ship date record (custom object from video URL)
if (gd.containsKey('Opportunity_Scheduled_Pick_Date__c')) {
    SObject orsd = gd.get('Opportunity_Scheduled_Pick_Date__c').newSObject();
    Map<String, Schema.SObjectField> osrdFields = gd.get('Opportunity_Scheduled_Pick_Date__c').getDescribe().fields.getMap();
    if (osrdFields.containsKey('Name') && osrdFields.get('Name').getDescribe().isCreateable()) {
        orsd.put('Name', 'OSPD-' + Datetime.now().format('HHmmss'));
    }
    if (osrdFields.containsKey('Opportunity__c') && osrdFields.get('Opportunity__c').getDescribe().isCreateable()) {
        orsd.put('Opportunity__c', opp.Id);
    }
    if (osrdFields.containsKey('Requested_Ship_Date__c') && osrdFields.get('Requested_Ship_Date__c').getDescribe().isCreateable()) {
        orsd.put('Requested_Ship_Date__c', Date.today().addDays(20));
    }
    if (osrdFields.containsKey('Requested_Quantity__c') && osrdFields.get('Requested_Quantity__c').getDescribe().isCreateable()) {
        orsd.put('Requested_Quantity__c', 5);
    }
    insert orsd;
}

System.debug('VIDEO_REPRO_ACCOUNT_ID=' + acc.Id);
System.debug('VIDEO_REPRO_OPPORTUNITY_ID=' + opp.Id);
System.debug('PROCESS_CAPTURE_ID=' + captureId);
