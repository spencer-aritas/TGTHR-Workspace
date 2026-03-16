# server/app/sync_runner.py
from __future__ import annotations

import json
import logging
import threading
import time
import uuid
from typing import Any, Dict, List, Optional, TypedDict, Literal, Union
from datetime import datetime, timezone

from .db import DuckClient
from .settings import settings
from .salesforce.sf_client import SFAuthError, SFError
from .sync_helpers import (
    fetch_programs,
    fetch_enrollments_for_programs_chunked,
    fetch_accounts,
    upsert_programs,
    upsert_participants,
    upsert_enrollments
)

logger = logging.getLogger("sync_runner")
_RUN_LOCK = threading.Lock()


def is_sync_running() -> bool:
    return _RUN_LOCK.locked()


def _local_cache_empty() -> bool:
    db = DuckClient()
    try:
        participants = int(db.fetch_all("SELECT COUNT(*) AS n FROM participants")[0]["n"])
        enrollments = int(db.fetch_all("SELECT COUNT(*) AS n FROM program_enrollments")[0]["n"])
        return participants == 0 and enrollments == 0
    finally:
        db.close()


def run_initial_sync_if_needed() -> None:
    """Run a bounded startup sync when local cache is empty."""
    if not settings.SYNC_INITIAL_SYNC_ON_STARTUP:
        logger.info("[startup-sync] disabled by configuration")
        return

    try:
        if not _local_cache_empty():
            logger.info("[startup-sync] local cache not empty, skipping initial sync")
            return
    except Exception as e:
        logger.warning("[startup-sync] failed to check local cache state: %s", e)
        return

    max_retries = max(1, int(settings.SYNC_INITIAL_SYNC_MAX_RETRIES))
    retry_delay = max(1, int(settings.SYNC_INITIAL_SYNC_RETRY_DELAY_SECONDS))

    logger.info("[startup-sync] local cache empty, attempting initial sync (max_retries=%s)", max_retries)
    for attempt in range(1, max_retries + 1):
        try:
            result = run_full_sync()
            logger.info("[startup-sync] initial sync succeeded on attempt %s: %s", attempt, result)
            return
        except RuntimeError as e:
            logger.warning("[startup-sync] attempt %s skipped: %s", attempt, e)
        except Exception as e:
            logger.error("[startup-sync] attempt %s failed: %s", attempt, e, exc_info=True)

        if attempt < max_retries:
            time.sleep(retry_delay)

    logger.error("[startup-sync] exhausted retries without successful initial sync")


class Counts(TypedDict):
    programs: int
    participants: int
    enrollments: int
    notes: int

class HealthyStatus(TypedDict):
    counts: Counts
    last_sync_time: Optional[str]
    last_sync_status: Optional[str]
    last_sync_run_id: Optional[str]
    last_sync_started_at: Optional[str]
    last_sync_duration_ms: Optional[int]
    last_sync_counts: Dict[str, int]
    last_sync_timings_ms: Dict[str, int]
    last_sync_error: Optional[str]
    is_sync_stale: bool
    stale_threshold_hours: int
    last_success_age_hours: Optional[float]
    sync_health: Literal["ok", "stale", "error", "unknown"]
    has_synced_once: bool
    sync_running: bool
    data_scope: Literal["local_cache"]
    program_filters: List[str]
    status: Literal["healthy"]

class ErrorStatus(TypedDict):
    status: Literal["error"]
    error: str

SyncStatus = Union[HealthyStatus, ErrorStatus]

class SyncRunner:
    """Single entry point for all sync operations"""
    
    def __init__(self):
        self.db = DuckClient()

    def _upsert_meta(self, key: str, value: str) -> None:
        self.db.execute(
            """
            INSERT OR REPLACE INTO meta (key, value)
            VALUES (?, ?)
            """,
            (key, value),
        )

    def _persist_sync_success(
        self,
        run_id: str,
        started_at: datetime,
        duration_ms: int,
        counts: Dict[str, int],
        timings_ms: Dict[str, int],
    ) -> None:
        self._upsert_meta("last_sync_time", datetime.now(timezone.utc).isoformat())
        self._upsert_meta("last_sync_status", "success")
        self._upsert_meta("last_sync_run_id", run_id)
        self._upsert_meta("last_sync_started_at", started_at.isoformat())
        self._upsert_meta("last_sync_duration_ms", str(duration_ms))
        self._upsert_meta("last_sync_counts", json.dumps(counts))
        self._upsert_meta("last_sync_timings_ms", json.dumps(timings_ms))
        self._upsert_meta("last_sync_error", "")

    def _persist_sync_failure(
        self,
        run_id: str,
        started_at: datetime,
        duration_ms: int,
        error: str,
    ) -> None:
        self._upsert_meta("last_sync_time", datetime.now(timezone.utc).isoformat())
        self._upsert_meta("last_sync_status", "error")
        self._upsert_meta("last_sync_run_id", run_id)
        self._upsert_meta("last_sync_started_at", started_at.isoformat())
        self._upsert_meta("last_sync_duration_ms", str(duration_ms))
        self._upsert_meta("last_sync_error", error)

    def _read_meta_map(self) -> Dict[str, str]:
        rows = self.db.fetch_all("SELECT key, value FROM meta")
        return {
            str(r.get("key")): str(r.get("value") or "")
            for r in rows
            if r.get("key") is not None
        }

    @staticmethod
    def _json_map(value: Optional[str]) -> Dict[str, int]:
        if not value:
            return {}
        try:
            parsed = json.loads(value)
            if isinstance(parsed, dict):
                out: Dict[str, int] = {}
                for k, v in parsed.items():
                    try:
                        out[str(k)] = int(v)
                    except (TypeError, ValueError):
                        continue
                return out
        except json.JSONDecodeError:
            return {}
        return {}

    @staticmethod
    def _parse_iso8601(value: Optional[str]) -> Optional[datetime]:
        if not value:
            return None
        normalized = value.strip()
        if normalized.endswith("Z"):
            normalized = normalized[:-1] + "+00:00"
        try:
            dt = datetime.fromisoformat(normalized)
            if dt.tzinfo is None:
                return dt.replace(tzinfo=timezone.utc)
            return dt
        except ValueError:
            return None
        
    def run_full_sync(self) -> Dict[str, int]:
        """Run complete sync from Salesforce to local database"""
        if not _RUN_LOCK.acquire(blocking=False):
            raise RuntimeError("sync already running")

        run_id = str(uuid.uuid4())
        started_at = datetime.now(timezone.utc)
        run_t0 = time.perf_counter()
        logger.info("[sync][%s] Starting full sync from Salesforce...", run_id)
        timings_ms: Dict[str, int] = {}
        
        try:
            # Fetch data from Salesforce
            stage_t0 = time.perf_counter()
            programs = fetch_programs()
            timings_ms["fetch_programs"] = int((time.perf_counter() - stage_t0) * 1000)
            prog_ids = sorted(str(p["Id"]) for p in programs if isinstance(p.get("Id"), str))
            logger.info("[sync][%s] Programs: %s", run_id, len(programs))

            batch_size = max(1, int(settings.SYNC_PROGRAM_BATCH_SIZE))
            max_enrollments = max(0, int(settings.SYNC_MAX_ENROLLMENTS_PER_RUN))
            stage_t0 = time.perf_counter()
            if prog_ids:
                enrollments = fetch_enrollments_for_programs_chunked(
                    prog_ids,
                    batch_size=batch_size,
                    max_records=max_enrollments,
                )
            else:
                enrollments = []
            timings_ms["fetch_enrollments"] = int((time.perf_counter() - stage_t0) * 1000)
            acct_ids = sorted(str(e["AccountId"]) for e in enrollments if isinstance(e.get("AccountId"), str))
            logger.info(
                "[sync][%s] Enrollments: %s | Accounts referenced: %s",
                run_id,
                len(enrollments),
                len(acct_ids),
            )
            
            stage_t0 = time.perf_counter()
            accounts = fetch_accounts(acct_ids) if acct_ids else []
            timings_ms["fetch_accounts"] = int((time.perf_counter() - stage_t0) * 1000)
            logger.info("[sync][%s] Accounts (Person): %s", run_id, len(accounts))
            
            # Upsert to local database
            stage_t0 = time.perf_counter()
            prog_uuid_by_id = upsert_programs(self.db, programs)
            timings_ms["upsert_programs"] = int((time.perf_counter() - stage_t0) * 1000)

            stage_t0 = time.perf_counter()
            acct_uuid_by_id = upsert_participants(self.db, accounts)
            timings_ms["upsert_participants"] = int((time.perf_counter() - stage_t0) * 1000)

            stage_t0 = time.perf_counter()
            enr_uuid_by_id = upsert_enrollments(self.db, enrollments, prog_uuid_by_id, acct_uuid_by_id)
            timings_ms["upsert_enrollments"] = int((time.perf_counter() - stage_t0) * 1000)
            
            # Get final counts
            stage_t0 = time.perf_counter()
            counts = {
                "programs": self.db.fetch_all("SELECT COUNT(*) n FROM programs")[0]["n"],
                "participants": self.db.fetch_all("SELECT COUNT(*) n FROM participants")[0]["n"],
                "enrollments": self.db.fetch_all("SELECT COUNT(*) n FROM program_enrollments")[0]["n"],
                "active_enrollments": self.db.fetch_all("SELECT COUNT(*) n FROM baseline_active_enrollments")[0]["n"],
            }
            timings_ms["count_queries"] = int((time.perf_counter() - stage_t0) * 1000)
            duration_ms = int((time.perf_counter() - run_t0) * 1000)

            self._persist_sync_success(run_id, started_at, duration_ms, counts, timings_ms)
            
            logger.info(
                "[sync][%s] Completed in %sms | counts=%s | timings_ms=%s",
                run_id,
                duration_ms,
                counts,
                timings_ms,
            )
            return counts
            
        except (SFAuthError, SFError) as e:
            duration_ms = int((time.perf_counter() - run_t0) * 1000)
            self._persist_sync_failure(run_id, started_at, duration_ms, str(e))
            logger.error("[sync][%s] Salesforce error after %sms: %s", run_id, duration_ms, e)
            raise
        except Exception as e:
            duration_ms = int((time.perf_counter() - run_t0) * 1000)
            self._persist_sync_failure(run_id, started_at, duration_ms, str(e))
            logger.error("[sync][%s] Unexpected error after %sms: %s", run_id, duration_ms, e, exc_info=True)
            raise
        finally:
            _RUN_LOCK.release()
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

            meta = self._read_meta_map()
            last_sync_time: Optional[str] = meta.get("last_sync_time") or None
            last_sync_status: Optional[str] = meta.get("last_sync_status") or None
            last_sync_run_id: Optional[str] = meta.get("last_sync_run_id") or None
            last_sync_started_at: Optional[str] = meta.get("last_sync_started_at") or None
            last_sync_error: Optional[str] = meta.get("last_sync_error") or None

            duration_raw = meta.get("last_sync_duration_ms")
            try:
                last_sync_duration_ms: Optional[int] = int(duration_raw) if duration_raw else None
            except ValueError:
                last_sync_duration_ms = None

            stale_threshold_hours = max(1, int(settings.SYNC_STALE_THRESHOLD_HOURS))
            is_sync_stale = False
            last_success_age_hours: Optional[float] = None
            sync_health: Literal["ok", "stale", "error", "unknown"] = "unknown"

            if last_sync_status == "success":
                parsed_last_sync = self._parse_iso8601(last_sync_time)
                if parsed_last_sync is not None:
                    age_seconds = (datetime.now(timezone.utc) - parsed_last_sync).total_seconds()
                    last_success_age_hours = round(max(0.0, age_seconds) / 3600.0, 3)
                    is_sync_stale = last_success_age_hours > stale_threshold_hours
                    sync_health = "stale" if is_sync_stale else "ok"
                else:
                    sync_health = "unknown"
            elif last_sync_status == "error":
                sync_health = "error"

            return {
                "counts": counts,
                "last_sync_time": last_sync_time,
                "last_sync_status": last_sync_status,
                "last_sync_run_id": last_sync_run_id,
                "last_sync_started_at": last_sync_started_at,
                "last_sync_duration_ms": last_sync_duration_ms,
                "last_sync_counts": self._json_map(meta.get("last_sync_counts")),
                "last_sync_timings_ms": self._json_map(meta.get("last_sync_timings_ms")),
                "last_sync_error": last_sync_error,
                "is_sync_stale": is_sync_stale,
                "stale_threshold_hours": stale_threshold_hours,
                "last_success_age_hours": last_success_age_hours,
                "sync_health": sync_health,
                "has_synced_once": bool(last_sync_time),
                "sync_running": is_sync_running(),
                "data_scope": "local_cache",
                "program_filters": list(settings.PROGRAM_NAMES),
                "status": "healthy",
            }
        except Exception as e:
            logger.error(f"[sync] Error getting sync status: {e}")
            return {"status": "error", "error": str(e)}
        finally:
            if hasattr(self, 'db'):
                self.db.close()

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