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
    # Clean up any leftover registry key from tests
    Remove-Item $script:VerbKey -Recurse -Force -ErrorAction SilentlyContinue

    if (Test-Path $env:APPDATA) {
        Remove-Item -Path $env:APPDATA -Recurse -Force -ErrorAction SilentlyContinue
    }
    $env:APPDATA = $script:OriginalAppData
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

    It 'Should not throw when called multiple times (idempotent)' {
        { Register-ContextMenu -ExePath $script:TestExe } | Should -Not -Throw
        { Register-ContextMenu -ExePath $script:TestExe } | Should -Not -Throw
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
