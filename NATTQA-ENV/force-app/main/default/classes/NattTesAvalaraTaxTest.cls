@IsTest
private class NattTesAvalaraTaxTest {
    @IsTest
    static void testCallout(){
        Test.setMock(HttpCalloutMock.class, new NattTesAvalaraTaxMockResponse());
        NattTesAvalaraTaxResponse resp = NattTesAvalaraTax.getTaxAmount(100.00,'103 Test Street','Calhoun','GA','30701','US');
    }
}