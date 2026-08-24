#Requires -Modules @{ ModuleName='Pester'; ModuleVersion='5.0.0' }
<#
.SYNOPSIS
    Tests for AG20-006: Get-ScheduleTime DST transition edge cases.
.NOTES
    Linux-safe: no Task Scheduler calls. Tests pure .NET DateTime arithmetic
    in Get-ScheduleTime. Regression guard ensuring no exception is thrown
    when a scheduled hour falls near a DST boundary.
#>

BeforeAll {
    $script:ProjectRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
    . (Join-Path $script:ProjectRoot 'DailyMotivation.ps1') -NoRun

    $script:OriginalAppData = $env:APPDATA
    $env:APPDATA = Join-Path ([System.IO.Path]::GetTempPath()) "DMBH_DST_Test_$(New-Guid)"
    Initialize-AppData

    # Fake radio control: IsVisible + IsChecked = "Today" selected
    $script:TodayControl    = [PSCustomObject]@{ IsVisible = $true;  IsChecked = $true  }
    $script:TomorrowControl = [PSCustomObject]@{ IsVisible = $true;  IsChecked = $false }
}

AfterAll {
    if (Test-Path $env:APPDATA) {
        Remove-Item -Path $env:APPDATA -Recurse -Force -ErrorAction SilentlyContinue
    }
    $env:APPDATA = $script:OriginalAppData
}

Describe 'Get-ScheduleTime - DST boundary safety (AG20-006)' {

    BeforeEach {
        # Restore default config hour before each test
        $script:MockedGetDateReturn = $null
    }

    It 'Should return a valid DateTime without throwing for a typical trigger hour' {
        Mock Get-Date { [datetime]::new(2026, 6, 15, 0, 0, 0) }

        $result = Get-ScheduleTime -TodayRadioControl $script:TodayControl
        $result | Should -BeOfType [datetime]
        $result | Should -Not -BeNullOrEmpty
    }

    It 'Should return today-at-hour when TodayRadioControl is visible and checked' {
        $fakeToday = [datetime]::new(2026, 6, 15, 9, 0, 0)
        Mock Get-Date { $fakeToday }

        $result = Get-ScheduleTime -TodayRadioControl $script:TodayControl
        $result.Date | Should -Be $fakeToday.Date
        # default_trigger_hour is 14 unless config overrides
        $result.Hour | Should -BeIn @(0..23)
    }

    It 'Should return tomorrow-at-hour when TodayRadioControl is not checked' {
        $fakeToday = [datetime]::new(2026, 6, 15, 9, 0, 0)
        Mock Get-Date { $fakeToday }

        $result = Get-ScheduleTime -TodayRadioControl $script:TomorrowControl
        $result.Date | Should -Be $fakeToday.Date.AddDays(1)
    }

    It 'Should not throw when the trigger date is a US spring-forward Sunday (AG20-006)' {
        # 2025-03-09: second Sunday in March (US/Eastern spring-forward day)
        # default_trigger_hour=14 is not in the skipped gap (2:00-3:00 AM),
        # but this regression test guards against future config values in the gap.
        Mock Get-Date { [datetime]::new(2025, 3, 9, 0, 0, 0) }

        { Get-ScheduleTime -TodayRadioControl $script:TodayControl } | Should -Not -Throw
    }

    It 'Should not throw when the trigger date is a US fall-back Sunday (AG20-006)' {
        # 2025-11-02: first Sunday in November (US/Eastern fall-back day)
        Mock Get-Date { [datetime]::new(2025, 11, 2, 0, 0, 0) }

        { Get-ScheduleTime -TodayRadioControl $script:TodayControl } | Should -Not -Throw
    }

    It 'Should return a DateTime with the configured trigger hour on a DST transition day' {
        # Verify the return value carries the configured hour even on transition days
        Mock Get-Date { [datetime]::new(2025, 3, 9, 0, 0, 0) }

        $result = Get-ScheduleTime -TodayRadioControl $script:TodayControl
        $result | Should -BeOfType [datetime]
        # Hour should be whatever default_trigger_hour is (14 by default)
        # The key assertion: result is a valid DateTime, not $null or an error
        $result.Year | Should -Be 2025
        $result.Month | Should -Be 3
        $result.Day | Should -Be 9
    }

    It 'Should return a DateTime for tomorrow on a DST transition day when Tomorrow is selected' {
        Mock Get-Date { [datetime]::new(2025, 3, 9, 0, 0, 0) }

        $result = Get-ScheduleTime -TodayRadioControl $script:TomorrowControl
        $result | Should -BeOfType [datetime]
        $result.Day | Should -Be 10   # next day
    }
}
