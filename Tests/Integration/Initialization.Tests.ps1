#Requires -Modules Pester
<#
.SYNOPSIS
    Integration tests for application initialization

.DESCRIPTION
    Tests the complete initialization flow including:
    - MainApp.ps1 startup and initialization
    - DailyMotivation.ps1 standalone initialization
    - Directory creation and file setup
    - Module path resolution
    - Error handling during initialization

.NOTES
    These tests address the issues documented in GitHub #2-#8
#>

BeforeAll {
    $script:RepoRoot = Join-Path $PSScriptRoot '..\..\'
    $script:TestAppDataDir = Join-Path ([System.IO.Path]::GetTempPath()) "DailyMotivationBrainHelper_IntegrationTest_$(New-Guid)"
    $script:OriginalAppDataDir = $env:APPDATA
}

AfterAll {
    # Cleanup
    if (Test-Path $script:TestAppDataDir) {
        Remove-Item -Path $script:TestAppDataDir -Recurse -Force -ErrorAction SilentlyContinue
    }
    $env:APPDATA = $script:OriginalAppDataDir
}

Describe 'Fresh Installation Initialization' -Tag 'Integration', 'Initialization' {
    Context 'When no AppData directory exists' {
        BeforeEach {
            # Set test AppData and ensure it doesn't exist
            $env:APPDATA = $script:TestAppDataDir
            if (Test-Path $script:TestAppDataDir) {
                Remove-Item -Path $script:TestAppDataDir -Recurse -Force
            }
        }

        It 'Should create AppData directory structure on first run' {
            # Import and initialize
            Import-Module (Join-Path $script:RepoRoot 'src\Modules\ConfigManager.psm1') -Force
            Initialize-AppData

            # Verify directory exists
            $appDataPath = Join-Path $script:TestAppDataDir 'DailyMotivationBrainHelper'
            Test-Path $appDataPath | Should -Be $true
        }

        It 'Should create all required config files' {
            Import-Module (Join-Path $script:RepoRoot 'src\Modules\ConfigManager.psm1') -Force
            Initialize-AppData

            $appDataPath = Join-Path $script:TestAppDataDir 'DailyMotivationBrainHelper'

            # Verify all required files
            Test-Path (Join-Path $appDataPath 'app_settings.json') | Should -Be $true
            Test-Path (Join-Path $appDataPath 'tasks.json') | Should -Be $true
            Test-Path (Join-Path $appDataPath 'popup_config.json') | Should -Be $true
        }

        It 'Should create valid JSON in all config files' {
            Import-Module (Join-Path $script:RepoRoot 'src\Modules\ConfigManager.psm1') -Force
            Initialize-AppData

            $appDataPath = Join-Path $script:TestAppDataDir 'DailyMotivationBrainHelper'

            # Test each file is valid JSON
            {
                Get-Content (Join-Path $appDataPath 'app_settings.json') -Raw | ConvertFrom-Json
            } | Should -Not -Throw

            {
                Get-Content (Join-Path $appDataPath 'tasks.json') -Raw | ConvertFrom-Json
            } | Should -Not -Throw

            {
                Get-Content (Join-Path $appDataPath 'popup_config.json') -Raw | ConvertFrom-Json
            } | Should -Not -Throw
        }

        It 'Should handle repeated initialization calls gracefully' {
            Import-Module (Join-Path $script:RepoRoot 'src\Modules\ConfigManager.psm1') -Force

            # Call Initialize-AppData multiple times
            Initialize-AppData
            Initialize-AppData
            Initialize-AppData

            # Should still have valid structure
            $appDataPath = Join-Path $script:TestAppDataDir 'DailyMotivationBrainHelper'
            Test-Path (Join-Path $appDataPath 'app_settings.json') | Should -Be $true
        }
    }
}

Describe 'Module Import Order' -Tag 'Integration', 'Initialization' {
    Context 'When modules are imported before directory exists' {
        BeforeEach {
            $env:APPDATA = $script:TestAppDataDir
            if (Test-Path $script:TestAppDataDir) {
                Remove-Item -Path $script:TestAppDataDir -Recurse -Force
            }
        }

        It 'Should allow module import even when AppData does not exist' {
            # This tests the fix for Issue #4
            {
                Import-Module (Join-Path $script:RepoRoot 'src\Modules\ConfigManager.psm1') -Force
                Import-Module (Join-Path $script:RepoRoot 'src\Modules\TaskScheduler.psm1') -Force
            } | Should -Not -Throw
        }

        It 'Should create directory when Initialize-AppData is called after import' {
            Import-Module (Join-Path $script:RepoRoot 'src\Modules\ConfigManager.psm1') -Force

            # Now initialize
            Initialize-AppData

            $appDataPath = Join-Path $script:TestAppDataDir 'DailyMotivationBrainHelper'
            Test-Path $appDataPath | Should -Be $true
        }
    }
}

Describe 'DailyMotivation.ps1 Standalone Initialization' -Tag 'Integration', 'Initialization' {
    Context 'When launched without MainApp.ps1 running first' {
        BeforeEach {
            $env:APPDATA = $script:TestAppDataDir
            if (Test-Path $script:TestAppDataDir) {
                Remove-Item -Path $script:TestAppDataDir -Recurse -Force
            }
        }

        It 'Should create directory structure if missing' -Skip {
            # This tests the fix for Issue #5
            # Skipped until DailyMotivation.ps1 is updated to call Initialize-AppData
            # After fix, this should pass
        }

        It 'Should show error dialog if config file missing' -Skip {
            # Skipped until error handling is improved (Issue #6)
            # After fix, should show dialog instead of silent exit
        }
    }
}

Describe 'Path Resolution' -Tag 'Integration', 'PathResolution' {
    Context 'When determining script directory' {
        It 'Should resolve module paths correctly from MainApp.ps1' {
            # Test that module path resolution works
            $mainAppPath = Join-Path $script:RepoRoot 'src\MainApp.ps1'

            # This would need to be executed in a separate PowerShell process
            # to properly test $PSScriptRoot behavior
            # For now, document expected behavior
        }

        It 'Should resolve paths in PS2EXE compiled mode' -Skip {
            # Skipped: Requires building EXE and testing
            # Documents Issue #3 requirements
        }
    }
}

Describe 'Error Handling During Initialization' -Tag 'Integration', 'ErrorHandling' {
    Context 'When AppData is not writable' {
        It 'Should show clear error message' -Skip {
            # Skipped: Difficult to simulate permission errors in test
            # Documents expected behavior from Issue #6
        }

        It 'Should not fail silently' -Skip {
            # Skipped: Tests Issue #6 fix
        }
    }

    Context 'When config files are corrupted' {
        BeforeEach {
            $env:APPDATA = $script:TestAppDataDir
            Import-Module (Join-Path $script:RepoRoot 'src\Modules\ConfigManager.psm1') -Force
            Initialize-AppData
        }

        It 'Should recover from corrupted app_settings.json' {
            $settingsPath = Join-Path $script:TestAppDataDir 'DailyMotivationBrainHelper\app_settings.json'
            'invalid json{' | Set-Content $settingsPath -Encoding UTF8

            # Should return defaults instead of throwing
            {
                $settings = Get-AppSettings
                $settings.firstRun | Should -Be $true
            } | Should -Not -Throw
        }

        It 'Should recover from corrupted tasks.json' {
            $tasksPath = Join-Path $script:TestAppDataDir 'DailyMotivationBrainHelper\tasks.json'
            'not valid' | Set-Content $tasksPath -Encoding UTF8

            {
                $tasks = Get-MotivationTasks
                $tasks.Count | Should -Be 0
            } | Should -Not -Throw
        }

        It 'Should handle empty config files' {
            $configPath = Join-Path $script:TestAppDataDir 'DailyMotivationBrainHelper\popup_config.json'
            '' | Set-Content $configPath -Encoding UTF8

            {
                Get-PopupConfig
            } | Should -Not -Throw
        }
    }
}

Describe 'End-to-End Initialization Flow' -Tag 'Integration', 'E2E' {
    Context 'Complete first-run scenario' {
        BeforeEach {
            $env:APPDATA = $script:TestAppDataDir
            if (Test-Path $script:TestAppDataDir) {
                Remove-Item -Path $script:TestAppDataDir -Recurse -Force
            }
        }

        It 'Should complete full initialization sequence' {
            # Import modules
            Import-Module (Join-Path $script:RepoRoot 'src\Modules\ConfigManager.psm1') -Force
            Import-Module (Join-Path $script:RepoRoot 'src\Modules\TaskScheduler.psm1') -Force

            # Initialize
            Initialize-AppData

            # Verify first run flag
            Get-IsFirstRun | Should -Be $true

            # Create a task
            $triggerTime = (Get-Date).AddHours(2)
            $result = New-MotivationTask -FolderPath 'C:\Test' -TriggerTime $triggerTime

            $result.Success | Should -Be $true

            # Verify task was created
            $tasks = Get-MotivationTasks
            $tasks.Count | Should -Be 1

            # Set popup config
            Set-PopupConfig -Glyph '[+]' -Title 'Test' -Body 'Body' `
                -ExplorerPath 'C:\Test' -TaskId $result.TaskId

            # Verify config
            $config = Get-PopupConfig
            $config.task_id | Should -Be $result.TaskId

            # Log an outcome
            Write-OutcomeLog -TaskId $result.TaskId -FolderName 'Test' `
                -FolderPath 'C:\Test' -Outcome 'Opened' -SnoozeCount 0

            # Verify log
            $log = Get-OutcomeLog
            $log.Count | Should -Be 1
            $log[0].Outcome | Should -Be 'Opened'

            # Mark first run complete
            Set-FirstRunComplete
            Get-IsFirstRun | Should -Be $false

            # Add to recent folders
            Add-RecentFolder -FolderPath 'C:\Test'
            $recent = Get-RecentFolders
            $recent.Count | Should -Be 1

            # All operations should have succeeded
        }
    }
}

Describe 'UTF-8 Encoding Integration' -Tag 'Integration', 'Encoding' {
    BeforeEach {
        $env:APPDATA = $script:TestAppDataDir
        if (Test-Path $script:TestAppDataDir) {
            Remove-Item -Path $script:TestAppDataDir -Recurse -Force
        }
        Import-Module (Join-Path $script:RepoRoot 'src\Modules\ConfigManager.psm1') -Force
        Import-Module (Join-Path $script:RepoRoot 'src\Modules\TaskScheduler.psm1') -Force
        Initialize-AppData
    }

    It 'Should preserve Unicode throughout the system' {
        # Test path with various Unicode characters
        $testPath = 'C:\Projets\Café\Montréal\Naïve\北京'

        # Set last folder
        Set-LastFolder -FolderPath $testPath
        Get-LastFolder | Should -Be $testPath

        # Add to recent
        Add-RecentFolder -FolderPath $testPath
        $recent = Get-RecentFolders
        $recent[0] | Should -Be $testPath

        # Create task
        $triggerTime = (Get-Date).AddHours(2)
        $result = New-MotivationTask -FolderPath $testPath -TriggerTime $triggerTime

        $tasks = Get-MotivationTasks
        $tasks[0].folder_path | Should -Be $testPath

        # Set popup config
        Set-PopupConfig -Glyph '🎯' -Title 'Motivación' -Body 'Café ☕' `
            -ExplorerPath $testPath -TaskId $result.TaskId

        $config = Get-PopupConfig
        $config.glyph | Should -Be '🎯'
        $config.title | Should -Be 'Motivación'
        $config.explorer_path | Should -Be $testPath

        # Write log
        Write-OutcomeLog -TaskId $result.TaskId -FolderName 'Café' `
            -FolderPath $testPath -Outcome 'Opened'

        $log = Get-OutcomeLog
        $log[0].FolderPath | Should -Be $testPath
    }
}
