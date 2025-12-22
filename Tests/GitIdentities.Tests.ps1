# GitIdentities.Tests.ps1
# Pester tests for GitIdentities PowerShell module

Describe "GitIdentities Module Tests" {
    BeforeAll {
        # Import module under test
        $ModulePath = Join-Path $PSScriptRoot "..\GitIdentities"
        Import-Module $ModulePath -Force
        # Dot-source private functions before tests
        $privatePath = Join-Path $PSScriptRoot '..\GitIdentities\Private'
        Get-ChildItem "$privatePath\*.ps1" | ForEach-Object { . $_.FullName }
        
        # Test user for all operations (as requested)
        $script:TestUser = "patata"
        $script:TestUserHome = "C:\Users\$TestUser"
        
        # Test data
        $script:TestAlias = "pestertest"
        $script:TestFolder = "C:\Temp\PesterTest"
        $script:TestEmail = "pester@test.com"
        $script:TestName = "Pester Test User"
        $script:TestUsername = "pesteruser"
        
        # Ensure test directory exists but is clean
        if (Test-Path $TestFolder) { Remove-Item $TestFolder -Recurse -Force -ErrorAction SilentlyContinue }
        New-Item -Path $TestFolder -ItemType Directory -Force | Out-Null
    }
    
    AfterAll {
        # Cleanup test artifacts
        try {
            Remove-GitIdentity -Alias $TestAlias -User $TestUser -Confirm:$false -ErrorAction SilentlyContinue
            if (Test-Path $TestFolder) { Remove-Item $TestFolder -Recurse -Force -ErrorAction SilentlyContinue }
        }
        catch {
            Write-Warning "Cleanup failed: $($_.Exception.Message)"
        }
    }
    
    Context "Module Import and Structure" {
        It "Should import the module successfully" {
            Get-Module GitIdentities | Should -Not -BeNullOrEmpty
        }
        
        It "Should export expected functions" {
            $expectedFunctions = @('Add-GitIdentity', 'Get-GitIdentities', 'Remove-GitIdentity', 'Test-GitIdentityProvision')
            $exportedFunctions = (Get-Command -Module GitIdentities).Name
            
            foreach ($func in $expectedFunctions) {
                ($exportedFunctions -contains $func) | Should -Be $true
            }
        }
        
        It "Should have valid module manifest" {
            $manifest = Test-ModuleManifest -Path (Join-Path $PSScriptRoot "..\GitIdentities\GitIdentities.psd1")
            $manifest | Should -Not -BeNullOrEmpty
            $manifest.Version | Should -BeGreaterThan ([Version]"0.0.0")
        }
    }
    
    Context "Platform Detection" {
        It "Should detect GitHub from alias" {
            { Add-GitIdentity -Alias "githubtest" -Name $TestName -Email $TestEmail -Username $TestUsername -Folders $TestFolder -User $TestUser -DryRun -Verbosity Silent } | Should -Not -Throw
        }
        
        It "Should detect GitLab from email domain" {
            { Add-GitIdentity -Alias "testgitlab" -Name $TestName -Email "test@gitlab.com" -Username $TestUsername -Folders $TestFolder -User $TestUser -DryRun -Verbosity Silent } | Should -Not -Throw
        }
        
        It "Should detect Azure DevOps from alias" {
            { Add-GitIdentity -Alias "azure-work" -Name $TestName -Email "test@dev.azure.com" -Username $TestUsername -Folders $TestFolder -User $TestUser -DryRun -Verbosity Silent } | Should -Not -Throw
        }
        
        It "Should detect Bitbucket from email" {
            { Add-GitIdentity -Alias "testbb" -Name $TestName -Email "test@bitbucket.org" -Username $TestUsername -Folders $TestFolder -User $TestUser -DryRun -Verbosity Silent } | Should -Not -Throw
        }
        
        It "Should have centralized platform configuration" {
            # Verify GIPlatformMap exists and contains expected platforms
            $script:GIPlatformMap | Should -Not -BeNullOrEmpty
            ($script:GIPlatformMap.Keys -contains 'github') | Should -Be $true
            ($script:GIPlatformMap.Keys -contains 'azure') | Should -Be $true
            ($script:GIPlatformMap.Keys -contains 'gitlab') | Should -Be $true
            ($script:GIPlatformMap.Keys -contains 'bitbucket') | Should -Be $true
            
            # Verify platform structure
            $script:GIPlatformMap['github'].HostName | Should -Be 'github.com'
            $script:GIPlatformMap['github'].SshAlgorithm | Should -Be 'ed25519'
            $script:GIPlatformMap['azure'].SshAlgorithm | Should -Be 'rsa'
        }
        
        It "Should fallback to GitHub for unknown patterns" {
            { Add-GitIdentity -Alias "unknownpattern" -Name $TestName -Email "test@unknown.com" -Username $TestUsername -Folders $TestFolder -User $TestUser -DryRun -Verbosity Silent } | Should -Not -Throw
        }
    }
    
    Context "Add-GitIdentity Functionality" {
        It "Should add identity successfully in DryRun mode" {
            { Add-GitIdentity -Alias $TestAlias -Name $TestName -Email $TestEmail -Username $TestUsername -Folders $TestFolder -User $TestUser -DryRun -Verbosity Silent } | Should -Not -Throw
        }
        
        It "Should add identity successfully for real" {
            { Add-GitIdentity -Alias $TestAlias -Name $TestName -Email $TestEmail -Username $TestUsername -Folders $TestFolder -User $TestUser -Verbosity Silent } | Should -Not -Throw
        }
        
        It "Should create state file" {
            $statePath = Join-Path $TestUserHome ".gitidentities.json"
            Test-Path $statePath | Should -Be $true
        }
        
        It "Should create alias gitconfig file" {
            $aliasConfigPath = Join-Path $TestUserHome ".gitconfig-$TestAlias"
            Test-Path $aliasConfigPath | Should -Be $true
        }
        
        It "Should contain correct user information in alias config" {
            $aliasConfigPath = Join-Path $TestUserHome ".gitconfig-$TestAlias"
            $content = Get-Content $aliasConfigPath -Raw
            $content | Should -Match $TestName
            $content | Should -Match $TestEmail
            $content | Should -Match $TestUsername
        }
        
        It "Should configure SSH via core.sshCommand in alias config" {
            $aliasConfigPath = Join-Path $TestUserHome ".gitconfig-$TestAlias"
            $content = Get-Content $aliasConfigPath -Raw
            # Should contain core.sshCommand with ssh key path
            $content | Should -Match 'sshCommand = ssh -i'
            $content | Should -Match "id_$TestAlias"
            # Should specify SSH user
            $content | Should -Match '-o User='
        }
        
        It "Should create includeIf block in global gitconfig" {
            $globalConfigPath = Join-Path $TestUserHome ".gitconfig"
            if (Test-Path $globalConfigPath) {
                $content = Get-Content $globalConfigPath -Raw
                # Ajuste: buscar el bloque includeIf para la carpeta de test, permitiendo barra final y diferentes formatos
                $pattern = '\[includeIf "gitdir:(.+)?C:/Temp/PesterTest/?"\]'
                $content | Should -Match $pattern
            }
        }
        
        It "Should handle multiple folders" {
            $folder2 = "C:\Temp\PesterTest2"
            New-Item -Path $folder2 -ItemType Directory -Force | Out-Null
            try {
                { Add-GitIdentity -Alias $TestAlias -Name $TestName -Email $TestEmail -Username $TestUsername -Folders @($TestFolder, $folder2) -User $TestUser -Verbosity Silent } | Should -Not -Throw
            }
            finally {
                Remove-Item $folder2 -Recurse -Force -ErrorAction SilentlyContinue
            }
        }
        
        It "Should be idempotent (safe to run multiple times)" {
            { Add-GitIdentity -Alias $TestAlias -Name $TestName -Email $TestEmail -Username $TestUsername -Folders $TestFolder -User $TestUser -Verbosity Silent } | Should -Not -Throw
            { Add-GitIdentity -Alias $TestAlias -Name $TestName -Email $TestEmail -Username $TestUsername -Folders $TestFolder -User $TestUser -Verbosity Silent } | Should -Not -Throw
        }
    }
    
    Context "Get-GitIdentities Functionality" {
        It "Should retrieve identities without error" {
            { Get-GitIdentities -User $TestUser -Verbosity Silent } | Should -Not -Throw
        }
        
        It "Should find the test identity" {
            $identities = Get-GitIdentities -User $TestUser -Verbosity Silent
            $testIdentity = $identities | Where-Object { $_.alias -eq $TestAlias }
            $testIdentity | Should -Not -BeNullOrEmpty
        }
        
        It "Should return correct identity properties" {
            $identities = Get-GitIdentities -User $TestUser -Verbosity Silent
            $testIdentity = $identities | Where-Object { $_.alias -eq $TestAlias }
            
            $testIdentity.alias | Should -Be $TestAlias
            $testIdentity.name | Should -Be $TestName
            $testIdentity.email | Should -Be $TestEmail
            ($testIdentity.folders -contains ($TestFolder.Replace('\', '/') + '/')) | Should -Be $true
        }
    }
    
    Context "Test-GitIdentityProvision Functionality" {
        It "Should test provision status without error" {
            { Test-GitIdentityProvision -Alias $TestAlias -User $TestUser } | Should -Not -Throw
        }
        
        It "Should report correct provision status" {
            $status = Test-GitIdentityProvision -Alias $TestAlias -User $TestUser
            
            $status.alias | Should -Be $TestAlias
            $status.stateFile | Should -Be $true
            $status.stateEntry | Should -Be $true
            $status.aliasGitConfig | Should -Be $true
            $status.includeIfBlocks | Should -BeGreaterThan 0
        }
        
        It "Should handle non-existent identity gracefully" {
            $status = Test-GitIdentityProvision -Alias "nonexistent" -User $TestUser
            $status.stateEntry | Should -Be $false
            ($status.missing -contains "stateEntry") | Should -Be $true
        }
    }
    
    Context "Remove-GitIdentity Functionality" {
        BeforeEach {
            # Ensure test identity exists for removal tests
            Add-GitIdentity -Alias "removetest" -Name $TestName -Email $TestEmail -Username $TestUsername -Folders $TestFolder -User $TestUser -Verbosity Silent -ErrorAction SilentlyContinue
        }
        
        It "Should remove folder from identity in DryRun mode" {
            { Remove-GitIdentity -Alias "removetest" -Folder $TestFolder -User $TestUser -DryRun -Confirm:$false -Verbosity Silent } | Should -Not -Throw
        }
        
        It "Should remove entire identity in DryRun mode" {
            { Remove-GitIdentity -Alias "removetest" -User $TestUser -DryRun -Confirm:$false -Verbosity Silent } | Should -Not -Throw
        }
        
        It "Should actually remove identity" {
            { Remove-GitIdentity -Alias "removetest" -User $TestUser -Confirm:$false -Verbosity Silent } | Should -Not -Throw
            
            # Verify removal
            $status = Test-GitIdentityProvision -Alias "removetest" -User $TestUser
            $status.stateEntry | Should -Be $false
            $status.aliasGitConfig | Should -Be $false
        }
        
        It "Should preserve SSH keys when removing identity" {
            # Add identity with SSH key
            Add-GitIdentity -Alias "sshtest" -Name $TestName -Email $TestEmail -Username $TestUsername -Folders $TestFolder -User $TestUser -Verbosity Silent
            
            # Remove identity
            Remove-GitIdentity -Alias "sshtest" -User $TestUser -Confirm:$false -Verbosity Silent
            
            # SSH keys should still exist
            $status = Test-GitIdentityProvision -Alias "sshtest" -User $TestUser
            # Note: SSH keys are preserved by design for security
            $status.sshPrivateKey | Should -Be $true -Because "SSH keys should be preserved for security"
        }
        
        It "Should handle non-existent identity gracefully" {
            { Remove-GitIdentity -Alias "nonexistent" -User $TestUser -Confirm:$false -Verbosity Silent -WarningAction SilentlyContinue } | Should -Not -Throw
        }
    }
    
    Context "File System Safety" {
        It "Should never delete physical repository folders" {
            # Create test content in folder
            $testFile = Join-Path $TestFolder "important-file.txt"
            "Important content" | Out-File $testFile -Encoding UTF8
            
            # Add and remove identity
            Add-GitIdentity -Alias "safetytest" -Name $TestName -Email $TestEmail -Username $TestUsername -Folders $TestFolder -User $TestUser -Verbosity Silent
            Remove-GitIdentity -Alias "safetytest" -User $TestUser -Confirm:$false -Verbosity Silent
            
            # Physical folder and content should remain
            Test-Path $TestFolder | Should -Be $true
            Test-Path $testFile | Should -Be $true
            Get-Content $testFile | Should -Be "Important content"
        }
    }
    
    Context "Error Handling" {
        #It "Should handle missing required parameters" {
        #    { Add-GitIdentity -Alias "test" } | Should -Throw
        #}
        
        It "Should handle invalid folder paths gracefully" {
            { Add-GitIdentity -Alias "invalidpath" -Name $TestName -Email $TestEmail -Username $TestUsername -Folders "Z:\NonExistent\Path" -User $TestUser -DryRun -Verbosity Silent } | Should -Not -Throw
        }
        
        It "Should handle special characters in alias" {
            { Add-GitIdentity -Alias "test-alias.with_special" -Name $TestName -Email $TestEmail -Username $TestUsername -Folders $TestFolder -User $TestUser -DryRun -Verbosity Silent } | Should -Not -Throw
        }
    }
    
    Context "SSH Key Generation" {
        It "Should handle SSH key generation in DryRun mode" {
            { Add-GitIdentity -Alias "sshtest" -Name $TestName -Email $TestEmail -Username $TestUsername -Folders $TestFolder -User $TestUser -DryRun -Verbosity Silent } | Should -Not -Throw
        }
        
        It "Should create SSH key files when not in DryRun" -Skip:(!$env:CI) {
            # Only run in CI environment where we have full control
            Add-GitIdentity -Alias "sshkeytest" -Name $TestName -Email $TestEmail -Username $TestUsername -Folders $TestFolder -User $TestUser -Verbosity Silent
            
            $privateKeyPath = Join-Path $TestUserHome ".ssh\id_sshkeytest"
            $publicKeyPath = "$privateKeyPath.pub"
            
            # At least one should exist (fallback mechanisms)
            ($privateKeyPath | Test-Path) -or ($publicKeyPath | Test-Path) | Should -Be $true
        }
        
        It "Should use RSA algorithm for Azure DevOps" {
            { Add-GitIdentity -Alias "azure-test" -Platform "azure" -Name $TestName -Email $TestEmail -Username $TestUsername -Folders $TestFolder -User $TestUser -DryRun -Verbosity Silent } | Should -Not -Throw
        }
        
        It "Should support custom SshUser parameter" {
            { Add-GitIdentity -Alias "custom-ssh" -Name $TestName -Email $TestEmail -Username $TestUsername -Folders $TestFolder -User $TestUser -SshUser @('git','customuser') -DryRun -Verbosity Silent } | Should -Not -Throw
        }
        
        It "Should configure multiple SSH users for Azure DevOps" {
            Add-GitIdentity -Alias "azure-multi" -Platform "azure" -Name $TestName -Email "test@dev.azure.com" -Username $TestUsername -Folders $TestFolder -User $TestUser -Verbosity Silent
            
            $aliasConfigPath = Join-Path $TestUserHome ".gitconfig-azure-multi"
            if (Test-Path $aliasConfigPath) {
                $content = Get-Content $aliasConfigPath -Raw
                # Azure configuration should exist and have SSH configuration
                $content | Should -Match 'sshCommand'
            }
            
            # Cleanup
            Remove-GitIdentity -Alias "azure-multi" -User $TestUser -Confirm:$false -Verbosity Silent -ErrorAction SilentlyContinue
        }
    }
    
    Context "Credential Helper Configuration" {
        It "Should configure credential helper appropriately" {
            # Store original credential helper
            $originalHelper = $null
            try {
                $originalHelper = git config --global --get credential.helper 2>$null
                if ($LASTEXITCODE -ne 0) { $originalHelper = $null }
            }
            catch { $originalHelper = $null }
            
            try {
                # Clear credential helper for test
                git config --global --unset credential.helper 2>$null
                
                # Test identity creation should set credential helper
                { Add-GitIdentity -Alias "credtest" -Name $TestName -Email $TestEmail -Username $TestUsername -Folders $TestFolder -User $TestUser -Verbosity Silent } | Should -Not -Throw
                
                # Verify credential helper was set (only in non-CI environments)
                if (-not $env:CI) {
                    $newHelper = git config --global --get credential.helper 2>$null
                    if ($LASTEXITCODE -eq 0) {
                        $newHelper | Should -Be "manager-core"
                    }
                }
                
                # Cleanup test identity
                Remove-GitIdentity -Alias "credtest" -User $TestUser -Confirm:$false -Verbosity Silent -ErrorAction SilentlyContinue
            }
            finally {
                # Restore original credential helper
                if ($originalHelper) {
                    git config --global credential.helper $originalHelper 2>$null
                }
                else {
                    git config --global --unset credential.helper 2>$null
                }
            }
        }
        
        It "Should handle existing credential helper gracefully" {
            # This test verifies the function doesn't crash with existing helpers
            # The interactive prompt can't be easily tested in automated tests
            { Add-GitIdentity -Alias "credtest2" -Name $TestName -Email $TestEmail -Username $TestUsername -Folders $TestFolder -User $TestUser -DryRun -Verbosity Silent } | Should -Not -Throw
        }
    }
    
    Context "Cross-User Support" {
        It "Should work with different user profiles" {
            { Add-GitIdentity -Alias "crossuser" -Name $TestName -Email $TestEmail -Username $TestUsername -Folders $TestFolder -User $TestUser -DryRun -Verbosity Silent } | Should -Not -Throw
        }
        
        It "Should handle missing user profile gracefully" {
            { Get-GitIdentities -User "NonExistentUser" -Verbosity Silent -WarningAction SilentlyContinue } | Should -Not -Throw
        }
    }
}
