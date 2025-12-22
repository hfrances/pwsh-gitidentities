"
# Add-GitIdentity

`powershell
.SYNOPSIS
Adds or extends a Git/SSH identity.
.DESCRIPTION
Creates (or updates) per-alias git config, SSH key (optional), host block, and includeIf entries for provided folders.
.PARAMETER Alias
Identity alias (unique).
.PARAMETER Platform
Platform name (github|azure|gitlab|bitbucket). Default github.
.PARAMETER Name
Git user.name
.PARAMETER Email
Git user.email
.PARAMETER Username
Credential username for platform.
.PARAMETER Folders
One or more repository root folders (gitdir scope). If an existing identity exists, new folders are appended.
.PARAMETER User
Windows user profile (defaults to current user).
.PARAMETER ForceRegenKeys
Regenerate SSH key even if exists.
.PARAMETER DryRun
Simulate actions.
.PARAMETER FileLog
Enable file logging.
.PARAMETER Verbosity
Log verbosity (Silent|Error|Warn|Info|Debug).
.EXAMPLE
Add-GitIdentity -Alias work -Name "Jane Doe" -Email jane@corp.com -Username janed -Folders C:\Repos\Work1,C:\Repos\Work2
`

## Examples

See README.md for usage examples.
"
