# GitIdentities PowerShell Module

> **Requires PowerShell 5.1+**

Manage multiple Git and SSH identities with automatic per-repository configuration.

## Installation

```powershell
Install-Module -Name GitIdentities -Scope CurrentUser
```

## Quick Start

```powershell
# Add an identity
Add-GitIdentity -Alias work -Name "Jane Doe" -Email jane@company.com -Username janed -Folders C:\Work\Repos

# List identities
Get-GitIdentities

# Remove an identity
Remove-GitIdentity -Alias work
```

## What It Does

Automates identity management by:
- Generating platform-specific SSH keys (ed25519 for GitHub/GitLab, RSA for Azure)
- Creating per-identity Git config with `core.sshCommand` for SSH
- Setting up `includeIf` rules for automatic identity switching per folder
- Configuring Windows Credential Manager
- Using native `git config` to preserve manual changes

## How It Works

Creates for each identity:
1. **~/.gitidentities.json**: State tracking
2. **~/.gitconfig-{alias}**: Identity config with user, credential, and SSH settings
3. **~/.ssh/id_{alias}**: SSH key pair
4. **~/.gitconfig additions**: `includeIf` blocks for auto-switching

**Example ~/.gitconfig-work:**
```ini
[user]
    name = Jane Doe
    email = jane@company.com
[credential "https://github.com/"]
    username = janed
[core]
    sshCommand = ssh -i ~/.ssh/id_work -o User=git -o IdentitiesOnly=yes
```

## Parameters

### Add-GitIdentity
- **Required**: `-Alias`, `-Name`, `-Email`, `-Username`, `-Folders`
- **Optional**: `-Platform` (auto-detected), `-SshAlgorithm` (auto-selected), `-SshUser` (auto-selected), `-ForceRegenKeys`, `-DryRun`, `-Verbosity`

### Azure DevOps Note
Automatically configures both SSH users ('git' and your username) to support different SSH URL formats.

## Platform Detection

Auto-detects from alias/email patterns:
- `github` → github.com (ed25519)
- `gitlab` → gitlab.com (ed25519)
- `azure` → ssh.dev.azure.com (RSA)
- `bitbucket` → bitbucket.org (ed25519)

## Troubleshooting

**SSH key fails**: Ensure OpenSSH is installed. Use `-Verbosity Debug` for details.

**Config not applied**: Verify folder paths use forward slashes and Git 2.13+.

**Permissions**: Run as appropriate user with write access to home directory.

## Advanced Usage

**Multiple emails per platform**:
```powershell
Add-GitIdentity -Alias github-work -Email work@company.com -Folders C:\Work
Add-GitIdentity -Alias github-personal -Email me@gmail.com -Folders C:\Personal
```

**Custom SSH user**:
```powershell
Add-GitIdentity -Alias custom -Name "Jane" -Email jane@example.com -Username jane -Folders C:\Repos -SshUser "customuser"
```

## License
MIT