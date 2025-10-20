# deploy.ps1 - Unified deployment script

param(
    [Parameter(Mandatory=$true)]
    [ValidateSet("dev", "staging", "prod")]
    [string]$Environment,
    
    [switch]$Salesforce,
    [switch]$PWA,
    [switch]$All
)

if ($All) { $Salesforce = $true; $PWA = $true }

Write-Host "Deploying to $Environment..." -ForegroundColor Green

# Deploy Salesforce components
if ($Salesforce) {
    Write-Host "Deploying Salesforce..." -ForegroundColor Yellow
    Push-Location "tgthrProgramManagement"
    
    switch ($Environment) {
        "dev" { sf project deploy start --source-dir force-app --target-org dev }
        "staging" { sf project deploy start --source-dir force-app --target-org staging }
        "prod" { sf project deploy start --source-dir force-app --target-org prod }
    }
    
    Pop-Location
}

# Deploy PWA
if ($PWA) {
    Write-Host "Deploying PWA..." -ForegroundColor Yellow
    Push-Location "pwa-sync-starter"
    
    # Build
    Push-Location "web"
    npm run build
    Pop-Location
    
    # Deploy to EC2 based on environment
    switch ($Environment) {
        "dev" { 
            Write-Host "Deploying to dev EC2..." 
            docker build -t tgthr-pwa-web ./web
            docker save tgthr-pwa-web | gzip > tgthr-pwa-web.tar.gz
            # scp tgthr-pwa-web.tar.gz user@dev-server:/tmp/
            # ssh user@dev-server "cd /var/www/tgthr && docker load < /tmp/tgthr-pwa-web.tar.gz && docker-compose up -d"
        }
        "staging" { 
            Write-Host "Deploying to staging EC2..." 
            docker build -t tgthr-pwa-web ./web
            docker save tgthr-pwa-web | gzip > tgthr-pwa-web.tar.gz
            # scp tgthr-pwa-web.tar.gz user@staging-server:/tmp/
            # ssh user@staging-server "cd /var/www/tgthr && docker load < /tmp/tgthr-pwa-web.tar.gz && docker-compose up -d"
        }
        "prod" { 
            Write-Host "Deploying to prod EC2..." 
            docker build -t tgthr-pwa-web ./web
            docker save tgthr-pwa-web | gzip > tgthr-pwa-web.tar.gz
            # scp tgthr-pwa-web.tar.gz user@prod-server:/tmp/
            # ssh user@prod-server "cd /var/www/tgthr && docker load < /tmp/tgthr-pwa-web.tar.gz && docker-compose up -d"
        }
    }
    
    Pop-Location
}

Write-Host "Deployment complete!" -ForegroundColor Green