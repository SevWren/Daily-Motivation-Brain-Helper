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

    $script:CapturedActions = @()
    Mock New-ScheduledTaskAction {
        param($Execute, $Argument)
        $script:CapturedActions += [PSCustomObject]@{ Execute = $Execute; Argument = $Argument }
        return [PSCustomObject]@{ Execute = $Execute; Argument = $Argument }
    }

    Mock New-ScheduledTaskTrigger {
        return [PSCustomObject]@{
            StartBoundary = ((Get-Date).AddHours(2)).ToString('yyyy-MM-ddTHH:mm:ss')
            EndBoundary   = ''
        }
    }
    Mock New-ScheduledTaskSettingsSet { return [PSCustomObject]@{} }
    Mock New-ScheduledTaskPrincipal {
        param($UserId, $LogonType, $RunLevel)
        return [PSCustomObject]@{ UserId = $UserId; LogonType = $LogonType; RunLevel = $RunLevel }
    }

    $script:MockedTasks = @{}
    # -RemoveParameterValidation bypasses CimInstance[] type enforcement on Action/Trigger/Settings/Principal
    # so PSCustomObject values from mocked New-ScheduledTask* cmdlets are accepted.
    Mock Register-ScheduledTask -RemoveParameterValidation 'Action', 'Trigger', 'Settings', 'Principal' {
        param($TaskName, $Action, $Trigger, $Settings, $Principal, $Description, [switch]$Force, $ErrorAction)
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
        # Reset captured actions and mocked task registry for each test.
        $script:CapturedActions = @()
        $script:MockedTasks     = @{}

        # Reset tasks.json to empty so duplicate-detection does not interfere.
        if (-not (Test-Path (Split-Path $script:TasksPath -Parent))) {
            New-Item -ItemType Directory -Path (Split-Path $script:TasksPath -Parent) -Force | Out-Null
        }
        '[]' | Set-Content $script:TasksPath -Encoding UTF8 -Force

        # Override ExePath to a path that contains spaces — the core of this issue.
        $script:OriginalExePath = $script:ExePath
        $script:ExePath = 'C:\Program Files\Daily Motivation\DailyMotivation.exe'
    }

    AfterEach {
        $script:ExePath = $script:OriginalExePath
    }

    Context 'New-ScheduledTaskAction -Execute argument' {

        It 'Should call New-ScheduledTaskAction exactly once when ExePath contains spaces' {
            New-MotivationTask -FolderPath 'C:\Projects\TestFolder' `
                               -TriggerTime ((Get-Date).AddHours(2)) | Out-Null

            Should -Invoke New-ScheduledTaskAction -Times 1 -Exactly
        }

        It 'Should pass ExePath verbatim (no added quotes) as the -Execute parameter' {
            # Task Scheduler handles path-with-spaces quoting internally;
            # the caller must NOT wrap the path in extra double-quotes.
            $expectedExePath = 'C:\Program Files\Daily Motivation\DailyMotivation.exe'

            New-MotivationTask -FolderPath 'C:\Projects\TestFolder' `
                               -TriggerTime ((Get-Date).AddHours(2)) | Out-Null

            $script:CapturedActions.Count | Should -Be 1
            $script:CapturedActions[0].Execute | Should -Be $expectedExePath
        }

        It 'Should not wrap the ExePath in double-quote characters' {
            New-MotivationTask -FolderPath 'C:\Projects\TestFolder' `
                               -TriggerTime ((Get-Date).AddHours(2)) | Out-Null

            $passedExecute = $script:CapturedActions[0].Execute
            # The string must not start and end with a double-quote character.
            $passedExecute | Should -Not -Match '^".*"$' `
                -Because 'New-ScheduledTaskAction -Execute must receive a bare path, not a shell-quoted string'
        }

        It 'Should pass /popup as the -Argument parameter regardless of spaces in ExePath' {
            New-MotivationTask -FolderPath 'C:\Projects\TestFolder' `
                               -TriggerTime ((Get-Date).AddHours(2)) | Out-Null

            $script:CapturedActions[0].Argument | Should -Be '/popup'
        }
    }

    Context 'Task persistence when ExePath contains spaces' {

        It 'Should return Success = $true for a valid folder path' {
            $result = New-MotivationTask -FolderPath 'C:\Projects\TestFolder' `
                                         -TriggerTime ((Get-Date).AddHours(2))

            Write-Host "AG20-009 Ctx2: Success=$($result.Success) Error='$($result['Error'])' IsDuplicate=$($result.IsDuplicate) TaskId=$($result.TaskId)"
            $result.Success | Should -Be $true
        }

        It 'Should persist one task record to tasks.json' {
            New-MotivationTask -FolderPath 'C:\Projects\TestFolder' `
                               -TriggerTime ((Get-Date).AddHours(2)) | Out-Null

            @(Get-TasksJson).Count | Should -Be 1
        }

        It 'Should set task_name to the DailyMotivation_<id> format' {
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
