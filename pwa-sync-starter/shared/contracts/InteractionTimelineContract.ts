// shared/contracts/InteractionTimelineContract.ts
// Lightweight row returned for the case timeline list view.
// Matches the widened SOQL in interaction_summary_service.py.

export interface InteractionTimelineRow {
  Id: string;
  Name?: string;
  RelatedRecordId?: string;
  AccountId?: string;
  InteractionPurpose?: string;
  Status?: string;
  InteractionDate?: string;
  StartTime?: string;
  EndTime?: string;
  Notes?: string;
  CreatedByName?: string;
  CreatedDate?: string;
  LastModifiedDate?: string;
  InterviewId?: string;
  InterviewTemplateName?: string;
  ActionRequired?: string;
  ActionAssignedTo?: string;
  RequiresManagerApproval?: boolean;
  ManagerSigned?: boolean;
  ManagerRejected?: boolean;
  ManagerApprover?: string;
}

export interface InteractionTimelineResponse {
  interactions: InteractionTimelineRow[];
  count: number;
}
