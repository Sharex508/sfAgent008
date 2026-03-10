/**********************************************************************************************
Class name       :  NAC_B2BSearchControllerTest              
Description      :  Improved Test Class for NAC_B2BSearchController with high-coverage scenarios
*************************************************************************************************/

@IsTest
public class NAC_B2BSearchControllerTest {

    static String commId;

    // ---------- A flexible mock that can simulate token success/failure, redirects, and final responses ----------
    private class OAuthAndCommerceMock implements HttpCalloutMock {
        // Controls
        Integer tokenStatusCode;
        String  tokenBodyJson;

        Integer firstCommerceStatusCode;
        String  firstCommerceLocation;     // Used when firstCommerceStatusCode is a redirect (e.g., 302)
        String  finalCommerceEndpoint;     // Will be matched when we follow Location

        Integer finalCommerceStatusCode;
        String  finalCommerceBodyJson;

        // Internal state
        Boolean firstCommerceCallHandled = false;

        OAuthAndCommerceMock(Integer tokenStatusCode,
                             String  tokenBodyJson,
                             Integer firstCommerceStatusCode,
                             String  firstCommerceLocation,
                             Integer finalCommerceStatusCode,
                             String  finalCommerceBodyJson) {
            this.tokenStatusCode         = tokenStatusCode;
            this.tokenBodyJson           = tokenBodyJson;
            this.firstCommerceStatusCode = firstCommerceStatusCode;
            this.firstCommerceLocation   = firstCommerceLocation;
            this.finalCommerceStatusCode = finalCommerceStatusCode;
            this.finalCommerceBodyJson   = finalCommerceBodyJson;

            this.finalCommerceEndpoint   = firstCommerceLocation;
        }

        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            String ep = req.getEndpoint();

            // Token endpoint
            if (ep == System.Label.CallMeBackAPPEndPointURL) {
                res.setStatusCode(tokenStatusCode);
                res.setBody(tokenBodyJson);
                res.setHeader('Content-Type', 'application/json');
                return res;
            }

            // First commerce call (original /search/product-search)
            // We match broadly on the base URL to avoid brittle tests (apiVersion string is private in the class)
            if (!firstCommerceCallHandled && ep.startsWith(System.Label.CallMeBackAPPBaseURl) && ep.contains('/search/product-search')) {
                firstCommerceCallHandled = true;
                res.setStatusCode(firstCommerceStatusCode);
                if (firstCommerceLocation != null) {
                    res.setHeader('Location', firstCommerceLocation);
                }
                // 2xx body for success, a minimal JSON structure otherwise
                res.setBody((firstCommerceStatusCode >= 200 && firstCommerceStatusCode <= 204)
                            ? '{"items":[{"name":"Widget A"}]}'
                            : '{"error":"first call failed"}');
                res.setHeader('Content-Type', 'application/json');
                return res;
            }

            // Follow-up commerce call to Location
            if (finalCommerceEndpoint != null && ep == finalCommerceEndpoint) {
                res.setStatusCode(finalCommerceStatusCode);
                res.setBody(finalCommerceBodyJson);
                res.setHeader('Content-Type', 'application/json');
                return res;
            }

            // Fallback (should not happen; helps debugging)
            res.setStatusCode(500);
            res.setBody('Unexpected endpoint in mock: ' + ep);
            return res;
        }
    }

    // ---------- Test data ----------
    @testSetup
    public static void setupTestData(){
        Webstore webSt = NAC_TestDataFactory.webstoreCreation();
        commId = [SELECT Id, Name FROM Network WHERE Name = :NAC_Global_Constants.DEFAULT_COMMUNITY_NAME_NAC].Id;
        User us = NAC_TestDataFactory.runAsNACUser();
        Contact con = [SELECT Id, AccountId FROM Contact WHERE Id = :us.ContactId];
        NAC_TestDataFactory.createOrder(con.Id, con.AccountId, '');
    }

    // ---------- Positive: effectiveAccountId provided + redirect chain exercised ----------
    @IsTest
    static void productSearch_Positive_WithRedirect(){
        Contact con = [SELECT Id, AccountId FROM Contact LIMIT 1];
        WebStore web = [SELECT Id FROM WebStore LIMIT 1];
        NAC_B2BUtils.communityIdToWebStoreIdCache.put(commId, web.Id);

        // Simulate: token 200 with access_token, first commerce 302 with Location, final 200
        Test.setMock(HttpCalloutMock.class,
            new OAuthAndCommerceMock(
                200, '{"access_token":"abc123"}',
                302, System.Label.CallMeBackAPPBaseURl + '/follow/up',
                200, '{"results":[{"id":"p-001","name":"Product 1"}]}'
            )
        );

        Test.startTest();
        NAC_B2BSearchController.searchResponseWrapper sr =
            NAC_B2BSearchController.productSearch(commId, '{"query":"searchQuery"}', con.AccountId, null);
        Test.stopTest();

        System.assertNotEquals(null, sr, 'Wrapper should not be null');
        System.assertNotEquals(null, sr.response, 'Response should be populated after redirect follow-up');
    }

    // ---------- Positive: guest-user branch exercised (effectiveAccountId null + runAs Guest) ----------
    @IsTest
    static void productSearch_Positive_AsGuest(){
        WebStore web = [SELECT Id FROM WebStore LIMIT 1];
        NAC_B2BUtils.communityIdToWebStoreIdCache.put(commId, web.Id);

        // Token OK, commerce directly OK (no redirect needed)
        Test.setMock(HttpCalloutMock.class,
            new OAuthAndCommerceMock(
                200, '{"access_token":"xyz789"}',
                200, null,
                200, '{"results":[{"id":"p-002","name":"Product 2"}]}'
            )
        );

        // Obtain Guest User for the site (Experience Cloud)
        // NOTE: Ensure your test org has at least one active Site.
        Site site = [SELECT Id, GuestUserId FROM Site LIMIT 1];
        User guest = [SELECT Id FROM User WHERE Id = :site.GuestUserId];

        List<Order> orders;
        System.runAs(guest) {
            Test.startTest();
            NAC_B2BSearchController.searchResponseWrapper sr =
                NAC_B2BSearchController.productSearch(commId, '{"query":"searchQuery"}', null, null);
            Test.stopTest();
            System.assertNotEquals(null, sr, 'Wrapper should not be null for guest branch');
        }
    }

    // ---------- Negative: OAuth token failure (non-2xx) ----------
    @IsTest
    static void productSearch_Negative_OAuth_Failure(){
        WebStore web = [SELECT Id FROM WebStore LIMIT 1];
        NAC_B2BUtils.communityIdToWebStoreIdCache.put(commId, web.Id);

        // Token 401 with error JSON
        Test.setMock(HttpCalloutMock.class,
            new OAuthAndCommerceMock(
                401, '{"error":"invalid_client","error_description":"Bad client credentials"}',
                200, null,
                200, '{"results":[]}'
            )
        );

        Test.startTest();
        Boolean thrown = false;
        try {
            NAC_B2BSearchController.productSearch(commId, '{"query":"searchQuery"}', null, null);
        } catch (Exception e) {
            thrown = true;
        }
        Test.stopTest();
        System.assert(thrown, 'Should throw on OAuth token failure');
    }

    // ---------- Negative: OAuth 200 but missing access_token ----------
    @IsTest
    static void productSearch_Negative_OAuth_NoToken(){
        WebStore web = [SELECT Id FROM WebStore LIMIT 1];
        NAC_B2BUtils.communityIdToWebStoreIdCache.put(commId, web.Id);

        // Token 200 but body missing access_token
        Test.setMock(HttpCalloutMock.class,
            new OAuthAndCommerceMock(
                200, '{"token_type":"bearer"}',
                200, null,
                200, '{"results":[]}'
            )
        );

        Test.startTest();
        Boolean thrown = false;
        try {
            NAC_B2BSearchController.productSearch(commId, '{"query":"searchQuery"}', null, null);
        } catch (Exception e) {
            thrown = true;
        }
        Test.stopTest();
        System.assert(thrown, 'Should throw when access_token is missing');
    }

    // ---------- Negative: commerce API returns non-2xx ----------
    @IsTest
    static void productSearch_Negative_Commerce_Non2xx(){
        WebStore web = [SELECT Id FROM WebStore LIMIT 1];
        NAC_B2BUtils.communityIdToWebStoreIdCache.put(commId, web.Id);

        // Token OK, first commerce call returns 500
        Test.setMock(HttpCalloutMock.class,
            new OAuthAndCommerceMock(
                200, '{"access_token":"ok"}',
                500, null,
                500, '{"error":"server down"}'
            )
        );

        Test.startTest();
        Boolean thrown = false;
        try {
            NAC_B2BSearchController.productSearch(commId, '{"query":"searchQuery"}', null, null);
        } catch (Exception e) {
            thrown = true;
        }
        Test.stopTest();
        System.assert(thrown, 'Should throw when commerce API returns non-2xx');
    }

    // ---------- Existing: orderSearch ----------
    @IsTest
    static void orderSearch_Positive(){
        Contact con = [SELECT Id, AccountId FROM Contact LIMIT 1];
        User us = [SELECT Id FROM User WHERE ContactId = :con.Id];

        List<Order> searchOrder = new List<Order>();
        Test.startTest();
        System.runAs(us) {
            searchOrder = NAC_B2BSearchController.orderSearch(con.AccountId);
        }
        Test.stopTest();

        System.assert(searchOrder.size() > 0, 'searchOrder is Empty');
    }
}