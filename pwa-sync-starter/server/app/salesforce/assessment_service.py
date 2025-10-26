import json
import logging
from datetime import date, timedelta
from typing import Any, Dict, Optional

from .sf_client import SalesforceClient

logger = logging.getLogger("assessment_service")

# Map PWA contract keys -> Assessment__c field API names
FIELD_MAP: Dict[str, str] = {
    # Ideation - Lifetime / Past Month
    "wishDeadPastMonth": "Wish_to_be_Dead_Past_Month__c",
    "wishDeadLifetimeDesc": "Wish_to_be_Dead_Description__c",
    "suicidalThoughtsLifetime": "Non_Specific_Active_Suicidal_Thoughts__c",
    "suicidalThoughtsLifetimeDesc": "Non_Specific_Active_Thoughts_Description__c",
    "suicidalThoughtsPastMonth": "Non_Specific_Thoughts_Past_Month__c",
    "methodsLifetime": "Active_Ideation_No_Plan_No_Intent__c",
    "methodsLifetimeDesc": "No_Plan_No_Intent_Description__c",
    "intentLifetime": "Active_Ideation_Some_Intent_No_Plan__c",
    "intentLifetimeDesc": "Some_Intent_No_Plan_Description__c",
    "planLifetime": "Active_Ideation_Plan_Intent__c",
    "planLifetimeDesc": "Active_Plan_Intent_Description__c",
    "planPastMonth": "Active_Plan_Intent_Past_Month__c",
    "intentPastMonth": "Some_Intent_No_Plan_Past_Month__c",
    "methodsPastMonth": "No_Plan_No_Intent_Past_month__c",

    # Intensity details
    "lifetimeMostSevereType": "Lifetime_Most_Severe_Ideation__c",
    "lifetimeMostSevereDesc": "Lifetime_Most_Severe_Description__c",
    "recentMostSevereType": "Recent_Most_Severe_Ideation__c",
    "recentMostSevereDesc": "Recent_Most_Severe_Description__c",
    "frequencyLifetime": "Frequency__c",
    "durationLifetime": "Duration_of_Thoughts__c",
    "controllabilityLifetime": "Controllability_of_Thoughts__c",
    "deterrentsLifetime": "Deterrents_from_Acting__c",
    "reasonsLifetime": "Reason_for_Ideation__c",

    # Behavior lifetime / past 3 months
    "actualAttemptLifetime": "Actual_Attempt_Lifetime__c",
    "actualAttemptLifetimeCount": "Total_Number_of_Attempts_Lifetime__c",
    "actualAttemptPast3Months": "Actual_Attempt_Past_3_Months__c",
    "actualAttemptPast3MonthsCount": "Total_Number_of_Attempts_Past_3_Months__c",
    "interruptedAttemptLifetime": "Interrupted_Attempt_Lifetime__c",
    "interruptedAttemptLifetimeDesc": "Interrupted_Attempts_Description__c",
    "interruptedAttemptLifetimeCount": "Total_Interrupted_Attempts_Lifetime__c",
    "interruptedAttemptPast3Months": "Interrupted_Attempt_Past_3_months__c",
    "interruptedAttemptPast3MonthsCount": "Total_Interrupted_Attempts_3_Months__c",
    "abortedAttemptLifetime": "Aborted_Attempt_Lifetime__c",
    "abortedAttemptLifetimeCount": "Total_Aborted_Lifetime__c",
    "abortedAttemptPast3Months": "Aborted_Attempt_Past_3_Months__c",
    "abortedAttemptPast3MonthsCount": "Total_Attempts_Aborted_Past_3_Months__c",
    "preparatoryActsLifetime": "Preparatory_Acts_Lifetime__c",
    "preparatoryActsLifetimeCount": "Total_Preparatory_Acts_Lifetime__c",
    "preparatoryActsPast3Months": "Preparatory_Acts_Past_3_Months__c",
    "preparatoryActsPast3MonthsCount": "Total_Preparatory_Acts_Past_3_Months__c",
    "nonSuicidalSelfInjuryLifetime": "Non_Suicidal_Self_Injurious_Harm__c",

    # Attempt details
    "firstAttemptDate": "First_Attempt_Date__c",
    "firstAttemptLethality": "First_Attempt_Lethality__c",
    "firstAttemptPotentialLethality": "First_Attempt_Potential_Lethality__c",
    "mostRecentAttemptDate": "Most_Recent_Attempt_Date__c",
    "mostRecentAttemptLethality": "Most_Recent_Actual_Lethality__c",
    "mostRecentAttemptPotentialLethality": "Most_Recent_Potential_Lethality__c",
    "mostLethalAttemptDate": "Most_Lethal_Attempt_Date__c",
    "mostLethalAttemptLethality": "Most_Lethal_Actual_Lethality__c",
    "mostLethalAttemptPotentialLethality": "Most_Lethal_Potential_Lethality__c",
    "dangerResultingInDeath": "Danger_Resulting_in_Death__c",
        "dangerResultingInDeathDesc": "Danger_Resulting_in_Death_Description__c",
}

ASSESSMENT_TYPE_VALUE = "Suicidal Ideation"

FREQUENCY_OPTIONS = {
    1: "Less than once a week",
    2: "Once a week",
    3: "2-5 times a week",
    4: "Daily or almost daily",
    5: "Many times each day",
}

DURATION_OPTIONS = {
    1: "Fleeting - few seconds or minutes",
    2: "Less than 1 hour/some of the time",
    3: "1-4 hours/a lot of the time",
    4: "4-8 hours/most of the day",
    5: "More than 8 hours/persistent or continuous",
}

CONTROLLABILITY_OPTIONS = {
    1: "Easily able to control thoughts",
    2: "Can control thoughts with little difficulty",
    3: "Can control thoughts with some difficulty",
    4: "Can control thoughts with a lot of difficulty",
    5: "Unable to control thoughts",
    0: "Does not attempt to control thoughts",
}

DETERRENT_OPTIONS = {
    1: "Deterrents definitely stopped you from attempting suicide",
    2: "Deterrents probably stopped you",
    3: "Uncertain that deterrents stopped you",
    4: "Deterrents most likely did not stop you",
    5: "Deterrents definitely did not stop you",
    0: "Does not apply",
}

REASON_OPTIONS = {
    1: "Completely to get attention, revenge or a reaction from others",
    2: "Mostly to get attention, revenge or a reaction from others",
    3: "Equally to get attention, revenge or a reaction from others, and to end/stop the pain",
    4: "Mostly to end or stop the pain (you couldn't go on living with the pain or how you were feeling)",
    5: "Completely to end or stop the pain (you couldn't go on living with the pain or how you were feeling)",
    0: "Does not apply",
}

PICKLIST_VALUE_MAPS: Dict[str, Dict[int, str]] = {
    "Frequency__c": FREQUENCY_OPTIONS,
    "Duration_of_Thoughts__c": DURATION_OPTIONS,
    "Controllability_of_Thoughts__c": CONTROLLABILITY_OPTIONS,
    "Deterrents_from_Acting__c": DETERRENT_OPTIONS,
    "Reason_for_Ideation__c": REASON_OPTIONS,
}


class AssessmentServiceClient:
    """Maps SSRS assessment payloads to Assessment__c and creates records in Salesforce."""

    def __init__(self):
        self.sf_client = SalesforceClient()
        self._assessment_fields: Optional[Dict[str, Dict[str, Any]]] = None

    def _get_assessment_fields(self) -> Dict[str, Dict[str, Any]]:
        if self._assessment_fields is None:
            desc = self.sf_client.describe("Assessment__c")
            self._assessment_fields = {f["name"]: f for f in desc.get("fields", [])}
        return self._assessment_fields

    def _field_exists(self, api_name: str) -> bool:
        return api_name in self._get_assessment_fields()

    def build_field_payload(self, assessment_data: Dict[str, Any]) -> Dict[str, Any]:
        """Translate SSRSAssessmentData keys to Assessment__c fields, respecting org schema."""
        payload: Dict[str, Any] = {}
        clean_data = {k: v for k, v in assessment_data.items() if v is not None}

        for source_key, field_name in FIELD_MAP.items():
            if source_key not in clean_data:
                continue
            if not self._field_exists(field_name):
                continue
            payload[field_name] = self._normalize_picklist_value(field_name, clean_data[source_key])

        return payload

    def _merge_description_fields(self, record: Dict[str, Any], assessment_data: Dict[str, Any]) -> None:
        """Combine lifetime/past period descriptions into single Salesforce rich text fields."""
        combos = [
            ("Wish_to_be_Dead_Description__c", "wishDeadLifetimeDesc", "wishDeadPastMonthDesc"),
            ("Non_Specific_Active_Thoughts_Description__c", "suicidalThoughtsLifetimeDesc", "suicidalThoughtsPastMonthDesc"),
            ("No_Plan_No_Intent_Description__c", "methodsLifetimeDesc", "methodsPastMonthDesc"),
            ("Some_Intent_No_Plan_Description__c", "intentLifetimeDesc", "intentPastMonthDesc"),
            ("Active_Plan_Intent_Description__c", "planLifetimeDesc", "planPastMonthDesc"),
        ]

        for field_name, lifetime_key, recent_key in combos:
            if not self._field_exists(field_name):
                continue
            lifetime_text = assessment_data.get(lifetime_key)
            recent_text = assessment_data.get(recent_key)
            if not lifetime_text and not recent_text:
                continue

            sections = []
            if lifetime_text:
                sections.append(f"Lifetime:\n{lifetime_text.strip()}")
            if recent_text:
                sections.append(f"Recent/Past Month:\n{recent_text.strip()}")

            record[field_name] = "\n\n".join(sections)

    def create_assessment(
        self,
        *,
        account_id: str,
        case_id: Optional[str],
        assessment_date: str,
        assessed_by_id: Optional[str],
        assessment_fields: Dict[str, Any],
        total_score: Optional[int],
        risk_level: str,
        raw_payload: Dict[str, Any],
    ) -> str:
        """Insert the Assessment__c record and return its Id."""
        record: Dict[str, Any] = {
            "Participant__c": account_id,
            "Assessment_Type__c": ASSESSMENT_TYPE_VALUE,
            "Assessment_Date__c": assessment_date,
            "Status__c": "Completed",
        }

        if case_id:
            record["Case__c"] = case_id
        if assessed_by_id:
            record["Assessed_By__c"] = assessed_by_id

        record.update(assessment_fields)
        self._apply_additional_field_logic(record, raw_payload)
        self._merge_description_fields(record, raw_payload)

        if total_score is not None and self._field_exists("Total_Score__c"):
            record["Total_Score__c"] = total_score
        if self._field_exists("Risk_Level__c"):
            record["Risk_Level__c"] = risk_level
        if self._field_exists("Response_Data__c"):
            record["Response_Data__c"] = json.dumps(raw_payload)

        logger.info("Creating Assessment__c for account %s (case %s)", account_id, case_id)
        result = self.sf_client.create("Assessment__c", record)
        return result.get("id") or result.get("Id")

    def _normalize_picklist_value(self, field_name: str, raw_value: Any) -> Any:
        if field_name not in PICKLIST_VALUE_MAPS:
            return raw_value
        mapping = PICKLIST_VALUE_MAPS[field_name]
        if raw_value is None:
            return None
        if isinstance(raw_value, str):
            if raw_value in mapping.values():
                return raw_value
            try:
                raw_value = int(raw_value)
            except ValueError:
                return raw_value
        if isinstance(raw_value, (int, float)):
            return mapping.get(int(raw_value), raw_value)
        return str(raw_value)

    def _apply_additional_field_logic(self, record: Dict[str, Any], data: Dict[str, Any]) -> None:
        self._apply_fallback_value(record, data, "Frequency__c", "frequencyLifetime", "frequencyRecent")
        self._apply_fallback_value(
            record, data, "Duration_of_Thoughts__c", "durationLifetime", "durationRecent"
        )
        self._apply_fallback_value(
            record, data, "Controllability_of_Thoughts__c", "controllabilityLifetime", "controllabilityRecent"
        )
        self._apply_fallback_value(
            record, data, "Deterrents_from_Acting__c", "deterrentsLifetime", "deterrentsRecent"
        )
        self._apply_fallback_value(
            record, data, "Reason_for_Ideation__c", "reasonsLifetime", "reasonsRecent"
        )
        self._apply_boolean_or(
            record,
            data,
            "Non_Suicidal_Self_Injurious_Harm__c",
            "nonSuicidalSelfInjuryLifetime",
            "nonSuicidalSelfInjuryPast3Months",
        )

    def _apply_fallback_value(
        self,
        record: Dict[str, Any],
        data: Dict[str, Any],
        field_name: str,
        primary_key: str,
        secondary_key: str,
    ) -> None:
        if field_name in record:
            return
        for key in (primary_key, secondary_key):
            if key in data and data[key] is not None:
                record[field_name] = self._normalize_picklist_value(field_name, data[key])
                return

    def _apply_boolean_or(
        self,
        record: Dict[str, Any],
        data: Dict[str, Any],
        field_name: str,
        primary_key: str,
        secondary_key: str,
    ) -> None:
        primary = data.get(primary_key)
        secondary = data.get(secondary_key)
        if primary is None and secondary is None:
            return
        record[field_name] = bool(primary) or bool(secondary)

    def create_follow_up_task(
        self,
        *,
        case_id: Optional[str],
        risk_level: str,
        recommendations: list[str],
    ) -> bool:
        """Create a Salesforce Task for moderate/high risk assessments."""
        if risk_level not in ("Moderate", "High", "Imminent"):
            return False
        if not case_id:
            logger.warning("Skipping follow-up task because caseId is missing.")
            return False

        due_days = 1 if risk_level == "High" or risk_level == "Imminent" else 7
        activity_date = date.today() + timedelta(days=due_days)

        description_lines = [
            f"Risk Level: {risk_level}",
            "",
            "Recommendations:",
            *recommendations,
        ]
        payload = {
            "WhatId": case_id,
            "Subject": f"SSRS Assessment Follow-up - {risk_level} Risk",
            "Description": "\n".join(description_lines),
            "Priority": "High" if risk_level in ("High", "Imminent") else "Normal",
            "Status": "Not Started",
            "ActivityDate": activity_date.isoformat(),
        }

        logger.info("Creating follow-up task for case %s (%s risk)", case_id, risk_level)
        self.sf_client.create("Task", payload)
        return True
