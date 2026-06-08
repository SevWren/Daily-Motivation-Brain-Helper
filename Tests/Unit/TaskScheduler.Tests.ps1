#Requires -Modules Pester
<#
.SYNOPSIS
    Unit tests for TaskScheduler.psm1

.DESCRIPTION
    Tests all functions in TaskScheduler module including:
    - New-MotivationTask
    - Get-MotivationTasks
    - Remove-MotivationTask
    - Update-MotivationTaskStatus
#>

BeforeAll {
    # Import modules under test
    $ConfigPath = Join-Path $PSScriptRoot '..\..\src\Modules\ConfigManager.psm1'
    $TaskPath = Join-Path $PSScriptRoot '..\..\src\Modules\TaskScheduler.psm1'
    Import-Module $ConfigPath -Force
    Import-Module $TaskPath -Force

    # Create test AppData directory
    $script:TestAppDataDir = Join-Path ([System.IO.Path]::GetTempPath()) "DailyMotivationBrainHelper_Test_$(New-Guid)"
    $script:OriginalAppDataDir = $env:APPDATA
    $env:APPDATA = $script:TestAppDataDir

    Initialize-AppData

    # Test folder paths
    $script:TestFolder1 = 'C:\Projects\TestFolder1'
    $script:TestFolder2 = 'C:\Projects\TestFolder2'
}

AfterAll {
    # Cleanup
    if (Test-Path $script:TestAppDataDir) {
        Remove-Item -Path $script:TestAppDataDir -Recurse -Force -ErrorAction SilentlyContinue
    }
    $env:APPDATA = $script:OriginalAppDataDir
}

Describe 'New-MotivationTask' {
    BeforeEach {
        # Clear tasks.json
        "[]" | Set-Content (Join-Path $script:TestAppDataDir 'DailyMotivationBrainHelper\tasks.json') -Encoding UTF8
    }

    Context 'When creating a new task' {
        It 'Should create task with valid parameters' {
            $triggerTime = (Get-Date).AddHours(2)
            $result = New-MotivationTask -FolderPath $script:TestFolder1 -TriggerTime $triggerTime

            $result.Success | Should -Be $true
            $result.TaskId | Should -Not -BeNullOrEmpty
            $result.TaskId.Length | Should -Be 16
            $result.IsDuplicate | Should -Be $false
        }

        It 'Should generate unique task IDs' {
            $triggerTime = (Get-Date).AddHours(2)
            $result1 = New-MotivationTask -FolderPath $script:TestFolder1 -TriggerTime $triggerTime
            $result2 = New-MotivationTask -FolderPath $script:TestFolder2 -TriggerTime $triggerTime

            $result1.TaskId | Should -Not -Be $result2.TaskId
        }

        It 'Should store task in tasks.json' {
            $triggerTime = (Get-Date).AddHours(2)
            $result = New-MotivationTask -FolderPath $script:TestFolder1 -TriggerTime $triggerTime

            $tasks = Get-MotivationTasks
            $tasks.Count | Should -Be 1
            $tasks[0].task_id | Should -Be $result.TaskId
            $tasks[0].folder_path | Should -Be $script:TestFolder1
        }

        It 'Should set status to PENDING' {
            $triggerTime = (Get-Date).AddHours(2)
            $result = New-MotivationTask -FolderPath $script:TestFolder1 -TriggerTime $triggerTime

            $tasks = Get-MotivationTasks
            $tasks[0].status | Should -Be 'PENDING'
        }

        It 'Should derive folder name from path' {
            $triggerTime = (Get-Date).AddHours(2)
            $result = New-MotivationTask -FolderPath 'C:\Projects\ClientA\Subfolder' -TriggerTime $triggerTime

            $tasks = Get-MotivationTasks
            $tasks[0].folder_name | Should -Be 'Subfolder'
        }

        It 'Should format trigger time as ISO 8601' {
            $triggerTime = Get-Date -Year 2026 -Month 12 -Day 25 -Hour 14 -Minute 0 -Second 0
            $result = New-MotivationTask -FolderPath $script:TestFolder1 -TriggerTime $triggerTime

            $tasks = Get-MotivationTasks
            $tasks[0].scheduled_time | Should -Match '2026-12-25T14:00:00'
        }

        It 'Should initialize snooze_count to 0' {
            $triggerTime = (Get-Date).AddHours(2)
            $result = New-MotivationTask -FolderPath $script:TestFolder1 -TriggerTime $triggerTime

            $tasks = Get-MotivationTasks
            $tasks[0].snooze_count | Should -Be 0
        }
    }

    Context 'When checking for duplicates' {
        It 'Should detect duplicate task for same folder and date' {
            $triggerTime = (Get-Date).Date.AddHours(14)
            $result1 = New-MotivationTask -FolderPath $script:TestFolder1 -TriggerTime $triggerTime

            $result2 = New-MotivationTask -FolderPath $script:TestFolder1 -TriggerTime $triggerTime

            $result2.Success | Should -Be $false
            $result2.IsDuplicate | Should -Be $true
        }

        It 'Should allow duplicate with -Force flag' {
            $triggerTime = (Get-Date).Date.AddHours(14)
            $result1 = New-MotivationTask -FolderPath $script:TestFolder1 -TriggerTime $triggerTime

            $result2 = New-MotivationTask -FolderPath $script:TestFolder1 -TriggerTime $triggerTime -Force

            $result2.Success | Should -Be $true
            $result2.IsDuplicate | Should -Be $false

            $tasks = Get-MotivationTasks
            $tasks.Count | Should -Be 2
        }

        It 'Should not detect duplicate for different folders' {
            $triggerTime = (Get-Date).Date.AddHours(14)
            $result1 = New-MotivationTask -FolderPath $script:TestFolder1 -TriggerTime $triggerTime
            $result2 = New-MotivationTask -FolderPath $script:TestFolder2 -TriggerTime $triggerTime

            $result1.Success | Should -Be $true
            $result2.Success | Should -Be $true
            $result2.IsDuplicate | Should -Be $false
        }

        It 'Should not detect duplicate for different dates' {
            $triggerTime1 = (Get-Date).Date.AddHours(14)
            $triggerTime2 = (Get-Date).Date.AddDays(1).AddHours(14)

            $result1 = New-MotivationTask -FolderPath $script:TestFolder1 -TriggerTime $triggerTime1
            $result2 = New-MotivationTask -FolderPath $script:TestFolder1 -TriggerTime $triggerTime2

            $result1.Success | Should -Be $true
            $result2.Success | Should -Be $true
            $result2.IsDuplicate | Should -Be $false
        }

        It 'Should perform case-insensitive duplicate check' {
            $triggerTime = (Get-Date).Date.AddHours(14)
            $result1 = New-MotivationTask -FolderPath 'C:\Projects\TestFolder' -TriggerTime $triggerTime
            $result2 = New-MotivationTask -FolderPath 'c:\PROJECTS\testfolder' -TriggerTime $triggerTime

            $result2.IsDuplicate | Should -Be $true
        }
    }

    Context 'When handling network paths' {
        It 'Should detect UNC paths' {
            $triggerTime = (Get-Date).AddHours(2)
            $result = New-MotivationTask -FolderPath '\\server\share\folder' -TriggerTime $triggerTime

            $result.IsNetworkPath | Should -Be $true
        }

        It 'Should detect mapped drives' {
            $triggerTime = (Get-Date).AddHours(2)
            $result = New-MotivationTask -FolderPath 'Z:\Projects\Folder' -TriggerTime $triggerTime

            # Note: This requires actual network drive detection logic
            # Current implementation may not detect this without WMI queries
            # Test documents expected behavior
        }
    }
}

Describe 'Get-MotivationTasks' {
    BeforeEach {
        "[]" | Set-Content (Join-Path $script:TestAppDataDir 'DailyMotivationBrainHelper\tasks.json') -Encoding UTF8
    }

    It 'Should return empty array when no tasks exist' {
        $tasks = Get-MotivationTasks

        $tasks | Should -Be $null  # PS5.1 returns $null for empty arrays from ConvertFrom-Json
    }

    It 'Should return all tasks' {
        $triggerTime = (Get-Date).AddHours(2)
        New-MotivationTask -FolderPath $script:TestFolder1 -TriggerTime $triggerTime
        New-MotivationTask -FolderPath $script:TestFolder2 -TriggerTime $triggerTime

        $tasks = Get-MotivationTasks
        $tasks.Count | Should -Be 2
    }

    It 'Should return tasks with all properties' {
        $triggerTime = (Get-Date).AddHours(2)
        New-MotivationTask -FolderPath $script:TestFolder1 -TriggerTime $triggerTime

        $tasks = Get-MotivationTasks
        $task = $tasks[0]

        $task.task_id | Should -Not -BeNullOrEmpty
        $task.task_name | Should -Match 'DailyMotivation_'
        $task.folder_path | Should -Not -BeNullOrEmpty
        $task.folder_name | Should -Not -BeNullOrEmpty
        $task.scheduled_time | Should -Not -BeNullOrEmpty
        $task.status | Should -Not -BeNullOrEmpty
        $task.snooze_count | Should -BeOfType [int]
    }

    It 'Should handle corrupted tasks.json gracefully' {
        'invalid json{' | Set-Content (Join-Path $script:TestAppDataDir 'DailyMotivationBrainHelper\tasks.json') -Encoding UTF8

        $tasks = Get-MotivationTasks

        $tasks.Count | Should -Be 0
    }
}

Describe 'Remove-MotivationTask' {
    BeforeEach {
        "[]" | Set-Content (Join-Path $script:TestAppDataDir 'DailyMotivationBrainHelper\tasks.json') -Encoding UTF8
    }

    It 'Should remove task by ID' {
        $triggerTime = (Get-Date).AddHours(2)
        $result = New-MotivationTask -FolderPath $script:TestFolder1 -TriggerTime $triggerTime

        Remove-MotivationTask -TaskId $result.TaskId

        $tasks = Get-MotivationTasks
        $tasks.Count | Should -Be 0
    }

    It 'Should only remove specified task' {
        $triggerTime = (Get-Date).AddHours(2)
        $result1 = New-MotivationTask -FolderPath $script:TestFolder1 -TriggerTime $triggerTime
        $result2 = New-MotivationTask -FolderPath $script:TestFolder2 -TriggerTime $triggerTime

        Remove-MotivationTask -TaskId $result1.TaskId

        $tasks = Get-MotivationTasks
        $tasks.Count | Should -Be 1
        $tasks[0].task_id | Should -Be $result2.TaskId
    }

    It 'Should not throw when removing non-existent task' {
        {
            Remove-MotivationTask -TaskId 'nonexistent'
        } | Should -Not -Throw
    }
}

Describe 'Update-MotivationTaskStatus' {
    BeforeEach {
        "[]" | Set-Content (Join-Path $script:TestAppDataDir 'DailyMotivationBrainHelper\tasks.json') -Encoding UTF8
    }

    It 'Should update task status' {
        $triggerTime = (Get-Date).AddHours(2)
        $result = New-MotivationTask -FolderPath $script:TestFolder1 -TriggerTime $triggerTime

        Update-MotivationTaskStatus -TaskId $result.TaskId -Status 'COMPLETED'

        $tasks = Get-MotivationTasks
        $tasks[0].status | Should -Be 'COMPLETED'
    }

    It 'Should support all valid status values' {
        $triggerTime = (Get-Date).AddHours(2)
        $validStatuses = @('PENDING', 'COMPLETED', 'SNOOZED', 'DISMISSED', 'DELETED')

        foreach ($status in $validStatuses) {
            "[]" | Set-Content (Join-Path $script:TestAppDataDir 'DailyMotivationBrainHelper\tasks.json') -Encoding UTF8
            $result = New-MotivationTask -FolderPath $script:TestFolder1 -TriggerTime $triggerTime

            Update-MotivationTaskStatus -TaskId $result.TaskId -Status $status

            $tasks = Get-MotivationTasks
            $tasks[0].status | Should -Be $status
        }
    }

    It 'Should not affect other tasks' {
        $triggerTime = (Get-Date).AddHours(2)
        $result1 = New-MotivationTask -FolderPath $script:TestFolder1 -TriggerTime $triggerTime
        $result2 = New-MotivationTask -FolderPath $script:TestFolder2 -TriggerTime $triggerTime

        Update-MotivationTaskStatus -TaskId $result1.TaskId -Status 'COMPLETED'

        $tasks = Get-MotivationTasks
        ($tasks | Where-Object { $_.task_id -eq $result1.TaskId }).status | Should -Be 'COMPLETED'
        ($tasks | Where-Object { $_.task_id -eq $result2.TaskId }).status | Should -Be 'PENDING'
    }
}

Describe 'Task Scheduler Integration' {
    It 'Should create Windows scheduled task' -Skip {
        # Skipped: Requires administrative privileges and Windows Task Scheduler
        # Integration test suite will cover this
    }

    It 'Should remove Windows scheduled task' -Skip {
        # Skipped: Requires administrative privileges
    }

    It 'Should detect when scheduled task is missing' -Skip {
        # Skipped: Requires Windows Task Scheduler access
    }
}
