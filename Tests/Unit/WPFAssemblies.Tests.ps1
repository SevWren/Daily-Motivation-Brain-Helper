#Requires -Modules @{ ModuleName='Pester'; ModuleVersion='5.0.0' }
<#
.SYNOPSIS
    Tests for Initialize-WindowsAssemblies — loads WPF and WinForms
    assemblies required by Show-MainWindow and Show-PopupWindow.
    Windows-only: assemblies do not exist on Linux.
#>

BeforeAll {
    if ($IsWindows) {
        . (Join-Path $PSScriptRoot '..\..\DailyMotivation.ps1') -NoRun
        $script:OriginalAppData = $env:APPDATA
        $env:APPDATA = Join-Path ([System.IO.Path]::GetTempPath()) "DMBH_WPFAssemblies_$(New-Guid)"
        Initialize-AppData
    }
}

AfterAll {
    if ($IsWindows) {
        if (Test-Path $env:APPDATA) {
            Remove-Item -Path $env:APPDATA -Recurse -Force -ErrorAction SilentlyContinue
        }
        $env:APPDATA = $script:OriginalAppData
    }
}

Describe 'Initialize-WindowsAssemblies' -Skip:(-not $IsWindows) {

    BeforeEach {
        # Force re-evaluation on each test
        $script:AssembliesLoaded = $false
        $script:WpfLoaded        = $false
        $script:FormsLoaded      = $false
    }

    It 'sets WpfLoaded to true after loading WPF assemblies' {
        Initialize-WindowsAssemblies
        $script:WpfLoaded | Should -Be $true
    }

    It 'sets FormsLoaded to true after loading WinForms assemblies' {
        Initialize-WindowsAssemblies
        $script:FormsLoaded | Should -Be $true
    }

    It 'sets AssembliesLoaded to true after first call' {
        Initialize-WindowsAssemblies
        $script:AssembliesLoaded | Should -Be $true
    }

    It 'is idempotent — calling twice does not throw and WpfLoaded stays true' {
        Initialize-WindowsAssemblies
        { Initialize-WindowsAssemblies } | Should -Not -Throw
        $script:WpfLoaded | Should -Be $true
    }

    It 'does not throw when called a third time' {
        Initialize-WindowsAssemblies
        Initialize-WindowsAssemblies
        { Initialize-WindowsAssemblies } | Should -Not -Throw
    }
}
