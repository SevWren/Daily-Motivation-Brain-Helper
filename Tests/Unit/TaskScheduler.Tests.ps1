#Requires -Modules @{ ModuleName='Pester'; ModuleVersion='5.0.0' }
<#
.SYNOPSIS
    Unit tests for task scheduler functions in DailyMotivation.ps1.
    Covers: New-MotivationTask, Get-MotivationTask s, Remove-MotivationTask.
.NOTES
    Windows-only tests: actual Register-ScheduledTask calls are mocked; these tests cover
    the JSON-persistence and business-logic layers only but require Task Scheduler cmdlets.
#>

BeforeAll {
    # Skip all tests if not on Windows (Task Scheduler cmdlets don't exist on Linux)
    if (-not $IsWindows) {
        Write-Host "Skipping TaskScheduler.Tests.ps1 - Windows Task Scheduler required" -ForegroundColor Yellow
        return
    }

    . (Join-Path $PSScriptRoot '..\..\DailyMotivation.ps1') -NoRun

    $script:OriginalAppData = $env:APPDATA
    $env:APPDATA = Join-Path ([System.IO.Path]::GetTempPath()) "DMBH_Task_Test_$(New-Guid)"
    Initialize-AppData

    # Override ExePath so the task action points to a dummy path
    $script:ExePath = "C:\Test\DailyMotivation.exe"

    $script:TestFolder1 = 'C:\Projects\TestFolder1'
    $script:TestFolder2 = 'C:\Projects\TestFolder2'

    # AG8-009: Mock Scope Documentation
    # ===================================
    # These mocks are scoped to BeforeAll, meaning they affect ALL tests in this file.
    # This is intentional for baseline behavior: most tests expect Register-ScheduledTask
    # to succeed and Get-ScheduledTask to return $null (no collision).
    #
    # Individual Context blocks override these mocks when testing specific scenarios:
    # - 'Collision detection retry loop' overrides Get-ScheduledTask to simulate collisions
    # - 'Error paths' overrides Register-ScheduledTask to throw exceptions
    #
    # Mock overrides in Context/It blocks are cleaned up in AfterEach to restore baseline.
    # This prevents test pollution where one test's mock affects subsequent tests.

    # Mock Windows Task Scheduler cmdlets so tests run without admin rights
    # Mock Register-ScheduledTask at the highest level to bypass CimInstance type validation
    # Real Task Scheduler cmdlets return CimInstance objects, which cannot be easily mocked.
    # By mocking Register-ScheduledTask directly, we bypass parameter type validation and
    # focus on testing the business logic (JSON persistence, duplicate detection, etc.)
    # Track registered tasks in script scope for stateful mocking
    $script:MockedTasks = @{}

    # AG8-001: Add -Verifiable to enable mock call verification
    Mock Register-ScheduledTask -Verifiable {
        param(
            $TaskName,
            $Action,
            $Trigger,
            $Settings,
            $Principal,
            $Description,
            [switch]$Force
        )
        # Track registered task for Get-ScheduledTask mock
        $script:MockedTasks[$TaskName] = [PSCustomObject]@{
            TaskName = $TaskName
            State = [PSCustomObject]@{ State = 'Ready' }
            Triggers = @($Trigger)
        }

        return $null
    }
    # AG8-003: Add -Verifiable to Unregister mock for validation
    Mock Unregister-ScheduledTask -Verifiable {
        param($TaskName, $Confirm)
        # Remove from tracked tasks
        if ($script:MockedTasks.ContainsKey($TaskName)) {
            $script:MockedTasks.Remove($TaskName)
        }
    }
    # Mock Get-ScheduledTask - handle both specific task lookups and wildcard queries
    # - For specific task names: return tracked task or throw if not found
    # - For wildcard "DailyMotivation_*": return all tracked tasks
    # Note: -ErrorAction is a CommonParameter and cannot be captured in Pester mocks
    Mock Get-ScheduledTask {
        param($TaskName)
        if ($TaskName -eq "DailyMotivation_*") {
            return @($script:MockedTasks.Values)
        }
        if ($script:MockedTasks.ContainsKey($TaskName)) {
            return $script:MockedTasks[$TaskName]
        }
        return $null
    }
}

AfterAll {
    if (Test-Path $env:APPDATA) {
        Remove-Item -Path $env:APPDATA -Recurse -Force -ErrorAction SilentlyContinue
    }
    $env:APPDATA = $script:OriginalAppData
}

Describe 'New-MotivationTask' -Skip:(-not $IsWindows) {
    BeforeEach {
        # Use $script:TasksPath directly to ensure we're writing to the same path that Get-TasksJson reads from
        if (-not (Test-Path (Split-Path $script:TasksPath -Parent))) {
            New-Item -ItemType Directory -Path (Split-Path $script:TasksPath -Parent) -Force | Out-Null
        }
        '[]' | Set-Content $script:TasksPath -Encoding UTF8 -Force
        $script:MockedTasks = @{}
    }

    Context 'When creating a new task' {
        It 'Should return Success=true with a valid TaskId' {
            $result = New-MotivationTask -FolderPath $script:TestFolder1 -TriggerTime ((Get-Date).AddHours(2))
            $result.Success   | Should -Be $true
            $result.TaskId    | Should -Not -BeNullOrEmpty
            $result.TaskId.Length | Should -Be 16
            $result.IsDuplicate | Should -Be $false
            # AG8-001: Verify Register-ScheduledTask was called exactly once
            Should -Invoke Register-ScheduledTask -Times 1 -Exactly
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

        It 'Should store scheduled_time in ISO 8601 format with timezone offset in JSON (AG8-027, AG18-024)' {
            # AG8-027: Verify the RAW JSON string format, not just deserialized DateTime.
            # AG18-024: format now includes timezone offset via K specifier (e.g. -06:00 or Z).
            $t = [datetime]::new(2026, 12, 25, 14, 0, 0)
            New-MotivationTask -FolderPath $script:TestFolder1 -TriggerTime $t | Out-Null

            # Read raw JSON without deserializing
            $rawJson = Get-Content (Join-Path $env:APPDATA 'DailyMotivationBrainHelper\tasks.json') -Raw

            # Verify date and time portion present; offset suffix varies by machine timezone
            $rawJson | Should -Match '"scheduled_time"\s*:\s*"2026-12-25T14:00:00'

            # Verify that an offset or Z suffix is present (AG18-024)
            $rawJson | Should -Match '"scheduled_time"\s*:\s*"2026-12-25T14:00:00[\+\-Z]'
        }

        It 'Should initialize snooze_count to 0' {
            New-MotivationTask -FolderPath $script:TestFolder1 -TriggerTime ((Get-Date).AddHours(2)) | Out-Null
            (Get-TasksJson)[0].snooze_count | Should -Be 0
        }

        It 'Should call Register-ScheduledTask with correct TaskName format' {
            # AG8-001/AG8-003: Verify mock parameters match expected format
            $result = New-MotivationTask -FolderPath $script:TestFolder1 -TriggerTime ((Get-Date).AddHours(2))
            Should -Invoke Register-ScheduledTask -Times 1 -ParameterFilter {
                $TaskName -like 'DailyMotivation_*'
            }
        }
    }

    Context 'Duplicate detection' {
        BeforeEach {
            # Inject platform adapter to skip Sync-TaskStatuses and use consistent mocking.
            # ScriptMethod is required because DailyMotivation.ps1 calls $script:Platform.ScheduleTask(@{...})
            # using method-invocation syntax, which does not work with NoteProperty scriptblocks.
            $script:Platform = [PSCustomObject]@{}
            $script:Platform | Add-Member -MemberType ScriptMethod -Name 'ScheduleTask' -Value {
                param($config)
                $taskId = [System.Guid]::NewGuid().ToString("N").Substring(0, 16)
                $taskName = "DailyMotivation_$taskId"
                # Directly insert into MockedTasks  -  ScriptMethods bypass Pester mock scope
                # so calling Register-ScheduledTask here would invoke the real cmdlet.
                $script:MockedTasks[$taskName] = [PSCustomObject]@{
                    TaskName = $taskName
                    State    = [PSCustomObject]@{ State = 'Ready' }
                    Triggers = @()
                }
                return @{ Success = $true; TaskId = $taskId }
            }
        }

        AfterEach {
            $script:Platform = $null
        }

        It 'Should block duplicate for same folder and date' {
            $t = (Get-Date).AddHours(2)
            New-MotivationTask -FolderPath $script:TestFolder1 -TriggerTime $t | Out-Null
            $r2 = New-MotivationTask -FolderPath $script:TestFolder1 -TriggerTime $t
            $r2.Success     | Should -Be $false
            $r2.IsDuplicate | Should -Be $true
        }

        It 'Should allow duplicate when -Force is set' {
            $t = (Get-Date).AddHours(2)
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
            $t = (Get-Date).AddHours(2)
            New-MotivationTask -FolderPath 'C:\Projects\TestFolder' -TriggerTime $t | Out-Null
            $r2 = New-MotivationTask -FolderPath 'c:\PROJECTS\testfolder' -TriggerTime $t
            $r2.IsDuplicate | Should -Be $true
        }

        It 'Should NOT block duplicate if first task status is COMPLETED' {
            # AG8-020: Negative test - COMPLETED tasks should not block new ones
            $t = (Get-Date).AddHours(2)
            New-MotivationTask -FolderPath $script:TestFolder1 -TriggerTime $t | Out-Null
            # Mark first task as COMPLETED
            $tasks = Get-TasksJson
            $tasks[0].status = 'COMPLETED'
            Save-TasksJson -Tasks $tasks
            # Should allow new task for same folder/date
            $r2 = New-MotivationTask -FolderPath $script:TestFolder1 -TriggerTime $t
            $r2.Success | Should -Be $true
            $r2.IsDuplicate | Should -Be $false
        }

        It 'Should not flag as duplicate when same folder is scheduled at 23:59:59 and 00:00:01 the next day' {
            # AG8-020: Negative test - 23:59:59 vs 00:00:01 next day
            $t1 = (Get-Date).Date.AddHours(23).AddMinutes(59).AddSeconds(59)
            $t2 = (Get-Date).Date.AddDays(1).AddSeconds(1)
            New-MotivationTask -FolderPath $script:TestFolder1 -TriggerTime $t1 | Out-Null
            $r2 = New-MotivationTask -FolderPath $script:TestFolder1 -TriggerTime $t2
            # Different dates, should not be duplicate
            $r2.IsDuplicate | Should -Be $false
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

    Context 'Edge cases - Path handling' {
        It 'Should not crash on very long folder paths (AG8-013)' {
            # Windows path limit is ~260 chars, task name limit is 238
            $longPath = 'C:\' + ('VeryLongFolderName' * 15)  # ~285 characters
            $result = New-MotivationTask -FolderPath $longPath -TriggerTime ((Get-Date).AddHours(2))
            # Should either succeed or fail gracefully (not crash)
            $result | Should -Not -BeNullOrEmpty
            if ($result.Success) {
                # If successful, task name should be within limits
                $task = @(Get-TasksJson)[0]
                $task.task_name.Length | Should -BeLessOrEqual 238
            }
        }

        It 'Should handle paths with quotes (AG8-014)' {
            $quotePath = 'C:\My "Special" Folder'
            $result = New-MotivationTask -FolderPath $quotePath -TriggerTime ((Get-Date).AddHours(2))
            $result.Success | Should -Be $true
            # Verify JSON round-trip doesn't corrupt the path
            $task = @(Get-TasksJson)[0]
            $task.folder_path | Should -Be $quotePath
        }

        It 'Should handle paths with Unicode characters (AG8-014)' {
            $unicodePath = 'C:\Café\Résumé\Naïve'
            $result = New-MotivationTask -FolderPath $unicodePath -TriggerTime ((Get-Date).AddHours(2))
            $result.Success | Should -Be $true
            $task = @(Get-TasksJson)[0]
            $task.folder_path | Should -Be $unicodePath
        }

        It 'Should handle paths with pipe characters (AG8-014)' {
            # Pipes are delimiters in Write-OutcomeLog - ensure proper escaping
            $pipePath = 'C:\Project|A|B'
            $result = New-MotivationTask -FolderPath $pipePath -TriggerTime ((Get-Date).AddHours(2))
            $result.Success | Should -Be $true
            $task = @(Get-TasksJson)[0]
            $task.folder_path | Should -Be $pipePath
        }

        It 'Should handle paths with trailing backslash (AG8-014)' {
            $trailingSlashPath = 'C:\Projects\MyFolder\'
            $result = New-MotivationTask -FolderPath $trailingSlashPath -TriggerTime ((Get-Date).AddHours(2))
            $result.Success | Should -Be $true
        }
    }

    Context 'Collision detection retry loop' {
        # AG8-004: Test that the retry loop actually executes when the first task name collides.
        # The mock returns a fake task on the first call (simulating collision), then $null.
        It 'Should retry and generate a new task ID on task name collision' {
            $script:callCount = 0
            Mock Get-ScheduledTask {
                $script:callCount++
                if ($script:callCount -eq 1) {
                    # Simulate collision  -  task already exists
                    return [PSCustomObject]@{ TaskName = 'DailyMotivation_collision' }
                }
                return $null  # Second call: no collision, new ID is unique
            }
            $result = New-MotivationTask -FolderPath $script:TestFolder1 -TriggerTime ((Get-Date).AddHours(2))
            $result.Success | Should -Be $true
            $script:callCount | Should -BeGreaterOrEqual 2  # retry loop executed
        }

        # AG5-025: Collision retry loop should sleep between attempts to avoid CPU spinning
        It 'Should sleep between collision retry attempts (AG5-025)' {
            $startTime = Get-Date
            $script:callCount = 0
            Mock Get-ScheduledTask {
                $script:callCount++
                # Simulate 3 collisions before success
                if ($script:callCount -le 3) {
                    return [PSCustomObject]@{ TaskName = 'DailyMotivation_collision' }
                }
                return $null
            }
            $result = New-MotivationTask -FolderPath $script:TestFolder1 -TriggerTime ((Get-Date).AddHours(2))
            $duration = ((Get-Date) - $startTime).TotalMilliseconds
            # Should have slept at least 100ms per retry (3 retries = 300ms minimum)
            $duration | Should -BeGreaterThan 150
            $result.Success | Should -Be $true
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

    Context 'Task Principal configuration' {
        It 'Should use Interactive LogonType for per-user desktop session' {
            # Verify that task principal is configured correctly
            Mock New-ScheduledTaskPrincipal {
                param($UserId, $LogonType, $RunLevel)
                # Verify LogonType is Interactive
                $LogonType | Should -Be 'Interactive'
                return [PSCustomObject]@{ UserId = $UserId; LogonType = $LogonType; RunLevel = $RunLevel }
            }
            $result = New-MotivationTask -FolderPath $script:TestFolder1 -TriggerTime ((Get-Date).AddHours(2))
            Should -Invoke New-ScheduledTaskPrincipal -Times 1
        }

        AfterEach {
            # Restore default mock
            Mock New-ScheduledTaskPrincipal {
                param($UserId, $LogonType, $RunLevel)
                return [PSCustomObject]@{ UserId = $UserId; LogonType = $LogonType; RunLevel = $RunLevel }
            }
        }
    }

    Context 'Task action path validation (AG5-005, AG5-023)' {
        BeforeEach {
            $script:OriginalExePath = $script:ExePath
        }

        It 'Should reject <Description> executable path' -ForEach @(
            @{ ExePath = '';                             ErrorPattern = 'executable path'; Description = 'empty' }
            @{ ExePath = 'C:\Test\DailyMotivation.ps1'; ErrorPattern = '\.exe';           Description = 'non-.exe' }
            @{ ExePath = 'DailyMotivation.exe';          ErrorPattern = 'absolute';        Description = 'relative' }
        ) {
            $script:ExePath = $ExePath
            $result = New-MotivationTask -FolderPath $script:TestFolder1 -TriggerTime ((Get-Date).AddHours(2))
            $result.Success | Should -Be $false
            $result.Error   | Should -Match $ErrorPattern
        }

        AfterEach {
            $script:ExePath = $script:OriginalExePath
        }
    }

    Context 'Trigger time validation (AG5-007)' {
        It 'Should handle <Description> (AG5-007)' -ForEach @(
            @{ OffsetHours = -1;    ShouldSucceed = $false; ErrorPattern = 'future';  Description = 'past time' }
            @{ OffsetHours = 87600; ShouldSucceed = $false; ErrorPattern = '4 years'; Description = 'far-future time' }
            @{ OffsetHours = 24;    ShouldSucceed = $true;  ErrorPattern = '';        Description = 'valid future time' }
        ) {
            $triggerTime = (Get-Date).AddHours($OffsetHours)
            $result = New-MotivationTask -FolderPath $script:TestFolder1 -TriggerTime $triggerTime
            if (-not $ShouldSucceed) {
                $result.Success | Should -Be $false
                $result.Error   | Should -Match $ErrorPattern
            } else {
                $result.Success | Should -Be $true
            }
        }
    }

    Context 'Trigger timing parameters passed to Register-ScheduledTask (AG20-011)' {
        # Override the global mock to also capture $Settings for inspection.
        BeforeAll {
            $script:CapturedSettings = $null
            Mock Register-ScheduledTask -Verifiable {
                param($TaskName, $Action, $Trigger, $Settings, $Principal, $Description, [switch]$Force)
                $script:MockedTasks[$TaskName] = [PSCustomObject]@{
                    TaskName = $TaskName
                    State    = [PSCustomObject]@{ State = 'Ready' }
                    Triggers = @($Trigger)
                    Settings = $Settings
                }
                $script:CapturedSettings = $Settings
                return $null
            }
        }

        AfterAll {
            # Restore the global mock
            Mock Register-ScheduledTask -Verifiable {
                param($TaskName, $Action, $Trigger, $Settings, $Principal, $Description, [switch]$Force)
                $script:MockedTasks[$TaskName] = [PSCustomObject]@{
                    TaskName = $TaskName
                    State    = [PSCustomObject]@{ State = 'Ready' }
                    Triggers = @($Trigger)
                }
                return $null
            }
        }

        It 'Should pass StartBoundary matching TriggerTime to Register-ScheduledTask' {
            # [datetime]::new() produces exact second-boundary values (no sub-second ticks).
            # Get-Date -Second 0 retains sub-second ticks from the current clock, which
            # would cause a mismatch because StartBoundary is second-precision only.
            $triggerTime = [datetime]::new(2026, 12, 25, 14, 0, 0)
            $result = New-MotivationTask -FolderPath $script:TestFolder1 -TriggerTime $triggerTime
            $result.Success | Should -Be $true

            $taskName        = "DailyMotivation_$($result.TaskId)"
            $capturedTrigger = $script:MockedTasks[$taskName].Triggers[0]
            $capturedTrigger | Should -Not -BeNullOrEmpty

            # New-ScheduledTaskTrigger stores StartBoundary as ISO 8601, either in
            # local time ('2026-12-25T14:00:00') or UTC ('2026-12-25T20:00:00Z').
            # Parse with RoundtripKind and normalise both sides to UTC before comparing.
            $stored = [datetime]::Parse(
                $capturedTrigger.StartBoundary,
                [System.Globalization.CultureInfo]::InvariantCulture,
                [System.Globalization.DateTimeStyles]::RoundtripKind)
            $storedUtc   = if ($stored.Kind -eq [System.DateTimeKind]::Utc) { $stored } else { $stored.ToUniversalTime() }
            $expectedUtc = $triggerTime.ToUniversalTime()
            $storedUtc | Should -Be $expectedUtc
        }

        It 'Should set EndBoundary 31 minutes after TriggerTime' {
            # [datetime]::new() avoids sub-second tick mismatch (see StartBoundary test).
            $triggerTime = [datetime]::new(2026, 12, 25, 14, 0, 0)

            $result = New-MotivationTask -FolderPath $script:TestFolder1 -TriggerTime $triggerTime
            $result.Success | Should -Be $true

            $taskName        = "DailyMotivation_$($result.TaskId)"
            $capturedTrigger = $script:MockedTasks[$taskName].Triggers[0]

            $stored = [datetime]::Parse(
                $capturedTrigger.EndBoundary,
                [System.Globalization.CultureInfo]::InvariantCulture,
                [System.Globalization.DateTimeStyles]::RoundtripKind)
            $storedUtc   = if ($stored.Kind -eq [System.DateTimeKind]::Utc) { $stored } else { $stored.ToUniversalTime() }
            $expectedUtc = $triggerTime.AddMinutes(31).ToUniversalTime()
            $storedUtc | Should -Be $expectedUtc
        }

        It 'Should pass a non-null Settings object to Register-ScheduledTask' {
            $result = New-MotivationTask -FolderPath $script:TestFolder1 -TriggerTime ((Get-Date).AddHours(2))
            $result.Success | Should -Be $true
            $script:CapturedSettings | Should -Not -BeNullOrEmpty
        }

        It 'Should pass StartWhenAvailable=true in task settings' {
            $result = New-MotivationTask -FolderPath $script:TestFolder1 -TriggerTime ((Get-Date).AddHours(2))
            $result.Success | Should -Be $true
            # Inspect via Register-ScheduledTask -ParameterFilter
            Should -Invoke Register-ScheduledTask -Times 1 -ParameterFilter {
                $Settings.StartWhenAvailable -eq $true
            }
        }
    }
}

Describe 'Get-MotivationTasks' -Skip:(-not $IsWindows) {
    BeforeEach {
        # Use $script:TasksPath directly to ensure we're writing to the same path that Get-TasksJson reads from
        if (-not (Test-Path (Split-Path $script:TasksPath -Parent))) {
            New-Item -ItemType Directory -Path (Split-Path $script:TasksPath -Parent) -Force | Out-Null
        }
        '[]' | Set-Content $script:TasksPath -Encoding UTF8 -Force
        $script:MockedTasks = @{}

        # Inject platform adapter to prevent Sync-TaskStatuses from interfering with Get-MotivationTasks tests.
        # ScriptMethod is required because DailyMotivation.ps1 calls via method-invocation syntax.
        $script:Platform = [PSCustomObject]@{}
        $script:Platform | Add-Member -MemberType ScriptMethod -Name 'ScheduleTask' -Value {
            param($config)
            $taskId = [System.Guid]::NewGuid().ToString("N").Substring(0, 16)
            $taskName = "DailyMotivation_$taskId"
            # Directly insert into MockedTasks  -  ScriptMethods bypass Pester mock scope.
            $script:MockedTasks[$taskName] = [PSCustomObject]@{
                TaskName = $taskName
                State    = [PSCustomObject]@{ State = 'Ready' }
                Triggers = @()
            }
            return @{ Success = $true; TaskId = $taskId }
        }
        $script:Platform | Add-Member -MemberType ScriptMethod -Name 'UnscheduleTask' -Value {
            param($taskId)
            $taskName = "DailyMotivation_$taskId"
            if ($script:MockedTasks.ContainsKey($taskName)) {
                $script:MockedTasks.Remove($taskName)
            }
        }
    }

    AfterEach {
        # Reset platform adapter so other tests aren't affected
        $script:Platform = $null
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

        # AG8-025: Strict property validation (not just -Not -BeNullOrEmpty)
        # Verify task_id is hexadecimal GUID format (16 chars)
        $task.task_id        | Should -Not -BeNullOrEmpty
        $task.task_id        | Should -Match '^[a-f0-9]{16}$' -Because "task_id should be 16-char hex string"
        $task.task_id.Length | Should -BeExactly 16

        # Verify task_name follows naming convention
        $task.task_name      | Should -Match '^DailyMotivation_[a-f0-9]{16}$'

        # Verify paths are not just spaces or empty strings
        $task.folder_path    | Should -Not -BeNullOrEmpty
        $task.folder_path.Trim() | Should -Not -BeExactly '' -Because "folder_path must not be whitespace only"

        $task.folder_name    | Should -Not -BeNullOrEmpty
        $task.folder_name.Trim() | Should -Not -BeExactly ''

        # Verify scheduled_time is a valid DateTime (not string)
        $task.scheduled_time | Should -Not -BeNullOrEmpty
        $task.scheduled_time | Should -BeOfType [DateTime] -Because "scheduled_time must deserialize to DateTime"

        # Verify status is one of known valid values
        $task.status         | Should -BeIn @('PENDING', 'COMPLETED', 'DELETED') -Because "status must be valid enum value"

        # Verify snooze_count is non-negative integer
        $task.snooze_count.GetType().Name | Should -BeIn @('Int32', 'Int64')
        $task.snooze_count   | Should -BeGreaterOrEqual 0 -Because "snooze_count cannot be negative"
    }

    It 'Should return an empty collection when tasks.json contains invalid JSON' {
        # AG8-002: Verify return value, not just that the function doesn't throw.
        # Must return an empty array (not $null or garbage) on corrupt input.
        'invalid json{' | Set-Content (Join-Path $env:APPDATA 'DailyMotivationBrainHelper\tasks.json') -Encoding UTF8
        { Get-MotivationTasks } | Should -Not -Throw
        $result = @(Get-MotivationTasks)
        Should -Not -Be $null -ActualValue $result
        $result.Count | Should -Be 0
    }
}

Describe 'Remove-MotivationTask' -Skip:(-not $IsWindows) {
    BeforeEach {
        # Use $script:TasksPath directly to ensure we're writing to the same path that Get-TasksJson reads from
        if (-not (Test-Path (Split-Path $script:TasksPath -Parent))) {
            New-Item -ItemType Directory -Path (Split-Path $script:TasksPath -Parent) -Force | Out-Null
        }
        '[]' | Set-Content $script:TasksPath -Encoding UTF8 -Force
        $script:MockedTasks = @{}
        # No Platform adapter here: use the real Windows path so that
        # Unregister-ScheduledTask goes through the Pester mock (BeforeAll scope)
        # and both task removal and -Invoke assertions work correctly.
        $script:Platform = $null
    }

    AfterEach {
        $script:Platform = $null
    }

    It 'Should remove the specified task from tasks.json' {
        $r = New-MotivationTask -FolderPath $script:TestFolder1 -TriggerTime ((Get-Date).AddHours(2))
        $taskName = (Get-TasksJson)[0].task_name
        Remove-MotivationTask -TaskId $r.TaskId
        @(Get-TasksJson).Count | Should -Be 0
        # AG8-003: Verify Unregister-ScheduledTask was called with correct TaskName
        Should -Invoke Unregister-ScheduledTask -Times 1 -ParameterFilter {
            $TaskName -eq $taskName
        }
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

