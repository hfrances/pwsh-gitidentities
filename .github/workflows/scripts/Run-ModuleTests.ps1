
# Run-ModuleTests.ps1
# Compatible con PowerShell 5.1 y superior

Write-Host "Versión de PowerShell:"
$psver = $PSVersionTable.PSVersion
Write-Host $psver

# === Module Syntax Validation ===
$moduleFiles = Get-ChildItem -Path "GitIdentities" -Recurse -Filter "*.ps1"
$errors = @()
foreach ($file in $moduleFiles) {
    Write-Host ("Checking: {0}" -f $file.FullName)
    $content = Get-Content $file.FullName -Raw
    $null = $null
    $parseError = $null
    try {
        $null = [System.Management.Automation.PSParser]::Tokenize($content, [ref]$parseError)
        Write-Host "  OK" -ForegroundColor Green
    } catch {
        Write-Host ("  SYNTAX ERROR: {0}" -f $_.Exception.Message) -ForegroundColor Red
        $errors += ("{0}: {1}" -f $file.Name, $_.Exception.Message)
    }
}
if ($errors.Count -gt 0) {
    Write-Host "`n=== SYNTAX ERRORS FOUND ===" -ForegroundColor Red
    $errors | ForEach-Object { Write-Host ("  {0}" -f $_) -ForegroundColor Red }
    exit 1
}
Write-Host "`nAll files passed syntax validation" -ForegroundColor Green

# Prepare test user home and .gitconfig
$TestUser = "patata"
$TestUserHome = "C:\Users\$TestUser"
if (-not (Test-Path $TestUserHome)) {
    New-Item -Path $TestUserHome -ItemType Directory -Force | Out-Null
}
$gitconfig = Join-Path $TestUserHome ".gitconfig"
if (-not (Test-Path $gitconfig)) {
    Set-Content -Path $gitconfig -Value "" -Encoding UTF8
}
Write-Host ("Test user home and .gitconfig prepared at {0}" -f $TestUserHome) -ForegroundColor Green

# Instalar Pester si no está disponible
if (-not (Get-Module -ListAvailable -Name Pester)) {
    Install-Module -Name Pester -Force -SkipPublisherCheck
}
Import-Module Pester -Force
Write-Host "Pester installed and imported" -ForegroundColor Green

# Ejecutar todos los tests Pester en la carpeta Tests
Invoke-Pester -Path ./Tests -Output Detailed
Write-Host ""
Write-Host ("PowerShell Version: {0}" -f $psver)
Write-Host ("OS: {0}" -f $env:OS)
Write-Host ("Test Date: {0}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss UTC'))
# Mostrar artefactos de test si existen
if (Test-Path "Tests\*TestResults.xml") {
    Write-Host "`nTest result files created:"
    Get-ChildItem "Tests\*TestResults.xml" | ForEach-Object { Write-Host ("  - {0}" -f $_.Name) }
}
