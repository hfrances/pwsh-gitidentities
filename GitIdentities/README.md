
# GitIdentities PowerShell Module

> **Minimum PowerShell version required: 5.1 or later (Windows PowerShell 5.1+ or PowerShell Core)**

GitIdentities is a PowerShell module for managing multiple Git and SSH identities with automatic per-repository configuration using Git's `includeIf` feature. This README is focused on module usage, parameters, troubleshooting, and advanced scenarios for PowerShell Gallery users.

## Features

- Idempotent provisioning: Safe to run multiple times, only creates/updates what's needed
- Automatic platform detection: Derives platform (GitHub, GitLab, Azure DevOps, Bitbucket) from alias names and email domains
- SSH key management: Generates ed25519 keys with RSA fallback, manages SSH config host blocks
- Per-repository configuration: Uses Git `includeIf` to automatically apply identity based on folder path
- State tracking: Maintains identity state in `~/.gitidentities.json` for discovery and management
- Cross-user support: Can manage identities for different Windows user profiles
- Comprehensive logging: Detailed logging with configurable verbosity levels
- Dry-run support: Preview changes without applying them

## Installation

Install from the PowerShell Gallery (recommended):

```powershell
Install-Module -Name GitIdentities -Scope CurrentUser
```

Or import manually from the repo:

```powershell
Import-Module ./GitIdentities
```


## Why use Add-GitIdentity? What does it automate?

Manually managing multiple Git/SSH identities is error-prone and can lead to credential leaks or misattributed commits. `Add-GitIdentity` automates:
- Creation of all required config files and SSH keys
- Per-folder rules using Git's `includeIf` so the right identity is always used
- Idempotent updates: run as many times as needed, only changes what's necessary
- Cross-user and cross-platform support

**Example: Adding identities from a JSON file (with example data)**

```json
{
    "identities": [
        {
            "alias": "github-personal",
            "platform": "github",
            "name": "Jane Example",
            "username": "janeuser",
            "email": "jane@example.com",
            "folders": ["C:/repos/personal", "C:/repos/opensource"]
        },
        {
            "alias": "work-acme",
            "platform": "azure",
            "name": "Jane Example",
            "username": "jane.acme@acme.com",
            "email": "jane.acme@acme.com",
            "folders": ["C:/repos/acme"]
        }
    ]
}
```

You can provision all identities with:

```powershell
Add-GitIdentity -Alias "github-personal" -Platform "github" -Name "Jane Example" -Username "janeuser" -Email "jane@example.com" -Folders @("C:/repos/personal","C:/repos/opensource")
Add-GitIdentity -Alias "work-acme" -Platform "azure" -Name "Jane Example" -Username "jane.acme@acme.com" -Email "jane.acme@acme.com" -Folders @("C:/repos/acme")
```

This guarantees each repo uses the correct identity, SSH key, and credentials automatically.

## Usage

### Add a new identity
```powershell
Add-GitIdentity -Alias work -Name "Jane Example" -Email jane@company.com -Username janed -Folders C:\Work\Repos
```

### List existing identities
```powershell
Get-GitIdentities
```

### Remove an identity
```powershell
Remove-GitIdentity -Alias work
```

### Test provisioning status
```powershell
Test-GitIdentityProvision -Alias work
```



## How It Works

When you add an identity, the module creates several artifacts:

1. **State file** (`~/.gitidentities.json`): Tracks all managed identities
2. **Alias gitconfig** (`~/.gitconfig-{alias}`): Contains `[user]` and `[credential]` sections for the identity
3. **SSH key pair** (`~/.ssh/id_{alias}` and `.pub`): Ed25519 key for authentication
4. **SSH host block** (`~/.ssh/config`): Maps alias to appropriate hostname (github.com, ssh.dev.azure.com, etc.)
5. **IncludeIf blocks** (`~/.gitconfig`): Automatically includes alias config when in specified folders

### Example Generated Files

**~/.gitconfig-work:**
```ini
# managed-by: gitidentities-module alias=work section=user
[user]
    name = Jane Doe
    email = jane@company.com
# managed-by: gitidentities-module alias=work section=credential
[credential "https://github.com/"]
    username = janed
```

**~/.gitconfig (additions):**
```ini
# managed-by: gitidentities-module alias=work folder=C:/Work/Repos/
[includeIf "gitdir:C:/Work/Repos/"]
    path = ~/.gitconfig-work
```

**~/.ssh/config (additions):**
```ini
# managed-by: gitidentities-module alias=work
Host work
  HostName github.com
  IdentityFile ~/.ssh/id_work
  User git
  IdentitiesOnly yes
```

## Platform Detection

The module automatically detects platforms based on:

1. **Alias patterns**: `github`, `gitlab`, `azure`, `bitbucket` in the alias name
2. **Email domains**: `@github.com`, `@gitlab.com`, etc. in the email address
3. **Fallback**: Defaults to `github` if no pattern matches

Supported platforms:
- `github` → github.com
- `gitlab` → gitlab.com  
- `azure` → ssh.dev.azure.com (for Azure DevOps)
- `bitbucket` → bitbucket.org

## Parameters

### Add-GitIdentity
- `Alias` (required): Unique identifier for the identity
- `Name` (required): Git user.name value
- `Email` (required): Git user.email value  
- `Username` (required): Username for credential helper
- `Folders` (required): Array of repository root paths
- `Platform`: Platform name (auto-detected if not specified)
- `User`: Windows user profile (defaults to current user)
- `ForceRegenKeys`: Regenerate SSH keys even if they exist
- `DryRun`: Preview changes without applying
- `Verbosity`: Logging level (Silent|Error|Warn|Info|Debug)
- `FileLog`: Enable file logging

### Get-GitIdentities
- `User`: Windows user profile (defaults to current user)
- `Verbosity`: Logging level

### Remove-GitIdentity  
- `Alias` (required): Identity to remove
- `Folders`: Specific folders to remove (optional)
- `All`: Remove entire identity
- `User`: Windows user profile
- `DryRun`: Preview changes
- `Verbosity`: Logging level

## SSH Key Generation

The module uses a robust SSH key generation strategy:

1. **Primary attempt**: Direct PowerShell invocation with ed25519
2. **Fallback**: Command via `cmd.exe` with proper quoting
3. **Final fallback**: RSA 4096-bit if ed25519 fails

All attempts are logged with full command output for troubleshooting.

## Windows Credential Manager Integration

GitIdentities automatically configures Git to use Windows Credential Manager for secure credential storage:

### Automatic Configuration
- **No helper configured**: Automatically sets `credential.helper = manager-core`
- **Different helper exists**: Prompts user with Yes/No/Cancel options
- **Already using manager-core**: No action needed

### User Experience
When `Add-GitIdentity` detects a different credential helper:

```
Current credential helper: 'store'
Recommended for Windows: 'manager-core' (Windows Credential Manager)

Do you want to change the credential helper to 'manager-core'?
[Y] Yes  [N] No  [C] Cancel  [?] Help (default is "Y"):
```

### Benefits
- **Secure Storage**: Credentials stored in Windows Credential Vault
- **SSO Integration**: Works with Windows authentication
- **Automatic Management**: No manual credential entry for most scenarios
- **Enterprise Ready**: Supports domain authentication and policies

### Manual Configuration
```powershell
# Set manually if needed
git config --global credential.helper manager-core
```

## Logging

Comprehensive logging with levels:
- `ERROR`: Critical failures
- `WARN`: Non-blocking issues  
- `INFO`: Key operations (default)
- `DEBUG`: Detailed diagnostic information
- `CHANGE`: What was actually modified

Enable file logging with `-FileLog` to write to `~/setup-git-identities.log`.

## Best Practices

1. **Use descriptive aliases**: `work`, `personal`, `company-azure` rather than `id1`, `id2`
2. **Organize by platform and purpose**: Different aliases for different Git platforms
3. **Test with dry-run**: Use `-DryRun` to preview changes before applying
4. **Regular validation**: Use `Test-GitIdentityProvision` to verify setup
5. **Backup important configs**: The module creates backups but manual backups are recommended

## Troubleshooting

### SSH Key Generation Fails
- Ensure OpenSSH client is installed and in PATH
- Check permissions on `~/.ssh` directory
- Try with `-Verbosity Debug` to see detailed error output
- Verify no existing keys conflict

### Git Config Not Applied
- Verify folder paths are correct and use forward slashes
- Check that `includeIf` blocks were created in `~/.gitconfig`
- Ensure Git version supports `includeIf` (Git 2.13+)

### Permission Issues
- Run PowerShell as appropriate user for target profile
- Verify write access to user home directory
- Check file/folder permissions on `.git`, `.ssh` directories

## Advanced Usage

### Custom Credential Helper
The module sets `credential.helper = manager-core` by default. To use a different helper, modify the global `.gitconfig` after running the module.

### Multiple Email Addresses
Create separate identities for different email addresses, even on the same platform:
```powershell
Add-GitIdentity -Alias github-work -Email work@company.com -Username work-account -Folders C:\Work
Add-GitIdentity -Alias github-personal -Email me@gmail.com -Username personal-account -Folders C:\Personal
```

### Cross-Platform Development
Use different identities for different platforms in the same repository structure:
```powershell
Add-GitIdentity -Alias azure-corp -Platform azure -Folders C:\Projects\Corporate
Add-GitIdentity -Alias github-oss -Platform github -Folders C:\Projects\OpenSource  
```

## License

This module is provided as-is for managing Git identities. Use at your own discretion and always backup important configurations before use.