param(
    [Parameter(Mandatory=$true)]
    [string]$ProjectVersion,
    [Parameter(Mandatory=$true)]
    [string]$SourceBranch,
    [Parameter(Mandatory=$true)]
    [string]$BuildNumber,
    [switch]$AsJson
)

Write-Host "=== Validating Release Version ==="
Write-Host "Project Version: $ProjectVersion"
Write-Host "Source Branch: $SourceBranch"
Write-Host "Build Number: $BuildNumber"

############################################################
# Establecer la versión release:
# Si la versión contiene un <prerelease>:
# - releaseVersion: <version>-<prerelease>+<build>
# - dockerVersion: <version>-<prerelease>
# - dockerAlias: <prerelease>
# Sino, si la rama es master o main: 
# - releaseVersion: <version>
# - dockerVersion: <version>
# - dockerAlias: latest
# Sino, si la rama es staging:
# - releaseVersion: <version>-alpha.<build>
# - dockerVersion: <version>-alpha.<build>
# - dockerAlias: alpha
# Sino, si es cualquier otra rama:
# - releaseVersion: <version>-<rama>.<build>
# - dockerVersion: <version>-<rama>.<build>
# - dockerAlias: alpha
# NOTA: <prerelease> podría contener o no puntos. Ejemplos:
# - 1.0.0-beta
# - 1.0.0-beta.1
############################################################

# Regex para parsear version semántica
# https://regex101.com/r/XJjOGd/1
$regex = '(?<version>(?<major>\d+)(?:.(?<minor>\d+))(?:.(?<patch>\d+))?(?:.(?<build>\d+))?)(?:-(?<prerelease>(?:0|[1-9]\d*|\d*[a-zA-Z-][0-9a-zA-Z-]*)(?:\.(?:0|[1-9]\d*|\d*[a-zA-Z-][0-9a-zA-Z-]*))*))?(?:\+(?<buildmetadata>[0-9a-zA-Z-]+(?:\.[0-9a-zA-Z-]+)*))?$'

$result = [ordered]@{
    IsValidVersion = $false
    Version        = $null
    VersionMajor   = $null
    VersionMinor   = $null
    VersionPatch   = $null
    VersionBuild   = $null
    VersionPrerelease = $null
    VersionIsPrerelease   = $false
    ReleaseVersion = $null
    ReleaseAssemblyVersion = $null
    DockerVersion  = $null
    DockerAlias    = $null
}

if ($ProjectVersion -match $regex) {
    Write-Host "✓ Valid semantic version format"
    
    $version = $matches['version']
    $major = $matches['major']
    $minor = $matches['minor']
    $patch = if ($matches['patch']) { $matches['patch'] } else { '0' }
    $build = $matches['build']
    $prerelease = $matches['prerelease']
    
    $result.IsValidVersion = $true
    $result.Version = $version
    $result.VersionMajor = [int]$major
    $result.VersionMinor = [int]$minor
    $result.VersionPatch = [int]$patch
    $result.VersionBuild = if ($build) { [int]$build } else { $null }
    $result.VersionPrerelease = $prerelease
    $result.VersionIsPrerelease = [bool]$prerelease

    if ($prerelease) {
        # The version already has its own suffix
        $prereleaseClean = -join ("$prerelease" -split '[^a-zA-Z0-9-]')
        $releaseVersion = "$ProjectVersion+$BuildNumber"
        $dockerVersion = "$version-$($prereleaseClean)"
        
        if ($prerelease -match '^(?<alias>\w+)') {
            $dockerAlias = $matches['alias']
        } else {
            $dockerAlias = $prereleaseClean
            Write-Warning "Invalid alias '$prerelease'"
        }
    }
    elseif ($SourceBranch -in @('refs/heads/master', 'refs/heads/main')) {
        # Master or main has tag "latest"
        $releaseVersion = $ProjectVersion
        $dockerVersion = $releaseVersion
        $dockerAlias = "latest"
    }
    elseif ($SourceBranch -eq 'refs/heads/staging') {
        # Staging has tag "alpha"
        $prereleaseClean = 'alpha'
        $releaseVersion = "$version-$($prereleaseClean).$BuildNumber"
        $dockerVersion = "$version-$($prereleaseClean).$BuildNumber"
        $dockerAlias = $prereleaseClean
    }
    else {
        # Other branches have the branch name as tag
        $branchName = $SourceBranch -replace 'refs/heads/', ''
        $branchNameClean = -join ("$branchName" -split '[^a-zA-Z0-9]')
        $releaseVersion = "$version-$($branchNameClean).$BuildNumber"
        $dockerVersion = "$version-$($branchNameClean).$BuildNumber"
        $dockerAlias = $branchNameClean
    }

    # Calculate AssemblyVersion
    $releaseAssemblyVersion = "$major.$minor.$patch.$BuildNumber"

    # Update result object
    $result.ReleaseVersion = $releaseVersion
    $result.ReleaseAssemblyVersion = $releaseAssemblyVersion
    $result.DockerVersion = $dockerVersion
    $result.DockerAlias = $dockerAlias
}
else {
    Write-Warning "Invalid version format: $ProjectVersion"
    $result.IsValidVersion = $false
    $result.Version = $ProjectVersion
}

# Output result
if ($AsJson) {
    $result | ConvertTo-Json
} else {
    $result
}

if (-not $result.IsValidVersion) {
    exit 1
}
exit 0

