public without sharing class NAC_StoreLocatorController {
    
    static final Integer REQUEST_TIMEOUT = 60000;
    static string MAP_MARKER = 'M12 2C8.13 2 5 5.13 5 9c0 5.25 7 13 7 13s7-7.75 7-13c0-3.87-3.13-7-7-7zm0 9.5c-1.38 0-2.5-1.12-2.5-2.5s1.12-2.5 2.5-2.5 2.5 1.12 2.5 2.5-1.12 2.5-2.5 2.5z';

    @AuraEnabled(cacheable=true)
    public static List<serviceCenterWrapper> findNearbyStore(String searchKey, String searchRadius) {
        try{
            Map<String, serviceCenterWrapper> scWrapMap = new Map<String, serviceCenterWrapper>();
            Integer searchRadiusInt = Integer.valueOf(searchRadius);
            Integer searchRadiusIntPlus = searchRadiusInt + 1;
            Location searchCenter = getGoogleGeolocation(searchKey);
            DistAccWrapper distWrap = new DistAccWrapper();
            List<String> validPicklistValues = new List<String>{'Premium Service Center','Advanced Service Center','Service Center'};
            distWrap.coordinates = searchCenter;
            distWrap.searchRadius = searchRadiusInt;
            distWrap.maxResults = 25;
            for(Schema.PicklistEntry serviceCenterType : Account.CONTAINER_Service_Location_Type__c.getDescribe().getPicklistValues()){
            
               if(validPicklistValues.contains(String.valueOf(serviceCenterType.getValue()))){
                    serviceCenterWrapper scWrap = new serviceCenterWrapper();
                    scWrap.label = serviceCenterType.getValue();
                    scWrapMap.put(scWrap.label, scWrap);
                }
               
            }
            for(Account accountList : getDistributorAccounts(distWrap)){  
                GeoWrapper locationWrap = new GeoWrapper();                               
                locationWrap.Latitude = accountList.CONTAINER_Service_Center_Geolocation__Latitude__s != null? String.valueOf(accountList.CONTAINER_Service_Center_Geolocation__Latitude__s):'';
                locationWrap.Longitude =accountList.CONTAINER_Service_Center_Geolocation__Longitude__s != null? String.valueOf(accountList.CONTAINER_Service_Center_Geolocation__Longitude__s):'';
                locationWrap.City = !String.isBlank(accountList.CONTAINER_Location_City__c)? String.valueOf(accountList.CONTAINER_Location_City__c):'';
                locationWrap.Country = !String.isBlank(accountList.CONTAINER_Location_Country__c)? String.valueOf(accountList.CONTAINER_Location_Country__c):'';
                locationWrap.PostalCode = !String.isBlank(accountList.Location_Zip_Postal_Code__c)? String.valueOf(accountList.Location_Zip_Postal_Code__c):'';
                locationWrap.State = !String.isBlank(accountList.CONTAINER_Location_State__c)? String.valueOf(accountList.CONTAINER_Location_State__c):'';
                locationWrap.Street = (!String.isBlank(accountList.CONTAINER_Location_Street2__c)) ? String.valueOf(accountList.CONTAINER_Location_Street__c)+', '+String.valueOf(accountList.CONTAINER_Location_Street2__c): String.valueOf(accountList.CONTAINER_Location_Street__c);
                LocationWrapper distributorLocWrap = new LocationWrapper();
                distributorLocWrap.id = String.valueOf(accountList.id);
                distributorLocWrap.name =  !String.isBlank(accountList.Name)? String.valueOf(accountList.Name) : '';
                distributorLocWrap.phoneNumber = !String.isBlank(accountList.Phone)? String.valueOf(accountList.Phone) :'';
                distributorLocWrap.serviceCenterType = !String.isBlank(accountList.CONTAINER_Service_Location_Type__c) ? String.valueOf(accountList.CONTAINER_Service_Location_Type__c) :'';
                distributorLocWrap.distance = String.valueOf((Location.getDistance(Location.newInstance(accountList.CONTAINER_Service_Center_Geolocation__Latitude__s,accountList.CONTAINER_Service_Center_Geolocation__Longitude__s), searchCenter, 'mi')).round());
                distributorLocWrap.title = (String.valueOf(accountList.Name)) + ': '+ (String.valueOf(accountList.CONTAINER_Location_Street__c)) +', '+ (String.valueOf(accountList.CONTAINER_Location_Street2__c)) + ', ' + (String.valueOf(accountList.CONTAINER_Location_City__c))+ ', ' + (String.valueOf(accountList.CONTAINER_Location_State__c))+ ', ' + (String.valueOf(accountList.Location_Zip_Postal_Code__c));
                distributorLocWrap.location = locationWrap;
                distributorLocWrap.mapIcon = new Icon();
                if(distributorLocWrap.serviceCenterType == 'Premium Service Center'){
                    distributorLocWrap.mapIcon.fillColor = '#FFD700';
                    distributorLocWrap.mapIcon.strokeColor = '#CD853F';
                }else if(distributorLocWrap.serviceCenterType == 'Advanced Service Center'){
                    distributorLocWrap.mapIcon.fillColor = '#DBA6F7';
                    distributorLocWrap.mapIcon.strokeColor = '#9161AB';
                }else if(distributorLocWrap.serviceCenterType == 'Service Center'){
                    distributorLocWrap.mapIcon.fillColor = '#F08080';
                    distributorLocWrap.mapIcon.strokeColor = '#8B0000';
                }
                if(scWrapMap.containsKey(distributorLocWrap.serviceCenterType)){
                    scWrapMap.get(distributorLocWrap.serviceCenterType).distributorLocWrapList.add(distributorLocWrap);
                }                                              
            }
            Integer countDistributors = 1;
            for(serviceCenterWrapper scWrap : scWrapMap.values()){
                scWrap.countLabel = scWrap.label + ' (' + scWrap.distributorLocWrapList.size() + ')';
                for(LocationWrapper lWrap : scWrap.distributorLocWrapList){
                    lWrap.title = countDistributors + '. ' + lWrap.title;
                    countDistributors++;
                }
            }
            return scWrapMap.values();
        }catch(Exception e) {
            String errorMessage = 'Error FROM NAC_StoreLocatorController.findNearbyStore - ' + e.getMessage() + ' AT LINE NUMBER :- ' +e.getLineNumber();
            System.debug(LoggingLevel.ERROR,errorMessage);
            AuraHandledException ahException = new AuraHandledException(errorMessage);
            ahException.setMessage(errorMessage);
            system.debug(ahException);
            throw ahException;
        } 
    }
    
    public static List<Account> getDistributorAccounts(DistAccWrapper distWrap) {
        Integer searchRadiusInt = Integer.valueOf(distWrap.searchRadius);
        Set<id> distributorIdSet = new Set<id>();
        map<id, Account> mapDistributorIds = new map<id, Account>();
        if(distWrap.coordinates.latitude != null && distWrap.coordinates.longitude !=null){
            Id contAuthServiceProviderRecordTypeId =  Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('CONTAINER_Authorized_Service_Provider').getRecordTypeId();
            Id contRepairCoTermRecordTypeId =  Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('CONTAINER_Repair_Co_Terminal').getRecordTypeId();
            Set<Id> recIdSet = new Set<Id>();
            recIdSet.add(contAuthServiceProviderRecordTypeId);
            recIdSet.add(contRepairCoTermRecordTypeId);
            String strQuery = 'SELECT Id, Name, CONTAINER_Location_City__c, CONTAINER_Location_Country__c, CONTAINER_Service_Center_Geolocation__Latitude__s, CONTAINER_Service_Center_Geolocation__Longitude__s, Location_Zip_Postal_Code__c, CONTAINER_Location_State__c, CONTAINER_Location_Street__c , CONTAINER_Location_Street2__c, Phone, CONTAINER_Service_Location_Type__c,'+
                'DISTANCE(CONTAINER_Service_Center_Geolocation__c, GEOLOCATION('+ distWrap.coordinates.latitude +','+ distWrap.coordinates.longitude +'), \'mi\')'+
                'FROM Account WHERE RecordTypeId IN: recIdSet AND DISTANCE(CONTAINER_Service_Center_Geolocation__c, GEOLOCATION('+ distWrap.coordinates.latitude +','+ distWrap.coordinates.longitude +'), \'mi\') < :searchRadiusInt '+
                'ORDER BY DISTANCE(CONTAINER_Service_Center_Geolocation__c, GEOLOCATION('+ distWrap.coordinates.latitude +','+ distWrap.coordinates.longitude +'), \'mi\') LIMIT '+distWrap.maxResults;
            System.debug('strQuery>>' + strQuery);
            List<Account> listDistributors = Database.query(strQuery);
            for(Account dist : listDistributors)
            {
                mapDistributorIds.put(dist.Id, dist);
            }
        }
        return mapDistributorIds.values();
    }
    
    public static Location getGoogleGeolocation(String key) {
        HttpResponse responseJson = new HttpResponse();
        if(!String.isEmpty(key)){
            responseJson = geocodeAddress(key);
        }            
        JSONParser responseParser = JSON.createParser(responseJson.getBody());
        double latitude = null;
        double longitude = null;
        while(responseParser.nextToken() != null) {
            if((responseParser.getCurrentToken() == JSONToken.FIELD_NAME) &&
               (responseParser.getText()== 'location')) {
                   responseParser.nextToken();
                   while(responseParser.nextToken() != JSONToken.END_OBJECT) {
                       String locationText = responseParser.getText();
                       responseParser.nextToken();
                       if (locationText == 'lat')
                           latitude = responseParser.getDoubleValue();
                       else if (locationText == 'lng')
                           longitude = responseParser.getDoubleValue();
                   }
               }
        }
        Location coordinates = Location.newInstance(latitude,longitude);
        return coordinates;
    }
       
    public static HttpResponse geocodeAddress(String searchTerm){    
        NAC_Google_Map_Setting__mdt gMapSettings = [SELECT Id,Endpoint_Base__c,Key__c FROM NAC_Google_Map_Setting__mdt WHERE DeveloperName = 'NAC_Google_Map_API'];        
        String geocodingKey = gMapSettings.Key__c;
        String endPointBase = gMapSettings.Endpoint_Base__c;
        String geoAddress = EncodingUtil.urlEncode(searchTerm, 'UTF-8');
        Http http = new Http();
        HttpRequest request = new HttpRequest();
        request.setEndpoint(endPointBase+'/maps/api/geocode/json?address='+geoAddress +'&key=' + geocodingKey+ '&sensor=false');
        request.setMethod('GET');
        request.setTimeout(REQUEST_TIMEOUT);
        HttpResponse response = http.send(request);
        return response;        
    }
    
    public class serviceCenterWrapper{
        @AuraEnabled public string label{get;set;}
        @AuraEnabled public string countLabel{get;set;}
        @AuraEnabled public List<LocationWrapper> distributorLocWrapList{get;set;}
        public serviceCenterWrapper(){
            distributorLocWrapList = new List<LocationWrapper>();
            countLabel = '';
        }
    }
    
    public class LocationWrapper{
        @AuraEnabled public string id{get;set;}
        @AuraEnabled public string name{get;set;}
        @AuraEnabled public string title{get;set;}
        @AuraEnabled public string distance{get;set;}
        @AuraEnabled public string phoneNumber{get;set;}
        @AuraEnabled public string serviceCenterType{get;set;}
        @AuraEnabled public GeoWrapper location{get;set;}
        @AuraEnabled public Icon mapIcon{get;set;}
    }
    
    public class Icon{
        @AuraEnabled public string path{get;set;}
        @AuraEnabled public decimal scale{get;set;}        
        @AuraEnabled public string fillColor{get;set;}
        @AuraEnabled public decimal fillOpacity{get;set;}
        @AuraEnabled public string strokeColor{get;set;}
        @AuraEnabled public Anchor anchor{get;set;}
        public icon(){
            path = MAP_MARKER;
            scale = 1.8;
            fillOpacity = 1;
            anchor = new Anchor();
        }
    }
    
    public class Anchor{
        @AuraEnabled public integer x{get;set;}
        @AuraEnabled public integer y{get;set;}
        public Anchor(){
            x = 12;
            y = 24;
        }
    }
    
    public class GeoWrapper{        
        @AuraEnabled public string Latitude {get;set;}
        @AuraEnabled public string Longitude {get;set;}
        @AuraEnabled public string City {get;set;}
        @AuraEnabled public string State {get;set;}
        @AuraEnabled public string Country {get;set;}
        @AuraEnabled public string PostalCode {get;set;}
        @AuraEnabled public string Street {get;set;}
    }
    
    public class DistAccWrapper {
        public Location coordinates {get;set;}
        public Integer searchRadius {get;set;}
        public Integer maxResults {get;set;}
    }
    
    public class MyException extends Exception {}

}