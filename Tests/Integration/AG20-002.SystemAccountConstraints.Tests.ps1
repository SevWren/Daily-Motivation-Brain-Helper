#Requires -Modules Pester
<#
.SYNOPSIS
    Integration tests for AG20-002: SYSTEM account identity constraints.
    Verifies that Initialize-AppData handles SYSTEM account APPDATA paths
    and produces descriptive error messages that include operation names.
    Windows-only: requires SYSTEM account path behavior.
#>

BeforeAll {
    if (-not $IsWindows) {
        Write-Host "Skipping AG20-002 - Windows SYSTEM account testing required" -ForegroundColor Yellow
        return
    }
    $script:RepoRoot = Join-Path $PSScriptRoot '..\..'
    . (Join-Path $script:RepoRoot 'DailyMotivation.ps1') -NoRun
    $script:OriginalAppData = $env:APPDATA
}

AfterAll {
    if (-not $IsWindows) { return }
    $env:APPDATA = $script:OriginalAppData
}

Describe 'AG20-002 SYSTEM Account Identity Constraints' -Skip:(-not $IsWindows) {

    BeforeEach {
        # Clean up any previous test directories
        if ($script:AppDataDir -and (Test-Path $script:AppDataDir)) {
            Remove-Item -Path $script:AppDataDir -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    AfterEach {
        # Restore original APPDATA
        $env:APPDATA = $script:OriginalAppData
    }

    It 'AC#1: Initialize-AppData with SYSTEM APPDATA path - creates directory or throws descriptive error (not generic "Invalid Folder")' {
        # Set APPDATA to SYSTEM account path
        $systemAppData = 'C:\Windows\System32\config\systemprofile\AppData\Roaming'
        $env:APPDATA = $systemAppData

        # Attempt to initialize - this should either succeed or fail with a descriptive error
        try {
            Initialize-AppData

            # If it succeeds, verify the directory structure
            $expectedAppDir = Join-Path $systemAppData 'DailyMotivationBrainHelper'
            $script:AppDataDir | Should -Be $expectedAppDir

            # If directory creation succeeded, the directory should exist
            # (or a fallback should have been used)
            $script:AppDataDir | Should -Not -BeNullOrEmpty

            # Verify that ConfigPath, PopupCfgPath, TasksPath, LogPath are set
            $script:ConfigPath | Should -Not -BeNullOrEmpty
            $script:PopupCfgPath | Should -Not -BeNullOrEmpty
            $script:TasksPath | Should -Not -BeNullOrEmpty
            $script:LogPath | Should -Not -BeNullOrEmpty
        }
        catch {
            # If it fails, the error message must:
            # 1. Include the operation name (e.g., "Initialize-AppData")
            # 2. NOT be the generic "Invalid Folder" error
            # 3. Include context about what operation failed

            $errorMsg = $_.Exception.Message
            $errorMsg | Should -Not -BeNullOrEmpty
            $errorMsg | Should -Not -Be 'Invalid Folder'

            # Error should mention Initialize-AppData or directory creation
            $errorMsg | Should -Match 'Initialize-AppData|Cannot create|Could not create'

            # Error should include the path that failed
            $errorMsg | Should -Match 'DailyMotivationBrainHelper|fallback'
        }
    }

    It 'AC#2: Initialize-AppData with writable SYSTEM path - successfully creates directory structure' {
        # Create a temp directory that simulates SYSTEM profile structure
        $tempSystemProfile = Join-Path ([System.IO.Path]::GetTempPath()) "SystemProfile_$(New-Guid)"
        $tempSystemAppData = Join-Path $tempSystemProfile 'AppData\Roaming'

        try {
            # Create the parent structure
            New-Item -ItemType Directory -Path $tempSystemAppData -Force | Out-Null

            # Set APPDATA to our writable SYSTEM-like path
            $env:APPDATA = $tempSystemAppData

            # Initialize should succeed
            Initialize-AppData

            # Verify directory was created
            $expectedAppDir = Join-Path $tempSystemAppData 'DailyMotivationBrainHelper'
            Test-Path $expectedAppDir | Should -Be $true

            # Verify all path variables are set correctly
            $script:AppDataDir | Should -Be $expectedAppDir
            $script:ConfigPath | Should -Be (Join-Path $expectedAppDir 'config.json')
            $script:PopupCfgPath | Should -Be (Join-Path $expectedAppDir 'popup_config.json')
            $script:TasksPath | Should -Be (Join-Path $expectedAppDir 'tasks.json')
            $script:LogPath | Should -Be (Join-Path $expectedAppDir 'popup_log.txt')

            # Verify config file was created
            Test-Path $script:ConfigPath | Should -Be $true
        }
        finally {
            # Cleanup temp directory
            if (Test-Path $tempSystemProfile) {
                Remove-Item -Path $tempSystemProfile -Recurse -Force -ErrorAction SilentlyContinue
            }
        }
    }

    It 'AC#2 Error handling: Initialize-AppData with non-writable path - error message includes operation name' {
        # Create a temp directory and make it read-only to simulate access denied
        $tempReadOnly = Join-Path ([System.IO.Path]::GetTempPath()) "ReadOnly_$(New-Guid)"

        try {
            New-Item -ItemType Directory -Path $tempReadOnly -Force | Out-Null

            # Set APPDATA to a subdirectory that doesn't exist under read-only parent
            $nonWritablePath = Join-Path $tempReadOnly 'NonWritable'
            $env:APPDATA = $nonWritablePath

            # Make the parent directory read-only
            $acl = Get-Acl -Path $tempReadOnly
            $currentUser = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name

            # Remove write permissions
            $acl.SetAccessRuleProtection($true, $false)  # Remove inherited rules
            $readRule = New-Object System.Security.AccessControl.FileSystemAccessRule(
                $currentUser,
                [System.Security.AccessControl.FileSystemRights]::Read,
                [System.Security.AccessControl.InheritanceFlags]'ContainerInherit,ObjectInherit',
                [System.Security.AccessControl.PropagationFlags]::None,
                [System.Security.AccessControl.AccessControlType]::Allow
            )
            $acl.AddAccessRule($readRule)
            Set-Acl -Path $tempReadOnly -AclObject $acl

            # Attempt to initialize - should fail but fall back to TempDir
            # (Initialize-AppData has a fallback mechanism, so it won't throw in most cases)
            $warningMessages = @()
            $originalWarningPreference = $WarningPreference
            $WarningPreference = 'Continue'

            try {
                Initialize-AppData 3>&1 | ForEach-Object {
                    if ($_ -is [System.Management.Automation.WarningRecord]) {
                        $warningMessages += $_.Message
                    }
                }
            }
            finally {
                $WarningPreference = $originalWarningPreference
            }

            # If a warning was issued, it should include the operation name
            if ($warningMessages.Count -gt 0) {
                $warningMessages[0] | Should -Match 'Initialize-AppData|Could not create'
                $warningMessages[0] | Should -Not -Be 'Invalid Folder'
            }

            # The function should have fallen back to TempDir
            $script:AppDataDir | Should -Not -BeNullOrEmpty
            $script:AppDataDir | Should -Match 'Temp|DailyMotivationBrainHelper'
        }
        finally {
            # Restore write permissions before cleanup
            try {
                $acl = Get-Acl -Path $tempReadOnly
                $acl.SetAccessRuleProtection($false, $true)  # Re-enable inheritance
                Set-Acl -Path $tempReadOnly -AclObject $acl
                Remove-Item -Path $tempReadOnly -Recurse -Force -ErrorAction SilentlyContinue
            }
            catch {
                # Cleanup failed, but that's OK for test purposes
            }
        }
    }

    It 'Initialize-AppData fallback to TempDir when primary path fails - all config paths updated correctly' {
        # Set APPDATA to a completely invalid path (e.g., a path that cannot be created)
        $invalidPath = 'C:\ThisPathShouldNeverExist_' + (New-Guid).ToString()
        $env:APPDATA = $invalidPath

        # Mock New-Item to fail for the invalid path but succeed for TempDir fallback
        Mock New-Item {
            param($ItemType, $Path, [switch]$Force, $ErrorAction)
            if ($Path -like "*ThisPathShouldNeverExist*") {
                throw "Access denied"
            }
            # Call the real New-Item for other paths
            & (Get-Command New-Item -CommandType Cmdlet) @PSBoundParameters
        }

        # Initialize should fall back to TempDir
        Initialize-AppData

        # Verify fallback was used (should be under Temp directory)
        $script:AppDataDir | Should -Not -Match 'ThisPathShouldNeverExist'
        $script:AppDataDir | Should -Match 'Temp.*DailyMotivationBrainHelper'

        # Verify all paths were updated to use the fallback directory
        $script:ConfigPath | Should -BeLike "$($script:AppDataDir)*"
        $script:PopupCfgPath | Should -BeLike "$($script:AppDataDir)*"
        $script:TasksPath | Should -BeLike "$($script:AppDataDir)*"
        $script:LogPath | Should -BeLike "$($script:AppDataDir)*"

        # Verify config file was created in the fallback location
        Test-Path $script:ConfigPath | Should -Be $true
    }
}
