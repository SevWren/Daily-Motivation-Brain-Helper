#Requires -Modules @{ ModuleName='Pester'; ModuleVersion='5.0.0' }
<#
.SYNOPSIS
    #201 mop-up: targeted coverage for previously uncovered branches.

    Covers:
    - New-MotivationTask: all 5 specific Register-ScheduledTask error arms,
      the null-return silent-failure path, and default (unrecognised) error.
    - New-MotivationTask: TaskId collision retry exhausted (10 retries all collide).
    - Invoke-FolderScheduling: Set-PopupConfig write failure triggers OS task rollback.
    - Set-SnoozeDuration: button content update (< 60 min and >= 60 min) and config persist.
    - Stop-UndoTimer: banner collapse and graceful no-op when no timer is active.

.NOTES
    Windows-only Describes are guarded with -Skip:(-not $IsWindows).
    Cross-platform Describes (HeadlessPlatform) run on both runners.
    No window is opened. No STA runspace is created.
    Pester rules: never mock New-ScheduledTask* helpers (WRONG 8).
                  never put ErrorAction in a splatted hashtable (WRONG 7).
                  never use <token> in test names without a -ForEach key (WRONG 10).
#>

BeforeAll {
    . (Join-Path $PSScriptRoot '..\..\DailyMotivation.ps1') -NoRun

    $script:OriginalAppData = $env:APPDATA
    $env:APPDATA = Join-Path ([System.IO.Path]::GetTempPath()) "DMBH_MopUp_$(New-Guid)"
    Initialize-AppData

    # Snapshot path for cross-platform cleanup
    $script:MopUpAppDataDir = $env:APPDATA
}

AfterAll {
    if (Test-Path $script:MopUpAppDataDir) {
        Remove-Item -Path $script:MopUpAppDataDir -Recurse -Force -ErrorAction SilentlyContinue
    }
    $env:APPDATA = $script:OriginalAppData
}

# ── Register-ScheduledTask specific error arms ────────────────────────────
# Each test throws the exact exception message text that triggers one regex arm
# in the switch -Regex block inside New-MotivationTask's catch clause.
# Per WRONG 8: only Register-ScheduledTask, Get-ScheduledTask, and
# Unregister-ScheduledTask are mocked — never the New-Scheduled* helpers.
Describe 'New-MotivationTask - Register-ScheduledTask specific error branches' -Skip:(-not $IsWindows) {

    BeforeAll {
        $script:ExePath    = 'C:\Test\DailyMotivation.exe'
        $script:Platform   = $null
        $script:TestFolder = 'C:\Projects\TestFolder'

        Mock Get-ScheduledTask    { return $null }
        Mock Unregister-ScheduledTask { }
    }

    It 'returns access-denied error with correct label when Register throws the canonical access-denied message' {
        Mock Register-ScheduledTask { throw [System.Exception]::new('Access is denied.') }
        $r = New-MotivationTask -FolderPath $script:TestFolder -TriggerTime (Get-Date).AddHours(2)
        $r.Success | Should -Be $false
        $r.Error   | Should -Match 'access denied'
    }

    It 'returns elevation-required error when Register throws the elevation message' {
        Mock Register-ScheduledTask { throw [System.Exception]::new('The requested operation requires elevation.') }
        $r = New-MotivationTask -FolderPath $script:TestFolder -TriggerTime (Get-Date).AddHours(2)
        $r.Success | Should -Be $false
        $r.Error   | Should -Match 'elevation required'
    }

    It 'returns S4U-unavailable error when Register throws the logon-session message' {
        Mock Register-ScheduledTask { throw [System.Exception]::new('A specified logon session does not exist.') }
        $r = New-MotivationTask -FolderPath $script:TestFolder -TriggerTime (Get-Date).AddHours(2)
        $r.Success | Should -Be $false
        $r.Error   | Should -Match 'S4U'
    }

    It 'returns scheduler-unavailable error when Register throws the service-unavailable message' {
        Mock Register-ScheduledTask { throw [System.Exception]::new('The Task Scheduler service is not available.') }
        $r = New-MotivationTask -FolderPath $script:TestFolder -TriggerTime (Get-Date).AddHours(2)
        $r.Success | Should -Be $false
        $r.Error   | Should -Match 'scheduler service unavailable'
    }

    It 'returns exe-not-found error when Register throws the cannot-find-file message' {
        Mock Register-ScheduledTask { throw [System.Exception]::new('The system cannot find the file specified.') }
        $r = New-MotivationTask -FolderPath $script:TestFolder -TriggerTime (Get-Date).AddHours(2)
        $r.Success | Should -Be $false
        $r.Error   | Should -Match 'exe path not found'
    }

    It 'returns task-name-collision error when Register throws the already-exists message' {
        Mock Register-ScheduledTask { throw [System.Exception]::new('A task with the name already exists.') }
        $r = New-MotivationTask -FolderPath $script:TestFolder -TriggerTime (Get-Date).AddHours(2)
        $r.Success | Should -Be $false
        $r.Error   | Should -Match 'Task name collision'
    }

    It 'returns default OS-registration error when Register throws an unrecognised message' {
        Mock Register-ScheduledTask { throw [System.Exception]::new('Something unexpected happened.') }
        $r = New-MotivationTask -FolderPath $script:TestFolder -TriggerTime (Get-Date).AddHours(2)
        $r.Success | Should -Be $false
        $r.Error   | Should -Match 'OS task registration failed'
    }

    It 'returns silent-failure error when Register-ScheduledTask returns null' {
        Mock Register-ScheduledTask { return $null }
        $r = New-MotivationTask -FolderPath $script:TestFolder -TriggerTime (Get-Date).AddHours(2)
        $r.Success | Should -Be $false
        $r.Error   | Should -Match 'silent failure'
    }
}

# ── TaskId collision retry exhausted ─────────────────────────────────────
Describe 'New-MotivationTask - TaskId collision retry exhausted after 10 attempts' -Skip:(-not $IsWindows) {

    BeforeAll {
        $script:ExePath    = 'C:\Test\DailyMotivation.exe'
        $script:Platform   = $null
        $script:TestFolder = 'C:\Projects\TestFolder'
        # Every Get-ScheduledTask call returns a non-null object — simulates collision on every attempt
        Mock Get-ScheduledTask    { return [PSCustomObject]@{ TaskName = 'DailyMotivation_existing' } }
        Mock Start-Sleep          { }   # skip real backoff delay
    }

    AfterAll {
        # Restore no-collision default for subsequent Describes
        Mock Get-ScheduledTask { return $null }
    }

    It 'returns Success=false when all 10 retry attempts find a name collision' {
        $r = New-MotivationTask -FolderPath $script:TestFolder -TriggerTime (Get-Date).AddHours(2)
        $r.Success | Should -Be $false
        $r.Error   | Should -Match 'collision retry exhausted'
    }

    It 'calls Start-Sleep at least once during the backoff loop' {
        New-MotivationTask -FolderPath $script:TestFolder -TriggerTime (Get-Date).AddHours(2) | Out-Null
        Should -Invoke Start-Sleep -Times 1 -Scope It -Because 'backoff loop must sleep between retry attempts'
    }
}

# ── Invoke-FolderScheduling: Set-PopupConfig write failure ────────────────
# Cross-platform: uses HeadlessPlatform so no Windows scheduler cmdlets needed.
Describe 'Invoke-FolderScheduling - Set-PopupConfig write failure triggers OS task rollback' {

    BeforeAll {
        $script:Platform = [HeadlessPlatform]::new()

        Mock Set-PopupConfig      { throw [System.IO.IOException]::new('Disk full') }
        Mock Remove-MotivationTask { return $true }
    }

    AfterAll {
        $script:Platform = $null
    }

    It 'returns Success=false when Set-PopupConfig throws during scheduling' {
        $r = Invoke-FolderScheduling -FolderPath '/tmp/test-folder' -TriggerTime (Get-Date).AddHours(2)
        $r.Success | Should -Be $false
    }

    It 'calls Remove-MotivationTask to roll back the OS task when Set-PopupConfig throws' {
        Invoke-FolderScheduling -FolderPath '/tmp/test-folder' -TriggerTime (Get-Date).AddHours(2) | Out-Null
        Should -Invoke Remove-MotivationTask -Times 1 -Scope It
    }

    It 'error message identifies the popup config write failure' {
        $r = Invoke-FolderScheduling -FolderPath '/tmp/test-folder' -TriggerTime (Get-Date).AddHours(2)
        $r.Error | Should -Match 'popup config write failed'
    }
}

# ── Set-SnoozeDuration with mock button control ───────────────────────────
# Cross-platform: passes a PSCustomObject as the button control.
# No WPF assembly needed — the function assigns .Content on an [object] param.
Describe 'Set-SnoozeDuration - button content and config persistence' {

    BeforeAll {
        # Minimal mock WPF button — only the .Content property is accessed
        $script:MockSnoozeBtn = [PSCustomObject]@{ Content = '' }
    }

    It 'sets button content to Xm format when minutes are less than 60' {
        Set-SnoozeDuration -Minutes 15 -SnoozeBtnControl $script:MockSnoozeBtn
        $script:MockSnoozeBtn.Content | Should -Be 'Snooze 15m'
    }

    It 'sets button content to 1h format when minutes are 60 or more' {
        Set-SnoozeDuration -Minutes 60 -SnoozeBtnControl $script:MockSnoozeBtn
        $script:MockSnoozeBtn.Content | Should -Be 'Snooze 1h'
    }

    It 'persists the chosen duration to config so it survives popup restart' {
        Set-SnoozeDuration -Minutes 30 -SnoozeBtnControl $script:MockSnoozeBtn
        $cfg = Get-Config
        $cfg.snooze_duration_minutes | Should -Be 30
    }
}

# ── Stop-UndoTimer with mock banner control ───────────────────────────────
# Cross-platform: passes a PSCustomObject as the banner control.
# No WPF assembly needed — the function only sets .Visibility on an [object] param.
Describe 'Stop-UndoTimer - banner collapse' {

    BeforeAll {
        $script:MockBanner = [PSCustomObject]@{ Visibility = 'Visible' }
    }

    It 'sets banner Visibility to Collapsed' {
        $script:undoTimer = $null   # prevent StrictMode RuntimeException on unset variable
        Stop-UndoTimer -UndoBannerControl $script:MockBanner
        $script:MockBanner.Visibility | Should -Be 'Collapsed'
    }

    It 'does not throw when no undo timer is active' {
        $script:undoTimer = $null
        { Stop-UndoTimer -UndoBannerControl $script:MockBanner } | Should -Not -Throw
    }
}
