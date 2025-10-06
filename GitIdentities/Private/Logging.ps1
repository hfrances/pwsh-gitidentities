# Logging utilities
param()

$script:GitIdentitiesVerbosityRank = @{ 'Silent'=0;'Error'=1;'Warn'=2;'Info'=3;'Debug'=4 }
if (-not $script:GitIdentitiesVerbosity) { $script:GitIdentitiesVerbosity = 'Info' }

function Write-GILog {
    [CmdletBinding()] param([ValidateSet('ERROR','WARN','INFO','DEBUG','CHANGE')]$Level,[string]$Message)
    $rank = switch ($Level) {'ERROR'{1};'WARN'{2};'INFO'{3};'CHANGE'{3};'DEBUG'{4}}
    $current = $script:GitIdentitiesVerbosityRank[$script:GitIdentitiesVerbosity]
    if ($rank -le $current) {
        $ts = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
        $line = "$ts [$Level] $Message"
        if ($Level -eq 'ERROR') { Write-Host $line -ForegroundColor Red }
        elseif ($Level -eq 'WARN') { Write-Host $line -ForegroundColor Yellow }
        elseif ($Level -eq 'CHANGE') { Write-Host $line -ForegroundColor Cyan }
        else { Write-Host $line }
        if ($script:GitIdentitiesLogFileUsable) { try { Add-Content -Path $script:GitIdentitiesLogFile -Value $line -Encoding UTF8 -ErrorAction Stop } catch { $script:GitIdentitiesLogFileUsable=$false } }
    }
}

function Set-GILogFile {
    [CmdletBinding()] param([string]$UserHome,[switch]$FileLog)
    $script:GitIdentitiesLogFileUsable = $false
    if (-not $FileLog) { return }
    $log = Join-Path $UserHome 'git-identities-module.log'
    $script:GitIdentitiesLogFile = $log
    try {
        if (-not (Test-Path -LiteralPath $log)) { New-Item -ItemType File -Path $log -Force -ErrorAction Stop | Out-Null }
        Add-Content -Path $log -Value "--- init $(Get-Date) ---" -Encoding UTF8 -ErrorAction Stop
        $script:GitIdentitiesLogFileUsable = $true
    } catch {
        Write-Host "WARN: Cannot init log file $log ($($_.Exception.Message))" -ForegroundColor Yellow
        $script:GitIdentitiesLogFileUsable = $false
    }
}
