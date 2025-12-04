@isTest
public class ConvertIntegerToStringTest {

    @isTest
    public static void testGetCount() {
        
        ConvertIntegerToString.Requests request = new ConvertIntegerToString.Requests();
        request.RequestInt = 5; 

        List<ConvertIntegerToString.Requests> requestList = new List<ConvertIntegerToString.Requests>();
        requestList.add(request);

        List<ConvertIntegerToString.Results> resultList = ConvertIntegerToString.GetCount(requestList);

        System.assertEquals(1, resultList.size(), 'There should be one result');
        ConvertIntegerToString.Results result = resultList[0];
        System.assertNotEquals(null, result.RequestResult, 'The result list should not be null');
        System.assertEquals(5, result.RequestResult.size(), 'The result list should have 5 elements');
        System.assertEquals('1', result.RequestResult[0], 'First element should be "1"');
        System.assertEquals('5', result.RequestResult[4], 'Last element should be "5"');
    }
}
