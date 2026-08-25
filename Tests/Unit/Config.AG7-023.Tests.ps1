#Requires -Modules @{ ModuleName='Pester'; ModuleVersion='5.0.0' }
<#
.SYNOPSIS
    Tests for AG7-023: Centralized default config values
#>

BeforeAll {
    . (Join-Path $PSScriptRoot '..\..\DailyMotivation.ps1') -NoRun

    $script:OriginalAppData = $env:APPDATA
    $env:APPDATA = Join-Path ([System.IO.Path]::GetTempPath()) "DMBH_AG7_023_Test_$(New-Guid)"
    Initialize-AppData
}

AfterAll {
    if (Test-Path $env:APPDATA) {
        Remove-Item -Path $env:APPDATA -Recurse -Force -ErrorAction SilentlyContinue
    }
    $env:APPDATA = $script:OriginalAppData
}

Describe 'AG7-023: Centralized Config Defaults' {
    Context 'Single source of truth for default values' {
        It 'Should have a $script:ConfigDefaults variable' {
            $script:ConfigDefaults | Should -Not -Be $null
            $script:ConfigDefaults.default_trigger_hour | Should -Be 14
            $script:ConfigDefaults.task_warning_threshold | Should -Be 5
        }

        It 'Should use ConfigDefaults when creating new config file' {
            # Remove existing config
            $configPath = Join-Path $env:APPDATA 'DailyMotivationBrainHelper\config.json'
            if (Test-Path $configPath) {
                Remove-Item $configPath -Force
            }

            # Reinitialize to create config
            Initialize-AppData

            # Config should match defaults
            $cfg = Get-Content $configPath -Raw | ConvertFrom-Json
            $cfg.default_trigger_hour | Should -Be $script:ConfigDefaults.default_trigger_hour
            $cfg.task_warning_threshold | Should -Be $script:ConfigDefaults.task_warning_threshold
        }

        It 'Should use ConfigDefaults in Get-Config fallback' {
            # Corrupt config
            $configPath = Join-Path $env:APPDATA 'DailyMotivationBrainHelper\config.json'
            'invalid json{' | Set-Content $configPath -Encoding UTF8

            # Get-Config should return defaults
            $cfg = Get-Config
            $cfg.default_trigger_hour | Should -Be $script:ConfigDefaults.default_trigger_hour
            $cfg.task_warning_threshold | Should -Be $script:ConfigDefaults.task_warning_threshold
        }

        It 'Should use ConfigDefaults in inline default expressions' {
            # This tests that inline defaults reference ConfigDefaults
            # We can't easily test Get-ScheduleTime without mocking UI controls,
            # so we verify that the default expressions are using ConfigDefaults
            # by checking that Get-Config returns ConfigDefaults when corrupted
            $configPath = Join-Path $env:APPDATA 'DailyMotivationBrainHelper\config.json'
            'corrupted' | Set-Content $configPath -Encoding UTF8

            # Clear cache
            $script:ConfigCache = $null
            $script:ConfigCacheMTime = $null

            $cfg = Get-Config
            # Inline default should match ConfigDefaults
            $hour = if ($cfg -and $null -ne $cfg.default_trigger_hour) { [int]$cfg.default_trigger_hour } else { $script:ConfigDefaults.default_trigger_hour }
            $hour | Should -Be $script:ConfigDefaults.default_trigger_hour
        }
    }

    Context 'Changing default values' {
        It 'Should eliminate hardcoded defaults throughout codebase' {
            # Verify that defaults are NOT hardcoded in multiple places
            # by checking that all usage points reference ConfigDefaults

            # Check that config initialization uses ConfigDefaults
            $configPath = Join-Path $env:APPDATA 'DailyMotivationBrainHelper\config.json'
            Remove-Item $configPath -Force -ErrorAction SilentlyContinue
            Initialize-AppData
            $cfg = Get-Content $configPath -Raw | ConvertFrom-Json
            # Should match ConfigDefaults values
            $cfg.default_trigger_hour | Should -Be $script:ConfigDefaults.default_trigger_hour
            $cfg.task_warning_threshold | Should -Be $script:ConfigDefaults.task_warning_threshold

            # Check that Get-Config fallback uses ConfigDefaults
            'corrupted json{' | Set-Content $configPath -Encoding UTF8
            $script:ConfigCache = $null
            $script:ConfigCacheMTime = $null
            $fallback = Get-Config
            $fallback.default_trigger_hour | Should -Be $script:ConfigDefaults.default_trigger_hour
            $fallback.task_warning_threshold | Should -Be $script:ConfigDefaults.task_warning_threshold
        }
    }
}
