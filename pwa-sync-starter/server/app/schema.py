# server/app/schema.py
from __future__ import annotations
import duckdb
from sqlalchemy import Column, String, Integer, Text, DateTime, Boolean
from sqlalchemy.orm import Mapped, mapped_column
from sqlalchemy.ext.declarative import declarative_base

Base = declarative_base()

# DuckDB Schema Definitions
SCHEMA_SQL = [
    """
    CREATE TABLE IF NOT EXISTS programs (
        uuid                  VARCHAR PRIMARY KEY,
        sfid                  VARCHAR UNIQUE,
        name                  VARCHAR NOT NULL,
        last_modified_date    TIMESTAMP
    )
    """,
    """
    CREATE TABLE IF NOT EXISTS participants (
        uuid                       VARCHAR PRIMARY KEY,
        sfid                       VARCHAR UNIQUE,
        first_name                 VARCHAR,
        last_name                  VARCHAR,
        preferred_name             VARCHAR,
        date_of_birth              DATE,
        ssn_last4                  VARCHAR,
        ssn_status                 VARCHAR,            -- 'Partial','Unknown','NotCollected','Complete'
        email                      VARCHAR,
        phone                      VARCHAR,
        profile_complete__c        BOOLEAN DEFAULT FALSE,
        missing_social__c          BOOLEAN DEFAULT TRUE,
        hmis_number                VARCHAR,
        hmis_entered               BOOLEAN,
        updated_at                 TIMESTAMP
    )
    """,
    """
    CREATE TABLE IF NOT EXISTS program_enrollments (
        uuid                  VARCHAR PRIMARY KEY,
        sfid                  VARCHAR UNIQUE,
        program_id            VARCHAR NOT NULL,
        enrollee_id           VARCHAR NOT NULL,
        start_date            DATE,
        end_date              DATE,
        status                VARCHAR,
        entered_hmis          BOOLEAN,
        exited_hmis           BOOLEAN,
        last_modified_date    TIMESTAMP,
        FOREIGN KEY (program_id)     REFERENCES programs(sfid),
        FOREIGN KEY (enrollee_id) REFERENCES participants(sfid)
    )
    """,
    """
    CREATE TABLE IF NOT EXISTS benefit_assignments (
        uuid                      VARCHAR PRIMARY KEY,
        sfid                      VARCHAR UNIQUE,
        enrollee_id               VARCHAR NOT NULL,
        program_enrollment_id     VARCHAR NOT NULL,
        benefit_name              VARCHAR,
        status                    VARCHAR,
        frequency                 VARCHAR,
        amount__c                    DOUBLE,
        balance__c                   DOUBLE,
        last_modified_date             TIMESTAMP,
        FOREIGN KEY (program_enrollment_id) REFERENCES program_enrollments(sfid),
        FOREIGN KEY (enrollee_id)          REFERENCES participants(sfid)
    )
    """,
    """
    CREATE TABLE IF NOT EXISTS disbursement_queue (
        LocalId                 INTEGER PRIMARY KEY,
        uuid                 VARCHAR,
        BenefitAssignmentId     VARCHAR NOT NULL,
        Amount__c               DOUBLE NOT NULL,
        Service_Date__c         DATE NOT NULL,
        Notes__c                VARCHAR,
        Program_Name__c         VARCHAR,
        synced                  BOOLEAN DEFAULT FALSE,
        synced_at                TIMESTAMP,
        FOREIGN KEY (BenefitAssignmentId) REFERENCES benefit_assignments(sfid)
    )
    """,
    """
    CREATE TABLE IF NOT EXISTS notes (
        id                    VARCHAR PRIMARY KEY,
        enrolleeId            VARCHAR,
        body                  TEXT NOT NULL,
        createdAt             VARCHAR NOT NULL,
        updatedAt             VARCHAR NOT NULL,
        deviceId              VARCHAR NOT NULL,
        version               INTEGER DEFAULT 0
    )
    """,
    """
    CREATE TABLE IF NOT EXISTS meta (
        key                   VARCHAR PRIMARY KEY,
        value                 VARCHAR NOT NULL
    )
    """,
    "CREATE INDEX IF NOT EXISTS idx_enroll_status ON program_enrollments(status);",
    "CREATE INDEX IF NOT EXISTS idx_ba_enroll ON benefit_assignments(program_enrollment_id);",
    "CREATE INDEX IF NOT EXISTS idx_dq_ba ON disbursement_queue(BenefitAssignmentId);",
    "CREATE INDEX IF NOT EXISTS idx_notes_version ON notes(version);",
]

# SQLAlchemy Model Definitions (for compatibility)
class Note(Base):
    __tablename__ = 'notes'
    id: Mapped[str] = mapped_column(String, primary_key=True)
    enrolleeId: Mapped[str | None] = mapped_column(String, nullable=True)
    body: Mapped[str] = mapped_column(Text)
    createdAt: Mapped[str] = mapped_column(String)
    updatedAt: Mapped[str] = mapped_column(String)
    deviceId: Mapped[str] = mapped_column(String)
    version: Mapped[int] = mapped_column(Integer, default=0)

class Meta(Base):
    __tablename__ = 'meta'
    key: Mapped[str] = mapped_column(String, primary_key=True)
    value: Mapped[str] = mapped_column(String)

BASELINE_VIEW_SQL = [
    # Active enrollments joined to participants + programs
    """
    CREATE OR REPLACE VIEW baseline_active_enrollments AS
    SELECT
      pe.uuid              AS enrollment_uuid,
      pe.status,
      pe.start_date,
      pe.end_date,

      -- Return UUIDs for the app, but join via SalesforceId FKs
      p.uuid               AS program_uuid,
      p.name                  AS program_name,
      pa.uuid              AS participant_uuid,
      pa.first_name,
      pa.last_name,
      pa.preferred_name

    FROM program_enrollments pe
    JOIN programs     p  ON p.sfid    = pe.program_id
    JOIN participants pa ON pa.sfid   = pe.enrollee_id

    WHERE (pe.status ILIKE 'Active' OR pe.end_date IS NULL OR pe.end_date >= CURRENT_DATE)
    """,

    # Active benefit assignments
    """
    CREATE OR REPLACE VIEW baseline_benefit_assignments AS
    SELECT
      ba.uuid                    AS benefit_assignment_uuid,
      ba.benefit_name,
      ba.status,
      ba.frequency,
      ba.amount__c,
      ba.balance__c,

      -- Resolve UUIDs through the SFID FKs
      pe.uuid                    AS enrollment_uuid,
      pa.uuid                    AS participant_uuid,
      p.uuid                     AS program_uuid

    FROM benefit_assignments ba
    JOIN program_enrollments pe ON pe.sfid  = ba.program_enrollment_id
    JOIN participants      pa ON pa.sfid    = ba.enrollee_id
    JOIN programs          p  ON p.sfid     = pe.program_id

    WHERE (ba.status ILIKE 'Active' OR ba.status IS NULL)
    """
]

def ensure_schema(conn: duckdb.DuckDBPyConnection) -> None:
    for sql in SCHEMA_SQL:
        conn.execute(sql)
    for sql in BASELINE_VIEW_SQL:
        conn.execute(sql)

def reset_database(db_path: str) -> None:
    """Delete and recreate the database with fresh schema"""
    from pathlib import Path
    db_file = Path(db_path)
    if db_file.exists():
        db_file.unlink()
    
    # Create fresh database
    conn = duckdb.connect(db_path)
    ensure_schema(conn)
    conn.close()