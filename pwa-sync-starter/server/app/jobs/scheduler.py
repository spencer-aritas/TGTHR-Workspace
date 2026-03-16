
# server/app/jobs/scheduler.py
from __future__ import annotations

import atexit
import logging
import threading
from datetime import datetime, timezone
from zoneinfo import ZoneInfo, ZoneInfoNotFoundError

from apscheduler.schedulers.background import BackgroundScheduler
from apscheduler.triggers.cron import CronTrigger

from ..settings import settings
from ..sync_runner import run_full_sync

logger = logging.getLogger("scheduler")
_sync_lock = threading.Lock()

def run_nightly():
    """Nightly sync job that runs full sync from Salesforce"""
    if not _sync_lock.acquire(blocking=False):
        logger.warning("[nightly] previous sync still running, skipping overlapping run")
        return

    logger.info(f"[nightly] {datetime.now(timezone.utc).isoformat()} running sync job")
    try:
        result = run_full_sync()
        logger.info(f"[nightly] Sync completed successfully: {result}")
    except Exception as e:
        logger.error(f"[nightly] Sync failed: {e}", exc_info=True)
    finally:
        _sync_lock.release()

def start_scheduler():
    """Start the background scheduler with configured timing"""
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
    logger.info(f"Scheduler started with nightly sync at {settings.SYNC_SCHEDULE_HOUR:02d}:{settings.SYNC_SCHEDULE_MINUTE:02d} {tz_name}")
    atexit.register(lambda: sched.shutdown(wait=False))
    return sched

