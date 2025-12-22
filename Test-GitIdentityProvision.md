"
# Test-GitIdentityProvision

`powershell
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
`

## Examples

See README.md for usage examples.
"
