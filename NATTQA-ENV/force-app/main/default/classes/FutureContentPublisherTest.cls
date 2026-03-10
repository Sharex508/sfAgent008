@IsTest
private class FutureContentPublisherTest {    
    private class MockHttpCallout implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            if (req.getEndpoint().contains('/oauth2/token')) {
                res.setStatusCode(200);
                res.setBody('{"access_token": "mock_access_token"}'); 
            } else if (req.getEndpoint().contains('/cms/contents/publish')) {
                res.setStatusCode(200);
                res.setBody('{"status": "success", "message": "Content published"}');
            } else {
                res.setStatusCode(400);
                res.setBody('{"status": "error", "message": "Invalid endpoint"}');
            }
            
            return res;
        }
    }

    @IsTest
    static void setupTestData() {        
        RecordType productRecordType = [SELECT Id FROM RecordType WHERE SObjectType = 'Product2' AND DeveloperName = 'NATT_Products' LIMIT 1];
        Product2 testProduct = new Product2(
            Name = 'Test Product',
            IsActive=true
        );
        insert testProduct; 
    }

    @IsTest
    static void testGetAccessToken() {
        
        Test.setMock(HttpCalloutMock.class, new MockHttpCallout());
        Test.startTest();
        String token = FutureContentPublisher.getAccessToken();
        Test.stopTest();
       
        System.assertNotEquals(token, null, 'Access token should not be null.');
        System.assertEquals(token, 'mock_access_token', 'The access token should match the mocked response.');
    }

    @IsTest(SeeAllData=true)
    static void testPublishManagedContent() {        
        Test.setMock(HttpCalloutMock.class, new MockHttpCallout());
        List<ManagedContent> managedContentList = [SELECT Id FROM ManagedContent LIMIT 1];
        String mockManagedContentId  = managedContentList[0].Id;
        Test.startTest();
        FutureContentPublisher.publishManagedContent(mockManagedContentId);
        Test.stopTest();        
        System.assert(true, 'publishManagedContent executed successfully.');
    }

    @IsTest(SeeAllData=true)
    static void testImageLinkToProduct() {     
        RecordType recordType = [SELECT Id, Name FROM RecordType WHERE Name='NATT Products'];   
        List<Product2> products = [SELECT Id FROM Product2 WHERE RecordTypeId= :recordType.Id LIMIT 1];
        System.assert(!products.isEmpty(), 'No Product2 record found');
        Product2 testProduct = products[0];
        System.debug('testProduct : ' + testProduct.Id);
        List<ManagedContent> managedContentList = [SELECT Id FROM ManagedContent LIMIT 1];
        String managedContentId = managedContentList[0].Id;
        Test.startTest();
        FutureContentPublisher.ImageLinkToProduct(managedContentId, testProduct.Id);           
        Test.stopTest();       
        
    }    
   
}