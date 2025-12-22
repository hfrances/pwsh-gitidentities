function Remove-GitIdentity {
<#
.SYNOPSIS
Removes an identity completely or a single folder.
.DESCRIPTION
Removes identity artifacts: per-alias gitconfig, includeIf blocks from global gitconfig.
SSH keys are preserved for security reasons.
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
  
  # Check if alias gitconfig exists
  $aliasCfg = Join-Path $userHome ".gitconfig-$Alias"
  $aliasConfigExists = Test-Path -LiteralPath $aliasCfg
  
  if ($Folder) {
    $norm = Get-GINormalizedFolderPath -Path $Folder
    if ($PSCmdlet.ShouldProcess($norm,"Remove folder from identity $Alias")) {
      if ($DryRun) {
        Write-GILog -Level CHANGE -Message "[DryRun] Would remove folder $norm from $Alias"
      } else {
        Write-GILog -Level CHANGE -Message "Removed folder $norm from $Alias"
      }
      # Remove includeIf block for that folder
      Remove-GIIncludeIfBlocks -UserHome $userHome -Alias $Alias -Folders @($norm) -DryRun:$DryRun
    }
  } else {
    # Remove entire identity
    if (-not $aliasConfigExists) {
      Write-GILog -Level WARN -Message "Alias $Alias not found (no .gitconfig-$Alias exists)"
      return
    }
    
    if ($PSCmdlet.ShouldProcess($Alias,'Remove entire identity')) {
      if ($DryRun) {
        Write-GILog -Level CHANGE -Message "[DryRun] Would remove identity $Alias"
      } else {
        Write-GILog -Level CHANGE -Message "Removed identity $Alias"
      }
      
      # Remove includeIf blocks
      Remove-GIIncludeIfBlocks -UserHome $userHome -Alias $Alias -All -DryRun:$DryRun
      
      # Remove alias gitconfig file
      if (Test-Path -LiteralPath $aliasCfg) {
        if ($PSCmdlet.ShouldProcess($aliasCfg,'Delete alias gitconfig file')) {
          if ($DryRun) {
            Write-GILog -Level CHANGE -Message "[DryRun] Would delete $aliasCfg"
          } else {
            Remove-Item -LiteralPath $aliasCfg -Force
            Write-GILog -Level CHANGE -Message "Deleted $aliasCfg"
          }
        }
      }
      
      # Note: SSH keys are preserved for security reasons
      Write-GILog -Level INFO -Message "SSH keys preserved for security; remove manually if needed"
    }
  }
}
