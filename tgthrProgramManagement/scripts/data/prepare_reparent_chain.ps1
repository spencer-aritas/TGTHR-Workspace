$old1='11WVY000000GC212AG'
$old2='11WVY000000GC0P2AW'
$new='11WVY000005ea9y2AA'

# 1) Build base map from successfully inserted clones (Anything_else__c = MIG:<oldId>)
# Anything_else__c isn't filterable in this org; pull target program enrollments and filter in script.
sf data query -o tgthrnpc-prod -q "SELECT Id,Anything_else__c,AccountId,ContactId FROM ProgramEnrollment WHERE ProgramId='$new'" --result-format csv > scripts/data/new_enrollments_mig_map.csv
$oldToNew = @{}
$migRows = Import-Csv scripts/data/new_enrollments_mig_map.csv
foreach($r in $migRows){
  if($r.Anything_else__c -like 'MIG:*'){
    $oldId = $r.Anything_else__c.Substring(4)
    $oldToNew[$oldId] = $r.Id
  }
}

# 2) Fallback mapping for failed clone rows: map by existing enrolled account in new program
$failedRows = Import-Csv 750VY00000gkeKDYAY-failed-records.csv
$failedWithAccount = $failedRows | Where-Object { $_.AccountId -and $_.AccountId.Trim() -ne '' }
$failedNoAccount = $failedRows | Where-Object { -not $_.AccountId -or $_.AccountId.Trim() -eq '' }
$acctIds = $failedWithAccount | Select-Object -ExpandProperty AccountId -Unique
if($acctIds.Count -gt 0){
  $acctIn = ($acctIds | ForEach-Object { "'$_'" }) -join ','
  sf data query -o tgthrnpc-prod -q "SELECT Id,AccountId,Status,StartDate,CreatedDate FROM ProgramEnrollment WHERE ProgramId='$new' AND AccountId IN ($acctIn) AND Status='Enrolled' ORDER BY CreatedDate DESC" --result-format csv > scripts/data/new_enrollments_existing_accounts.csv
  $existing = Import-Csv scripts/data/new_enrollments_existing_accounts.csv
  $pickByAcct = @{}
  foreach($e in $existing){
    if(-not $pickByAcct.ContainsKey($e.AccountId)){
      $pickByAcct[$e.AccountId] = $e.Id
    }
  }
  foreach($f in $failedWithAccount){
    if($f.Anything_else__c -like 'MIG:*'){
      $oldId = $f.Anything_else__c.Substring(4)
      if(-not $oldToNew.ContainsKey($oldId) -and $pickByAcct.ContainsKey($f.AccountId)){
        $oldToNew[$oldId] = $pickByAcct[$f.AccountId]
      }
    }
  }
}

# Save mapping for audit
$mapOut = New-Object System.Collections.Generic.List[object]
foreach($k in $oldToNew.Keys){
  $mapOut.Add([PSCustomObject]@{ OldProgramEnrollmentId=$k; NewProgramEnrollmentId=$oldToNew[$k] })
}
$mapOut | Export-Csv scripts/data/old_to_new_enrollment_map.csv -NoTypeInformation

# 3) Build Benefit name -> new Benefit Id map
sf data query -o tgthrnpc-prod -q "SELECT Id,Name FROM Benefit WHERE ProgramId='$new'" --result-format csv > scripts/data/new_program_benefits_map.csv
$benefitMap = @{}
foreach($b in (Import-Csv scripts/data/new_program_benefits_map.csv)){
  if(-not $benefitMap.ContainsKey($b.Name)){
    $benefitMap[$b.Name] = $b.Id
  }
}

# 4) Query assignments in source scope and prepare updates
sf data query -o tgthrnpc-prod -q "SELECT Id,ProgramEnrollmentId,BenefitId,Benefit.Name FROM BenefitAssignment WHERE ProgramEnrollment.ProgramId IN ('$old1','$old2') AND ProgramEnrollment.Status='Enrolled'" --result-format csv > scripts/data/source_assignments_scope.csv
$assignments = Import-Csv scripts/data/source_assignments_scope.csv
$assignUpd = New-Object System.Collections.Generic.List[object]
$missingBenefit = New-Object System.Collections.Generic.HashSet[string]
$missingMapAssignments = 0
foreach($a in $assignments){
  $oldPe = $a.ProgramEnrollmentId
  if(-not $oldToNew.ContainsKey($oldPe)){
    $missingMapAssignments++
    continue
  }
  $bn = $a.'Benefit.Name'
  if(-not $bn -or -not $benefitMap.ContainsKey($bn)){
    if($bn){ $null = $missingBenefit.Add($bn) }
    continue
  }
  $assignUpd.Add([PSCustomObject]@{ Id=$a.Id; ProgramEnrollmentId=$oldToNew[$oldPe]; BenefitId=$benefitMap[$bn] })
}
$assignUpd | Export-Csv scripts/data/assignment_reparent_updates.csv -NoTypeInformation

# 5) Query disbursements in source scope and prepare updates
sf data query -o tgthrnpc-prod -q "SELECT Id,ProgramEnrollmentId FROM BenefitDisbursement WHERE ProgramEnrollment.ProgramId IN ('$old1','$old2') AND ProgramEnrollment.Status='Enrolled'" --result-format csv > scripts/data/source_disbursements_scope.csv
$disb = Import-Csv scripts/data/source_disbursements_scope.csv
$disbUpd = New-Object System.Collections.Generic.List[object]
$missingMapDisb = 0
foreach($d in $disb){
  $oldPe = $d.ProgramEnrollmentId
  if(-not $oldToNew.ContainsKey($oldPe)){
    $missingMapDisb++
    continue
  }
  $newPe = $oldToNew[$oldPe]
  if($newPe -ne $oldPe){
    $disbUpd.Add([PSCustomObject]@{ Id=$d.Id; ProgramEnrollmentId=$newPe })
  }
}
$disbUpd | Export-Csv scripts/data/disbursement_reparent_updates.csv -NoTypeInformation

Write-Host "Mapping count: $($oldToNew.Count) of 812"
Write-Host "Failed rows without AccountId: $($failedNoAccount.Count)"
Write-Host "Assignment updates prepared: $($assignUpd.Count), assignment rows missing enrollment map: $missingMapAssignments, missing benefit names: $($missingBenefit.Count)"
Write-Host "Disbursement updates prepared: $($disbUpd.Count), disbursement rows missing enrollment map: $missingMapDisb"
if($missingBenefit.Count -gt 0){
  ($missingBenefit | Select-Object -First 20) | ForEach-Object { Write-Host "Missing benefit name: $_" }
}
