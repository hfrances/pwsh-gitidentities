function Set-GICredentialHelper {
<#
.SYNOPSIS
    Configures Git credential helper for Windows Credential Manager in user-specific .gitconfig
    
.DESCRIPTION
    Checks current Git credential helper configuration in the specified user's .gitconfig
    and sets it to manager-core if none exists, or prompts user for confirmation if a different helper is configured.
    This function operates on the user-specific .gitconfig file, not the global system configuration.
    
.PARAMETER UserHome
    Path to user home directory
    
.PARAMETER DryRun
    Simulate actions without making changes
    
.EXAMPLE
    Set-GICredentialHelper -UserHome "C:/Users/patata" -DryRun:$false
#>
    param(
        [Parameter(Mandatory = $true)]
        [string]$UserHome,
        
        [Parameter()]
        [switch]$DryRun
    )
    
    Write-GILog -Level DEBUG -Message "Checking Git credential helper configuration for user: $UserHome"
    
    try {
        $gitConfigPath = Join-Path $UserHome '.gitconfig'
        
        # Check current credential helper configuration from user's .gitconfig
        $currentHelper = $null
        
        if (Test-Path $gitConfigPath) {
            try {
                $configContent = Get-Content $gitConfigPath -ErrorAction SilentlyContinue
                $inCredentialSection = $false
                
                foreach ($line in $configContent) {
                    $line = $line.Trim()
                    if ($line -match '^\[credential\]$') {
                        $inCredentialSection = $true
                        continue
                    }
                    if ($line -match '^\[.*\]$' -and $line -notmatch '^\[credential\]$') {
                        $inCredentialSection = $false
                        continue
                    }
                    if ($inCredentialSection -and $line -match '^\s*helper\s*=\s*(.+)$') {
                        $currentHelper = $matches[1].Trim()
                        Write-GILog -Level DEBUG -Message "Current credential helper in ${gitConfigPath}: '$currentHelper'"
                        break
                    }
                }
            }
            catch {
                Write-GILog -Level DEBUG -Message "Error reading ${gitConfigPath} : $($_.Exception.Message)"
            }
        }
        else {
            Write-GILog -Level DEBUG -Message "No .gitconfig found at ${gitConfigPath}"
        }
        
        $targetHelper = "manager-core"
        
        # If no helper is configured, set manager-core automatically
        if ([string]::IsNullOrWhiteSpace($currentHelper)) {
            Write-GILog -Level INFO -Message "No credential helper configured in user's .gitconfig. Setting Windows Credential Manager (manager-core)"
            
            if ($DryRun) {
                Write-GILog -Level CHANGE -Message "[DryRun] Would add credential.helper = $targetHelper to ${gitConfigPath}"
            }
            else {
                try {
                    Add-GICredentialHelperToConfig -GitConfigPath $gitConfigPath -HelperName $targetHelper
                    Write-GILog -Level CHANGE -Message "Git credential helper set to: $targetHelper in ${gitConfigPath}"
                }
                catch {
                    Write-GILog -Level WARN -Message "Error setting credential helper: $($_.Exception.Message)"
                }
            }
        }
        # If a different helper is configured, ask user
        elseif ($currentHelper -ne $targetHelper) {
            Write-GILog -Level INFO -Message "Current credential helper in user config: '$currentHelper'"
            Write-GILog -Level INFO -Message "Recommended credential helper: '$targetHelper'"
            
            if ($DryRun) {
                Write-GILog -Level CHANGE -Message "[DryRun] Would prompt to change credential helper from '$currentHelper' to '$targetHelper' in ${gitConfigPath}"
            }
            else {
                # Prompt user for confirmation
                $title = "Git Credential Helper Configuration"
                $message = @"
Current credential helper in user config: '$currentHelper'
Recommended for Windows: '$targetHelper' (Windows Credential Manager)

Do you want to change the credential helper to '$targetHelper'?
"@
                
                $choices = @(
                    [System.Management.Automation.Host.ChoiceDescription]::new("&Yes", "Change to $targetHelper")
                    [System.Management.Automation.Host.ChoiceDescription]::new("&No", "Keep current helper '$currentHelper'")
                    [System.Management.Automation.Host.ChoiceDescription]::new("&Cancel", "Cancel operation")
                )
                
                $defaultChoice = 0  # Default to Yes
                
                try {
                    $choice = $Host.UI.PromptForChoice($title, $message, $choices, $defaultChoice)
                    
                    switch ($choice) {
                        0 { # Yes
                            try {
                                Update-GICredentialHelperInConfig -GitConfigPath $gitConfigPath -OldHelper $currentHelper -NewHelper $targetHelper
                                Write-GILog -Level CHANGE -Message "Git credential helper changed from '$currentHelper' to '$targetHelper' in ${gitConfigPath}"
                            }
                            catch {
                                Write-GILog -Level ERROR -Message "Error changing credential helper: $($_.Exception.Message)"
                            }
                        }
                        1 { # No
                            Write-GILog -Level INFO -Message "Keeping current credential helper: '$currentHelper'"
                        }
                        2 { # Cancel
                            Write-GILog -Level WARN -Message "Operation cancelled by user"
                            throw "Operation cancelled by user"
                        }
                    }
                }
                catch [System.Management.Automation.Host.PromptingException] {
                    # Handle case where host doesn't support prompting (like ISE or some CI environments)
                    Write-GILog -Level WARN -Message "Cannot prompt in this environment. Keeping current credential helper: '$currentHelper'"
                }
            }
        }
        else {
            Write-GILog -Level DEBUG -Message "Credential helper already set to recommended value: '$targetHelper'"
        }
    }
    catch {
        Write-GILog -Level ERROR -Message "Error configuring credential helper: $($_.Exception.Message)"
        # Don't throw - this is not critical enough to stop the whole identity creation process
    }
}

function Add-GICredentialHelperToConfig {
    <#
    .SYNOPSIS
        Adds credential helper configuration to user's .gitconfig
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$GitConfigPath,
        
        [Parameter(Mandatory = $true)]
        [string]$HelperName
    )
    
    # Usar git config para evitar duplicaciones
    try {
        # Crear archivo si no existe
        if (-not (Test-Path $GitConfigPath)) {
            New-Item -Path $GitConfigPath -ItemType File -Force | Out-Null
        }
        
        # Usar git config --file para añadir/actualizar el helper
        git config --file $GitConfigPath credential.helper $HelperName
        Write-GILog -Level DEBUG -Message "Set credential.helper to $HelperName using git config"
    }
    catch {
        Write-GILog -Level ERROR -Message "Failed to set credential helper: $($_.Exception.Message)"
        throw
    }
}

function Update-GICredentialHelperInConfig {
    <#
    .SYNOPSIS
        Updates existing credential helper configuration in user's .gitconfig
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$GitConfigPath,
        
        [Parameter(Mandatory = $true)]
        [string]$OldHelper,
        
        [Parameter(Mandatory = $true)]
        [string]$NewHelper
    )
    
    if (-not (Test-Path $GitConfigPath)) {
        throw "Git config file not found: $GitConfigPath"
    }
    
    # Usar git config --file para reemplazar el helper
    try {
        git config --file $GitConfigPath --replace-all credential.helper $NewHelper
        Write-GILog -Level DEBUG -Message "Updated credential.helper from $OldHelper to $NewHelper using git config"
    }
    catch {
        Write-GILog -Level ERROR -Message "Failed to update credential helper: $($_.Exception.Message)"
        throw
    }
}