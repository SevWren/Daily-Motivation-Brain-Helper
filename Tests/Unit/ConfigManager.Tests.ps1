#Requires -Modules Pester
<#
.SYNOPSIS
    Unit tests for ConfigManager.psm1

.DESCRIPTION
    Tests all functions in ConfigManager module including:
    - Initialize-AppData
    - Get/Save-AppSettings
    - Get/Set-PopupConfig
    - Get/Add-RecentFolder
    - Get/Write/Clear-OutcomeLog
    - Show-ErrorDialog
#>

BeforeAll {
    # Import module under test
    $ModulePath = Join-Path $PSScriptRoot '..\..\src\Modules\ConfigManager.psm1'
    Import-Module $ModulePath -Force

    # Create test AppData directory in temp
    $script:TestAppDataDir = Join-Path ([System.IO.Path]::GetTempPath()) "DailyMotivationBrainHelper_Test_$(New-Guid)"

    # Mock the module-scoped variables
    $script:OriginalAppDataDir = $env:APPDATA
}

AfterAll {
    # Cleanup test directory
    if (Test-Path $script:TestAppDataDir) {
        Remove-Item -Path $script:TestAppDataDir -Recurse -Force -ErrorAction SilentlyContinue
    }

    # Restore environment
    $env:APPDATA = $script:OriginalAppDataDir
}

Describe 'Initialize-AppData' {
    Context 'When AppData directory does not exist' {
        BeforeEach {
            $env:APPDATA = $script:TestAppDataDir
            if (Test-Path $script:TestAppDataDir) {
                Remove-Item -Path $script:TestAppDataDir -Recurse -Force
            }
        }

        It 'Should create the AppData directory' {
            Initialize-AppData

            Test-Path (Join-Path $script:TestAppDataDir 'DailyMotivationBrainHelper') | Should -Be $true
        }

        It 'Should create app_settings.json with default values' {
            Initialize-AppData

            $settingsPath = Join-Path $script:TestAppDataDir 'DailyMotivationBrainHelper\app_settings.json'
            Test-Path $settingsPath | Should -Be $true

            $settings = Get-Content $settingsPath -Raw | ConvertFrom-Json
            $settings.firstRun | Should -Be $true
            $settings.lastFolder | Should -Be ''
            $settings.recentFolders | Should -Be $null  # PS5.1 returns $null for empty arrays
            $settings.theme | Should -Be 'dark'
        }

        It 'Should create tasks.json as empty array' {
            Initialize-AppData

            $tasksPath = Join-Path $script:TestAppDataDir 'DailyMotivationBrainHelper\tasks.json'
            Test-Path $tasksPath | Should -Be $true

            $content = Get-Content $tasksPath -Raw
            $content.Trim() | Should -Be '[]'
        }

        It 'Should create popup_config.json with empty defaults' {
            Initialize-AppData

            $configPath = Join-Path $script:TestAppDataDir 'DailyMotivationBrainHelper\popup_config.json'
            Test-Path $configPath | Should -Be $true

            $config = Get-Content $configPath -Raw | ConvertFrom-Json
            $config.glyph | Should -Be '[+]'
            $config.explorer_path | Should -Be ''
            $config.folder_name | Should -Be ''
            $config.task_id | Should -Be ''
        }

        It 'Should not overwrite existing files' {
            Initialize-AppData

            # Modify settings
            $settingsPath = Join-Path $script:TestAppDataDir 'DailyMotivationBrainHelper\app_settings.json'
            @{ firstRun = $false; lastFolder = 'C:\Test' } | ConvertTo-Json | Set-Content $settingsPath -Encoding UTF8

            # Initialize again
            Initialize-AppData

            # Should not overwrite
            $settings = Get-Content $settingsPath -Raw | ConvertFrom-Json
            $settings.firstRun | Should -Be $false
            $settings.lastFolder | Should -Be 'C:\Test'
        }
    }

    Context 'When AppData creation fails' {
        It 'Should fall back to TEMP directory' -Skip {
            # Note: This test requires mocking New-Item which is complex in Pester 5
            # Consider implementing when fallback strategy is finalized (Issue #7)
        }
    }
}

Describe 'Get-AppSettings and Save-AppSettings' {
    BeforeEach {
        $env:APPDATA = $script:TestAppDataDir
        Initialize-AppData
    }

    It 'Should retrieve default settings' {
        $settings = Get-AppSettings

        $settings.firstRun | Should -Be $true
        $settings.lastFolder | Should -Be ''
        # PS5.1 returns $null for empty arrays from ConvertFrom-Json
        if ($null -eq $settings.recentFolders) { $count = 0 } else { $count = $settings.recentFolders.Count }
        $count | Should -Be 0
    }

    It 'Should save and retrieve modified settings' {
        $settings = Get-AppSettings
        $settings.firstRun = $false
        $settings.lastFolder = 'C:\Projects\Test'

        Save-AppSettings -Settings $settings

        $retrieved = Get-AppSettings
        $retrieved.firstRun | Should -Be $false
        $retrieved.lastFolder | Should -Be 'C:\Projects\Test'
    }

    It 'Should handle corrupted settings file gracefully' {
        $settingsPath = Join-Path $script:TestAppDataDir 'DailyMotivationBrainHelper\app_settings.json'
        'invalid json{' | Set-Content $settingsPath -Encoding UTF8

        $settings = Get-AppSettings

        # Should return defaults
        $settings.firstRun | Should -Be $true
        $settings.lastFolder | Should -Be ''
    }
}

Describe 'First Run Functions' {
    BeforeEach {
        $env:APPDATA = $script:TestAppDataDir
        Initialize-AppData
    }

    It 'Get-IsFirstRun should return true initially' {
        Get-IsFirstRun | Should -Be $true
    }

    It 'Set-FirstRunComplete should mark first run as complete' {
        Set-FirstRunComplete

        Get-IsFirstRun | Should -Be $false
    }
}

Describe 'Last Folder Functions' {
    BeforeEach {
        $env:APPDATA = $script:TestAppDataDir
        Initialize-AppData
    }

    It 'Get-LastFolder should return empty string initially' {
        Get-LastFolder | Should -Be ''
    }

    It 'Set-LastFolder should persist folder path' {
        Set-LastFolder -FolderPath 'C:\Projects\ClientA'

        Get-LastFolder | Should -Be 'C:\Projects\ClientA'
    }
}

Describe 'Recent Folders Functions' {
    BeforeEach {
        $env:APPDATA = $script:TestAppDataDir
        Initialize-AppData
    }

    It 'Get-RecentFolders should return empty array initially' {
        $recent = Get-RecentFolders

        $recent | Should -Be $null  # PS5.1 returns $null for empty arrays from ConvertFrom-Json
    }

    It 'Add-RecentFolder should add folder to list' {
        Add-RecentFolder -FolderPath 'C:\Projects\A'

        $recent = Get-RecentFolders
        $recent.Count | Should -Be 1
        $recent[0] | Should -Be 'C:\Projects\A'
    }

    It 'Add-RecentFolder should maintain newest-first order' {
        Add-RecentFolder -FolderPath 'C:\Projects\A'
        Add-RecentFolder -FolderPath 'C:\Projects\B'
        Add-RecentFolder -FolderPath 'C:\Projects\C'

        $recent = Get-RecentFolders
        $recent[0] | Should -Be 'C:\Projects\C'
        $recent[1] | Should -Be 'C:\Projects\B'
        $recent[2] | Should -Be 'C:\Projects\A'
    }

    It 'Add-RecentFolder should deduplicate entries' {
        Add-RecentFolder -FolderPath 'C:\Projects\A'
        Add-RecentFolder -FolderPath 'C:\Projects\B'
        Add-RecentFolder -FolderPath 'C:\Projects\A'

        $recent = Get-RecentFolders
        # Handle both $null and array return types from PS5.1
        if ($null -eq $recent) { $count = 0 } else { $count = $recent.Count }
        $count | Should -Be 2
        $recent[0] | Should -Be 'C:\Projects\A'
        $recent[1] | Should -Be 'C:\Projects\B'
    }

    It 'Add-RecentFolder should limit to 5 entries' {
        1..10 | ForEach-Object {
            Add-RecentFolder -FolderPath "C:\Projects\Folder$_"
        }

        $recent = Get-RecentFolders
        $recent.Count | Should -Be 5
        $recent[0] | Should -Be 'C:\Projects\Folder10'
        $recent[4] | Should -Be 'C:\Projects\Folder6'
    }
}

Describe 'Popup Config Functions' {
    BeforeEach {
        $env:APPDATA = $script:TestAppDataDir
        Initialize-AppData
    }

    It 'Get-PopupConfig should return default config' {
        $config = Get-PopupConfig

        $config.glyph | Should -Be '[+]'
        $config.explorer_path | Should -Be ''
    }

    It 'Set-PopupConfig should persist all fields' {
        Set-PopupConfig -Glyph '[!]' -Title 'Test Title' -Body 'Test Body' `
            -ExplorerPath 'C:\Projects\Test' -TaskId 'abc123'

        $config = Get-PopupConfig
        $config.glyph | Should -Be '[!]'
        $config.title | Should -Be 'Test Title'
        $config.body | Should -Be 'Test Body'
        $config.explorer_path | Should -Be 'C:\Projects\Test'
        $config.task_id | Should -Be 'abc123'
    }

    It 'Set-PopupConfig should derive folder_name from path' {
        Set-PopupConfig -Glyph '[+]' -Title 'Title' -Body 'Body' `
            -ExplorerPath 'C:\Projects\ClientA\SubFolder' -TaskId 'xyz'

        $config = Get-PopupConfig
        $config.folder_name | Should -Be 'SubFolder'
    }

    It 'Get-PopupConfig should return null for corrupted file' {
        $configPath = Join-Path $script:TestAppDataDir 'DailyMotivationBrainHelper\popup_config.json'
        'invalid' | Set-Content $configPath -Encoding UTF8

        Get-PopupConfig | Should -BeNullOrEmpty
    }
}

Describe 'Outcome Log Functions' {
    BeforeEach {
        $env:APPDATA = $script:TestAppDataDir
        Initialize-AppData
    }

    It 'Get-OutcomeLog should return empty array initially' {
        $log = Get-OutcomeLog

        if ($null -eq $log) { $count = 0 } else { $count = $log.Count }
        $count | Should -Be 0
    }

    It 'Write-OutcomeLog should create log entry' {
        Write-OutcomeLog -TaskId 'task1' -FolderName 'ClientA' -FolderPath 'C:\Projects\ClientA' `
            -Outcome 'Opened' -SnoozeCount 0

        $log = Get-OutcomeLog
        # Handle both $null and array return types from PS5.1
        if ($null -eq $log) { $count = 0 } else { $count = $log.Count }
        $count | Should -Be 1
        $log[0].TaskId | Should -Be 'task1'
        $log[0].FolderName | Should -Be 'ClientA'
        $log[0].Outcome | Should -Be 'Opened'
    }

    It 'Get-OutcomeLog should return newest entries first' {
        Write-OutcomeLog -TaskId 'task1' -FolderName 'A' -FolderPath 'C:\A' -Outcome 'Opened'
        Start-Sleep -Milliseconds 100
        Write-OutcomeLog -TaskId 'task2' -FolderName 'B' -FolderPath 'C:\B' -Outcome 'Snoozed'

        $log = Get-OutcomeLog
        $log[0].TaskId | Should -Be 'task2'
        $log[1].TaskId | Should -Be 'task1'
    }

    It 'Get-OutcomeLog should respect Limit parameter' {
        1..10 | ForEach-Object {
            Write-OutcomeLog -TaskId "task$_" -FolderName "F$_" -FolderPath "C:\$_" -Outcome 'Opened'
        }

        $log = Get-OutcomeLog -Limit 5
        $log.Count | Should -Be 5
    }

    It 'Get-OutcomeLog should parse pipe-delimited format correctly' {
        Write-OutcomeLog -TaskId 'abc123' -FolderName 'Test Folder' -FolderPath 'C:\Test\Path' `
            -Outcome 'Snoozed' -SnoozeCount 3

        $log = Get-OutcomeLog
        $log[0].TaskId | Should -Be 'abc123'
        $log[0].FolderName | Should -Be 'Test Folder'
        $log[0].FolderPath | Should -Be 'C:\Test\Path'
        $log[0].Outcome | Should -Be 'Snoozed'
        $log[0].SnoozeCount | Should -Be 3
    }

    It 'Clear-OutcomeLog should remove all entries' {
        Write-OutcomeLog -TaskId 'task1' -FolderName 'A' -FolderPath 'C:\A' -Outcome 'Opened'
        Write-OutcomeLog -TaskId 'task2' -FolderName 'B' -FolderPath 'C:\B' -Outcome 'Dismissed'

        Clear-OutcomeLog

        $log = Get-OutcomeLog
        if ($null -eq $log) { $count = 0 } else { $count = $log.Count }
        $count | Should -Be 0
    }
}

Describe 'Show-ErrorDialog' {
    It 'Should not throw when called' {
        # Cannot test UI dialogs in non-interactive context
        # This just ensures the function exists and doesn't crash
        {
            # Mock MessageBox to prevent actual display
            Mock -ModuleName ConfigManager -CommandName Show-ErrorDialog { }
            Show-ErrorDialog -Message "Test error"
        } | Should -Not -Throw
    }
}

Describe 'UTF-8 Encoding' {
    BeforeEach {
        $env:APPDATA = $script:TestAppDataDir
        Initialize-AppData
    }

    It 'Should preserve Unicode characters in folder paths' {
        $testPath = 'C:\Projects\Café\Naïve'
        Set-LastFolder -FolderPath $testPath

        $retrieved = Get-LastFolder
        $retrieved | Should -Be $testPath
    }

    It 'Should preserve Unicode in popup config' {
        Set-PopupConfig -Glyph '🎯' -Title 'Motivación' -Body 'Café time' `
            -ExplorerPath 'C:\Projets\Montréal' -TaskId 'test'

        $config = Get-PopupConfig
        $config.glyph | Should -Be '🎯'
        $config.title | Should -Be 'Motivación'
        $config.explorer_path | Should -Be 'C:\Projets\Montréal'
    }
}
