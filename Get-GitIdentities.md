"
# Get-GitIdentities

`powershell
.SYNOPSIS
Enumerates Git identities by reading per-alias gitconfig files and global .gitconfig includeIf blocks.
.DESCRIPTION
Returns a list of identity objects with: alias, platform, name, email, username, folders, ssh.
Information is gathered from:
 - Per-alias gitconfig files (~/.gitconfig-{alias}): user info, credentials, SSH configuration
 - Global .gitconfig includeIf blocks: folder associations
`

## Examples

See README.md for usage examples.
"
