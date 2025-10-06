# GitIdentities

![Build](https://github.com/hfrances/pwsh-gitidentities/actions/workflows/ci.yml/badge.svg)
![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)

**GitIdentities** is a PowerShell module for managing multiple Git and SSH identities automatically and securely. It is designed for developers who work with several profiles (work, personal, clients, etc.) on the same machine.

## Main Features
- Automatic and idempotent provisioning of Git/SSH identities
- Platform detection (GitHub, GitLab, Azure DevOps, Bitbucket)
- SSH key management and per-folder `includeIf` configuration
- Advanced logging and dry-run mode
- Windows compatible (PowerShell 5.1+)

## Quick Installation

```powershell
# Install from PowerShell Gallery (when published)
Install-Module -Name GitIdentities -Scope CurrentUser

# Or import manually from the repo
Import-Module ./GitIdentities
```

## Basic Usage

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

## Running Tests

This project uses [Pester](https://pester.dev/) for automated testing. If you are new to PowerShell testing, follow these steps:

### 1. Install Pester (if needed)

Open PowerShell as Administrator and run:

```powershell
Install-Module -Name Pester -Scope CurrentUser -Force
```

> **Note:** On Windows PowerShell 5.1, you may need to update NuGet first:
> ```powershell
> Install-PackageProvider -Name NuGet -Force
> ```

### 2. Run the Tests

From the root of the repository, run:

```powershell
Invoke-Pester -Path ./Tests
```

This will execute all test scripts in the `Tests` folder and show a summary of results. No manual input is required.

For more details, see the [Pester documentation](https://pester.dev/docs/quick-start/).

## Documentation
- Full documentation and examples: [`GitIdentities/README.md`](GitIdentities/README.md)
- Changelog: [`CHANGELOG.md`](CHANGELOG.md)

## Contributing
Issues and pull requests are welcome! See the [contribution guidelines](https://github.com/hfrances/pwsh-gitidentities/blob/main/CONTRIBUTING.md) (coming soon).

## License
MIT. See [`LICENSE`](LICENSE).
