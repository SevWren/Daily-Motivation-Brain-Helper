#Requires -Modules Pester
<#
.SYNOPSIS
    Tests for platform-aware configuration functions

.DESCRIPTION
    Tests that Initialize-AppData and config functions work with HeadlessPlatform
    on Linux. Per architecture-report.html Candidate 3.
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
}

Describe "Initialize-AppData with platform adapter" -Tag "Unit", "Config", "Platform" {

    BeforeEach {
        # Clean slate for each test
        if (Test-Path $script:TestAppData) {
            Remove-Item -Path $script:TestAppData -Recurse -Force
        }

        # Inject HeadlessPlatform adapter
        $script:Platform = [HeadlessPlatform]::new()
    }

    Context "When platform adapter is injected" {
        It "uses platform.GetAppDataPath() instead of hardcoded env:APPDATA" {
            # This test will fail until Initialize-AppData uses platform adapter
            Initialize-AppData

            # Script variables should be set
            $script:AppDataDir | Should -Not -BeNullOrEmpty

            # On Linux, should use platform-provided path
            if (-not $script:IsWindowsPlatform) {
                $script:AppDataDir | Should -BeLike "*/.local/share/DailyMotivationBrainHelper"
            }
        }

        It "creates config.json in platform-specific directory" {
            Initialize-AppData

            Test-Path $script:ConfigPath | Should -Be $true
            $config = Get-Content $script:ConfigPath -Raw | ConvertFrom-Json
            $config.default_trigger_hour | Should -Be 14
        }

        It "creates popup_config.json in platform-specific directory" {
            Initialize-AppData

            Test-Path $script:PopupCfgPath | Should -Be $true
            $popupConfig = Get-Content $script:PopupCfgPath -Raw | ConvertFrom-Json
            $popupConfig.glyph | Should -Be "[+]"
        }

        It "creates tasks.json in platform-specific directory" {
            Initialize-AppData

            Test-Path $script:TasksPath | Should -Be $true
            $tasks = Get-Content $script:TasksPath -Raw
            $tasks | Should -Be "[]"
        }
    }
}
