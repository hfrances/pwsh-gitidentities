# Core reusable helpers
param()

# Platform map
$script:GIPlatformMap = @{
  'github' = @{ HostName='github.com'; CredentialHost='https://github.com/' }
  'azure' = @{ HostName='ssh.dev.azure.com'; CredentialHost='https://dev.azure.com/' }
  'gitlab' = @{ HostName='gitlab.com'; CredentialHost='https://gitlab.com/' }
  'bitbucket' = @{ HostName='bitbucket.org'; CredentialHost='https://bitbucket.org/' }
}
$script:GIManagedMarkerPrefix = '# managed-by: gitidentities-module'

function Get-GIUserHome {
  [CmdletBinding()] param([string]$User)
  if (-not $User) { $User = $env:USERNAME }
  $userHome = Join-Path -Path 'C:\Users' -ChildPath $User
  if (-not (Test-Path -LiteralPath $userHome)) { return $env:USERPROFILE }
  return $userHome
}

function Get-GINormalizedFolderPath {
  param([string]$Path)
  if (-not $Path) { return $null }
  $p = $Path -replace '\\','/'
  $p = $p.Trim('"')
  $p = [Environment]::ExpandEnvironmentVariables($p)
  if ($p -notmatch '/$') { $p+='/'}
  return $p
}

function Read-GIJsonConfig {
  param([string]$Path)
  if (-not (Test-Path -LiteralPath $Path)) { throw "Config JSON not found: $Path" }
  (Get-Content -LiteralPath $Path -Raw -Encoding UTF8) | ConvertFrom-Json
}

function Set-GIFileContentIfChanged {
  param([string]$Path,[string]$Content,[switch]$DryRun,[switch]$Backup)
  $needsWrite = $true
  if (Test-Path -LiteralPath $Path) {
    $existing = Get-Content -LiteralPath $Path -Raw -Encoding UTF8
    if ($existing -eq $Content) { $needsWrite = $false }
  }
  if (-not $needsWrite) { Write-GILog -Level DEBUG -Message "No changes: $Path"; return $false }
  if ($DryRun) { Write-GILog -Level CHANGE -Message "[DryRun] Would write: $Path"; return $true }
  if ($Backup -and (Test-Path -LiteralPath $Path)) { Copy-Item -LiteralPath $Path -Destination "$Path.$((Get-Date).ToString('yyyyMMdd-HHmmss')).bak" -Force }
  [IO.File]::WriteAllText($Path,$Content,[System.Text.UTF8Encoding]::new($false))
  Write-GILog -Level CHANGE -Message "File written: $Path"
  return $true
}
