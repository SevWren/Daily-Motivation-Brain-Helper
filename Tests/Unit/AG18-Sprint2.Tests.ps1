#Requires -Modules @{ ModuleName='Pester'; ModuleVersion='5.0.0' }
<#
.SYNOPSIS
    Tests for Sprint 2 data-integrity fixes (AG18 series).
    Linux-safe: all tests use pure data manipulation with no Task Scheduler calls.
#>

BeforeAll {
    $script:ProjectRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
    . (Join-Path $script:ProjectRoot 'DailyMotivation.ps1') -NoRun

    $script:OriginalAppData = $env:APPDATA
    $env:APPDATA = Join-Path ([System.IO.Path]::GetTempPath()) "DMBH_AG18_Test_$(New-Guid)"
    Initialize-AppData
}

AfterAll {
    if (Test-Path $env:APPDATA) {
        Remove-Item -Path $env:APPDATA -Recurse -Force -ErrorAction SilentlyContinue
    }
    $env:APPDATA = $script:OriginalAppData
}

Describe 'Get-TasksJson - null element filtering (AG18-018)' {

    BeforeEach {
        '[]' | Set-Content $script:TasksPath -Encoding UTF8 -Force
    }

    It 'Should strip null elements from tasks.json on load' {
        # Write a JSON array containing a null literal
        '[{"task_id":"abc123","status":"PENDING","folder_path":"C:\\test"},null]' |
            Set-Content $script:TasksPath -Encoding UTF8 -Force

        $tasks = Get-TasksJson
        $tasks | Should -Not -BeNullOrEmpty
        $tasks.Count | Should -Be 1
        $tasks[0].task_id | Should -Be 'abc123'
    }

    It 'Should return empty array when tasks.json contains only nulls' {
        '[null, null]' | Set-Content $script:TasksPath -Encoding UTF8 -Force

        $tasks = Get-TasksJson
        @($tasks).Count | Should -Be 0
    }
}

Describe 'Get-TasksJson - invalid task filtering (AG18-010)' {

    BeforeEach {
        '[]' | Set-Content $script:TasksPath -Encoding UTF8 -Force
    }

    It 'Should filter out tasks with empty task_id' {
        '[{"task_id":"","status":"PENDING","folder_path":"C:\\test"}]' |
            Set-Content $script:TasksPath -Encoding UTF8 -Force

        $tasks = Get-TasksJson
        @($tasks).Count | Should -Be 0
    }

    It 'Should filter out tasks with missing task_id field' {
        '[{"status":"PENDING","folder_path":"C:\\test"}]' |
            Set-Content $script:TasksPath -Encoding UTF8 -Force

        $tasks = Get-TasksJson
        @($tasks).Count | Should -Be 0
    }

    It 'Should filter out tasks with UNKNOWN status' {
        # UNKNOWN is the normalised value for unrecognised status strings
        '[{"task_id":"abc123","status":"BOGUS_STATUS","folder_path":"C:\\test"}]' |
            Set-Content $script:TasksPath -Encoding UTF8 -Force

        $tasks = Get-TasksJson
        @($tasks).Count | Should -Be 0
    }

    It 'Should return valid tasks alongside invalid ones' {
        '[{"task_id":"good1","status":"PENDING","folder_path":"C:\\good"},{"task_id":"","status":"PENDING","folder_path":"C:\\bad"}]' |
            Set-Content $script:TasksPath -Encoding UTF8 -Force

        $tasks = Get-TasksJson
        @($tasks).Count | Should -Be 1
        $tasks[0].task_id | Should -Be 'good1'
    }
}

Describe 'Save-TasksJson - null element stripping (AG18-018)' {

    BeforeEach {
        '[]' | Set-Content $script:TasksPath -Encoding UTF8 -Force
    }

    It 'Should not write null literals when Tasks array contains $null entries' {
        $good = [PSCustomObject]@{ task_id = 'abc'; status = 'PENDING'; folder_path = 'C:\test' }
        Save-TasksJson @($good, $null, $null)

        $raw = Get-Content $script:TasksPath -Raw
        $raw | Should -Not -Match 'null'
        $raw | Should -Match 'abc'
    }
}

Describe 'Get-Config - BOM stripping (AG18-005)' {

    BeforeEach {
        $null | Out-Null  # ensure $script:ConfigPath is accessible
    }

    It 'Should parse config correctly when file has UTF-8 BOM' {
        # Write config with UTF-8 BOM prefix (U+FEFF as EF BB BF)
        $content = '{"default_trigger_hour":9,"task_warning_threshold":3}'
        $bytes   = [System.Text.Encoding]::UTF8.GetPreamble() +
                   [System.Text.Encoding]::UTF8.GetBytes($content)
        [System.IO.File]::WriteAllBytes($script:ConfigPath, $bytes)

        $cfg = Get-Config
        $cfg.default_trigger_hour | Should -Be 9
        $cfg.task_warning_threshold | Should -Be 3
    }

    It 'Should not alter config when file has no BOM' {
        '{"default_trigger_hour":10,"task_warning_threshold":7}' |
            Set-Content $script:ConfigPath -Encoding UTF8 -Force

        $cfg = Get-Config
        $cfg.default_trigger_hour | Should -Be 10
    }
}

Describe 'Get-Config - task_warning_threshold upper bound (AG18-025)' {

    It 'Should reset task_warning_threshold to 5 when value exceeds 100' {
        '{"default_trigger_hour":14,"task_warning_threshold":999999}' |
            Set-Content $script:ConfigPath -Encoding UTF8 -Force

        $cfg = Get-Config
        $cfg.task_warning_threshold | Should -Be 5
    }

    It 'Should accept task_warning_threshold values within valid range' {
        '{"default_trigger_hour":14,"task_warning_threshold":20}' |
            Set-Content $script:ConfigPath -Encoding UTF8 -Force

        $cfg = Get-Config
        $cfg.task_warning_threshold | Should -Be 20
    }

    It 'Should accept task_warning_threshold of exactly 100' {
        '{"default_trigger_hour":14,"task_warning_threshold":100}' |
            Set-Content $script:ConfigPath -Encoding UTF8 -Force

        $cfg = Get-Config
        $cfg.task_warning_threshold | Should -Be 100
    }
}
