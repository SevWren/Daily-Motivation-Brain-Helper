#Requires -Modules Pester
<#
.SYNOPSIS
    Tests for platform-aware task scheduling

.DESCRIPTION
    Tests that New-MotivationTask works with HeadlessPlatform on Linux.
    Per architecture-report.html Candidate 3.
#>

BeforeAll {
    # Dot-source the script with -NoRun
    . "$PSScriptRoot\..\..\DailyMotivation.ps1" -NoRun

    # Redirect to test temp directory
    $script:TestAppData = Join-Path ([System.IO.Path]::GetTempPath()) "DailyMotivationTest_$(New-Guid)"
    $env:APPDATA = $script:TestAppData
}

AfterAll {
    # Cleanup test directory
    if (Test-Path $script:TestAppData) {
        Remove-Item -Path $script:TestAppData -Recurse -Force -ErrorAction SilentlyContinue
    }
}

BeforeEach {
    if (Test-Path $script:TestAppData) {
        Remove-Item -Path $script:TestAppData -Recurse -Force -ErrorAction SilentlyContinue
    }
    $script:Platform = [HeadlessPlatform]::new()
    Initialize-AppData
    Set-Content -Path $script:TasksPath -Value "[]" -Encoding UTF8 -NoNewline
    $script:ExePath = "/usr/local/bin/DailyMotivation.exe"
}

Describe "New-MotivationTask with platform adapter" -Tag "Unit", "TaskScheduler", "Platform" {

    Context "When platform adapter is injected" {
        It "creates a task without calling Windows Task Scheduler API" {
            # This will fail until New-MotivationTask uses platform adapter
            $result = New-MotivationTask -FolderPath "/tmp/test-folder" -TriggerTime (Get-Date).AddHours(1)

            $result.Success | Should -Be $true
            $result.TaskId | Should -Not -BeNullOrEmpty
            $result.TaskId | Should -BeLike "headless-mock-*"
        }

        It "saves task to tasks.json with mock task ID" {
            $result = New-MotivationTask -FolderPath "/tmp/test-folder" -TriggerTime (Get-Date).AddHours(1)

            # Debug: check what result contains
            $result | Should -Not -BeNullOrEmpty
            $result.Success | Should -Be $true
            $result.TaskId | Should -Not -BeNullOrEmpty

            $tasks = Get-TasksJson
            $tasks.Count | Should -Be 1
            $tasks[0].task_id | Should -Not -BeNullOrEmpty
            $tasks[0].task_id | Should -Be $result.TaskId
            $tasks[0].folder_path | Should -Be "/tmp/test-folder"
            $tasks[0].status | Should -Be "PENDING"
        }

        It "New-MotivationTask does not throw when Register-ScheduledTask cmdlet is absent (Linux / HeadlessPlatform)" {
            # On Linux, Register-ScheduledTask doesn't exist
            # Platform adapter should handle this gracefully
            { New-MotivationTask -FolderPath "/tmp/test" -TriggerTime (Get-Date).AddHours(1) } | Should -Not -Throw
        }
    }
}

Describe "Remove-MotivationTask with platform adapter" -Tag "Unit", "TaskScheduler", "Platform" {

    BeforeEach {
        $result = New-MotivationTask -FolderPath "/tmp/test-folder" -TriggerTime (Get-Date).AddHours(1)
        $script:TestTaskId = $result.TaskId
    }

    Context "When platform adapter is injected" {
        It "removes task without calling Windows Task Scheduler API" {
            # This will fail until Remove-MotivationTask uses platform adapter
            { Remove-MotivationTask -TaskId $script:TestTaskId } | Should -Not -Throw
        }

        It "removes task from tasks.json" {
            Remove-MotivationTask -TaskId $script:TestTaskId

            $tasks = Get-TasksJson
            $tasks | Where-Object { $_.task_id -eq $script:TestTaskId } | Should -BeNullOrEmpty
        }
    }
}
