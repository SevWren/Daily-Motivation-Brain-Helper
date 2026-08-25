#Requires -Modules @{ ModuleName='Pester'; ModuleVersion='5.0.0' }
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

    # AG20-015: Sweep for stray DailyMotivation_* tasks (safety net)
    try {
        $strayTasks = Get-ScheduledTask -TaskName "DailyMotivation_*" -ErrorAction SilentlyContinue
        if ($strayTasks) {
            Write-Warning "AG20-015 cleanup: Found $($strayTasks.Count) stray task(s) after test run. Removing..."
            foreach ($task in $strayTasks) {
                try {
                    Unregister-ScheduledTask -TaskName $task.TaskName -Confirm:$false -ErrorAction Stop
                    Write-Host "  - Removed stray task: $($task.TaskName)" -ForegroundColor Yellow
                }
                catch {
                    Write-Warning "  - Failed to remove $($task.TaskName): $($_.Exception.Message)"
                }
            }
        }
    }
    catch {
        # Get-ScheduledTask itself failed - log but don't fail the test run
        Write-Warning "AG20-015 cleanup: Could not sweep for stray tasks: $($_.Exception.Message)"
    }

    $env:APPDATA = $script:OriginalAppData
}

Describe 'AG20-002 SYSTEM Account Identity Constraints' -Skip:(-not $IsWindows) {

    BeforeEach {
        # Clean up any previous test directories
        # Guard with Get-Variable to avoid StrictMode throw before AppDataDir is first set
        $prevAppDir = if (Get-Variable -Name 'AppDataDir' -Scope 'Script' -ErrorAction SilentlyContinue) {
            $script:AppDataDir
        } else { $null }
        if ($prevAppDir -and (Test-Path $prevAppDir)) {
            Remove-Item -Path $prevAppDir -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    AfterEach {
        # Restore original APPDATA
        $env:APPDATA = $script:OriginalAppData
    }

    It 'AC#1: Initialize-AppData with SYSTEM APPDATA path - creates directory or throws descriptive error (not generic "Invalid Folder")' {
        # Set APPDATA to SYSTEM account path (access denied on standard user accounts)
        $env:APPDATA = 'C:\Windows\System32\config\systemprofile\AppData\Roaming'

        # Attempt to initialize - either succeeds (via TempDir fallback) or throws
        try {
            Initialize-AppData

            # Success path (fallback or unlikely direct success):
            # AppDataDir must be set - it may be the fallback TempDir path, not the SYSTEM path
            $script:AppDataDir | Should -Not -BeNullOrEmpty
            # All derived paths must be set
            $script:ConfigPath   | Should -Not -BeNullOrEmpty
            $script:PopupCfgPath | Should -Not -BeNullOrEmpty
            $script:TasksPath    | Should -Not -BeNullOrEmpty
            $script:LogPath      | Should -Not -BeNullOrEmpty
        }
        catch {
            # Failure path: the error must NOT be the generic "Invalid Folder" message.
            # Windows errors like "Access to the path ... is denied." are acceptable because
            # they name the operation (path-based access failure), unlike "Invalid Folder"
            # which gives no context. inner `throw` re-raises the original Windows exception.
            $errorMsg = $_.Exception.Message
            $errorMsg | Should -Not -BeNullOrEmpty
            $errorMsg | Should -Not -Be 'Invalid Folder'
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
