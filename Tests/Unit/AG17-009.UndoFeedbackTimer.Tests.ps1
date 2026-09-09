#Requires -Modules @{ ModuleName='Pester'; ModuleVersion='5.0.0' }
<#
.SYNOPSIS
    Tests for AG17-009: UndoFeedbackTimer is disposed after stopping to prevent
    DispatcherTimer resource leaks when undo is clicked multiple times.
#>

BeforeAll {
    . "$PSScriptRoot/../../DailyMotivation.ps1" -NoRun
}

Describe "AG17-009: UndoFeedbackTimer Disposal" {
    Context "undoFeedbackTimer Tick handler in undoBtn click handler" {
        BeforeAll {
            $script:content = Get-Content (Join-Path $PSScriptRoot '..\..\DailyMotivation.ps1') -Raw

            # Locate the undoFeedbackTimer Add_Tick scriptblock
            $tickMatch = [System.Text.RegularExpressions.Regex]::Match(
                $script:content,
                '(?s)\$undoFeedbackTimer\.Add_Tick\(\{.{0,600}?\}\)',
                [System.Text.RegularExpressions.RegexOptions]::Singleline
            )
            $script:tickHandler = $tickMatch.Value
            $script:tickFound   = $tickMatch.Success
        }

        It "Should have an Add_Tick handler registered on undoFeedbackTimer" {
            $script:tickFound | Should -Be $true `
                -Because "undoFeedbackTimer must have a Tick handler to collapse the undo banner after 2.5s"
        }

        It "Should call Stop() on undoFeedbackTimer inside the Tick handler" {
            $script:tickHandler | Should -Match 'undoFeedbackTimer\.Stop\(\)' `
                -Because "Timer must be stopped in its own Tick handler to prevent repeated firing (AG17-009)"
        }

        It "Should call Dispose() on undoFeedbackTimer inside the Tick handler" {
            $script:tickHandler | Should -Match 'undoFeedbackTimer\.Dispose\(\)' `
                -Because "DispatcherTimer.Dispose() must be called after Stop() to release dispatcher resources; omitting it causes accumulation when undo is clicked repeatedly (AG17-009)"
        }

        It "Should call Stop() before Dispose() in the Tick handler" {
            $stopIdx    = $script:tickHandler.IndexOf('undoFeedbackTimer.Stop()')
            $disposeIdx = $script:tickHandler.IndexOf('undoFeedbackTimer.Dispose()')
            $stopIdx    | Should -BeGreaterThan -1 -Because "Stop() must be present in tick handler"
            $disposeIdx | Should -BeGreaterThan -1 -Because "Dispose() must be present in tick handler"
            $stopIdx    | Should -BeLessThan $disposeIdx `
                -Because "Stop() must precede Dispose() to cleanly halt the timer before releasing it (AG17-009)"
        }
    }
}
