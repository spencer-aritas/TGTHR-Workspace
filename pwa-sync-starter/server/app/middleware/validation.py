"""
server/app/middleware/validation.py

Input validation models and utilities for API endpoints.
These models use Pydantic v2 for strict runtime validation.
"""

from pydantic import BaseModel, field_validator, Field, ValidationError, model_validator
from typing import Optional, Dict, Any, List, Literal
from datetime import datetime
import re
import logging

logger = logging.getLogger("validation")


# ==================== MUTATION VALIDATION ====================

class SyncMutationValidated(BaseModel):
    """
    Strictly validated sync mutation model.
    All fields must conform to expected formats and sizes.
    """
    id: str = Field(..., min_length=36, max_length=36, description="UUID format")
    table: str = Field(..., description="Table name")
    op: str = Field(..., description="Operation type")
    payload: Dict[str, Any] = Field(..., description="Mutation payload")
    clientTs: str = Field(..., description="Client timestamp (ISO 8601)")
    deviceId: str = Field(..., min_length=20, description="Device identifier")
    
    @field_validator('table')
    @classmethod
    def validate_table(cls, v):
        if v not in ('notes', 'interactions'):
            raise ValueError('table must be "notes" or "interactions"')
        return v
    
    @field_validator('op')
    @classmethod
    def validate_op(cls, v):
        if v not in ('insert', 'update', 'delete'):
            raise ValueError('op must be "insert", "update", or "delete"')
        return v

    @field_validator('clientTs')
    @classmethod
    def validate_timestamp(cls, v):
        """Validate ISO 8601 timestamp format"""
        try:
            # Accept both formats: 2025-01-01T00:00:00Z and 2025-01-01T00:00:00+00:00
            datetime.fromisoformat(v.replace('Z', '+00:00'))
            return v
        except (ValueError, AttributeError):
            raise ValueError(f"Invalid ISO 8601 timestamp: {v}")

    @field_validator('payload')
    @classmethod
    def validate_payload_size(cls, v):
        """Prevent oversized payloads (DoS protection)"""
        import json
        payload_size = len(json.dumps(v).encode('utf-8'))
        if payload_size > 100000:  # 100 KB limit per mutation
            raise ValueError(f"Payload too large: {payload_size} bytes (max 100KB)")
        return v

    class Config:
        json_schema_extra = {
            "example": {
                "id": "550e8400-e29b-41d4-a716-446655440000",
                "table": "notes",
                "op": "insert",
                "payload": {
                    "id": "note-123",
                    "enrolleeId": "enrollee-456",
                    "body": "Clinical notes...",
                    "createdAt": "2025-01-01T12:00:00Z",
                    "updatedAt": "2025-01-01T12:00:00Z",
                    "deviceId": "device-uuid-12345678901234567890"
                },
                "clientTs": "2025-01-01T12:00:00Z",
                "deviceId": "device-uuid-12345678901234567890"
            }
        }


class NotePayload(BaseModel):
    """Validated note data payload"""
    id: str = Field(..., min_length=1, max_length=100, description="Note ID")
    enrolleeId: str = Field(..., min_length=1, max_length=100, description="Enrollee ID")
    body: str = Field(..., min_length=0, max_length=50000, description="Note content")
    createdAt: str = Field(..., description="Creation timestamp (ISO 8601)")
    updatedAt: str = Field(..., description="Update timestamp (ISO 8601)")
    deviceId: str = Field(..., min_length=20, description="Device ID")

    @field_validator('body')
    @classmethod
    def validate_body_not_malicious(cls, v):
        """Basic validation that body doesn't contain obvious attack patterns"""
        if not v:
            return v
        
        # Check for excessive special characters (potential injection)
        special_char_ratio = sum(1 for c in v if not c.isalnum() and c not in ' \n\t.,:;!?-') / len(v)
        if special_char_ratio > 0.5:  # More than 50% special chars is suspicious
            raise ValueError("Note body contains too many special characters")
        
        return v


class InteractionPayload(BaseModel):
    """Validated interaction/encounter data payload"""
    id: str = Field(..., min_length=1, max_length=100)
    caseId: str = Field(..., min_length=1, max_length=100)
    encounterDate: str = Field(..., description="ISO 8601 date")
    interactionType: str = Field(..., description="Type of interaction")
    notes: str = Field(..., max_length=50000)
    minutesSpent: int = Field(..., ge=0, le=480)  # Max 8 hours per interaction
    deviceId: str = Field(..., min_length=20)

    @field_validator('interactionType')
    @classmethod
    def validate_interaction_type(cls, v):
        if v not in ('Clinical', 'CaseManagement', 'Outreach', 'Other'):
            raise ValueError('interactionType must be one of: Clinical, CaseManagement, Outreach, Other')
        return v

    @field_validator('encounterDate')
    @classmethod
    def validate_encounter_date(cls, v):
        """Validate date is not in future"""
        try:
            encounter = datetime.fromisoformat(v.replace('Z', '+00:00'))
            if encounter > datetime.now(encounter.tzinfo):
                raise ValueError("Encounter date cannot be in the future")
            return v
        except (ValueError, AttributeError) as e:
            raise ValueError(f"Invalid encounter date: {str(e)}")


# ==================== UTILITY FUNCTIONS ====================

def validate_mutation_list(mutations: List[Dict[str, Any]]) -> tuple[List[SyncMutationValidated], List[str]]:
    """
    Validate list of mutations, returning valid mutations and error summaries.
    
    Args:
        mutations: List of mutation dictionaries from client
    
    Returns:
        Tuple of (valid_mutations, error_messages)
        
    Example:
        valid, errors = validate_mutation_list(raw_mutations)
        if errors:
            logger.warning(f"Validation errors: {errors}")
        # Process valid mutations
    """
    valid_mutations = []
    error_messages = []

    for idx, mutation in enumerate(mutations):
        try:
            validated = SyncMutationValidated(**mutation)
            
            # Additional payload validation based on table type
            if validated.table == 'notes':
                try:
                    NotePayload(**validated.payload)
                except ValidationError as e:
                    error_messages.append(f"Mutation {idx}: Invalid note payload - {e.error_count()} errors")
                    continue
            
            elif validated.table == 'interactions':
                try:
                    InteractionPayload(**validated.payload)
                except ValidationError as e:
                    error_messages.append(f"Mutation {idx}: Invalid interaction payload - {e.error_count()} errors")
                    continue
            
            valid_mutations.append(validated)
            
        except ValidationError as e:
            error_msg = f"Mutation {idx}: {e.error_count()} validation errors"
            logger.warning(error_msg)
            error_messages.append(error_msg)

    return valid_mutations, error_messages


def get_validation_errors_user_friendly(validation_error: ValidationError) -> str:
    """
    Convert Pydantic ValidationError to user-friendly message without exposing internals.
    
    Args:
        validation_error: Pydantic ValidationError
    
    Returns:
        Safe user-facing error message
    """
    error_count = validation_error.error_count()
    return f"Input validation failed ({error_count} error{'s' if error_count != 1 else ''}). Please check your data and try again."
