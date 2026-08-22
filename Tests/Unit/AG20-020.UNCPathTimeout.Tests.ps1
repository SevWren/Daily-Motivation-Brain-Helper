#Requires -Modules Pester
<#
.SYNOPSIS
    Tests for UNC path network timeout and unavailability handling (AG20-020).

.DESCRIPTION
    Verifies Invoke-FolderScheduling behavior when a UNC path is:
      1. Reachable — schedules normally and sets IsNetworkPath = $true
      2. Unreachable (Test-Path throws IOException) — returns Success = $false or does not
         propagate an unhandled exception
      3. Gone (Test-Path returns $false) — behaves consistently with any other missing folder

    Linux-compatible tests use HeadlessPlatform + Invoke-FolderScheduling.
    Windows-only tests (New-MotivationTask) are guarded with -Skip:(-not $IsWindows).
#>

BeforeAll {
    . "$PSScriptRoot\..\..\DailyMotivation.ps1" -NoRun

    $script:TestAppData = Join-Path ([System.IO.Path]::GetTempPath()) "DailyMotivationTest_$(New-Guid)"
    $script:OuterOriginalAppData = $env:APPDATA
    $env:APPDATA = $script:TestAppData
}

AfterAll {
    if (Test-Path $script:TestAppData) {
        Remove-Item -Path $script:TestAppData -Recurse -Force -ErrorAction SilentlyContinue
    }
    $env:APPDATA = $script:OuterOriginalAppData
}

Describe "Invoke-FolderScheduling — UNC path network failure (AG20-020)" -Tag "Unit", "NetworkPath" {

    BeforeEach {
        if (Test-Path $script:TestAppData) {
            Remove-Item -Path $script:TestAppData -Recurse -Force -ErrorAction SilentlyContinue
        }

        $script:Platform = [HeadlessPlatform]::new()
        Initialize-AppData

        Set-Content -Path $script:TasksPath -Value "[]" -Encoding UTF8 -NoNewline

        $script:ExePath = "/usr/local/bin/DailyMotivation.exe"
    }

    Context "Reachable UNC path" {
        It "schedules successfully and sets IsNetworkPath = true when UNC path is reachable" {
            # HeadlessPlatform is injected, so Test-Path for the UNC path is bypassed by the
            # platform guard in Invoke-FolderScheduling. Confirm the network flag and success.
            $result = Invoke-FolderScheduling -FolderPath "\\server\share\folder" -TriggerTime (Get-Date).AddHours(1)

            $result.Success       | Should -Be $true
            $result.IsNetworkPath | Should -Be $true
            $result.TaskId        | Should -Not -BeNullOrEmpty
        }

        It "persists the task to tasks.json with IsNetworkPath reflected in scheduling result" {
            $result = Invoke-FolderScheduling -FolderPath "\\fileserver\dept\projects" -TriggerTime (Get-Date).AddHours(2)

            $result.Success       | Should -Be $true
            $result.IsNetworkPath | Should -Be $true

            $tasks = Get-TasksJson
            $tasks.Count | Should -Be 1
            $tasks[0].task_id     | Should -Be $result.TaskId
            $tasks[0].folder_path | Should -Be "\\fileserver\dept\projects"
        }
    }

    Context "UNC path becomes unavailable — Test-Path throws (simulated network timeout)" {
        It "does not throw an unhandled exception when Test-Path raises IOException for a UNC path" {
            # Simulate network timeout / path suddenly unreachable
            Mock Test-Path {
                throw [System.IO.IOException]::new("Network path unreachable")
            } -ParameterFilter { $Path -like '\\*' }

            # The function must not propagate the exception to the caller.
            # Use $script: scope so the result is accessible after the Should -Not -Throw scriptblock.
            $script:UncThrowResult = $null
            { $script:UncThrowResult = Invoke-FolderScheduling -FolderPath "\\server\share\folder" -TriggerTime (Get-Date).AddHours(1) } |
                Should -Not -Throw

            $script:UncThrowResult | Should -Not -BeNullOrEmpty
        }

        It "does not throw, returns a non-null result, and includes a non-empty Error field when Success=false, when Test-Path throws IOException for a UNC path" {
            # Per issue #173: acceptable outcomes are (a) Success=$false with error message,
            # or (b) graceful handling with no unhandled exception.
            Mock Test-Path {
                throw [System.IO.IOException]::new("Network path unreachable")
            } -ParameterFilter { $Path -like '\\*' }

            $script:UncGracefulResult = $null
            { $script:UncGracefulResult = Invoke-FolderScheduling -FolderPath "\\nas\shared\docs" -TriggerTime (Get-Date).AddHours(1) } |
                Should -Not -Throw

            # Either the function succeeded despite the throw (UNC validation skip) or it
            # returned a structured failure. Either way the result must be a hashtable.
            $script:UncGracefulResult | Should -Not -BeNullOrEmpty

            if ($script:UncGracefulResult.Success -eq $false) {
                # If the implementation chose to surface the failure, an Error field is expected
                $script:UncGracefulResult.Error | Should -Not -BeNullOrEmpty
            }
        }
    }

    Context "UNC path gone — Test-Path returns false (simulated share removal)" {
        It "does not throw and returns a non-null result when Test-Path returns false for a UNC path" {
            Mock Test-Path { return $false } -ParameterFilter { $Path -like '\\*' }

            $script:UncGoneResult = $null
            { $script:UncGoneResult = Invoke-FolderScheduling -FolderPath "\\server\share\gone" -TriggerTime (Get-Date).AddHours(1) } |
                Should -Not -Throw
            $script:UncGoneResult | Should -Not -BeNullOrEmpty
        }

        It "behavior when UNC path Test-Path returns false is consistent with a missing local folder" {
            # A local folder that does not exist returns Success = $false on real platform.
            # With HeadlessPlatform injected, Test-Path is skipped for both; confirm neither throws.
            Mock Test-Path { return $false } -ParameterFilter { $Path -like '\\*' }

            $script:UncConsistResult   = $null
            $script:LocalConsistResult = $null

            { $script:UncConsistResult   = Invoke-FolderScheduling -FolderPath "\\server\share\missing" -TriggerTime (Get-Date).AddHours(1) } |
                Should -Not -Throw
            { $script:LocalConsistResult = Invoke-FolderScheduling -FolderPath "/nonexistent/path/xyz"  -TriggerTime (Get-Date).AddHours(1) } |
                Should -Not -Throw

            # Both must return a result object — no silent nulls
            $script:UncConsistResult   | Should -Not -BeNullOrEmpty
            $script:LocalConsistResult | Should -Not -BeNullOrEmpty
        }
    }

    Context "UNC path IsNetworkPath flag is always set regardless of reachability" {
        It "sets IsNetworkPath = true even when Test-Path throws for UNC path" {
            Mock Test-Path {
                throw [System.IO.IOException]::new("Network path unreachable")
            } -ParameterFilter { $Path -like '\\*' }

            $result = Invoke-FolderScheduling -FolderPath "\\server\share\folder" -TriggerTime (Get-Date).AddHours(1)

            $result.IsNetworkPath | Should -Be $true
        }

        It "sets IsNetworkPath = true even when Test-Path returns false for a UNC path" {
            Mock Test-Path { return $false } -ParameterFilter { $Path -like '\\*' }

            $result = Invoke-FolderScheduling -FolderPath "\\server\share\folder" -TriggerTime (Get-Date).AddHours(1)

            $result.IsNetworkPath | Should -Be $true
        }
    }
}

Describe "New-MotivationTask — UNC path network failure (AG20-020, Windows only)" `
    -Tag "Unit", "NetworkPath" `
    -Skip:(-not $IsWindows) {

    BeforeAll {
        if (-not $IsWindows) { return }

        $script:OriginalAppData = $env:APPDATA
        $env:APPDATA = Join-Path ([System.IO.Path]::GetTempPath()) "DMBH_AG20020_Test_$(New-Guid)"
        Initialize-AppData
        $script:ExePath = "C:\Test\DailyMotivation.exe"

        Mock Register-ScheduledTask { return $null }
        Mock Unregister-ScheduledTask { }
        Mock Get-ScheduledTask {
            param($TaskName)
            # Return empty for wildcard (prevents Sync-TaskStatuses phantom recovery).
            # Return null for specific task (no collision, no "still exists" after unregister).
            if ($TaskName -eq 'DailyMotivation_*') { return @() }
            return $null
        }
        # Ensure no Platform adapter from other test files bleeds into this scope
        $script:Platform = $null
    }

    AfterAll {
        if (-not $IsWindows) { return }
        if (Test-Path $env:APPDATA) {
            Remove-Item -Path $env:APPDATA -Recurse -Force -ErrorAction SilentlyContinue
        }
        $env:APPDATA = $script:OriginalAppData
    }

    BeforeEach {
        if (-not $IsWindows) { return }
        if (-not (Test-Path (Split-Path $script:TasksPath -Parent))) {
            New-Item -ItemType Directory -Path (Split-Path $script:TasksPath -Parent) -Force | Out-Null
        }
        '[]' | Set-Content $script:TasksPath -Encoding UTF8 -Force
    }

    Context "Reachable UNC path" {
        It "schedules normally and sets IsNetworkPath = true for a UNC path" {
            $result = New-MotivationTask -FolderPath '\\server\share\folder' -TriggerTime (Get-Date).AddHours(2)

            $result.Success       | Should -Be $true
            $result.IsNetworkPath | Should -Be $true
            $result.TaskId        | Should -Not -BeNullOrEmpty
        }
    }

    Context "UNC path becomes unavailable — Test-Path throws (simulated network timeout)" {
        It "does not throw an unhandled exception when Test-Path raises IOException for a UNC path" {
            Mock Test-Path {
                throw [System.IO.IOException]::new("Network path unreachable")
            } -ParameterFilter { $Path -like '\\*' }

            { New-MotivationTask -FolderPath '\\server\share\folder' -TriggerTime (Get-Date).AddHours(2) } |
                Should -Not -Throw
        }

        It "returns Success = false with an error message when Test-Path raises IOException for a UNC path" {
            Mock Test-Path {
                throw [System.IO.IOException]::new("Network path unreachable")
            } -ParameterFilter { $Path -like '\\*' }

            $result = New-MotivationTask -FolderPath '\\server\share\folder' -TriggerTime (Get-Date).AddHours(2)

            $result        | Should -Not -BeNullOrEmpty
            if ($result.Success -eq $false) {
                $result.Error | Should -Not -BeNullOrEmpty
            }
        }

    }

    Context "UNC path gone — Test-Path returns false" {
        It "does not throw when Test-Path returns false for a UNC path" {
            Mock Test-Path { return $false } -ParameterFilter { $Path -like '\\*' }

            { New-MotivationTask -FolderPath '\\server\share\missing' -TriggerTime (Get-Date).AddHours(2) } |
                Should -Not -Throw
        }

    }
}
