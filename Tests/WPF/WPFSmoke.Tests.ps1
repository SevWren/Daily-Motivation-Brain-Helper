#Requires -Modules @{ ModuleName='Pester'; ModuleVersion='5.0.0' }
<#
.SYNOPSIS
    WPF smoke tests for Initialize-WindowsAssemblies, Show-MainWindow,
    and Show-PopupWindow.
.NOTES
    Must run inside an STA runspace — Invoke-STAPester.ps1 guarantees this.
    All Describe blocks are -Tag 'WPF' and -Skip:(-not $IsWindows).
    A DispatcherTimer fires 200ms after each window opens, records control
    assertions, then closes the window so ShowDialog() unblocks.
#>

BeforeAll {
    . (Join-Path $PSScriptRoot '..\..\DailyMotivation.ps1') -NoRun
    $script:OriginalAppData = $env:APPDATA
    $env:APPDATA = Join-Path ([System.IO.Path]::GetTempPath()) "DMBH_WPF_$(New-Guid)"
    Initialize-AppData
    $script:ExePath = [System.Diagnostics.Process]::GetCurrentProcess().MainModule.FileName

    # Helper: open a window via a DispatcherTimer that records assertions then closes.
    # $openAction   - scriptblock that opens the window (blocks on ShowDialog)
    # $assertAction - scriptblock that runs inside the timer tick, receives $win
    # Returns a hashtable of assertion results.
    function script:Invoke-WPFWindowTest {
        param(
            [scriptblock]$OpenAction,
            [scriptblock]$AssertAction
        )
        $results  = @{ Exception = $null; Assertions = @{} }
        $timer    = [System.Windows.Threading.DispatcherTimer]::new()
        $timer.Interval = [TimeSpan]::FromMilliseconds(200)
        $timer.Add_Tick({
            $timer.Stop()
            try {
                $win = [System.Windows.Application]::Current.Windows |
                    Select-Object -First 1
                if ($win) {
                    & $AssertAction $win $results.Assertions
                    $win.Close()
                }
            }
            catch { $results.Exception = $_ }
        })
        $timer.Start()
        try { & $OpenAction }
        catch { $results.Exception = $_ }
        return $results
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

# ============================================================
# Initialize-WindowsAssemblies
# ============================================================
Describe 'Initialize-WindowsAssemblies' -Tag 'WPF' -Skip:(-not $IsWindows) {

    It 'loads WPF assemblies and sets WpfLoaded to true' {
        $script:AssembliesLoaded = $false
        $script:WpfLoaded        = $false
        Initialize-WindowsAssemblies
        $script:WpfLoaded | Should -Be $true
    }

    It 'loads WinForms assemblies and sets FormsLoaded to true' {
        $script:AssembliesLoaded = $false
        $script:FormsLoaded      = $false
        Initialize-WindowsAssemblies
        $script:FormsLoaded | Should -Be $true
    }

    It 'sets AssembliesLoaded to true after first call' {
        $script:AssembliesLoaded = $false
        Initialize-WindowsAssemblies
        $script:AssembliesLoaded | Should -Be $true
    }

    It 'is idempotent — calling twice does not throw and WpfLoaded stays true' {
        Initialize-WindowsAssemblies
        { Initialize-WindowsAssemblies } | Should -Not -Throw
        $script:WpfLoaded | Should -Be $true
    }
}

# ============================================================
# Show-MainWindow smoke tests
# ============================================================
Describe 'Show-MainWindow — control tree' -Tag 'WPF' -Skip:(-not $IsWindows) {

    BeforeAll {
        Initialize-WindowsAssemblies
    }

    It 'opens without throwing' {
        $r = Invoke-WPFWindowTest `
            -OpenAction   { Show-MainWindow } `
            -AssertAction { param($win, $a) }
        $r.Exception | Should -BeNull
    }

    It 'SelectFolderBtn control exists' {
        $r = Invoke-WPFWindowTest `
            -OpenAction   { Show-MainWindow } `
            -AssertAction { param($win, $a) $a['SelectFolderBtn'] = $null -ne $win.FindName('SelectFolderBtn') }
        $r.Assertions['SelectFolderBtn'] | Should -Be $true
    }

    It 'ScheduleBtn control exists' {
        $r = Invoke-WPFWindowTest `
            -OpenAction   { Show-MainWindow } `
            -AssertAction { param($win, $a) $a['ScheduleBtn'] = $null -ne $win.FindName('ScheduleBtn') }
        $r.Assertions['ScheduleBtn'] | Should -Be $true
    }

    It 'TodayRadio control exists' {
        $r = Invoke-WPFWindowTest `
            -OpenAction   { Show-MainWindow } `
            -AssertAction { param($win, $a) $a['TodayRadio'] = $null -ne $win.FindName('TodayRadio') }
        $r.Assertions['TodayRadio'] | Should -Be $true
    }

    It 'TomorrowRadio control exists' {
        $r = Invoke-WPFWindowTest `
            -OpenAction   { Show-MainWindow } `
            -AssertAction { param($win, $a) $a['TomorrowRadio'] = $null -ne $win.FindName('TomorrowRadio') }
        $r.Assertions['TomorrowRadio'] | Should -Be $true
    }

    It 'UndoBtn control exists' {
        $r = Invoke-WPFWindowTest `
            -OpenAction   { Show-MainWindow } `
            -AssertAction { param($win, $a) $a['UndoBtn'] = $null -ne $win.FindName('UndoBtn') }
        $r.Assertions['UndoBtn'] | Should -Be $true
    }

    It 'window closes cleanly via DispatcherTimer (no exception from timer callback)' {
        $r = Invoke-WPFWindowTest `
            -OpenAction   { Show-MainWindow } `
            -AssertAction { param($win, $a) $a['Closed'] = $true }
        $r.Exception | Should -BeNull
        $r.Assertions['Closed'] | Should -Be $true
    }
}

# ============================================================
# Show-PopupWindow smoke tests
# ============================================================
Describe 'Show-PopupWindow — control tree' -Tag 'WPF' -Skip:(-not $IsWindows) {

    BeforeAll {
        Initialize-WindowsAssemblies
        # Write a minimal PopupConfig so Show-PopupWindow does not early-exit
        Set-PopupConfig -Glyph '[+]' -Title 'Test Popup' -Body 'Test body' `
                        -ExplorerPath 'C:\Temp' -TaskId 'wpf-smoke-test-001'
    }

    It 'opens without throwing' {
        $r = Invoke-WPFWindowTest `
            -OpenAction   { Show-PopupWindow } `
            -AssertAction { param($win, $a) }
        $r.Exception | Should -BeNull
    }

    It 'LetsGoBtn control exists' {
        $r = Invoke-WPFWindowTest `
            -OpenAction   { Show-PopupWindow } `
            -AssertAction { param($win, $a) $a['LetsGoBtn'] = $null -ne $win.FindName('LetsGoBtn') }
        $r.Assertions['LetsGoBtn'] | Should -Be $true
    }

    It 'SnoozeBtn control exists' {
        $r = Invoke-WPFWindowTest `
            -OpenAction   { Show-PopupWindow } `
            -AssertAction { param($win, $a) $a['SnoozeBtn'] = $null -ne $win.FindName('SnoozeBtn') }
        $r.Assertions['SnoozeBtn'] | Should -Be $true
    }

    It 'DismissBtn control exists' {
        $r = Invoke-WPFWindowTest `
            -OpenAction   { Show-PopupWindow } `
            -AssertAction { param($win, $a) $a['DismissBtn'] = $null -ne $win.FindName('DismissBtn') }
        $r.Assertions['DismissBtn'] | Should -Be $true
    }

    It 'popup Mutex is released after Show-PopupWindow returns' {
        # Run a full popup open/close cycle first
        Invoke-WPFWindowTest `
            -OpenAction   { Show-PopupWindow } `
            -AssertAction { param($win, $a) } | Out-Null

        # If the Mutex was released, we can acquire it within a timeout
        $mutexName = $script:PopupMutexName
        $mutexName | Should -Not -BeNullOrEmpty -Because 'PopupMutexName must be set after Show-PopupWindow'
        $m = $null
        try {
            $m = [System.Threading.Mutex]::new($false, $mutexName)
            $acquired = $m.WaitOne(500)
            $acquired | Should -Be $true -Because 'Mutex must be released after Show-PopupWindow returns'
            if ($acquired) { $m.ReleaseMutex() }
        }
        finally {
            if ($m) { $m.Dispose() }
        }
    }
}
