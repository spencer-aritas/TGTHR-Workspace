
# server/app/jobs/scheduler.py
from __future__ import annotations

import atexit
import logging
from datetime import datetime, timezone
from zoneinfo import ZoneInfo, ZoneInfoNotFoundError

from apscheduler.schedulers.background import BackgroundScheduler
from apscheduler.triggers.cron import CronTrigger

from ..settings import settings
from ..sync_runner import run_full_sync

logger = logging.getLogger("scheduler")

def run_nightly():
    """Nightly sync job that runs full sync from Salesforce"""
    logger.info(f"[nightly] {datetime.now(timezone.utc).isoformat()} running sync job")
    try:
        result = run_full_sync()
        logger.info(f"[nightly] Sync completed successfully: {result}")
    except Exception as e:
        logger.error(f"[nightly] Sync failed: {e}", exc_info=True)

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
        )
    )

    sched.start()
    logger.info(f"Scheduler started with nightly sync at {settings.SYNC_SCHEDULE_HOUR:02d}:{settings.SYNC_SCHEDULE_MINUTE:02d} {tz_name}")
    atexit.register(lambda: sched.shutdown(wait=False))
    return sched

