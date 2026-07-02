# PowerShell Best Practices Tests (AG9-001 through AG9-023)
# Tests for Section 9: POWERSHELL BEST PRACTICES from FORENSIC_CODEBASE_BUG_REPORT.md

BeforeAll {
    . "$PSScriptRoot/../../DailyMotivation.ps1" -NoRun
}

Describe "AG9-001: Missing [CmdletBinding()] on Advanced Functions" -Tag "AG9-001", "HIGH" {
    It "Initialize-AppData should have [CmdletBinding()] attribute" {
        $func = Get-Command Initialize-AppData
        $func.CmdletBinding | Should -Be $true
    }

    It "Get-Config should have [CmdletBinding()] attribute" {
        $func = Get-Command Get-Config
        $func.CmdletBinding | Should -Be $true
    }

    It "Save-Config should have [CmdletBinding()] attribute" {
        $func = Get-Command Save-Config
        $func.CmdletBinding | Should -Be $true
    }

    It "Get-PopupConfig should have [CmdletBinding()] attribute" {
        $func = Get-Command Get-PopupConfig
        $func.CmdletBinding | Should -Be $true
    }

    It "Set-PopupConfig should have [CmdletBinding()] attribute" {
        $func = Get-Command Set-PopupConfig
        $func.CmdletBinding | Should -Be $true
    }

    It "Write-OutcomeLog should have [CmdletBinding()] attribute" {
        $func = Get-Command Write-OutcomeLog
        $func.CmdletBinding | Should -Be $true
    }

    It "Show-ErrorDialog should have [CmdletBinding()] attribute" {
        $func = Get-Command Show-ErrorDialog
        $func.CmdletBinding | Should -Be $true
    }
}
