public class FutureContentPublisher {
    private static final String CLIENT_ID = System.Label.Client_ID_PIM;
    private static final String CLIENT_SECRET = System.Label.Client_Secret_PIM;    
    private static final String AUTH_URL = System.Label.Auth_URL_PIM;
    

    public static String getAccessToken() {
    Http http = new Http();
    HttpRequest request = new HttpRequest();

    request.setMethod('POST');
    request.setEndpoint(AUTH_URL);
    String requestBody = 'grant_type=client_credentials' +
                         '&client_id=' + CLIENT_ID +
                         '&client_secret=' + CLIENT_SECRET;
                         
    request.setBody(requestBody);
    request.setHeader('Content-Type', 'application/x-www-form-urlencoded');

    try {
        HttpResponse response = http.send(request);
        if (response.getStatusCode() == 200) {
            Map<String, Object> responseMap = (Map<String, Object>) JSON.deserializeUntyped(response.getBody());
            return (String) responseMap.get('access_token');
        } else {
            System.debug('Error in access token response: ' + response.getBody());
            return null;
        }
    } catch (Exception e) {
        System.debug('Exception in access token retrieval: ' + e.getMessage());
        return null;
    }
}     
    
    @future(callout=true)
    public static void publishManagedContent(String managedContentId) {
        try {
            String accessToken = getAccessToken();
             if (accessToken == null) {
                System.debug('Failed to retrieve access token.');
                return;
             }
            Http http = new Http(); 
            String baseUrl = System.Label.CMS_BaseURL;
            String endpoint = baseUrl +'/services/data/v58.0/connect/cms/contents/publish';
            HttpRequest reqs = new HttpRequest();
            reqs.setEndpoint(endpoint);
            reqs.setMethod('POST');
            reqs.setHeader('Authorization', 'Bearer ' + accessToken);
            reqs.setHeader('Content-Type', 'application/json');
            reqs.setBody('{"description": "Inriver Image", "contentIds": ["' + managedContentId + '"]}');
            HttpResponse ress = http.send(reqs);
            if (ress.getStatusCode() == 200) {
                System.debug('Success: ' + ress.getBody());                               
            } else {
                System.debug('Failed with status code: ' + ress.getStatusCode() + ' - ' + ress.getBody());
            }
        } catch (Exception e) {
            System.debug('Error: ' + e.getMessage());
        }
    }
    public static void ImageLinkToProduct(String managedContentId, String productId) {
         try {  
         
            ElectronicMediaGroup mediaGroup = [SELECT Id FROM ElectronicMediaGroup WHERE Name='Product Detail Images'];
            
            ProductMedia media = new ProductMedia(); 
            media.ProductId = productId;             
            media.ElectronicMediaId = managedContentId; 
            media.ElectronicMediaGroupId = mediaGroup.Id;
            insert media;
            System.debug('Inserted Media: ' + media);            
        } catch (Exception e) {
            System.debug('Error: ' + e.getMessage());
        }
    }
}