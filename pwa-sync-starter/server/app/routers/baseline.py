# server/app/routers/baseline.py
from fastapi import APIRouter, Depends, HTTPException, Response
from pydantic import BaseModel
from typing import List, Optional
from datetime import datetime, timezone
import hashlib, json

from ..db import get_db  # DuckDB dependency

router = APIRouter(prefix="/baseline", tags=["baseline"])

# ---------------- Pydantic models ----------------

class ActiveRow(BaseModel):
    participant_uuid: str
    participant_sfid: Optional[str] = None
    first_name: Optional[str] = None
    last_name: str
    preferred_name: Optional[str] = None

    program_uuid: str
    program_sfid: Optional[str] = None
    program_code: str            # 'PINE' | 'N56'
    program_name: str

    enrollment_uuid: str
    enrollment_sfid: Optional[str] = None
    start_date: Optional[str] = None  # 'YYYY-MM-DD'
    end_date: Optional[str] = None
    status: str                       # 'Active' | 'Exited' | 'Waitlist' | 'Pending'

    profile_complete: Optional[bool] = None
    missing_social: Optional[bool] = None

    updated_at: str  # ISO string

class BaselinePayload(BaseModel):
    baseline_hash: str
    last_refreshed_at: str
    items: List[ActiveRow]

# ---------------- util + SQL ----------------

def compute_baseline_hash(items: List[dict]) -> str:
    sorted_items = sorted(
        items,
        key=lambda r: (
            (r.get("last_name") or "").lower(),
            (r.get("first_name") or "").lower(),
            r.get("participant_uuid") or "",
            r.get("program_uuid") or "",
        ),
    )
    payload = json.dumps(sorted_items, separators=(",", ":"), ensure_ascii=False)
    return "sha256:" + hashlib.sha256(payload.encode("utf-8")).hexdigest()

SQL_ACTIVE_BASELINE = """
WITH codes(code) AS /*:codes_values*/
SELECT
    p.uuid      AS participant_uuid,
    p.sfid               AS participant_sfid,
    p.first_name,
    p.last_name,
    p.preferred_name,
    pr.uuid     AS program_uuid,
    pr.sfid              AS program_sfid,
    pr.code              AS program_code,
    pr.name              AS program_name,
    e.uuid      AS enrollment_uuid,
    e.sfid               AS enrollment_sfid,
    strftime(e.start_date, '%Y-%m-%d') AS start_date,
    CASE WHEN e.end_date IS NULL THEN NULL ELSE strftime(e.end_date, '%Y-%m-%d') END AS end_date,
    e.status,
    p.profile_complete,
    p.missing_social,
    strftime(greatest(p.updated_at, e.updated_at, pr.updated_at), '%Y-%m-%dT%H:%M:%SZ') AS updated_at
FROM v_active_participants vap
JOIN participants p        ON p.uuid  = vap.participant_uuid
JOIN programs pr           ON pr.uuid = vap.program_uuid
JOIN program_enrollments e ON e.uuid  = vap.enrollment_uuid
JOIN codes ON codes.code = pr.code
ORDER BY lower(p.last_name), lower(p.first_name);
"""

# ---------------- route ----------------

@router.get("/active-participants", response_model=BaselinePayload)
def get_active_participants_baseline(
    response: Response,
    codes: Optional[str] = None,
    db = Depends(get_db)
):
    program_codes = [c.strip().upper() for c in (codes.split(",") if codes else ["PINE", "N56"]) if c.strip()]

    try:
        rows = db.fetch_all(SQL_ACTIVE_BASELINE, {"codes": program_codes})
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"DB error: {e}")

    items = [{
        "participant_uuid": r["participant_uuid"],
        "participant_sfid": r.get("participant_sfid"),
        "first_name": r.get("first_name"),
        "last_name": r["last_name"],
        "preferred_name": r.get("preferred_name"),
        "program_uuid": r["program_uuid"],
        "program_sfid": r.get("program_sfid"),
        "program_code": r["program_code"],
        "program_name": r["program_name"],
        "enrollment_uuid": r["enrollment_uuid"],
        "enrollment_sfid": r.get("enrollment_sfid"),
        "start_date": r.get("start_date"),
        "end_date": r.get("end_date"),
        "status": r.get("status"),
        "profile_complete": r.get("profile_complete"),
        "missing_social": r.get("missing_social"),
        "updated_at": r.get("updated_at"),
    } for r in rows]

    baseline_hash = compute_baseline_hash(items)
    response.headers["ETag"] = baseline_hash

    now = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    return BaselinePayload(
        baseline_hash=baseline_hash,
        last_refreshed_at=now,
        items=items
    )
