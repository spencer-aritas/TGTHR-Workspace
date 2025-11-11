// web/src/services/interviewTemplateService.ts
import type { InterviewTemplateDefinition } from '@shared/contracts/index.ts';

interface InterviewQuestion {
  Id: string;
  Name: string;
  QuestionText: string;  // Mapped from Label__c
  QuestionType: string;  // Mapped from Response_Type__c (text, number, select, etc.)
  IsRequired: boolean;   // Mapped from Required__c
  ApiName?: string;      // From API_Name__c
  MapsTo?: string;       // From Maps_To__c
  HelpText?: string;     // From Help_Text__c
  Section?: string;      // From Section__c
  Sensitive?: boolean;   // From Sensitive__c
  ScoreWeight?: number;  // From Score_Weight__c
  Options?: string;      // Mapped from Picklist_Values__c (newline-separated)
  DisplayOrder?: number; // Mapped from Order__c
}

class InterviewTemplateService {
  async getMobileAvailableTemplates(): Promise<InterviewTemplateDefinition[]> {
    try {
      console.log('Fetching mobile-available interview templates...');
      const response = await fetch('/api/interview-templates/mobile-available');
      
      if (!response.ok) {
        console.error(`Failed to fetch templates (HTTP ${response.status})`);
        return [];
      }
      
      const result = await response.json();
      console.log('Received templates:', result);
      const templates = result.templates || [];
      console.log(`Found ${templates.length} templates`);
      return templates;
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

      console.log(`Fetching questions for template version: ${templateVersionId}`);
      const response = await fetch(`/api/interview-templates/${encodeURIComponent(templateVersionId)}/questions`);
      
      if (!response.ok) {
        console.error(`Failed to fetch questions (HTTP ${response.status})`, await response.text());
        return [];
      }
      
      const result = await response.json();
      console.log('Received questions:', result);
      const questions = result.questions || [];
      console.log(`Found ${questions.length} questions`);
      return questions;
    } catch (err) {
      console.error(`Failed to fetch questions for template ${templateVersionId}`, err);
      return [];
    }
  }
}

export const interviewTemplateService = new InterviewTemplateService();
