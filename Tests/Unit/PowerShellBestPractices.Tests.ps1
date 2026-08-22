# PowerShell Best Practices Tests (AG9-001 through AG9-023)
# Tests for Section 9: POWERSHELL BEST PRACTICES from FORENSIC_CODEBASE_BUG_REPORT.md

BeforeAll {
    . "$PSScriptRoot/../../DailyMotivation.ps1" -NoRun
}

Describe "AG9-001: Missing [CmdletBinding()] on Advanced Functions" -Tag "AG9-001", "HIGH" {
    It '<_> should have [CmdletBinding()] attribute' -ForEach @(
        'Initialize-AppData'
        'Get-Config'
        'Save-Config'
        'Get-PopupConfig'
        'Set-PopupConfig'
        'Write-OutcomeLog'
        'Show-ErrorDialog'
    ) {
        (Get-Command $_).CmdletBinding | Should -Be $true
    }
}
