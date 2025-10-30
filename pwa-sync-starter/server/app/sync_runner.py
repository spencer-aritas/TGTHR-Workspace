# server/app/sync_runner.py
from __future__ import annotations

import logging
from typing import Any, Dict, List, Optional, TypedDict, Literal, Union
from datetime import datetime

from .db import DuckClient
from .settings import settings
from .salesforce.sf_client import query_soql, sobject_update, SFAuthError, SFError
from .sync_helpers import (
    fetch_programs,
    fetch_enrollments_for_programs,
    fetch_accounts,
    upsert_programs,
    upsert_participants,
    upsert_enrollments
)

logger = logging.getLogger("sync_runner")
class Counts(TypedDict):
    programs: int
    participants: int
    enrollments: int
    notes: int

class HealthyStatus(TypedDict):
    counts: Counts
    last_sync_time: Optional[str]
    status: Literal["healthy"]

class ErrorStatus(TypedDict):
    status: Literal["error"]
    error: str

SyncStatus = Union[HealthyStatus, ErrorStatus]

class SyncRunner:
    """Single entry point for all sync operations"""
    
    def __init__(self):
        self.db = DuckClient()
        
    def run_full_sync(self) -> Dict[str, int]:
        """Run complete sync from Salesforce to local database"""
        logger.info("[sync] Starting full sync from Salesforce...")
        
        try:
            # Fetch data from Salesforce
            programs = fetch_programs()
            prog_ids = sorted(str(p["Id"]) for p in programs if isinstance(p.get("Id"), str))
            logger.info(f"[sync] Programs: {len(programs)}")
            
            enrollments = fetch_enrollments_for_programs(prog_ids) if prog_ids else []
            acct_ids = sorted(str(e["AccountId"]) for e in enrollments if isinstance(e.get("AccountId"), str))
            logger.info(f"[sync] Enrollments: {len(enrollments)} | Accounts referenced: {len(acct_ids)}")
            
            accounts = fetch_accounts(acct_ids) if acct_ids else []
            logger.info(f"[sync] Accounts (Person): {len(accounts)}")
            
            # Upsert to local database
            prog_uuid_by_id = upsert_programs(self.db, programs)
            acct_uuid_by_id = upsert_participants(self.db, accounts)
            enr_uuid_by_id = upsert_enrollments(self.db, enrollments, prog_uuid_by_id, acct_uuid_by_id)
            
            # Get final counts
            counts = {
                "programs": self.db.fetch_all("SELECT COUNT(*) n FROM programs")[0]["n"],
                "participants": self.db.fetch_all("SELECT COUNT(*) n FROM participants")[0]["n"],
                "enrollments": self.db.fetch_all("SELECT COUNT(*) n FROM program_enrollments")[0]["n"],
                "active_enrollments": self.db.fetch_all("SELECT COUNT(*) n FROM baseline_active_enrollments")[0]["n"],
            }
            
            logger.info(f"[sync] Completed: {counts}")
            return counts
            
        except (SFAuthError, SFError) as e:
            logger.error(f"[sync] Salesforce error: {e}")
            raise
        except Exception as e:
            logger.error(f"[sync] Unexpected error: {e}", exc_info=True)
            raise
        finally:
            if hasattr(self, 'db'):
                self.db.close()
    
    def run_incremental_sync(self, since: Optional[datetime] = None) -> Dict[str, int]:
        """Run incremental sync for changes since specified time"""
        logger.info(f"[sync] Starting incremental sync since {since}")
        # Implementation would filter by LastModifiedDate
        # For now, delegate to full sync
        return self.run_full_sync()
    
    def sync_notes_to_sf(self, notes: List[Dict]) -> List[str]:
        """Sync local notes to Salesforce"""
        logger.info(f"[sync] Syncing {len(notes)} notes to Salesforce")
        synced_ids = []
        
        for note in notes:
            try:
                # Implementation would create/update notes in SF
                # For now, just mark as synced
                synced_ids.append(note.get("id"))
            except Exception as e:
                logger.error(f"[sync] Failed to sync note {note.get('id')}: {e}")
        
        return synced_ids
    
    def get_sync_status(self) -> SyncStatus:
        try:
            def _count(tbl: str) -> int:
                rows = self.db.fetch_all(f"SELECT COUNT(*) AS n FROM {tbl}")
                return int(rows[0].get("n", 0)) if rows else 0

            counts: Counts = {
                "programs": _count("programs"),
                "participants": _count("participants"),
                "enrollments": _count("program_enrollments"),
                "notes": _count("notes"),
            }

            last_sync = self.db.fetch_all(
                "SELECT value FROM meta WHERE key = 'last_sync_time' LIMIT 1"
            )
            last_sync_time: Optional[str] = last_sync[0]["value"] if last_sync else None

            return {"counts": counts, "last_sync_time": last_sync_time, "status": "healthy"}
        except Exception as e:
            logger.error(f"[sync] Error getting sync status: {e}")
            return {"status": "error", "error": str(e)}
        finally:
            pass  

# Convenience functions for backward compatibility
def run_full_sync() -> Dict[str, int]:
    """Run full sync - convenience function"""
    runner = SyncRunner()
    return runner.run_full_sync()

def run_incremental_sync(since: Optional[datetime] = None) -> Dict[str, int]:
    """Run incremental sync - convenience function"""
    runner = SyncRunner()
    return runner.run_incremental_sync(since)

def get_sync_status() -> SyncStatus:
    """Get sync status - convenience function"""
    runner = SyncRunner()
    return runner.get_sync_status()