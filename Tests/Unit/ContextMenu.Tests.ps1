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
    }

    It 'Should create the registry verb key' -Skip:(-not $IsWindows -and $PSVersionTable.PSVersion.Major -ge 6) {
        Register-ContextMenu -ExePath $script:TestExe
        Test-Path $script:VerbKey | Should -Be $true
    }

    It 'Should set the verb display name' -Skip:(-not $IsWindows -and $PSVersionTable.PSVersion.Major -ge 6) {
        Register-ContextMenu -ExePath $script:TestExe
        $val = (Get-ItemProperty -Path $script:VerbKey -ErrorAction SilentlyContinue).'(default)'
        $val | Should -Match "Daily Motivation"
    }

    It 'Should set the command to exe /setfolder "%1"' -Skip:(-not $IsWindows -and $PSVersionTable.PSVersion.Major -ge 6) {
        Register-ContextMenu -ExePath $script:TestExe
        $cmdKey = "$($script:VerbKey)\command"
        $cmd = (Get-ItemProperty -Path $cmdKey -ErrorAction SilentlyContinue).'(default)'
        $cmd | Should -Match ([regex]::Escape($script:TestExe))
        $cmd | Should -Match '/setfolder'
        $cmd | Should -Match '"%1"'
    }

    It 'Should not throw when called multiple times (idempotent)' -Skip:(-not $IsWindows -and $PSVersionTable.PSVersion.Major -ge 6) {
        # AG8-022: Verify true idempotency - state unchanged after second call
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
    }

    It 'Should skip registration and not write to registry when ExePath is a .ps1 file' {
        # Regression test: running the script directly (not the compiled exe) sets
        # $script:ExePath to a .ps1 path. If Register-ContextMenu wrote that to the
        # registry, right-clicking a folder would produce "This app can't run on your PC".
        $ps1Path = 'C:\Test\DailyMotivation.ps1'
        Remove-Item $script:VerbKey -Recurse -Force -ErrorAction SilentlyContinue
        { Register-ContextMenu -ExePath $ps1Path } | Should -Not -Throw
        Test-Path $script:VerbKey | Should -Be $false
    }

    It 'Should skip registration and not throw when ExePath is empty' {
        Remove-Item $script:VerbKey -Recurse -Force -ErrorAction SilentlyContinue
        { Register-ContextMenu -ExePath '' } | Should -Not -Throw
        Test-Path $script:VerbKey | Should -Be $false
    }
}

Describe 'Unregister-ContextMenu' {
    It 'Should remove the registry verb key when it exists' -Skip:(-not $IsWindows -and $PSVersionTable.PSVersion.Major -ge 6) {
        Register-ContextMenu -ExePath $script:TestExe
        Unregister-ContextMenu
        Test-Path $script:VerbKey | Should -Be $false
    }

    It 'Should not throw when the key does not exist' {
        Remove-Item $script:VerbKey -Recurse -Force -ErrorAction SilentlyContinue
        { Unregister-ContextMenu } | Should -Not -Throw
    }
}
