// web/src/services/interviewAnswerService.ts

interface SaveInterviewAnswersRequest {
  caseId: string;
  templateVersionId: string;
  answers: Record<string, string>;
}

interface SaveInterviewAnswersResponse {
  success: boolean;
  interviewId: string;
  answersCount: number;
  message: string;
}

class InterviewAnswerService {
  async saveInterviewAnswers(
    caseId: string,
    templateVersionId: string,
    answers: Record<string, string>
  ): Promise<SaveInterviewAnswersResponse> {
    try {
      const payload: SaveInterviewAnswersRequest = {
        caseId,
        templateVersionId,
        answers
      };

      const response = await fetch('/api/interview-answers', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify(payload)
      });

      if (!response.ok) {
        const errorData = await response.json().catch(() => ({ detail: 'Unknown error' }));
        throw new Error(errorData.detail || `HTTP ${response.status}`);
      }

      const result = await response.json();
      return result;
    } catch (err) {
      console.error('Failed to save interview answers', err);
      throw err;
    }
  }
}

export const interviewAnswerService = new InterviewAnswerService();
