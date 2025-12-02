// Test Map syntax
List<Map<String, Object>> testData = new List<Map<String, Object>>();

testData.add(new Map<String, Object>{
    'name' => 'Test',
    'value' => 123
});

System.debug('Test successful: ' + testData);
