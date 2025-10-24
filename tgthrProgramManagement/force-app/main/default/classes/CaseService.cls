public with sharing class CaseService {
    
    @AuraEnabled
    public static Id createCase(String subject, String accountId, String description, String priority, String status, String origin) {
        // Check for existing case with same subject and account
        String existingQuery = 'SELECT Id FROM Case WHERE Subject = :subject AND AccountId = :accountId LIMIT 1';
        List<SObject> existingCases = Database.query(existingQuery);
        if (!existingCases.isEmpty()) {
            return (Id) existingCases[0].get('Id');
        }
        
        SObject caseSObj = (SObject) Type.forName('Case').newInstance();
        caseSObj.put('Subject', subject);
        caseSObj.put('AccountId', accountId);
        caseSObj.put('Description', description);
        caseSObj.put('Priority', priority != null ? priority : 'Medium');
        caseSObj.put('Status', status != null ? status : 'New');
        caseSObj.put('Origin', origin != null ? origin : 'Web');
        caseSObj.put('Type', 'Program Involvement');
        caseSObj.put('OwnerId', UserInfo.getUserId());
        caseSObj.put('IsEscalated', false);

        
        insert caseSObj;
        return caseSObj.Id;
    }
    
    @AuraEnabled
    public static List<SObject> getCasesByAccount(String accountId, Integer maxRows) {
        Integer m = (maxRows == null || maxRows <= 0 || maxRows > 2000) ? 50 : maxRows;
        String query = 'SELECT Id, Subject, Status, Priority, CreatedDate, Description FROM Case WHERE AccountId = :accountId ORDER BY CreatedDate DESC LIMIT :m';
        return Database.query(query);
    }
}