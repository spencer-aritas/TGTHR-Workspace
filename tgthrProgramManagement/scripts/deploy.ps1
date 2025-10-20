param(
    [string]$alias = 'benefits',
    [string]$testLevel = ''
)

# Simple deploy wrapper
Write-Host "Deploying to org: $alias"
if ([string]::IsNullOrWhiteSpace($testLevel)) {
    sf project deploy start -o $alias
} else {
    sf project deploy start -o $alias --test-level $testLevel
}
