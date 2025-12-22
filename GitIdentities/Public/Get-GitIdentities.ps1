function Get-GitIdentities {
<#
.SYNOPSIS
Enumerates Git identities by reading per-alias gitconfig files and global .gitconfig includeIf blocks.
.DESCRIPTION
Returns a list of identity objects with: alias, platform, name, email, username, folders, ssh.
Information is gathered from:
 - Per-alias gitconfig files (~/.gitconfig-{alias}): user info, credentials, SSH configuration
 - Global .gitconfig includeIf blocks: folder associations
#>
  [CmdletBinding()] param(
    [string]$User,
    [ValidateSet('Silent','Error','Warn','Info','Debug')][string]$Verbosity='Warn'
  )
  $script:GitIdentitiesVerbosity = $Verbosity
  $userHome = Get-GIUserHome -User $User

  $results = @{}
  $addOrMerge = {
    param($alias,$data)
    if (-not $results.ContainsKey($alias)) {
      # Normalizar folders a array limpio
      if (-not ($data.folders -is [System.Collections.IEnumerable])) { $data.folders = @($data.folders) }
      $data.folders = @($data.folders | Where-Object { $_ }) | Select-Object -Unique
      $results[$alias] = $data
    } else {
      $existing = $results[$alias]
      # Merge folders
      if ($data.folders) {
        $existing.folders = @(@($existing.folders)+@($data.folders)) | Where-Object { $_ } | Select-Object -Unique
      }
      # Solo actualizar si no existe (prioridad a gitconfig-alias)
      foreach ($prop in 'platform','name','email','username','ssh') {
        if (-not $existing.$prop -and $data.$prop) { $existing.$prop = $data.$prop }
      }
    }
  }

  # 1. Per-alias gitconfig-* files
  Get-ChildItem -Path $userHome -Filter '.gitconfig-*' -File -ErrorAction SilentlyContinue | ForEach-Object {
    $file = $_.FullName
    $alias = ($_.Name -replace '^\.gitconfig-','')
    $lines = Get-Content -LiteralPath $file -Encoding UTF8
    $name = ($lines | Where-Object { $_ -match '^\s*name\s*=\s*' } | Select-Object -First 1) -replace '^\s*name\s*=\s*',''
    $email = ($lines | Where-Object { $_ -match '^\s*email\s*=\s*' } | Select-Object -First 1) -replace '^\s*email\s*=\s*',''
    $username = ($lines | Where-Object { $_ -match '^\s*username\s*=\s*' } | Select-Object -First 1) -replace '^\s*username\s*=\s*',''
    
    # SSH info: buscar core.sshCommand
    $sshInfo = [pscustomobject]@{ hasKey=$false; keyPath=$null; sshUsers=$null }
    $sshLines = @($lines | Where-Object { $_ -match '^\s*sshCommand\s*=\s*' })
    if ($sshLines.Count -gt 0) {
      # Extract key file from -i parameter (first occurrence)
      $firstLine = $sshLines[0]
      if ($firstLine -match '-i\s+"?([^"\s]+)"?') {
        $keyPath = $Matches[1]
        # Expandir ~ al home del usuario
        if ($keyPath -like '~/*' -or $keyPath -like '~\*') {
          $keyPath = $keyPath -replace '^~[/\\]?', ($userHome + [IO.Path]::DirectorySeparatorChar)
        }
        $sshInfo.keyPath = $keyPath
        $sshInfo.hasKey = Test-Path -LiteralPath $keyPath -ErrorAction SilentlyContinue
      }
      # Extract SSH users from all sshCommand lines
      $sshUsers = @()
      foreach ($line in $sshLines) {
        # Check for {{USERNAME}} token (multi-user)
        if ($line -match '\{\{USERNAME\}\}') {
          if ($line -match 'ssh://([^@]+)@') {
            $sshUsers += $Matches[1]
          }
        }
        # Check for -o User=xxx format
        elseif ($line -match '-o\s+User=(\S+)') {
          $sshUsers += $Matches[1]
        }
        # Check for ssh://user@host format
        elseif ($line -match 'ssh://([^@]+)@') {
          $sshUsers += $Matches[1]
        }
      }
      if ($sshUsers.Count -gt 0) {
        $uniqueUsers = @($sshUsers | Select-Object -Unique)
        $sshInfo.sshUsers = $uniqueUsers -join ', '
      }
    }
    
    # Credenciales: buscar secciones [credential "url"]
    $creds = @()
    for ($i=0; $i -lt $lines.Count; $i++) {
      $l = $lines[$i]
      if ($l -match '^\s*\[credential\s+"([^"]+)"\s*\]') {
        $cUrl = $Matches[1]
        $j=$i+1; $cUser=$null
        while ($j -lt $lines.Count -and $lines[$j] -notmatch '^\s*\[') {
          if ($lines[$j] -match '^\s*username\s*=\s*(.+)$') { $cUser = $Matches[1].Trim() }
          $j++
        }
        $creds += [pscustomobject]@{ url=$cUrl; username=$cUser }
        $i=$j-1
      }
    }
    & $addOrMerge $alias ([pscustomobject]@{ alias=$alias; platform=$null; name=$name; email=$email; username=$username; folders=@(); credentials=$creds; ssh=$sshInfo })
  }

  # 2. Global .gitconfig includeIf blocks
  $globalGit = Join-Path $userHome '.gitconfig'
  if (Test-Path -LiteralPath $globalGit) {
    $glines = Get-Content -LiteralPath $globalGit -Encoding UTF8
    for ($i=0; $i -lt $glines.Count; $i++) {
      $line = $glines[$i]
      if ($line -like '*includeIf*gitdir:*') {
        # Expect next line path = .../.gitconfig-alias
        $block = @($line)
        $j=$i+1
        while ($j -lt $glines.Count -and $glines[$j] -match '^\s' ) { $block += $glines[$j]; $j++ }
        $pathLine = $block | Where-Object { $_ -match '\bpath\s*=\s*' } | Select-Object -First 1
        if ($pathLine) {
          $p = ($pathLine -split '=')[1].Trim()
          if ($p -match '\.gitconfig-(.+)$') {
            $alias = $Matches[1]
            # Extract folder from condition
            $folder = $null
            if ($line -match 'gitdir:([^"\]]+)') { $folder = $Matches[1] }
            if ($folder) {
              # Normalizar: asegurar barra final y limpiar caracteres
              $folder = $folder.Trim().TrimEnd('"',']')
              if ($folder -notmatch '/$') { $folder += '/' }
            }
            & $addOrMerge $alias ([pscustomobject]@{ alias=$alias; platform=$null; name=$null; email=$null; username=$null; folders=@($folder) })
          }
        }
        $i = $j-1
      }
    }
  }

  # Convertir a salida ordenada
  $objects = @()
  foreach ($k in $results.Keys | Sort-Object) {
    $obj = $results[$k]
    # Platform: derivar del primer dominio de credentials si existe
    $obj.platform = $null
    if ($obj.PSObject.Properties.Name -contains 'credentials' -and $obj.credentials -and $obj.credentials.Count -gt 0) {
      $firstCred = ($obj.credentials | Where-Object { $_.url })[0]
      if ($firstCred) {
        $u = $firstCred.url
        if ($u.EndsWith('/')) { $u = $u.TrimEnd('/') }
        $domain = $null
        if ($u -match '^[a-zA-Z][a-zA-Z0-9+.-]*://([^/]+)') { $domain = $Matches[1] }
        elseif ($u -match '^([^/]+)(/|$)') { $domain = $Matches[1] }
        if ($domain) {
          $hl = $domain.ToLowerInvariant()
          switch ($hl) {
            'github.com' { $obj.platform='github' }
            'dev.azure.com' { $obj.platform='azure' }
            'gitlab.com' { $obj.platform='gitlab' }
            'bitbucket.org' { $obj.platform='bitbucket' }
            default { $obj.platform = $hl }
          }
        }
      }
    }
    # Limpiar propiedades internas
    $null = $obj.PSObject.Properties.Remove('credentials')
    $objects += $obj
  }
  return $objects
}
