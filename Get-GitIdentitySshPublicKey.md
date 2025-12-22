"
# Get-GitIdentitySshPublicKey

`powershell
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
`

## Examples

See README.md for usage examples.
"
