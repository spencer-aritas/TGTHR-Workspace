// web/src/types/interviews.ts
// Re-export interview contract types and provide helper builders for the wizard.

export * from '@shared/contracts/index.ts';

import {
  InterviewQuestionDraft,
  InterviewTemplateDraft,
  InterviewTemplateVersionDraft,
} from '@shared/contracts/index.ts';

export interface InterviewBuilderState {
  template: InterviewTemplateDraft;
  version: InterviewTemplateVersionDraft;
  questions: InterviewQuestionDraft[];
}

export const createDefaultInterviewTemplateDraft = (): InterviewTemplateDraft => ({
  name: '',
  programId: undefined,
  category: 'CaseManagement',
  active: true,
});

export const createDefaultInterviewTemplateVersionDraft =
  (): InterviewTemplateVersionDraft => ({
    name: '',
    versionNumber: 1,
    status: 'Draft',
    variant: 'CaseManager',
    effectiveFrom: undefined,
    effectiveTo: undefined,
  });

export const createDefaultInterviewQuestionDraft = (
  overrides: Partial<InterviewQuestionDraft> = {},
): InterviewQuestionDraft => ({
  name: '',
  apiName: '',
  label: '',
  section: '',
  helpText: '',
  mapsTo: '',
  order: 1,
  responseType: 'text',
  required: false,
  sensitive: false,
  scoreWeight: undefined,
  picklistValues: [],
  ...overrides,
});

export const createInterviewBuilderState = (): InterviewBuilderState => ({
  template: createDefaultInterviewTemplateDraft(),
  version: createDefaultInterviewTemplateVersionDraft(),
  questions: [],
});
