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


## Why use Add-GitIdentity and what does it solve?

Managing multiple Git and SSH identities on the same machine can be error-prone and tedious, especially when switching between work, personal, and client repositories. Manual configuration often leads to mistakes, credential leaks, or misattributed commits.

**GitIdentities** solves this by providing a single command, `Add-GitIdentity`, which:
- Creates all necessary configuration files and SSH keys for each identity
- Automatically sets up per-folder rules using Git's `includeIf` so the right identity is used in each repo
- Is idempotent: you can run it as many times as you want, and it will only update what is needed
- Supports cross-platform and cross-user scenarios

**Example: Adding multiple identities from a JSON file**

Suppose you have a file like this (with example data):

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

You can add all identities with:

```powershell
Add-GitIdentity -Alias "github-personal" -Platform "github" -Name "Jane Example" -Username "janeuser" -Email "jane@example.com" -Folders @("C:/repos/personal","C:/repos/opensource")
Add-GitIdentity -Alias "work-acme" -Platform "azure" -Name "Jane Example" -Username "jane.acme@acme.com" -Email "jane.acme@acme.com" -Folders @("C:/repos/acme")
```

This ensures each repo uses the correct identity, SSH key, and credentials automatically.

## Basic Usage

```powershell
# Add an identity
Add-GitIdentity -Alias work -Name "Jane Example" -Email jane@company.com -Username janed -Folders C:\Work\Repos

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
