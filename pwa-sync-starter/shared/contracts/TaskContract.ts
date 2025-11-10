// shared/contracts/TaskContract.ts
// Contract between PWA and Salesforce TaskService
// Maps to Apex TaskService.TaskCreationDTO and TaskService.FollowUpTaskDTO

/**
 * TaskCreationDTO Contract
 * Used to create validation tasks for benefit disbursements
 * Maps to: TaskService.TaskCreationDTO (Apex)
 */
export interface TaskCreationRequest {
  disbursementId?: string;        // Optional: WhatId for BenefitDisbursement
  encounterUuid: string;          // Required: CallObject unique identifier
  notes?: string;                 // Optional: Task description prefix
  pos?: string;                   // Optional: Position/location code (default "27")
  isCrisis: boolean;              // Required: Crisis indicator flag
  startUtc?: string;              // Optional: ISO datetime string (e.g., "2025-11-08T14:30:00Z")
  endUtc?: string;                // Optional: ISO datetime string
  createdByUserId?: string;       // Optional: Task owner User ID
}

/**
 * FollowUpTaskDTO Contract
 * Used to create follow-up tasks for outreach encounters
 * Maps to: TaskService.FollowUpTaskDTO (Apex)
 */
export interface FollowUpTaskRequest {
  accountId: string;              // Required: WhatId - Account this task relates to
  encounterUuid: string;          // Required: CallObject unique identifier
  notes?: string;                 // Optional: Task description
  pos?: string;                   // Optional: Position/location (default "27")
  isCrisis: boolean;              // Required: Crisis flag
  startUtc?: string;              // Optional: ISO datetime string
  endUtc?: string;                // Optional: ISO datetime string
  createdByUserId?: string;       // Optional: Task owner User ID
}

/**
 * Task Creation Response
 * Returned after successful task creation
 */
export interface TaskCreationResponse {
  success: boolean;               // Operation success indicator
  taskId?: string;                // Created Task Id (if successful)
  message?: string;               // Success or error message
  errorCode?: string;             // Diagnostic error code
}

/**
 * Task Detail
 * Represents a Salesforce Task record
 */
export interface TaskDetail {
  Id: string;                     // Task record ID
  Subject: string;                // Task subject line
  Description?: string;           // Full task description
  WhatId?: string;                // Related record ID (Disbursement or Account)
  WhoId?: string;                 // Related contact/lead
  OwnerId: string;                // Task owner (User ID)
  CallObject?: string;            // Encounter UUID
  ActivityDate?: string;          // Activity date
  Status: string;                 // Not Started, In Progress, Completed
  Priority?: string;              // Low, Normal, High
  CreatedDate?: string;           // Creation timestamp
  CreatedById?: string;           // Creator User ID
  LastModifiedDate?: string;      // Last update timestamp
}

/**
 * Task Service Interface
 * Defines contract for Task management operations
 */
export interface TaskServiceContract {
  /**
   * Create a validation task for benefit disbursement
   * @param request TaskCreationRequest with all required fields
   * @returns Promise resolving to TaskCreationResponse
   */
  createValidationTask(request: TaskCreationRequest): Promise<TaskCreationResponse>;

  /**
   * Create a follow-up task for outreach
   * @param request FollowUpTaskRequest with all required fields
   * @returns Promise resolving to TaskCreationResponse
   */
  createFollowUpTask(request: FollowUpTaskRequest): Promise<TaskCreationResponse>;

  /**
   * Retrieve a task by ID
   * @param taskId Task record ID
   * @returns Promise resolving to TaskDetail
   */
  getTask(taskId: string): Promise<TaskDetail>;

  /**
   * Retrieve tasks by related record (WhatId)
   * @param whatId Related record ID (Account or Disbursement)
   * @param maxRows Optional: maximum rows to return
   * @returns Promise resolving to array of TaskDetail
   */
  getTasksByWhat(whatId: string, maxRows?: number): Promise<TaskDetail[]>;

  /**
   * Retrieve tasks by encounter UUID
   * @param encounterUuid Unique encounter identifier
   * @returns Promise resolving to TaskDetail
   */
  getTaskByEncounter(encounterUuid: string): Promise<TaskDetail | null>;

  /**
   * Update a task
   * @param taskId Task record ID
   * @param updates Partial TaskDetail with fields to update
   * @returns Promise resolving to TaskCreationResponse
   */
  updateTask(taskId: string, updates: Partial<TaskDetail>): Promise<TaskCreationResponse>;
}

// Type guards and helpers
export function isTaskCreationRequest(obj: any): obj is TaskCreationRequest {
  return (
    typeof obj === 'object' &&
    obj !== null &&
    typeof obj.encounterUuid === 'string' &&
    typeof obj.isCrisis === 'boolean'
  );
}

export function isFollowUpTaskRequest(obj: any): obj is FollowUpTaskRequest {
  return (
    typeof obj === 'object' &&
    obj !== null &&
    typeof obj.accountId === 'string' &&
    typeof obj.encounterUuid === 'string' &&
    typeof obj.isCrisis === 'boolean'
  );
}

// Conversion helpers for Datetime handling
export function convertToISODatetime(date: Date | string | undefined): string | undefined {
  if (!date) return undefined;
  if (typeof date === 'string') return date;
  return date.toISOString();
}

export function convertFromISODatetime(dateStr: string | undefined): Date | undefined {
  if (!dateStr) return undefined;
  return new Date(dateStr);
}
