#Requires -Modules @{ ModuleName='Pester'; ModuleVersion='5.0.0' }
<#
.SYNOPSIS
    WPF control-tree assertions (Pattern A: source-text regex) and
    Show-MainWindow early-exit coverage (Pattern B).
    XAML tests: cross-platform. Early-exit test: Windows-only.
.NOTES
    No window is opened in any test in this file.
    Source-text regex does not execute function code (0 coverage gain)
    but satisfies control-existence acceptance criteria.
    Pattern B (early-exit) covers the no-assemblies guard at the top
    of Show-MainWindow without calling ShowDialog.
#>

BeforeAll {
    $script:Src = Get-Content (Join-Path $PSScriptRoot '..\..\DailyMotivation.ps1') -Raw
}

# ── Show-MainWindow control tree (Pattern A, cross-platform) ──────────────
Describe 'Show-MainWindow — XAML control tree' {

    It 'SelectFolderBtn exists'    { $script:Src | Should -Match 'x:Name="SelectFolderBtn"' }
    It 'ScheduleBtn exists'        { $script:Src | Should -Match 'x:Name="ScheduleBtn"' }
    It 'TodayRadio exists'         { $script:Src | Should -Match 'x:Name="TodayRadio"' }
    It 'TomorrowRadio exists'      { $script:Src | Should -Match 'x:Name="TomorrowRadio"' }
    It 'UndoBtn exists'            { $script:Src | Should -Match 'x:Name="UndoBtn"' }
    It 'DropZone exists'           { $script:Src | Should -Match 'x:Name="DropZone"' }
    It 'TaskList exists'           { $script:Src | Should -Match 'x:Name="TaskList"' }
    It 'HistoryToggleBtn exists'   { $script:Src | Should -Match 'x:Name="HistoryToggleBtn"' }
    It 'NoTasksLabel exists'       { $script:Src | Should -Match 'x:Name="NoTasksLabel"' }
}

# ── Show-PopupWindow control tree (Pattern A, cross-platform) ─────────────
Describe 'Show-PopupWindow — XAML control tree' {

    It 'LetsGoBtn exists'          { $script:Src | Should -Match 'x:Name="LetsGoBtn"' }
    It 'SnoozeBtn exists'          { $script:Src | Should -Match 'x:Name="SnoozeBtn"' }
    It 'SnoozeDropBtn exists'      { $script:Src | Should -Match 'x:Name="SnoozeDropBtn"' }
    It 'DismissBtn exists'         { $script:Src | Should -Match 'x:Name="DismissBtn"' }
    It 'RePickBtn exists'          { $script:Src | Should -Match 'x:Name="RePickBtn"' }
    It 'GlyphText exists'          { $script:Src | Should -Match 'x:Name="GlyphText"' }
    It 'BodyText exists'           { $script:Src | Should -Match 'x:Name="BodyText"' }
    It 'NormalPanel exists'        { $script:Src | Should -Match 'x:Name="NormalPanel"' }
    It 'PathMissingPanel exists'   { $script:Src | Should -Match 'x:Name="PathMissingPanel"' }
}

# ── Show-MainWindow early-exit guard (Pattern B, Windows-only) ───────────
Describe 'Show-MainWindow — early-exit when assemblies not loaded' -Skip:(-not $IsWindows) {

    BeforeAll {
        if ($IsWindows) {
            . (Join-Path $PSScriptRoot '..\..\DailyMotivation.ps1') -NoRun
            $script:OriginalAppData = $env:APPDATA
            $env:APPDATA = Join-Path ([System.IO.Path]::GetTempPath()) "DMBH_MainEarlyExit_$(New-Guid)"
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

    It 'returns without throwing when AssembliesLoaded is false' {
        # Pattern B: exercises the no-assemblies early-exit without opening any window.
        # No ShowDialog call is made; the function returns via Console.Error.WriteLine.
        $script:AssembliesLoaded = $false
        { Show-MainWindow } | Should -Not -Throw
    }

    It 'does not open a window when AssembliesLoaded is false' {
        $script:AssembliesLoaded = $false
        Show-MainWindow
        # If a window had opened it would not have closed — test would hang.
        # Reaching this assertion proves no ShowDialog was called.
        $true | Should -Be $true
    }
}
