# Test PowerShell 5.1 Compatibility
Write-Host "Testing PowerShell 5.1 Compatibility..." -ForegroundColor Cyan
Write-Host "PowerShell Version: $($PSVersionTable.PSVersion)" -ForegroundColor Yellow

$errors = @()

# Test 1: UTF8Encoding
try {
    $enc = [System.Text.UTF8Encoding]::new($false)
    Write-Host "[OK] UTF8Encoding::new() works" -ForegroundColor Green
} catch {
    $errors += "UTF8Encoding::new() failed: $_"
    Write-Host "[FAIL] UTF8Encoding::new() failed" -ForegroundColor Red
}

# Test 2: ChoiceDescription
try {
    $choice = [System.Management.Automation.Host.ChoiceDescription]::new("&Yes", "Test")
    Write-Host "[OK] ChoiceDescription::new() works" -ForegroundColor Green
} catch {
    $errors += "ChoiceDescription::new() failed: $_"
    Write-Host "[FAIL] ChoiceDescription::new() failed" -ForegroundColor Red
}

# Test 3: Import the module
try {
    $ModulePath = Join-Path $PSScriptRoot "..\GitIdentities"
    Import-Module $ModulePath -Force -ErrorAction Stop
    Write-Host "[OK] Module imports successfully" -ForegroundColor Green
    
    $commands = Get-Command -Module GitIdentities
    if ($commands.Count -gt 0) {
        Write-Host "[OK] Module exports $($commands.Count) commands" -ForegroundColor Green
    }
} catch {
    $errors += "Module import failed: $_"
    Write-Host "[FAIL] Module import failed" -ForegroundColor Red
}

if ($errors.Count -eq 0) {
    Write-Host "`n[SUCCESS] All compatibility tests passed!" -ForegroundColor Green
    exit 0
} else {
    Write-Host "`n[FAILED] $($errors.Count) compatibility issues found" -ForegroundColor Red
    exit 1
}
