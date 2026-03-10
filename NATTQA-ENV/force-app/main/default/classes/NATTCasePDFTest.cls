@IsTest
private class NATTCasePDFTest {
    @IsTest static void myUnitTest(){
        Case c = new Case();
        c.Subject='Test';
        insert c;
        
        NATTCasePDF casePdf = new NATTCasePDF(new ApexPages.StandardController(c));
        Case ca = casePdf.c; 
    }
}