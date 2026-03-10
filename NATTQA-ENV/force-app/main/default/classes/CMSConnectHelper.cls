public with sharing class CMSConnectHelper {
    
   @AuraEnabled (cacheable=true)
    public static String retrieveMediaFromCMS(String channelName){
        String channelId = getChannelId(channelName);
        System.debug('channel value' + channelId);

        //get the image content
        ConnectApi.ManagedContentVersionCollection obj = 
            ConnectApi.ManagedContent.getAllContent(channelId, 0, 250, 'en_US', 
                                                    'cms_image',false,
                                                    '2011-02-25T18:24:31.000Z','3021-09-25T18:24:31.000Z',true);
        
        List<ReturnWrapper> wrapperList = new List<ReturnWrapper>();
        System.debug('json value=' + JSON.serialize(obj));

        //loop through each item and prepare a wrapper list
        for(ConnectApi.ManagedContentVersion versionObj: obj.items){
            ReturnWrapper wrapper = new ReturnWrapper();
            wrapper.title = versionObj.title;
            
            //get the url
            Map<String,ConnectApi.ManagedContentNodeValue> contentNodesMap = versionObj.contentNodes;
            for(String str:contentNodesMap.keySet()){                
                if(str=='source'){
                    wrapper.url= ((ConnectApi.ManagedContentMediaSourceNodeValue)contentNodesMap.get(str)).url;
                }		
            }
            wrapperList.add(wrapper);	
        }
        return JSON.serialize(wrapperList);
    }

    @AuraEnabled (cacheable=true)
    public static String getChannelId(String channelName){
        ConnectApi.ManagedContentChannelCollection channelRepObj = 
                ConnectApi.ManagedContent.getAllDeliveryChannels(0,10);        

        //loop through the channels and return the channel Id
        for(ConnectApi.ManagedContentChannel channelObj: channelRepObj.channels){
            if(channelObj.channelName == channelName){
                return channelObj.channelId;
            }
        }
        return null;
    }

    public class ReturnWrapper{
        String title {get;set;}
        String url {get;set;}
    }
}