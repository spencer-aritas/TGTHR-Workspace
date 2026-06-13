<#
.SYNOPSIS
  Migrates 5 InterviewTemplate__c records (+ active versions + questions)
  from the 'benefits' sandbox to 'tgthrnpc-prod'.

.DESCRIPTION
  Pipeline:
    1. Read source JSON exports (already done before running this script)
    2. Build + bulk-insert InterviewTemplate__c CSV → prod
    3. Query prod to get new template IDs (by UUID / Name)
    4. Build + bulk-insert InterviewTemplateVersion__c CSV (with remapped IDs)
    5. Query prod to get new version IDs
    6. Build + bulk-insert InterviewQuestion__c CSV (with remapped version IDs)
    7. Verify counts in prod
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$DIR   = $PSScriptRoot
$DEST  = 'tgthrnpc-prod'

# ─── helpers ───────────────────────────────────────────────────────────────────
function Escape-CSV($v) {
    if ($null -eq $v) { return '' }
    $s = "$v"
    if ($s -match '[",\r\n]') { return '"' + $s.Replace('"','""') + '"' }
    return $s
}

function Write-CSV($path, $headers, $rows) {
    $lines = @($headers -join ',')
    foreach ($r in $rows) {
        $lines += ($headers | ForEach-Object { Escape-CSV $r.$_ }) -join ','
    }
    Set-Content -Path $path -Value $lines -Encoding UTF8
    Write-Host "  Wrote $($rows.Count) rows → $path"
}

function Bulk-Insert($csv, $obj) {
    Write-Host "`n[INSERT] $obj from $csv"
    $result = sf data import bulk --file $csv --sobject $obj --target-org $DEST --wait 10 --json 2>&1 | ConvertFrom-Json
    if ($result.status -ne 0) {
        Write-Error "Bulk insert FAILED: $($result.message)"
    }
    Write-Host "  Job complete. Checking counts..."
}

function SF-Query($soql) {
    $r = sf data query --query $soql --target-org $DEST --json 2>&1 | ConvertFrom-Json
    if ($r.status -ne 0) { Write-Error "SOQL failed: $($r.message)" }
    return $r.result.records
}

# ─── 1. Load source exports ─────────────────────────────────────────────────────
Write-Host "`n=== Loading source exports ==="
$srcTemplates = (Get-Content "$DIR\src_templates.json" -Raw | ConvertFrom-Json).result.records
$srcVersions  = (Get-Content "$DIR\src_versions.json"  -Raw | ConvertFrom-Json).result.records
$srcQuestions = (Get-Content "$DIR\src_questions.json" -Raw | ConvertFrom-Json).result.records

Write-Host "  Templates : $($srcTemplates.Count)"
Write-Host "  Versions  : $($srcVersions.Count)"
Write-Host "  Questions : $($srcQuestions.Count)"

# ─── 2. Build & insert InterviewTemplate__c ────────────────────────────────────
Write-Host "`n=== Step 1: Insert InterviewTemplate__c ==="

$tplHeaders = @(
    'Name','Category__c','Active__c','Available_for_Mobile__c',
    'Allow_Benefits_Disbursement__c','Allow_Goal_Assignment__c','Allow_Diagnoses__c',
    'Add_Staff_Signature_Block__c','Diagnoses_Policy__c','Goals_Policy__c',
    'Staff_Signature_Policy__c','Client_Signature_Policy__c',
    'Housing_Benefit_Policy__c','Clinical_Benefit_Policy__c',
    'Income_Benefits_Policy__c','Demographics_Policy__c',
    'Consent_Required__c','Data_Retention_Days__c','Clinical__c',
    'cpt_note_type__c','has_cpt_codes__c','UUID__c'
)

$tplRows = $srcTemplates | ForEach-Object {
    [PSCustomObject]@{
        Name                         = $_.Name
        Category__c                  = $_.Category__c
        Active__c                    = $_.Active__c
        Available_for_Mobile__c      = $_.Available_for_Mobile__c
        Allow_Benefits_Disbursement__c = $_.Allow_Benefits_Disbursement__c
        Allow_Goal_Assignment__c     = $_.Allow_Goal_Assignment__c
        Allow_Diagnoses__c           = $_.Allow_Diagnoses__c
        Add_Staff_Signature_Block__c = $_.Add_Staff_Signature_Block__c
        Diagnoses_Policy__c          = $_.Diagnoses_Policy__c
        Goals_Policy__c              = $_.Goals_Policy__c
        Staff_Signature_Policy__c    = $_.Staff_Signature_Policy__c
        Client_Signature_Policy__c   = $_.Client_Signature_Policy__c
        Housing_Benefit_Policy__c    = $_.Housing_Benefit_Policy__c
        Clinical_Benefit_Policy__c   = $_.Clinical_Benefit_Policy__c
        Income_Benefits_Policy__c    = $_.Income_Benefits_Policy__c
        Demographics_Policy__c       = $_.Demographics_Policy__c
        Consent_Required__c          = $_.Consent_Required__c
        Data_Retention_Days__c       = $_.Data_Retention_Days__c
        Clinical__c                  = $_.Clinical__c
        cpt_note_type__c             = $_.cpt_note_type__c
        has_cpt_codes__c             = $_.has_cpt_codes__c
        UUID__c                      = $_.UUID__c
    }
}

$tplCsv = "$DIR\import_templates.csv"
Write-CSV $tplCsv $tplHeaders $tplRows
Bulk-Insert $tplCsv 'InterviewTemplate__c'

# ─── 3. Query prod for new template IDs ────────────────────────────────────────
Write-Host "`n=== Step 2: Fetch new template IDs from prod ==="

$nameList = ($srcTemplates.Name | ForEach-Object { "'$_'" }) -join ','
$prodTemplates = SF-Query "SELECT Id, Name FROM InterviewTemplate__c WHERE Name IN ($nameList)"

# Build old-ID → new-ID map keyed by Name
$tplMap = @{}
foreach ($t in $srcTemplates) {
    $match = $prodTemplates | Where-Object { $_.Name -eq $t.Name } | Select-Object -First 1
    if ($null -eq $match) { Write-Error "No prod record found for template: $($t.Name)" }
    $tplMap[$t.Id] = $match.Id
    Write-Host "  $($t.Name): $($t.Id) → $($match.Id)"
}

# ─── 4. Build & insert InterviewTemplateVersion__c ────────────────────────────
Write-Host "`n=== Step 3: Insert InterviewTemplateVersion__c ==="

$verHeaders = @(
    'Name','InterviewTemplate__c','Version__c','Status__c',
    'Effective_From__c','Effective_To__c','Variant__c','UUID__c'
)

$verRows = $srcVersions | ForEach-Object {
    $newTplId = $tplMap[$_.InterviewTemplate__c]
    if ($null -eq $newTplId) { Write-Error "No template mapping for version: $($_.Name)" }
    [PSCustomObject]@{
        Name                  = $_.Name
        InterviewTemplate__c  = $newTplId
        Version__c            = $_.Version__c
        Status__c             = $_.Status__c
        Effective_From__c     = $_.Effective_From__c
        Effective_To__c       = $_.Effective_To__c
        Variant__c            = $_.Variant__c
        UUID__c               = $_.UUID__c
    }
}

$verCsv = "$DIR\import_versions.csv"
Write-CSV $verCsv $verHeaders $verRows
Bulk-Insert $verCsv 'InterviewTemplateVersion__c'

# ─── 5. Query prod for new version IDs ────────────────────────────────────────
Write-Host "`n=== Step 4: Fetch new version IDs from prod ==="

$verNameList = ($srcVersions.Name | ForEach-Object { "'$_'" }) -join ','
$prodVersions = SF-Query "SELECT Id, Name FROM InterviewTemplateVersion__c WHERE Name IN ($verNameList)"

$verMap = @{}
foreach ($v in $srcVersions) {
    $match = $prodVersions | Where-Object { $_.Name -eq $v.Name } | Select-Object -First 1
    if ($null -eq $match) { Write-Error "No prod record found for version: $($v.Name)" }
    $verMap[$v.Id] = $match.Id
    Write-Host "  $($v.Name): $($v.Id) → $($match.Id)"
}

# ─── 6. Build & insert InterviewQuestion__c ────────────────────────────────────
Write-Host "`n=== Step 5: Insert InterviewQuestion__c ($($srcQuestions.Count) questions) ==="

$qHeaders = @(
    'Name','InterviewTemplateVersion__c','Section__c','Order__c','API_Name__c',
    'Label__c','Help_Text__c','Response_Type__c','Picklist_Values__c',
    'Required__c','Sensitive__c','Score_Weight__c','Maps_To__c',
    'UUID__c','Status__c','Question_Text__c','Version_Number__c',
    'Validation_Rule__c','Visibility_Rules__c','Data_Binding__c',
    'Protected__c','Compliance_Flags__c','Field_Set_Group__c',
    'Allow_Carry_Forward__c','Requires_Review__c'
)

$qRows = $srcQuestions | ForEach-Object {
    $newVerId = $verMap[$_.InterviewTemplateVersion__c]
    if ($null -eq $newVerId) { Write-Error "No version mapping for question: $($_.Name)" }
    [PSCustomObject]@{
        Name                         = $_.Name
        InterviewTemplateVersion__c  = $newVerId
        Section__c                   = $_.Section__c
        Order__c                     = $_.Order__c
        API_Name__c                  = $_.API_Name__c
        Label__c                     = $_.Label__c
        Help_Text__c                 = $_.Help_Text__c
        Response_Type__c             = $_.Response_Type__c
        Picklist_Values__c           = $_.Picklist_Values__c
        Required__c                  = $_.Required__c
        Sensitive__c                 = $_.Sensitive__c
        Score_Weight__c              = $_.Score_Weight__c
        Maps_To__c                   = $_.Maps_To__c
        UUID__c                      = $_.UUID__c
        Status__c                    = $_.Status__c
        Question_Text__c             = $_.Question_Text__c
        Version_Number__c            = $_.Version_Number__c
        Validation_Rule__c           = $_.Validation_Rule__c
        Visibility_Rules__c          = $_.Visibility_Rules__c
        Data_Binding__c              = $_.Data_Binding__c
        Protected__c                 = $_.Protected__c
        Compliance_Flags__c          = $_.Compliance_Flags__c
        Field_Set_Group__c           = $_.Field_Set_Group__c
        Allow_Carry_Forward__c       = $_.Allow_Carry_Forward__c
        Requires_Review__c           = $_.Requires_Review__c
    }
}

$qCsv = "$DIR\import_questions.csv"
Write-CSV $qCsv $qHeaders $qRows
Bulk-Insert $qCsv 'InterviewQuestion__c'

# ─── 7. Verify ─────────────────────────────────────────────────────────────────
Write-Host "`n=== Step 6: Verify prod ==="

$newTplIds = ($prodTemplates.Id | ForEach-Object { "'$_'" }) -join ','
$tCount = (SF-Query "SELECT COUNT(Id) cnt FROM InterviewTemplate__c WHERE Id IN ($newTplIds)")[0].cnt
Write-Host "  InterviewTemplate__c in prod    : $tCount"

$newVerIds = ($prodVersions.Id | ForEach-Object { "'$_'" }) -join ','
$vCount = (SF-Query "SELECT COUNT(Id) cnt FROM InterviewTemplateVersion__c WHERE Id IN ($newVerIds)")[0].cnt
Write-Host "  InterviewTemplateVersion__c     : $vCount"

# Verify via getActiveTemplates logic (same query the LWC uses)
$activeVers = SF-Query "SELECT Id, Name, InterviewTemplate__r.Name, Status__c FROM InterviewTemplateVersion__c WHERE InterviewTemplate__r.Active__c = true AND Status__c = 'Active' AND InterviewTemplate__c IN ($newTplIds)"
Write-Host "`n  Active versions visible to documentationHub LWC:"
foreach ($av in $activeVers) {
    Write-Host "    ✓ $($av.'InterviewTemplate__r'.Name) → $($av.Name)"
}

Write-Host "`n=== Migration complete! ==="
Write-Host "Treatment Plan, Drop-In, Psycho-Social, Comprehensive Clinical, and Casey Life Skills"
Write-Host "are now live in tgthrnpc-prod. Documentation Hub buttons should be enabled."
