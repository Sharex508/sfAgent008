/* Created a Apex class to create a ContentDocumentLinkHelper to update the logic while document upload
 * Created by : Rajasekharreddy Kotella
 * Created on : 04-10-2024
 * Class Name : ServiceAgreementTriggerHelper
 */
public class ContentDocumentLinkHelper {
    public static void updateVisiblePermission(list<ContentDocumentLink> cdlList ){
        for (ContentDocumentLink cdl : cdlList) {
            if (cdl.LinkedEntityId.getSObjectType().getDescribe().getName() == 'CONTAINER_Service_Agreement__c') {
                cdl.visibility = 'AllUsers';
                cdl.ShareType = 'V';
            }
        }
    }
}