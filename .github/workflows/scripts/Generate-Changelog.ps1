param(
    [string]$OutputPath = "release_notes.txt"
)

Write-Host "=== Generating Changelog ==="

# Get previous tag
$previousTag = git describe --tags --abbrev=0 2>$null
if ($previousTag) {
    $commits = git log "$previousTag..HEAD" --format="%s"
    Write-Host "Commits since $previousTag"
} else {
    $commits = git log --format="%s"
    Write-Host "All commits"
}

$features = @()
$fixes = @()
$improvements = @()
$other = @()

foreach ($commit in $commits) {
    if ($commit -match '^feat:') {
        $features += $commit -replace '^feat:\s*', ''
    } elseif ($commit -match '^fix:') {
        $fixes += $commit -replace '^fix:\s*', ''
    } elseif ($commit -match '^improvement:|^perf:') {
        $improvements += $commit -replace '^(improvement|perf):\s*', ''
    } else {
        $other += $commit
    }
}

$releaseNotes = @"
## What's New

"@

if ($features.Count -gt 0) {
    $releaseNotes += @"
### Features
$($features | ForEach-Object { "- $_" } | Out-String)
"@
}

if ($fixes.Count -gt 0) {
    $releaseNotes += @"
### Fixes
$($fixes | ForEach-Object { "- $_" } | Out-String)
"@
}

if ($improvements.Count -gt 0) {
    $releaseNotes += @"
### Improvements
$($improvements | ForEach-Object { "- $_" } | Out-String)
"@
}

if ($other.Count -gt 0 -and $features.Count -eq 0 -and $fixes.Count -eq 0) {
    $releaseNotes += @"
### Changes
$($other | ForEach-Object { "- $_" } | Out-String)
"@
}

$releaseNotes += @"
## Installation

``````powershell
# Extract the ZIP to your PowerShell modules directory
# Then import the module:
Import-Module GitIdentities
``````

## Quick Start

``````powershell
# Add a new identity
Add-GitIdentity -Alias work -Name "Your Name" -Email work@company.com -Username workuser -Folders C:\Work\Repos

# List all identities  
Get-GitIdentities

# Test identity status
Test-GitIdentityProvision -Alias work
``````

See README.md for complete documentation.
"@

$releaseNotes | Out-File -FilePath $OutputPath -Encoding utf8
Write-Host "✓ Release notes generated: $OutputPath"
