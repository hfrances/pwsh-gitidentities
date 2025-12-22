function Test-GitIdentityProvision {
<#
.SYNOPSIS
Tests Git identity provisioning status.
.DESCRIPTION
Validates that all required artifacts exist for a given alias:
- Per-alias gitconfig file (~/.gitconfig-{alias})
- SSH key pair (private and public keys)
- includeIf entries in global ~/.gitconfig for all configured folders
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
        aliasGitConfig = $false
        sshPrivateKey = $false
        sshPublicKey = $false
        includeIfBlocks = 0
        missing = @()
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
        Write-Warning "SSH private key not found: $privateKey"
    }
    if (Test-Path -LiteralPath $publicKey) {
        $result.sshPublicKey = $true
    } else {
        $result.missing += 'sshPublicKey'
        Write-Warning "SSH public key not found: $publicKey"
    }
    
    # Check includeIf blocks in global .gitconfig
    $globalGit = Join-Path $userHome '.gitconfig'
    if (Test-Path -LiteralPath $globalGit) {
        $globalLines = Get-Content -LiteralPath $globalGit -Encoding UTF8
        $includeMarker = "# managed-by: gitidentities-module alias=$Alias"
        $result.includeIfBlocks = ($globalLines | Where-Object { $_ -like "*$includeMarker*" }).Count
    }
    if ($result.includeIfBlocks -eq 0) {
        $result.missing += 'includeIfBlocks'
    }
    
    return [pscustomobject]$result
}