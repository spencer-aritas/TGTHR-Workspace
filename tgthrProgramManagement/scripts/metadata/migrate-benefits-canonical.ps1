param(
    [string]$SandboxAlias = "benefits",
    [string]$ProdAlias = "tgthrnpc-prod",
    [switch]$Execute
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
$PSNativeCommandUseErrorActionPreference = $false

$projectRoot = Resolve-Path (Join-Path $PSScriptRoot "..\..")
Set-Location $projectRoot

$dataDir = Join-Path $projectRoot "scripts\data"
New-Item -ItemType Directory -Force -Path $dataDir | Out-Null

$paths = @{
    SandboxBenefitTypes = Join-Path $dataDir "sandbox_benefittypes.csv"
    SandboxBenefits = Join-Path $dataDir "sandbox_benefits_enriched.csv"
    SandboxPrograms = Join-Path $dataDir "sandbox_programs.csv"
    ProdPrograms = Join-Path $dataDir "prod_programs.csv"
    ProdBenefitTypes = Join-Path $dataDir "prod_benefittypes.csv"
    ProdActiveBefore = Join-Path $dataDir "prod_active_benefits_pre_migration.csv"
    BenefitTypeUpsert = Join-Path $dataDir "prod_benefittypes_upsert.csv"
    BenefitUpsert = Join-Path $dataDir "prod_benefits_upsert.csv"
    RetireUpdate = Join-Path $dataDir "prod_benefits_retire_update.csv"
    Unmapped = Join-Path $dataDir "sandbox_benefits_unmapped.csv"
}

function Invoke-SfCsvQuery {
    param(
        [string]$Org,
        [string]$Query,
        [string]$OutFile
    )
    & sf data query -o $Org -q $Query --result-format csv | Out-File -FilePath $OutFile -Encoding utf8
}

Write-Host "Exporting source/target data..."
Invoke-SfCsvQuery -Org $SandboxAlias -Query "SELECT Id,Name,NPSP_ID__c,SWSHE_Service__c FROM BenefitType ORDER BY Name" -OutFile $paths.SandboxBenefitTypes
Invoke-SfCsvQuery -Org $SandboxAlias -Query "SELECT Id,Name FROM Program ORDER BY Name" -OutFile $paths.SandboxPrograms
Invoke-SfCsvQuery -Org $ProdAlias -Query "SELECT Id,Name FROM Program ORDER BY Name" -OutFile $paths.ProdPrograms
Invoke-SfCsvQuery -Org $ProdAlias -Query "SELECT Id,Name,NPSP_ID__c,SWSHE_Service__c FROM BenefitType ORDER BY Name" -OutFile $paths.ProdBenefitTypes
Invoke-SfCsvQuery -Org $ProdAlias -Query "SELECT Id,Name,NPSP_ID__c,IsActive,Available_for_Housing__c,Available_for_Program_Engagement__c,Available_for_Case_Management__c,Available_for_Clinical__c,Available_for_Peer__c FROM Benefit WHERE IsActive=true ORDER BY Name" -OutFile $paths.ProdActiveBefore
Invoke-SfCsvQuery -Org $SandboxAlias -Query "SELECT Id,Name,NPSP_ID__c,UUID__c,ProgramId,Program.Name,BenefitTypeId,BenefitType.Name,IsActive,BenefitStatus,CPT_Code__c,Default_Disbursement_Quantity__c,Default_Duration_c__c,Housing_Capacity__c,Is_a_Housing_Benefit__c,Spots_Currently_Filled__c,Available_for_Housing__c,Available_for_Program_Engagement__c,Available_for_Case_Management__c,Available_for_Clinical__c,Available_for_Peer__c,Lifecycle_State__c FROM Benefit ORDER BY Name" -OutFile $paths.SandboxBenefits

$sandboxBenefitTypes = Import-Csv $paths.SandboxBenefitTypes
$sandboxBenefits = Import-Csv $paths.SandboxBenefits
$sandboxPrograms = Import-Csv $paths.SandboxPrograms
$prodPrograms = Import-Csv $paths.ProdPrograms
$prodBenefitTypes = Import-Csv $paths.ProdBenefitTypes
$prodActiveBefore = Import-Csv $paths.ProdActiveBefore

$prodProgramNameGroups = $prodPrograms | Group-Object Name
$prodProgramNameToId = @{}
foreach ($g in $prodProgramNameGroups) {
    if ($g.Count -eq 1) {
        $prodProgramNameToId[$g.Name] = $g.Group[0].Id
    }
}

$sbProgramIdToName = @{}
foreach ($p in $sandboxPrograms) {
    $sbProgramIdToName[$p.Id] = $p.Name
}

$prodBtByNpsp = @{}
foreach ($bt in $prodBenefitTypes) {
    if ($bt.NPSP_ID__c) { $prodBtByNpsp[$bt.NPSP_ID__c] = $bt.Id }
}
$prodBtNameGroups = $prodBenefitTypes | Group-Object Name
$prodBtNameToId = @{}
foreach ($g in $prodBtNameGroups) {
    if ($g.Count -eq 1) {
        $prodBtNameToId[$g.Name] = $g.Group[0].Id
    }
}

$sbBtById = @{}
foreach ($bt in $sandboxBenefitTypes) {
    $sbBtById[$bt.Id] = $bt
}

$retireRows = foreach ($b in $prodActiveBefore) {
    [PSCustomObject]@{
        Id = $b.Id
        IsActive = 'false'
        Available_for_Housing__c = 'false'
        Available_for_Program_Engagement__c = 'false'
        Available_for_Case_Management__c = 'false'
        Available_for_Clinical__c = 'false'
        Available_for_Peer__c = 'false'
    }
}
$retireRows | Export-Csv -Path $paths.RetireUpdate -NoTypeInformation

$btUpsertRows = foreach ($bt in $sandboxBenefitTypes) {
    [PSCustomObject]@{
        Name = $bt.Name
        NPSP_ID__c = $bt.NPSP_ID__c
        SWSHE_Service__c = $bt.SWSHE_Service__c
    }
}
$btUpsertRows | Export-Csv -Path $paths.BenefitTypeUpsert -NoTypeInformation

Write-Host "Preflight summary:"
Write-Host "  Sandbox BenefitTypes: $($sandboxBenefitTypes.Count)"
Write-Host "  Sandbox Benefits: $($sandboxBenefits.Count)"
Write-Host "  Prod active Benefits to retire: $($prodActiveBefore.Count)"

if (-not $Execute) {
    Write-Host "Dry run complete. Re-run with -Execute to apply changes."
    exit 0
}

Write-Host "Upserting BenefitType records to prod..."
& sf data upsert bulk -o $ProdAlias -s BenefitType -f $paths.BenefitTypeUpsert -i NPSP_ID__c -w 30 --line-ending CRLF

# Refresh prod BenefitType map after upsert.
Invoke-SfCsvQuery -Org $ProdAlias -Query "SELECT Id,Name,NPSP_ID__c,SWSHE_Service__c FROM BenefitType ORDER BY Name" -OutFile $paths.ProdBenefitTypes
$prodBenefitTypes = Import-Csv $paths.ProdBenefitTypes
$prodBtByNpsp = @{}
foreach ($bt in $prodBenefitTypes) {
    if ($bt.NPSP_ID__c) { $prodBtByNpsp[$bt.NPSP_ID__c] = $bt.Id }
}
$prodBtNameGroups = $prodBenefitTypes | Group-Object Name
$prodBtNameToId = @{}
foreach ($g in $prodBtNameGroups) {
    if ($g.Count -eq 1) {
        $prodBtNameToId[$g.Name] = $g.Group[0].Id
    }
}

$unmapped = New-Object System.Collections.Generic.List[Object]
$benefitUpsertRows = New-Object System.Collections.Generic.List[Object]

foreach ($b in $sandboxBenefits) {
    $programName = $null
    $prodProgramId = $null
    if ($b.ProgramId -and $sbProgramIdToName.ContainsKey($b.ProgramId)) {
        $programName = $sbProgramIdToName[$b.ProgramId]
        if ($programName -and $prodProgramNameToId.ContainsKey($programName)) {
            $prodProgramId = $prodProgramNameToId[$programName]
        }
    }

    $prodBenefitTypeId = $null
    $sbBt = $null
    if ($b.BenefitTypeId -and $sbBtById.ContainsKey($b.BenefitTypeId)) {
        $sbBt = $sbBtById[$b.BenefitTypeId]
        if ($sbBt.NPSP_ID__c -and $prodBtByNpsp.ContainsKey($sbBt.NPSP_ID__c)) {
            $prodBenefitTypeId = $prodBtByNpsp[$sbBt.NPSP_ID__c]
        } elseif ($sbBt.Name -and $prodBtNameToId.ContainsKey($sbBt.Name)) {
            $prodBenefitTypeId = $prodBtNameToId[$sbBt.Name]
        }
    }

    if (-not $prodProgramId -or -not $prodBenefitTypeId) {
        $unmapped.Add([PSCustomObject]@{
            Name = $b.Name
            SandboxBenefitId = $b.Id
            ProgramId = $b.ProgramId
            ProgramName = $programName
            BenefitTypeId = $b.BenefitTypeId
            BenefitTypeName = if ($sbBt) { $sbBt.Name } else { $b.'BenefitType.Name' }
            BenefitTypeNpspId = if ($sbBt) { $sbBt.NPSP_ID__c } else { '' }
            MissingProgramMap = [bool](-not $prodProgramId)
            MissingBenefitTypeMap = [bool](-not $prodBenefitTypeId)
        })
        continue
    }

    $benefitUpsertRows.Add([PSCustomObject]@{
        Name = $b.Name
        NPSP_ID__c = $b.NPSP_ID__c
        UUID__c = $b.UUID__c
        ProgramId = $prodProgramId
        BenefitTypeId = $prodBenefitTypeId
        IsActive = if ($b.IsActive) { $b.IsActive } else { 'false' }
        BenefitStatus = $b.BenefitStatus
        CPT_Code__c = $b.CPT_Code__c
        Default_Disbursement_Quantity__c = $b.Default_Disbursement_Quantity__c
        Default_Duration_c__c = $b.Default_Duration_c__c
        Housing_Capacity__c = $b.Housing_Capacity__c
        Is_a_Housing_Benefit__c = $b.Is_a_Housing_Benefit__c
        Spots_Currently_Filled__c = $b.Spots_Currently_Filled__c
        Available_for_Housing__c = $b.Available_for_Housing__c
        Available_for_Program_Engagement__c = $b.Available_for_Program_Engagement__c
        Available_for_Case_Management__c = $b.Available_for_Case_Management__c
        Available_for_Clinical__c = $b.Available_for_Clinical__c
        Available_for_Peer__c = $b.Available_for_Peer__c
        Lifecycle_State__c = $b.Lifecycle_State__c
    })
}

$benefitUpsertRows | Export-Csv -Path $paths.BenefitUpsert -NoTypeInformation
$unmapped | Export-Csv -Path $paths.Unmapped -NoTypeInformation

Write-Host "Mapped sandbox benefits ready to upsert: $($benefitUpsertRows.Count)"
Write-Host "Unmapped sandbox benefits (skipped): $($unmapped.Count)"
if ($unmapped.Count -gt 0) {
    Write-Host "Review skipped rows in: $($paths.Unmapped)"
}

if ($benefitUpsertRows.Count -eq 0) {
    throw "No mapped Benefit rows to upsert. Aborting before retire step."
}

Write-Host "Upserting mapped Benefits to prod by NPSP_ID__c..."
& sf data upsert bulk -o $ProdAlias -s Benefit -f $paths.BenefitUpsert -i NPSP_ID__c -w 45 --line-ending CRLF

Write-Host "Retiring previously active prod Benefit records..."
& sf data update bulk -o $ProdAlias -s Benefit -f $paths.RetireUpdate -w 45 --line-ending CRLF

Write-Host "Migration complete."
Write-Host "Artifacts:"
Write-Host "  $($paths.BenefitTypeUpsert)"
Write-Host "  $($paths.BenefitUpsert)"
Write-Host "  $($paths.RetireUpdate)"
Write-Host "  $($paths.Unmapped)"
