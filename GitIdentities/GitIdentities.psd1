@{
    RootModule = 'GitIdentities.psm1'
    ModuleVersion = '0.1.0'
    GUID = 'c2a2b05d-0b6c-4a4c-9e55-6a9d3a0dfe01'
    Author = 'hfrances'
    CompanyName = 'TrCode' 
    Copyright = '(c) 2025 hfrances / TrCode. All rights reserved.'
    Description = 'PowerShell module for managing multiple Git/SSH identities with automatic per-repository configuration using Git includeIf feature.'
    
    # Minimum version of the PowerShell engine required by this module
    PowerShellVersion = '5.1'
    
    # Functions to export from this module, for best performance, do not use wildcards and do not delete the entry
    FunctionsToExport = @(
        'Add-GitIdentity',
        'Get-GitIdentities',
        'Get-GitIdentitySshPublicKey',
        'Remove-GitIdentity',
        'Test-GitIdentityProvision'
    )
    
    # Cmdlets to export from this module, for best performance, do not use wildcards and do not delete the entry
    CmdletsToExport = @()
    
    # Variables to export from this module
    VariablesToExport = @()
    
    # Aliases to export from this module, for best performance, do not use wildcards and do not delete the entry
    AliasesToExport = @()
    
    # Private data to pass to the module specified in RootModule/ModuleToProcess
    PrivateData = @{
        PSData = @{
            # Tags applied to this module. These help with module discovery in online galleries.
            Tags = @('Git', 'SSH', 'Identity', 'Configuration', 'Repository', 'MultiUser', 'includeIf')
            
            # A URL to the license for this module.
            LicenseUri = 'https://github.com/hfrances/pwsh-gitidentities/blob/main/LICENSE'
            
            # A URL to the main website for this project.
            ProjectUri = 'https://github.com/hfrances/pwsh-gitidentities'
            
            # ReleaseNotes of this module
            ReleaseNotes = @'
# GitIdentities v1.0.0 Release Notes

## Features
- Multi-identity Git and SSH management
- Automatic platform detection (GitHub, GitLab, Azure DevOps, Bitbucket)
- Per-repository configuration using Git includeIf
- SSH key generation with ed25519 and RSA fallback
- Idempotent operations (safe to run multiple times)
- Cross-user Windows profile support
- Comprehensive logging with configurable verbosity
- Dry-run mode for safe testing
- Identity provisioning status checking

## Commands
- Add-GitIdentity: Create or update Git/SSH identities
- Get-GitIdentities: Discover and list existing identities
- Remove-GitIdentity: Remove identities or specific folders
- Test-GitIdentityProvision: Check identity artifact status

## Requirements
- PowerShell 5.1 or later
- Git (for includeIf support - requires Git 2.13+)
- OpenSSH client (for SSH key generation)
- Windows (tested on Windows 10/11)
'@
            
            # Flag to indicate whether the module requires explicit user acceptance for install/update/save
            RequireLicenseAcceptance = $false
        }
    }
}
