#Requires -Modules Pester
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

    }
}
