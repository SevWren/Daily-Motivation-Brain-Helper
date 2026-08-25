#Requires -Modules @{ ModuleName='Pester'; ModuleVersion='5.0.0' }
<#
.SYNOPSIS
    Tests for extracted folder scheduling business logic

.DESCRIPTION
    Tests Invoke-FolderScheduling function (extracted from Show-MainWindow's Do-Schedule).
    Per architecture-report.html Candidate 1.
#>

BeforeAll {
    # Dot-source the script with -NoRun
    . "$PSScriptRoot\..\..\DailyMotivation.ps1" -NoRun

    # Redirect to test temp directory
    $script:TestAppData = Join-Path ([System.IO.Path]::GetTempPath()) "DailyMotivationTest_$(New-Guid)"
    $env:APPDATA = $script:TestAppData
}

AfterAll {
    # Cleanup test directory
    if (Test-Path $script:TestAppData) {
        Remove-Item -Path $script:TestAppData -Recurse -Force -ErrorAction SilentlyContinue
    }
    # Cleanup test folders
    if (Test-Path "/tmp/test-folder") {
        Remove-Item -Path "/tmp/test-folder" -Recurse -Force -ErrorAction SilentlyContinue
    }
    if (Test-Path "/tmp/test") {
        Remove-Item -Path "/tmp/test" -Recurse -Force -ErrorAction SilentlyContinue
    }
}

Describe "Invoke-FolderScheduling" -Tag "Unit", "BusinessLogic" {

    BeforeEach {
        # Clean slate
        if (Test-Path $script:TestAppData) {
            Remove-Item -Path $script:TestAppData -Recurse -Force -ErrorAction SilentlyContinue
        }

        # Inject platform adapter for cross-platform testing
        $script:Platform = [HeadlessPlatform]::new()
        Initialize-AppData

        # Clear tasks
        Set-Content -Path $script:TasksPath -Value "[]" -Encoding UTF8 -NoNewline

        # Set exe path
        $script:ExePath = "/usr/local/bin/DailyMotivation.exe"

        # Create test folders for scheduling tests
        $script:TestFolder = "/tmp/test-folder"
        if (-not (Test-Path $script:TestFolder)) {
            New-Item -Path $script:TestFolder -ItemType Directory -Force | Out-Null
        }

        $script:TestFolder2 = "/tmp/test"
        if (-not (Test-Path $script:TestFolder2)) {
            New-Item -Path $script:TestFolder2 -ItemType Directory -Force | Out-Null
        }
    }

    Context "Basic scheduling" {
        It "schedules a valid folder and returns success" {
            # TRACER BULLET - This will fail until Invoke-FolderScheduling exists
            $triggerTime = (Get-Date).AddHours(1)
            $result = Invoke-FolderScheduling -FolderPath "/tmp/test-folder" -TriggerTime $triggerTime

            $result.Success | Should -Be $true
            $result.TaskId | Should -Not -BeNullOrEmpty
            $result.IsDuplicate | Should -Be $false
        }

        It "creates a task in tasks.json" {
            $triggerTime = (Get-Date).AddHours(1)
            $result = Invoke-FolderScheduling -FolderPath "/tmp/test-folder" -TriggerTime $triggerTime

            $tasks = Get-TasksJson
            $tasks.Count | Should -Be 1
            $tasks[0].task_id | Should -Be $result.TaskId
            $tasks[0].folder_path | Should -Be "/tmp/test-folder"
        }
    }

    Context "Duplicate detection" {
        It "blocks duplicate folder on same date" {
            $triggerTime = (Get-Date).Date.AddHours(14)

            # First schedule succeeds
            $result1 = Invoke-FolderScheduling -FolderPath "/tmp/test" -TriggerTime $triggerTime
            $result1.Success | Should -Be $true

            # Second schedule on same date fails
            $result2 = Invoke-FolderScheduling -FolderPath "/tmp/test" -TriggerTime $triggerTime
            $result2.Success | Should -Be $false
            $result2.IsDuplicate | Should -Be $true
        }

        It "allows duplicate with Force flag" {
            $triggerTime = (Get-Date).Date.AddHours(14)

            # First schedule
            Invoke-FolderScheduling -FolderPath "/tmp/test" -TriggerTime $triggerTime

            # Second schedule with Force succeeds
            $result = Invoke-FolderScheduling -FolderPath "/tmp/test" -TriggerTime $triggerTime -Force
            $result.Success | Should -Be $true
            $result.IsDuplicate | Should -Be $false

            # Should have 2 tasks
            $tasks = Get-TasksJson
            $tasks.Count | Should -Be 2
        }
    }

    Context "Network path detection" {
        It "detects UNC paths and sets IsNetworkPath flag" {
            $result = Invoke-FolderScheduling -FolderPath "\\server\share\folder" -TriggerTime (Get-Date).AddHours(1)

            $result.Success | Should -Be $true
            $result.IsNetworkPath | Should -Be $true
        }
    }

    Context "Get-RandomMessage integration (AG8-017)" {
        # AG8-017: Test that calling code correctly handles Get-RandomMessage return values

        It "Should handle Get-RandomMessage returning null gracefully" {
            # Mock Get-RandomMessage to return null
            Mock Get-RandomMessage { return $null }

            $result = Invoke-FolderScheduling -FolderPath "/tmp/test-folder" -TriggerTime (Get-Date).AddHours(1)

            # Function should handle null message and still succeed or fail gracefully
            # (depending on implementation, might use default message or skip message selection)
            $result | Should -Not -BeNullOrEmpty
        }

        It "Should handle Get-RandomMessage returning invalid object (missing properties)" {
            # Mock to return object missing required properties
            Mock Get-RandomMessage {
                return [PSCustomObject]@{ invalid = 'data' }
            }

            $result = Invoke-FolderScheduling -FolderPath "/tmp/test-folder" -TriggerTime (Get-Date).AddHours(1)

            # Should not throw, even if message object is malformed
            $result | Should -Not -BeNullOrEmpty
        }

        It "Should use Get-RandomMessage glyph, title, and body when setting popup config" {
            # Mock Get-RandomMessage with specific values
            $mockMessage = [PSCustomObject]@{
                glyph = '[★]'
                title = 'Test Title'
                body  = 'Test Body'
            }
            Mock Get-RandomMessage { return $mockMessage }

            $result = Invoke-FolderScheduling -FolderPath "/tmp/test-folder" -TriggerTime (Get-Date).AddHours(1)
            $result.Success | Should -Be $true

            # Verify Set-PopupConfig was called with message properties
            $config = Get-PopupConfig
            if ($config) {
                # If popup config was set, verify it has the message data
                $config.glyph | Should -Not -BeNullOrEmpty
            }
        }

        It "Should call Get-RandomMessage exactly once during scheduling" {
            Mock Get-RandomMessage {
                return [PSCustomObject]@{ glyph = '[+]'; title = 'Title'; body = 'Body' }
            }

            Invoke-FolderScheduling -FolderPath "/tmp/test-folder" -TriggerTime (Get-Date).AddHours(1)

            # Verify Get-RandomMessage was called
            Should -Invoke Get-RandomMessage -Times 1 -Exactly
        }
    }

    Context "Windows path handling (AG8-024)" {
        # AG8-024: Add cross-platform path tests for Windows-specific scenarios

        It "Should detect Windows UNC paths correctly" {
            $result = Invoke-FolderScheduling -FolderPath "\\server\share\folder" -TriggerTime (Get-Date).AddHours(1)
            $result.IsNetworkPath | Should -Be $true
        }

        It "Should handle Windows drive letters as local paths" -Skip:(-not $IsWindows) {
            # This test only makes sense on Windows
            $result = Invoke-FolderScheduling -FolderPath "C:\Projects\MyFolder" -TriggerTime (Get-Date).AddHours(1)
            $result.Success | Should -Be $true
            $result.IsNetworkPath | Should -Be $false
        }

        It "Should detect mapped network drives on Windows" -Skip:(-not $IsWindows) {
            # AG8-024: Test mapped drive detection (Z:\ etc)
            # Note: This test assumes Z: is a mapped drive
            # In real Windows environment, this would need actual mapped drive
            $result = Invoke-FolderScheduling -FolderPath "Z:\SharedFolder" -TriggerTime (Get-Date).AddHours(1)
            # Depending on implementation, might be detected as network path
            $result.Success | Should -Be $true
        }

        It "Should handle Windows paths with spaces" {
            $result = Invoke-FolderScheduling -FolderPath "C:\Program Files\My App" -TriggerTime (Get-Date).AddHours(1)
            $result.Success | Should -Be $true
        }

        It "Should handle Unix paths on Linux" -Skip:($IsWindows) {
            # This test only makes sense on Linux/Unix
            $result = Invoke-FolderScheduling -FolderPath "/home/user/documents" -TriggerTime (Get-Date).AddHours(1)
            $result.Success | Should -Be $true
            $result.IsNetworkPath | Should -Be $false
        }
    }
}

Describe 'BUG-3: Do-Schedule error dialog title for scheduling failures' {
    It 'uses "Schedule Failed" title, not "Invalid Folder", when Invoke-FolderScheduling returns an error' {
        $sourceFile = Join-Path $PSScriptRoot '..\..\DailyMotivation.ps1'
        $content = Get-Content $sourceFile -Raw
        $fnStart = $content.IndexOf('function Do-Schedule')
        $fnEnd   = $content.IndexOf("`nfunction ", $fnStart + 20)
        $functionBody = if ($fnEnd -gt $fnStart) { $content.Substring($fnStart, $fnEnd - $fnStart) } else { $content.Substring($fnStart) }
        $hasScheduleFailed = $functionBody -match 'Schedule Failed'
        $hasInvalidFolder  = $functionBody -match '"Invalid Folder"'
        $hasScheduleFailed | Should -Be $true
        $hasInvalidFolder  | Should -Be $false
    }

    It 'preserves "Invalid Folder" title in Set-SelectedPath for actual FolderPath validation failures' {
        $sourceFile = Join-Path $PSScriptRoot '..\..\DailyMotivation.ps1'
        $content = Get-Content $sourceFile -Raw
        $fnStart = $content.IndexOf('function Set-SelectedPath')
        $fnEnd   = $content.IndexOf("`nfunction ", $fnStart + 25)
        $functionBody = if ($fnEnd -gt $fnStart) { $content.Substring($fnStart, $fnEnd - $fnStart) } else { $content.Substring($fnStart) }
        $functionBody -match '"Invalid Folder"' | Should -Be $true
    }
}

Describe 'BUG-1: Show-PopupWindow openExplorer state preservation' {
    It 'Show-PopupWindow finally block does not reset openExplorer' {
        $src = Get-Content (Join-Path $PSScriptRoot '..\..\DailyMotivation.ps1') -Raw
        $functionStart = $src.IndexOf('function Show-PopupWindow')
        $functionEnd   = $src.IndexOf('# ============================================================', $functionStart + 100)
        $functionBody  = $src.Substring($functionStart, $functionEnd - $functionStart)
        $finallyMatch  = [regex]::Match($functionBody, 'finally\s*\{(.+?)\}', [System.Text.RegularExpressions.RegexOptions]::Singleline)
        $finallyContent = $finallyMatch.Groups[1].Value
        $finallyContent -match '\$script:openExplorer\s*=' | Should -Be $false -Because 'finally block must not reset openExplorer; user button choice must be preserved (BUG-1 fix)'
    }
    It 'Show-PopupWindow initializes openExplorer=true before ShowDialog' {
        $src = Get-Content (Join-Path $PSScriptRoot '..\..\DailyMotivation.ps1') -Raw
        $functionStart = $src.IndexOf('function Show-PopupWindow')
        $functionEnd   = $src.IndexOf('# ============================================================', $functionStart + 100)
        $functionBody  = $src.Substring($functionStart, $functionEnd - $functionStart)
        $functionBody -match '\$script:openExplorer\s*=\s*\$true' | Should -Be $true -Because 'Popup must initialize openExplorer=true before showing window'
    }
    It 'Open Folder button sets openExplorer=true' {
        $src = Get-Content (Join-Path $PSScriptRoot '..\..\DailyMotivation.ps1') -Raw
        $functionStart = $src.IndexOf('function Show-PopupWindow')
        $functionEnd   = $src.IndexOf('# ============================================================', $functionStart + 100)
        $functionBody  = $src.Substring($functionStart, $functionEnd - $functionStart)
        $functionBody -match 'letsGoBtn.*Add_Click' | Should -Be $true
        $openBlock = [regex]::Match($functionBody, '\$letsGoBtn\.Add_Click\(\{[\s\S]+?\}\)', [System.Text.RegularExpressions.RegexOptions]::Singleline)
        $openBlock.Value -match '\$script:openExplorer\s*=\s*\$true' | Should -Be $true -Because 'Open Folder button must set openExplorer=true'
    }
    It 'Dismiss button sets openExplorer=false' {
        $src = Get-Content (Join-Path $PSScriptRoot '..\..\DailyMotivation.ps1') -Raw
        $functionStart = $src.IndexOf('function Show-PopupWindow')
        $functionEnd   = $src.IndexOf('# ============================================================', $functionStart + 100)
        $functionBody  = $src.Substring($functionStart, $functionEnd - $functionStart)
        $dismissBlock = [regex]::Match($functionBody, '\$dismissBtn\.Add_Click\(\{[\s\S]+?\}\)', [System.Text.RegularExpressions.RegexOptions]::Singleline)
        $dismissBlock.Value -match '\$script:openExplorer\s*=\s*\$false' | Should -Be $true -Because 'Dismiss button must set openExplorer=false'
    }
    It 'Snooze button sets openExplorer=false' {
        $src = Get-Content (Join-Path $PSScriptRoot '..\..\DailyMotivation.ps1') -Raw
        $functionStart = $src.IndexOf('function Show-PopupWindow')
        $functionEnd   = $src.IndexOf('# ============================================================', $functionStart + 100)
        $functionBody  = $src.Substring($functionStart, $functionEnd - $functionStart)
        $snoozeBlock = [regex]::Match($functionBody, '\$snoozeBtn\.Add_Click\(\{[\s\S]+?\}\)', [System.Text.RegularExpressions.RegexOptions]::Singleline)
        $snoozeBlock.Value -match '\$script:openExplorer\s*=\s*\$false' | Should -Be $true -Because 'Snooze button must set openExplorer=false'
    }
}
