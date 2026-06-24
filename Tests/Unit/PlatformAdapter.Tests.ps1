#Requires -Modules Pester
<#
.SYNOPSIS
    Tests for platform abstraction seam (OS-agnostic PowerShell 7)

.DESCRIPTION
    Tests HeadlessPlatform adapter to enable cross-platform CI testing.
    Per architecture-report.html Candidate 3.
#>

BeforeAll {
    # Dot-source the script with -NoRun
    . "$PSScriptRoot\..\..\DailyMotivation.ps1" -NoRun
}

Describe "HeadlessPlatform adapter" -Tag "Unit", "Platform" {

    Context "GetAppDataPath" {
        It "returns a valid path for headless testing" {
            # RED: This will fail until HeadlessPlatform class exists
            $platform = [HeadlessPlatform]::new()
            $path = $platform.GetAppDataPath()

            $path | Should -Not -BeNullOrEmpty
            $path | Should -BeLike "*DailyMotivationBrainHelper*"
        }
    }
}
