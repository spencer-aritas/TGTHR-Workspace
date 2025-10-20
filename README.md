# TGTHR Program Management System

Combined PWA + Salesforce repository for street outreach client intake and program management.

## Structure
```
├── pwa-sync-starter/          # PWA application
│   ├── web/                   # React frontend
│   ├── server/                # FastAPI backend
│   └── shared/contracts/      # Integration contracts
├── tgthrProgramManagement/    # Salesforce components
│   └── force-app/             # Apex classes, LWCs
└── deploy.ps1                 # Unified deployment script
```

## Quick Start

### Development
```bash
# PWA
cd pwa-sync-starter/web && npm run dev
cd pwa-sync-starter/server && uvicorn app.main:app --reload

# Salesforce
cd tgthrProgramManagement && sf org open
```

### Deployment
```powershell
# Deploy everything to dev
.\deploy.ps1 -Environment dev -All

# Deploy only PWA to staging
.\deploy.ps1 -Environment staging -PWA

# Deploy only Salesforce to prod
.\deploy.ps1 -Environment prod -Salesforce
```

## Workflow

1. **Development**: Work in respective folders with their IDEs
2. **Git**: Commit/push entire combined repo
3. **Deploy**: Use `deploy.ps1` for environment-specific deployments
4. **Integration**: Shared contracts ensure compatibility

## New Client Intake Flow

PWA form → FastAPI → Salesforce ProgramEnrollmentService → Creates:
- Person Account
- Program Enrollment (Street Outreach)
- Benefit Assignments
- Interaction Summary
- Follow-up Task