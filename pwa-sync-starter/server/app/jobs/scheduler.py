
# server/app/jobs/scheduler.py
from __future__ import annotations

import atexit
import logging
from datetime import datetime, timezone
from typing import Any, Dict, Optional
from zoneinfo import ZoneInfo, ZoneInfoNotFoundError

from apscheduler.schedulers.background import BackgroundScheduler
from apscheduler.triggers.cron import CronTrigger

from ..settings import settings
from ..sync_runner import run_full_sync

logger = logging.getLogger("scheduler")
_scheduler: Optional[BackgroundScheduler] = None

def run_nightly():
    """Nightly sync job that runs full sync from Salesforce"""
    logger.info(f"[nightly] {datetime.now(timezone.utc).isoformat()} running sync job")
    try:
        result = run_full_sync()
        logger.info(f"[nightly] Sync completed successfully: {result}")
    except RuntimeError as e:
        logger.warning(f"[nightly] {e}; skipping overlapping run")
    except Exception as e:
        logger.error(f"[nightly] Sync failed: {e}", exc_info=True)

def start_scheduler():
    """Start the background scheduler with configured timing"""
    global _scheduler
    tz_name = settings.TIMEZONE
    try:
        tz = ZoneInfo(tz_name)
    except ZoneInfoNotFoundError:
        logger.warning(f"Invalid timezone '{tz_name}', defaulting to UTC")
        tz_name = "UTC"
        tz = ZoneInfo("UTC")

    sched = BackgroundScheduler(timezone=tz)

    # Schedule using configured time
    sched.add_job(
        run_nightly,
        CronTrigger(
            hour=settings.SYNC_SCHEDULE_HOUR,
            minute=settings.SYNC_SCHEDULE_MINUTE
        ),
        id="nightly_sync",
        replace_existing=True,
        coalesce=settings.SCHEDULER_COALESCE,
        misfire_grace_time=settings.SCHEDULER_MISFIRE_GRACE_SECONDS,
        max_instances=settings.SCHEDULER_MAX_INSTANCES,
    )

    sched.start()
    _scheduler = sched
    logger.info(f"Scheduler started with nightly sync at {settings.SYNC_SCHEDULE_HOUR:02d}:{settings.SYNC_SCHEDULE_MINUTE:02d} {tz_name}")
    atexit.register(lambda: sched.shutdown(wait=False))
    return sched

def get_scheduler_state() -> Dict[str, Any]:
    """Return scheduler diagnostics including next run time for the nightly job."""
    if _scheduler is None:
        return {
            "started": False,
            "running": False,
            "timezone": settings.TIMEZONE,
            "job_id": "nightly_sync",
            "next_run_time": None,
            "trigger": None,
        }

    job = _scheduler.get_job("nightly_sync")
    next_run_time = job.next_run_time.isoformat() if job and job.next_run_time else None
    trigger = str(job.trigger) if job else None

    return {
        "started": True,
        "running": _scheduler.running,
        "timezone": str(_scheduler.timezone),
        "job_id": "nightly_sync",
        "next_run_time": next_run_time,
        "trigger": trigger,
    }

