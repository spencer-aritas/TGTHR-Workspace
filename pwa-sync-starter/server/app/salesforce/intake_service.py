# server/app/salesforce/intake_service.py
import logging
import json
from typing import Dict, Any, Optional

import requests

from .sf_client import SalesforceClient

logger = logging.getLogger("intake_service")

class IntakeService:
    """Service for processing comprehensive new client intakes"""
    
    def __init__(self):
        self.sf_client = SalesforceClient()
    
    def _reverse_geocode(self, location: Dict[str, Any]) -> Optional[Dict[str, Any]]:
        """Attempt to resolve a latitude/longitude pair into a street address."""
        latitude = location.get('latitude')
        longitude = location.get('longitude')

        try:
            lat = float(latitude) if latitude is not None else None
            lon = float(longitude) if longitude is not None else None
        except (TypeError, ValueError):
            logger.warning(f"Invalid coordinates supplied for reverse geocoding: {latitude}, {longitude}")
            return None

        if lat is None or lon is None:
            return None

        try:
            response = requests.get(
                'https://nominatim.openstreetmap.org/reverse',
                params={
                    'format': 'jsonv2',
                    'lat': lat,
                    'lon': lon,
                    'zoom': 18,
                    'addressdetails': 1
                },
                headers={'User-Agent': 'TGTHR-Intake/1.0 (contact@tgthr.org)'},
                timeout=8
            )
            if response.status_code != 200:
                logger.warning(f"Reverse geocode failed (HTTP {response.status_code}): {response.text[:200]}")
                return None

            data = response.json()
            address = data.get('address') or {}

            street_parts = [
                address.get('house_number'),
                address.get('road') or address.get('pedestrian'),
            ]
            street = " ".join([part for part in street_parts if part])

            city = (
                address.get('city')
                or address.get('town')
                or address.get('village')
                or address.get('hamlet')
                or address.get('municipality')
            )

            return {
                'street': street or address.get('suburb') or address.get('neighbourhood'),
                'city': city,
                'state': address.get('state') or address.get('region'),
                'postalCode': address.get('postcode'),
                'country': address.get('country'),
                'formatted': data.get('display_name'),
            }
        except Exception as exc:
            logger.warning(f"Reverse geocoding exception: {exc}")
            return None

    def _normalize_location(self, location: Any) -> Optional[Dict[str, Any]]:
        """Normalize location payload from the client and enrich with address data."""
        if not isinstance(location, dict):
            return None

        normalized: Dict[str, Any] = {
            'latitude': location.get('latitude'),
            'longitude': location.get('longitude'),
            'accuracy': location.get('accuracy'),
            'altitude': location.get('altitude'),
            'heading': location.get('heading'),
            'speed': location.get('speed'),
            'timestamp': location.get('timestamp'),
            'source': location.get('source') or 'device',
        }

        # Carry through any address information we already have or attempt to resolve it.
        address = location.get('address')
        if isinstance(address, dict):
            normalized['address'] = address
        else:
            resolved = self._reverse_geocode(normalized)
            if resolved:
                normalized['address'] = resolved

        # Provide formatted fallback if supplied by the client.
        formatted = location.get('formattedAddress')
        if formatted and 'address' not in normalized:
            normalized['address'] = {'formatted': formatted}

        return normalized

    def process_full_intake(self, payload: Dict[str, Any]) -> Dict[str, Any]:
        """Process complete new client intake workflow"""
        try:
            logger.info(f"Processing full intake for person: {payload['personUuid']}")

            location_payload = self._normalize_location(payload.get('location'))
            
            # Call the existing ProgramEnrollmentService.ingestEncounter with enhanced data
            encounter_data: Dict[str, Any] = {
                "encounterUuid": payload['encounterUuid'],
                "personUuid": payload['personUuid'],
                "firstName": payload['firstName'],
                "lastName": payload['lastName'],
                "startUtc": payload['startUtc'],
                "endUtc": payload['endUtc'],
                "pos": payload['pos'],
                "isCrisis": payload['isCrisis'],
                "notes": payload['notes'],
                "email": payload.get('email'),
                "phone": payload.get('phone'),
                "birthdate": payload.get('birthdate'),
                "deviceId": payload['deviceId'],
                "createdBy": payload['createdBy'],
                "createdByEmail": payload['createdByEmail'],
            }

            if location_payload:
                encounter_data["location"] = location_payload
            logger.info(
                "Prepared ProgramEnrollmentService payload: encounterUuid=%s personUuid=%s hasLocation=%s createdBy=%s",
                encounter_data.get("encounterUuid"),
                encounter_data.get("personUuid"),
                bool(encounter_data.get("location")),
                encounter_data.get("createdBy"),
            )
            try:
                logger.debug(
                    "ProgramEnrollmentService payload body: %s",
                    json.dumps(encounter_data, default=str, sort_keys=True),
                )
            except TypeError as serialization_error:
                logger.debug(
                    "ProgramEnrollmentService payload serialization failed: %s",
                    serialization_error,
                )
            
            # Make REST call to enhanced ProgramEnrollmentService
            response = self.sf_client.call_apex_rest(
                'ProgramEnrollmentService',
                encounter_data
            )
            
            if response.get('success'):
                logger.info(f"Successfully processed intake: {response}")
                return {
                    'personAccountId': response.get('accountId'),
                    'programEnrollmentId': response.get('enrollmentId'),
                    'benefitAssignmentIds': response.get('benefitAssignmentIds', []),
                    'interactionSummaryId': response.get('interactionSummaryId'),
                    'taskId': response.get('taskId')
                }
            else:
                raise Exception(f"Salesforce processing failed: {response}")
                
        except Exception as e:
            logger.error(f"Failed to process full intake: {e}")
            raise

def process_full_intake(payload: Dict[str, Any]) -> Dict[str, Any]:
    """Standalone function for processing full intake"""
    service = IntakeService()
    return service.process_full_intake(payload)
