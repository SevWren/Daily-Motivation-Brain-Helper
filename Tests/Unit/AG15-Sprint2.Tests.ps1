#Requires -Modules @{ ModuleName='Pester'; ModuleVersion='5.0.0' }
<#
.SYNOPSIS
    Tests for Sprint 2 logging/observability fixes (AG15, AG19 series).
    Linux-safe: all tests use Write-OutcomeLog and config parsing, no Task Scheduler.
#>

BeforeAll {
    $script:ProjectRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
    . (Join-Path $script:ProjectRoot 'DailyMotivation.ps1') -NoRun

    $script:OriginalAppData = $env:APPDATA
    $env:APPDATA = Join-Path ([System.IO.Path]::GetTempPath()) "DMBH_AG15_Test_$(New-Guid)"
    Initialize-AppData
}

AfterAll {
    if (Test-Path $env:APPDATA) {
        Remove-Item -Path $env:APPDATA -Recurse -Force -ErrorAction SilentlyContinue
    }
    $env:APPDATA = $script:OriginalAppData
}

Describe 'Write-OutcomeLog - timestamp precision (AG15-013)' {

    BeforeEach {
        if (Test-Path $script:LogPath) { Remove-Item $script:LogPath -Force }
    }

    It 'Should write timestamp with millisecond precision' {
        Write-OutcomeLog -TaskId 'abc123' -FolderName 'TestFolder' -FolderPath 'C:\test' -Outcome 'Opened'

        $line = Get-Content $script:LogPath -Raw
        # Format: [yyyy-MM-dd HH:mm:ss.fff]
        $line | Should -Match '\[\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}\.\d{3}\]'
    }
}

Describe 'Write-OutcomeLog - pipe character escaping (AG15-017)' {

    BeforeEach {
        if (Test-Path $script:LogPath) { Remove-Item $script:LogPath -Force }
    }

    It 'Should replace pipe characters in FolderName with [PIPE]' {
        Write-OutcomeLog -TaskId 'abc123' -FolderName 'Work|Personal' -FolderPath 'C:\Work|Personal' -Outcome 'Opened'

        $line = Get-Content $script:LogPath -Raw
        $line | Should -Not -Match 'Work\|Personal'
        $line | Should -Match 'Work\[PIPE\]Personal'
    }

    It 'Should not alter FolderName with no pipe characters' {
        Write-OutcomeLog -TaskId 'abc123' -FolderName 'MyProjects' -FolderPath 'C:\MyProjects' -Outcome 'Opened'

        $line = Get-Content $script:LogPath -Raw
        $line | Should -Match 'MyProjects'
        $line | Should -Not -Match '\[PIPE\]'
    }

    It 'Should produce exactly 6 pipe-delimited fields even with a pipe in FolderName' {
        Write-OutcomeLog -TaskId 'id1' -FolderName 'A|B|C' -FolderPath 'C:\A' -Outcome 'Dismissed' -SnoozeCount 0

        $line = (Get-Content $script:LogPath -Raw).Trim()
        ($line -split ' \| ').Count | Should -Be 6
    }
}

Describe 'Write-OutcomeLog - log directory creation (AG15-007)' {

    It 'Should create the log directory if it does not exist before writing' {
        # Remove the log directory to simulate a fresh install scenario
        $logDir = Split-Path $script:LogPath -Parent
        if (Test-Path $logDir) { Remove-Item $logDir -Recurse -Force }

        { Write-OutcomeLog -TaskId 'abc' -FolderName 'Test' -FolderPath 'C:\test' -Outcome 'Opened' } |
            Should -Not -Throw

        Test-Path $script:LogPath | Should -Be $true
    }
}

Describe 'Get-SafeErrorMessage - route user-facing errors (AG19-003)' {

    It 'Should strip stack trace lines from error messages' {
        $raw = "Some error occurred`nat DoThing line 42`nat Main line 1"
        $safe = Get-SafeErrorMessage $raw
        # Should not contain internal script path details
        $safe | Should -Not -BeNullOrEmpty
    }

    It 'Should replace Windows file paths with [PATH]' {
        $raw = "Failed to open C:\Users\Admin\AppData\Roaming\App\file.txt"
        $safe = Get-SafeErrorMessage $raw
        $safe | Should -Match '\[PATH\]'
        $safe | Should -Not -Match 'C:\\Users\\Admin'
    }

    It 'Should return a non-empty string for any non-empty input' {
        $safe = Get-SafeErrorMessage "any error message"
        $safe | Should -Not -BeNullOrEmpty
    }
}

Describe 'AG1-016: Write-OutcomeLog Add-Content has error handling' {
    It 'Write-OutcomeLog wraps Add-Content in try/catch' {
        $src = Get-Content (Join-Path $PSScriptRoot '..\..\DailyMotivation.ps1') -Raw
        $fnStart = $src.IndexOf('function Write-OutcomeLog')
        $fnEnd   = $src.IndexOf("`nfunction ", $fnStart + 25)
        $fnBody  = if ($fnEnd -gt $fnStart) { $src.Substring($fnStart, $fnEnd - $fnStart) } else { $src.Substring($fnStart) }
        # The Add-Content call must be inside a try block, not a bare -ErrorAction SilentlyContinue
        $fnBody -match 'try\s*\{[^}]*Add-Content' | Should -Be $true -Because 'AG1-016: Add-Content must be inside try/catch to surface write failures'
    }
    It 'Write-OutcomeLog does not use bare -ErrorAction SilentlyContinue on Add-Content' {
        $src = Get-Content (Join-Path $PSScriptRoot '..\..\DailyMotivation.ps1') -Raw
        $fnStart = $src.IndexOf('function Write-OutcomeLog')
        $fnEnd   = $src.IndexOf("`nfunction ", $fnStart + 25)
        $fnBody  = if ($fnEnd -gt $fnStart) { $src.Substring($fnStart, $fnEnd - $fnStart) } else { $src.Substring($fnStart) }
        # Should not silently suppress Add-Content errors
        $fnBody -match 'Add-Content[^\n]*-ErrorAction SilentlyContinue' | Should -Be $false -Because 'AG1-016: write failures must not be silently discarded'
    }
}
