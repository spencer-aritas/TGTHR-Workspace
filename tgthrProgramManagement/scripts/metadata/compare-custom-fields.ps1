param(
    [string]$SandboxAlias = "benefits",
    [string]$ProdAlias = "tgthrnpc-prod",
    [string]$OutputCsv = "scripts/data/missing_custom_fields.csv"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
$PSNativeCommandUseErrorActionPreference = $false

function Get-CustomFieldsForObject {
    param(
        [Parameter(Mandatory = $true)]
        [string]$OrgAlias,
        [Parameter(Mandatory = $true)]
        [string]$ObjectApiName
    )

    $previousErrorAction = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    $raw = & sf data query -o $OrgAlias -q "SELECT DeveloperName FROM CustomField WHERE TableEnumOrId='$ObjectApiName'" --use-tooling-api --result-format csv 2>&1
    $ErrorActionPreference = $previousErrorAction

    $lines = $raw |
        ForEach-Object { $_.ToString().Trim() } |
        Where-Object {
            $_ -and
            $_ -ne 'Querying Data... done' -and
            $_ -notmatch '^ERROR at Row:' -and
            $_ -notmatch '^No such column' -and
            $_ -notmatch '^Warning:'
        }

    $fields = $lines |
        Where-Object { $_ -eq 'DeveloperName' -or $_ -eq '"DeveloperName"' -or $_ -match '^[A-Za-z0-9_]+$' } |
        Select-Object -Skip 1 |
        ForEach-Object { "{0}__c" -f $_.Trim('"') } |
        Where-Object { $_ }

    return @($fields)
}

$projectRoot = Resolve-Path (Join-Path $PSScriptRoot "..\..")
Set-Location $projectRoot

$outputDir = Split-Path -Parent $OutputCsv
if ($outputDir -and -not (Test-Path $outputDir)) {
    New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
}

$objectsPath = Join-Path $projectRoot "force-app/main/default/objects"
if (-not (Test-Path $objectsPath)) {
    throw "Could not find objects directory at $objectsPath"
}

$objects = Get-ChildItem -Path $objectsPath -Directory |
    Where-Object { $_.Name -notmatch "__mdt$" } |
    Select-Object -ExpandProperty Name

$missing = New-Object System.Collections.Generic.List[Object]

foreach ($obj in $objects) {
    $sandboxFields = Get-CustomFieldsForObject -OrgAlias $SandboxAlias -ObjectApiName $obj
    $prodFields = Get-CustomFieldsForObject -OrgAlias $ProdAlias -ObjectApiName $obj

    if (-not $sandboxFields -and -not $prodFields) {
        continue
    }

    foreach ($field in $sandboxFields) {
        if ($field -notin $prodFields) {
            $missing.Add([PSCustomObject]@{
                Object = $obj
                Field = $field
            })
        }
    }
}

if ($missing.Count -eq 0) {
    "No sandbox custom fields are missing in prod for tracked objects." | Write-Host
    if (Test-Path $OutputCsv) {
        Remove-Item $OutputCsv -Force
    }
    exit 0
}

$sorted = @(
    $missing |
        Sort-Object Object, Field
)

$sorted | Export-Csv -Path $OutputCsv -NoTypeInformation

"Missing custom fields found: $($sorted.Count)" | Write-Host
"CSV written: $OutputCsv" | Write-Host
$sorted | Format-Table -AutoSize
