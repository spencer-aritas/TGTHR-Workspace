# server/scripts/sync_sf_to_duckdb.py
from __future__ import annotations

import sys
from pathlib import Path

# Add parent directory to path for imports
sys.path.insert(0, str(Path(__file__).resolve().parents[2]))

from server.app.sync_runner import run_full_sync

def main():
    """Main entry point for sync script - delegates to sync_runner"""
    try:
        result = run_full_sync()
        print(f"[sync] Sync completed successfully: {result}")
        return 0
    except Exception as e:
        print(f"[sync] Sync failed: {e}")
        return 1

if __name__ == "__main__":
    exit(main())
