# GitIdentities

![Build](https://github.com/hfrances/pwsh-gitidentities/actions/workflows/ci.yml/badge.svg)
![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)

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

```powershell
# Add an identity
Add-GitIdentity -Alias work -Name "Jane Doe" -Email jane@company.com -Username janed -Folders C:\Work\Repos

# List identities
Get-GitIdentities

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
