@isTest
global class SyncACRBatchCalloutMock {
    
    public static HTTPResponse getResp(Map<String, ID> externalIDMap){
        
        Set<String> externalIDSet = externalIDMap.keyset();
        String externalID = string.valueof(externalIDSet).replace('{','').replace('}','');
        
        String payload = JSON.serialize(
            new Map<String, Object> { 
                externalID =>
                   new Map<String, Object> {
                        'success' => 'TRUE',
                         'message' => 'Successfully update with ID 07k9E00000Yw8OtQAJ',
                         'externalID'=> externalID
                   }
            }
        );
        
        HttpResponse response = new HttpResponse();
        response.setHeader('Content-Type', 'application/json');
        //response.setBody('{"00100063-00100066":{"success":"True","message":"Successfully update with ID 07k9E00000Yw8OtQAJ","externalID":"00100063-00100066"}} ');
        response.setBody(payload);
        response.setStatusCode(200);
        return response; 
    }
}