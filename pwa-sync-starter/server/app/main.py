# server/app/main.py
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from .routers import baseline
from .settings import settings
from .models.db import engine, Base
from .jobs.scheduler import start_scheduler
from .api.sync import sf_router
from .db import init_schema_and_seed
import uuid
from .api import sync, device, health
from .api.outreach import router as outreach_router
from .api.auth import router as auth_router
from .api.users import router as users_router
from .api.signatures import router as signatures_router
from .api.cases import router as cases_router
from .api.interaction_summary import router as interaction_summary_router
from .api.interview_templates import router as interview_templates_router
from .routers.ssrs_assessment import router as ssrs_router
from .middleware.logging_with_audit import setup_audit_logging

init_schema_and_seed()

app = FastAPI(title="TGTHR Sync API", version="0.1.0")
app.include_router(sf_router, prefix="/api")
app.include_router(baseline.router)

# Initialize DB schema
Base.metadata.create_all(bind=engine)

# CORS configuration
app.add_middleware(
    CORSMiddleware,
    allow_origins=[
        # Development origins
        "http://localhost:5173",
        "http://127.0.0.1:5173",
        "http://192.168.1.20:5173",
        # Production origins
        "https://outreachintake.aritasconsulting.com",
        "https://app.outreachintake.aritasconsulting.com"
    ],
    allow_credentials=True,
    allow_methods=["GET", "POST"],  # Restrict methods
    allow_headers=["Content-Type", "Authorization"],
)

# Security headers
@app.middleware("http")
async def add_security_headers(request, call_next):
    response = await call_next(request)
    response.headers["X-Content-Type-Options"] = "nosniff"
    response.headers["X-Frame-Options"] = "DENY"
    response.headers["X-XSS-Protection"] = "1; mode=block"
    response.headers["Strict-Transport-Security"] = "max-age=31536000; includeSubDomains"
    return response

# Mount API routers under /api
app.include_router(sync.router, prefix="/api")
app.include_router(device.router, prefix="/api")
app.include_router(health.router, prefix="/api")
app.include_router(outreach_router, prefix="/api")
app.include_router(auth_router)  # Auth router already has /api/auth prefix
app.include_router(users_router, prefix="/api")
app.include_router(signatures_router, prefix="/api")
app.include_router(cases_router, prefix="/api")
app.include_router(interaction_summary_router, prefix="/api")
app.include_router(interview_templates_router, prefix="/api")
app.include_router(ssrs_router, prefix="/api")

# Add device registration router
from .routers.device import router as device_reg_router
app.include_router(device_reg_router)

# Add users router
from .routers.users import router as users_router
app.include_router(users_router)

# Simple top-level health
@app.get("/health")
def healthcheck():
    return {"ok": True}

# Start background jobs once per process (avoids double-start with --reload)
@app.on_event("startup")
def _startup():
    start_scheduler()
