public class ctbrCustomMetadataCallback implements Metadata.DeployCallback {
    //Created By : Tejas Hatalkar/Dharani S - 11/11/2022
    //Purpose: This is invoked by ExchangeRateMetaDataUtil2 to invoke callback for Metadata.
    public void handleResult(Metadata.DeployResult result,
                             Metadata.DeployCallbackContext context) {
                             
        if (result.status == Metadata.DeployStatus.Succeeded) {
            System.debug('success: '+ result);
        } else {
            // Deployment was not successful
            System.debug('fail: '+ result);
        }
        
    }
}