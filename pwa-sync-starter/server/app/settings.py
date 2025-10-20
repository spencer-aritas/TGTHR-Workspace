# server/app/settings.py
from __future__ import annotations
from typing import Optional, Literal, List
from pathlib import Path
import os

from dotenv import load_dotenv
from pydantic_settings import BaseSettings, SettingsConfigDict

# Load env from both places; server/.env overrides root/.env
_SERVER_DIR = Path(__file__).resolve().parents[1]  # .../server
_ROOT_DIR = _SERVER_DIR.parent                      # .../pwa-sync-starter
load_dotenv(_ROOT_DIR / ".env", override=False, encoding="utf-8")
load_dotenv(_SERVER_DIR / ".env", override=True,  encoding="utf-8")

class Settings(BaseSettings):
    # Environment selection
    SF_ENV: Literal["benefits", "prod"] = "benefits"
    
    # Database configuration
    DB_PATH: str = "data/app.duckdb"
    SQLITE_DB_PATH: str = "./server.db"
    
    # Sync configuration  
    PROGRAM_NAMES: List[str] = ["1440 Pine", "Nest 56"]
    WRITE_MISSING_UUIDS: bool = False
    
    def __init__(self, **kwargs):
        super().__init__(**kwargs)
        # Parse PROGRAM_NAMES from env if it's a string
        if isinstance(self.PROGRAM_NAMES, str):
            import json
            try:
                self.PROGRAM_NAMES = json.loads(self.PROGRAM_NAMES)
            except json.JSONDecodeError:
                # Fallback to comma-separated parsing
                self.PROGRAM_NAMES = [name.strip().strip('"') for name in self.PROGRAM_NAMES.strip('[]').split(',')]
    
    # Scheduler configuration
    SYNC_SCHEDULE_HOUR: int = 2
    SYNC_SCHEDULE_MINUTE: int = 0
    TIMEZONE: str = "America/Denver"

    # Salesforce sandbox keys
    SF_BENEFITS_JWT_CONSUMER_KEY: Optional[str] = None
    SF_BENEFITS_JWT_USERNAME: Optional[str] = None
    SF_BENEFITS_JWT_LOGIN_URL: Optional[str] = None
    SF_BENEFITS_JWT_PRIVATE_KEY_PATH: Optional[str] = None

    # Salesforce prod keys
    SF_PROD_JWT_CONSUMER_KEY: Optional[str] = None
    SF_PROD_JWT_USERNAME: Optional[str] = None
    SF_PROD_JWT_LOGIN_URL: Optional[str] = None
    SF_PROD_JWT_PRIVATE_KEY_PATH: Optional[str] = None

    # Salesforce shared settings
    SALESFORCE_API_VERSION: str = "v61.0"
    SALESFORCE_PERSON_ACCOUNT_RECORD_TYPE_ID: Optional[str] = None

    
    # Salesforce object names
    SF_PROGRAM_OBJECT: str = "Program"
    SF_PROGRAM_ENROLLMENT_OBJECT: str = "ProgramEnrollment"
    SF_ACCOUNT_OBJECT: str = "Account"
    SF_BENEFIT_ASSIGNMENT_OBJECT: str = "BenefitAssignment"
    
    # Salesforce field mappings
    SF_PROGRAM_FIELDS: List[str] = ["Id", "Name", "UUID__c", "LastModifiedDate"]
    SF_PROGRAM_ENROLLMENT_FIELDS: List[str] = [
        "Id", "UUID__c", "ProgramId", "AccountId",
        "StartDate", "EndDate", "Status",
        "Entered_into_HMIS__c", "Exited_from_HMIS__c",
        "LastModifiedDate"
    ]
    SF_ACCOUNT_FIELDS: List[str] = [
        "Id", "IsPersonAccount",
        "PersonFirstName", "PersonLastName",
        "PersonBirthdate", "PersonEmail", "Phone",
        "UUID__c", "LastModifiedDate"
    ]

    # pydantic-settings v2
    model_config = SettingsConfigDict(extra="ignore")

    # --- normalized properties used by sf_client.py ---
    @property
    def SALESFORCE_CLIENT_ID(self) -> str:
        return (self.SF_BENEFITS_JWT_CONSUMER_KEY if self.SF_ENV == "benefits"
                else self.SF_PROD_JWT_CONSUMER_KEY) or ""

    @property
    def SALESFORCE_USERNAME(self) -> str:
        return (self.SF_BENEFITS_JWT_USERNAME if self.SF_ENV == "benefits"
                else self.SF_PROD_JWT_USERNAME) or ""

    @property
    def SALESFORCE_PRIVATE_KEY_PATH(self) -> str:
        return (self.SF_BENEFITS_JWT_PRIVATE_KEY_PATH if self.SF_ENV == "benefits"
                else self.SF_PROD_JWT_PRIVATE_KEY_PATH) or ""

    @property
    def SALESFORCE_LOGIN_URL(self) -> str:
        raw = (self.SF_BENEFITS_JWT_LOGIN_URL if self.SF_ENV == "benefits"
               else self.SF_PROD_JWT_LOGIN_URL) or ""
        # For JWT bearer, token host must be test/login, not My Domain
        if "my.salesforce.com" in raw or "lightning.force.com" in raw:
            return "https://test.salesforce.com" if self.SF_ENV == "benefits" else "https://login.salesforce.com"
        return raw or ("https://test.salesforce.com" if self.SF_ENV == "benefits" else "https://login.salesforce.com")
    
    @property
    def TGTHR_DB_PATH(self) -> str:
        return os.environ.get("TGTHR_DB_PATH", self.DB_PATH)
    
    @property
    def TGTHR_WRITE_MISSING_UUIDS(self) -> bool:
        return os.getenv("TGTHR_WRITE_MISSING_UUIDS") == "1" or self.WRITE_MISSING_UUIDS

settings = Settings()

# Optional: quick debug if you still have issues
if os.getenv("DEBUG_SETTINGS") == "1":
    print("SF_ENV:", settings.SF_ENV)
    print("CLIENT_ID present:", bool(settings.SALESFORCE_CLIENT_ID))
    print("USERNAME present:", bool(settings.SALESFORCE_USERNAME))
    print("KEY PATH:", settings.SALESFORCE_PRIVATE_KEY_PATH)
    print("DB_PATH:", settings.TGTHR_DB_PATH)
