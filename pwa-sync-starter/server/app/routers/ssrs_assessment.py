from fastapi import APIRouter, HTTPException
from pydantic import BaseModel
from typing import Optional, List
import logging

from ..salesforce.assessment_service import AssessmentServiceClient

logger = logging.getLogger(__name__)

router = APIRouter()
assessment_service = AssessmentServiceClient()

class SSRSAssessmentData(BaseModel):
    wishDeadLifetime: Optional[bool] = None
    wishDeadLifetimeDesc: Optional[str] = None
    suicidalThoughtsLifetime: Optional[bool] = None
    suicidalThoughtsLifetimeDesc: Optional[str] = None
    methodsLifetime: Optional[bool] = None
    methodsLifetimeDesc: Optional[str] = None
    intentLifetime: Optional[bool] = None
    intentLifetimeDesc: Optional[str] = None
    planLifetime: Optional[bool] = None
    planLifetimeDesc: Optional[str] = None
    wishDeadPastMonth: Optional[bool] = None
    suicidalThoughtsPastMonth: Optional[bool] = None
    methodsPastMonth: Optional[bool] = None
    intentPastMonth: Optional[bool] = None
    planPastMonth: Optional[bool] = None
    frequencyLifetime: Optional[int] = None
    frequencyRecent: Optional[int] = None
    actualAttemptLifetime: Optional[bool] = None
    actualAttemptLifetimeDesc: Optional[str] = None
    actualAttemptPast3Months: Optional[bool] = None

class SSRSAssessmentRequest(BaseModel):
    accountId: str
    caseId: Optional[str] = None
    assessmentData: SSRSAssessmentData
    assessmentDate: str
    assessedById: str

class SSRSAssessmentResult(BaseModel):
    assessmentId: str
    caseId: str
    totalScore: Optional[int] = None
    riskLevel: str
    recommendations: List[str]
    taskCreated: bool = False

@router.post("/ssrs-assessment", response_model=SSRSAssessmentResult)
async def submit_ssrs_assessment(request: SSRSAssessmentRequest):
    """Submit SSRS Assessment and create/update case as needed"""
    try:
        # Normalize payloads
        assessment_dict = request.assessmentData.dict(exclude_none=True)
        bool_score = sum(1 for value in assessment_dict.values() if isinstance(value, bool) and value)
        
        # Determine risk tier + recommendations
        if request.assessmentData.planLifetime and request.assessmentData.intentLifetime:
            risk_level = "Imminent"
            recommendations = [
                "Immediate intervention required",
                "Do not leave person alone", 
                "Contact crisis team immediately"
            ]
        elif request.assessmentData.actualAttemptPast3Months or (
            request.assessmentData.suicidalThoughtsLifetime and request.assessmentData.methodsLifetime
        ):
            risk_level = "High"
            recommendations = [
                "Schedule follow-up within 24-48 hours",
                "Implement safety plan",
                "Consider hospitalization"
            ]
        elif request.assessmentData.suicidalThoughtsLifetime or request.assessmentData.wishDeadLifetime:
            risk_level = "Moderate"
            recommendations = [
                "Schedule follow-up within 1 week",
                "Provide crisis resources",
                "Monitor closely"
            ]
        else:
            risk_level = "Low"
            recommendations = [
                "Continue regular check-ins",
                "Monitor for changes"
            ]

        mapped_fields = assessment_service.build_field_payload(assessment_dict)

        assessment_id = assessment_service.create_assessment(
            account_id=request.accountId,
            case_id=request.caseId,
            assessment_date=request.assessmentDate,
            assessed_by_id=request.assessedById or None,
            assessment_fields=mapped_fields,
            total_score=bool_score,
            risk_level=risk_level,
            raw_payload=assessment_dict,
        )

        task_created = assessment_service.create_follow_up_task(
            case_id=request.caseId,
            risk_level=risk_level,
            recommendations=recommendations,
        )
        
        return SSRSAssessmentResult(
            assessmentId=assessment_id,
            caseId=request.caseId or "",
            totalScore=bool_score,
            riskLevel=risk_level,
            recommendations=recommendations,
            taskCreated=task_created
        )
        
    except Exception as e:
        logger.error(f"Error submitting SSRS assessment: {str(e)}", exc_info=True)
        raise HTTPException(status_code=500, detail="Failed to submit assessment")
