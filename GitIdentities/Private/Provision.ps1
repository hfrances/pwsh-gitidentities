<# Provision helpers (re-written minimal to resolve parse issues) #>

function Get-GIAliasCanonicalHost {
  param([string]$Alias,[string]$Email)
  if (-not $Alias) { return 'unknown' }
  $a = $Alias.ToLowerInvariant()
  if ($a -match 'github') { return 'github.com' }
  if ($a -match 'gitlab') { return 'gitlab.com' }
  if ($a -match 'azure|devops') { return 'dev.azure.com' }
  if ($a -match 'bitbucket') { return 'bitbucket.org' }
  if ($Email -and $Email -match '@(.+)$') { return $Matches[1] }
  'unknown'
}

function Set-GIAliasGitConfig {
  param([string]$UserHome,[string]$Alias,[string]$Name,[string]$Email,[string]$Username,[switch]$DryRun)
  if (-not $UserHome -or -not $Alias) { return }
  $file = Join-Path $UserHome ('.gitconfig-' + $Alias)
  $h = Get-GIAliasCanonicalHost -Alias $Alias -Email $Email
  $credUrl = 'https://' + $h + '/'
  $lines = @()
  $lines += '# managed-by: gitidentities-module alias=' + $Alias + ' section=user'
  $lines += '[user]'
  $lines += '    name = ' + $Name
  $lines += '    email = ' + $Email
  $lines += '# managed-by: gitidentities-module alias=' + $Alias + ' section=credential'
  $lines += '[credential "' + $credUrl + '"]'
  $lines += '    username = ' + $Username
  $content = [string]::Join([Environment]::NewLine,$lines)
  Set-GIFileContentIfChanged -Path $file -Content $content -DryRun:$DryRun | Out-Null
  return $file
}

function Set-GIIncludeIfBlocks {
  param([string]$UserHome,[string]$Alias,[string[]]$Folders,[switch]$DryRun)
  if (-not $Folders -or $Folders.Count -eq 0) { return }
  $global = Join-Path $UserHome '.gitconfig'
  if (-not (Test-Path -LiteralPath $global) -and -not $DryRun) { '' | Out-File -FilePath $global -Encoding utf8 -NoNewline }
  $existing = if (Test-Path -LiteralPath $global) { Get-Content -LiteralPath $global -Encoding UTF8 } else { @() }
  foreach ($folder in $Folders) {
    $norm = Get-GINormalizedFolderPath -Path $folder
    if (-not $norm) { continue }
    $marker = "$script:GIManagedMarkerPrefix alias=$Alias folder=$norm"
    if ($existing | Where-Object { $_ -like "*$marker*" }) { Write-GILog -Level DEBUG -Message "includeIf exists for $Alias -> $norm"; continue }
    $block = @()
    $block += $marker
    $block += '[includeIf "gitdir:' + $norm + '"]'
    $block += '    path = ~/.gitconfig-' + $Alias
    $text = [string]::Join([Environment]::NewLine,$block)
    if ($DryRun) { Write-GILog -Level CHANGE -Message "[DryRun] Would append includeIf for $Alias -> $norm" } else { Add-Content -LiteralPath $global -Value $text; Write-GILog -Level CHANGE -Message "Added includeIf for $Alias -> $norm" }
  }
}

function Remove-GIIncludeIfBlocks {
  param([string]$UserHome,[string]$Alias,[string[]]$Folders,[switch]$All,[switch]$DryRun)
  $global = Join-Path $UserHome '.gitconfig'
  if (-not (Test-Path -LiteralPath $global)) { return }
  $lines = Get-Content -LiteralPath $global -Encoding UTF8
  $targets = @(); if (-not $All -and $Folders) { $targets = $Folders | ForEach-Object { Get-GINormalizedFolderPath -Path $_ } }
  $out=@(); $removed=0
  for ($i=0; $i -lt $lines.Count; $i++) {
    $l = $lines[$i]
    if ($l -like "*$script:GIManagedMarkerPrefix*" -and $l -like "*alias=$Alias*") {
      $match=$true
      if (-not $All -and $targets.Count -gt 0) { $match=$false; foreach($t in $targets){ if($l -like "*folder=$t*"){$match=$true;break} } }
      if ($match) { 
        if ($i+2 -lt $lines.Count) { $i+=2 }
        $removed++
        $msg = if($DryRun){"[DryRun] Would remove includeIf block for $Alias"} else {"Removed includeIf block for $Alias"}
        Write-GILog -Level CHANGE -Message $msg
        continue 
      }
    }
    $out += $l
  }
  if ($removed -gt 0 -and -not $DryRun) { [IO.File]::WriteAllText($global,[string]::Join([Environment]::NewLine,$out),[System.Text.UTF8Encoding]::new($false)) }
}

function Set-GISshKey {
  param([string]$UserHome,[string]$Alias,[string]$Email,[string]$Algorithm,[switch]$Force,[switch]$DryRun)
  $sshDir = Join-Path $UserHome '.ssh'
  $privateKey = Join-Path $sshDir ("id_" + $Alias)
  $publicKey  = $privateKey + '.pub'
  $exists = (Test-Path -LiteralPath $privateKey) -and (Test-Path -LiteralPath $publicKey)
  if ($exists -and -not $Force) {
    Write-GILog -Level DEBUG -Message "SSH key already exists: $privateKey"
    return $privateKey
  }
  if ($exists -and $Force) {
    if ($DryRun) { Write-GILog -Level CHANGE -Message "[DryRun] Would regenerate SSH key for $Alias"; return $privateKey }
    try { Remove-Item -LiteralPath $privateKey -Force -ErrorAction Stop; Remove-Item -LiteralPath $publicKey -Force -ErrorAction SilentlyContinue } catch { Write-GILog -Level WARN -Message "Failed deleting old key for regen: $($_.Exception.Message)" }
    Write-GILog -Level INFO -Message "Regenerating SSH key for $Alias"
  } elseif (-not $exists) {
    if ($DryRun) { Write-GILog -Level CHANGE -Message "[DryRun] Would generate SSH key: $privateKey"; return $privateKey }
    Write-GILog -Level INFO -Message "Generating SSH key for $Alias"
  }
  if (-not (Get-Command ssh-keygen -ErrorAction SilentlyContinue)) { Write-GILog -Level ERROR -Message 'ssh-keygen not found in PATH'; return $null }
  try {
    if (-not (Test-Path -LiteralPath $sshDir)) { New-Item -ItemType Directory -Path $sshDir -Force | Out-Null }
    $cmd = (Get-Command ssh-keygen -ErrorAction SilentlyContinue).Source
    $algo = if ($Algorithm) { $Algorithm.ToLowerInvariant() } else { 'ed25519' }
    if ($algo -eq 'rsa') {
      $argsPrimary = @('-t','rsa','-b','4096','-C',$Email,'-f',$privateKey,'-N','')
    } else {
      $argsPrimary = @('-t','ed25519','-C',$Email,'-f',$privateKey,'-N','')
    }
    Write-GILog -Level DEBUG -Message ("Invoking ssh-keygen primary: {0} {1}" -f $cmd, ($argsPrimary -join ' '))
    $primaryOutput = ssh-keygen @argsPrimary 2>&1
    $primaryOutput | ForEach-Object { $line=$_.ToString().Trim(); if ($line) { Write-GILog -Level DEBUG -Message "ssh-keygen: $line" } }
    $success = ($LASTEXITCODE -eq 0 -and (Test-Path -LiteralPath $privateKey))
    if (-not $success) {
      Write-GILog -Level WARN -Message "Primary ssh-keygen attempt failed (exit $LASTEXITCODE). Trying fallback via cmd.exe"
      $quotedEmail = '"' + $Email + '"'
      $quotedKey = '"' + $privateKey + '"'
      if ($algo -eq 'rsa') {
        $cmdLine = "ssh-keygen -t rsa -b 4096 -C $quotedEmail -f $quotedKey -N `"`"" 
      } else {
        $cmdLine = "ssh-keygen -t ed25519 -C $quotedEmail -f $quotedKey -N `"`"" 
      }
      Write-GILog -Level DEBUG -Message "Fallback command: $cmdLine"
      $fallbackOutput = cmd /c $cmdLine 2>&1
      $fallbackOutput | ForEach-Object { $line=$_.ToString().Trim(); if ($line) { Write-GILog -Level DEBUG -Message "ssh-keygen(fallback): $line" } }
      if (-not (Test-Path -LiteralPath $privateKey) -and $algo -ne 'rsa') {
        Write-GILog -Level WARN -Message "Fallback did not create ed25519 key. Trying RSA 4096"
        $cmdLine2 = "ssh-keygen -t rsa -b 4096 -C $quotedEmail -f $quotedKey -N `"`""
        Write-GILog -Level DEBUG -Message "RSA fallback command: $cmdLine2"
        $rsaOutput = cmd /c $cmdLine2 2>&1
        $rsaOutput | ForEach-Object { $line=$_.ToString().Trim(); if ($line) { Write-GILog -Level DEBUG -Message "ssh-keygen(rsa): $line" } }
      }
    }
    if ((Test-Path -LiteralPath $privateKey)) { Write-GILog -Level CHANGE -Message "SSH key ensured: $privateKey" } else { Write-GILog -Level ERROR -Message "Failed to generate SSH key for $Alias (check permissions/OpenSSH)" }
  } catch {
    Write-GILog -Level ERROR -Message "SSH key generation exception: $($_.Exception.Message)"
  }
  return $privateKey
}

function Set-GISshHostBlock {
  param([string]$UserHome,[string]$Alias,[string]$Platform,[switch]$DryRun)
  $sshDir = Join-Path $UserHome '.ssh'
  $cfg = Join-Path $sshDir 'config'
  if (-not (Test-Path -LiteralPath $sshDir) -and -not $DryRun) { New-Item -ItemType Directory -Path $sshDir | Out-Null }
  $existing = if (Test-Path -LiteralPath $cfg) { Get-Content -LiteralPath $cfg -Encoding UTF8 } else { @() }
  $marker = "$script:GIManagedMarkerPrefix alias=$Alias"
  $clean=@()
  for($i=0;$i -lt $existing.Count;$i++){
    if ($existing[$i] -like "*$marker*") { $i++; while($i -lt $existing.Count -and $existing[$i] -notmatch '^Host '){$i++}; $i--; continue }
    $clean += $existing[$i]
  }
  $hostName = switch($Platform){'github'{'github.com'}'azure'{'ssh.dev.azure.com'}'gitlab'{'gitlab.com'}'bitbucket'{'bitbucket.org'}default{'github.com'}}
  $block=@()
  $block += $marker
  $block += 'Host ' + $Alias
  $block += '  HostName ' + $hostName
  $block += '  IdentityFile ~/.ssh/id_' + $Alias
  $block += '  User git'
  $block += '  IdentitiesOnly yes'
  $text = [string]::Join([Environment]::NewLine,$block)
  if ($DryRun) { Write-GILog -Level CHANGE -Message "[DryRun] Would set SSH host block for $Alias" } else { $clean += $block; [IO.File]::WriteAllText($cfg,[string]::Join([Environment]::NewLine,$clean),[System.Text.UTF8Encoding]::new($false)); Write-GILog -Level CHANGE -Message "SSH host block set for $Alias" }
}

function Remove-GISshHostBlock {
  param([string]$UserHome,[string]$Alias,[switch]$DryRun)
  $sshDir = Join-Path $UserHome '.ssh'
  $cfg = Join-Path $sshDir 'config'
  if (-not (Test-Path -LiteralPath $cfg)) { return }
  $marker = "$script:GIManagedMarkerPrefix alias=$Alias"
  $lines = Get-Content -LiteralPath $cfg -Encoding UTF8
  $out=@(); $removed=$false
  for($i=0;$i -lt $lines.Count;$i++){
    if ($lines[$i] -like "*$marker*") { $removed=$true; $i++; while($i -lt $lines.Count -and $lines[$i] -notmatch '^Host '){$i++}; $i--; continue }
    $out += $lines[$i]
  }
  if ($removed) { if ($DryRun) { Write-GILog -Level CHANGE -Message "[DryRun] Would remove SSH host block for $Alias" } else { [IO.File]::WriteAllText($cfg,[string]::Join([Environment]::NewLine,$out),[System.Text.UTF8Encoding]::new($false)); Write-GILog -Level CHANGE -Message "Removed SSH host block for $Alias" } }
}
