@isTest
public class ContentDocumentLinkBatchTest {
    
   @isTest
    static void testBatchExecution() {
        Id customerAccountRecordTypeId = Schema.SObjectType.Account.getRecordTypeInfosByName().get('CONTAINER Authorized Service Provider').getRecordTypeId();
        
        Account testAccount = new Account(
            Name = 'Test Account UCP1',
            RecordTypeId = customerAccountRecordTypeId
        );
        insert testAccount;
         CONTAINER_Service_Agreement__c serviceAgreement = new CONTAINER_Service_Agreement__c(account__c =testAccount.id );
        insert serviceAgreement;
        
        // Create test ContentDocumentLink records
        Blob beforeblob=Blob.valueOf('Unit Test Attachment Body for UCP');
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
        contentlink.ContentDocumentId = testcontent.ContentDocumentId;
        insert contentlink;
        
        list<ContentDocumentLink> lstCDL = [SELECT Id, ShareType, LinkedEntityId, ContentDocumentId,Visibility FROM ContentDocumentLink 
                                            WHERE ContentDocumentId =: contentlink.ContentDocumentId];
        system.debug('lstCDL-'+ lstCDL);
         ContentDocumentLinkBatch batch = new ContentDocumentLinkBatch();
        Database.executeBatch(batch, 10); 
    }
    
  
}