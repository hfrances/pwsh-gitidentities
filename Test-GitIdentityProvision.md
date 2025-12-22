"
# Test-GitIdentityProvision

`powershell
.SYNOPSIS
Tests Git identity provisioning status.
.DESCRIPTION
Reports what artifacts exist or are missing for a given alias: state entry, alias gitconfig, SSH key pair, SSH host block, includeIf entries.
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
