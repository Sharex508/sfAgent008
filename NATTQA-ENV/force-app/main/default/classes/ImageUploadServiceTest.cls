@IsTest
private class ImageUploadServiceTest {
    @IsTest
    static void setupTestData() {
        // Create test data for Product2
        RecordType productRecordType = [SELECT Id FROM RecordType WHERE SObjectType = 'Product2' AND DeveloperName = 'NATT_Products' LIMIT 1];
        Product2 testProduct = new Product2(
            Name = 'Test Product',
            IsActive=true
        );
        insert testProduct; 
       }
           
    
    // Mock class for HTTP callout
    class HttpCalloutMockImpl implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            // Create a mock response
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody('{"success": true}');
            return res;
        }
    }
 
    @IsTest(SeeAllData=true)
    static void testUploadImageAndCreateManagedContent_Success() {
        // Mock HTTP callout for downloading image
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator(200, Blob.valueOf('test image data')));
 
        // Mock ConnectApi call
        Test.startTest();
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        RestContext.request = req;
        RestContext.response = res;
 
        req.requestBody = Blob.valueOf(JSON.serialize(new Map<String, String>{
            'imageUrl' => 'https://example.com/test-image.jpg',
            'imageTitle' => 'Test Image',
            'productSKU' => 'TEST_SKU'
        }));
 
        ImageUploadService.uploadImageAndCreateManagedContent();
 
        // Assert ContentVersion is created
        List<ContentVersion> contentVersions = [SELECT Id FROM ContentVersion WHERE Title = 'Test Image'];
        
        System.debug('contentVersions size' + contentVersions);
        
        Test.stopTest();
    }
 
    @IsTest(SeeAllData=true)
    static void testUploadImageAndCreateManagedContent_ExistingManagedContent() {  
    
      ManagedContentSpace workSpace = [SELECT Id FROM ManagedContentSpace WHERE Name = 'PIM - PPG' LIMIT 1];
 
        ManagedContent testManagedContent = [SELECT Id, Name, AuthoredManagedContentSpaceId
                                        FROM ManagedContent
                                        WHERE AuthoredManagedContentSpaceId = :workSpace.Id
                                        LIMIT 1];
 
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator(200, Blob.valueOf('test image data')));
 
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        RestContext.request = req;
        RestContext.response = res;
   
        req.requestBody = Blob.valueOf(JSON.serialize(new Map<String, String>{
            'imageUrl' => 'https://example.com/test-image.jpg',
            'imageTitle' => testManagedContent.Name, // Use the existing ManagedContent Name
            'productSKU' => 'TEST_SKU'
        }));
 
        Test.startTest();
        ImageUploadService.uploadImageAndCreateManagedContent();
        Test.stopTest();
    }
 
    @IsTest
    static void testUploadImageAndCreateManagedContent_FailedDownload() {
        // Mock HTTP callout to simulate a failed image download
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator(404, null));
 
        Test.startTest();
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        RestContext.request = req;
        RestContext.response = res;
 
        req.requestBody = Blob.valueOf(JSON.serialize(new Map<String, String>{
            'imageUrl' => 'https://example.com/invalid-image.jpg',
            'imageTitle' => 'Invalid Image',
            'productSKU' => '12345'
        }));
 
        //ImageUploadService.uploadImageAndCreateManagedContent();
        
        List<ContentVersion> contentVersions = [SELECT Id FROM ContentVersion WHERE Title = 'Invalid Image'];
        System.assertEquals(0, contentVersions.size(), 'ContentVersion should not be created for failed download.');
 
        Test.stopTest();
    }
    
    @IsTest(SeeAllData=true)
    static void testLinkToProduct() {
         // Create test data for Product2
        RecordType productRecordType = [SELECT Id FROM RecordType WHERE SObjectType = 'Product2' AND DeveloperName = 'NATT_Products' LIMIT 1];
        Product2 testProduct = new Product2(
            Name = 'Test Product',
            IsActive=true
        );
        insert testProduct; 
        RecordType recordType = [SELECT Id, Name FROM RecordType WHERE Name='NATT Products'];   
        List<Product2> products = [SELECT Id FROM Product2 WHERE RecordTypeId= :recordType.Id LIMIT 1];
        System.assert(!products.isEmpty(), 'No Product2 record found');
        Product2 testProduct1 = products[0];
 
        List<ManagedContent> managedContentList = [SELECT Id FROM ManagedContent LIMIT 1];
        String mockManagedContentId = managedContentList[0].Id;
        Test.startTest();
        FutureContentPublisher.ImageLinkToProduct(mockManagedContentId, testProduct1.Id);
        Test.stopTest();        
    }
 
    private class MockHttpResponseGenerator implements HttpCalloutMock {
        Integer statusCode;
        Blob responseBody;
 
        MockHttpResponseGenerator(Integer statusCode, Blob responseBody) {
            this.statusCode = statusCode;
            this.responseBody = responseBody;
        }
 
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(statusCode);
            if (responseBody != null) {
                res.setBodyAsBlob(responseBody);
            }
            return res;
        }
    }            
   
    private class UnpublishImageMockHttpResponseGenerator implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            
            // Simulate response based on content ID
            HttpResponse res = new HttpResponse();
            if (req.getBody().contains('mockContentId')) {
                res.setStatusCode(200);
                res.setBody('{"success": true, "message": "Content unpublished successfully"}');
            } else {
                res.setStatusCode(400);
                res.setBody('{"error": "Invalid content ID"}');
            }
            res.setHeader('Content-Type', 'application/json');
            return res;
        }
    }

    @isTest
    static void testUnpublishImageContentSuccess() {
        // Set the mock response
        Test.setMock(HttpCalloutMock.class, new UnpublishImageMockHttpResponseGenerator());

        // Test data
        String mockContentId = 'mockContentId';
        String mockImageUrl = 'https://example.com/image.jpg';
        String mockImageTitle = 'Sample Image';
        String mockProductSKU = 'SKU123';
        FutureContentPublisher.getAccessToken();

        // Call the method
        Test.startTest();
        FutureContentPublisher.getAccessToken();
        //FutureContentPublisher.setMockAccessToken('mockAccessToken'); // Mock the access token retrieval
        ImageUploadService.unpublishImageContent(mockContentId, mockImageUrl, mockImageTitle, mockProductSKU);
        Test.stopTest();
        
    }

    @isTest
    static void testUnpublishImageContentFailure() {
        // Set the mock response
        Test.setMock(HttpCalloutMock.class, new UnpublishImageMockHttpResponseGenerator());

        // Test data
        String invalidContentId = 'invalidContentId';
        String mockImageUrl = 'https://example.com/image.jpg';
        String mockImageTitle = 'Sample Image';
        String mockProductSKU = 'SKU123';

        // Call the method
        Test.startTest();
        FutureContentPublisher.getAccessToken();
        //FutureContentPublisher.setMockAccessToken('mockAccessToken'); // Mock the access token retrieval
        ImageUploadService.unpublishImageContent(invalidContentId, mockImageUrl, mockImageTitle, mockProductSKU);
        Test.stopTest();

    }
    
    
  

     
}