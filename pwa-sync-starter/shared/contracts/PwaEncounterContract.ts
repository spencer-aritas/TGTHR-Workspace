// shared/contracts/PwaEncounterContract.ts
// Contract between PWA and Salesforce for Encounter Data
// Maps to: PwaEncounter.cls (Apex global class)

/**
 * PwaEncounter Contract
 * Represents a single encounter captured by the PWA (field engagement, outreach, etc.)
 * Maps to: PwaEncounter.cls (Apex)
 * 
 * Data Flow:
 *   PWA → REST endpoint → ProgramEnrollmentService.ingestEncounter()
 *   Deserialized into PwaEncounter (Apex)
 *   Used to create Account, ProgramEnrollment, Task, etc.
 */
export interface PwaEncounter {
  encounterUuid: string;          // Required: Unique encounter identifier (CallObject in Salesforce)
  personUuid: string;             // Required: Person Account UUID (UUID__c field)
  firstName: string;              // Required: First name
  lastName: string;               // Required: Last name
  startUtc?: string;              // Optional: ISO datetime string (encounter start)
  endUtc?: string;                // Optional: ISO datetime string (encounter end)
  pos?: string;                   // Optional: Position/location code (default "27")
  isCrisis: boolean;              // Required: Crisis indicator
  notes?: string;                 // Optional: Encounter notes/description
  location?: string;              // Optional: Physical location or address
  services?: string;              // Optional: Services provided (comma-separated or JSON)
  deviceId?: string;              // Optional: Mobile device identifier
}

/**
 * PwaEncounter with additional metadata
 * Extended version for logging and tracking
 */
export interface PwaEncounterExtended extends PwaEncounter {
  encounterDate?: string;         // Optional: ISO date string
  duration?: number;              // Optional: Duration in minutes
  serviceArea?: string;           // Optional: Service area code
  referralSource?: string;        // Optional: How person was referred
  followUpRequired?: boolean;      // Optional: Flag for follow-up needed
  tags?: string[];                // Optional: Encounter tags/categories
}

/**
 * Ingest Encounter Request
 * Payload sent to ProgramEnrollmentService.ingestEncounter() REST endpoint
 */
export interface IngestEncounterRequest {
  email?: string;                 // Optional: Person email
  phone?: string;                 // Optional: Person phone
  birthdate?: string;             // Optional: ISO date (YYYY-MM-DD)
  createdByUserId?: string;       // Optional: Creating user ID
  programId?: string;             // Optional: Program ID (lookup)
  programName?: string;           // Optional: Program name (fallback lookup)
  // Plus all PwaEncounter fields
  encounterUuid: string;
  personUuid: string;
  firstName: string;
  lastName: string;
  startUtc?: string;
  endUtc?: string;
  pos?: string;
  isCrisis: boolean;
  notes?: string;
  location?: string;
  services?: string;
  deviceId?: string;
}

/**
 * Ingest Encounter Response
 * Returned from ProgramEnrollmentService.ingestEncounter()
 */
export interface IngestEncounterResponse {
  success: boolean;               // Operation success
  encounterId?: string;           // Echo back: encounterUuid
  programEnrollmentId?: string;   // Created ProgramEnrollment ID
  programId?: string;             // Program ID used
  accountId?: string;             // Account ID (created or upserted)
  personUuid?: string;            // Echo back: personUuid
  firstName?: string;             // Echo back: firstName
  lastName?: string;              // Echo back: lastName
  message?: string;               // Success or error message
  errors?: string[];              // Detailed error messages
  taskIds?: string[];             // Created Task IDs (if applicable)
  disbursementIds?: string[];     // Created Disbursement IDs (if applicable)
}

/**
 * Encounter Service Interface
 * Defines contract for encounter ingestion and querying
 */
export interface EncounterServiceContract {
  /**
   * Ingest a new encounter from PWA
   * @param request IngestEncounterRequest with encounter data
   * @returns Promise resolving to IngestEncounterResponse
   * 
   * This method:
   * - Upserts Account by UUID
   * - Creates or finds ProgramEnrollment
   * - Creates follow-up Task if needed
   * - Processes benefit disbursements if applicable
   * - Returns created record IDs
   */
  ingestEncounter(request: IngestEncounterRequest): Promise<IngestEncounterResponse>;

  /**
   * Retrieve encounters for a person
   * @param personUuid Person Account UUID
   * @param maxRows Optional: maximum rows to return
   * @returns Promise resolving to array of PwaEncounter
   */
  getPersonEncounters(personUuid: string, maxRows?: number): Promise<PwaEncounter[]>;

  /**
   * Retrieve encounters for a program
   * @param programId Program record ID
   * @param startDate Optional: ISO date string (YYYY-MM-DD)
   * @param endDate Optional: ISO date string (YYYY-MM-DD)
   * @param maxRows Optional: maximum rows to return
   * @returns Promise resolving to array of PwaEncounter
   */
  getProgramEncounters(
    programId: string,
    startDate?: string,
    endDate?: string,
    maxRows?: number
  ): Promise<PwaEncounter[]>;

  /**
   * Retrieve a single encounter
   * @param encounterUuid Unique encounter identifier
   * @returns Promise resolving to PwaEncounter or null
   */
  getEncounter(encounterUuid: string): Promise<PwaEncounter | null>;

  /**
   * Retrieve crisis encounters (flagged for follow-up)
   * @param programId Optional: filter by program
   * @param maxRows Optional: maximum rows to return
   * @returns Promise resolving to array of PwaEncounterExtended
   */
  getCrisisEncounters(programId?: string, maxRows?: number): Promise<PwaEncounterExtended[]>;
}

// Type guards and validators
export function isPwaEncounter(obj: any): obj is PwaEncounter {
  return (
    typeof obj === 'object' &&
    obj !== null &&
    typeof obj.encounterUuid === 'string' &&
    typeof obj.personUuid === 'string' &&
    typeof obj.firstName === 'string' &&
    typeof obj.lastName === 'string' &&
    typeof obj.isCrisis === 'boolean'
  );
}

export function isIngestEncounterRequest(obj: any): obj is IngestEncounterRequest {
  return (
    typeof obj === 'object' &&
    obj !== null &&
    typeof obj.encounterUuid === 'string' &&
    typeof obj.personUuid === 'string' &&
    typeof obj.firstName === 'string' &&
    typeof obj.lastName === 'string' &&
    typeof obj.isCrisis === 'boolean'
  );
}

// Validation helpers
export function validatePwaEncounter(encounter: any): { valid: boolean; errors: string[] } {
  const errors: string[] = [];

  if (!encounter) {
    errors.push('Encounter object is required');
    return { valid: false, errors };
  }

  if (!encounter.encounterUuid) {
    errors.push('encounterUuid is required');
  }
  if (!encounter.personUuid) {
    errors.push('personUuid is required');
  }
  if (!encounter.firstName) {
    errors.push('firstName is required');
  }
  if (!encounter.lastName) {
    errors.push('lastName is required');
  }
  if (typeof encounter.isCrisis !== 'boolean') {
    errors.push('isCrisis must be a boolean');
  }

  if (encounter.startUtc && !isValidISODatetime(encounter.startUtc)) {
    errors.push('startUtc must be valid ISO datetime (e.g., 2025-11-08T14:30:00Z)');
  }
  if (encounter.endUtc && !isValidISODatetime(encounter.endUtc)) {
    errors.push('endUtc must be valid ISO datetime');
  }

  return { valid: errors.length === 0, errors };
}

export function isValidISODatetime(dateStr: string): boolean {
  try {
    const date = new Date(dateStr);
    return date instanceof Date && !isNaN(date.getTime());
  } catch {
    return false;
  }
}

// Conversion helpers
export function encountToIngestRequest(
  encounter: PwaEncounter,
  additionalData?: Partial<IngestEncounterRequest>
): IngestEncounterRequest {
  return {
    ...encounter,
    ...additionalData,
  };
}

export function enrichEncounterWithMetadata(
  encounter: PwaEncounter,
  metadata: Partial<PwaEncounterExtended>
): PwaEncounterExtended {
  return {
    ...encounter,
    ...metadata,
  };
}
