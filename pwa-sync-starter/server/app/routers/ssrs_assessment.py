from fastapi import APIRouter, HTTPException
from pydantic import BaseModel
from typing import Optional, List
import logging
import json
from ..salesforce.sf_client import SalesforceClient

logger = logging.getLogger(__name__)

router = APIRouter()

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
    riskLevel: str
    recommendations: List[str]
    taskCreated: bool = False

@router.post("/ssrs-assessment", response_model=SSRSAssessmentResult)
async def submit_ssrs_assessment(request: SSRSAssessmentRequest):
    """Submit SSRS Assessment and create/update case as needed"""
    try:
        # Calculate risk level
        data = request.assessmentData
        
        if data.planLifetime and data.intentLifetime:
            risk_level = "Imminent"
            recommendations = [
                "Immediate intervention required",
                "Do not leave person alone", 
                "Contact crisis team immediately"
            ]
        elif data.actualAttemptPast3Months or (data.suicidalThoughtsLifetime and data.methodsLifetime):
            risk_level = "High"
            recommendations = [
                "Schedule follow-up within 24-48 hours",
                "Implement safety plan",
                "Consider hospitalization"
            ]
        elif data.suicidalThoughtsLifetime or data.wishDeadLifetime:
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

        # TODO: Deploy SSRSAssessmentHandler Apex class to Salesforce
        # For now, create a mock assessment record
        assessment_id = f"SSRS_{request.accountId}_{request.assessmentDate}"
        case_id = request.caseId or f"CASE_{request.accountId}"
        task_created = risk_level in ["Moderate", "High", "Imminent"]
        
        logger.info(f"Mock SSRS assessment created: {assessment_id} with {risk_level} risk")
        
        return SSRSAssessmentResult(
            assessmentId=assessment_id,
            caseId=case_id,
            totalScore=yes_count,
            riskLevel=risk_level,
            recommendations=recommendations,
            taskCreated=task_created
        )
        
    except Exception as e:
        logger.error(f"Error submitting SSRS assessment: {str(e)}")
        raise HTTPException(status_code=500, detail="Failed to submit assessment")