#Requires -Modules @{ ModuleName='Pester'; ModuleVersion='5.0.0' }
<#
.SYNOPSIS
    Source-text checks for main window resize support, pressed-state feedback,
    and popup config loading consistency.
#>

BeforeAll {
    $script:SourceText = Get-Content (Join-Path $PSScriptRoot '..\..\DailyMotivation.ps1') -Raw
}

Describe 'AG19 main window UX source checks' {
    It 'Main window should allow resizing instead of CanMinimize-only' {
        $script:SourceText | Should -Match 'x:Name="MainWin"[\s\S]*?ResizeMode="CanResize"' `
            -Because 'the main window should be user-resizable on high-DPI displays'
    }

    It 'Main window should declare a minimum width for the resizable layout' {
        $script:SourceText | Should -Match 'x:Name="MainWin"[\s\S]*?MinWidth="520"' `
            -Because 'the resizable layout still needs a floor that matches the existing compact design'
    }

    It 'PrimaryBtn template should include a pressed-state trigger' {
        $script:SourceText | Should -Match '<Style x:Key="PrimaryBtn"[\s\S]*?<Trigger Property="IsPressed" Value="True">' `
            -Because 'the primary action needs click-state feedback in addition to hover feedback'
    }

    It 'Show-PopupWindow should load popup config through Get-PopupConfig' {
        $script:SourceText | Should -Match 'function Show-PopupWindow[\s\S]*?\$config = Get-PopupConfig' `
            -Because 'popup mode should reuse the shared popup-config normalization path instead of parsing raw JSON inline'
    }
}
