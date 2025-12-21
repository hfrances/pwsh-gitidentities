# TestConfig.ps1
# Configuration and utilities for GitIdentities testing

<#
.SYNOPSIS
    Test configuration and utilities for GitIdentities module testing
    
.DESCRIPTION
    This file contains configuration variables and utility functions used across
    different test scenarios in the GitIdentities module test suite.
    
.NOTES
    This file is imported by test scripts to provide consistent test configuration
    and shared utilities across integration and unit tests.
#>

# Test Configuration Variables
$script:TestConfig = @{
    # Test User Configuration
    TestUser = "patata"  # As requested by user
    TestAlias = "testidentity"
    TestName = "Test Patata User"
    TestEmail = "patata@example.com"
    TestUsername = "patata"
    
    # Test Folders
    TestFolders = @(
        "C:\TestRepo1",
        "C:\TestRepo2\SubProject"
    )
    
    # Cleanup Settings
    CleanupAfterTests = $true
    PreserveTestData = $false
    
    # Platform Test Data
    PlatformTests = @{
        GitHub = @{
            Alias = "mygithub"
            Email = "test@github.com"
            ExpectedHost = "github.com"
            ExpectedAlgorithm = "ed25519"
            ExpectedSshUsers = @("git")
        }
        GitLab = @{
            Alias = "workgitlab"
            Email = "test@gitlab.com"
            ExpectedHost = "gitlab.com"
            ExpectedAlgorithm = "ed25519"
            ExpectedSshUsers = @("git")
        }
        Azure = @{
            Alias = "corpazure"
            Email = "test@dev.azure.com"
            ExpectedHost = "dev.azure.com"
            ExpectedAlgorithm = "rsa"
            ExpectedSshUsers = @("git")  # Note: Azure also uses username, but that's dynamic
        }
        Bitbucket = @{
            Alias = "teambitbucket"
            Email = "test@bitbucket.org"
            ExpectedHost = "bitbucket.org"
            ExpectedAlgorithm = "ed25519"
            ExpectedSshUsers = @("git")
        }
    }
    
    # SSH Key Test Configuration
    SshKeyTests = @{
        SkipInCI = $true  # Skip actual SSH key generation in CI
        TestKeyTypes = @("ed25519", "rsa")
        TestKeyComments = @("test-key-{0}")
        # SSH User configurations
        SshUserTests = @{
            SingleUser = @("git")
            MultipleUsers = @("git", "customuser")
            AzureUsers = @("git", "testuser")  # Azure supports multiple SSH users
        }
    }
    
    # Error Simulation
    ErrorTests = @{
        InvalidEmails = @("", "notanemail", "@domain.com", "user@", "user@@domain.com")
        InvalidPaths = @("", "not\a\valid\path", "C:\Windows\System32")
        InvalidAliases = @("", " ", "alias with spaces", "alias@special")
    }
}

<#
.SYNOPSIS
    Gets test configuration for the specified category
    
.PARAMETER Category
    The configuration category to retrieve
    
.EXAMPLE
    Get-TestConfig -Category "PlatformTests"
#>
function Get-TestConfig {
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet("TestUser", "TestAlias", "TestName", "TestEmail", "TestUsername", 
                     "TestFolders", "CleanupAfterTests", "PreserveTestData", 
                     "PlatformTests", "SshKeyTests", "ErrorTests")]
        [string]$Category
    )
    
    return $script:TestConfig[$Category]
}

<#
.SYNOPSIS
    Initializes test environment with cleanup of any existing test data
    
.EXAMPLE
    Initialize-TestEnvironment
#>
function Initialize-TestEnvironment {
    param(
        [string]$User = $script:TestConfig.TestUser
    )
    
    Write-Host "Initializing test environment for user: $User" -ForegroundColor Yellow
    
    # Clean up any existing test identities
    $existingIdentities = Get-GitIdentities -User $User -Verbosity Silent -ErrorAction SilentlyContinue
    if ($existingIdentities) {
        foreach ($identity in $existingIdentities) {
            if ($identity.alias -like "*test*" -or $identity.alias -eq $script:TestConfig.TestAlias) {
                Write-Host "Cleaning up existing test identity: $($identity.alias)" -ForegroundColor Gray
                Remove-GitIdentity -Alias $identity.alias -User $User -Confirm:$false -Verbosity Silent -ErrorAction SilentlyContinue
            }
        }
    }
    
    Write-Host "Test environment initialized" -ForegroundColor Green
}

<#
.SYNOPSIS
    Cleans up test environment after test completion
    
.EXAMPLE
    Cleanup-TestEnvironment
#>
function Clear-TestEnvironment {
    param(
        [string]$User = $script:TestConfig.TestUser,
        [switch]$Force
    )
    
    if (-not $script:TestConfig.CleanupAfterTests -and -not $Force) {
        Write-Host "Cleanup disabled in test configuration" -ForegroundColor Yellow
        return
    }
    
    Write-Host "Cleaning up test environment for user: $User" -ForegroundColor Yellow
    
    # Remove test identities
    $identities = Get-GitIdentities -User $User -Verbosity Silent -ErrorAction SilentlyContinue
    if ($identities) {
        foreach ($identity in $identities) {
            if ($identity.alias -like "*test*" -or $identity.alias -eq $script:TestConfig.TestAlias) {
                Write-Host "Removing test identity: $($identity.alias)" -ForegroundColor Gray
                Remove-GitIdentity -Alias $identity.alias -User $User -Confirm:$false -Verbosity Silent -ErrorAction SilentlyContinue
            }
        }
    }
    
    Write-Host "Test environment cleaned up" -ForegroundColor Green
}

<#
.SYNOPSIS
    Creates a temporary test folder for testing purposes
    
.EXAMPLE
    $testFolder = New-TestFolder -Name "TestRepo"
#>
function New-TestFolder {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name,
        
        [string]$BasePath = $env:TEMP
    )
    
    $folderPath = Join-Path $BasePath $Name
    
    if (-not (Test-Path $folderPath)) {
        New-Item -Path $folderPath -ItemType Directory -Force | Out-Null
    }
    
    return $folderPath
}

<#
.SYNOPSIS
    Removes temporary test folders
    
.EXAMPLE
    Remove-TestFolder -Path $testFolder
#>
function Remove-TestFolder {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )
    
    if (Test-Path $Path) {
        Remove-Item -Path $Path -Recurse -Force -ErrorAction SilentlyContinue
    }
}

<#
.SYNOPSIS
    Validates that a test is running in the expected environment
    
.EXAMPLE
    Assert-TestEnvironment -RequiresAdmin $false
#>
function Assert-TestEnvironment {
    param(
        [bool]$RequiresAdmin = $false,
        [bool]$RequiresGit = $true,
        [bool]$RequiresSsh = $true
    )
    
    if ($RequiresAdmin) {
        $isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")
        if (-not $isAdmin) {
            throw "This test requires administrator privileges"
        }
    }
    
    if ($RequiresGit) {
        try {
            git --version | Out-Null
        }
        catch {
            throw "Git is not available in PATH. Please install Git or ensure it's available."
        }
    }
    
    if ($RequiresSsh) {
        try {
            ssh-keygen 2>&1 | Out-Null
        }
        catch {
            Write-Warning "SSH keygen not available. Some tests may be skipped."
        }
    }
}

<#
.SYNOPSIS
    Gets the current CI environment information
    
.EXAMPLE
    $ciInfo = Get-CIEnvironment
#>
function Get-CIEnvironment {
    return @{
        IsCI = $env:CI -eq 'true' -or $env:GITHUB_ACTIONS -eq 'true'
        IsGitHubActions = $env:GITHUB_ACTIONS -eq 'true'
        Runner = $env:RUNNER_OS
        WorkflowName = $env:GITHUB_WORKFLOW
        RunId = $env:GITHUB_RUN_ID
    }
}

# Functions are available for use in test scripts after dot-sourcing this file