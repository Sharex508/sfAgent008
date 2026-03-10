public class ErrorDisplayController {
    public string objName;
    public ErrorDisplayController(ApexPages.StandardController stdController){
        this.objName = ApexPages.currentPage().getParameters().get('objName');
    }
    
    public pageReference doRedirect(){
        pageReference p = new pageReference('');
        if(this.objName == 'Opportunity'){
            if(Site.getSiteType() != null){
                p = new pageReference(System.Label.Community_URL + '/recordlist/Opportunity/Default');
            }else{
                p = new pageReference('/lightning/o/Opportunity/list?filterName=Recent');
            }
        }
        else if(this.objName == 'SBQQ__Quote__c'){
            if(Site.getSiteType() != null){
                p = new pageReference(System.Label.Community_URL + '/recordlist/SBQQ__Quote__c/Default');
            }else{
                p = new pageReference('/lightning/o/SBQQ__Quote__c/list?filterName=Recent');
            }
        }
        else if(this.objName == 'Order'){
            if(Site.getSiteType() != null){
                p = new pageReference(System.Label.Community_URL + '/recordlist/Order/Default');
            }else{
                p = new pageReference('/lightning/o/Order/list?filterName=Recent');
            }
        }
        return p;
    }
}