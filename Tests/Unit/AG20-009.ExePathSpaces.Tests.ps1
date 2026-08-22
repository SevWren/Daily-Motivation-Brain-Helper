#Requires -Modules @{ ModuleName='Pester'; ModuleVersion='5.0.0' }
<#
.SYNOPSIS
    AG20-009: Verify that New-MotivationTask passes an ExePath containing spaces
    to New-ScheduledTaskAction verbatim (no extra quoting applied by the caller).
.NOTES
    Windows-only — Task Scheduler cmdlets do not exist on Linux.
    The -Execute parameter of New-ScheduledTaskAction is designed to receive
    the bare executable path; Task Scheduler wraps it internally when building
    the command line. DailyMotivation.ps1 must NOT double-quote the path before
    passing it, because that would break the action on Windows.
#>

BeforeAll {
    if (-not $IsWindows) {
        Write-Host "Skipping AG20-009 - Windows Task Scheduler required" -ForegroundColor Yellow
        return
    }

    . (Join-Path $PSScriptRoot '..\..\DailyMotivation.ps1') -NoRun

    $script:OriginalAppData = $env:APPDATA
    $env:APPDATA = Join-Path ([System.IO.Path]::GetTempPath()) "DMBH_ExePath_Test_$(New-Guid)"
    Initialize-AppData

    # Capture every call to New-ScheduledTaskAction so tests can inspect arguments.
    # ExePath is only set inside `if (-not $NoRun)` in DailyMotivation.ps1,
    # so it is never assigned when dot-sourcing with -NoRun. Initialize it to $null
    # so that BeforeEach can safely save/restore it under Set-StrictMode -Version Latest.
    $script:ExePath = $null

    # New-ScheduledTaskAction/Trigger/Settings/Principal are native Windows cmdlets that return real
    # CimInstances. Mocking any of them with PSCustomObjects and -RemoveParameterValidation fails
    # because that flag strips ValidateXxx attributes only — NOT type constraints.
    # Let all helper cmdlets run for real.
    #
    # Capture Execute/Arguments from Register-ScheduledTask instead: the real CIM action object
    # has .Execute and .Arguments properties that reflect exactly what DailyMotivation.ps1 passed.
    $script:CapturedRegistrations = @()
    $script:MockedTasks = @{}
    Mock Register-ScheduledTask {
        param($TaskName, $Action, $Trigger, $Settings, $Principal, $Description, [switch]$Force)
        $script:CapturedRegistrations += [PSCustomObject]@{
            ActionExecute   = $Action.Execute
            ActionArguments = $Action.Arguments
        }
        $script:MockedTasks[$TaskName] = [PSCustomObject]@{ TaskName = $TaskName }
        return $null
    }
    Mock Get-ScheduledTask {
        param($TaskName, $ErrorAction)
        if ($TaskName -eq 'DailyMotivation_*') { return @($script:MockedTasks.Values) }
        if ($script:MockedTasks.ContainsKey($TaskName)) {
            return $script:MockedTasks[$TaskName]
        }
        return $null
    }
    Mock Unregister-ScheduledTask {}
}

AfterAll {
    if ($IsWindows -and (Test-Path $env:APPDATA)) {
        Remove-Item -Path $env:APPDATA -Recurse -Force -ErrorAction SilentlyContinue
    }
    if ($IsWindows) {
        $env:APPDATA = $script:OriginalAppData
    }
}

Describe 'AG20-009 — ExePath with spaces in New-MotivationTask' -Skip:(-not $IsWindows) {

    BeforeEach {
        # Reset captured registrations and mocked task registry for each test.
        $script:CapturedRegistrations = @()
        $script:MockedTasks           = @{}

        # Reset tasks.json to empty so duplicate-detection does not interfere.
        '[]' | Set-Content $script:TasksPath -Encoding UTF8 -Force

        # Override ExePath to a path that contains spaces — the core of this issue.
        $script:ExePath = 'C:\Program Files\Daily Motivation\DailyMotivation.exe'
    }

    Context 'New-ScheduledTaskAction -Execute argument' {

        It 'Should register exactly one scheduled task when ExePath contains spaces' {
            # Verified via Register-ScheduledTask capture: exactly one registration means
            # New-ScheduledTaskAction was called exactly once.
            New-MotivationTask -FolderPath 'C:\Projects\TestFolder' `
                               -TriggerTime ((Get-Date).AddHours(2)) | Out-Null

            $script:CapturedRegistrations.Count | Should -Be 1 `
                -Because 'New-MotivationTask should register exactly one task action'
        }

        It 'Should pass ExePath verbatim (no added quotes) as the -Execute parameter' {
            # Task Scheduler handles path-with-spaces quoting internally;
            # the caller must NOT wrap the path in extra double-quotes.
            # Verified via the .Execute property of the real CIM action object.
            $expectedExePath = 'C:\Program Files\Daily Motivation\DailyMotivation.exe'

            New-MotivationTask -FolderPath 'C:\Projects\TestFolder' `
                               -TriggerTime ((Get-Date).AddHours(2)) | Out-Null

            $script:CapturedRegistrations[0].ActionExecute | Should -Be $expectedExePath
        }

        It 'Should not wrap the ExePath in double-quote characters' {
            New-MotivationTask -FolderPath 'C:\Projects\TestFolder' `
                               -TriggerTime ((Get-Date).AddHours(2)) | Out-Null

            $passedExecute = $script:CapturedRegistrations[0].ActionExecute
            # The string must not start and end with a double-quote character.
            $passedExecute | Should -Not -Match '^".*"$' `
                -Because 'New-ScheduledTaskAction -Execute must receive a bare path, not a shell-quoted string'
        }

        It 'Should pass /popup as the -Argument parameter regardless of spaces in ExePath' {
            New-MotivationTask -FolderPath 'C:\Projects\TestFolder' `
                               -TriggerTime ((Get-Date).AddHours(2)) | Out-Null

            # .Arguments is the CIM property name corresponding to New-ScheduledTaskAction -Argument
            $script:CapturedRegistrations[0].ActionArguments | Should -Be '/popup'
        }
    }

    Context 'Task persistence when ExePath contains spaces' {

        It 'Should return Success = $true for a valid folder path' {
            $result = New-MotivationTask -FolderPath 'C:\Projects\TestFolder' `
                                         -TriggerTime ((Get-Date).AddHours(2))

            $result.Success | Should -Be $true
        }

        It 'Should persist one task record to tasks.json' {
            New-MotivationTask -FolderPath 'C:\Projects\TestFolder' `
                               -TriggerTime ((Get-Date).AddHours(2)) | Out-Null

            @(Get-TasksJson).Count | Should -Be 1
        }

        It 'Should set task_name to DailyMotivation_ followed by a 16-char hex id' {
            New-MotivationTask -FolderPath 'C:\Projects\TestFolder' `
                               -TriggerTime ((Get-Date).AddHours(2)) | Out-Null

            $task = @(Get-TasksJson)[0]
            $task.task_name | Should -Match '^DailyMotivation_[a-f0-9]{16}$'
        }

        It 'Should set status to PENDING' {
            New-MotivationTask -FolderPath 'C:\Projects\TestFolder' `
                               -TriggerTime ((Get-Date).AddHours(2)) | Out-Null

            @(Get-TasksJson)[0].status | Should -Be 'PENDING'
        }

        It 'Should return a TaskId that matches the task_name suffix in tasks.json' {
            $result = New-MotivationTask -FolderPath 'C:\Projects\TestFolder' `
                                         -TriggerTime ((Get-Date).AddHours(2))

            $task = @(Get-TasksJson)[0]
            $task.task_name | Should -Be "DailyMotivation_$($result.TaskId)"
        }
    }

    Context 'Validation still rejects invalid exe paths when path contains spaces' {

        It 'Should return Success = $false for an empty ExePath even if it previously had spaces' {
            $script:ExePath = ''
            $result = New-MotivationTask -FolderPath 'C:\Projects\TestFolder' `
                                         -TriggerTime ((Get-Date).AddHours(2))
            $result.Success | Should -Be $false
            $result.Error   | Should -Match 'executable path'
        }

        It 'Should return Success = $false for a non-exe path that contains spaces' {
            $script:ExePath = 'C:\Program Files\Daily Motivation\DailyMotivation.ps1'
            $result = New-MotivationTask -FolderPath 'C:\Projects\TestFolder' `
                                         -TriggerTime ((Get-Date).AddHours(2))
            $result.Success | Should -Be $false
            $result.Error   | Should -Match '\.exe'
        }
    }
}
