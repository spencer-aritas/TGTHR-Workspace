// shared/contracts/SSRSAssessmentContract.ts
// Contract for Columbia SSRS Full Suicide Screening Assessment

export interface SSRSAssessmentData {
  // Suicidal Ideation - Lifetime
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
  
  // Suicidal Ideation - Past Month
  wishDeadPastMonth?: boolean;
  wishDeadPastMonthDesc?: string;
  suicidalThoughtsPastMonth?: boolean;
  suicidalThoughtsPastMonthDesc?: string;
  methodsPastMonth?: boolean;
  methodsPastMonthDesc?: string;
  intentPastMonth?: boolean;
  intentPastMonthDesc?: string;
  planPastMonth?: boolean;
  planPastMonthDesc?: string;
  
  // Intensity of Ideation
  lifetimeMostSevereType?: number;
  lifetimeMostSevereDesc?: string;
  recentMostSevereType?: number;
  recentMostSevereDesc?: string;
  frequencyLifetime?: number;
  frequencyRecent?: number;
  durationLifetime?: number;
  durationRecent?: number;
  controllabilityLifetime?: number;
  controllabilityRecent?: number;
  deterrentsLifetime?: number;
  deterrentsRecent?: number;
  reasonsLifetime?: number;
  reasonsRecent?: number;
  
  // Suicidal Behavior - Lifetime
  actualAttemptLifetime?: boolean;
  actualAttemptLifetimeDesc?: string;
  actualAttemptLifetimeCount?: number;
  nonSuicidalSelfInjuryLifetime?: boolean;
  interruptedAttemptLifetime?: boolean;
  interruptedAttemptLifetimeDesc?: string;
  interruptedAttemptLifetimeCount?: number;
  abortedAttemptLifetime?: boolean;
  abortedAttemptLifetimeDesc?: string;
  abortedAttemptLifetimeCount?: number;
  preparatoryActsLifetime?: boolean;
  preparatoryActsLifetimeDesc?: string;
  preparatoryActsLifetimeCount?: number;
  
  // Suicidal Behavior - Past 3 Months
  actualAttemptPast3Months?: boolean;
  actualAttemptPast3MonthsCount?: number;
  nonSuicidalSelfInjuryPast3Months?: boolean;
  interruptedAttemptPast3Months?: boolean;
  interruptedAttemptPast3MonthsCount?: number;
  abortedAttemptPast3Months?: boolean;
  abortedAttemptPast3MonthsCount?: number;
  preparatoryActsPast3Months?: boolean;
  preparatoryActsPast3MonthsCount?: number;
  
  // Attempt Details
  mostRecentAttemptDate?: string;
  mostRecentAttemptLethality?: number;
  mostRecentAttemptPotentialLethality?: number;
  mostLethalAttemptDate?: string;
  mostLethalAttemptLethality?: number;
  mostLethalAttemptPotentialLethality?: number;
  firstAttemptDate?: string;
  firstAttemptLethality?: number;
  firstAttemptPotentialLethality?: number;
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
  totalScore?: number;
  riskLevel: 'Low' | 'Moderate' | 'High' | 'Imminent';
  recommendations: string[];
  taskCreated?: boolean;
}

export interface SSRSAssessmentService {
  submitAssessment(request: SSRSAssessmentRequest): Promise<SSRSAssessmentResult>;
  calculateRisk(data: SSRSAssessmentData): { riskLevel: string; recommendations: string[] };
}
