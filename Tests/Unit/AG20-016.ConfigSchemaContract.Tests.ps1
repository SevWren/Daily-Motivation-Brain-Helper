#Requires -Modules @{ ModuleName='Pester'; ModuleVersion='5.0.0' }
<#
.SYNOPSIS
    AG20-016  -  Config schema contract tests.

.DESCRIPTION
    Verifies that Get-Config enforces type and range constraints on
    default_trigger_hour and task_warning_threshold.

    All tests document CURRENT behavior (as implemented in Get-Config).
    Where validation already exists the tests assert the corrected value.
    Where no validation exists the tests document the pass-through behavior.

    Current implementation (DailyMotivation.ps1 lines 264-274):
      - default_trigger_hour: null / non-numeric / outside [0,23]  → replaced with 14
      - task_warning_threshold: null / non-numeric / < 0           → replaced with 5
      - task_warning_threshold = 0  passes the (< 0) guard         → returned as 0

    These tests are platform-agnostic and Linux-safe.
#>

BeforeAll {
    . (Join-Path $PSScriptRoot '..\..\DailyMotivation.ps1') -NoRun
    $script:OriginalAppData = $env:APPDATA
    $env:APPDATA = Join-Path ([System.IO.Path]::GetTempPath()) "DMBH_Schema_$(New-Guid)"
    Initialize-AppData
}

AfterAll {
    if (Test-Path $env:APPDATA) { Remove-Item -Path $env:APPDATA -Recurse -Force -ErrorAction SilentlyContinue }
    $env:APPDATA = $script:OriginalAppData
}

Describe 'Config schema contract' {
    BeforeEach {
        # Each test gets its own isolated APPDATA so there is no cross-test pollution.
        $env:APPDATA = Join-Path ([System.IO.Path]::GetTempPath()) "DMBH_SchemaCfg_$(New-Guid)"
        Initialize-AppData
        # Bust the config cache so every test reads from disk.
        $script:ConfigCache     = $null
        $script:ConfigCacheMTime = $null
    }

    AfterEach {
        $script:ConfigCache     = $null
        $script:ConfigCacheMTime = $null
        if (Test-Path $env:APPDATA) { Remove-Item -Path $env:APPDATA -Recurse -Force -ErrorAction SilentlyContinue }
    }

    # -------------------------------------------------------------------------
    # TYPE ASSERTIONS  -  fresh defaults
    # -------------------------------------------------------------------------

    Context 'Type assertions on default values' {
        It 'default_trigger_hour is an integer type (not string, not float) on fresh init' {
            $cfg = Get-Config
            # ConvertFrom-Json deserialises JSON integers as [long] on .NET Core
            # and as [int] on .NET Framework; both are acceptable.
            ($cfg.default_trigger_hour -is [int] -or $cfg.default_trigger_hour -is [long]) |
                Should -Be $true
        }

        It 'task_warning_threshold is an integer type (not string, not float) on fresh init' {
            $cfg = Get-Config
            ($cfg.task_warning_threshold -is [int] -or $cfg.task_warning_threshold -is [long]) |
                Should -Be $true
        }
    }

    # -------------------------------------------------------------------------
    # default_trigger_hour  -  RANGE VALIDATION
    # Current behaviour: values outside [0,23] are replaced with the safe
    # default of 14.
    # -------------------------------------------------------------------------

    Context 'default_trigger_hour range validation' {
        It 'returns safe default 14 when default_trigger_hour = -1 (below range)' {
            # Seed an out-of-range value directly into config.json.
            $configPath = Join-Path $env:APPDATA 'DailyMotivationBrainHelper\config.json'
            @{ default_trigger_hour = -1; task_warning_threshold = 5 } |
                ConvertTo-Json | Set-Content $configPath -Encoding UTF8

            $cfg = Get-Config
            $cfg.default_trigger_hour | Should -Be 14
        }

        It 'returns safe default 14 when default_trigger_hour = 25 (above range)' {
            $configPath = Join-Path $env:APPDATA 'DailyMotivationBrainHelper\config.json'
            @{ default_trigger_hour = 25; task_warning_threshold = 5 } |
                ConvertTo-Json | Set-Content $configPath -Encoding UTF8

            $cfg = Get-Config
            $cfg.default_trigger_hour | Should -Be 14
        }

        It 'returns 0 when default_trigger_hour = 0 (lower boundary  -  valid)' {
            $configPath = Join-Path $env:APPDATA 'DailyMotivationBrainHelper\config.json'
            @{ default_trigger_hour = 0; task_warning_threshold = 5 } |
                ConvertTo-Json | Set-Content $configPath -Encoding UTF8

            $cfg = Get-Config
            $cfg.default_trigger_hour | Should -Be 0
        }

        It 'returns 23 when default_trigger_hour = 23 (upper boundary  -  valid)' {
            $configPath = Join-Path $env:APPDATA 'DailyMotivationBrainHelper\config.json'
            @{ default_trigger_hour = 23; task_warning_threshold = 5 } |
                ConvertTo-Json | Set-Content $configPath -Encoding UTF8

            $cfg = Get-Config
            $cfg.default_trigger_hour | Should -Be 23
        }
    }

    # -------------------------------------------------------------------------
    # default_trigger_hour  -  WRONG TYPE
    # Current behaviour: non-numeric string fails the type guard and is replaced
    # with the safe default of 14.
    # -------------------------------------------------------------------------

    Context 'default_trigger_hour wrong-type handling' {
        It 'returns safe default 14 when default_trigger_hour = "noon" (string  -  wrong type)' {
            # Write raw JSON so that "noon" is stored as a JSON string, not a number.
            $configPath = Join-Path $env:APPDATA 'DailyMotivationBrainHelper\config.json'
            '{"default_trigger_hour":"noon","task_warning_threshold":5}' |
                Set-Content $configPath -Encoding UTF8

            $cfg = Get-Config
            $cfg.default_trigger_hour | Should -Be 14
        }

        It 'returns safe default 14 when default_trigger_hour is null in JSON' {
            $configPath = Join-Path $env:APPDATA 'DailyMotivationBrainHelper\config.json'
            '{"default_trigger_hour":null,"task_warning_threshold":5}' |
                Set-Content $configPath -Encoding UTF8

            $cfg = Get-Config
            $cfg.default_trigger_hour | Should -Be 14
        }
    }

    # -------------------------------------------------------------------------
    # task_warning_threshold  -  RANGE AND TYPE VALIDATION
    # Current behaviour:
    #   negative values (< 0) → replaced with safe default 5
    #   0                      → returned as-is (guard only rejects < 0)
    # -------------------------------------------------------------------------

    Context 'task_warning_threshold range and type validation' {
        It 'returns safe default 5 when task_warning_threshold = -5 (negative)' {
            $configPath = Join-Path $env:APPDATA 'DailyMotivationBrainHelper\config.json'
            @{ default_trigger_hour = 14; task_warning_threshold = -5 } |
                ConvertTo-Json | Set-Content $configPath -Encoding UTF8

            $cfg = Get-Config
            $cfg.task_warning_threshold | Should -Be 5
        }

        It 'returns 0 when task_warning_threshold is 0 (guard rejects only < 0)' {
            # NOTE: 0 is a non-positive value and arguably invalid for a "warning threshold"
            # (AG20-016 gap). The current guard is (< 0), so 0 passes through without correction.
            # This test documents that gap rather than asserting aspirational validation.
            $configPath = Join-Path $env:APPDATA 'DailyMotivationBrainHelper\config.json'
            @{ default_trigger_hour = 14; task_warning_threshold = 0 } |
                ConvertTo-Json | Set-Content $configPath -Encoding UTF8

            $cfg = Get-Config
            $cfg.task_warning_threshold | Should -Be 0
        }

        It 'returns safe default 5 when task_warning_threshold is a string' {
            $configPath = Join-Path $env:APPDATA 'DailyMotivationBrainHelper\config.json'
            '{"default_trigger_hour":14,"task_warning_threshold":"five"}' |
                Set-Content $configPath -Encoding UTF8

            $cfg = Get-Config
            $cfg.task_warning_threshold | Should -Be 5
        }

        It 'returns safe default 5 when task_warning_threshold is null in JSON' {
            $configPath = Join-Path $env:APPDATA 'DailyMotivationBrainHelper\config.json'
            '{"default_trigger_hour":14,"task_warning_threshold":null}' |
                Set-Content $configPath -Encoding UTF8

            $cfg = Get-Config
            $cfg.task_warning_threshold | Should -Be 5
        }
    }

    # -------------------------------------------------------------------------
    # TYPE ASSERTIONS after out-of-range values are corrected
    # After validation the replacement literals (14 / 5) must themselves be
    # integer-typed so that callers receive a consistent type regardless of
    # what was stored on disk.
    # -------------------------------------------------------------------------

    Context 'Corrected values retain integer type' {
        It 'default_trigger_hour corrected from -1 is still an integer type' {
            $configPath = Join-Path $env:APPDATA 'DailyMotivationBrainHelper\config.json'
            @{ default_trigger_hour = -1; task_warning_threshold = 5 } |
                ConvertTo-Json | Set-Content $configPath -Encoding UTF8

            $cfg = Get-Config
            ($cfg.default_trigger_hour -is [int] -or $cfg.default_trigger_hour -is [long]) |
                Should -Be $true
        }

        It 'task_warning_threshold corrected from -5 is still an integer type' {
            $configPath = Join-Path $env:APPDATA 'DailyMotivationBrainHelper\config.json'
            @{ default_trigger_hour = 14; task_warning_threshold = -5 } |
                ConvertTo-Json | Set-Content $configPath -Encoding UTF8

            $cfg = Get-Config
            ($cfg.task_warning_threshold -is [int] -or $cfg.task_warning_threshold -is [long]) |
                Should -Be $true
        }
    }
}
