@IsTest
public class ContentDocumentLinkHelperTest { 
    @IsTest
    public static void Test1() {
        // Create test data for the LinkedEntity
        Account testAcc1 = new Account(
            Name = 'test acc TT',
            NATT_Division__c = 'Truck Trailer'
        );
        CONTAINER_Service_Agreement__c serviceAgreement = new CONTAINER_Service_Agreement__c(account__c =testAcc1.id );
        insert serviceAgreement;
        
        // Create test ContentDocumentLink records
         Blob beforeblob=Blob.valueOf('Unit Test Attachment Body');

        ContentVersion cv = new ContentVersion();
        cv.title = 'test content trigger';      
        cv.PathOnClient ='test';           
        cv.VersionData =beforeblob;          
        insert cv;         

        ContentVersion testContent = [SELECT id, ContentDocumentId FROM ContentVersion where Id = :cv.Id];

        ContentDocumentLink contentlink=new ContentDocumentLink();
        contentlink.LinkedEntityId=serviceAgreement.id;
        contentlink.ShareType= 'I';
        contentlink.Visibility = 'InternalUsers';
        contentlink.ContentDocumentId=testcontent.ContentDocumentId;

        insert contentlink;
        
        list<ContentDocumentLink> cdlList = new list<ContentDocumentLink>();
        cdlList.add(contentlink);
       Test.startTest();
        ContentDocumentLinkHelper.updateVisiblePermission(cdlList);
        Test.stopTest();
    }
}