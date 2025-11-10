/**
 * @description Unit tests for TaskService, including new TaskCreationDTO pattern and legacy overloads
 */
@isTest
public class TaskServiceTest {
    
    private static final String TEST_ENCOUNTER_UUID = 'test-encounter-2025-001';
    private static final String TEST_NOTES = 'Client completed intake assessment';
    private static final String TEST_POS = '27';
    private static final Boolean TEST_IS_CRISIS = false;
    
    /**
     * @description Test createValidationTask with TaskCreationDTO - happy path
     */
    @isTest
    static void testCreateValidationTask_WithDTO_Success() {
        // Arrange
        User testUser = [SELECT Id FROM User WHERE Profile.Name = 'System Administrator' LIMIT 1];
        Id testUserId = testUser.Id;
        
        Datetime startTime = Datetime.now();
        Datetime endTime = startTime.addMinutes(30);
        
        TaskService.TaskCreationDTO taskDto = new TaskService.TaskCreationDTO(
            null,                    // disbursementId (can be null)
            TEST_ENCOUNTER_UUID,
            TEST_NOTES,
            TEST_POS,
            TEST_IS_CRISIS,
            startTime,
            endTime,
            testUserId
        );
        
        // Act
        Test.startTest();
        Id createdTaskId = TaskService.createValidationTask(taskDto);
        Test.stopTest();
        
        // Assert
        Assert.isNotNull(createdTaskId, 'Task ID should be returned');
        
        Task createdTask = [SELECT Id, CallObject, OwnerId, Description FROM Task WHERE Id = :createdTaskId];
        Assert.isNotNull(createdTask, 'Task should exist in database');
        Assert.areEqual(TEST_ENCOUNTER_UUID, createdTask.CallObject, 'CallObject should match encounterUuid');
        Assert.areEqual(testUserId, createdTask.OwnerId, 'Task owner should match createdByUserId');
        Assert.isTrue(createdTask.Description.contains(TEST_NOTES), 'Description should contain notes');
    }
    
    /**
     * @description Test createValidationTask with empty/default constructor DTO
     */
    @isTest
    static void testCreateValidationTask_WithDTO_DefaultConstructor() {
        // Arrange
        User testUser = [SELECT Id FROM User WHERE Profile.Name = 'System Administrator' LIMIT 1];
        
        TaskService.TaskCreationDTO taskDto = new TaskService.TaskCreationDTO();
        taskDto.encounterUuid = TEST_ENCOUNTER_UUID;
        taskDto.notes = TEST_NOTES;
        taskDto.createdByUserId = testUser.Id;
        
        // Act
        Test.startTest();
        Id createdTaskId = TaskService.createValidationTask(taskDto);
        Test.stopTest();
        
        // Assert
        Assert.isNotNull(createdTaskId, 'Task ID should be returned with default constructor');
        Task createdTask = [SELECT CallObject FROM Task WHERE Id = :createdTaskId];
        Assert.areEqual(TEST_ENCOUNTER_UUID, createdTask.CallObject);
    }
    
    /**
     * @description Test createValidationTask throws when DTO is null
     */
    @isTest
    static void testCreateValidationTask_WithDTO_NullThrows() {
        // Arrange
        TaskService.TaskCreationDTO nullDto = null;
        
        // Act & Assert
        Test.startTest();
        try {
            TaskService.createValidationTask(nullDto);
            Assert.fail('Expected IllegalArgumentException for null DTO');
        } catch (IllegalArgumentException ex) {
            Assert.isTrue(
                ex.getMessage().contains('TaskCreationDTO cannot be null'),
                'Exception message should indicate null DTO'
            );
        }
        Test.stopTest();
    }
    
    /**
     * @description Test legacy overload with individual parameters - backward compatibility
     */
    @isTest
    static void testCreateValidationTask_LegacyOverload_Success() {
        // Arrange
        User testUser = [SELECT Id FROM User WHERE Profile.Name = 'System Administrator' LIMIT 1];
        
        Datetime startTime = Datetime.now();
        Datetime endTime = startTime.addMinutes(30);
        
        // Act
        Test.startTest();
        Id createdTaskId = TaskService.createValidationTask(
            null,                    // disbursementId
            TEST_ENCOUNTER_UUID,
            TEST_NOTES,
            TEST_POS,
            TEST_IS_CRISIS,
            startTime,
            endTime,
            testUser.Id
        );
        Test.stopTest();
        
        // Assert
        Assert.isNotNull(createdTaskId, 'Legacy overload should return Task ID');
        Task createdTask = [SELECT CallObject, OwnerId FROM Task WHERE Id = :createdTaskId];
        Assert.areEqual(TEST_ENCOUNTER_UUID, createdTask.CallObject);
        Assert.areEqual(testUser.Id, createdTask.OwnerId);
    }
    
    /**
     * @description Test both DTO and legacy overload create equivalent tasks
     */
    @isTest
    static void testCreateValidationTask_DTOVsLegacy_Equivalence() {
        // Arrange
        User testUser = [SELECT Id FROM User WHERE Profile.Name = 'System Administrator' LIMIT 1];
        Datetime startTime = Datetime.now();
        Datetime endTime = startTime.addMinutes(30);
        
        // Act
        Test.startTest();
        
        // Create task via DTO
        TaskService.TaskCreationDTO taskDto = new TaskService.TaskCreationDTO(
            null, TEST_ENCOUNTER_UUID, TEST_NOTES, TEST_POS, TEST_IS_CRISIS, startTime, endTime, testUser.Id
        );
        Id dtoTaskId = TaskService.createValidationTask(taskDto);
        
        // Create task via legacy overload
        Id legacyTaskId = TaskService.createValidationTask(
            null, TEST_ENCOUNTER_UUID, TEST_NOTES, TEST_POS, TEST_IS_CRISIS, startTime, endTime, testUser.Id
        );
        
        Test.stopTest();
        
        // Assert
        Task dtoTask = [SELECT CallObject, OwnerId, Description FROM Task WHERE Id = :dtoTaskId];
        Task legacyTask = [SELECT CallObject, OwnerId, Description FROM Task WHERE Id = :legacyTaskId];
        
        Assert.areEqual(dtoTask.CallObject, legacyTask.CallObject, 'CallObject should match');
        Assert.areEqual(dtoTask.OwnerId, legacyTask.OwnerId, 'OwnerId should match');
        Assert.areEqual(dtoTask.Description, legacyTask.Description, 'Description should match');
    }
    
    /**
     * @description Test createValidationTask with disbursement ID
     */
    @isTest
    static void testCreateValidationTask_WithDisbursementId() {
        // Arrange
        User testUser = [SELECT Id FROM User WHERE Profile.Name = 'System Administrator' LIMIT 1];
        
        // Create minimal test objects for context
        Account testAccount = new Account(Name = 'Test Account');
        insert testAccount;
        
        // Mock disbursement ID (won't verify foreign key in test)
        Id mockDisbursementId = testAccount.Id; // Using account ID as mock
        
        Datetime startTime = Datetime.now();
        Datetime endTime = startTime.addMinutes(30);
        
        TaskService.TaskCreationDTO taskDto = new TaskService.TaskCreationDTO(
            mockDisbursementId,
            TEST_ENCOUNTER_UUID,
            TEST_NOTES,
            TEST_POS,
            TEST_IS_CRISIS,
            startTime,
            endTime,
            testUser.Id
        );
        
        // Act
        Test.startTest();
        Id createdTaskId = TaskService.createValidationTask(taskDto);
        Test.stopTest();
        
        // Assert
        Assert.isNotNull(createdTaskId, 'Task with disbursement ID should be created');
        Task createdTask = [SELECT WhatId FROM Task WHERE Id = :createdTaskId];
        Assert.areEqual(mockDisbursementId, createdTask.WhatId, 'Task WhatId should reference disbursement');
    }
    
    /**
     * @description Test createFollowUpTask still works (existing 7-parameter signature)
     */
    @isTest
    static void testCreateFollowUpTask_StillWorks() {
        // Arrange
        User testUser = [SELECT Id FROM User WHERE Profile.Name = 'System Administrator' LIMIT 1];
        
        Account testAccount = new Account(Name = 'Test Account');
        insert testAccount;
        
        Datetime startTime = Datetime.now();
        Datetime endTime = startTime.addMinutes(30);
        
        // Act
        Test.startTest();
        Id createdTaskId = TaskService.createFollowUpTask(
            testAccount.Id,           // accountId (as String)
            TEST_ENCOUNTER_UUID,      // encounterUuid
            'Follow-up outreach',     // notes
            TEST_POS,                 // pos
            false,                    // isCrisis
            startTime,                // startUtc
            endTime                   // endUtc
        );
        Test.stopTest();
        
        // Assert
        Assert.isNotNull(createdTaskId, 'Follow-up task should be created');
        Task createdTask = [SELECT CallObject FROM Task WHERE Id = :createdTaskId];
        Assert.areEqual(TEST_ENCOUNTER_UUID, createdTask.CallObject);
    }
    
    /**
     * @description Test createValidationTask with crisis flag
     */
    @isTest
    static void testCreateValidationTask_CrisisFlag() {
        // Arrange
        User testUser = [SELECT Id FROM User WHERE Profile.Name = 'System Administrator' LIMIT 1];
        
        TaskService.TaskCreationDTO crisisDto = new TaskService.TaskCreationDTO(
            null,
            TEST_ENCOUNTER_UUID,
            'Crisis situation requiring immediate follow-up',
            TEST_POS,
            true,  // isCrisis = true
            Datetime.now(),
            Datetime.now().addMinutes(30),
            testUser.Id
        );
        
        // Act
        Test.startTest();
        Id createdTaskId = TaskService.createValidationTask(crisisDto);
        Test.stopTest();
        
        // Assert
        Assert.isNotNull(createdTaskId, 'Crisis task should be created');
        Task createdTask = [SELECT Description FROM Task WHERE Id = :createdTaskId];
        Assert.isTrue(
            createdTask.Description.contains('Crisis') || createdTask.Description.contains('true'),
            'Crisis flag should be reflected in task'
        );
    }
    
    /**
     * @description Test multiple tasks created in batch
     */
    @isTest
    static void testCreateValidationTask_MultipleTasks() {
        // Arrange
        User testUser = [SELECT Id FROM User WHERE Profile.Name = 'System Administrator' LIMIT 1];
        List<Id> createdTaskIds = new List<Id>();
        
        // Act
        Test.startTest();
        for (Integer i = 0; i < 5; i++) {
            TaskService.TaskCreationDTO taskDto = new TaskService.TaskCreationDTO(
                null,
                'encounter-' + i,
                'Batch task ' + i,
                TEST_POS,
                false,
                Datetime.now(),
                Datetime.now().addMinutes(30),
                testUser.Id
            );
            createdTaskIds.add(TaskService.createValidationTask(taskDto));
        }
        Test.stopTest();
        
        // Assert
        Assert.areEqual(5, createdTaskIds.size(), 'All 5 tasks should be created');
        for (Id taskId : createdTaskIds) {
            Assert.isNotNull(taskId, 'Each task ID should be valid');
        }
        
        List<Task> createdTasks = [SELECT CallObject FROM Task WHERE Id IN :createdTaskIds ORDER BY CallObject];
        Assert.areEqual(5, createdTasks.size(), 'All 5 tasks should exist in database');
    }
    
    /**
     * @description Test DTO field preservation through creation
     */
    @isTest
    static void testCreateValidationTask_AllFieldsPreserved() {
        // Arrange
        User testUser = [SELECT Id FROM User WHERE Profile.Name = 'System Administrator' LIMIT 1];
        
        String uniqueNotes = 'Test notes ' + System.now().getTime();
        String uniquePos = 'POS-UNIQUE-' + System.now().getTime();
        Datetime preciseDtStart = Datetime.now();
        Datetime preciseDtEnd = preciseDtStart.addMinutes(45);
        
        TaskService.TaskCreationDTO taskDto = new TaskService.TaskCreationDTO(
            null,
            TEST_ENCOUNTER_UUID,
            uniqueNotes,
            uniquePos,
            true,  // crisis
            preciseDtStart,
            preciseDtEnd,
            testUser.Id
        );
        
        // Act
        Test.startTest();
        Id createdTaskId = TaskService.createValidationTask(taskDto);
        Test.stopTest();
        
        // Assert
        Task createdTask = [SELECT CallObject, OwnerId, Description FROM Task WHERE Id = :createdTaskId];
        Assert.areEqual(TEST_ENCOUNTER_UUID, createdTask.CallObject, 'encounterUuid preserved');
        Assert.areEqual(testUser.Id, createdTask.OwnerId, 'createdByUserId preserved');
        Assert.isTrue(createdTask.Description.contains(uniqueNotes), 'notes preserved');
        Assert.isTrue(createdTask.Description.contains(uniquePos), 'pos preserved');
    }
}
