global without sharing class NATT_SBQQCalculateCallback implements SBQQ.CalculateCallback {
    
    global void callback(String quoteJSON){
        SBQQ.ServiceRouter.save('SBQQ.QuoteAPI.QuoteSaver', quoteJSON);       
    }
}