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
        $script:ConfigCache = $null
        $script:ConfigCacheMTime = $null
    }

    It 'Returns task_warning_threshold = 5 when config.json is missing that key (old schema)' {
        # Seed: only default_trigger_hour present — simulates config written before task_warning_threshold existed
        @{ default_trigger_hour = 9 } |
            ConvertTo-Json |
            Set-Content (Join-Path $env:APPDATA 'DailyMotivationBrainHelper\config.json') -Encoding UTF8

        $cfg = Get-Config

        $cfg.task_warning_threshold | Should -Be 5
    }

    It 'Preserves the present key default_trigger_hour = 9 when task_warning_threshold is missing' {
        # The valid key that IS present must survive — only the missing key gets a default
        @{ default_trigger_hour = 9 } |
            ConvertTo-Json |
            Set-Content $script:ConfigPath -Encoding UTF8
        $script:ConfigCache = $null; $script:ConfigCacheMTime = $null

        $cfg = Get-Config

        $cfg.default_trigger_hour | Should -Be 9
    }

    It 'Returns default_trigger_hour = 14 when config.json is missing that key' {
        # Seed: only task_warning_threshold present — simulates config missing default_trigger_hour
        @{ task_warning_threshold = 3 } |
            ConvertTo-Json |
            Set-Content (Join-Path $env:APPDATA 'DailyMotivationBrainHelper\config.json') -Encoding UTF8

        $cfg = Get-Config

        $cfg.default_trigger_hour | Should -Be 14
    }

    It 'Preserves the present key task_warning_threshold = 3 when default_trigger_hour is missing' {
        @{ task_warning_threshold = 3 } |
            ConvertTo-Json |
            Set-Content $script:ConfigPath -Encoding UTF8
        $script:ConfigCache = $null; $script:ConfigCacheMTime = $null

        $cfg = Get-Config

        $cfg.task_warning_threshold | Should -Be 3
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
