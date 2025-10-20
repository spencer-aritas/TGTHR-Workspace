# sync-salesforce.ps1
# Sync Salesforce components between repos for deployment

Write-Host "Syncing Salesforce components..." -ForegroundColor Green

# Copy Apex classes from tgthrProgramManagement to pwa-sync-starter
$sourceApex = "tgthrProgramManagement\force-app\main\default\classes"
$targetApex = "pwa-sync-starter\salesforce-apex"

# Ensure target directory exists
if (!(Test-Path $targetApex)) {
    New-Item -ItemType Directory -Path $targetApex -Force
}

# Copy essential Apex classes
$apexClasses = @(
    "ProgramEnrollmentService.cls",
    "BenefitService.cls", 
    "InteractionSummaryService.cls",
    "TaskService.cls",
    "PwaEncounter.cls"
)

foreach ($class in $apexClasses) {
    $sourcePath = Join-Path $sourceApex $class
    $targetPath = Join-Path $targetApex $class
    
    if (Test-Path $sourcePath) {
        Copy-Item $sourcePath $targetPath -Force
        Write-Host "Copied $class" -ForegroundColor Yellow
        
        # Copy meta.xml file if it exists
        $metaSource = $sourcePath + "-meta.xml"
        $metaTarget = $targetPath + "-meta.xml"
        if (Test-Path $metaSource) {
            Copy-Item $metaSource $metaTarget -Force
        }
    } else {
        Write-Host "Warning: $class not found in source" -ForegroundColor Red
    }
}

Write-Host "Salesforce sync complete!" -ForegroundColor Green