#!/usr/bin/env pwsh
# Complete cache clearing script for TGTHR PWA

Write-Host "🧹 Starting complete cache clear process..." -ForegroundColor Yellow

# 1. Stop all containers
Write-Host "1. Stopping Docker containers..." -ForegroundColor Cyan
docker compose down

# 2. Remove ALL Docker data (including named volumes)
Write-Host "2. Removing ALL Docker data..." -ForegroundColor Cyan
docker system prune -a --volumes -f
docker volume prune -f

# 3. Clear local database files
Write-Host "3. Clearing local database files..." -ForegroundColor Cyan
if (Test-Path "server/server.db") { Remove-Item "server/server.db" -Force }
if (Test-Path "data/app.duckdb") { Remove-Item "data/app.duckdb" -Force }
if (Test-Path "server/data/server.db") { Remove-Item "server/data/server.db" -Force }

# 4. Clear any Python cache
Write-Host "4. Clearing Python cache..." -ForegroundColor Cyan
Get-ChildItem -Path "server" -Recurse -Name "__pycache__" | ForEach-Object { Remove-Item "server/$_" -Recurse -Force }
Get-ChildItem -Path "server" -Recurse -Name "*.pyc" | ForEach-Object { Remove-Item "server/$_" -Force }

# 5. Clear Node.js cache
Write-Host "5. Clearing Node.js cache..." -ForegroundColor Cyan
if (Test-Path "web/node_modules") { Remove-Item "web/node_modules" -Recurse -Force }
if (Test-Path "web/dev-dist") { Remove-Item "web/dev-dist" -Recurse -Force }
if (Test-Path "web/dist") { Remove-Item "web/dist" -Recurse -Force }

# 6. Git pull latest
Write-Host "6. Pulling latest code..." -ForegroundColor Cyan
git pull

# 7. Rebuild and start
Write-Host "7. Rebuilding and starting containers..." -ForegroundColor Cyan
docker compose up -d --build --force-recreate

Write-Host "✅ Complete cache clear finished!" -ForegroundColor Green
Write-Host "🌐 Clear browser data manually:" -ForegroundColor Yellow
Write-Host "   - Chrome: F12 > Application > Storage > Clear site data" -ForegroundColor White
Write-Host "   - Phone: Settings > Apps > Browser > Storage > Clear Data" -ForegroundColor White