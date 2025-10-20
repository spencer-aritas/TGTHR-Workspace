import sqlite3
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from ..schema import Base
from ..settings import settings

engine = create_engine(f'sqlite:///{settings.SQLITE_DB_PATH}', echo=False, future=True)
SessionLocal = sessionmaker(bind=engine, autoflush=False, expire_on_commit=False, future=True)

def get_db():
    """Get SQLite connection for device registration"""
    conn = sqlite3.connect(settings.SQLITE_DB_PATH)
    
    # Create device_registrations table if not exists
    conn.execute("""
        CREATE TABLE IF NOT EXISTS device_registrations (
            device_id TEXT PRIMARY KEY,
            user_id TEXT NOT NULL,
            sf_user_id TEXT NOT NULL,
            registered_at TEXT NOT NULL,
            last_sync_at TEXT
        )
    """)
    conn.commit()
    
    return conn
