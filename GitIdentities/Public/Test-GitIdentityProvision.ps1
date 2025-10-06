function Test-GitIdentityProvision {
<#
.SYNOPSIS
Tests Git identity provisioning status.
.DESCRIPTION
Reports what artifacts exist or are missing for a given alias: state entry, alias gitconfig, SSH key pair, SSH host block, includeIf entries.
.PARAMETER Alias
Identity alias to test.
.PARAMETER User
Windows user profile (defaults to current user).
.EXAMPLE
Test-GitIdentityProvision -Alias work
#>
    param(
        [Parameter(Mandatory)][string]$Alias,
        [string]$User
    )
    
    $userHome = Get-GIUserHome -User $User
    $result = [ordered]@{
        alias = $Alias
        userHome = $userHome
        stateFile = $false
        stateEntry = $false
        aliasGitConfig = $false
        sshPrivateKey = $false
        sshPublicKey = $false
        sshHostBlock = $false
        includeIfBlocks = 0
        missing = @()
    }
    
    # Check state file and entry
    $statePath = Join-Path $userHome '.gitidentities.json'
    if (Test-Path -LiteralPath $statePath) {
        $result.stateFile = $true
        try {
            $state = Get-Content -LiteralPath $statePath -Raw -Encoding UTF8 | ConvertFrom-Json
            if ($state | Where-Object { $_.alias -eq $Alias }) {
                $result.stateEntry = $true
            } else {
                $result.missing += 'stateEntry'
            }
        } catch {
            $result.missing += 'stateEntry (parse error)'
        }
    } else {
        $result.missing += 'stateFile'
        $result.missing += 'stateEntry'
    }
    
    # Check alias gitconfig
    $aliasConfigPath = Join-Path $userHome ".gitconfig-$Alias"
    if (Test-Path -LiteralPath $aliasConfigPath) {
        $result.aliasGitConfig = $true
    } else {
        $result.missing += 'aliasGitConfig'
    }
    
    # Check SSH keys
    $sshDir = Join-Path $userHome '.ssh'
    $privateKey = Join-Path $sshDir "id_$Alias"
    $publicKey = "$privateKey.pub"
    if (Test-Path -LiteralPath $privateKey) {
        $result.sshPrivateKey = $true
    } else {
        $result.missing += 'sshPrivateKey'
    }
    if (Test-Path -LiteralPath $publicKey) {
        $result.sshPublicKey = $true
    } else {
        $result.missing += 'sshPublicKey'
    }
    
    # Check SSH host block
    $sshConfig = Join-Path $sshDir 'config'
    if (Test-Path -LiteralPath $sshConfig) {
        $configLines = Get-Content -LiteralPath $sshConfig -Encoding UTF8
        $marker = "# managed-by: gitidentities-module alias=$Alias"
        if ($configLines | Where-Object { $_ -like "*$marker*" }) {
            $result.sshHostBlock = $true
        } else {
            $result.missing += 'sshHostBlock'
        }
    } else {
        $result.missing += 'sshHostBlock'
    }
    
    # Check includeIf blocks
    $globalGit = Join-Path $userHome '.gitconfig'
    if (Test-Path -LiteralPath $globalGit) {
        $globalLines = Get-Content -LiteralPath $globalGit -Encoding UTF8
        $includeMarker = "# managed-by: gitidentities-module alias=$Alias"
        $result.includeIfBlocks = ($globalLines | Where-Object { $_ -like "*$includeMarker*folder=*" }).Count
    }
    if ($result.includeIfBlocks -eq 0) {
        $result.missing += 'includeIfBlocks'
    }
    
    return [pscustomobject]$result
}