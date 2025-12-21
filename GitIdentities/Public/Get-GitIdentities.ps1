function Get-GitIdentities {
<#!
.SYNOPSIS
Enumerates Git identities by inspeccionating (1) state file, (2) per-alias gitconfig-* files, (3) global .gitconfig includeIf blocks, and (4) SSH config + keys.
.DESCRIPTION
Devuelve una lista combinada (sin duplicados) de objetos con:
 alias, platform (si detectable), name, email, username, folders, hasSshKey, sshKeyPath, sshHostBlock, sources.
El campo 'sources' indica de dónde se obtuvo cada pieza de información: StateFile, GitConfigAlias, GlobalInclude, SshConfig, SshKey.
Cuando haya conflicto, se prioriza: StateFile > AliasGitConfig > GlobalInclude.
#>
  [CmdletBinding()] param(
    [string]$User,
    [ValidateSet('Silent','Error','Warn','Info','Debug')][string]$Verbosity='Warn'
  )
  $script:GitIdentitiesVerbosity = $Verbosity
  $userHome = Get-GIUserHome -User $User

  $results = @{}
  $addOrMerge = {
    param($alias,$data,$sourceTag)
    # Asegurar propiedad sources en $data
    if (-not ($data.PSObject.Properties.Name -contains 'sources')) {
      Add-Member -InputObject $data -MemberType NoteProperty -Name sources -Value @() -Force
    }
    if (-not $results.ContainsKey($alias)) {
      $data.sources = @($sourceTag)
      # Normalizar folders a array limpio
      if (-not ($data.folders -is [System.Collections.IEnumerable])) { $data.folders = @($data.folders) }
      $data.folders = @($data.folders | Where-Object { $_ }) | Select-Object -Unique
      $results[$alias] = $data
    } else {
      $existing = $results[$alias]
      if (-not ($existing.PSObject.Properties.Name -contains 'sources')) {
        Add-Member -InputObject $existing -MemberType NoteProperty -Name sources -Value @() -Force
      }
      # Merge folders
      if ($data.folders) {
        $existing.folders = @(@($existing.folders)+@($data.folders)) | Where-Object { $_ } | Select-Object -Unique
      }
      foreach ($prop in 'platform','name','email','username') {
        if (-not $existing.$prop -and $data.$prop) { $existing.$prop = $data.$prop }
      }
      if ($data.hasSshKey) { $existing.hasSshKey = $true; if ($data.sshKeyPath) { $existing.sshKeyPath = $data.sshKeyPath } }
      if ($data.sshHostBlock) { $existing.sshHostBlock = $true }
      $existing.sources = @($existing.sources + $sourceTag) | Select-Object -Unique
    }
  }

  # 1. State file
  $statePath = Join-Path $userHome '.gitidentities.json'
  if (Test-Path -LiteralPath $statePath) {
    try {
      $state = Get-Content -LiteralPath $statePath -Raw -Encoding UTF8 | ConvertFrom-Json
      foreach ($id in $state) {
    & $addOrMerge $id.alias ([pscustomobject]@{ alias=$id.alias; platform=$id.platform; name=$id.name; email=$id.email; username=$id.username; folders=@($id.folders); hasSshKey=$false; sshKeyPath=$null; sshHostBlock=$false; sources=@() }) 'StateFile'
      }
    } catch { Write-GILog -Level WARN -Message "Failed to parse state file: $($_.Exception.Message)" }
  }

  # 2. Per-alias gitconfig-* files
  Get-ChildItem -Path $userHome -Filter '.gitconfig-*' -File -ErrorAction SilentlyContinue | ForEach-Object {
    $file = $_.FullName
    $alias = ($_.Name -replace '^\.gitconfig-','')
    $lines = Get-Content -LiteralPath $file -Encoding UTF8
    $name = ($lines | Where-Object { $_ -match '^\s*name\s*=\s*' } | Select-Object -First 1) -replace '^\s*name\s*=\s*',''
    $email = ($lines | Where-Object { $_ -match '^\s*email\s*=\s*' } | Select-Object -First 1) -replace '^\s*email\s*=\s*',''
    $username = ($lines | Where-Object { $_ -match '^\s*username\s*=\s*' } | Select-Object -First 1) -replace '^\s*username\s*=\s*',''
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
    & $addOrMerge $alias ([pscustomobject]@{ alias=$alias; platform=$null; name=$name; email=$email; username=$username; folders=@(); credentials=$creds; hasSshKey=$false; sshKeyPath=$null; sshHostBlock=$false; sources=@() }) 'GitConfigAlias'
  }

  # 3. Global .gitconfig includeIf blocks
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
            # Extract folder from condition using non-greedy until closing quote
            $folder = $null
            if ($line -match 'gitdir:([^"\]]+)') { $folder = $Matches[1] }
            if ($folder) {
              # Normalizar: asegurar barra final y limpiar caracteres basura
              $folder = $folder.Trim().TrimEnd('"',']')
              if ($folder -notmatch '/$') { $folder += '/' }
            }
            & $addOrMerge $alias ([pscustomobject]@{ alias=$alias; platform=$null; name=$null; email=$null; username=$null; folders=@($folder); hasSshKey=$false; sshKeyPath=$null; sshHostBlock=$false; sources=@() }) 'GlobalInclude'
          }
        }
        $i = $j-1
      }
    }
  }

  # 4. SSH config + keys
  $sshDir = Join-Path $userHome '.ssh'
  $sshConfig = Join-Path $sshDir 'config'
  $presentKeys = @{}
  if (Test-Path -LiteralPath $sshDir) {
    Get-ChildItem -Path $sshDir -Filter 'id_*' -File -ErrorAction SilentlyContinue | Where-Object { $_.Name -notlike '*.pub' } | ForEach-Object {
      $alias = ($_.Name -replace '^id_','')
      $presentKeys[$alias] = $_.FullName
  & $addOrMerge $alias ([pscustomobject]@{ alias=$alias; platform=$null; name=$null; email=$null; username=$null; folders=@(); hasSshKey=$true; sshKeyPath=$_.FullName; sshHostBlock=$false; sources=@() }) 'SshKey'
    }
  }
  if (Test-Path -LiteralPath $sshConfig) {
    $clines = Get-Content -LiteralPath $sshConfig -Encoding UTF8
    for ($i=0; $i -lt $clines.Count; $i++) {
      $line = $clines[$i]
      if ($line -match '^Host\s+') {
        $alias = ($line -split '\s+')[1]
        # capture block until next Host
        $j=$i+1
        while ($j -lt $clines.Count -and $clines[$j] -notmatch '^Host\s+') { $j++ }
          # Infer platform from HostName line inside block
          $blockHostName = ($clines[($i+1)..($j-1)] | Where-Object { $_ -match '^\s*HostName\s+' } | Select-Object -First 1)
          $plat = $null
          if ($blockHostName) {
            $hn = ($blockHostName -split '\s+')[1]
            switch -Regex ($hn) {
              'github\.com' { $plat='github'; break }
              'ssh\.dev\.azure\.com' { $plat='azure'; break }
              'gitlab\.com' { $plat='gitlab'; break }
              'bitbucket\.org' { $plat='bitbucket'; break }
            }
          }
          & $addOrMerge $alias ([pscustomobject]@{ alias=$alias; platform=$plat; rawHostName=$hn; name=$null; email=$null; username=$null; folders=@(); hasSshKey=($presentKeys.ContainsKey($alias)); sshKeyPath=($presentKeys[$alias]); sshHostBlock=$true; sources=@() }) 'SshConfig'
        $i=$j-1
      }
    }
  }

  # Convertir a salida ordenada
  $objects = @()
  foreach ($k in $results.Keys | Sort-Object) {
    $obj = $results[$k]
    # Platform: derivar únicamente del primer host de credentials si existe.
    $obj.platform = $null
    if ($obj.PSObject.Properties.Name -contains 'credentials' -and $obj.credentials -and $obj.credentials.Count -gt 0) {
      $firstCred = ($obj.credentials | Where-Object { $_.url })[0]
      if ($firstCred) {
        $u = $firstCred.url
        if ($u.EndsWith('/')) { $u = $u.TrimEnd('/') }
        $host = $null
        if ($u -match '^[a-zA-Z][a-zA-Z0-9+.-]*://([^/]+)') { $host = $Matches[1] }
        elseif ($u -match '^([^/]+)(/|$)') { $host = $Matches[1] }
        if ($host) {
          $hl = $host.ToLowerInvariant()
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
    elseif ($obj.PSObject.Properties.Name -contains 'rawHostName' -and $obj.rawHostName) {
      # Sin credentials usamos host del bloque SSH únicamente
      $obj.platform = $obj.rawHostName.ToLowerInvariant()
    }
    # Colapsar campos SSH en un objeto ssh
    $sshObj = [pscustomobject]@{
      hasKey = $obj.hasSshKey
      keyPath = $obj.sshKeyPath
      hasHostConfig = $obj.sshHostBlock
    }
    # Remover propiedades antiguas
    $null = $obj.PSObject.Properties.Remove('hasSshKey')
    $null = $obj.PSObject.Properties.Remove('sshKeyPath')
    $null = $obj.PSObject.Properties.Remove('sshHostBlock')
    # Añadir propiedad ssh
    Add-Member -InputObject $obj -MemberType NoteProperty -Name ssh -Value $sshObj -Force
    # Sources: sólo mostrar en Verbosity Debug
    if ($Verbosity -eq 'Debug') {
      if ($obj.sources -and ($obj.sources -isnot [string])) { $obj.sources = ($obj.sources -join ',') }
    } else {
      $null = $obj.PSObject.Properties.Remove('sources')
    }
    # remover rawHostName siempre (no lo necesitamos en salida simplificada)
    if ($obj.PSObject.Properties.Name -contains 'rawHostName') { $null = $obj.PSObject.Properties.Remove('rawHostName') }
    # ocultar credentials en salida (se usó sólo para derivar platform)
    if ($obj.PSObject.Properties.Name -contains 'credentials') { $null = $obj.PSObject.Properties.Remove('credentials') }
    $objects += $obj
  }
  return $objects
}
