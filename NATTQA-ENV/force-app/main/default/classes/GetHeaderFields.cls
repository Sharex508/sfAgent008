/*
* Rest Resource class that QCP sends request to an retrive the QCP controller methods
* Test Class:GetHeaderFieldsTest
*/
@RestResource(urlMapping='/GetHeaderFields/*') 
global with sharing class GetHeaderFields {
    /*
* Method to get the Fields from a Object (First parameter) and inside a FieldSet (Second parameter)
*/
    @HttpGet
    global static String getter(){
        List<FieldSetUtils.CustomFieldDefinition> headerFields = new List<FieldSetUtils.CustomFieldDefinition>();
        
        List<FieldSetUtils.CustomFieldDefinition> bluEdgeExtendedBasic = FieldsetUtils.getFields('SBQQ__Quote__c', 'BluEdge_Extended_Basic');
        headerFields.addAll(bluEdgeExtendedBasic);
        List<FieldSetUtils.CustomFieldDefinition> bluEdgeMajorComponent = FieldsetUtils.getFields('SBQQ__Quote__c', 'BluEdge_Major_Component');
        headerFields.addAll(bluEdgeMajorComponent);
        List<FieldSetUtils.CustomFieldDefinition> bluEdgeOptionalCoverage = FieldsetUtils.getFields('SBQQ__Quote__c', 'BluEdge_Optional_Coverage');
        headerFields.addAll(bluEdgeOptionalCoverage);
        List<FieldSetUtils.CustomFieldDefinition> bluEdgeEliteRepair = FieldsetUtils.getFields('SBQQ__Quote__c', 'BluEdge_Elite_Repair');
        headerFields.addAll(bluEdgeEliteRepair);
        return JSON.serialize(headerFields);
    }     
    
}