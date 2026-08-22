#Requires -Modules Pester
<#
.SYNOPSIS
    Unit tests for Get-Config upgrade path — AG20-012.
    Verifies that Get-Config returns safe defaults when config.json was written
    by an older (or newer) version of the application with a partial or different schema.
#>

BeforeAll {
    . (Join-Path $PSScriptRoot '..\..\DailyMotivation.ps1') -NoRun
    $script:OriginalAppData = $env:APPDATA
}

AfterAll {
    $env:APPDATA = $script:OriginalAppData
}

Describe 'Get-Config old schema upgrade path' {
    BeforeEach {
        # Clear platform adapter so Initialize-AppData uses $env:APPDATA, not HeadlessPlatform.
        $script:Platform = $null
        $env:APPDATA = Join-Path ([System.IO.Path]::GetTempPath()) "DMBH_OldSchema_$(New-Guid)"
        Initialize-AppData
        # Clear cache so every test reads directly from disk
        $script:ConfigCache = $null
        $script:ConfigCacheMTime = $null
    }

    AfterEach {
        if (Test-Path $env:APPDATA) {
            Remove-Item -Path $env:APPDATA -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    It 'Returns <ExpectedValue> for <AssertProperty> when config contains only <SeedKey>' -ForEach @(
        @{ SeedJson = '{"default_trigger_hour":9}';   AssertProperty = 'task_warning_threshold'; ExpectedValue = 5;  SeedKey = 'default_trigger_hour' }
        @{ SeedJson = '{"default_trigger_hour":9}';   AssertProperty = 'default_trigger_hour';   ExpectedValue = 9;  SeedKey = 'default_trigger_hour' }
        @{ SeedJson = '{"task_warning_threshold":3}'; AssertProperty = 'default_trigger_hour';   ExpectedValue = 14; SeedKey = 'task_warning_threshold' }
        @{ SeedJson = '{"task_warning_threshold":3}'; AssertProperty = 'task_warning_threshold'; ExpectedValue = 3;  SeedKey = 'task_warning_threshold' }
    ) {
        $configPath = Join-Path $env:APPDATA 'DailyMotivationBrainHelper\config.json'
        $SeedJson | Set-Content $configPath -Encoding UTF8
        $script:ConfigCache      = $null
        $script:ConfigCacheMTime = $null
        $cfg = Get-Config
        $cfg.$AssertProperty | Should -Be $ExpectedValue
    }

    It 'Returns default_trigger_hour = 14 when config.json has old renamed key trigger_hour' {
        # trigger_hour was the old name before the key was renamed to default_trigger_hour.
        # Get-Config does not recognise trigger_hour, so default_trigger_hour is absent → safe default.
        @{ trigger_hour = 10; task_warning_threshold = 5 } |
            ConvertTo-Json |
            Set-Content (Join-Path $env:APPDATA 'DailyMotivationBrainHelper\config.json') -Encoding UTF8

        $cfg = Get-Config

        $cfg.default_trigger_hour | Should -Be 14
    }

    It 'Does not throw when config.json contains extra unknown keys from a future version' {
        # A future version may add keys not present in the current schema.
        # Get-Config must not throw; known keys must be returned correctly.
        @{
            default_trigger_hour   = 8
            task_warning_threshold = 4
            future_feature_flag    = $true
            new_unknown_int        = 42
        } |
            ConvertTo-Json |
            Set-Content (Join-Path $env:APPDATA 'DailyMotivationBrainHelper\config.json') -Encoding UTF8

        { $script:FutureCfg = Get-Config } | Should -Not -Throw
        $script:FutureCfg.default_trigger_hour   | Should -Be 8
        $script:FutureCfg.task_warning_threshold  | Should -Be 4
    }

    It 'Returns both safe defaults when config.json is a completely empty JSON object' {
        # {} is valid JSON but contains no keys at all — both fields must fall back to defaults.
        '{}' |
            Set-Content (Join-Path $env:APPDATA 'DailyMotivationBrainHelper\config.json') -Encoding UTF8

        $cfg = Get-Config

        $cfg.default_trigger_hour   | Should -Be 14
        $cfg.task_warning_threshold | Should -Be 5
    }
}
