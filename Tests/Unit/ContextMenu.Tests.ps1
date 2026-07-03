#Requires -Modules Pester
<#
.SYNOPSIS
    Unit tests for context menu functions in DailyMotivation.ps1.
    Covers: Register-ContextMenu, Unregister-ContextMenu.
    These tests write to HKCU (current user only, no admin required).
#>

BeforeAll {
    . (Join-Path $PSScriptRoot '..\..\DailyMotivation.ps1') -NoRun

    $script:OriginalAppData = $env:APPDATA
    $env:APPDATA = Join-Path ([System.IO.Path]::GetTempPath()) "DMBH_CM_Test_$(New-Guid)"
    Initialize-AppData

    $script:VerbKey = 'HKCU:\Software\Classes\Directory\shell\ScheduleMotivation'
    $script:TestExe = 'C:\Test\DailyMotivation.exe'
}

AfterAll {
    # AG8-021: Add cleanup verification to prevent state leakage
    try {
        # Clean up any leftover registry key from tests
        if (Test-Path $script:VerbKey) {
            Remove-Item $script:VerbKey -Recurse -Force -ErrorAction Stop
        }

        if (Test-Path $env:APPDATA) {
            Remove-Item -Path $env:APPDATA -Recurse -Force -ErrorAction Stop
        }
    }
    catch {
        Write-Warning "Cleanup failed: $_"
    }
    finally {
        $env:APPDATA = $script:OriginalAppData
        # AG8-021: Verify cleanup succeeded
        if ($IsWindows) {
            Test-Path $script:VerbKey | Should -Be $false -Because "Registry key should be deleted"
        }
    }
}

Describe 'Register-ContextMenu' {
    BeforeEach {
        Remove-Item $script:VerbKey -Recurse -Force -ErrorAction SilentlyContinue

        # AG8-006: Platform-aware mock setup for cross-platform testing
        if (-not $IsWindows) {
            # Mock registry operations for non-Windows platforms
            Mock New-Item { return [PSCustomObject]@{ PSPath = $Path } } -ParameterFilter { $Path -like 'HKCU:*' }
            Mock Set-ItemProperty { }  -ParameterFilter { $Path -like 'HKCU:*' }
            Mock Get-ItemProperty { return [PSCustomObject]@{ '(default)' = $Value } } -ParameterFilter { $Path -like 'HKCU:*' }
            Mock Test-Path { return $true } -ParameterFilter { $Path -like 'HKCU:*' }
            Mock Get-ChildItem { return @([PSCustomObject]@{ Name = 'command' }) } -ParameterFilter { $Path -like 'HKCU:*' }
        }
    }

    It 'Should create the registry verb key' {
        Register-ContextMenu -ExePath $script:TestExe
        if ($IsWindows) {
            Test-Path $script:VerbKey | Should -Be $true
        } else {
            # On non-Windows, verify mock was called
            Should -Invoke New-Item -Times 1 -ParameterFilter { $Path -like '*ScheduleMotivation*' }
        }
    }

    It 'Should set the verb display name' {
        Register-ContextMenu -ExePath $script:TestExe
        if ($IsWindows) {
            $val = (Get-ItemProperty -Path $script:VerbKey -ErrorAction SilentlyContinue).'(default)'
            $val | Should -Match "Daily Motivation"
        } else {
            # Verify Set-ItemProperty was called with the display name
            Should -Invoke Set-ItemProperty -Times 1 -ParameterFilter {
                $Name -eq '(default)' -and $Value -match 'Daily Motivation'
            }
        }
    }

    It 'Should set the command to exe /setfolder "%1"' {
        Register-ContextMenu -ExePath $script:TestExe
        if ($IsWindows) {
            $cmdKey = "$($script:VerbKey)\command"
            $cmd = (Get-ItemProperty -Path $cmdKey -ErrorAction SilentlyContinue).'(default)'
            $cmd | Should -Match ([regex]::Escape($script:TestExe))
            $cmd | Should -Match '/setfolder'
            $cmd | Should -Match '"%1"'
        } else {
            # Verify Set-ItemProperty was called with the command
            Should -Invoke Set-ItemProperty -Times 1 -ParameterFilter {
                $Value -match [regex]::Escape($script:TestExe) -and
                $Value -match '/setfolder' -and
                $Value -match '"%1"'
            }
        }
    }

    It 'Should not throw when called multiple times (idempotent)' {
        # AG8-022: Verify true idempotency - state unchanged after second call
        if ($IsWindows) {
            # Verify initial state
            Test-Path $script:VerbKey | Should -Be $false

            # First call
            Register-ContextMenu -ExePath $script:TestExe
            $cmdKey = "$($script:VerbKey)\command"
            $val1 = (Get-ItemProperty -Path $cmdKey -ErrorAction SilentlyContinue).'(default)'

            # Second call
            Register-ContextMenu -ExePath $script:TestExe
            $val2 = (Get-ItemProperty -Path $cmdKey -ErrorAction SilentlyContinue).'(default)'

            # AG8-022: Verify values are identical (no duplication, no cruft)
            $val2 | Should -BeExactly $val1
            # Verify no leftover subkeys
            $subkeys = Get-ChildItem -Path $script:VerbKey -ErrorAction SilentlyContinue
            $subkeys.Count | Should -Be 1  # Only 'command' subkey
        } else {
            # On non-Windows, verify behavior through mocks
            Register-ContextMenu -ExePath $script:TestExe
            Register-ContextMenu -ExePath $script:TestExe
            # Both calls should succeed without errors
            $true | Should -Be $true
        }
    }

    It 'Should skip registration and not write to registry when ExePath is a .ps1 file' -Skip:(-not $IsWindows) {
        # Regression test: running the script directly (not the compiled exe) sets
        # $script:ExePath to a .ps1 path. If Register-ContextMenu wrote that to the
        # registry, right-clicking a folder would produce "This app can't run on your PC".
        # Windows-only: Tests actual Registry behavior
        $ps1Path = 'C:\Test\DailyMotivation.ps1'
        Remove-Item $script:VerbKey -Recurse -Force -ErrorAction SilentlyContinue
        { Register-ContextMenu -ExePath $ps1Path } | Should -Not -Throw
        Test-Path $script:VerbKey | Should -Be $false
    }

    It 'Should skip registration and not throw when ExePath is empty' -Skip:(-not $IsWindows) {
        # Windows-only: Tests actual Registry behavior
        Remove-Item $script:VerbKey -Recurse -Force -ErrorAction SilentlyContinue
        { Register-ContextMenu -ExePath '' } | Should -Not -Throw
        Test-Path $script:VerbKey | Should -Be $false
    }
}

Describe 'Unregister-ContextMenu' {
    BeforeEach {
        # AG8-006: Platform-aware mock for Remove-Item
        if (-not $IsWindows) {
            Mock Remove-Item { } -ParameterFilter { $Path -like 'HKCU:*' }
        }
    }

    It 'Should remove the registry verb key when it exists' {
        Register-ContextMenu -ExePath $script:TestExe
        Unregister-ContextMenu
        if ($IsWindows) {
            Test-Path $script:VerbKey | Should -Be $false
        } else {
            # Verify Remove-Item was called on non-Windows
            Should -Invoke Remove-Item -Times 1 -ParameterFilter { $Path -like '*ScheduleMotivation*' }
        }
    }

    It 'Should not throw when the key does not exist' {
        Remove-Item $script:VerbKey -Recurse -Force -ErrorAction SilentlyContinue
        { Unregister-ContextMenu } | Should -Not -Throw
    }
}
