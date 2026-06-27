#Requires -Modules Pester
<#
.SYNOPSIS
    Unit tests for task scheduler functions in DailyMotivation.ps1.
    Covers: New-MotivationTask, Get-MotivationTasks, Remove-MotivationTask.
    Note: actual Register-ScheduledTask calls are mocked; these tests cover
    the JSON-persistence and business-logic layers only.
#>

BeforeAll {
    . (Join-Path $PSScriptRoot '..\..\DailyMotivation.ps1') -NoRun

    $script:OriginalAppData = $env:APPDATA
    $env:APPDATA = Join-Path ([System.IO.Path]::GetTempPath()) "DMBH_Task_Test_$(New-Guid)"
    Initialize-AppData

    # Override ExePath so the task action points to a dummy path
    $script:ExePath = "C:\Test\DailyMotivation.exe"

    $script:TestFolder1 = 'C:\Projects\TestFolder1'
    $script:TestFolder2 = 'C:\Projects\TestFolder2'

    # Mock Windows Task Scheduler cmdlets so tests run without admin rights
    # Mock Register-ScheduledTask at the highest level to bypass CimInstance type validation
    # Real Task Scheduler cmdlets return CimInstance objects, which cannot be easily mocked.
    # By mocking Register-ScheduledTask directly, we bypass parameter type validation and
    # focus on testing the business logic (JSON persistence, duplicate detection, etc.)
    Mock Register-ScheduledTask {
        param(
            $TaskName,
            $Action,
            $Trigger,
            $Settings,
            $Principal,
            $Description,
            [switch]$Force
        )
        # Just succeed - we're testing business logic, not Windows API
        return $null
    }
    Mock Unregister-ScheduledTask { }
    # Mock Get-ScheduledTask - return $null to simulate task not existing
    # This allows the collision-detection retry loop in New-MotivationTask to work correctly
    # Note: -ErrorAction is a CommonParameter and cannot be captured in Pester mocks
    Mock Get-ScheduledTask { return $null }
}

AfterAll {
    if (Test-Path $env:APPDATA) {
        Remove-Item -Path $env:APPDATA -Recurse -Force -ErrorAction SilentlyContinue
    }
    $env:APPDATA = $script:OriginalAppData
}

Describe 'New-MotivationTask' {
    BeforeEach {
        '[]' | Set-Content (Join-Path $env:APPDATA 'DailyMotivationBrainHelper\tasks.json') -Encoding UTF8
    }

    Context 'When creating a new task' {
        It 'Should return Success=true with a valid TaskId' {
            $result = New-MotivationTask -FolderPath $script:TestFolder1 -TriggerTime ((Get-Date).AddHours(2))
            $result.Success   | Should -Be $true
            $result.TaskId    | Should -Not -BeNullOrEmpty
            $result.TaskId.Length | Should -Be 16
            $result.IsDuplicate | Should -Be $false
        }

        It 'Should generate unique task IDs for different folders' {
            $t = (Get-Date).AddHours(2)
            $r1 = New-MotivationTask -FolderPath $script:TestFolder1 -TriggerTime $t
            $r2 = New-MotivationTask -FolderPath $script:TestFolder2 -TriggerTime $t
            $r1.TaskId | Should -Not -Be $r2.TaskId
        }

        It 'Should persist the task to tasks.json' {
            $result = New-MotivationTask -FolderPath $script:TestFolder1 -TriggerTime ((Get-Date).AddHours(2))
            $tasks = Get-TasksJson
            $tasks.Count             | Should -Be 1
            $tasks[0].task_id        | Should -Be $result.TaskId
            $tasks[0].folder_path    | Should -Be $script:TestFolder1
        }

        It 'Should set status to PENDING' {
            New-MotivationTask -FolderPath $script:TestFolder1 -TriggerTime ((Get-Date).AddHours(2)) | Out-Null
            (Get-TasksJson)[0].status | Should -Be 'PENDING'
        }

        It 'Should derive folder_name from path' {
            New-MotivationTask -FolderPath 'C:\Projects\ClientA\Subfolder' -TriggerTime ((Get-Date).AddHours(2)) | Out-Null
            (Get-TasksJson)[0].folder_name | Should -Be 'Subfolder'
        }

        It 'Should format trigger time as ISO 8601' {
            $t = Get-Date -Year 2026 -Month 12 -Day 25 -Hour 14 -Minute 0 -Second 0
            New-MotivationTask -FolderPath $script:TestFolder1 -TriggerTime $t | Out-Null
            $actual = (Get-TasksJson)[0].scheduled_time

            # PowerShell ConvertFrom-Json automatically converts ISO 8601 strings to DateTime objects
            # Verify the DateTime value matches what we expect
            $actual | Should -BeOfType [DateTime]
            $actual.Year | Should -Be 2026
            $actual.Month | Should -Be 12
            $actual.Day | Should -Be 25
            $actual.Hour | Should -Be 14
            $actual.Minute | Should -Be 0
            $actual.Second | Should -Be 0
        }

        It 'Should initialize snooze_count to 0' {
            New-MotivationTask -FolderPath $script:TestFolder1 -TriggerTime ((Get-Date).AddHours(2)) | Out-Null
            (Get-TasksJson)[0].snooze_count | Should -Be 0
        }
    }

    Context 'Duplicate detection' {
        It 'Should block duplicate for same folder and date' {
            $t = (Get-Date).Date.AddHours(14)
            New-MotivationTask -FolderPath $script:TestFolder1 -TriggerTime $t | Out-Null
            $r2 = New-MotivationTask -FolderPath $script:TestFolder1 -TriggerTime $t
            $r2.Success     | Should -Be $false
            $r2.IsDuplicate | Should -Be $true
        }

        It 'Should allow duplicate when -Force is set' {
            $t = (Get-Date).Date.AddHours(14)
            New-MotivationTask -FolderPath $script:TestFolder1 -TriggerTime $t | Out-Null
            $r2 = New-MotivationTask -FolderPath $script:TestFolder1 -TriggerTime $t -Force
            $r2.Success | Should -Be $true
            (Get-TasksJson).Count | Should -Be 2
        }

        It 'Should allow same folder on a different date' {
            $t1 = (Get-Date).Date.AddHours(14)
            $t2 = (Get-Date).Date.AddDays(1).AddHours(14)
            New-MotivationTask -FolderPath $script:TestFolder1 -TriggerTime $t1 | Out-Null
            $r2 = New-MotivationTask -FolderPath $script:TestFolder1 -TriggerTime $t2
            $r2.IsDuplicate | Should -Be $false
        }

        It 'Should perform case-insensitive path comparison' {
            $t = (Get-Date).Date.AddHours(14)
            New-MotivationTask -FolderPath 'C:\Projects\TestFolder' -TriggerTime $t | Out-Null
            $r2 = New-MotivationTask -FolderPath 'c:\PROJECTS\testfolder' -TriggerTime $t
            $r2.IsDuplicate | Should -Be $true
        }
    }

    Context 'Network path detection' {
        It 'Should detect UNC paths and set IsNetworkPath=true' {
            $result = New-MotivationTask -FolderPath '\\server\share\folder' -TriggerTime ((Get-Date).AddHours(2))
            $result.IsNetworkPath | Should -Be $true
        }

        It 'Should return IsNetworkPath=false for a local path' {
            $result = New-MotivationTask -FolderPath 'C:\Projects\Local' -TriggerTime ((Get-Date).AddHours(2))
            $result.IsNetworkPath | Should -Be $false
        }
    }

    Context 'Collision detection retry loop' {
        # AG8-004: Test that the retry loop actually executes when the first task name collides.
        # The mock returns a fake task on the first call (simulating collision), then $null.
        It 'Should retry and generate a new task ID on task name collision' {
            $callCount = 0
            Mock Get-ScheduledTask {
                $script:callCount++
                if ($script:callCount -eq 1) {
                    # Simulate collision — task already exists
                    return [PSCustomObject]@{ TaskName = 'DailyMotivation_collision' }
                }
                return $null  # Second call: no collision, new ID is unique
            }
            $result = New-MotivationTask -FolderPath $script:TestFolder1 -TriggerTime ((Get-Date).AddHours(2))
            $result.Success | Should -Be $true
            $script:callCount | Should -BeGreaterOrEqual 2  # retry loop executed
        }

        AfterEach {
            # Restore default mock (no collision)
            Mock Get-ScheduledTask { return $null }
        }
    }

    Context 'Error paths' {
        # AG8-012: Test error scenarios that were previously untested (happy-path only).

        It 'Should return Success=false and not persist task when Register-ScheduledTask throws' {
            Mock Register-ScheduledTask { throw 'Access Denied' }
            $result = New-MotivationTask -FolderPath $script:TestFolder1 -TriggerTime ((Get-Date).AddHours(2))
            $result.Success     | Should -Be $false
            $result.IsDuplicate | Should -Be $false
            $result.Error       | Should -Not -BeNullOrEmpty
            # Task must NOT have been persisted to tasks.json
            @(Get-TasksJson).Count | Should -Be 0
        }

        It 'Should call Unregister-ScheduledTask rollback when Save-TasksJson fails' {
            # Simulate a write failure by locking out the tasks.json path
            Mock Save-TasksJson { throw 'Disk full' }
            New-MotivationTask -FolderPath $script:TestFolder1 -TriggerTime ((Get-Date).AddHours(2)) | Out-Null
            Should -Invoke Unregister-ScheduledTask -Times 1 -Exactly
        }

        AfterEach {
            # Restore mocks to defaults
            Mock Register-ScheduledTask { return $null }
            Mock Save-TasksJson {
                param([object[]]$Tasks)
                $path     = $script:TasksPath
                $tempPath = $path + ".tmp"
                if ($null -eq $Tasks -or $Tasks.Count -eq 0) {
                    Set-Content -Path $tempPath -Value '[]' -Encoding UTF8 -NoNewline -ErrorAction Stop
                } else {
                    ConvertTo-Json -InputObject $Tasks -Depth 4 | Set-Content -Path $tempPath -Encoding UTF8 -ErrorAction Stop
                }
                Move-Item -Path $tempPath -Destination $path -Force -ErrorAction Stop
            }
        }
    }
}

Describe 'Get-MotivationTasks' {
    BeforeEach {
        '[]' | Set-Content (Join-Path $env:APPDATA 'DailyMotivationBrainHelper\tasks.json') -Encoding UTF8
    }

    It 'Should return an empty array when no tasks exist' {
        $tasks = Get-MotivationTasks
        @($tasks).Count | Should -Be 0
    }

    It 'Should return all tasks' {
        $t = (Get-Date).AddHours(2)
        New-MotivationTask -FolderPath $script:TestFolder1 -TriggerTime $t | Out-Null
        New-MotivationTask -FolderPath $script:TestFolder2 -TriggerTime $t | Out-Null
        @(Get-MotivationTasks).Count | Should -Be 2
    }

    It 'Should return tasks with required properties' {
        New-MotivationTask -FolderPath $script:TestFolder1 -TriggerTime ((Get-Date).AddHours(2)) | Out-Null
        $task = @(Get-MotivationTasks)[0]
        $task.task_id        | Should -Not -BeNullOrEmpty
        $task.task_name      | Should -Match 'DailyMotivation_'
        $task.folder_path    | Should -Not -BeNullOrEmpty
        $task.folder_name    | Should -Not -BeNullOrEmpty
        $task.scheduled_time | Should -Not -BeNullOrEmpty
        $task.status         | Should -Not -BeNullOrEmpty
        # Accept both [int] and [long] types (platform-specific JSON deserialization)
        $task.snooze_count.GetType().Name | Should -BeIn @('Int32', 'Int64')
        $task.snooze_count   | Should -Be 0
    }

    It 'Should handle corrupted tasks.json gracefully' {
        # AG8-002: Verify return value, not just that the function doesn't throw.
        # Must return an empty array (not $null or garbage) on corrupt input.
        'invalid json{' | Set-Content (Join-Path $env:APPDATA 'DailyMotivationBrainHelper\tasks.json') -Encoding UTF8
        $result = $null
        { $result = Get-MotivationTasks } | Should -Not -Throw
        $result         | Should -Not -Be $null
        @($result).Count | Should -Be 0
    }
}

Describe 'Remove-MotivationTask' {
    BeforeEach {
        '[]' | Set-Content (Join-Path $env:APPDATA 'DailyMotivationBrainHelper\tasks.json') -Encoding UTF8
    }

    It 'Should remove the specified task from tasks.json' {
        $r = New-MotivationTask -FolderPath $script:TestFolder1 -TriggerTime ((Get-Date).AddHours(2))
        Remove-MotivationTask -TaskId $r.TaskId
        @(Get-TasksJson).Count | Should -Be 0
    }

    It 'Should only remove the specified task, leaving others intact' {
        $t = (Get-Date).AddHours(2)
        $r1 = New-MotivationTask -FolderPath $script:TestFolder1 -TriggerTime $t
        $r2 = New-MotivationTask -FolderPath $script:TestFolder2 -TriggerTime $t
        Remove-MotivationTask -TaskId $r1.TaskId
        $tasks = @(Get-TasksJson)
        $tasks.Count        | Should -Be 1
        $tasks[0].task_id   | Should -Be $r2.TaskId
    }

    It 'Should not throw when removing a non-existent task ID' {
        { Remove-MotivationTask -TaskId 'nonexistent' } | Should -Not -Throw
    }
}

Describe 'Task Scheduler Integration' {
    It 'Should create a Windows scheduled task' -Skip {
        # Skipped: requires administrative privileges and Windows Task Scheduler
    }

    It 'Should remove a Windows scheduled task' -Skip {
        # Skipped: requires administrative privileges
    }
}
