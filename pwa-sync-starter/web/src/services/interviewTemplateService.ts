// web/src/services/interviewTemplateService.ts
import type { InterviewTemplateDefinition } from '@shared/contracts/index.ts';

interface InterviewQuestion {
  Id: string;
  Name: string;
  QuestionText: string;
  QuestionType: string;
  IsRequired: boolean;
  FieldReference?: string;
  Options?: string;
  DisplayOrder?: number;
}

class InterviewTemplateService {
  async getMobileAvailableTemplates(): Promise<InterviewTemplateDefinition[]> {
    try {
      const response = await fetch('/api/interview-templates/mobile-available');
      
      if (!response.ok) {
        console.error(`Failed to fetch templates (HTTP ${response.status})`);
        return [];
      }
      
      const result = await response.json();
      return result.templates || [];
    } catch (err) {
      console.error('Failed to fetch interview templates', err);
      return [];
    }
  }

  async getQuestionsForTemplate(templateVersionId: string): Promise<InterviewQuestion[]> {
    try {
      if (!templateVersionId) {
        console.warn('templateVersionId is required to fetch questions');
        return [];
      }

      const response = await fetch(`/api/interview-templates/${encodeURIComponent(templateVersionId)}/questions`);
      
      if (!response.ok) {
        console.error(`Failed to fetch questions (HTTP ${response.status})`);
        return [];
      }
      
      const result = await response.json();
      return result.questions || [];
    } catch (err) {
      console.error(`Failed to fetch questions for template ${templateVersionId}`, err);
      return [];
    }
  }
}

export const interviewTemplateService = new InterviewTemplateService();
