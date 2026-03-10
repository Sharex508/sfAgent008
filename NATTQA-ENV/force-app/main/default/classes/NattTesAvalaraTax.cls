public with sharing class NattTesAvalaraTax {
    @AuraEnabled
    public static NattTesAvalaraTaxResponse getTaxAmount(decimal amount,String street,String city,String state,String postalCode,String country){
        decimal taxAmount=0;
        String currentDate = Datetime.now().format('yyyy-MM-dd');
        try {
            String json='{"companyCode": "TES","type": "SalesOrder",';
            json+='"date": "'+currentDate+'",';
            json+='"customerCode": "dummyCUSTOMER",';
            json+='"addresses": {';
            json+='"singleLocation": {';
            json+='"line1": "'+street+'",';
            json+='"city": "'+city+'",';
            json+='"region": "'+state+'",';
            json+='"country": "'+country+'",';
            json+='"postalCode": "'+postalCode+'"';
            json+='}';
            json+='},';
            json+='"lines": [';
            json+='{';
            json+='"amount":'+amount;
            json+='}';
            json+=']';
            json+='} ';

            Http http1 = new Http();
            HttpRequest req = new HttpRequest();    
            Organization org = [SELECT Id,IsSandbox FROM Organization limit 1];
            if(org.IsSandbox){  
                req.setEndpoint('callout:avalaraSandbox/api/v2/transactions/create');
            }else{
                req.setEndpoint('callout:avalara/api/v2/transactions/create');
            }
            req.setHeader('Content-Type','application/json');
            req.setMethod('POST'); 
            req.setBody(json);
            
            HttpResponse res = http1.send(req);
            system.debug('res1==>' +res);
            system.debug('res1==>' +res.getBody());                
            NattTesAvalaraTaxResponse atr = NattTesAvalaraTaxResponse.parse(res.getBody());
            System.debug('atr:'+atr.totalTax);
            return NattTesAvalaraTaxResponse.parse(res.getBody());
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }
}