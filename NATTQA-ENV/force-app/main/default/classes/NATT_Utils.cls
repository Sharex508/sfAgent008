public with sharing class NATT_Utils {
    
    public static Boolean isError = false;

    public class TestException extends Exception {}

    public static Boolean isAccessible(String sObjectType, String fieldName){
        SObjectType schemaType = Schema.getGlobalDescribe().get(sObjectType);
        Map<String, SObjectField> fields = schemaType.getDescribe().fields.getMap();
        DescribeFieldResult fieldDescribe = fields.get(fieldName).getDescribe();

        return fieldDescribe.isAccessible();
    }
    
    public static Boolean isAccessible(String sObjectType){
        SObjectType schemaType = Schema.getGlobalDescribe().get(sObjectType);

        return schemaType.getDescribe().isAccessible();
    }
    
    public static Boolean isCreateable(String sObjectType){
        SObjectType schemaType = Schema.getGlobalDescribe().get(sObjectType);

        return schemaType.getDescribe().isCreateable();
    }
    
    public static Boolean isDeletable(String sObjectType){
        SObjectType schemaType = Schema.getGlobalDescribe().get(sObjectType);

        return schemaType.getDescribe().isDeletable();
    }
    
    public static Boolean isUpdatable(String sObjectType){
        SObjectType schemaType = Schema.getGlobalDescribe().get(sObjectType);
        
        return schemaType.getDescribe().isUpdateable();
    }

}