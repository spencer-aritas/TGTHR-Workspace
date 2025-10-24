// web/src/types/ssrs.ts
// SSRS Assessment types for PWA

export interface SSRSAssessmentData {
  wishDeadLifetime?: boolean;
  wishDeadLifetimeDesc?: string;
  suicidalThoughtsLifetime?: boolean;
  suicidalThoughtsLifetimeDesc?: string;
  methodsLifetime?: boolean;
  methodsLifetimeDesc?: string;
  intentLifetime?: boolean;
  intentLifetimeDesc?: string;
  planLifetime?: boolean;
  planLifetimeDesc?: string;
  wishDeadPastMonth?: boolean;
  suicidalThoughtsPastMonth?: boolean;
  methodsPastMonth?: boolean;
  intentPastMonth?: boolean;
  planPastMonth?: boolean;
  frequencyLifetime?: number;
  frequencyRecent?: number;
  actualAttemptLifetime?: boolean;
  actualAttemptLifetimeDesc?: string;
  actualAttemptPast3Months?: boolean;
}

export interface SSRSAssessmentRequest {
  accountId: string;
  caseId?: string;
  assessmentData: SSRSAssessmentData;
  assessmentDate: string;
  assessedById: string;
}

export interface SSRSAssessmentResult {
  assessmentId: string;
  caseId: string;
  riskLevel: 'Low' | 'Moderate' | 'High' | 'Imminent';
  recommendations: string[];
  taskCreated?: boolean;
}