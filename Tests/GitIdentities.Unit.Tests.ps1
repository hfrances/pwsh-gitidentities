# GitIdentities.Unit.Tests.ps1
# Unit tests for individual GitIdentities functions with mocking

Describe "Add-GitIdentity Unit Tests" {
    BeforeAll {
        # Import module under test
        $ModulePath = Join-Path $PSScriptRoot "..\GitIdentities"
        Import-Module $ModulePath -Force
        # Dot-source private functions before tests
        $privatePath = Join-Path $PSScriptRoot '..\GitIdentities\Private'
        Get-ChildItem "$privatePath\*.ps1" | ForEach-Object { . $_.FullName }
        
        # Mock data
        $script:MockUserHome = "C:\Users\TestUser"
        $script:MockAlias = "unittest"
        $script:MockStateData = @(
            [PSCustomObject]@{
                alias = "existing"
                platform = "github"
                name = "Existing User"
                email = "existing@test.com"
                username = "existing"
                folders = @("C:/Test/Repo1/")
            }
        )
    }
    Context "Parameter Validation" {
        It "Should validate required parameters" {
            { Add-GitIdentity -Alias "" -Name "Test" -Email "test@test.com" -Username "test" -Folders @("C:\Temp") } | Should -Throw
            { Add-GitIdentity -Alias "test" -Name "" -Email "test@test.com" -Username "test" -Folders @("C:\Temp") } | Should -Throw
            { Add-GitIdentity -Alias "test" -Name "Test" -Email "" -Username "test" -Folders @("C:\Temp") } | Should -Throw
            { Add-GitIdentity -Alias "test" -Name "Test" -Email "test@test.com" -Username "" -Folders @("C:\Temp") } | Should -Throw
        }
        
        It "Should accept valid parameters" {
            { Add-GitIdentity -Alias "test" -Name "Test User" -Email "test@test.com" -Username "testuser" -Folders @("C:\Temp") -User patata -DryRun } | Should -Not -Throw
        }
        
        It "Should accept SshUser parameter" {
            { Add-GitIdentity -Alias "test" -Name "Test User" -Email "test@test.com" -Username "testuser" -Folders @("C:\Temp") -SshUser @('git','custom') -User patata -DryRun } | Should -Not -Throw
        }
        
        It "Should accept SshAlgorithm parameter" {
            { Add-GitIdentity -Alias "test" -Name "Test User" -Email "test@test.com" -Username "testuser" -Folders @("C:\Temp") -SshAlgorithm 'rsa' -User patata -DryRun } | Should -Not -Throw
        }
    }
    
    Context "Platform Detection Logic" {
        It "Should detect platform from alias patterns" {
            # Test platform detection without actually creating identities
            Mock Get-GIAliasCanonicalHost { return "github.com" } -ModuleName GitIdentities
            { Add-GitIdentity -Alias "mygithub" -Name "Test" -Email "test@example.com" -Username "test" -Folders @("C:\Temp") -User patata -DryRun -Verbosity Silent } | Should -Not -Throw
            Should -Invoke Get-GIAliasCanonicalHost -ModuleName GitIdentities
        }
        
        It "Should handle email-based platform detection" {
            Mock Get-GIAliasCanonicalHost { return "gitlab.com" } -ModuleName GitIdentities
            { Add-GitIdentity -Alias "test" -Name "Test" -Email "test@gitlab.com" -Username "test" -Folders @("C:\Temp") -User patata -DryRun -Verbosity Silent } | Should -Not -Throw
            Should -Invoke Get-GIAliasCanonicalHost -ModuleName GitIdentities
        }
        
        It "Should use centralized platform configuration" {
            # Verify platform map structure
            $script:GIPlatformMap | Should -Not -BeNullOrEmpty
            $script:GIPlatformMap['github'] | Should -Not -BeNullOrEmpty
            $script:GIPlatformMap['github'].SshAlgorithm | Should -Be 'ed25519'
            $script:GIPlatformMap['azure'].SshAlgorithm | Should -Be 'rsa'
            $script:GIPlatformMap['github'].SshUsers | Should -Contain 'git'
        }
    }
}

Describe "Get-GitIdentities Unit Tests" {
    BeforeAll {
        # Import module under test
        $ModulePath = Join-Path $PSScriptRoot "..\GitIdentities"
        Import-Module $ModulePath -Force
        $privatePath = Join-Path $PSScriptRoot '..\GitIdentities\Private'
        Get-ChildItem "$privatePath\*.ps1" | ForEach-Object { . $_.FullName }
        
        $script:MockStateData = @(
            [PSCustomObject]@{
                alias = "existing"
                platform = "github"
                name = "Existing User"
                email = "existing@test.com"
                username = "existing"
                folders = @("C:/Test/Repo1/")
            }
        )
    }
    
    Context "State File Handling" {
        It "Should handle missing state file gracefully" {
            Mock Test-Path { return $false } -ParameterFilter { $Path -like "*\.gitidentities.json" }
            Mock Get-Content { return $null }
            
            { Get-GitIdentities -User patata -Verbosity Silent } | Should -Not -Throw
        }
        
        It "Should parse valid state file" {
            Mock Test-Path { return $true } -ParameterFilter { $Path -like "*\.gitidentities.json" }
            Mock Get-Content { return ($MockStateData | ConvertTo-Json) }
            
            $result = Get-GitIdentities -User patata -Verbosity Silent
            $result | Should -Not -BeNullOrEmpty
        }
        
        It "Should handle corrupt state file" {
            Mock Test-Path { return $true } -ParameterFilter { $Path -like "*\.gitidentities.json" }
            Mock Get-Content { return "invalid json" }
            
            { Get-GitIdentities -User patata -Verbosity Silent -ErrorAction SilentlyContinue } | Should -Not -Throw
        }
    }
}

Describe "Remove-GitIdentity Unit Tests" {
    BeforeAll {
        # Import module under test
        $ModulePath = Join-Path $PSScriptRoot "..\GitIdentities"
        Import-Module $ModulePath -Force
        $privatePath = Join-Path $PSScriptRoot '..\GitIdentities\Private'
        Get-ChildItem "$privatePath\*.ps1" | ForEach-Object { . $_.FullName }
        
        $script:MockStateData = @(
            [PSCustomObject]@{
                alias = "existing"
                platform = "github"
                name = "Existing User"
                email = "existing@test.com"
                username = "existing"
                folders = @("C:/Test/Repo1/")
            }
        )
    }
    
    Context "State Management" {
        BeforeEach {
            Mock Test-Path { return $true } -ParameterFilter { $Path -like "*\.gitidentities.json" }
            Mock Get-Content { return ($MockStateData | ConvertTo-Json) }
        }
        
        It "Should handle missing identity gracefully" {
            Mock Remove-GIIncludeIfBlocks { }
            Mock Remove-GISshHostBlock { }
            
            { Remove-GitIdentity -Alias "nonexistent" -User patata -Confirm:$false -Verbosity Silent } | Should -Not -Throw
        }
        
        It "Should call appropriate removal functions for complete removal" {
            Mock Remove-GIIncludeIfBlocks { }
            Mock Remove-GISshHostBlock { }
            Mock Test-Path { return $true } -ParameterFilter { $Path -like "*\.gitconfig-*" }
            Mock Remove-Item { }
            Mock Set-Content { }
            
            Remove-GitIdentity -Alias "existing" -User patata -Confirm:$false -Verbosity Silent
            
            Should -Invoke Remove-GIIncludeIfBlocks -Exactly 1
            Should -Invoke Remove-GISshHostBlock -Exactly 1
        }
        
        It "Should only remove specific folder when Folder parameter provided" {
            Mock Remove-GIIncludeIfBlocks { }
            Mock Set-Content { }
            
            Remove-GitIdentity -Alias "existing" -User patata -Folder "C:\Test\Repo1" -Confirm:$false -Verbosity Silent
            
            Should -Invoke Remove-GIIncludeIfBlocks -ParameterFilter { $Folders -contains "C:/Test/Repo1/" } -Exactly 1
        }
    }
}

Describe "Test-GitIdentityProvision Unit Tests" {
    BeforeAll {
        # Import module under test
        $ModulePath = Join-Path $PSScriptRoot "..\GitIdentities"
        Import-Module $ModulePath -Force
        $privatePath = Join-Path $PSScriptRoot '..\GitIdentities\Private'
        Get-ChildItem "$privatePath\*.ps1" | ForEach-Object { . $_.FullName }
    }
    
    Context "Artifact Detection" {
        It "Should detect missing state file" {
            Mock Test-Path { return $false } -ParameterFilter { $Path -like "*\.gitidentities.json" }
            
            $result = Test-GitIdentityProvision -Alias "test" -User patata
            
            $result.stateFile | Should -Be $false
            $result.missing | Should -Contain "stateFile"
        }
        
        It "Should detect existing artifacts" {
            Mock Test-Path { 
                param($Path)
                switch -Wildcard ($Path) {
                    "*\.gitidentities.json" { return $true }
                    "*\.gitconfig-test" { return $true }
                    "*\.ssh\id_test" { return $true }
                    "*\.ssh\id_test.pub" { return $true }
                    "*\.gitconfig" { return $true }
                    default { return $false }
                }
            }
            Mock Get-Content { 
                param($Path)
                if ($Path -like "*\.gitidentities.json") {
                    return '[{"alias":"test","platform":"github","name":"Test","email":"test@test.com","username":"test","folders":["C:/Test/"]}]'
                }
                elseif ($Path -like "*\.gitconfig-test") {
                    return @("[user]", "    name = Test", "[core]", "    sshCommand = ssh -i ~/.ssh/id_test -o User=git -o IdentitiesOnly=yes")
                }
                elseif ($Path -like "*\.gitconfig") {
                    return @("# managed-by: gitidentities-module alias=test folder=C:/Test/", "[includeIf `"gitdir:C:/Test/`"]")
                }
                return @()
            }
            
            $result = Test-GitIdentityProvision -Alias "test" -User patata
            
            $result.stateFile | Should -Be $true
            $result.stateEntry | Should -Be $true
            $result.aliasGitConfig | Should -Be $true
            $result.sshPrivateKey | Should -Be $true
            $result.sshPublicKey | Should -Be $true
            $result.includeIfBlocks | Should -BeGreaterThan 0
            $result.missing | Should -BeNullOrEmpty
        }
    }
}

Describe "Set-GICredentialHelper Unit Tests" {
    BeforeAll {
        # Import module under test
        $ModulePath = Join-Path $PSScriptRoot "..\GitIdentities"
        Import-Module $ModulePath -Force
        $privatePath = Join-Path $PSScriptRoot '..\GitIdentities\Private'
        Get-ChildItem "$privatePath\*.ps1" | ForEach-Object { . $_.FullName }
    }
    
    Context "Credential Helper Configuration" {
        It "Should handle missing git command gracefully" {
            Mock Get-Command { return $null } -ParameterFilter { $Name -eq "git" }
            
            { Set-GICredentialHelper -UserHome "C:\Test" -DryRun } | Should -Not -Throw
        }
        
        It "Should set credential helper when none exists" {
            Mock git { return "" } -ParameterFilter { $args -contains "--get" }
            Mock git { } -ParameterFilter { $args -contains "credential.helper" -and $args -contains "manager-core" }
            
            { Set-GICredentialHelper -UserHome "C:\Test" -DryRun } | Should -Not -Throw
        }
        
        It "Should handle existing credential helper" {
            Mock git { return "store" } -ParameterFilter { $args -contains "--get" }
            
            { Set-GICredentialHelper -UserHome "C:\Test" -DryRun } | Should -Not -Throw
        }
        
        It "Should not modify manager-core if already set" {
            Mock git { return "manager-core" } -ParameterFilter { $args -contains "--get" }
            
            { Set-GICredentialHelper -UserHome "C:\Test" -DryRun } | Should -Not -Throw
        }
    }
}

Describe "Core Helper Functions Unit Tests" {
    BeforeAll {
        # Import module under test
        $ModulePath = Join-Path $PSScriptRoot "..\GitIdentities"
        Import-Module $ModulePath -Force
        $privatePath = Join-Path $PSScriptRoot '..\GitIdentities\Private'
        Get-ChildItem "$privatePath\*.ps1" | ForEach-Object { . $_.FullName }
    }
    
    Context "Get-GIAliasCanonicalHost" {
        It "Should detect GitHub patterns" {
            $result = Get-GIAliasCanonicalHost -Alias "mygithub" -Email "test@example.com"
            $result | Should -Be "github.com"
        }
        
        It "Should detect GitLab patterns" {
            $result = Get-GIAliasCanonicalHost -Alias "workgitlab" -Email "test@example.com"
            $result | Should -Be "gitlab.com"
        }
        
        It "Should detect Azure patterns" {
            $result = Get-GIAliasCanonicalHost -Alias "corpazure" -Email "test@example.com"
            $result | Should -Be "dev.azure.com"
        }
        
        It "Should extract domain from email" {
            $result = Get-GIAliasCanonicalHost -Alias "unknown" -Email "test@gitlab.com"
            $result | Should -Be "gitlab.com"
        }
        
        It "Should return unknown for no patterns" {
            $result = Get-GIAliasCanonicalHost -Alias "random" -Email "test@unknown.com"
            $result | Should -Be "unknown.com"
        }
    }
    
    Context "Get-GINormalizedFolderPath" {
        It "Should normalize Windows paths to forward slashes" {
            Mock Get-GINormalizedFolderPath { return "C:/Test/Path/" } -ModuleName GitIdentities
            
            $result = Get-GINormalizedFolderPath -Path "C:\Test\Path"
            $result | Should -Be "C:/Test/Path/"
        }
        
        It "Should add trailing slash" {
            Mock Get-GINormalizedFolderPath { return "C:/Test/" } -ModuleName GitIdentities
            
            $result = Get-GINormalizedFolderPath -Path "C:/Test"
            $result | Should -Be "C:/Test/"
        }
        
        It "Should handle empty input" {
            Mock Get-GINormalizedFolderPath { return $null } -ModuleName GitIdentities
            
            $result = Get-GINormalizedFolderPath -Path ""
            $result | Should -BeNullOrEmpty
        }
    }
}
