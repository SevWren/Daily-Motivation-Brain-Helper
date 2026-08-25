#Requires -Modules Pester
<#
.SYNOPSIS
    Integration tests for DailyMotivation.ps1 single-file architecture.
    Verifies: dot-source loads without error, all required functions are defined,
    Initialize-AppData creates the expected directory structure,
    and the three execution modes are reachable.
#>

BeforeAll {
    $script:RepoRoot       = Join-Path $PSScriptRoot '..\..'
    $script:ScriptPath     = Join-Path $script:RepoRoot 'DailyMotivation.ps1'
    $script:OriginalAppData = $env:APPDATA
    $env:APPDATA = Join-Path ([System.IO.Path]::GetTempPath()) "DMBH_Integration_$(New-Guid)"

    # Dot-source the script without executing the entry point
    . $script:ScriptPath -NoRun

    Initialize-AppData
    $script:AppDir = Join-Path $env:APPDATA 'DailyMotivationBrainHelper'
}

AfterAll {
    if (Test-Path $env:APPDATA) {
        Remove-Item -Path $env:APPDATA -Recurse -Force -ErrorAction SilentlyContinue
    }
    $env:APPDATA = $script:OriginalAppData
}

Describe 'Single-File Dot-Source' {
    It 'DailyMotivation.ps1 should exist at repo root' {
        Test-Path $script:ScriptPath | Should -Be $true
    }

    It 'Should dot-source without errors using -NoRun' {
        # BeforeAll already succeeded if we reached this point;
        # this assertion makes failure explicit.
        $script:ScriptPath | Should -Not -BeNullOrEmpty
        { . $script:ScriptPath -NoRun } | Should -Not -Throw
    }
}

Describe 'Required Functions Defined After Dot-Source' {
    $requiredFunctions = @(
        'Initialize-AppData',
        'Get-Config',
        'Save-Config',
        'Get-PopupConfig',
        'Set-PopupConfig',
        'Write-OutcomeLog',
        'Show-ErrorDialog',
        'Get-TasksJson',
        'Save-TasksJson',
        'New-MotivationTask',
        'Get-MotivationTasks',
        'Remove-MotivationTask',
        'Register-ContextMenu',
        'Unregister-ContextMenu',
        'Get-RandomMessage'
    )

    It "Function '<_>' should be defined" -ForEach $requiredFunctions {
        (Get-Command -Name $_ -ErrorAction SilentlyContinue) | Should -Not -BeNullOrEmpty
    }
}

Describe 'Initialize-AppData Directory Structure' {
    It 'Should create the DailyMotivationBrainHelper directory' {
        Test-Path $script:AppDir | Should -Be $true
    }

    It 'Should create config.json' {
        Test-Path (Join-Path $script:AppDir 'config.json') | Should -Be $true
    }

    It 'Should create popup_config.json' {
        Test-Path (Join-Path $script:AppDir 'popup_config.json') | Should -Be $true
    }

    It 'Should create tasks.json' {
        Test-Path (Join-Path $script:AppDir 'tasks.json') | Should -Be $true
    }

    It 'config.json should be valid JSON with required keys' {
        $cfg = Get-Content (Join-Path $script:AppDir 'config.json') -Raw | ConvertFrom-Json
        $cfg.PSObject.Properties.Name | Should -Contain 'default_trigger_hour'
        $cfg.PSObject.Properties.Name | Should -Contain 'task_warning_threshold'
    }

    It 'tasks.json should start as an empty array' {
        (Get-Content (Join-Path $script:AppDir 'tasks.json') -Raw).Trim() | Should -Be '[]'
    }
}

Describe 'Get-RandomMessage returns a valid message' {
    It 'Should return an object with glyph, title, body' {
        $msg = Get-RandomMessage
        $msg.glyph | Should -Not -BeNullOrEmpty
        $msg.title | Should -Not -BeNullOrEmpty
        $msg.body  | Should -Not -BeNullOrEmpty
    }
}

Describe 'Write-OutcomeLog creates the log file' {
    It 'Should write a log entry to popup_log.txt' {
        Write-OutcomeLog -TaskId 'intg-t1' -FolderName 'TestFolder' `
            -FolderPath 'C:\Test\Folder' -Outcome 'Opened' -SnoozeCount 0
        $logPath = Join-Path $script:AppDir 'popup_log.txt'
        Test-Path $logPath | Should -Be $true
        (Get-Content $logPath -Raw) | Should -Match 'intg-t1'
    }
}

Describe 'Mode switching and config persistence (AG8-026)' {
    # AG8-026: Integration tests for config persistence across execution modes

    BeforeEach {
        # Clean config state
        $script:AppDir = Join-Path $env:APPDATA 'DailyMotivationBrainHelper'
        if (Test-Path $script:AppDir) {
            Remove-Item -Path $script:AppDir -Recurse -Force
        }
        Initialize-AppData
    }

    It 'Should persist popup config written by main mode for popup mode to read' {
        # Simulate main mode writing popup_config.json
        $testConfig = @{
            folder_path = 'C:\TestFolder'
            folder_name = 'TestFolder'
            message_glyph = '[!]'
            message_title = 'Test Title'
            message_body = 'Test Body'
        }
        Set-PopupConfig -FolderPath $testConfig.folder_path `
            -FolderName $testConfig.folder_name `
            -Glyph $testConfig.message_glyph `
            -Title $testConfig.message_title `
            -Body $testConfig.message_body

        # Verify file was written
        $popupConfigPath = Join-Path $script:AppDir 'popup_config.json'
        Test-Path $popupConfigPath | Should -Be $true

        # Simulate popup mode reading config
        $readConfig = Get-PopupConfig
        $readConfig | Should -Not -Be $null
        $readConfig.folder_path | Should -Be $testConfig.folder_path
        $readConfig.message_title | Should -Be $testConfig.message_title
    }

    It 'Should verify config.json persists default settings across reads' {
        # Write config
        Save-Config -DefaultTriggerHour 15 -TaskWarningThreshold 7

        # Read config
        $cfg = Get-Config
        $cfg.default_trigger_hour | Should -Be 15
        $cfg.task_warning_threshold | Should -Be 7

        # Verify persistence: re-read from disk
        $cfg2 = Get-Config
        $cfg2.default_trigger_hour | Should -Be 15
        $cfg2.task_warning_threshold | Should -Be 7
    }

    It 'Should verify tasks.json persists across mode switches' -Skip:(-not $IsWindows) {
        # AG8-007: let real helper cmdlets run, only mock Register/Unregister/Get-ScheduledTask
        # Register returns task object (AG5-001 verification uses return value)
        Mock Register-ScheduledTask {
            param($TaskName, $Action, $Trigger, $Settings, $Principal, $Description, [switch]$Force)
            return [PSCustomObject]@{ TaskName = $TaskName; State = 'Ready' }
        }
        Mock Get-ScheduledTask {
            param($TaskName)
            if ($TaskName -eq "DailyMotivation_*") { return @() }
            return $null
        }
        Mock Unregister-ScheduledTask {
            param($TaskName, $Confirm)
        }
        $script:ExePath = 'C:\Test\DailyMotivation.exe'

        $result = New-MotivationTask -FolderPath 'C:\TestFolder' -TriggerTime ((Get-Date).AddHours(2))
        $result.Success | Should -Be $true

        # Verify task persists
        $tasks1 = Get-MotivationTasks
        $tasks1.Count | Should -Be 1

        # Simulate setfolder mode reading tasks
        $tasks2 = Get-MotivationTasks
        $tasks2.Count | Should -Be 1
        $tasks2[0].task_id | Should -Be $result.TaskId
    }
}

Describe 'Integration scenario - Full lifecycle (AG8-007)' -Skip:(-not $IsWindows) {
    # AG8-007: Expanded integration tests covering actual integration scenarios
    # Windows-only: Requires Task Scheduler cmdlets

    BeforeEach {
        # AG8-007: mock only Task Scheduler persistence cmdlets.
        # Register returns task object (AG5-001 verification uses return value, not Get-ScheduledTask).
        Mock Register-ScheduledTask {
            param($TaskName, $Action, $Trigger, $Settings, $Principal, $Description, [switch]$Force)
            return [PSCustomObject]@{ TaskName = $TaskName; State = 'Ready'; Triggers = @($Trigger) }
        }
        Mock Unregister-ScheduledTask {
            param($TaskName, $Confirm)
        }
        Mock Get-ScheduledTask {
            param($TaskName)
            if ($TaskName -eq "DailyMotivation_*") { return @() }
            return $null
        }
        $script:ExePath = 'C:\Test\DailyMotivation.exe'

        $script:AppDir = Join-Path $env:APPDATA 'DailyMotivationBrainHelper'
        if (Test-Path $script:AppDir) {
            Remove-Item -Path $script:AppDir -Recurse -Force
        }
        Initialize-AppData
    }

    It 'Should complete full task lifecycle: create, list, remove' {
        # Create task
        $result = New-MotivationTask -FolderPath 'C:\Projects\TestApp' -TriggerTime ((Get-Date).AddHours(3))
        $result.Success | Should -Be $true
        $taskId = $result.TaskId

        # List tasks
        $tasks = @(Get-MotivationTasks)
        $tasks.Count | Should -Be 1
        $tasks[0].task_id | Should -Be $taskId

        # Remove task
        Remove-MotivationTask -TaskId $taskId

        # Verify removed
        $tasks = @(Get-MotivationTasks)
        $tasks.Count | Should -Be 0
    }

    It 'Should handle duplicate detection across task operations' {
        # Use relative time to ensure it's always in the future
        $triggerTime = (Get-Date).AddHours(2)

        # Create first task
        $r1 = New-MotivationTask -FolderPath 'C:\TestFolder' -TriggerTime $triggerTime
        $r1.Success | Should -Be $true

        # Attempt duplicate
        $r2 = New-MotivationTask -FolderPath 'C:\TestFolder' -TriggerTime $triggerTime
        $r2.Success | Should -Be $false
        $r2.IsDuplicate | Should -Be $true

        # Verify only one task exists
        $tasks = @(Get-MotivationTasks)
        $tasks.Count | Should -Be 1
    }
}
