#Requires -Modules @{ ModuleName='Pester'; ModuleVersion='5.0.0' }
<#
.SYNOPSIS
    Integration tests for AG20-001: Multi-folder scheduling scenarios.
    Verifies that scheduling, listing, and removing multiple tasks maintains
    tasks.json consistency and correct state across all operations.
    Windows-only: requires Task Scheduler cmdlets.
#>

BeforeAll {
    if (-not $IsWindows) {
        Write-Host "Skipping AG20-001 - Windows Task Scheduler required" -ForegroundColor Yellow
        return
    }
    $script:RepoRoot = Join-Path $PSScriptRoot '..\..'
    . (Join-Path $script:RepoRoot 'DailyMotivation.ps1') -NoRun
    $script:OriginalAppData = $env:APPDATA
    $env:APPDATA = Join-Path ([System.IO.Path]::GetTempPath()) "DMBH_Multi_$(New-Guid)"
    Initialize-AppData
    $script:ExePath = 'C:\Test\DailyMotivation.exe'
    # Register returns task object (AG5-001 verification uses return value, not Get-ScheduledTask)
    Mock Register-ScheduledTask {
        param($TaskName,$Action,$Trigger,$Settings,$Principal,$Description,[switch]$Force)
        return [PSCustomObject]@{ TaskName=$TaskName; State='Ready'; Triggers=@($Trigger) }
    }
    Mock Unregister-ScheduledTask {
        param($TaskName,$Confirm)
    }
    # Get-ScheduledTask: collision detection only; return $null = no collision
    Mock Get-ScheduledTask {
        param($TaskName)
        if ($TaskName -eq 'DailyMotivation_*') { return @() }
        return $null
    }
}

AfterAll {
    if (-not $IsWindows) { return }

    # AG20-015: Sweep for stray DailyMotivation_* tasks (safety net)
    try {
        $strayTasks = Get-ScheduledTask -TaskName "DailyMotivation_*" -ErrorAction SilentlyContinue
        if ($strayTasks) {
            Write-Warning "AG20-015 cleanup: Found $($strayTasks.Count) stray task(s) after test run. Removing..."
            foreach ($task in $strayTasks) {
                try {
                    Unregister-ScheduledTask -TaskName $task.TaskName -Confirm:$false -ErrorAction Stop
                    Write-Host "  - Removed stray task: $($task.TaskName)" -ForegroundColor Yellow
                }
                catch {
                    Write-Warning "  - Failed to remove $($task.TaskName): $($_.Exception.Message)"
                }
            }
        }
    }
    catch {
        # Get-ScheduledTask itself failed - log but don't fail the test run
        Write-Warning "AG20-015 cleanup: Could not sweep for stray tasks: $($_.Exception.Message)"
    }

    if (Test-Path $env:APPDATA) { Remove-Item -Path $env:APPDATA -Recurse -Force -ErrorAction SilentlyContinue }
    $env:APPDATA = $script:OriginalAppData
}

Describe 'AG20-001 Multi-Folder Scheduling Integration' -Skip:(-not $IsWindows) {

    BeforeEach {
        $script:AppDir = Join-Path $env:APPDATA 'DailyMotivationBrainHelper'
        if (Test-Path $script:AppDir) {
            Remove-Item -Path $script:AppDir -Recurse -Force
        }
        Initialize-AppData
    }

    It 'AC#1: Schedule 3 different folders - tasks.json has 3 PENDING entries with unique TaskIds, Register-ScheduledTask called 3 times' {
        $folder1 = 'C:\Projects\Alpha'
        $folder2 = 'C:\Projects\Beta'
        $folder3 = 'C:\Projects\Gamma'

        $r1 = New-MotivationTask -FolderPath $folder1 -TriggerTime ((Get-Date).AddHours(2))
        $r2 = New-MotivationTask -FolderPath $folder2 -TriggerTime ((Get-Date).AddHours(3))
        $r3 = New-MotivationTask -FolderPath $folder3 -TriggerTime ((Get-Date).AddHours(4))

        $r1.Success | Should -Be $true
        $r2.Success | Should -Be $true
        $r3.Success | Should -Be $true

        # Verify tasks.json contains exactly 3 PENDING entries
        $tasks = Get-MotivationTasks
        $tasks.Count | Should -Be 3

        # All tasks must be PENDING
        $tasks | ForEach-Object { $_.status | Should -Be 'PENDING' }

        # All TaskIds must be unique
        $taskIds = $tasks | ForEach-Object { $_.task_id }
        $taskIds.Count | Should -Be 3
        ($taskIds | Select-Object -Unique).Count | Should -Be 3

        # Verify correct folder paths
        $folderPaths = $tasks | ForEach-Object { $_.folder_path }
        $folderPaths | Should -Contain $folder1
        $folderPaths | Should -Contain $folder2
        $folderPaths | Should -Contain $folder3

        # Verify Register-ScheduledTask was called exactly 3 times
        Should -Invoke -CommandName Register-ScheduledTask -Times 3 -Exactly
    }

    It 'AC#2: Schedule 2 folders, remove 1 - tasks.json retains exactly 1 PENDING entry, Unregister-ScheduledTask called once' {
        $folder1 = 'C:\Projects\Alpha'
        $folder2 = 'C:\Projects\Beta'

        $r1 = New-MotivationTask -FolderPath $folder1 -TriggerTime ((Get-Date).AddHours(2))
        $r2 = New-MotivationTask -FolderPath $folder2 -TriggerTime ((Get-Date).AddHours(3))

        $r1.Success | Should -Be $true
        $r2.Success | Should -Be $true

        # Remove task 2
        $removeResult = Remove-MotivationTask -TaskId $r2.TaskId
        $removeResult | Should -Be $true

        # Verify tasks.json contains exactly 1 PENDING entry
        $tasks = Get-MotivationTasks
        $tasks.Count | Should -Be 1
        $tasks[0].status | Should -Be 'PENDING'
        $tasks[0].folder_path | Should -Be $folder1
        $tasks[0].task_id | Should -Be $r1.TaskId

        # Verify Unregister-ScheduledTask was called exactly once with correct task name
        Should -Invoke -CommandName Unregister-ScheduledTask -Times 1 -Exactly
        Should -Invoke -CommandName Unregister-ScheduledTask -ParameterFilter {
            $TaskName -eq "DailyMotivation_$($r2.TaskId)"
        } -Times 1 -Exactly
    }

    It 'Remove the MIDDLE task (task 2 of 3) - adjacent entries remain intact with no data corruption' {
        $folder1 = 'C:\Projects\Alpha'
        $folder2 = 'C:\Projects\Beta'
        $folder3 = 'C:\Projects\Gamma'

        $r1 = New-MotivationTask -FolderPath $folder1 -TriggerTime ((Get-Date).AddHours(2))
        $r2 = New-MotivationTask -FolderPath $folder2 -TriggerTime ((Get-Date).AddHours(3))
        $r3 = New-MotivationTask -FolderPath $folder3 -TriggerTime ((Get-Date).AddHours(4))

        $r1.Success | Should -Be $true
        $r2.Success | Should -Be $true
        $r3.Success | Should -Be $true

        # Remove the middle task (task 2)
        $removeResult = Remove-MotivationTask -TaskId $r2.TaskId
        $removeResult | Should -Be $true

        $tasks = Get-MotivationTasks
        $tasks.Count | Should -Be 2

        $folderPaths = $tasks | ForEach-Object { $_.folder_path }
        $folderPaths | Should -Contain $folder1
        $folderPaths | Should -Not -Contain $folder2
        $folderPaths | Should -Contain $folder3

        # Verify task IDs are exactly task 1 and task 3 (no data corruption)
        $taskIds = $tasks | ForEach-Object { $_.task_id }
        $taskIds | Should -Contain $r1.TaskId
        $taskIds | Should -Not -Contain $r2.TaskId
        $taskIds | Should -Contain $r3.TaskId
    }

    It 'Schedule a 4th folder after removal of middle task - total becomes 3 tasks' {
        $folder1 = 'C:\Projects\Alpha'
        $folder2 = 'C:\Projects\Beta'
        $folder3 = 'C:\Projects\Gamma'
        $folder4 = 'C:\Projects\Delta'

        $r1 = New-MotivationTask -FolderPath $folder1 -TriggerTime ((Get-Date).AddHours(2))
        $r2 = New-MotivationTask -FolderPath $folder2 -TriggerTime ((Get-Date).AddHours(3))
        $r3 = New-MotivationTask -FolderPath $folder3 -TriggerTime ((Get-Date).AddHours(4))

        $r1.Success | Should -Be $true
        $r2.Success | Should -Be $true
        $r3.Success | Should -Be $true

        Remove-MotivationTask -TaskId $r2.TaskId

        $r4 = New-MotivationTask -FolderPath $folder4 -TriggerTime ((Get-Date).AddHours(5))
        $r4.Success | Should -Be $true

        $tasks = Get-MotivationTasks
        $tasks.Count | Should -Be 3

        $folderPaths = $tasks | ForEach-Object { $_.folder_path }
        $folderPaths | Should -Contain $folder1
        $folderPaths | Should -Not -Contain $folder2
        $folderPaths | Should -Contain $folder3
        $folderPaths | Should -Contain $folder4
    }

    It 'tasks.json is valid and parseable JSON after all operations (no corruption)' {
        $folder1 = 'C:\Projects\Alpha'
        $folder2 = 'C:\Projects\Beta'
        $folder3 = 'C:\Projects\Gamma'
        $folder4 = 'C:\Projects\Delta'

        $r1 = New-MotivationTask -FolderPath $folder1 -TriggerTime ((Get-Date).AddHours(2))
        $r2 = New-MotivationTask -FolderPath $folder2 -TriggerTime ((Get-Date).AddHours(3))
        $r3 = New-MotivationTask -FolderPath $folder3 -TriggerTime ((Get-Date).AddHours(4))

        $r1.Success | Should -Be $true
        $r2.Success | Should -Be $true
        $r3.Success | Should -Be $true

        Remove-MotivationTask -TaskId $r2.TaskId

        $r4 = New-MotivationTask -FolderPath $folder4 -TriggerTime ((Get-Date).AddHours(5))
        $r4.Success | Should -Be $true

        $appDir = Join-Path $env:APPDATA 'DailyMotivationBrainHelper'
        $tasksJsonPath = Join-Path $appDir 'tasks.json'
        Test-Path $tasksJsonPath | Should -Be $true

        $raw = Get-Content -Path $tasksJsonPath -Raw
        $raw | Should -Not -BeNullOrEmpty

        # ConvertFrom-Json throws on invalid JSON  -  this assertion catches corruption
        { $raw | ConvertFrom-Json } | Should -Not -Throw

        $parsed = $raw | ConvertFrom-Json
        $parsedArray = @($parsed)
        $parsedArray.Count | Should -Be 3
    }

    It 'AC#3: Get-MotivationTasks returns all tasks with correct FolderPath values (case-insensitive match)' {
        $folder1 = 'C:\Projects\Alpha'
        $folder2 = 'c:\projects\beta'  # lowercase
        $folder3 = 'C:\PROJECTS\GAMMA'  # uppercase

        $r1 = New-MotivationTask -FolderPath $folder1 -TriggerTime ((Get-Date).AddHours(2))
        $r2 = New-MotivationTask -FolderPath $folder2 -TriggerTime ((Get-Date).AddHours(3))
        $r3 = New-MotivationTask -FolderPath $folder3 -TriggerTime ((Get-Date).AddHours(4))

        $r1.Success | Should -Be $true
        $r2.Success | Should -Be $true
        $r3.Success | Should -Be $true

        # Get all tasks
        $tasks = Get-MotivationTasks
        $tasks.Count | Should -Be 3

        # Verify all folder paths are present (exact match - case preserved as stored)
        $folderPaths = $tasks | ForEach-Object { $_.folder_path }
        $folderPaths | Should -Contain $folder1
        $folderPaths | Should -Contain $folder2
        $folderPaths | Should -Contain $folder3

        # Verify case-insensitive comparison works for duplicate detection
        $rDupe = New-MotivationTask -FolderPath 'C:\PROJECTS\ALPHA' -TriggerTime ((Get-Date).AddHours(2))
        $rDupe.Success | Should -Be $false
        $rDupe.IsDuplicate | Should -Be $true

        # Count must remain at 3 - case-insensitive duplicate was rejected
        $tasks = Get-MotivationTasks
        $tasks.Count | Should -Be 3
    }

    It 'Schedule same folder twice on the same date - second call returns IsDuplicate=$true, count stays at 3' {
        $folder1 = 'C:\Projects\Alpha'
        $folder2 = 'C:\Projects\Beta'
        $folder3 = 'C:\Projects\Gamma'

        $triggerTime = (Get-Date).AddHours(2)

        $r1 = New-MotivationTask -FolderPath $folder1 -TriggerTime $triggerTime
        $r2 = New-MotivationTask -FolderPath $folder2 -TriggerTime ((Get-Date).AddHours(3))
        $r3 = New-MotivationTask -FolderPath $folder3 -TriggerTime ((Get-Date).AddHours(4))

        $r1.Success | Should -Be $true
        $r2.Success | Should -Be $true
        $r3.Success | Should -Be $true

        # Attempt to schedule folder1 again at the same trigger time (same date)
        $rDupe = New-MotivationTask -FolderPath $folder1 -TriggerTime $triggerTime
        $rDupe.Success    | Should -Be $false
        $rDupe.IsDuplicate | Should -Be $true

        # Count must remain at 3  -  duplicate was rejected
        $tasks = Get-MotivationTasks
        $tasks.Count | Should -Be 3
    }
}
