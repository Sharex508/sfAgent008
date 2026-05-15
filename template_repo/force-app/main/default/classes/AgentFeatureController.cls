public with sharing class AgentFeatureController {
    public class EnvironmentContext {
        @AuraEnabled public String orgId;
        @AuraEnabled public String orgName;
        @AuraEnabled public String orgDomainUrl;
    }

    @AuraEnabled(cacheable=true)
    public static EnvironmentContext getEnvironmentContext() {
        EnvironmentContext context = new EnvironmentContext();
        context.orgId = UserInfo.getOrganizationId();
        context.orgDomainUrl = Url.getOrgDomainUrl().toExternalForm();
        Organization orgRow = [SELECT Name FROM Organization LIMIT 1];
        context.orgName = orgRow.Name;
        return context;
    }

    @AuraEnabled(cacheable=true)
    public static String getUiFeatures(String endpointBase, String apiKey) {
        return sendBackendRequest('GET', endpointBase, apiKey, '/sf-repo-ai/ui-features', null);
    }

    @AuraEnabled(cacheable=true)
    public static String getUiFeature(String endpointBase, String apiKey, String featureId) {
        requireText(featureId, 'featureId');
        return sendBackendRequest('GET', endpointBase, apiKey, '/sf-repo-ai/ui-features/' + EncodingUtil.urlEncode(featureId, 'UTF-8'), null);
    }

    @AuraEnabled
    public static String createUiFeature(String endpointBase, String apiKey, String requestJson) {
        requireText(requestJson, 'requestJson');
        return sendBackendRequest('POST', endpointBase, apiKey, '/sf-repo-ai/ui-features', requestJson);
    }

    @AuraEnabled
    public static String updateUiFeature(String endpointBase, String apiKey, String featureId, String requestJson) {
        requireText(featureId, 'featureId');
        requireText(requestJson, 'requestJson');
        return sendBackendRequest('PUT', endpointBase, apiKey, '/sf-repo-ai/ui-features/' + EncodingUtil.urlEncode(featureId, 'UTF-8'), requestJson);
    }

    @AuraEnabled(cacheable=true)
    public static String getUiFeatureRuns(String endpointBase, String apiKey, String featureId) {
        requireText(featureId, 'featureId');
        return sendBackendRequest('GET', endpointBase, apiKey, '/sf-repo-ai/ui-features/' + EncodingUtil.urlEncode(featureId, 'UTF-8') + '/runs', null);
    }

    @AuraEnabled(cacheable=true)
    public static String getUiFeatureRunArtifacts(String endpointBase, String apiKey, String featureId, String runId) {
        requireText(featureId, 'featureId');
        requireText(runId, 'runId');
        return sendBackendRequest(
            'GET',
            endpointBase,
            apiKey,
            '/sf-repo-ai/ui-features/' + EncodingUtil.urlEncode(featureId, 'UTF-8') + '/runs/' + EncodingUtil.urlEncode(runId, 'UTF-8') + '/artifacts',
            null
        );
    }

    @AuraEnabled
    public static String runUiFeature(String endpointBase, String apiKey, String featureId, String requestJson) {
        requireText(featureId, 'featureId');
        String body = String.isBlank(requestJson) ? '{}' : requestJson;
        return sendBackendRequest(
            'POST',
            endpointBase,
            apiKey,
            '/sf-repo-ai/ui-features/' + EncodingUtil.urlEncode(featureId, 'UTF-8') + '/run',
            body
        );
    }

    private static String sendBackendRequest(String method, String endpointBase, String apiKey, String path, String requestBody) {
        String normalizedBase = normalizeEndpointBase(endpointBase);
        HttpRequest req = new HttpRequest();
        req.setMethod(method);
        req.setEndpoint(normalizedBase + path);
        req.setHeader('Content-Type', 'application/json');
        if (!String.isBlank(apiKey)) {
            req.setHeader('X-API-Key', apiKey.trim());
        }
        req.setTimeout(120000);
        if (!String.isBlank(requestBody)) {
            req.setBody(requestBody);
        }

        Http http = new Http();
        HttpResponse res = http.send(req);
        if (res.getStatusCode() < 200 || res.getStatusCode() >= 300) {
            throw new AuraHandledException('API call failed: HTTP ' + res.getStatusCode() + ' - ' + res.getBody());
        }
        return res.getBody();
    }

    @TestVisible
    private static String normalizeEndpointBase(String endpointBase) {
        String base = requireText(endpointBase, 'endpointBase').trim();
        Integer idx = base.toLowerCase().indexOf('/sf-repo-ai/');
        if (idx > -1) {
            base = base.substring(0, idx);
        }
        while (base.endsWith('/')) {
            base = base.substring(0, base.length() - 1);
        }
        return base;
    }

    private static String requireText(String value, String fieldName) {
        String text = String.isBlank(value) ? null : value.trim();
        if (String.isBlank(text)) {
            throw new AuraHandledException(fieldName + ' is required.');
        }
        return text;
    }
}
