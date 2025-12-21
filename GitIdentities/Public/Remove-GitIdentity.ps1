function Remove-GitIdentity {
<#!
.SYNOPSIS
Removes an identity completely or a single folder.
#>
  [CmdletBinding(SupportsShouldProcess,ConfirmImpact='Medium')]
  param(
    [Parameter(Mandatory)][string]$Alias,
    [string]$Folder,
    [string]$User,
    [switch]$DryRun,
    [ValidateSet('Silent','Error','Warn','Info','Debug')][string]$Verbosity='Warn'
  )
  $script:GitIdentitiesVerbosity = $Verbosity
  $userHome = Get-GIUserHome -User $User
  $statePath = Join-Path $userHome '.gitidentities.json'
  $stateExists = Test-Path -LiteralPath $statePath
  if (-not $stateExists) { Write-GILog -Level WARN -Message 'No state file; proceeding to remove artefacts only.'; $state = @() } else { $state = Get-Content -LiteralPath $statePath -Raw -Encoding UTF8 | ConvertFrom-Json }
  $found = $state | Where-Object { $_.alias -eq $Alias }
  if (-not $found) { Write-GILog -Level WARN -Message "Alias $Alias not found"; return }
  if ($Folder) {
    $norm = Get-GINormalizedFolderPath -Path $Folder
    if ($PSCmdlet.ShouldProcess($norm,"Remove folder from identity $Alias")) {
      foreach ($id in $state) { if ($id.alias -eq $Alias) { $id.folders = @($id.folders | Where-Object { $_ -ne $norm }) } }
      if ($DryRun) {
        Write-GILog -Level CHANGE -Message "[DryRun] Would remove folder $norm from $Alias"
      } else {
        if ($stateExists) { [IO.File]::WriteAllText($statePath,($state | ConvertTo-Json -Depth 6),[System.Text.UTF8Encoding]::new($false)) }
        Write-GILog -Level CHANGE -Message "Removed folder $norm from $Alias"
      }
      # Remove includeIf block for that folder
      Remove-GIIncludeIfBlocks -UserHome $userHome -Alias $Alias -Folders @($norm) -DryRun:$DryRun
    }
  } else {
    if ($PSCmdlet.ShouldProcess($Alias,'Remove entire identity')) {
      $state = @($state | Where-Object { $_.alias -ne $Alias })
      if ($DryRun) {
        Write-GILog -Level CHANGE -Message "[DryRun] Would remove identity $Alias"
      } else {
        if ($stateExists) { [IO.File]::WriteAllText($statePath,($state | ConvertTo-Json -Depth 6),[System.Text.UTF8Encoding]::new($false)) }
        Write-GILog -Level CHANGE -Message "Removed identity $Alias"
      }
      # Artefacts (no borramos clave para no ser destructivos)
      Remove-GIIncludeIfBlocks -UserHome $userHome -Alias $Alias -All -DryRun:$DryRun
      Remove-GISshHostBlock -UserHome $userHome -Alias $Alias -DryRun:$DryRun
      $aliasCfg = Join-Path $userHome ".gitconfig-$Alias"
      if (Test-Path -LiteralPath $aliasCfg) {
        if ($PSCmdlet.ShouldProcess($aliasCfg,'Delete alias gitconfig file')) {
          if ($DryRun) { Write-GILog -Level CHANGE -Message "[DryRun] Would delete $aliasCfg" } else { Remove-Item -LiteralPath $aliasCfg -Force; Write-GILog -Level CHANGE -Message "Deleted $aliasCfg" }
        }
      }
    }
  }
}
