// web/src/services/interviewService.ts
import {
  InterviewAnswer,
  InterviewCreationRequest,
  InterviewCreationResult,
  InterviewQuestion,
  InterviewTemplate,
  InterviewTemplateUpsertRequest,
  InterviewTemplateUpsertResult,
  InterviewTemplateVersion,
  InterviewService as InterviewServiceContract,
} from '../types/interviews';

const TEMPLATE_STORAGE_KEY = 'tgthr.interviews.templates.v1';
const INTERVIEW_STORAGE_KEY = 'tgthr.interviews.instances.v1';

const generateUuid = () => {
  if (typeof crypto !== 'undefined' && crypto.randomUUID) {
    return crypto.randomUUID();
  }

  return `uuid_${Math.random().toString(36).slice(2)}_${Date.now()}`;
};

const nowIso = () => new Date().toISOString();
const safeTrim = (value?: string | null) => (value ?? '').trim();

type StoredTemplateBundle = {
  template: InterviewTemplate;
  version: InterviewTemplateVersion;
  questions: InterviewQuestion[];
};

type StoredInterview = {
  interview: InterviewCreationResult & {
    name: string;
    caseId?: string;
    clientId?: string;
    programEnrollmentId?: string;
    interactionSummaryId?: string;
    startedOn?: string;
    ownerId?: string;
    createdById?: string;
  };
  answers: InterviewAnswer[];
};

class LocalInterviewService implements InterviewServiceContract {
  private hasStorage() {
    return typeof window !== 'undefined' && typeof window.localStorage !== 'undefined';
  }

  private loadTemplates(): StoredTemplateBundle[] {
    if (!this.hasStorage()) {
      return [];
    }

    const raw = window.localStorage.getItem(TEMPLATE_STORAGE_KEY);
    if (!raw) {
      return [];
    }

    try {
      return JSON.parse(raw) as StoredTemplateBundle[];
    } catch {
      return [];
    }
  }

  private saveTemplates(data: StoredTemplateBundle[]) {
    if (!this.hasStorage()) {
      return;
    }

    window.localStorage.setItem(TEMPLATE_STORAGE_KEY, JSON.stringify(data));
  }

  private loadInterviews(): StoredInterview[] {
    if (!this.hasStorage()) {
      return [];
    }

    const raw = window.localStorage.getItem(INTERVIEW_STORAGE_KEY);
    if (!raw) {
      return [];
    }

    try {
      return JSON.parse(raw) as StoredInterview[];
    } catch {
      return [];
    }
  }

  private saveInterviews(data: StoredInterview[]) {
    if (!this.hasStorage()) {
      return;
    }

    window.localStorage.setItem(INTERVIEW_STORAGE_KEY, JSON.stringify(data));
  }

  private resolveBundleForUpsert(
    payload: InterviewTemplateUpsertRequest,
    existing: StoredTemplateBundle[],
  ) {
    if (payload.version.uuid) {
      return existing.find((entry) => entry.version.uuid === payload.version.uuid);
    }

    if (payload.template.uuid) {
      return existing.find((entry) => entry.template.uuid === payload.template.uuid);
    }

    return undefined;
  }

  async listTemplates(params?: {
    programId?: string;
    variant?: string;
    status?: string;
    includeInactive?: boolean;
  }): Promise<InterviewTemplateVersion[]> {
    const stored = this.loadTemplates();

    return stored
      .map((bundle) => ({
        ...bundle.version,
        template: bundle.template,
        questions: bundle.questions,
      }))
      .filter((version) => {
        if (!params) {
          return true;
        }

        if (params.programId && version.template?.programId !== params.programId) {
          return false;
        }

        if (params.variant && version.variant !== params.variant) {
          return false;
        }

        if (
          params.status &&
          version.status.toLowerCase() !== params.status.toLowerCase()
        ) {
          return false;
        }

        if (!params.includeInactive && version.template?.active === false) {
          return false;
        }

        return true;
      });
  }

  async upsertTemplate(
    payload: InterviewTemplateUpsertRequest,
  ): Promise<InterviewTemplateUpsertResult> {
    const stored = this.loadTemplates();
    const existing = this.resolveBundleForUpsert(payload, stored);

    const template: InterviewTemplate = {
      id: existing?.template.id ?? generateUuid(),
      uuid: existing?.template.uuid ?? payload.template.uuid ?? generateUuid(),
      name: safeTrim(payload.template.name),
      programId: payload.template.programId,
      category: payload.template.category,
      active: payload.template.active,
      ownerId: existing?.template.ownerId,
      createdById: existing?.template.createdById,
      lastModifiedById: existing?.template.lastModifiedById,
    };

    const version: InterviewTemplateVersion = {
      id: existing?.version.id ?? generateUuid(),
      uuid: existing?.version.uuid ?? payload.version.uuid ?? generateUuid(),
      templateId: template.id,
      templateUuid: template.uuid,
      name: safeTrim(payload.version.name) || `${template.name} v${payload.version.versionNumber}`,
      versionNumber: payload.version.versionNumber,
      status: payload.version.status,
      variant: payload.version.variant,
      effectiveFrom: payload.version.effectiveFrom,
      effectiveTo: payload.version.effectiveTo,
      ownerId: existing?.version.ownerId,
      createdById: existing?.version.createdById,
      lastModifiedById: existing?.version.lastModifiedById,
      template,
    };

    const questions: InterviewQuestion[] = payload.questions.map((question, index) => {
      const label = safeTrim(question.label) || safeTrim(question.name) || `Question ${index + 1}`;
      const existingQuestion = existing?.questions.find(
        (q) => q.uuid === question.uuid || q.apiName === question.apiName,
      );

      return {
        id: existingQuestion?.id ?? generateUuid(),
        uuid: existingQuestion?.uuid ?? question.uuid ?? generateUuid(),
        name: safeTrim(question.name) || label,
        templateVersionId: version.id,
        templateVersionUuid: version.uuid,
        apiName:
          safeTrim(question.apiName) ||
          label.toLowerCase().replace(/[^a-z0-9]+/g, '_').replace(/^_|_$/g, ''),
        label,
        section: question.section,
        helpText: question.helpText,
        mapsTo: question.mapsTo,
        order: question.order ?? index + 1,
        responseType: question.responseType,
        required: question.required ?? false,
        sensitive: question.sensitive ?? false,
        scoreWeight: question.scoreWeight,
        picklistValues: question.picklistValues,
        ownerId: existingQuestion?.ownerId,
        createdById: existingQuestion?.createdById,
        lastModifiedById: existingQuestion?.lastModifiedById,
      };
    });

    const bundle: StoredTemplateBundle = { template, version, questions };

    if (existing) {
      const index = stored.findIndex((entry) => entry.version.uuid === existing.version.uuid);
      stored[index] = bundle;
    } else {
      stored.push(bundle);
    }

    this.saveTemplates(stored);

    return {
      templateId: template.id!,
      templateUuid: template.uuid,
      templateVersionId: version.id!,
      templateVersionUuid: version.uuid,
      questionIds: questions.map((question) => question.id!).filter(Boolean),
    };
  }

  async createInterview(
    request: InterviewCreationRequest,
  ): Promise<InterviewCreationResult> {
    const templates = this.loadTemplates();
    const bundle = templates.find(
      (entry) =>
        entry.version.uuid === request.interviewTemplateVersionUuid ||
        entry.version.id === request.interviewTemplateVersionId,
    );

    if (!bundle) {
      throw new Error('INTERVIEW_TEMPLATE_NOT_FOUND');
    }

    const interviewId = generateUuid();
    const interviewUuid = generateUuid();

    const interviewRecord: StoredInterview = {
      interview: {
        interviewId,
        interviewUuid,
        pdfFileId: undefined,
        staffSignatureRequired: false,
        clientSignatureRequired: false,
        name: bundle.template.name,
        caseId: request.caseId,
        clientId: request.clientId,
        programEnrollmentId: request.programEnrollmentId,
        interactionSummaryId: request.interactionSummaryId,
        startedOn: request.startedOn ?? nowIso(),
        ownerId: request.ownerId,
        createdById: request.createdById,
      },
      answers: (request.answers ?? []).map((answer) => ({
        ...answer,
        id: answer.id ?? generateUuid(),
        uuid: answer.uuid ?? generateUuid(),
        interviewId,
        interviewUuid,
      })),
    };

    const interviews = this.loadInterviews();
    interviews.push(interviewRecord);
    this.saveInterviews(interviews);

    return {
      interviewId,
      interviewUuid,
      pdfFileId: interviewRecord.interview.pdfFileId,
      staffSignatureRequired: interviewRecord.interview.staffSignatureRequired,
      clientSignatureRequired: interviewRecord.interview.clientSignatureRequired,
    };
  }
}

export const interviewService = new LocalInterviewService();
