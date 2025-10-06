# Invoke-GitIdentitiesTests.ps1
# Comprehensive test runner for GitIdentities module

<#
.SYNOPSIS
    Comprehensive test runner for GitIdentities module
    
.DESCRIPTION
    This script orchestrates the execution of different test suites for the GitIdentities module,
    including unit tests, integration tests, and CI/CD pipeline validation.
    
.PARAMETER TestSuite
    Specifies which test suite to run
    
.PARAMETER User
    Specifies the user for cross-user testing (default: patata)
    
.PARAMETER SkipCleanup
    Skip cleanup after tests complete
    
.PARAMETER CI
    Run in CI mode with appropriate configurations
    
.EXAMPLE
    .\Invoke-GitIdentitiesTests.ps1 -TestSuite All
    
.EXAMPLE
    .\Invoke-GitIdentitiesTests.ps1 -TestSuite Unit -User patata
    
.EXAMPLE
    .\Invoke-GitIdentitiesTests.ps1 -TestSuite Integration -CI
#>

[CmdletBinding()]
param(
    [Parameter()]
    [ValidateSet("All", "Unit", "Integration", "CI", "Manual")]
    [string]$TestSuite = "All",
    
    [Parameter()]
    [string]$User = "patata",
    
    [Parameter()]
    [switch]$SkipCleanup,
    
    [Parameter()]
    [switch]$CI,
    
    [Parameter()]
    [ValidateSet("Silent", "Minimal", "Normal", "Verbose")]
    [string]$Verbosity = "Normal"
)

# Initialize
$ErrorActionPreference = "Stop"
$script:TestResults = @{
    Unit = @{ Passed = 0; Failed = 0; Skipped = 0; Errors = @() }
    Integration = @{ Passed = 0; Failed = 0; Skipped = 0; Errors = @() }
    Overall = @{ StartTime = Get-Date; EndTime = $null; Duration = $null }
}

# Import required modules
$ModulePath = Join-Path $PSScriptRoot "..\GitIdentities"
$TestConfigPath = Join-Path $PSScriptRoot "TestConfig.ps1"

if (-not (Test-Path $ModulePath)) {
    throw "GitIdentities module not found at: $ModulePath"
}

if (-not (Test-Path $TestConfigPath)) {
    throw "Test configuration not found at: $TestConfigPath"
}

# Import test configuration
. $TestConfigPath

# Import GitIdentities module
Import-Module $ModulePath -Force

Write-Host "GitIdentities Test Runner Started" -ForegroundColor Cyan
Write-Host "Test Suite: $TestSuite" -ForegroundColor White
Write-Host "User: $User" -ForegroundColor White
Write-Host "CI Mode: $CI" -ForegroundColor White
Write-Host "Verbosity: $Verbosity" -ForegroundColor White
Write-Host ("=" * 60) -ForegroundColor Gray

<#
.SYNOPSIS
    Runs unit tests using Pester
#>
function Invoke-UnitTests {
    param([string]$User)
    
    Write-Host "Running Unit Tests..." -ForegroundColor Yellow
    
    try {
        $unitTestPath = Join-Path $PSScriptRoot "GitIdentities.Unit.Tests.ps1"
        
        if (-not (Test-Path $unitTestPath)) {
            throw "Unit test file not found: $unitTestPath"
        }
        
        # Configure Pester (compatible with both v4 and v5)
        $pesterVersion = (Get-Module Pester).Version
        
        if ($pesterVersion.Major -ge 5) {
            # Pester v5+ configuration
            $pesterConfig = @{
                Run = @{
                    Path = $unitTestPath
                }
                Output = @{
                    Verbosity = $Verbosity
                }
                TestResult = @{
                    Enabled = $true
                    OutputPath = Join-Path $PSScriptRoot "UnitTestResults.xml"
                    OutputFormat = "NUnitXml"
                }
            }
            
            if ($CI) {
                $pesterConfig.CodeCoverage = @{
                    Enabled = $true
                    Path = "$ModulePath\**\*.ps1"
                    OutputPath = Join-Path $PSScriptRoot "UnitCoverage.xml"
                    OutputFormat = "JaCoCo"
                }
            }
            
            $result = Invoke-Pester -Configuration $pesterConfig
        }
        else {
            # Pester v4 configuration
            $pesterParams = @{
                Script = $unitTestPath
                OutputFile = Join-Path $PSScriptRoot "UnitTestResults.xml"
                OutputFormat = "NUnitXml"
                PassThru = $true
            }
            
            if ($CI) {
                $pesterParams.CodeCoverage = "$ModulePath\**\*.ps1"
                $pesterParams.CodeCoverageOutputFile = Join-Path $PSScriptRoot "UnitCoverage.xml"
            }
            
            $result = Invoke-Pester @pesterParams
        }
        
        $script:TestResults.Unit.Passed = $result.PassedCount
        $script:TestResults.Unit.Failed = $result.FailedCount
        $script:TestResults.Unit.Skipped = $result.SkippedCount
        
        if ($result.FailedCount -gt 0) {
            $script:TestResults.Unit.Errors = $result.Failed
            Write-Host "❌ Unit Tests Failed: $($result.FailedCount) failures" -ForegroundColor Red
        }
        else {
            Write-Host "✅ Unit Tests Passed: $($result.PassedCount) tests" -ForegroundColor Green
        }
        
        return $result.FailedCount -eq 0
    }
    catch {
        Write-Host "💥 Unit Tests Error: $($_.Exception.Message)" -ForegroundColor Red
        $script:TestResults.Unit.Errors += $_.Exception
        return $false
    }
}

<#
.SYNOPSIS
    Runs integration tests using Pester
#>
function Invoke-IntegrationTests {
    param([string]$User)
    
    Write-Host "Running Integration Tests..." -ForegroundColor Yellow
    
    try {
        $integrationTestPath = Join-Path $PSScriptRoot "GitIdentities.Tests.ps1"
        
        if (-not (Test-Path $integrationTestPath)) {
            throw "Integration test file not found: $integrationTestPath"
        }
        
        # Initialize test environment
        Initialize-TestEnvironment -User $User
        
        # Configure Pester (compatible with both v4 and v5)
        $pesterVersion = (Get-Module Pester).Version
        
        # Set environment variables for tests
        $env:GITIDENTITIES_TEST_USER = $User
        $env:GITIDENTITIES_CI_MODE = $CI.ToString()
        
        if ($pesterVersion.Major -ge 5) {
            # Pester v5+ configuration
            $pesterConfig = @{
                Run = @{
                    Path = $integrationTestPath
                }
                Output = @{
                    Verbosity = $Verbosity
                }
                TestResult = @{
                    Enabled = $true
                    OutputPath = Join-Path $PSScriptRoot "IntegrationTestResults.xml"
                    OutputFormat = "NUnitXml"
                }
            }
            
            $result = Invoke-Pester -Configuration $pesterConfig
        }
        else {
            # Pester v4 configuration
            $pesterParams = @{
                Script = $integrationTestPath
                OutputFile = Join-Path $PSScriptRoot "IntegrationTestResults.xml"
                OutputFormat = "NUnitXml"
                PassThru = $true
            }
            
            $result = Invoke-Pester @pesterParams
        }
        
        $script:TestResults.Integration.Passed = $result.PassedCount
        $script:TestResults.Integration.Failed = $result.FailedCount
        $script:TestResults.Integration.Skipped = $result.SkippedCount
        
        if ($result.FailedCount -gt 0) {
            $script:TestResults.Integration.Errors = $result.Failed
            Write-Host "❌ Integration Tests Failed: $($result.FailedCount) failures" -ForegroundColor Red
        }
        else {
            Write-Host "✅ Integration Tests Passed: $($result.PassedCount) tests" -ForegroundColor Green
        }
        
        return $result.FailedCount -eq 0
    }
    catch {
        Write-Host "💥 Integration Tests Error: $($_.Exception.Message)" -ForegroundColor Red
        $script:TestResults.Integration.Errors += $_.Exception
        return $false
    }
    finally {
        # Cleanup test environment
        if (-not $SkipCleanup) {
            Clear-TestEnvironment -User $User
        }
    }
}

<#
.SYNOPSIS
    Runs manual validation tests
#>
function Invoke-ManualTests {
    param([string]$User)
    
    Write-Host "Running Manual Validation Tests..." -ForegroundColor Yellow
    
    try {
        # Test 1: Basic identity creation
        Write-Host "Test 1: Creating test identity..." -ForegroundColor Cyan
        Add-GitIdentity -Alias "manualtest" -Name "Manual Test User" -Email "manual@test.com" -Username "manualtest" -Folders @("C:\Temp\TestRepo") -User $User -Verbosity $Verbosity
        
        # Test 2: Verify provisioning
        Write-Host "Test 2: Verifying provisioning..." -ForegroundColor Cyan
        $provisionStatus = Test-GitIdentityProvision -Alias "manualtest" -User $User
        
        if ($provisionStatus.missing.Count -eq 0) {
            Write-Host "✅ Manual Test 2 Passed: All artifacts provisioned" -ForegroundColor Green
            $script:TestResults.Integration.Passed += 1
        }
        else {
            Write-Host "❌ Manual Test 2 Failed: Missing artifacts: $($provisionStatus.missing -join ', ')" -ForegroundColor Red
            $script:TestResults.Integration.Failed += 1
        }
        
        # Test 3: List identities
        Write-Host "Test 3: Listing identities..." -ForegroundColor Cyan
        $identities = Get-GitIdentities -User $User -Verbosity $Verbosity
        
        if ($identities | Where-Object { $_.alias -eq "manualtest" }) {
            Write-Host "✅ Manual Test 3 Passed: Identity found in list" -ForegroundColor Green
            $script:TestResults.Integration.Passed += 1
        }
        else {
            Write-Host "❌ Manual Test 3 Failed: Identity not found in list" -ForegroundColor Red
            $script:TestResults.Integration.Failed += 1
        }
        
        # Test 4: Remove identity
        Write-Host "Test 4: Removing test identity..." -ForegroundColor Cyan
        Remove-GitIdentity -Alias "manualtest" -User $User -Confirm:$false -Verbosity $Verbosity
        
        # Test 5: Verify removal
        Write-Host "Test 5: Verifying removal..." -ForegroundColor Cyan
        $postRemovalStatus = Test-GitIdentityProvision -Alias "manualtest" -User $User
        
        if ($postRemovalStatus.stateEntry -eq $false) {
            Write-Host "✅ Manual Test 5 Passed: Identity removed from state" -ForegroundColor Green
            $script:TestResults.Integration.Passed += 1
        }
        else {
            Write-Host "❌ Manual Test 5 Failed: Identity still in state" -ForegroundColor Red
            $script:TestResults.Integration.Failed += 1
        }
        
        return $script:TestResults.Integration.Failed -eq 0
    }
    catch {
        Write-Host "💥 Manual Tests Error: $($_.Exception.Message)" -ForegroundColor Red
        $script:TestResults.Integration.Errors += $_.Exception
        return $false
    }
}

<#
.SYNOPSIS
    Displays test summary
#>
function Show-TestSummary {
    $script:TestResults.Overall.EndTime = Get-Date
    $script:TestResults.Overall.Duration = $script:TestResults.Overall.EndTime - $script:TestResults.Overall.StartTime
    
    Write-Host ("-" * 60) -ForegroundColor Gray
    Write-Host "Test Summary" -ForegroundColor Cyan
    Write-Host ("-" * 60) -ForegroundColor Gray
    
    Write-Host "Duration: $($script:TestResults.Overall.Duration.ToString('mm\:ss'))" -ForegroundColor White
    
    if ($TestSuite -eq "All" -or $TestSuite -eq "Unit") {
        Write-Host "Unit Tests:" -ForegroundColor Yellow
        Write-Host "  ✅ Passed: $($script:TestResults.Unit.Passed)" -ForegroundColor Green
        Write-Host "  ❌ Failed: $($script:TestResults.Unit.Failed)" -ForegroundColor Red
        Write-Host "  Skipped: $($script:TestResults.Unit.Skipped)" -ForegroundColor Yellow
    }
    
    if ($TestSuite -eq "All" -or $TestSuite -eq "Integration" -or $TestSuite -eq "Manual") {
        Write-Host "Integration Tests:" -ForegroundColor Yellow
        Write-Host "  ✅ Passed: $($script:TestResults.Integration.Passed)" -ForegroundColor Green
        Write-Host "  ❌ Failed: $($script:TestResults.Integration.Failed)" -ForegroundColor Red
        Write-Host "  Skipped: $($script:TestResults.Integration.Skipped)" -ForegroundColor Yellow
    }
    
    $totalFailed = $script:TestResults.Unit.Failed + $script:TestResults.Integration.Failed
    $totalPassed = $script:TestResults.Unit.Passed + $script:TestResults.Integration.Passed
    
    Write-Host ("-" * 60) -ForegroundColor Gray
    
    if ($totalFailed -eq 0) {
        Write-Host "SUCCESS: All Tests Passed! ($totalPassed total)" -ForegroundColor Green
        return $true
    }
    else {
        Write-Host "FAILED: Tests Failed! ($totalFailed failures, $totalPassed successes)" -ForegroundColor Red
        return $false
    }
}

# Main execution
try {
    # Check environment
    Assert-TestEnvironment -RequiresGit $true -RequiresSsh (-not $CI)
    
    $allPassed = $true
    
    switch ($TestSuite) {
        "Unit" {
            $allPassed = Invoke-UnitTests -User $User
        }
        "Integration" {
            $allPassed = Invoke-IntegrationTests -User $User
        }
        "Manual" {
            $allPassed = Invoke-ManualTests -User $User
        }
        "CI" {
            $allPassed = (Invoke-UnitTests -User $User) -and (Invoke-IntegrationTests -User $User)
        }
        "All" {
            $unitResult = Invoke-UnitTests -User $User
            $integrationResult = Invoke-IntegrationTests -User $User
            $allPassed = $unitResult -and $integrationResult
        }
    }
    
    $summaryResult = Show-TestSummary
    
    if (-not $allPassed -or -not $summaryResult) {
        exit 1
    }
    else {
        exit 0
    }
}
catch {
    Write-Host "FATAL ERROR: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host $_.ScriptStackTrace -ForegroundColor Red
    exit 1
}