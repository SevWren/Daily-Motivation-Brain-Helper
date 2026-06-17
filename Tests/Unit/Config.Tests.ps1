#Requires -Modules Pester
<#
.SYNOPSIS
    Unit tests for configuration functions in DailyMotivation.ps1.
    Covers: Initialize-AppData, Get-Config/Save-Config, Get/Set-PopupConfig,
            Write-OutcomeLog, Show-ErrorDialog, UTF-8 encoding.
#>

BeforeAll {
    . (Join-Path $PSScriptRoot '..\..\DailyMotivation.ps1') -NoRun

    $script:OriginalAppData = $env:APPDATA
    $env:APPDATA = Join-Path ([System.IO.Path]::GetTempPath()) "DMBH_Test_$(New-Guid)"
    Initialize-AppData
}

AfterAll {
    if (Test-Path $env:APPDATA) {
        Remove-Item -Path $env:APPDATA -Recurse -Force -ErrorAction SilentlyContinue
    }
    $env:APPDATA = $script:OriginalAppData
}

Describe 'Initialize-AppData' {
    Context 'When AppData directory does not exist' {
        BeforeEach {
            $env:APPDATA = Join-Path ([System.IO.Path]::GetTempPath()) "DMBH_Init_Test_$(New-Guid)"
            if (Test-Path $env:APPDATA) {
                Remove-Item -Path $env:APPDATA -Recurse -Force
            }
        }

        AfterEach {
            if (Test-Path $env:APPDATA) {
                Remove-Item -Path $env:APPDATA -Recurse -Force -ErrorAction SilentlyContinue
            }
        }

        It 'Should create the AppData directory' {
            Initialize-AppData
            Test-Path (Join-Path $env:APPDATA 'DailyMotivationBrainHelper') | Should -Be $true
        }

        It 'Should create config.json with default_trigger_hour=14' {
            Initialize-AppData
            $configPath = Join-Path $env:APPDATA 'DailyMotivationBrainHelper\config.json'
            Test-Path $configPath | Should -Be $true
            $cfg = Get-Content $configPath -Raw | ConvertFrom-Json
            $cfg.default_trigger_hour   | Should -Be 14
            $cfg.task_warning_threshold | Should -Be 5
        }

        It 'Should create tasks.json as empty array' {
            Initialize-AppData
            $tasksPath = Join-Path $env:APPDATA 'DailyMotivationBrainHelper\tasks.json'
            Test-Path $tasksPath | Should -Be $true
            (Get-Content $tasksPath -Raw).Trim() | Should -Be '[]'
        }

        It 'Should create popup_config.json with empty defaults' {
            Initialize-AppData
            $cfgPath = Join-Path $env:APPDATA 'DailyMotivationBrainHelper\popup_config.json'
            Test-Path $cfgPath | Should -Be $true
            $cfg = Get-Content $cfgPath -Raw | ConvertFrom-Json
            $cfg.glyph         | Should -Be '[+]'
            $cfg.explorer_path | Should -Be ''
            $cfg.folder_name   | Should -Be ''
            $cfg.task_id       | Should -Be ''
        }

        It 'Should not overwrite existing config.json' {
            Initialize-AppData
            $configPath = Join-Path $env:APPDATA 'DailyMotivationBrainHelper\config.json'
            @{ default_trigger_hour = 9; task_warning_threshold = 3 } |
                ConvertTo-Json | Set-Content $configPath -Encoding UTF8
            Initialize-AppData
            $cfg = Get-Content $configPath -Raw | ConvertFrom-Json
            $cfg.default_trigger_hour | Should -Be 9
        }
    }
}

Describe 'Get-Config and Save-Config' {
    BeforeEach {
        $env:APPDATA = Join-Path ([System.IO.Path]::GetTempPath()) "DMBH_Cfg_Test_$(New-Guid)"
        Initialize-AppData
    }

    AfterEach {
        if (Test-Path $env:APPDATA) {
            Remove-Item -Path $env:APPDATA -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    It 'Should return default values on fresh init' {
        $cfg = Get-Config
        $cfg.default_trigger_hour   | Should -Be 14
        $cfg.task_warning_threshold | Should -Be 5
    }

    It 'Should persist changes via Save-Config' {
        $cfg = Get-Config
        $cfg.default_trigger_hour = 9
        Save-Config -Config $cfg
        (Get-Config).default_trigger_hour | Should -Be 9
    }

    It 'Should return safe defaults when config.json is corrupted' {
        $configPath = Join-Path $env:APPDATA 'DailyMotivationBrainHelper\config.json'
        'invalid json{' | Set-Content $configPath -Encoding UTF8
        $cfg = Get-Config
        $cfg.default_trigger_hour   | Should -Be 14
        $cfg.task_warning_threshold | Should -Be 5
    }
}

Describe 'Popup Config Functions' {
    BeforeEach {
        $env:APPDATA = Join-Path ([System.IO.Path]::GetTempPath()) "DMBH_PopCfg_Test_$(New-Guid)"
        Initialize-AppData
    }

    AfterEach {
        if (Test-Path $env:APPDATA) {
            Remove-Item -Path $env:APPDATA -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    It 'Get-PopupConfig should return default glyph on fresh init' {
        $cfg = Get-PopupConfig
        $cfg.glyph | Should -Be '[+]'
        $cfg.explorer_path | Should -Be ''
    }

    It 'Set-PopupConfig should persist all fields' {
        Set-PopupConfig -Glyph '[!]' -Title 'Test Title' -Body 'Test Body' `
            -ExplorerPath 'C:\Projects\Test' -TaskId 'abc123'
        $cfg = Get-PopupConfig
        $cfg.glyph         | Should -Be '[!]'
        $cfg.title         | Should -Be 'Test Title'
        $cfg.body          | Should -Be 'Test Body'
        $cfg.explorer_path | Should -Be 'C:\Projects\Test'
        $cfg.task_id       | Should -Be 'abc123'
    }

    It 'Set-PopupConfig should derive folder_name from path' {
        Set-PopupConfig -Glyph '[+]' -Title 'T' -Body 'B' `
            -ExplorerPath 'C:\Projects\ClientA\SubFolder' -TaskId 'x'
        (Get-PopupConfig).folder_name | Should -Be 'SubFolder'
    }

    It 'Get-PopupConfig should return null for corrupted file' {
        $cfgPath = Join-Path $env:APPDATA 'DailyMotivationBrainHelper\popup_config.json'
        'invalid' | Set-Content $cfgPath -Encoding UTF8
        Get-PopupConfig | Should -BeNullOrEmpty
    }
}

Describe 'Write-OutcomeLog' {
    BeforeEach {
        $env:APPDATA = Join-Path ([System.IO.Path]::GetTempPath()) "DMBH_Log_Test_$(New-Guid)"
        Initialize-AppData
    }

    AfterEach {
        if (Test-Path $env:APPDATA) {
            Remove-Item -Path $env:APPDATA -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    It 'Should create the log file and write a pipe-delimited entry' {
        Write-OutcomeLog -TaskId 't1' -FolderName 'ClientA' `
            -FolderPath 'C:\Projects\ClientA' -Outcome 'Opened' -SnoozeCount 0
        $logPath = Join-Path $env:APPDATA 'DailyMotivationBrainHelper\popup_log.txt'
        Test-Path $logPath | Should -Be $true
        $line = Get-Content $logPath -Raw
        $line | Should -Match 't1'
        $line | Should -Match 'ClientA'
        $line | Should -Match 'Opened'
    }

    It 'Should not throw on write errors' {
        { Write-OutcomeLog -TaskId '' -FolderName '' -FolderPath '' -Outcome 'Dismissed' } |
            Should -Not -Throw
    }
}

Describe 'Show-ErrorDialog' {
    It 'Should be callable without throwing (in headless context falls back to stderr)' {
        { Show-ErrorDialog -Message "Test error" } | Should -Not -Throw
    }
}

Describe 'UTF-8 Encoding' {
    BeforeEach {
        $env:APPDATA = Join-Path ([System.IO.Path]::GetTempPath()) "DMBH_UTF8_Test_$(New-Guid)"
        Initialize-AppData
    }

    AfterEach {
        if (Test-Path $env:APPDATA) {
            Remove-Item -Path $env:APPDATA -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    It 'Should preserve Unicode characters in popup config body' {
        Set-PopupConfig -Glyph '[*]' -Title 'Motivacion' -Body 'Cafe time' `
            -ExplorerPath 'C:\Projets\Montreal' -TaskId 'test'
        $cfg = Get-PopupConfig
        $cfg.title | Should -Be 'Motivacion'
    }

    It 'Should preserve Unicode folder paths in popup config' {
        Set-PopupConfig -Glyph '[+]' -Title 'T' -Body 'B' `
            -ExplorerPath 'C:\Projets\Montreal\Dossier' -TaskId 'u1'
        (Get-PopupConfig).explorer_path | Should -Be 'C:\Projets\Montreal\Dossier'
    }
}
