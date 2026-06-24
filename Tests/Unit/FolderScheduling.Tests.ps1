#Requires -Modules Pester
<#
.SYNOPSIS
    Tests for extracted folder scheduling business logic

.DESCRIPTION
    Tests Invoke-FolderScheduling function (extracted from Show-MainWindow's Do-Schedule).
    Per architecture-report.html Candidate 1.
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
    # Cleanup test folders
    if (Test-Path "/tmp/test-folder") {
        Remove-Item -Path "/tmp/test-folder" -Recurse -Force -ErrorAction SilentlyContinue
    }
    if (Test-Path "/tmp/test") {
        Remove-Item -Path "/tmp/test" -Recurse -Force -ErrorAction SilentlyContinue
    }
}

Describe "Invoke-FolderScheduling" -Tag "Unit", "BusinessLogic" {

    BeforeEach {
        # Clean slate
        if (Test-Path $script:TestAppData) {
            Remove-Item -Path $script:TestAppData -Recurse -Force -ErrorAction SilentlyContinue
        }

        # Inject platform adapter for cross-platform testing
        $script:Platform = [HeadlessPlatform]::new()
        Initialize-AppData

        # Clear tasks
        Set-Content -Path $script:TasksPath -Value "[]" -Encoding UTF8 -NoNewline

        # Set exe path
        $script:ExePath = "/usr/local/bin/DailyMotivation.exe"

        # Create test folders for scheduling tests
        $script:TestFolder = "/tmp/test-folder"
        if (-not (Test-Path $script:TestFolder)) {
            New-Item -Path $script:TestFolder -ItemType Directory -Force | Out-Null
        }

        $script:TestFolder2 = "/tmp/test"
        if (-not (Test-Path $script:TestFolder2)) {
            New-Item -Path $script:TestFolder2 -ItemType Directory -Force | Out-Null
        }
    }

    Context "Basic scheduling" {
        It "schedules a valid folder and returns success" {
            # TRACER BULLET - This will fail until Invoke-FolderScheduling exists
            $triggerTime = (Get-Date).AddHours(1)
            $result = Invoke-FolderScheduling -FolderPath "/tmp/test-folder" -TriggerTime $triggerTime

            $result.Success | Should -Be $true
            $result.TaskId | Should -Not -BeNullOrEmpty
            $result.IsDuplicate | Should -Be $false
        }

        It "creates a task in tasks.json" {
            $triggerTime = (Get-Date).AddHours(1)
            $result = Invoke-FolderScheduling -FolderPath "/tmp/test-folder" -TriggerTime $triggerTime

            $tasks = Get-TasksJson
            $tasks.Count | Should -Be 1
            $tasks[0].task_id | Should -Be $result.TaskId
            $tasks[0].folder_path | Should -Be "/tmp/test-folder"
        }
    }

    Context "Duplicate detection" {
        It "blocks duplicate folder on same date" {
            $triggerTime = (Get-Date).Date.AddHours(14)

            # First schedule succeeds
            $result1 = Invoke-FolderScheduling -FolderPath "/tmp/test" -TriggerTime $triggerTime
            $result1.Success | Should -Be $true

            # Second schedule on same date fails
            $result2 = Invoke-FolderScheduling -FolderPath "/tmp/test" -TriggerTime $triggerTime
            $result2.Success | Should -Be $false
            $result2.IsDuplicate | Should -Be $true
        }

        It "allows duplicate with Force flag" {
            $triggerTime = (Get-Date).Date.AddHours(14)

            # First schedule
            Invoke-FolderScheduling -FolderPath "/tmp/test" -TriggerTime $triggerTime

            # Second schedule with Force succeeds
            $result = Invoke-FolderScheduling -FolderPath "/tmp/test" -TriggerTime $triggerTime -Force
            $result.Success | Should -Be $true
            $result.IsDuplicate | Should -Be $false

            # Should have 2 tasks
            $tasks = Get-TasksJson
            $tasks.Count | Should -Be 2
        }
    }

    Context "Network path detection" {
        It "detects UNC paths and sets IsNetworkPath flag" {
            $result = Invoke-FolderScheduling -FolderPath "\\server\share\folder" -TriggerTime (Get-Date).AddHours(1)

            $result.Success | Should -Be $true
            $result.IsNetworkPath | Should -Be $true
        }
    }
}
