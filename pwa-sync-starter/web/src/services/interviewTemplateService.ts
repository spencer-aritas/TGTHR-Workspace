// web/src/services/interviewTemplateService.ts
import type { InterviewTemplateDefinition } from '@shared/contracts/index.ts';

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
}

export const interviewTemplateService = new InterviewTemplateService();
