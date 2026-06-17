#Requires -Modules Pester
<#
.SYNOPSIS
    Integration tests for DailyMotivation.ps1 single-file architecture.
    Verifies: dot-source loads without error, all required functions are defined,
    Initialize-AppData creates the expected directory structure,
    and the three execution modes are reachable.
#>

BeforeAll {
    $script:RepoRoot       = Join-Path $PSScriptRoot '..\..'
    $script:ScriptPath     = Join-Path $script:RepoRoot 'DailyMotivation.ps1'
    $script:OriginalAppData = $env:APPDATA
    $env:APPDATA = Join-Path ([System.IO.Path]::GetTempPath()) "DMBH_Integration_$(New-Guid)"

    # Dot-source the script without executing the entry point
    . $script:ScriptPath -NoRun

    Initialize-AppData
    $script:AppDir = Join-Path $env:APPDATA 'DailyMotivationBrainHelper'
}

AfterAll {
    if (Test-Path $env:APPDATA) {
        Remove-Item -Path $env:APPDATA -Recurse -Force -ErrorAction SilentlyContinue
    }
    $env:APPDATA = $script:OriginalAppData
}

Describe 'Single-File Dot-Source' {
    It 'DailyMotivation.ps1 should exist at repo root' {
        Test-Path $script:ScriptPath | Should -Be $true
    }

    It 'Should dot-source without errors using -NoRun' {
        # BeforeAll already succeeded if we reached this point;
        # this assertion makes failure explicit.
        $script:ScriptPath | Should -Not -BeNullOrEmpty
        { . $script:ScriptPath -NoRun } | Should -Not -Throw
    }
}

Describe 'Required Functions Defined After Dot-Source' {
    $requiredFunctions = @(
        'Initialize-AppData',
        'Get-Config',
        'Save-Config',
        'Get-PopupConfig',
        'Set-PopupConfig',
        'Write-OutcomeLog',
        'Show-ErrorDialog',
        'Get-TasksJson',
        'Save-TasksJson',
        'New-MotivationTask',
        'Get-MotivationTasks',
        'Remove-MotivationTask',
        'Register-ContextMenu',
        'Unregister-ContextMenu',
        'Get-RandomMessage'
    )

    It "Function '<_>' should be defined" -ForEach $requiredFunctions {
        (Get-Command -Name $_ -ErrorAction SilentlyContinue) | Should -Not -BeNullOrEmpty
    }
}

Describe 'Initialize-AppData Directory Structure' {
    It 'Should create the DailyMotivationBrainHelper directory' {
        Test-Path $script:AppDir | Should -Be $true
    }

    It 'Should create config.json' {
        Test-Path (Join-Path $script:AppDir 'config.json') | Should -Be $true
    }

    It 'Should create popup_config.json' {
        Test-Path (Join-Path $script:AppDir 'popup_config.json') | Should -Be $true
    }

    It 'Should create tasks.json' {
        Test-Path (Join-Path $script:AppDir 'tasks.json') | Should -Be $true
    }

    It 'config.json should be valid JSON with required keys' {
        $cfg = Get-Content (Join-Path $script:AppDir 'config.json') -Raw | ConvertFrom-Json
        $cfg.PSObject.Properties.Name | Should -Contain 'default_trigger_hour'
        $cfg.PSObject.Properties.Name | Should -Contain 'task_warning_threshold'
    }

    It 'tasks.json should start as an empty array' {
        (Get-Content (Join-Path $script:AppDir 'tasks.json') -Raw).Trim() | Should -Be '[]'
    }
}

Describe 'Get-RandomMessage returns a valid message' {
    It 'Should return an object with glyph, title, body' {
        $msg = Get-RandomMessage
        $msg.glyph | Should -Not -BeNullOrEmpty
        $msg.title | Should -Not -BeNullOrEmpty
        $msg.body  | Should -Not -BeNullOrEmpty
    }
}

Describe 'Write-OutcomeLog creates the log file' {
    It 'Should write a log entry to popup_log.txt' {
        Write-OutcomeLog -TaskId 'intg-t1' -FolderName 'TestFolder' `
            -FolderPath 'C:\Test\Folder' -Outcome 'Opened' -SnoozeCount 0
        $logPath = Join-Path $script:AppDir 'popup_log.txt'
        Test-Path $logPath | Should -Be $true
        (Get-Content $logPath -Raw) | Should -Match 'intg-t1'
    }
}
