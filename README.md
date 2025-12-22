# GitIdentities

![Build](https://github.com/hfrances/pwsh-gitidentities/actions/workflows/ci.yml/badge.svg)
[![PowerShell Gallery](https://img.shields.io/powershellgallery/v/GitIdentities.svg)](https://www.powershellgallery.com/packages/GitIdentities)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

**GitIdentities** is a PowerShell module for managing multiple Git and SSH identities automatically. Designed for developers who work with multiple profiles (work, personal, clients) on the same machine.

## Features
- Automatic Git/SSH identity provisioning with platform detection (GitHub, GitLab, Azure DevOps, Bitbucket)
- SSH key management with per-platform algorithm selection (ed25519/RSA)
- Per-folder `includeIf` configuration for automatic identity switching
- Idempotent and safe: run multiple times without issues

## Installation

```powershell
# Install from PowerShell Gallery (when published)
Install-Module -Name GitIdentities -Scope CurrentUser

# Or import manually from the repo
Import-Module ./GitIdentities
```

## Quick Start

### Add commands

```powershell
# Add an identity
Add-GitIdentity -Alias work -Name "github-jane" -Email jane@company.com -Username janed -Folders "C:\Work\Repos"

# Add an identity (multiple folders)
Add-GitIdentity -Alias work -Name "github-jane" -Email jane@company.com -Username janed -Folders @("C:\Work\Repos\repo1", "C:\Work\Repos\repo2") 

# Add an identity (with platform)
Add-GitIdentity -Alias work -Name "github-jane" -Email jane@company.com -Username janed -Platform "github" -Folders "C:\Work\Repos\github"

Add-GitIdentity -Alias work -Name "azure-jane" -Email jane@company.com -Username janed -Platform "azure" -Folders "C:\Work\Repos\azure"

```

Possible platforms:
- github
- azure
- gitlab
- bitbucket

### Adding SSH Keys to Your Platforms

After creating identities, you need to add the public SSH key to each platform. The keys are stored in `~\.ssh\` directory.

**To get your SSH public key:**
```powershell
# Get the public key and copy to clipboard
Get-GitIdentitySshPublicKey -Alias work

# Or get the key content for manual use
Get-GitIdentitySshPublicKey -Alias work -Content | Set-Clipboard
```

Then add it to your platform:

| Platform | Documentation |
|----------|---------------|
| **GitHub** | [Adding a new SSH key to your GitHub account](https://docs.github.com/en/authentication/connecting-to-github-with-ssh/adding-a-new-ssh-key-to-your-github-account) |
| **Azure DevOps** | [Set up SSH authentication](https://learn.microsoft.com/en-us/azure/devops/repos/git/use-ssh-keys-to-authenticate) |
| **GitLab** | [Use SSH keys to communicate with GitLab](https://docs.gitlab.com/ee/user/ssh.html) |
| **Bitbucket** | [Set up an SSH key](https://support.atlassian.com/bitbucket-cloud/docs/set-up-an-ssh-key/) |

### Other commands 

```powershell
# List identities
Get-GitIdentities

# Get SSH public key for an identity
Get-GitIdentitySshPublicKey -Alias work

# Check provisioning status
Test-GitIdentityProvision -Alias work

# Remove an identity
Remove-GitIdentity -Alias work
```

## What It Does

When you add an identity, GitIdentities:
1. Generates SSH keys (ed25519 for GitHub/GitLab, RSA for Azure DevOps)
2. Creates per-identity Git config with `core.sshCommand` for SSH authentication
3. Sets up `includeIf` rules in your `.gitconfig` to auto-switch identities per folder
4. Configures Windows Credential Manager for HTTPS authentication

All configuration is managed via native `git config` commands, preserving manual changes.

## Documentation
- Full documentation: [`GitIdentities/README.md`](GitIdentities/README.md)
- Changelog: [`CHANGELOG.md`](CHANGELOG.md)

## Contributing
Issues and pull requests are welcome! See the [contribution guidelines](https://github.com/hfrances/pwsh-gitidentities/blob/main/CONTRIBUTING.md) (coming soon).

## License
MIT. See [`LICENSE`](LICENSE).
