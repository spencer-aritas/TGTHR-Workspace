# server/reset_db.py
"""Script to reset the DuckDB database with fresh schema"""

import sys
from pathlib import Path

# Add app to path
sys.path.insert(0, str(Path(__file__).parent))

from app.schema import reset_database
from app.settings import settings

def main():
    print(f"Resetting database at: {settings.TGTHR_DB_PATH}")
    reset_database(settings.TGTHR_DB_PATH)
    print("Database reset complete!")

if __name__ == "__main__":
    main()