function Get-GitIdentitySshPublicKey {
<#
.SYNOPSIS
Retrieves the SSH public key for a Git identity.

.DESCRIPTION
Retrieves the SSH public key content for a specified identity alias and copies it to the clipboard.
The public key is located in ~/.ssh/id_{alias}.pub

.PARAMETER Alias
Identity alias for which to retrieve the SSH public key.

.PARAMETER User
Windows user profile (defaults to current user).

.PARAMETER Content
If specified, returns only the key content as a string (for piping to Set-Clipboard or other commands).

.PARAMETER Verbosity
Log verbosity (Silent|Error|Warn|Info|Debug).

.EXAMPLE
Get-GitIdentitySshPublicKey -Alias work

.EXAMPLE
Get-GitIdentitySshPublicKey -Alias work -Content | Set-Clipboard
#>
    param(
        [Parameter(Mandatory)][string]$Alias,
        [string]$User,
        [switch]$Content,
        [ValidateSet('Silent','Error','Warn','Info','Debug')][string]$Verbosity = 'Warn'
    )
    
    $script:GitIdentitiesVerbosity = $Verbosity
    $userHome = Get-GIUserHome -User $User
    
    # Build SSH public key path
    $sshDir = Join-Path $userHome '.ssh'
    $publicKeyPath = Join-Path $sshDir "id_$Alias.pub"
    
    Write-GILog -Level INFO -Message "Retrieving SSH public key for alias $Alias"
    
    # Check if public key exists
    if (-not (Test-Path -LiteralPath $publicKeyPath)) {
        Write-GILog -Level ERROR -Message "SSH public key not found: $publicKeyPath"
        throw "SSH public key not found for alias '$Alias'. Run Test-GitIdentityProvision -Alias $Alias to check provisioning status."
    }
    
    # Read public key content
    $keyContent = Get-Content -LiteralPath $publicKeyPath -Encoding UTF8 -Raw
    
    # If -Content, return raw string without copying to clipboard
    if ($Content) {
        return $keyContent.TrimEnd()
    }
    
    # Copy to clipboard
    try {
        $keyContent | Set-Clipboard
        Write-GILog -Level INFO -Message "SSH public key copied to clipboard"
    } catch {
        Write-GILog -Level WARN -Message "Failed to copy to clipboard: $($_.Exception.Message)"
    }
    
    # Return the key content as custom object for consistency
    [pscustomobject]@{
        alias = $Alias
        keyPath = $publicKeyPath
        content = $keyContent.TrimEnd()
    }
}
