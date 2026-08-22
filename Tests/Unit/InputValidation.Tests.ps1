#Requires -Modules Pester
<#
.SYNOPSIS
    Unit tests for input validation bugs (AG2-001 through AG2-025)
.NOTES
    Windows-only tests: Requires Windows Task Scheduler cmdlets
#>

BeforeAll {
    . (Join-Path $PSScriptRoot '..\..\DailyMotivation.ps1') -NoRun

    $script:OriginalAppData = $env:APPDATA
    $env:APPDATA = Join-Path ([System.IO.Path]::GetTempPath()) "DMBH_InputVal_Test_$(New-Guid)"
    Initialize-AppData

    # Override ExePath
    $script:ExePath = "C:\Test\DailyMotivation.exe"

    # Mock Windows Task Scheduler cmdlets only on Windows
    if ($IsWindows) {
        $script:InputValMockedTasks = @{}

        Mock Register-ScheduledTask {
            param($TaskName, $Action, $Trigger, $Settings, $Principal, $Description, $Force, $ErrorAction)
            $script:InputValMockedTasks[$TaskName] = [PSCustomObject]@{ TaskName = $TaskName }
            return $null
        }
        Mock Unregister-ScheduledTask {
            param($TaskName, $Confirm)
            if ($script:InputValMockedTasks.ContainsKey($TaskName)) {
                $script:InputValMockedTasks.Remove($TaskName)
            }
        }
        Mock Get-ScheduledTask {
            param($TaskName)
            if ($TaskName -eq "DailyMotivation_*") {
                return @($script:InputValMockedTasks.Values)
            }
            if ($script:InputValMockedTasks.ContainsKey($TaskName)) {
                return $script:InputValMockedTasks[$TaskName]
            }
            throw "Task not found: $TaskName"
        }
    }
}

AfterAll {
    if (Test-Path $env:APPDATA) {
        Remove-Item -Path $env:APPDATA -Recurse -Force -ErrorAction SilentlyContinue
    }
    $env:APPDATA = $script:OriginalAppData
}

Describe 'AG2-001: Missing null check on $FolderPath before length comparison' -Skip:(-not $IsWindows) {
    BeforeEach {
        '[]' | Set-Content (Join-Path $env:APPDATA 'DailyMotivationBrainHelper\tasks.json') -Encoding UTF8
    }

    It 'New-MotivationTask does not throw for FolderPath = <label>' -ForEach @(
        @{ label = 'null';         path = $null }
        @{ label = 'empty string'; path = '' }
        @{ label = 'single char';  path = 'C' }
    ) {
        { New-MotivationTask -FolderPath $path -TriggerTime ((Get-Date).AddHours(2)) } | Should -Not -Throw
    }

    It 'Invoke-FolderScheduling does not throw for FolderPath = <label>' -ForEach @(
        @{ label = 'null';         path = $null }
        @{ label = 'empty string'; path = '' }
    ) {
        { Invoke-FolderScheduling -FolderPath $path -TriggerTime ((Get-Date).AddHours(2)) } | Should -Not -Throw
    }
}

