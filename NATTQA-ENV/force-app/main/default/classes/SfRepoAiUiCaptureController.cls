public with sharing class SfRepoAiUiCaptureController {
    @AuraEnabled
    public static void trackUiEvent(
        String eventType,
        String componentName,
        String actionName,
        String elementLabel,
        String pageUrl,
        String recordId,
        String detailsJson
    ) {
        Map<String, Object> payload = new Map<String, Object>();
        payload.put('event_type', String.isBlank(eventType) ? 'UI_EVENT' : eventType);
        payload.put('component_name', componentName);
        payload.put('action_name', actionName);
        payload.put('element_label', elementLabel);
        payload.put('page_url', pageUrl);
        payload.put('record_id', recordId);
        payload.put('event_ts', String.valueOf(System.now()));

        if (!String.isBlank(detailsJson)) {
            try {
                Object parsed = JSON.deserializeUntyped(detailsJson);
                if (parsed instanceof Map<String, Object>) {
                    payload.put('details', parsed);
                } else {
                    payload.put('details', new Map<String, Object>{ 'raw' => detailsJson });
                }
            } catch (Exception ex) {
                payload.put('details', new Map<String, Object>{ 'raw' => detailsJson });
            }
        } else {
            payload.put('details', new Map<String, Object>());
        }

        System.debug(LoggingLevel.INFO, 'UI_CAPTURE|' + JSON.serialize(payload));
    }
}
