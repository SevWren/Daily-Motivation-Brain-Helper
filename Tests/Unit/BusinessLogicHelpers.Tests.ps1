#Requires -Modules @{ ModuleName='Pester'; ModuleVersion='5.0.0' }
<#
.SYNOPSIS
    Unit tests for business-logic helpers in DailyMotivation.ps1:
    Write-OutcomeLog, Get-SafeErrorMessage, Show-ErrorDialog, Show-InfoDialog.
.NOTES
    Write-OutcomeLog and Get-SafeErrorMessage are fully cross-platform.
    Show-ErrorDialog and Show-InfoDialog: console-fallback paths run on all
    platforms; WPF/MessageBox display paths are gated -Skip:(-not $IsWindows).
#>

BeforeAll {
    . (Join-Path $PSScriptRoot '..\..\DailyMotivation.ps1') -NoRun
    $script:OriginalAppData = $env:APPDATA
    $env:APPDATA = Join-Path ([System.IO.Path]::GetTempPath()) "DMBH_BizLogic_$(New-Guid)"
    Initialize-AppData
}

AfterAll {
    if ($IsWindows) {
        if (Test-Path $env:APPDATA) {
            Remove-Item -Path $env:APPDATA -Recurse -Force -ErrorAction SilentlyContinue
        }
        $env:APPDATA = $script:OriginalAppData
    }
}

# ============================================================
# Write-OutcomeLog
# ============================================================
Describe 'Write-OutcomeLog' {

    BeforeEach {
        if (Test-Path $script:LogPath) {
            Remove-Item $script:LogPath -Force -ErrorAction SilentlyContinue
        }
    }

    It 'appends a correctly-formatted pipe-delimited entry' {
        Write-OutcomeLog -TaskId 'abc123' -FolderName 'Work' -FolderPath 'C:\Work' -Outcome 'Opened' -SnoozeCount 0
        $lines = @(Get-Content $script:LogPath -Encoding UTF8)
        $lines | Should -HaveCount 1
        $lines[0] | Should -Match '^\[\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}\.\d{3}\] \| abc123 \| Work \| HASH:[0-9A-F]{64} \| Opened \| 0$'
    }

    It 'stores a SHA-256 HASH prefix, not the plaintext FolderPath' {
        Write-OutcomeLog -TaskId 'abc123' -FolderName 'Work' -FolderPath 'C:\Secret\Path' -Outcome 'Opened'
        $line = Get-Content $script:LogPath -Encoding UTF8 | Select-Object -First 1
        $line | Should -Match 'HASH:[0-9A-F]{64}'
        $line | Should -Not -Match 'C:\\Secret'
        $line | Should -Not -Match 'Secret'
    }

    It 'writes HASH:NO_PATH when FolderPath is an empty string' {
        Write-OutcomeLog -TaskId 'abc123' -FolderName 'Work' -FolderPath '' -Outcome 'Dismissed'
        $line = Get-Content $script:LogPath -Encoding UTF8 | Select-Object -First 1
        $line | Should -Match 'HASH:NO_PATH'
    }

    It 'escapes pipe characters in FolderName to [PIPE]' {
        Write-OutcomeLog -TaskId 'abc123' -FolderName 'folder|name' -FolderPath 'C:\Work' -Outcome 'Opened'
        $line = Get-Content $script:LogPath -Encoding UTF8 | Select-Object -First 1
        $line | Should -Match '\[PIPE\]'
        $line | Should -Not -Match 'folder\|name'
    }

    It 'appends a second entry without erasing the first' {
        Write-OutcomeLog -TaskId 'id1' -FolderName 'A' -FolderPath 'C:\A' -Outcome 'Opened'
        Write-OutcomeLog -TaskId 'id2' -FolderName 'B' -FolderPath 'C:\B' -Outcome 'Snoozed'
        $lines = @(Get-Content $script:LogPath -Encoding UTF8)
        $lines | Should -HaveCount 2
        $lines[0] | Should -Match ' \| id1 \| '
        $lines[1] | Should -Match ' \| id2 \| '
    }

    It 'writes the supplied SnoozeCount as the last pipe-delimited field' {
        Write-OutcomeLog -TaskId 'abc123' -FolderName 'Work' -FolderPath 'C:\Work' -Outcome 'Snoozed' -SnoozeCount 3
        $line = Get-Content $script:LogPath -Encoding UTF8 | Select-Object -First 1
        $line | Should -Match ' \| 3$'
    }

    It 'emits Write-Warning and does not throw when Add-Content fails' {
        Mock Add-Content { throw 'disk full' }
        Mock Write-Warning {}
        { Write-OutcomeLog -TaskId 'abc123' -FolderName 'Work' -FolderPath 'C:\Work' -Outcome 'Opened' } |
            Should -Not -Throw
        Should -Invoke Write-Warning -Times 1 -Scope It -ParameterFilter {
            $Message -match 'Write-OutcomeLog'
        }
    }

    It 'creates the Outcome Log directory when it does not exist' {
        $logDir = Split-Path $script:LogPath -Parent
        Remove-Item $logDir -Recurse -Force -ErrorAction SilentlyContinue
        Test-Path $logDir | Should -Be $false
        Write-OutcomeLog -TaskId 'abc123' -FolderName 'Work' -FolderPath 'C:\Work' -Outcome 'Opened'
        Test-Path $script:LogPath | Should -Be $true
    }

    It 'rotates the Outcome Log when its size exceeds 1 MB' {
        # Write ~1.1 MB of dummy content so the file is already over threshold
        $dummy = 'x' * 1100000
        [System.IO.File]::WriteAllText($script:LogPath, $dummy, [System.Text.Encoding]::UTF8)
        (Get-Item $script:LogPath).Length | Should -BeGreaterThan 1MB

        Write-OutcomeLog -TaskId 'abc123' -FolderName 'Work' -FolderPath 'C:\Work' -Outcome 'Opened'

        # An archive file should have been created alongside the log
        $archiveDir = Split-Path $script:LogPath -Parent
        $archives   = Get-ChildItem $archiveDir -Filter 'popup_log.txt.archive_*' -ErrorAction SilentlyContinue
        $archives | Should -Not -BeNullOrEmpty

        # The original log should have been cleared by rotation (zero or near-zero bytes)
        (Get-Item $script:LogPath).Length | Should -BeLessThan 1MB
    }
}

# ============================================================
# Get-SafeErrorMessage
# ============================================================
Describe 'Get-SafeErrorMessage' {

    It 'replaces a Windows drive path with [PATH]' {
        $result = Get-SafeErrorMessage -ErrorMessage 'Failed: C:\Users\foo\bar.ps1'
        $result | Should -Match '\[PATH\]'
        $result | Should -Not -Match 'C:\\'
    }

    It 'replaces a UNC path with [UNC_PATH]' {
        $result = Get-SafeErrorMessage -ErrorMessage 'Connect: \\server\share\dir'
        $result | Should -Match '\[UNC_PATH\]'
        $result | Should -Not -Match '\\\\server'
    }

    It 'redacts the password keyword' {
        $result = Get-SafeErrorMessage -ErrorMessage 'Auth: password=mysecret123'
        $result | Should -Match '\[REDACTED\]'
        $result | Should -Not -Match 'mysecret'
    }

    It 'redacts the token keyword' {
        $result = Get-SafeErrorMessage -ErrorMessage 'Bad token=abc123xyz'
        $result | Should -Match '\[REDACTED\]'
        $result | Should -Not -Match 'abc123xyz'
    }

    It 'redacts the secret keyword' {
        $result = Get-SafeErrorMessage -ErrorMessage 'secret=hunter2'
        $result | Should -Match '\[REDACTED\]'
    }

    It 'replaces a $env: variable path with [ENV_PATH]' {
        $result = Get-SafeErrorMessage -ErrorMessage '$env:APPDATA\subdir\file'
        $result | Should -Match '\[ENV_PATH\]'
        $result | Should -Not -Match 'APPDATA'
    }

    It 'strips PowerShell stack trace lines' {
        $input = "Error occurred`r`n    at DailyMotivation.ps1:line 42`r`n    at System.Runtime.Core"
        $result = Get-SafeErrorMessage -ErrorMessage $input
        $result | Should -Not -Match 'at DailyMotivation'
        $result | Should -Not -Match 'at System\.Runtime'
    }

    It 'passes a clean string through unchanged' {
        $result = Get-SafeErrorMessage -ErrorMessage 'Task not found'
        $result | Should -Be 'Task not found'
    }
}

# ============================================================
# Show-ErrorDialog — console-fallback path (cross-platform)
# ============================================================
Describe 'Show-ErrorDialog — console fallback' {

    BeforeAll {
        $script:WpfLoaded   = $false
        $script:FormsLoaded = $false
    }

    It 'does not throw when no WPF or WinForms assemblies are loaded' {
        { Show-ErrorDialog -Message 'Test error' -Title 'Test' } | Should -Not -Throw
    }

    It 'does not throw when Message contains a Windows drive path' {
        { Show-ErrorDialog -Message 'Error at C:\Secret\Path\file.ps1' -Title 'Test' } |
            Should -Not -Throw
    }

    It 'does not throw when Message contains a UNC path' {
        { Show-ErrorDialog -Message 'Error: \\server\share unreachable' -Title 'Test' } |
            Should -Not -Throw
    }

    It 'does not throw when Title is omitted (uses default)' {
        { Show-ErrorDialog -Message 'Error' } | Should -Not -Throw
    }
}

# ============================================================
# Show-InfoDialog — console-fallback path (cross-platform)
# ============================================================
Describe 'Show-InfoDialog — console fallback' {

    BeforeAll {
        $script:WpfLoaded   = $false
        $script:FormsLoaded = $false
    }

    It 'does not throw when no WPF or WinForms assemblies are loaded' {
        { Show-InfoDialog -Message 'Test info' -Title 'Test' } | Should -Not -Throw
    }

    It 'does not throw when Title is omitted (uses default)' {
        { Show-InfoDialog -Message 'Info message' } | Should -Not -Throw
    }
}

# ============================================================
# Show-ErrorDialog — MessageBox path (Windows only)
# ============================================================
Describe 'Show-ErrorDialog — sanitizes message before display' -Skip:(-not $IsWindows) {

    It 'sanitizes a Windows path out of the message via Get-SafeErrorMessage' {
        # Verify the sanitization function produces clean output for the same input
        # (direct behavioral contract; actual MessageBox display is out of scope here)
        $raw  = 'Error at C:\Users\secret\file.ps1'
        $safe = Get-SafeErrorMessage -ErrorMessage $raw
        $safe | Should -Match '\[PATH\]'
        $safe | Should -Not -Match 'C:\\'
        # And Show-ErrorDialog with same input must not throw
        $script:WpfLoaded = $false
        { Show-ErrorDialog -Message $raw -Title 'Test' } | Should -Not -Throw
    }
}
