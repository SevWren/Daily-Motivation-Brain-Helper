#Requires -Modules Pester
<#
.SYNOPSIS
    Tests for platform abstraction seam (OS-agnostic PowerShell 7)

.DESCRIPTION
    Tests HeadlessPlatform adapter to enable cross-platform CI testing.
    Per architecture-report.html Candidate 3.
#>

BeforeAll {
    # Dot-source the script with -NoRun
    . "$PSScriptRoot\..\..\DailyMotivation.ps1" -NoRun
}

Describe "HeadlessPlatform adapter" -Tag "Unit", "Platform" {

    BeforeEach {
        $platform = [HeadlessPlatform]::new()
    }

    Context "GetAppDataPath" {
        It "returns a valid path for headless testing" {
            $path = $platform.GetAppDataPath()

            $path | Should -Not -BeNullOrEmpty
            $path | Should -BeLike "*DailyMotivationBrainHelper*"
        }

        It "returns a cross-platform path (not Windows-specific)" {
            $path = $platform.GetAppDataPath()

            # Should not contain Windows-specific patterns
            $path | Should -Not -BeLike "*AppData*"
            $path | Should -Not -BeLike "*C:\*"
        }
    }

    Context "OpenFolder" {
        It "executes without error in headless mode" {
            { $platform.OpenFolder("/tmp/test") } | Should -Not -Throw
        }
    }

    Context "ScheduleTask" {
        It "returns a mock task ID" {
            $result = $platform.ScheduleTask(@{
                FolderPath = "/tmp/test"
                TriggerTime = (Get-Date)
            })

            $result.Success | Should -Be $true
            $result.TaskId | Should -Not -BeNullOrEmpty
            $result.TaskId | Should -BeLike "headless-mock-*"
        }
    }

    Context "UnscheduleTask" {
        It "executes without error in headless mode" {
            { $platform.UnscheduleTask("test-task-123") } | Should -Not -Throw
        }
    }

    Context "RegisterContextMenu" {
        It "executes without error in headless mode" {
            { $platform.RegisterContextMenu("/usr/bin/test.exe") } | Should -Not -Throw
        }
    }

    Context "ShowDialog" {
        It "returns default button value" {
            $result = $platform.ShowDialog("Test message", "Test title", "OK", "Information")

            $result | Should -Be "OK"
        }
    }
}
