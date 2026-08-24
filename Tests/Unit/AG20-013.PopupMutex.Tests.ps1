#Requires -Modules @{ ModuleName='Pester'; ModuleVersion='5.0.0' }
<#
.SYNOPSIS
    Tests for AG20-013: Show-PopupWindow mutex release in early-exit and
    graceful-shutdown paths.
.NOTES
    Windows-only: uses Global\ named mutex which requires Windows kernel object
    namespace support. Skip on Linux.
#>

BeforeAll {
    if (-not $IsWindows) {
        Write-Host "Skipping AG20-013.PopupMutex.Tests.ps1 - Windows named mutex required" -ForegroundColor Yellow
        return
    }

    $script:ProjectRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
    . (Join-Path $script:ProjectRoot 'DailyMotivation.ps1') -NoRun

    $script:OriginalAppData = $env:APPDATA
    $env:APPDATA = Join-Path ([System.IO.Path]::GetTempPath()) "DMBH_Mutex_Test_$(New-Guid)"
    Initialize-AppData
}

AfterAll {
    if (-not $IsWindows) { return }
    if (Test-Path $env:APPDATA) {
        Remove-Item -Path $env:APPDATA -Recurse -Force -ErrorAction SilentlyContinue
    }
    $env:APPDATA = $script:OriginalAppData
}

Describe 'Show-PopupWindow mutex lifecycle (AG20-013)' -Skip:(-not $IsWindows) {

    It 'Should release the popup mutex after returning due to no explorer_path in config' {
        # Show-PopupWindow returns early when popup_config.json has no explorer_path.
        # Verify the mutex is not still held after the function returns.
        Show-PopupWindow

        $mutexName = $script:PopupMutexName
        $mutexName | Should -Not -BeNullOrEmpty -Because 'PopupMutexName must be set during Show-PopupWindow'

        # If the mutex was released, we can acquire it here
        $probe = [System.Threading.Mutex]::new($false, $mutexName)
        try {
            $acquired = $probe.WaitOne(0)
            $acquired | Should -Be $true -Because 'mutex must be released when Show-PopupWindow exits early'
            if ($acquired) { $probe.ReleaseMutex() }
        }
        finally {
            $probe.Dispose()
        }
    }

    It 'Should return without throwing when the popup mutex is already held' {
        # Establish the mutex name by running once first (early-exit via no config)
        Show-PopupWindow
        $mutexName = $script:PopupMutexName
        $mutexName | Should -Not -BeNullOrEmpty

        # Now hold the mutex externally to simulate another instance
        $holder = [System.Threading.Mutex]::new($false, $mutexName)
        $holderAcquired = $holder.WaitOne(0)
        $holderAcquired | Should -Be $true -Because 'test setup must acquire the mutex before calling Show-PopupWindow'

        try {
            # Show-PopupWindow should return immediately and NOT throw
            { Show-PopupWindow } | Should -Not -Throw
        }
        finally {
            $holder.ReleaseMutex()
            $holder.Dispose()
        }
    }

    It 'Should set PopupMutexName to a string containing the current username' {
        Show-PopupWindow
        # Assign to variable first: [regex]::Escape() is a static method call that
        # must be in expression mode; passing it bare after -Match causes PowerShell
        # to parse it as a bareword string, not a method invocation.
        $pattern = [regex]::Escape($env:USERNAME)
        $script:PopupMutexName | Should -Match $pattern
    }

    It 'Should set PopupMutexName to include the process session ID' {
        Show-PopupWindow
        $sessionId = [System.Diagnostics.Process]::GetCurrentProcess().SessionId
        $pattern   = [regex]::Escape("_$sessionId")
        $script:PopupMutexName | Should -Match $pattern
    }

    It 'Should release the mutex even when popup_config.json is missing entirely' {
        # Confirm the release path works when the config file is absent
        $configPath = $script:PopupCfgPath
        if (Test-Path $configPath) { Remove-Item $configPath -Force }

        Show-PopupWindow

        $probe = [System.Threading.Mutex]::new($false, $script:PopupMutexName)
        try {
            $acquired = $probe.WaitOne(0)
            $acquired | Should -Be $true -Because 'mutex must be released when config is missing'
            if ($acquired) { $probe.ReleaseMutex() }
        }
        finally {
            $probe.Dispose()
        }
    }
}
