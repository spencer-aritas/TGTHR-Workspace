param(
  [switch]$Execute
)

$ErrorActionPreference = 'Stop'

$sbAlias = 'benefits'
$prodAlias = 'tgthrnpc-prod'

$sbProgram1440 = '11WVY000000GC6r2AG'
$sbProgramNest = '11WVY000000GC3d2AG'
$sbProgramDropIn = '11WRT0000017pV32AI'

$prodProgram1440 = '11WVY000000GC6r2AG'
$prodProgramNest = '11WVY000000GC3d2AG'
$prodProgramDropIn = '11WVY000005ea9y2AA'

$programMap = @{
  $sbProgram1440 = $prodProgram1440
  $sbProgramNest = $prodProgramNest
  $sbProgramDropIn = $prodProgramDropIn
}

# Pull canonical sandbox benefits
sf data query -o $sbAlias -q "SELECT Id,Name,ProgramId,IsActive,BenefitTypeId,Available_for_Clinical__c,Available_for_Peer__c,Available_for_Case_Management__c,BenefitType.Name,BenefitType.ProcessType,BenefitType.UnitofMeasure.Name FROM Benefit WHERE ProgramId IN ('$sbProgram1440','$sbProgramNest','$sbProgramDropIn')" --result-format csv > scripts/data/sb_benefits_canonical_sync.csv
$sbBenefits = Import-Csv scripts/data/sb_benefits_canonical_sync.csv

# Pull prod target benefits
sf data query -o $prodAlias -q "SELECT Id,Name,ProgramId,IsActive,BenefitTypeId,CreatedDate FROM Benefit WHERE ProgramId IN ('$prodProgram1440','$prodProgramNest','$prodProgramDropIn')" --result-format csv > scripts/data/prod_benefits_sync_scope.csv
$prodBenefits = Import-Csv scripts/data/prod_benefits_sync_scope.csv

# Pull benefit type catalogs for mapping sandbox BT -> prod BT by Name/ProcessType/UOM
sf data query -o $sbAlias -q "SELECT Id,Name,ProcessType,UnitofMeasure.Name FROM BenefitType" --result-format csv > scripts/data/sb_benefit_types_for_sync.csv
sf data query -o $prodAlias -q "SELECT Id,Name,ProcessType,UnitofMeasure.Name FROM BenefitType" --result-format csv > scripts/data/prod_benefit_types_for_sync.csv
$sbTypes = Import-Csv scripts/data/sb_benefit_types_for_sync.csv
$prodTypes = Import-Csv scripts/data/prod_benefit_types_for_sync.csv

$prodTypeByComposite = @{}
foreach($pt in $prodTypes){
  $k = "{0}|{1}|{2}" -f $pt.Name, $pt.ProcessType, $pt.'UnitofMeasure.Name'
  if(-not $prodTypeByComposite.ContainsKey($k)){
    $prodTypeByComposite[$k] = $pt.Id
  }
}

# Build canonical target set keyed by prod ProgramId + Name
$canonicalByProgramName = @{}
$missingTypeMappings = New-Object System.Collections.Generic.HashSet[string]

foreach($sb in $sbBenefits){
  if(-not $programMap.ContainsKey($sb.ProgramId)){
    continue
  }

  $targetProgramId = $programMap[$sb.ProgramId]
  $typeComposite = "{0}|{1}|{2}" -f $sb.'BenefitType.Name', $sb.'BenefitType.ProcessType', $sb.'BenefitType.UnitofMeasure.Name'

  if(-not $prodTypeByComposite.ContainsKey($typeComposite)){
    $null = $missingTypeMappings.Add($typeComposite)
    continue
  }

  $key = "{0}|{1}" -f $targetProgramId, $sb.Name
  if(-not $canonicalByProgramName.ContainsKey($key)){
    $canonicalByProgramName[$key] = [PSCustomObject]@{
      Name = $sb.Name
      ProgramId = $targetProgramId
      BenefitTypeId = $prodTypeByComposite[$typeComposite]
      IsActive = 'true'
      Available_for_Clinical__c = $sb.Available_for_Clinical__c
      Available_for_Peer__c = $sb.Available_for_Peer__c
      Available_for_Case_Management__c = $sb.Available_for_Case_Management__c
    }
  }
}

if($missingTypeMappings.Count -gt 0){
  Write-Host "Missing BenefitType mappings in prod: $($missingTypeMappings.Count)"
  $missingTypeMappings | Select-Object -First 30 | ForEach-Object { Write-Host "  $_" }
  throw 'Cannot continue until missing BenefitType mappings are resolved.'
}

# Group existing prod benefits by ProgramId+Name
$prodGroups = @{}
foreach($pb in $prodBenefits){
  $k = "{0}|{1}" -f $pb.ProgramId, $pb.Name
  if(-not $prodGroups.ContainsKey($k)){
    $prodGroups[$k] = New-Object System.Collections.Generic.List[object]
  }
  $prodGroups[$k].Add($pb)
}

$updates = New-Object System.Collections.Generic.List[object]
$inserts = New-Object System.Collections.Generic.List[object]

# Activate/normalize canonical keys; deactivate duplicate rows for same key
foreach($key in $canonicalByProgramName.Keys){
  $canonical = $canonicalByProgramName[$key]

  if($prodGroups.ContainsKey($key)){
    $rows = $prodGroups[$key]

    # Keep one record (prefer active, else first)
    $keep = $rows | Where-Object { $_.IsActive -eq 'true' } | Select-Object -First 1
    if(-not $keep){ $keep = $rows | Select-Object -First 1 }

    $updates.Add([PSCustomObject]@{
      Id = $keep.Id
      IsActive = 'true'
      BenefitTypeId = $canonical.BenefitTypeId
      Available_for_Clinical__c = $canonical.Available_for_Clinical__c
      Available_for_Peer__c = $canonical.Available_for_Peer__c
      Available_for_Case_Management__c = $canonical.Available_for_Case_Management__c
    })

    foreach($r in $rows){
      if($r.Id -ne $keep.Id){
        $updates.Add([PSCustomObject]@{
          Id = $r.Id
          IsActive = 'false'
        })
      }
    }
  }
  else {
    $inserts.Add([PSCustomObject]@{
      Name = $canonical.Name
      ProgramId = $canonical.ProgramId
      BenefitTypeId = $canonical.BenefitTypeId
      IsActive = 'true'
      Available_for_Clinical__c = $canonical.Available_for_Clinical__c
      Available_for_Peer__c = $canonical.Available_for_Peer__c
      Available_for_Case_Management__c = $canonical.Available_for_Case_Management__c
    })
  }
}

# Deactivate all non-canonical prod benefits in scope
foreach($pb in $prodBenefits){
  $k = "{0}|{1}" -f $pb.ProgramId, $pb.Name
  if(-not $canonicalByProgramName.ContainsKey($k)){
    $updates.Add([PSCustomObject]@{
      Id = $pb.Id
      IsActive = 'false'
    })
  }
}

# Deduplicate updates by Id (last one wins)
$updatesById = @{}
foreach($u in $updates){
  $updatesById[$u.Id] = $u
}
$finalUpdates = $updatesById.Values

$finalUpdates | Export-Csv scripts/data/prod_benefits_sync_updates.csv -NoTypeInformation
$inserts | Export-Csv scripts/data/prod_benefits_sync_inserts.csv -NoTypeInformation

Write-Host "Canonical benefit keys from sandbox: $($canonicalByProgramName.Count)"
Write-Host "Prod benefits in scope (pre-sync): $($prodBenefits.Count)"
Write-Host "Prepared updates (activate/deactivate/normalize): $($finalUpdates.Count)"
Write-Host "Prepared inserts (missing canonical): $($inserts.Count)"

if(-not $Execute){
  Write-Host 'Dry run complete. Re-run with -Execute to apply updates/inserts.'
  exit 0
}

if($finalUpdates.Count -gt 0){
  sf data update bulk -o $prodAlias -s Benefit -f scripts/data/prod_benefits_sync_updates.csv -w 45 --line-ending CRLF
}

if($inserts.Count -gt 0){
  sf data import bulk -o $prodAlias -s Benefit -f scripts/data/prod_benefits_sync_inserts.csv -w 45 --line-ending CRLF
}

sf data query -o $prodAlias -q "SELECT ProgramId,COUNT(Id) total,SUM(CASE WHEN IsActive = true THEN 1 ELSE 0 END) activeCount FROM Benefit WHERE ProgramId IN ('$prodProgram1440','$prodProgramNest','$prodProgramDropIn') GROUP BY ProgramId" --result-format csv > scripts/data/prod_benefits_sync_post_counts.csv
Write-Host 'Sync complete. Post counts:'
Get-Content scripts/data/prod_benefits_sync_post_counts.csv
