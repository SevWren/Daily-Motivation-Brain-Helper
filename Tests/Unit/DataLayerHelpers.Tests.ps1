#Requires -Modules @{ ModuleName='Pester'; ModuleVersion='5.0.0' }
<#
.SYNOPSIS
    Unit tests for data-layer helpers in DailyMotivation.ps1:
    Get-HistoryData, Update-HistoryUI, Get-ScheduleTime, Update-TaskListUI.
.NOTES
    All four functions are cross-platform. WPF control parameters are stubbed
    as PSCustomObject instances — no real window is opened in any test.
#>

BeforeAll {
    . (Join-Path $PSScriptRoot '..\..\DailyMotivation.ps1') -NoRun
    $script:OriginalAppData = $env:APPDATA
    $env:APPDATA = Join-Path ([System.IO.Path]::GetTempPath()) "DMBH_DataLayer_$(New-Guid)"
    Initialize-AppData

    # Helper: append a pipe-delimited Outcome Log entry to $script:LogPath
    function script:Add-TestLogEntry {
        param([string]$Timestamp, [string]$FolderName, [string]$Outcome)
        $hash = 'A' * 64
        "[$Timestamp] | task-001 | $FolderName | HASH:$hash | $Outcome | 0" |
            Add-Content -Path $script:LogPath -Encoding UTF8
    }

    # Helper: build a minimal MotivationTask PSCustomObject for Save-TasksJson
    function script:New-TestTask {
        param([string]$TaskId, [string]$FolderName, [string]$Status,
              [string]$ScheduledTime = '2026-09-20T14:00:00+00:00')
        [PSCustomObject]@{
            task_id        = $TaskId
            task_name      = "DailyMotivation_$TaskId"
            folder_path    = "C:\Work\$FolderName"
            folder_name    = $FolderName
            status         = $Status
            scheduled_time = $ScheduledTime
            snooze_count   = 0
            description    = "Daily Motivation Brain Helper - Task $TaskId"
        }
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
# Get-HistoryData
# ============================================================
Describe 'Get-HistoryData' {

    BeforeEach {
        if (Test-Path $script:LogPath) {
            Remove-Item $script:LogPath -Force -ErrorAction SilentlyContinue
        }
    }

    It 'returns an empty array when the Outcome Log does not exist' {
        $result = @(Get-HistoryData)
        $result | Should -HaveCount 0
    }

    It 'returns an empty array when the Outcome Log contains no lines starting with [' {
        '# comment line' | Set-Content $script:LogPath -Encoding UTF8
        $result = @(Get-HistoryData)
        $result | Should -HaveCount 0
    }

    It 'returns the most recent 30 entries from a log with 50 lines' {
        1..50 | ForEach-Object {
            Add-TestLogEntry -Timestamp "2026-09-20 14:00:$('{0:D2}' -f $_).000" `
                             -FolderName "Folder$_" -Outcome 'Opened'
        }
        $result = @(Get-HistoryData)
        $result | Should -HaveCount 30
        # Should be the LAST 30 — Folder21..50
        $result[0].FolderName | Should -Be 'Folder21'
    }

    It 'parses FolderName from the third pipe-delimited field' {
        Add-TestLogEntry -Timestamp '2026-09-20 14:00:01.000' `
                         -FolderName 'Projects' -Outcome 'Opened'
        $result = @(Get-HistoryData)
        $result[0].FolderName | Should -Be 'Projects'
    }

    It 'maps Opened outcome to color #52B788' {
        Add-TestLogEntry -Timestamp '2026-09-20 14:00:01.000' `
                         -FolderName 'A' -Outcome 'Opened'
        $result = @(Get-HistoryData)
        $result[0].OutcomeColor | Should -Be '#52B788'
    }

    It 'maps Dismissed outcome to color #E07A5F' {
        Add-TestLogEntry -Timestamp '2026-09-20 14:00:01.000' `
                         -FolderName 'A' -Outcome 'Dismissed'
        $result = @(Get-HistoryData)
        $result[0].OutcomeColor | Should -Be '#E07A5F'
    }

    It 'maps Snoozed outcome to color #F4A261' {
        Add-TestLogEntry -Timestamp '2026-09-20 14:00:01.000' `
                         -FolderName 'A' -Outcome 'Snoozed'
        $result = @(Get-HistoryData)
        $result[0].OutcomeColor | Should -Be '#F4A261'
    }

    It 'maps PathMissing outcome to color #E07A5F and OutcomeDisplay to Path Missing' {
        Add-TestLogEntry -Timestamp '2026-09-20 14:00:01.000' `
                         -FolderName 'A' -Outcome 'PathMissing'
        $result = @(Get-HistoryData)
        $result[0].OutcomeColor   | Should -Be '#E07A5F'
        $result[0].OutcomeDisplay | Should -Be 'Path Missing'
    }

    It 'maps an unknown outcome to default color #8888A8' {
        Add-TestLogEntry -Timestamp '2026-09-20 14:00:01.000' `
                         -FolderName 'A' -Outcome 'Custom'
        $result = @(Get-HistoryData)
        $result[0].OutcomeColor | Should -Be '#8888A8'
    }

    It 'skips lines with fewer than 5 pipe-delimited fields' {
        'only | three | parts' | Add-Content $script:LogPath -Encoding UTF8
        '[2026-09-20 14:00:01.000] | task | Folder | HASH:AAAA | Opened | 0' |
            Add-Content $script:LogPath -Encoding UTF8
        $result = @(Get-HistoryData)
        $result | Should -HaveCount 1
    }

    It 'strips the surrounding brackets from the Timestamp field' {
        Add-TestLogEntry -Timestamp '2026-09-20 14:00:01.000' `
                         -FolderName 'A' -Outcome 'Opened'
        $result = @(Get-HistoryData)
        $result[0].Timestamp | Should -Be '2026-09-20 14:00:01.000'
        $result[0].Timestamp | Should -Not -Match '^\['
    }
}

# ============================================================
# Get-ScheduleTime
# ============================================================
Describe 'Get-ScheduleTime' {

    It 'returns today at the configured trigger hour when radio is visible and checked' {
        $cfg = Get-Config; $cfg.default_trigger_hour = 9; Save-Config -Config $cfg
        $radio  = [PSCustomObject]@{ IsVisible = $true; IsChecked = $true }
        $result = Get-ScheduleTime -TodayRadioControl $radio
        $result.Date | Should -Be (Get-Date).Date
        $result.Hour | Should -Be 9
    }

    It 'returns tomorrow at the trigger hour when radio is not visible' {
        $cfg = Get-Config; $cfg.default_trigger_hour = 14; Save-Config -Config $cfg
        $radio  = [PSCustomObject]@{ IsVisible = $false; IsChecked = $true }
        $result = Get-ScheduleTime -TodayRadioControl $radio
        $result.Date | Should -Be (Get-Date).Date.AddDays(1)
        $result.Hour | Should -Be 14
    }

    It 'returns tomorrow at the trigger hour when radio is visible but unchecked' {
        $cfg = Get-Config; $cfg.default_trigger_hour = 14; Save-Config -Config $cfg
        $radio  = [PSCustomObject]@{ IsVisible = $true; IsChecked = $false }
        $result = Get-ScheduleTime -TodayRadioControl $radio
        $result.Date | Should -Be (Get-Date).Date.AddDays(1)
    }

    It 'reads default_trigger_hour from AppConfig' {
        $cfg = Get-Config; $cfg.default_trigger_hour = 8; Save-Config -Config $cfg
        $radio  = [PSCustomObject]@{ IsVisible = $true; IsChecked = $true }
        $result = Get-ScheduleTime -TodayRadioControl $radio
        $result.Hour | Should -Be 8
    }

    It 'falls back to ConfigDefaults.default_trigger_hour when AppConfig is absent' {
        Remove-Item $script:ConfigPath -Force -ErrorAction SilentlyContinue
        $radio  = [PSCustomObject]@{ IsVisible = $false; IsChecked = $false }
        $result = Get-ScheduleTime -TodayRadioControl $radio
        $result.Hour | Should -Be $script:ConfigDefaults.default_trigger_hour
    }

    It 'returns a DateTime value (not a string)' {
        $radio  = [PSCustomObject]@{ IsVisible = $false; IsChecked = $false }
        $result = Get-ScheduleTime -TodayRadioControl $radio
        $result | Should -BeOfType [datetime]
    }
}

# ============================================================
# Update-TaskListUI
# ============================================================
Describe 'Update-TaskListUI' {

    BeforeEach {
        Save-TasksJson @()
        $script:ExePath = 'C:\Test\DailyMotivation.exe'
    }

    It 'sets NoTasksLabel Visibility to Visible when there are no tasks' {
        $taskList = [PSCustomObject]@{ ItemsSource = $null }
        $noLabel  = [PSCustomObject]@{ Visibility  = $null }
        Update-TaskListUI -TaskListControl $taskList -NoTasksLabelControl $noLabel
        $noLabel.Visibility | Should -Be 'Visible'
    }

    It 'sets NoTasksLabel Visibility to Collapsed when a PENDING task exists' {
        Save-TasksJson @(New-TestTask -TaskId 'aaa1' -FolderName 'Work' -Status 'PENDING')
        $taskList = [PSCustomObject]@{ ItemsSource = $null }
        $noLabel  = [PSCustomObject]@{ Visibility  = $null }
        Update-TaskListUI -TaskListControl $taskList -NoTasksLabelControl $noLabel
        $noLabel.Visibility | Should -Be 'Collapsed'
    }

    It 'excludes DELETED tasks from ItemsSource' {
        Save-TasksJson @(
            New-TestTask -TaskId 'del1' -FolderName 'Gone'    -Status 'DELETED'
            New-TestTask -TaskId 'pnd1' -FolderName 'Present' -Status 'PENDING'
        )
        $taskList = [PSCustomObject]@{ ItemsSource = $null }
        $noLabel  = [PSCustomObject]@{ Visibility  = $null }
        Update-TaskListUI -TaskListControl $taskList -NoTasksLabelControl $noLabel
        $taskList.ItemsSource | Should -HaveCount 1
        $taskList.ItemsSource[0].task_id | Should -Be 'pnd1'
    }

    It 'sorts PENDING tasks ascending by scheduled_time' {
        Save-TasksJson @(
            New-TestTask -TaskId 'late'  -FolderName 'Late'  -Status 'PENDING' `
                         -ScheduledTime '2026-09-20T16:00:00+00:00'
            New-TestTask -TaskId 'early' -FolderName 'Early' -Status 'PENDING' `
                         -ScheduledTime '2026-09-20T09:00:00+00:00'
        )
        $taskList = [PSCustomObject]@{ ItemsSource = $null }
        $noLabel  = [PSCustomObject]@{ Visibility  = $null }
        Update-TaskListUI -TaskListControl $taskList -NoTasksLabelControl $noLabel
        $taskList.ItemsSource[0].task_id | Should -Be 'early'
        $taskList.ItemsSource[1].task_id | Should -Be 'late'
    }

    It 'title-cases folder_name and replaces hyphens and underscores with spaces' {
        Save-TasksJson @(New-TestTask -TaskId 'aaa1' -FolderName 'my-project_work' -Status 'PENDING')
        $taskList = [PSCustomObject]@{ ItemsSource = $null }
        $noLabel  = [PSCustomObject]@{ Visibility  = $null }
        Update-TaskListUI -TaskListControl $taskList -NoTasksLabelControl $noLabel
        $taskList.ItemsSource[0].folder_name | Should -Be 'My Project Work'
    }

    It 'uses empty string for folder_name when the field is absent' {
        $task = [PSCustomObject]@{
            task_id = 'aaa1'; task_name = 'DailyMotivation_aaa1'
            status = 'PENDING'; scheduled_time = '2026-09-20T14:00:00+00:00'
            folder_path = 'C:\Work'; snooze_count = 0; description = 'x'
        }
        Save-TasksJson @($task)
        $taskList = [PSCustomObject]@{ ItemsSource = $null }
        $noLabel  = [PSCustomObject]@{ Visibility  = $null }
        Update-TaskListUI -TaskListControl $taskList -NoTasksLabelControl $noLabel
        $taskList.ItemsSource[0].folder_name | Should -Be ''
    }

    It 'sets ItemsSource on the control (not $null) even when all tasks are DELETED' {
        Save-TasksJson @(New-TestTask -TaskId 'del1' -FolderName 'Gone' -Status 'DELETED')
        $taskList = [PSCustomObject]@{ ItemsSource = $null }
        $noLabel  = [PSCustomObject]@{ Visibility  = $null }
        Update-TaskListUI -TaskListControl $taskList -NoTasksLabelControl $noLabel
        $taskList.ItemsSource | Should -Not -BeNullOrEmpty -Because 'ItemsSource must be set even when empty'
    }
}

# ============================================================
# Update-HistoryUI
# ============================================================
Describe 'Update-HistoryUI' {

    BeforeEach {
        if (Test-Path $script:LogPath) {
            Remove-Item $script:LogPath -Force -ErrorAction SilentlyContinue
        }
    }

    It 'sets ItemsSource to an empty array (not null) when the Outcome Log is absent' {
        $historyList = [PSCustomObject]@{ ItemsSource = $null }
        Update-HistoryUI -HistoryListControl $historyList
        # Avoid pipeline unrolling of @() — check directly instead
        ($null -ne $historyList.ItemsSource) | Should -Be $true
        @($historyList.ItemsSource).Count   | Should -Be 0
    }

    It 'sorts entries newest-first by default' {
        Add-TestLogEntry -Timestamp '2026-09-20 09:00:00.000' -FolderName 'A' -Outcome 'Opened'
        Add-TestLogEntry -Timestamp '2026-09-20 11:00:00.000' -FolderName 'B' -Outcome 'Opened'
        Add-TestLogEntry -Timestamp '2026-09-20 10:00:00.000' -FolderName 'C' -Outcome 'Opened'
        $historyList = [PSCustomObject]@{ ItemsSource = $null }
        Update-HistoryUI -HistoryListControl $historyList
        $items = @($historyList.ItemsSource)
        $items[0].FolderName | Should -Be 'B'   # 11:00 — newest
        $items[2].FolderName | Should -Be 'A'   # 09:00 — oldest
    }

    It 'sorts entries oldest-first when SortOrder is oldest' {
        Add-TestLogEntry -Timestamp '2026-09-20 09:00:00.000' -FolderName 'A' -Outcome 'Opened'
        Add-TestLogEntry -Timestamp '2026-09-20 11:00:00.000' -FolderName 'B' -Outcome 'Opened'
        $historyList = [PSCustomObject]@{ ItemsSource = $null }
        Update-HistoryUI -HistoryListControl $historyList -SortOrder 'oldest'
        $items = @($historyList.ItemsSource)
        $items[0].FolderName | Should -Be 'A'   # 09:00 — oldest first
        $items[1].FolderName | Should -Be 'B'
    }

    It 'passes FolderName data through from Get-HistoryData unchanged' {
        Add-TestLogEntry -Timestamp '2026-09-20 14:00:00.000' `
                         -FolderName 'MyKnownFolder' -Outcome 'Snoozed'
        $historyList = [PSCustomObject]@{ ItemsSource = $null }
        Update-HistoryUI -HistoryListControl $historyList
        @($historyList.ItemsSource)[0].FolderName | Should -Be 'MyKnownFolder'
    }
}
