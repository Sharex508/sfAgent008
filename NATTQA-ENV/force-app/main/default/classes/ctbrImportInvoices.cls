/* Author: LTI
* Created Date: 17 Oct 2022
* Class Name: ImportInvoices
* Description: Custom Web service class used to import Invoices under Orders. 
*/
@RestResource(urlMapping='/ImportInvoices/*')
global without sharing class ctbrImportInvoices {
   //This method imports pdf files from SAP and attaches to the Order.
    @HttpPost
    global static string ImportInvoiceonOrder(List<wrapperClassOrderData> orderData) {
        try{
            if(orderData!=null && !orderData.isEmpty())
            {
                if(orderData.size() > 100)
            	{
                	return 'Too many Orders in Request: ' +orderData.size()+', please limit the Batch size to 100 Orders';
            	}
                List<Order> orderLst = new list<Order>();
                List<ContentVersion> files = new List<ContentVersion>();
                Set <Id> OrderIds = new Set<Id>();
                //We can eliminate this Order loop, if SAP Team passes just the pdf files and an Order Id with it.
                for(wrapperClassOrderData OrderWrapperObj : orderData)
                {
                    Order ordertoUpdate = new Order();
             //   ordertoUpdate.status = OrderWrapperObj.status;
              //  ordertoupdate.NATT_Ship_Date__c	 = orderwrapperobj.orderShipDate;
                    ordertoUpdate.id = OrderWrapperObj.OrderExternalId;
                    OrderIds.add(OrderWrapperObj.OrderExternalId);
                    orderLst.add(orderToUpdate);
                     List<filesWrapperClass> filesLst = new List<filesWrapperClass>();
                     filesLst = OrderWrapperObj.Invoicefiles; // list of all the files 
                    // to associate files attached with order updated above
                      if(filesLst!=null && !filesLst.isEmpty())
                      {
                            for (filesWrapperClass fileObj : filesLst) 
                            {
                                ContentVersion file = new ContentVersion();
                                if(fileObj.fileName != null && fileObj.versionData != null)
                                {
                                    String nameWithExtension = fileObj.fileName;
                                    Integer dotIndex = nameWithExtension.indexOf('.');
                                    file.Title = nameWithExtension.substring(0, dotIndex);  
                                    file.PathOnClient = nameWithExtension;
                                    file.ContentLocation = 'S';
                                    Blob decodedFile = EncodingUtil.base64Decode(fileObj.versionData); // used to  convert base64 String to image 
                                    system.debug('decodedFile-->'+decodedFile);
                                    file.versionData = decodedFile;
                                    file.FirstPublishLocationId = OrderWrapperObj.OrderExternalId; 
                                    system.debug('file-->'+file);
                                    files.add(file);
                                }
                            }
                            
                        }
                } //end for.
                if(!files.isEmpty()){
                                insert files; 
                            }
                List<ContentDocumentLink> lstToupdate =new List<ContentDocumentLink>([Select Id,ContentDocumentId,ContentDocument.Title,LinkedEntityId,Visibility,ShareType from ContentDocumentLink where LinkedEntityId in : OrderIds]);
                        List<ContentDocumentLink> lstToupdateid =new List<ContentDocumentLink>();
                        for(ContentDocumentLink contentdoc : lstToupdate){
                            // change the visbility of ContentDocumentLink records just created above due to the insertion files at line 88.
                            if(contentdoc.Visibility =='InternalUsers'){
                                contentdoc.Visibility='AllUsers';
                                lstToupdateid.add(contentdoc);
                            }
                        }
                        
                        if(!lsttoupdateid.isEmpty()){
                            update lsttoupdateid;
                        }
                Database.SaveResult[] orderResultLst = Database.update(orderLst, false);
					System.debug('resultLst&&&&' + orderResultLst);
            }else{
                return 'Null data';
            }
               	return 'Success';
            
        }catch(Exception ex){
            ctbrUtility.LogException(ex, 'ctbrImportInvoiceonOrder', 'updateOrder');
            return 'Error in importing Invoices for Orders: '+ex.getMessage() + ' : ' +ex.getStackTraceString();
        }
    } 
   
    // Form Data Wrapperclass 
    global class wrapperClassOrderData {
        public string OrderExternalId;
        global List<filesWrapperClass> Invoicefiles;
    }
    
    // files to be Attached Wrapperclass 
    global class filesWrapperClass {
        global String fileName;
        global String versionData;
    }
}