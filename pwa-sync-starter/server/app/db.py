# server/app/db.py
from __future__ import annotations
import duckdb
from typing import Any, Dict, Iterable, List, Optional
from pathlib import Path
from datetime import datetime
from .schema import ensure_schema
from .settings import settings

# --- Tiny wrapper so routers can call fetch_all(SQL, params) and get list[dict] ---

class DuckClient:
    def __init__(self, db_path: str | None = None):
        self.db_path = db_path or settings.TGTHR_DB_PATH
        Path(self.db_path).parent.mkdir(parents=True, exist_ok=True)
        self.conn = duckdb.connect(self.db_path, read_only=False)
        ensure_schema(self.conn)

    def execute(self, sql: str, params: tuple = ()) -> None:
        self.conn.execute(sql, params)

    def fetch_all(self, sql: str, params: tuple = ()) -> list[dict]:
        cur = self.conn.execute(sql, params)
        cols = [d[0] for d in cur.description]
        return [dict(zip(cols, row)) for row in cur.fetchall()]

    def close(self) -> None:
        try:
            self.conn.close()
        except Exception:
            pass

# --- App lifecycle helpers ---
def map_sf_to_db(rec: dict) -> dict:
    out = {}
    for k, v in rec.items():
        lk = k.lower()
        if lk == "uuid__c":
            out["uuid"] = v
        else:
            out[lk] = v
    return out

def init_schema_and_seed():
    """Create minimal tables and view if missing, and seed programs from settings."""
    from .schema import reset_database
    
    con = None
    try:
        # Ensure data directory exists
        Path(settings.TGTHR_DB_PATH).parent.mkdir(parents=True, exist_ok=True)
        con = duckdb.connect(settings.TGTHR_DB_PATH)
        ensure_schema(con)
    except Exception as e:
        # If schema creation fails, reset the database
        print(f"Schema conflict detected, resetting database: {e}")
        if con:
            con.close()
        reset_database(settings.TGTHR_DB_PATH)
        con = duckdb.connect(settings.TGTHR_DB_PATH)
    
    # Seed programs if missing
    try:
        count = con.execute("SELECT COUNT(*) FROM programs").fetchone()[0]
        if count == 0:
            for i, name in enumerate(settings.PROGRAM_NAMES):
                code = name.replace(" ", "").upper()[:4]
                uuid_val = f"prog-{i+1}-{code.lower()}"
                con.execute("""
                    INSERT INTO programs (uuid, sfid, name, last_modified_date) 
                    VALUES (?, NULL, ?, now())
                """, (uuid_val, name))
    finally:
        if con:
            con.close()

# Dependency for FastAPI

def get_db():
    client = DuckClient()
    try:
        yield client
    finally:
        client.close()
