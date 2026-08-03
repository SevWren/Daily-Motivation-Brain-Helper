#Requires -Modules Pester
<#
.SYNOPSIS
    Unit tests for concurrent multi-task reconciliation in Sync-TaskStatuses.
    AG20-022: SyncTaskStatuses.Tests.ps1 only covered single-task reconciliation.
    This file seeds tasks.json with 3 PENDING tasks simultaneously and verifies
    a single Sync-TaskStatuses call reconciles all of them without data loss or
    one correction overwriting another.
.NOTES
    Windows-only tests: Uses mocked Task Scheduler cmdlets (Windows-only cmdlets).
#>

BeforeAll {
    if (-not $IsWindows) {
        Write-Host "Skipping AG20-022.ConcurrentTaskSync.Tests.ps1 - Windows Task Scheduler required" -ForegroundColor Yellow
        return
    }

    . (Join-Path $PSScriptRoot '..\..\DailyMotivation.ps1') -NoRun

    $script:OriginalAppData = $env:APPDATA
    $env:APPDATA = Join-Path ([System.IO.Path]::GetTempPath()) "DMBH_Sync_Test_$(New-Guid)"
    Initialize-AppData

    $script:ExePath = "C:\Test\DailyMotivation.exe"

    $script:SyncMockedTasks = @{}

    Mock Register-ScheduledTask {
        param($TaskName, $Action, $Trigger, $Settings, $Principal, $Description, $Force, $ErrorAction)
        $script:SyncMockedTasks[$TaskName] = [PSCustomObject]@{ TaskName = $TaskName }
        return $null
    }
    Mock Unregister-ScheduledTask {
        param($TaskName, $Confirm)
        if ($script:SyncMockedTasks.ContainsKey($TaskName)) { $script:SyncMockedTasks.Remove($TaskName) }
    }
}

AfterAll {
    if (Test-Path $env:APPDATA) { Remove-Item -Path $env:APPDATA -Recurse -Force -ErrorAction SilentlyContinue }
    $env:APPDATA = $script:OriginalAppData
}

Describe 'Sync-TaskStatuses - concurrent multi-task reconciliation' -Skip:(-not $IsWindows) {

    BeforeEach {
        '[]' | Set-Content (Join-Path $env:APPDATA 'DailyMotivationBrainHelper\tasks.json') -Encoding UTF8
    }

    Context 'When tasks.json has 3 PENDING tasks and OS scheduler is missing task 2' {

        BeforeAll {
            if (-not $IsWindows) { return }

            # task 1: present in OS scheduler
            # task 2: absent from OS scheduler (should become DELETED)
            # task 3: present in OS scheduler
            Mock Get-ScheduledTask {
                param($TaskName)
                if ($TaskName -eq 'DailyMotivation_*') {
                    return @(
                        [PSCustomObject]@{ TaskName = 'DailyMotivation_sync-task-001' },
                        [PSCustomObject]@{ TaskName = 'DailyMotivation_sync-task-003' }
                    )
                }
                if ($TaskName -eq 'DailyMotivation_sync-task-001') {
                    return [PSCustomObject]@{ TaskName = 'DailyMotivation_sync-task-001' }
                }
                if ($TaskName -eq 'DailyMotivation_sync-task-002') {
                    throw [System.Exception]::new("The system cannot find the file specified.")
                }
                if ($TaskName -eq 'DailyMotivation_sync-task-003') {
                    return [PSCustomObject]@{ TaskName = 'DailyMotivation_sync-task-003' }
                }
                throw [System.Exception]::new("Task not found: $TaskName")
            }
        }

        BeforeEach {
            if (-not $IsWindows) { return }

            $futureTime = (Get-Date).AddHours(2).ToString('yyyy-MM-ddTHH:mm:ss')
            $createdAt  = (Get-Date -Format 'o')

            $task1 = [PSCustomObject]@{
                task_id        = 'sync-task-001'
                task_name      = 'DailyMotivation_sync-task-001'
                folder_path    = 'C:\TestFolder1'
                folder_name    = 'TestFolder1'
                scheduled_time = $futureTime
                created_at     = $createdAt
                status         = 'PENDING'
                snooze_count   = 0
            }
            $task2 = [PSCustomObject]@{
                task_id        = 'sync-task-002'
                task_name      = 'DailyMotivation_sync-task-002'
                folder_path    = 'C:\TestFolder2'
                folder_name    = 'TestFolder2'
                scheduled_time = $futureTime
                created_at     = $createdAt
                status         = 'PENDING'
                snooze_count   = 0
            }
            $task3 = [PSCustomObject]@{
                task_id        = 'sync-task-003'
                task_name      = 'DailyMotivation_sync-task-003'
                folder_path    = 'C:\TestFolder3'
                folder_name    = 'TestFolder3'
                scheduled_time = $futureTime
                created_at     = $createdAt
                status         = 'PENDING'
                snooze_count   = 0
            }

            Save-TasksJson @($task1, $task2, $task3)
        }

        It 'Should not throw during reconciliation of 3 simultaneous tasks' {
            { Sync-TaskStatuses } | Should -Not -Throw
        }

        It 'Should preserve all 3 entries in tasks.json (no data loss)' {
            Sync-TaskStatuses
            $tasks = @(Get-TasksJson)
            $tasks.Count | Should -Be 3
        }

        It 'Should keep task 1 as PENDING (present in OS scheduler)' {
            Sync-TaskStatuses
            $tasks  = @(Get-TasksJson)
            $task1  = $tasks | Where-Object { $_.task_id -eq 'sync-task-001' }
            $task1  | Should -Not -BeNullOrEmpty
            $task1.status | Should -Be 'PENDING'
        }

        It 'Should mark task 2 as DELETED (absent from OS scheduler)' {
            Sync-TaskStatuses
            $tasks  = @(Get-TasksJson)
            $task2  = $tasks | Where-Object { $_.task_id -eq 'sync-task-002' }
            $task2  | Should -Not -BeNullOrEmpty
            $task2.status | Should -Be 'DELETED'
        }

        It 'Should keep task 3 as PENDING (present in OS scheduler)' {
            Sync-TaskStatuses
            $tasks  = @(Get-TasksJson)
            $task3  = $tasks | Where-Object { $_.task_id -eq 'sync-task-003' }
            $task3  | Should -Not -BeNullOrEmpty
            $task3.status | Should -Be 'PENDING'
        }
    }
}
