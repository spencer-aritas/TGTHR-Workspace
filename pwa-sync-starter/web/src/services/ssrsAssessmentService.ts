import { SSRSAssessmentRequest, SSRSAssessmentResult, SSRSAssessmentData } from '../../../shared/contracts';

class SSRSAssessmentService {
  async submitAssessment(request: SSRSAssessmentRequest): Promise<SSRSAssessmentResult> {
    const response = await fetch('/api/ssrs-assessment', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
      },
      body: JSON.stringify(request),
    });

    if (!response.ok) {
      throw new Error('Failed to submit SSRS assessment');
    }

    return response.json();
  }

  calculateRisk(data: SSRSAssessmentData): { riskLevel: string; recommendations: string[] } {
    let riskLevel = 'Low';
    const recommendations: string[] = [];

    // Check for imminent risk
    if (data.planLifetime && data.intentLifetime) {
      riskLevel = 'Imminent';
      recommendations.push('Immediate intervention required');
      recommendations.push('Do not leave person alone');
      recommendations.push('Contact crisis team immediately');
    }
    // Check for high risk
    else if (data.actualAttemptPast3Months || data.suicidalThoughtsLifetime) {
      riskLevel = 'High';
      recommendations.push('Schedule follow-up within 24-48 hours');
      recommendations.push('Implement safety plan');
      recommendations.push('Consider hospitalization');
    }
    // Check for moderate risk
    else if (data.suicidalThoughtsLifetime || data.wishDeadLifetime) {
      riskLevel = 'Moderate';
      recommendations.push('Schedule follow-up within 1 week');
      recommendations.push('Provide crisis resources');
      recommendations.push('Monitor closely');
    }
    // Low risk
    else {
      recommendations.push('Continue regular check-ins');
      recommendations.push('Monitor for changes');
    }

    return { riskLevel, recommendations };
  }
}

export const ssrsAssessmentService = new SSRSAssessmentService();