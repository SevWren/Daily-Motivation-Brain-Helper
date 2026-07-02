#Requires -Modules Pester
<#
.SYNOPSIS
    Unit tests for input validation bugs (AG2-001 through AG2-025)
#>

BeforeAll {
    . (Join-Path $PSScriptRoot '..\..\DailyMotivation.ps1') -NoRun

    $script:OriginalAppData = $env:APPDATA
    $env:APPDATA = Join-Path ([System.IO.Path]::GetTempPath()) "DMBH_InputVal_Test_$(New-Guid)"
    Initialize-AppData

    # Override ExePath
    $script:ExePath = "C:\Test\DailyMotivation.exe"

    # Mock Windows Task Scheduler cmdlets
    Mock Register-ScheduledTask { return $null }
    Mock Unregister-ScheduledTask { }
    Mock Get-ScheduledTask {
        param($TaskName)
        if ($TaskName -eq "DailyMotivation_*") { return @() }
        return $null
    }
}

AfterAll {
    if (Test-Path $env:APPDATA) {
        Remove-Item -Path $env:APPDATA -Recurse -Force -ErrorAction SilentlyContinue
    }
    $env:APPDATA = $script:OriginalAppData
}

Describe 'AG2-001: Missing null check on $FolderPath before length comparison' {
    BeforeEach {
        '[]' | Set-Content (Join-Path $env:APPDATA 'DailyMotivationBrainHelper\tasks.json') -Encoding UTF8
    }

    Context 'New-MotivationTask' {
        It 'Should handle null FolderPath without throwing NullReferenceException' {
            $result = $null
            { $result = New-MotivationTask -FolderPath $null -TriggerTime ((Get-Date).AddHours(2)) } | Should -Not -Throw
        }

        It 'Should handle empty FolderPath without throwing' {
            $result = $null
            { $result = New-MotivationTask -FolderPath '' -TriggerTime ((Get-Date).AddHours(2)) } | Should -Not -Throw
        }

        It 'Should handle single character FolderPath without array index error' {
            $result = $null
            { $result = New-MotivationTask -FolderPath 'C' -TriggerTime ((Get-Date).AddHours(2)) } | Should -Not -Throw
        }
    }

    Context 'Invoke-FolderScheduling' {
        It 'Should handle null FolderPath without throwing NullReferenceException' {
            $result = $null
            { $result = Invoke-FolderScheduling -FolderPath $null -TriggerTime ((Get-Date).AddHours(2)) } | Should -Not -Throw
        }

        It 'Should handle empty FolderPath without throwing' {
            $result = $null
            { $result = Invoke-FolderScheduling -FolderPath '' -TriggerTime ((Get-Date).AddHours(2)) } | Should -Not -Throw
        }
    }
}

Describe 'AG2-004: Unvalidated array index access on $FolderPath' {
    BeforeEach {
        '[]' | Set-Content (Join-Path $env:APPDATA 'DailyMotivationBrainHelper\tasks.json') -Encoding UTF8
    }

    It 'Should handle single character path without array bounds exception' {
        $result = $null
        { $result = New-MotivationTask -FolderPath 'X' -TriggerTime ((Get-Date).AddHours(2)) } | Should -Not -Throw
    }
}
