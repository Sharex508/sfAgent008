@isTest
public class GetHeaderFieldsTest {
    
    @isTest static void testGetterMethod(){
    	String res = GetHeaderFields.getter();
        List<Schema.FieldSetMember> bluEdgeExtendedBasic = Schema.SObjectType.SBQQ__Quote__c.fieldSets.getMap().get('BluEdge_Extended_Basic').getFields();
        List<Schema.FieldSetMember> bluEdgeMajorComponent = Schema.SObjectType.SBQQ__Quote__c.fieldSets.getMap().get('BluEdge_Major_Component').getFields();
        List<Schema.FieldSetMember> bluEdgeOptionalCoverage = Schema.SObjectType.SBQQ__Quote__c.fieldSets.getMap().get('BluEdge_Optional_Coverage').getFields();
        List<Schema.FieldSetMember> bluEdgeEliteRepair = Schema.SObjectType.SBQQ__Quote__c.fieldSets.getMap().get('BluEdge_Elite_Repair').getFields();
        
    	List<FieldSetUtils.CustomFieldDefinition> listFields = (List<FieldSetUtils.CustomFieldDefinition>) JSON.deserialize(res, List<FieldSetUtils.CustomFieldDefinition>.class);
    }
}