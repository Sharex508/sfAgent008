public with sharing class NAC_B2BSearchController {
    private static Decimal apiVersionApexClass = 60.0;

    @AuraEnabled(cacheable=true)
    public static searchResponseWrapper productSearch(String communityId, String searchQuery, String effectiveAccountId, String categoryId) {
        searchResponseWrapper srWrap = new searchResponseWrapper();
        system.debug('searchQuery=>>>'+searchQuery);
        String webstoreId = NAC_B2BUtils.resolveCommunityIdToWebstoreId(communityId);
        if (String.isNotBlank(categoryId)) {
            srWrap.categoryPath = ConnectApi.CommerceCatalog.getProductCategoryPath(webstoreId, categoryId);
        }

        
        HttpRequest tokenReq = new HttpRequest();
        tokenReq.setMethod('POST');
        tokenReq.setEndpoint(label.CallMeBackAPPEndPointURL);
        tokenReq.setHeader('Content-Type', 'application/x-www-form-urlencoded');

        String clientId     = System.Label.CallMeBackAPPClientID;
        String clientSecret = System.Label.CallMeBackAPPClientSecret;

        String tokenBody =
            'grant_type=client_credentials' +
            '&client_id='     + EncodingUtil.urlEncode(clientId, 'UTF-8') +
            '&client_secret=' + EncodingUtil.urlEncode(clientSecret, 'UTF-8');


        tokenReq.setBody(tokenBody);

        Http http = new Http();
        HttpResponse tokenRes = http.send(tokenReq);

        if (tokenRes.getStatusCode() < 200 || tokenRes.getStatusCode() > 299) {
            Map<String, Object> oauthErr;
            try { oauthErr = (Map<String, Object>) JSON.deserializeUntyped(tokenRes.getBody()); } catch (Exception ignore) { oauthErr = null; }
            System.debug(LoggingLevel.ERROR, 'OAuth token failed: status=' + tokenRes.getStatusCode() +
                ', error=' + (oauthErr != null ? (String) oauthErr.get('error') : null) +
                ', error_description=' + (oauthErr != null ? (String) oauthErr.get('error_description') : null));
            throw new CalloutException('OAuth token request failed: ' + (oauthErr != null ? (String) oauthErr.get('error') : 'see debug logs'));
        }

        Map<String, Object> tokenJson = (Map<String, Object>) JSON.deserializeUntyped(tokenRes.getBody());
        String accessToken = (String) tokenJson.get('access_token');
        if (String.isBlank(accessToken)) {
            throw new CalloutException('No access_token in OAuth response');
        }

        
        String baseUrl = label.CallMeBackAPPBaseURl; 
        String accountIdParameter = '';
        if (effectiveAccountId != null) {
            accountIdParameter = '?effectiveAccountId=' + EncodingUtil.urlEncode(effectiveAccountId, 'UTF-8');
        } else if (UserInfo.getUserType().equalsIgnoreCase('Guest')) {
            accountIdParameter = NAC_B2BGetInfoController.guestEffectiveAccount();
        }

        String commerceEndpoint =
            baseUrl +
            '/services/data/v' + String.valueOf(apiVersionApexClass) +
            '/commerce/webstores/' + webstoreId +
            '/search/product-search' +
            accountIdParameter;

        HttpRequest httpRequest = new HttpRequest();
        httpRequest.setMethod('POST');
        httpRequest.setHeader('Content-Type', 'application/json; charset=utf-8');
        httpRequest.setHeader('Authorization', 'Bearer ' + accessToken);
        httpRequest.setEndpoint(commerceEndpoint);
        httpRequest.setBody(searchQuery);

        List<String> newLocationStatusCode = Label.NAOCAP_New_Location_Status_Code.split(',');

        try {
            HttpResponse httpResponse = http.send(httpRequest);
            Integer statusCode = httpResponse.getStatusCode();

            while (newLocationStatusCode.contains(String.valueOf(statusCode))) {
                httpRequest.setEndpoint(httpResponse.getHeader('Location'));
                httpResponse = new Http().send(httpRequest);
                statusCode = httpResponse.getStatusCode();
            }

            if (statusCode >= 200 && statusCode <= 204) {
                srWrap.response = JSON.deserializeUntyped(httpResponse.getBody());
            } else {
                throw new CalloutException(httpResponse.getBody());
            }
        } catch (System.Exception e) {
            System.debug('ERROR: ' + e);
            throw e;
        }

        return srWrap;
    }

    @AuraEnabled(cacheable=true)
    public static List<Order> orderSearch(String effectiveAccountId){
        return [SELECT Id, Name FROM Order WHERE AccountId =: effectiveAccountId WITH SECURITY_ENFORCED LIMIT 10];
    }

    public class searchResponseWrapper{
        @AuraEnabled public Object response;
        @AuraEnabled public ConnectApi.ProductCategoryPath categoryPath;
    }
}