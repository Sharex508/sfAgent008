public class CSVFileParser {
    
    public List<String> safeSplit(String  inStr, String delim){
        Integer regexFindLimit = 100;
        Integer regexFindCount = 0;
        
        List<String> output = new List<String>();
        
        Matcher m = Pattern.compile(delim).matcher(inStr);
        
        Integer lastEnd = 0;
        
        while(!m.hitEnd())
        {
            while(regexFindCount < regexFindLimit && !m.hitEnd())
            {
                if(m.find())
                {
                    output.add(inStr.substring(lastEnd, m.start()));  
                    lastEnd = m.end();
                }
                else
                {
                    output.add(inStr.substring(lastEnd));
                    lastEnd = inStr.length();
                }
                
                regexFindCount++;
            }
            
            // Note: Using region() to advance instead of substring() saves 
            // drastically on heap size. Nonetheless, we still must reset the 
            // (unmodified) input sequence to avoid a 'Regex too complicated' 
            // error.
            m.reset(inStr);        
            m.region(lastEnd, m.regionEnd());
            
            regexFindCount = 0;
        }
        
        return output;
    }

}