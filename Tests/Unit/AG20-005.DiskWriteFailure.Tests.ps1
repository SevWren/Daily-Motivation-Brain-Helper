#Requires -Modules Pester
<#
.SYNOPSIS
    Tests for AG20-005: atomic write failure and data preservation in Save-TasksJson.

.DESCRIPTION
    Verifies the behaviour of the Save-TasksJson atomic write path when Move-Item
    fails after the .tmp file has already been written.

    Specifically tests:
      1. Pre-existing tasks.json is preserved intact when Move-Item throws.
      2. Get-TasksJson does not throw after a failed Save-TasksJson call.
      3. The .tmp scratch file is cleaned up by the catch block on failure.

    Platform-agnostic: no Task Scheduler dependency; runs on Linux and Windows.
#>

Describe 'AG20-005 — Save-TasksJson atomic write failure and data preservation' {

    BeforeAll {
        . (Join-Path $PSScriptRoot '..\..\DailyMotivation.ps1') -NoRun

        $script:OriginalAppData = $env:APPDATA
        $env:APPDATA = Join-Path ([System.IO.Path]::GetTempPath()) "DMBH_Disk_Test_$(New-Guid)"
        Initialize-AppData

        # Seed tasks.json with one known-good task so there is a pre-existing file
        # to preserve across the failure scenario.
        $script:ValidTask = [PSCustomObject]@{
            task_id        = 'original-task-001'
            task_name      = 'DailyMotivation_original-task-001'
            folder_path    = 'C:\Original'
            folder_name    = 'Original'
            scheduled_time = '2026-09-01T14:00:00'
            created_at     = (Get-Date -Format 'o')
            status         = 'PENDING'
            snooze_count   = 0
        }
        Save-TasksJson @($script:ValidTask)

        # Capture the tasks.json path and its .tmp counterpart for assertions.
        $script:TasksJsonPath = $script:TasksPath
        $script:TmpPath       = $script:TasksPath + '.tmp'
    }

    AfterAll {
        if (Test-Path $env:APPDATA) {
            Remove-Item -Path $env:APPDATA -Recurse -Force -ErrorAction SilentlyContinue
        }
        $env:APPDATA = $script:OriginalAppData
    }

    Context 'when Move-Item throws IOException after .tmp write succeeds' {

        BeforeEach {
            # Simulate a full-disk / locked-file condition at the rename step.
            # Move-Item is the final atomic rename inside Save-TasksJson; mocking it
            # here exercises the real Set-Content .tmp write path before the failure.
            Mock Move-Item {
                throw [System.IO.IOException]::new("Access to path denied")
            }

            # Attempt to replace the existing valid task with a different payload.
            $script:NewTask = [PSCustomObject]@{
                task_id        = 'new-task-999'
                task_name      = 'DailyMotivation_new-task-999'
                folder_path    = 'C:\New'
                folder_name    = 'New'
                scheduled_time = '2026-12-01T09:00:00'
                created_at     = (Get-Date -Format 'o')
                status         = 'PENDING'
                snooze_count   = 0
            }

            # Capture the exception so tests can inspect it without aborting the suite.
            try {
                Save-TasksJson @($script:NewTask)
                $script:SaveThrew = $false
            }
            catch {
                $script:SaveThrew   = $true
                $script:SaveError   = $_
            }
        }

        It 'Save-TasksJson re-throws when Move-Item fails' {
            $script:SaveThrew | Should -Be $true
        }

        It 'tasks.json still contains the ORIGINAL valid task after the failed write' {
            # The pre-existing tasks.json must be untouched because Move-Item never
            # completed — the .tmp file was never renamed over the live file.
            $raw = Get-Content -Path $script:TasksJsonPath -Raw -Encoding UTF8
            $raw | Should -Not -BeNullOrEmpty

            $tasks = $raw | ConvertFrom-Json
            @($tasks).Count | Should -Be 1
            @($tasks)[0].task_id | Should -Be 'original-task-001'
        }

        It 'tasks.json does NOT contain the new (un-committed) task entry' {
            $raw   = Get-Content -Path $script:TasksJsonPath -Raw -Encoding UTF8
            $tasks = $raw | ConvertFrom-Json
            $ids   = @($tasks) | Select-Object -ExpandProperty task_id
            $ids   | Should -Not -Contain 'new-task-999'
        }

        It 'Get-TasksJson does not throw after a failed Save-TasksJson call' {
            { Get-TasksJson } | Should -Not -Throw
        }

        It 'Get-TasksJson returns the original task entry after the failed write' {
            $result = Get-TasksJson
            @($result).Count | Should -Be 1
            @($result)[0].task_id | Should -Be 'original-task-001'
            @($result)[0].status  | Should -Be 'PENDING'
        }

        It 'the .tmp scratch file does not exist on disk after Save-TasksJson fails during Move-Item' {
            # Save-TasksJson catch block calls Remove-Item on the .tmp file.
            # After a failed save the temp file must not persist on disk.
            # NOTE: if this assertion fails it means partial writes CAN survive a
            # failure, which risks corrupting state on the next successful save.
            Test-Path $script:TmpPath | Should -Be $false
        }
    }
}
