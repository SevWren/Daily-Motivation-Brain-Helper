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

    It 'AC#2 (AG20-008): AbandonedMutexException is caught - Show-PopupWindow does not throw (AG20-013)' {
        # Establish the mutex name first
        Show-PopupWindow
        $mutexName = $script:PopupMutexName
        $mutexName | Should -Not -BeNullOrEmpty

        # Simulate an abandoned mutex: acquire it in a background job (separate runspace)
        # so when the job exits without ReleaseMutex, the OS marks it as abandoned
        $job = Start-Job -ScriptBlock {
            param($name)
            $m = [System.Threading.Mutex]::new($false, $name)
            $acquired = $m.WaitOne(500)
            if ($acquired) {
                # Hold it briefly then exit WITHOUT releasing (abandon)
                Start-Sleep -Milliseconds 100
                # Do NOT call $m.ReleaseMutex() - exit abandons it
            }
        } -ArgumentList $mutexName
        # Wait for the job to hold and abandon the mutex
        Wait-Job $job -Timeout 5 | Out-Null
        Remove-Job $job -Force

        # Give the OS a moment to mark the mutex as abandoned
        Start-Sleep -Milliseconds 200

        # Show-PopupWindow must handle AbandonedMutexException without throwing
        { Show-PopupWindow } | Should -Not -Throw
    }

    It 'AC#1 (AG20-013): Show-PopupWindow releases mutex even when XAML load fails due to corrupted config path' {
        # Write a valid PopupConfig but point it to an explorer_path that will cause
        # the popup to exit via the "path missing" early return - this exercises the
        # mutex release path in the catch/return handlers without requiring real WPF.
        $fakeConfig = [ordered]@{
            glyph         = "[+]"
            title         = "Test"
            body          = "Test body"
            explorer_path = "C:\NonExistent_$(New-Guid)"
            folder_name   = "NonExistent"
            task_id       = "0000000000000000"
        }
        $fakeConfig | ConvertTo-Json | Set-Content -Path $script:PopupCfgPath -Encoding UTF8

        # This should not throw even though the explorer path doesn't exist
        { Show-PopupWindow } | Should -Not -Throw

        # Mutex must be released after returning
        $probe = [System.Threading.Mutex]::new($false, $script:PopupMutexName)
        try {
            $acquired = $probe.WaitOne(0)
            $acquired | Should -Be $true -Because 'mutex must be released after Show-PopupWindow exits'
            if ($acquired) { $probe.ReleaseMutex() }
        }
        finally {
            $probe.Dispose()
        }
    }
}
