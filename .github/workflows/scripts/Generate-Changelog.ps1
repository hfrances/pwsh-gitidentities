param(
    [string]$OutputPath = "release_notes.txt",
    [string]$RepoOwner,
    [string]$RepoName,
    [string]$Version,
    [bool]$IsPrerelease = $false
)

Write-Host "=== Generating Changelog ==="

# Get current tag from environment or git
$currentTag = if ($env:GITHUB_REF -match 'refs/tags/(.+)') { $matches[1] } else { git describe --tags --abbrev=0 }
Write-Host "Current tag: $currentTag"

# Get previous tag
$previousTag = git describe --tags --abbrev=0 "$currentTag^" 2>$null
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

"@

if (-not $IsPrerelease -and $Version) {
    $releaseNotes += @"
Or install directly from PowerShell Gallery:

``````powershell
Install-Module -Name GitIdentities -RequiredVersion $Version
``````

"@
}

$releaseNotes += @"

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

Full Changelog: https://github.com/$RepoOwner/$RepoName/commits/$currentTag
"@

$releaseNotes | Out-File -FilePath $OutputPath -Encoding utf8
Write-Host "✓ Release notes generated: $OutputPath"
