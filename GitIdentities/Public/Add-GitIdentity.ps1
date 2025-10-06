function Add-GitIdentity {
<#
.SYNOPSIS
Adds or extends a Git/SSH identity.
.DESCRIPTION
Creates (or updates) per-alias git config, SSH key (optional), host block, and includeIf entries for provided folders.
.PARAMETER Alias
Identity alias (unique).
.PARAMETER Platform
Platform name (github|azure|gitlab|bitbucket). Default github.
.PARAMETER Name
Git user.name
.PARAMETER Email
Git user.email
.PARAMETER Username
Credential username for platform.
.PARAMETER Folders
One or more repository root folders (gitdir scope). If an existing identity exists, new folders are appended.
.PARAMETER User
Windows user profile (defaults to current user).
.PARAMETER ForceRegenKeys
Regenerate SSH key even if exists.
.PARAMETER DryRun
Simulate actions.
.PARAMETER FileLog
Enable file logging.
.PARAMETER Verbosity
Log verbosity (Silent|Error|Warn|Info|Debug).
.EXAMPLE
Add-GitIdentity -Alias work -Name "Jane Doe" -Email jane@corp.com -Username janed -Folders C:\Repos\Work1,C:\Repos\Work2
#>
    param(
    [Parameter(Mandatory)][string]$Alias,
    [string]$Platform,
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)][string]$Email,
        [Parameter(Mandatory)][string]$Username,
        [Parameter(Mandatory)][string[]]$Folders,
        [string]$User,
        [switch]$ForceRegenKeys,
        [switch]$DryRun,
        [switch]$FileLog,
        [ValidateSet('Silent','Error','Warn','Info','Debug')][string]$Verbosity = 'Info'
    )

    $script:GitIdentitiesVerbosity = $Verbosity
    $userHome = Get-GIUserHome -User $User
    Set-GILogFile -UserHome $userHome -FileLog:$FileLog
    Write-GILog -Level INFO -Message "Adding identity $Alias"

    # Derivar plataforma si no se pasa explícitamente (regla minimal)
    if (-not $PSBoundParameters.ContainsKey('Platform') -or [string]::IsNullOrWhiteSpace($Platform)) {
        try {
            $derivedHost = Get-GIAliasCanonicalHost -Alias $Alias -Email $Email
            switch ($derivedHost.ToLowerInvariant()) {
                'github.com' { $Platform='github'; break }
                'dev.azure.com' { $Platform='azure'; break }
                'gitlab.com' { $Platform='gitlab'; break }
                'bitbucket.org' { $Platform='bitbucket'; break }
                default { $Platform = 'github' } # fallback conservador
            }
            Write-GILog -Level DEBUG -Message "Derived platform=$Platform from host=$derivedHost"
        } catch { Write-GILog -Level DEBUG -Message "Platform derivation fallback: $($_.Exception.Message)"; if (-not $Platform) { $Platform='github' } }
    }

    # Normalize folders
    $normalized = @()
    foreach ($f in $Folders) { $nf = Get-GINormalizedFolderPath -Path $f; if ($nf) { $normalized += $nf } }
    if ($normalized.Count -eq 0) { throw 'No valid folders provided.' }

    # Load or build identities state file (module uses its own JSON store under user home)
    $statePath = Join-Path $userHome '.gitidentities.json'
    $state = @()
    if (Test-Path -LiteralPath $statePath) { $state = (Get-Content -LiteralPath $statePath -Raw -Encoding UTF8 | ConvertFrom-Json) }
    if (-not ($state | Where-Object { $_.alias -eq $Alias })) {
    $new = [pscustomobject]@{ alias=$Alias; platform=$Platform; name=$Name; email=$Email; username=$Username; folders=@($normalized) }
        $state = @($state) + @($new)
    } else {
        foreach ($id in $state) {
            if ($id.alias -eq $Alias) {
                # Merge folders
                $merged = @($id.folders + $normalized) | Select-Object -Unique
                $id.folders = $merged
                # Update core fields (name/email/username/platform) in case changed
                $id.name = $Name; $id.email=$Email; $id.username=$Username; $id.platform=$Platform
            }
        }
    }

    # Escritura del estado (separada para claridad)
    if ($DryRun) {
        Write-GILog -Level CHANGE -Message "[DryRun] Would update state file $statePath"
    } else {
        $json = ($state | ConvertTo-Json -Depth 6)
        [IO.File]::WriteAllText($statePath,$json,[System.Text.UTF8Encoding]::new($false))
        Write-GILog -Level CHANGE -Message "State file updated: $statePath"
    }

    # Reuse setup logic by calling internal composite function (implemented later) or replicate minimal actions (placeholder now)
    # TODO: integrate with full Setup function extraction.
    # Aprovisionar artefactos en carpeta usuario
    try {
        # Configure Windows Credential Manager if needed
        Set-GICredentialHelper -UserHome $userHome -DryRun:$DryRun

        $aliasCfg = Set-GIAliasGitConfig -UserHome $userHome -Alias $Alias -Name $Name -Email $Email -Username $Username -DryRun:$DryRun
        Write-GILog -Level DEBUG -Message "Alias gitconfig ensured: $aliasCfg"
        Set-GIIncludeIfBlocks -UserHome $userHome -Alias $Alias -Folders $normalized -DryRun:$DryRun
        $keyPath = Set-GISshKey -UserHome $userHome -Alias $Alias -Email $Email -Force:$ForceRegenKeys -DryRun:$DryRun
        Set-GISshHostBlock -UserHome $userHome -Alias $Alias -Platform $Platform -DryRun:$DryRun | Out-Null
    } catch {
        Write-GILog -Level ERROR -Message "Provisioning error: $($_.Exception.Message)"
    }
    Write-GILog -Level INFO -Message 'Provisioning steps executed.'
}
