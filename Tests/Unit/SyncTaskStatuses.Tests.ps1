#Requires -Modules Pester
<#
.SYNOPSIS
    Unit tests for Sync-TaskStatuses in DailyMotivation.ps1.
    AG8-019: Sync-TaskStatuses had zero test coverage; this file provides coverage for
    the critical reconciliation paths including orphan recovery and stale-task cleanup.
.NOTES
    Windows-only tests: Uses mocked Task Scheduler cmdlets (Windows-only cmdlets).
#>

BeforeAll {
    # Skip all tests if not on Windows (Task Scheduler cmdlets don't exist on Linux)
    if (-not $IsWindows) {
        Write-Host "Skipping SyncTaskStatuses.Tests.ps1 - Windows Task Scheduler required" -ForegroundColor Yellow
        return
    }

    . (Join-Path $PSScriptRoot '..\..\DailyMotivation.ps1') -NoRun

    $script:OriginalAppData = $env:APPDATA
    $env:APPDATA = Join-Path ([System.IO.Path]::GetTempPath()) "DMBH_Sync_Test_$(New-Guid)"
    Initialize-AppData

    $script:ExePath = "C:\Test\DailyMotivation.exe"

    Mock Register-ScheduledTask { return $null }
    Mock Unregister-ScheduledTask { }
}

AfterAll {
    if (Test-Path $env:APPDATA) {
        Remove-Item -Path $env:APPDATA -Recurse -Force -ErrorAction SilentlyContinue
    }
    $env:APPDATA = $script:OriginalAppData
}

Describe 'Sync-TaskStatuses' -Skip:(-not $IsWindows) {
    BeforeEach {
        '[]' | Set-Content (Join-Path $env:APPDATA 'DailyMotivationBrainHelper\tasks.json') -Encoding UTF8
    }

    Context 'When a PENDING task is missing from OS Task Scheduler (Direction 1: JSON → OS)' {
        It 'Should mark the task status as DELETED when the OS task is gone' {
            # AG8-019: Direction 1 — task in tasks.json but not in OS scheduler
            Mock Get-ScheduledTask {
                param($TaskName)
                # Throw CimJobException when looking up a specific task name (task not found)
                throw [System.Exception]::new("The system cannot find the file specified.")
            }
            # Seed a PENDING task directly in tasks.json
            $fakeTask = [PSCustomObject]@{
                task_id        = 'sync-test-001'
                task_name      = 'DailyMotivation_sync-test-001'
                folder_path    = 'C:\TestFolder'
                folder_name    = 'TestFolder'
                scheduled_time = (Get-Date).AddHours(2).ToString('yyyy-MM-ddTHH:mm:ss')
                created_at     = (Get-Date -Format 'o')
                status         = 'PENDING'
                snooze_count   = 0
            }
            Save-TasksJson @($fakeTask)

            Sync-TaskStatuses

            $tasks = @(Get-TasksJson)
            $tasks.Count             | Should -Be 1
            $tasks[0].status         | Should -Be 'DELETED'
        }
    }

    Context 'When an OS task is orphaned (not in tasks.json) (Direction 2: OS → JSON)' {
        It 'Should recover the orphaned OS task into tasks.json' {
            # AG8-019: Direction 2 — task in OS scheduler but missing from tasks.json
            # Start with empty tasks.json
            $orphanTaskName = 'DailyMotivation_orphan001'
            Mock Get-ScheduledTask {
                param($TaskName)
                if ($TaskName -eq 'DailyMotivation_*' -or $null -eq $TaskName) {
                    return @([PSCustomObject]@{
                        TaskName    = $orphanTaskName
                        Description = 'Daily Motivation Brain Helper - C:\OrphanFolder'
                        Triggers    = @([PSCustomObject]@{
                            StartBoundary = (Get-Date).AddHours(3).ToString('yyyy-MM-ddTHH:mm:ss')
                        })
                    })
                }
                # No matching task found for specific task name lookups
                throw [System.Exception]::new("Task not found")
            }

            Sync-TaskStatuses

            $tasks = @(Get-TasksJson)
            $tasks.Count              | Should -Be 1
            $tasks[0].task_name       | Should -Be $orphanTaskName
            $tasks[0].status          | Should -Be 'PENDING'
            $tasks[0].folder_path     | Should -Be 'C:\OrphanFolder'
        }
    }

    Context 'When no tasks exist' {
        It 'Should not throw and leave tasks.json as empty array' {
            Mock Get-ScheduledTask {
                param($TaskName)
                if ($null -eq $TaskName -or $TaskName -eq 'DailyMotivation_*') { return @() }
                throw [System.Exception]::new("Task not found")
            }
            { Sync-TaskStatuses } | Should -Not -Throw
            @(Get-TasksJson).Count | Should -Be 0
        }
    }

    Context 'When platform adapter is active' {
        It 'Should skip reconciliation and return immediately' {
            $script:Platform = [HeadlessPlatform]::new()
            try {
                # Seed a task to verify it is NOT modified
                $fakeTask = [PSCustomObject]@{
                    task_id        = 'plat-test-001'
                    task_name      = 'DailyMotivation_plat-test-001'
                    folder_path    = 'C:\PlatTest'
                    folder_name    = 'PlatTest'
                    scheduled_time = (Get-Date).AddHours(2).ToString('yyyy-MM-ddTHH:mm:ss')
                    created_at     = (Get-Date -Format 'o')
                    status         = 'PENDING'
                    snooze_count   = 0
                }
                Save-TasksJson @($fakeTask)
                Sync-TaskStatuses
                # Status should be unchanged (function returned early)
                $tasks = @(Get-TasksJson)
                $tasks[0].status | Should -Be 'PENDING'
            }
            finally {
                $script:Platform = $null
            }
        }
    }
}
