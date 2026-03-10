/*********************
Name of Test Class: TestShareFilesWithCommunityUsers_test
======================================================
History
-------
 AUTHOR                  DATE           DETAIL                 Description
 Mahesh Meesala         18/10/2022      INITIAL CarStage       
*********************/
@IsTest
Public class ShareFilesWithCommunityUsers_test {
    
    static testmethod void SetFileVisibilityForKnowledgeTest(){
        Test.startTest();
		User u=[Select Name, ID from User where UserPermissionsKnowledgeUser=true AND  isActive = TRUE  limit 1];
        System.runAS(u){
        Knowledge__kav knowledge = New Knowledge__kav(Title='TestKnowledge', UrlName='Test-Visiblity4-com');
        insert knowledge;
        
        ContentVersion content=new ContentVersion(); 
        content.Title='Header_Picture1'; 
        content.PathOnClient='/' + content.Title + '.jpg'; 
        Blob bodyBlob=Blob.valueOf('Unit Test ContentVersion Body'); 
        content.VersionData=bodyBlob; 
        //content.LinkedEntityId=sub.id;
        content.origin = 'H';
        insert content;
        ContentDocumentLink contentlink=new ContentDocumentLink();
        contentlink.LinkedEntityId=knowledge.id;
        contentlink.contentdocumentid=[select contentdocumentid from contentversion where id =: content.id].contentdocumentid;
        //contentlink.ShareType = 'I';
        contentlink.Visibility = 'AllUsers'; 
        insert contentlink;
        Test.stopTest();
        }
    }
}