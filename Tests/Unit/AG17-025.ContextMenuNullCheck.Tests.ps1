#Requires -Modules Pester
<#
.SYNOPSIS
    Tests for AG17-025: ContextMenu null check before accessing .IsOpen in the
    snoozeDropBtn click handler to prevent NullReferenceException on XAML load failure.
#>

BeforeAll {
    . "$PSScriptRoot/../../DailyMotivation.ps1" -NoRun
}

Describe "AG17-025: Missing Null Checks Before Accessing ContextMenu" {
    Context "snoozeDropBtn.Add_Click handler" {
        BeforeAll {
            $script:content = Get-Content (Join-Path $PSScriptRoot '..\..\DailyMotivation.ps1') -Raw
        }

        It "Should contain a null check for snoozeDropBtn.ContextMenu before accessing its properties" {
            $script:content | Should -Match '\$null -eq \$snoozeDropBtn\.ContextMenu' `
                -Because "Accessing .IsOpen on a null ContextMenu throws NullReferenceException; null guard required (AG17-025)"
        }

        It "Should return early from the click handler when ContextMenu is null" {
            $nullCheckIdx = $script:content.IndexOf('$null -eq $snoozeDropBtn.ContextMenu')
            $nullCheckIdx | Should -BeGreaterThan 0 `
                -Because "Null check must exist for snoozeDropBtn.ContextMenu (AG17-025)"

            # Inspect next 250 chars after the null check for a return statement
            $guardContext = $script:content.Substring($nullCheckIdx, [Math]::Min(250, $script:content.Length - $nullCheckIdx))
            $guardContext | Should -Match '\breturn\b' `
                -Because "Guard block must return early when ContextMenu is null to prevent NullReferenceException (AG17-025)"
        }

        It "Should only access ContextMenu.IsOpen after the null guard" {
            $nullCheckIdx = $script:content.IndexOf('$null -eq $snoozeDropBtn.ContextMenu')
            $isOpenIdx    = $script:content.IndexOf('$snoozeDropBtn.ContextMenu.IsOpen')
            $nullCheckIdx | Should -BeGreaterThan 0 -Because "Null guard must exist (AG17-025)"
            $isOpenIdx    | Should -BeGreaterThan 0 -Because "ContextMenu.IsOpen must be set in handler"
            $isOpenIdx    | Should -BeGreaterThan $nullCheckIdx `
                -Because ".IsOpen must only be accessed after the null guard (AG17-025)"
        }
    }
}
