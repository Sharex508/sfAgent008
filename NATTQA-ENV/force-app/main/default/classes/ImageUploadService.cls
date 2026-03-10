@RestResource(urlMapping='/ImageUploadService/*')
global with sharing class ImageUploadService{

    @HttpPost
    global static void uploadImageAndCreateManagedContent() {
        
        RestRequest req = RestContext.request;
        String requestBody = req.requestBody.toString();        
        
        Map<String, Object> params = (Map<String, Object>) JSON.deserializeUntyped(requestBody);

        String imageUrl = (String) params.get('imageUrl');
        String imageTitle = (String) params.get('imageTitle');
        String productSKU = (String) params.get('productSKU'); 
        
        ManagedContentSpace workSpaceId = [SELECT Id, Name FROM ManagedContentSpace WHERE Name='PIM - PPG'];
         
        List<ManagedContent> managedContents = [SELECT Id, Name, AuthoredManagedContentSpaceId FROM ManagedContent WHERE AuthoredManagedContentSpaceId= :workSpaceId.Id AND Name= :imageTitle ];
            if (managedContents.size() > 0) {            
            System.debug('Number of rows returned: ' + managedContents.size());
                for (ManagedContent content : managedContents) {                
                Id contentId = content.Id;
                System.debug('ManagedContent ID: ' + contentId);
             String accessToken = FutureContentPublisher.getAccessToken();
             if (accessToken == null) {
                System.debug('Failed to retrieve access token.');
                return;
             }
          unpublishImageContent(contentId, imageUrl, imageTitle, productSKU);
          }
          }
          else {                
                uploadImageAndCreateManagedContentsa(imageUrl, imageTitle, productSKU);
            }
         
    }
    
    public static void uploadImageAndCreateManagedContentsa(String imageUrl, String imageTitle, String productSKU) {
        try {     
            
            Http http = new Http();
            HttpRequest request = new HttpRequest();
            request.setEndpoint(imageUrl);
            request.setMethod('GET');
            HttpResponse response = http.send(request);            
            
            if (response.getStatusCode() == 200) {
                // Step 2: Create a ContentVersion record to upload the image to Salesforce
                ContentVersion contentVersion = new ContentVersion();
                contentVersion.Title = imageTitle;
                contentVersion.PathOnClient = '/' + imageTitle + '.jpg';  
                contentVersion.VersionData = response.getBodyAsBlob();  
                contentVersion.IsMajorVersion = true;
                insert contentVersion;  // Insert the ContentVersion record
                
                // Step 3: Link ContentVersion to ManagedContent (Optional)
                ContentVersion insertedContent = [SELECT Id, ContentDocumentId FROM ContentVersion WHERE Id = :contentVersion.Id LIMIT 1]; 
                System.debug('Uploaded content with ContentDocumentId: ' + insertedContent.ContentDocumentId);
                String ContentDocId = insertedContent.ContentDocumentId;
                
                // Step 4: Add the image into Managed Content Object
                ContentVersion cv = [SELECT Id, ContentDocumentId, ContentDocument.Title, VersionData, FileType FROM ContentVersion WHERE ContentDocumentId = :ContentDocId];
                ConnectApi.BinaryInput contentData = new ConnectApi.BinaryInput(cv.VersionData, 'image/' + cv.FileType.toLowerCase(), cv.ContentDocument.Title + '.' + cv.FileType.toLowerCase());
                
                Map<String, String> typel = new Map<String, String>{ 'type' => 'file', 'mimeType' => 'image/' + cv.FileType.toLowerCase()};
                Map<String, Object> sourcel = new Map<String, Object>{ 'source' => typel };
                Map<String, Object> bodyMap = new Map<String, Object>{ 'sfdc_cms:media' => sourcel };
                
                ConnectApi.ManagedContentBodyInput contentBody = new ConnectApi.ManagedContentBodyInput();
                contentBody.nodeMap = bodyMap;
                ConnectApi.ManagedContentDocumentInput managedContentInput = new ConnectApi.ManagedContentDocumentInput();
                managedContentInput.title = cv.ContentDocument.Title;
                managedContentInput.contentBody = contentBody;
                managedContentInput.contentType = 'sfdc_cms__image';
                managedContentInput.contentSpaceOrFolderId = System.Label.CMS_Inriver_Folder;
                
                ConnectApi.ManagedContentDocument managedContent = ConnectApi.ManagedContent.createManagedContentWithMedia(managedContentInput, contentData);                
            
                Id managedContentId = managedContent.managedContentId;
                
                // Step 5: Call future method in the FutureContentPublisher class to publish the content
                FutureContentPublisher.publishManagedContent(managedContentId);
                
                RecordType recordType = [SELECT Id, Name FROM RecordType WHERE Name='NATT Products'];
                
                //Step 6: Link it to a Product
                Product2 Pdt = [SELECT Id FROM Product2 WHERE CONTAINER_Part_Number__c = :productSKU AND RecordTypeId= :recordType.Id];
                FutureContentPublisher.ImageLinkToProduct(managedContentId, Pdt.Id);
                
            } else {
                System.debug('Failed to download image. Status code: ' + response.getStatusCode());
            }
        } catch (Exception e) {
            System.debug('Error: ' + e.getMessage());
        }
    }
    
    public static void unpublishImageContent(String contentId, String imageUrl, String imageTitle, String productSKU){
    
    try {
    String accessToken = FutureContentPublisher.getAccessToken();
            Http http = new Http(); 
            String baseUrl = System.Label.CMS_BaseURL;
            String endpoint = baseUrl +'/services/data/v58.0/connect/cms/contents/unpublish';
            HttpRequest reqs = new HttpRequest();
            reqs.setEndpoint(endpoint);
            reqs.setMethod('POST');
            reqs.setHeader('Authorization', 'Bearer ' + accessToken);
            reqs.setHeader('Content-Type', 'application/json');
            reqs.setBody('{"description": "Inriver Image", "contentIds": ["' + contentId + '"]}');
            HttpResponse ress = http.send(reqs);
            if (ress.getStatusCode() == 200) {
                System.debug('Success: ' + ress.getBody());   
                uploadImageAndCreateManagedContentsa(imageUrl, imageTitle, productSKU);             
            } else {
                System.debug('Failed with status code: ' + ress.getStatusCode() + ' - ' + ress.getBody());
                uploadImageAndCreateManagedContentsa(imageUrl, imageTitle, productSKU);
            }            
            
    
        }
        catch (Exception e) {
            System.debug('Error: ' + e.getMessage());
        }
    
    }
    
}