@isTest
public class FieldSetUtilsTest {
    @isTest static void testFieldSetUtils(){
        List<FieldSetUtils.CustomFieldDefinition> fieldSetUtilsList = FieldSetUtils.getFields('SBQQ__Quote__c', 'NATT_BluEdge_Quote_Line_Editor');
        List<String> picklistValues = FieldSetUtils.getPicklistValues('SBQQ__Quote__c', 'SBQQ__BillingFrequency__c');
    }
}