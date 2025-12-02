/**
 * Test script for ContentDocumentLink creation following established patterns
 * 
 * This verifies that the linkFilesToCase method works as expected
 * Run with: sf apex run --file scripts/apex/testFileLinkingToCase.apex -o benefits
 */

// Get a test Case
List<Case> cases = [SELECT Id, CaseNumber FROM Case LIMIT 1];
if (cases.isEmpty()) {
    System.debug('❌ No Case records found. Create a Case first.');
    return;
}

Case testCase = cases[0];
System.debug('📋 Using Case: ' + testCase.CaseNumber + ' (ID: ' + testCase.Id + ')');

// Create a test ContentVersion (simulating file upload)
ContentVersion cv = new ContentVersion();
cv.Title = 'Test Income Documentation';
cv.PathOnClient = 'test-income.pdf';
cv.VersionData = Blob.valueOf('Test file content for income verification');
cv.IsMajorVersion = true;
insert cv;

System.debug('📤 Created ContentVersion: ' + cv.Id);

// Query to get ContentDocumentId
ContentVersion cvQueried = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id LIMIT 1];
String contentDocId = cvQueried.ContentDocumentId;
System.debug('📄 ContentDocument ID: ' + contentDocId);

// Call the linkFilesToCase method
List<String> fileIds = new List<String>{ contentDocId };
Boolean success = InterviewSessionController.linkFilesToCase(testCase.Id, fileIds);

if (success) {
    System.debug('✅ File linking succeeded!');
    
    // Verify the link was created
    List<ContentDocumentLink> links = [
        SELECT Id, LinkedEntityId, ContentDocumentId, ShareType, Visibility
        FROM ContentDocumentLink
        WHERE LinkedEntityId = :testCase.Id
        AND ContentDocumentId = :contentDocId
        LIMIT 1
    ];
    
    if (!links.isEmpty()) {
        ContentDocumentLink link = links[0];
        System.debug('✅ ContentDocumentLink verified:');
        System.debug('   - ID: ' + link.Id);
        System.debug('   - LinkedEntityId: ' + link.LinkedEntityId);
        System.debug('   - ContentDocumentId: ' + link.ContentDocumentId);
        System.debug('   - ShareType: ' + link.ShareType);
        System.debug('   - Visibility: ' + link.Visibility);
        System.debug('');
        System.debug('🎉 Test completed successfully! File should now appear in Case Files related list.');
    } else {
        System.debug('❌ ContentDocumentLink not found - linking may have failed');
    }
} else {
    System.debug('❌ File linking failed!');
}
