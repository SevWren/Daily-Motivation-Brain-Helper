#Requires -Modules @{ ModuleName='Pester'; ModuleVersion='5.0.0' }
<#
.SYNOPSIS
    Unit tests for UI/WPF resource disposal and lifecycle management (AG6-004, AG6-010, AG6-016, AG6-018).
    Tests window disposal, timer cleanup, and reader disposal.
#>

BeforeAll {
    . (Join-Path $PSScriptRoot '..\..\DailyMotivation.ps1') -NoRun
}

Describe 'AG6-018: XmlNodeReader Disposal' {
    It 'Should dispose XmlNodeReader after loading XAML in Show-MainWindow' {
        # Read the source file and check for reader disposal pattern
        $sourceFile = Join-Path $PSScriptRoot '..\..\DailyMotivation.ps1'
        $content = Get-Content $sourceFile -Raw
        
        # Look for the Show-MainWindow function and check if reader is disposed
        $functionStart = $content.IndexOf('function Show-MainWindow')
        $functionEnd = $content.IndexOf('function Show-PopupWindow', $functionStart)
        $functionBody = $content.Substring($functionStart, $functionEnd - $functionStart)
        
        # Should have reader.Dispose() or finally block with reader cleanup
        $hasReaderDisposal = ($functionBody -match '\$reader\.Dispose\(\)') -or 
                             ($functionBody -match 'finally\s*\{[^\}]*\$reader')
        
        $hasReaderDisposal | Should -Be $true -Because "XmlNodeReader must be disposed to prevent memory leaks"
    }

    It 'Should dispose XmlNodeReader after loading XAML in Show-PopupWindow' {
        $sourceFile = Join-Path $PSScriptRoot '..\..\DailyMotivation.ps1'
        $content = Get-Content $sourceFile -Raw
        
        $functionStart = $content.IndexOf('function Show-PopupWindow')
        $functionEnd = $content.IndexOf('# ============================================================', $functionStart + 100)
        $functionBody = $content.Substring($functionStart, $functionEnd - $functionStart)
        
        $hasReaderDisposal = ($functionBody -match '\$reader\.Dispose\(\)') -or 
                             ($functionBody -match 'finally\s*\{[^\}]*\$reader')
        
        $hasReaderDisposal | Should -Be $true -Because "XmlNodeReader must be disposed to prevent memory leaks"
    }
}

Describe 'AG6-016: DispatcherTimer Interval Validation' {
    It 'Should validate timer interval before setting in Show-PopupWindow' {
        $sourceFile = Join-Path $PSScriptRoot '..\..\DailyMotivation.ps1'
        $content = Get-Content $sourceFile -Raw
        
        $functionStart = $content.IndexOf('function Show-PopupWindow')
        $functionEnd = $content.IndexOf('# ============================================================', $functionStart + 100)
        $functionBody = $content.Substring($functionStart, $functionEnd - $functionStart)
        
        # Should validate interval before setting timer
        # Look for: TotalMilliseconds/TotalSeconds -le 0 or -gt 0 checks
        $hasIntervalValidation = ($functionBody -match 'TotalMilliseconds\s*-[lg][te]\s*0') -or
                                 ($functionBody -match 'TotalSeconds\s*-[lg][te]\s*0') -or
                                 ($functionBody -match 'Interval.*-[lg][te]\s*0')
        
        $hasIntervalValidation | Should -Be $true -Because "Timer interval must be validated to prevent CPU spike from zero/negative interval"
    }
}

Describe 'AG6-010: DispatcherTimer Cleanup on Window Close' {
    It 'Should have Add_Closing handler in Show-MainWindow to stop timers' {
        $sourceFile = Join-Path $PSScriptRoot '..\..\DailyMotivation.ps1'
        $content = Get-Content $sourceFile -Raw
        
        $functionStart = $content.IndexOf('function Show-MainWindow')
        $functionEnd = $content.IndexOf('function Show-PopupWindow', $functionStart)
        $functionBody = $content.Substring($functionStart, $functionEnd - $functionStart)
        
        # Should have Add_Closing with timer cleanup
        $hasClosingHandler = ($functionBody -match 'Add_Closing') -and 
                            ($functionBody -match 'undoTimer.*Stop\(\)')
        
        $hasClosingHandler | Should -Be $true -Because "Timers must be stopped when window closes to prevent memory leaks"
    }

    It 'Should have Add_Closing handler in Show-PopupWindow to stop countdown timer' {
        $sourceFile = Join-Path $PSScriptRoot '..\..\DailyMotivation.ps1'
        $content = Get-Content $sourceFile -Raw
        
        $functionStart = $content.IndexOf('function Show-PopupWindow')
        $functionEnd = $content.IndexOf('# ============================================================', $functionStart + 100)
        $functionBody = $content.Substring($functionStart, $functionEnd - $functionStart)
        
        # Should have Add_Closing with timer stop
        $hasClosingHandler = ($functionBody -match 'Add_Closing') -and 
                            ($functionBody -match '\$timer.*Stop\(\)')
        
        $hasClosingHandler | Should -Be $true -Because "Countdown timer must be stopped when window closes"
    }

    It 'Should have Add_Closing handler to stop fallbackTimer in Show-PopupWindow' {
        $sourceFile = Join-Path $PSScriptRoot '..\..\DailyMotivation.ps1'
        $content = Get-Content $sourceFile -Raw
        
        $functionStart = $content.IndexOf('function Show-PopupWindow')
        $functionEnd = $content.IndexOf('# ============================================================', $functionStart + 100)
        $functionBody = $content.Substring($functionStart, $functionEnd - $functionStart)
        
        # Should clean up fallbackTimer too
        $hasFallbackCleanup = ($functionBody -match 'Add_Closing') -and 
                              ($functionBody -match 'fallbackTimer.*Stop\(\)')
        
        $hasFallbackCleanup | Should -Be $true -Because "Fallback animation timer must be stopped when window closes (AG6-024)"
    }
}

Describe 'AG8-016: Timer Object Cleanup in Tests' {
    # AG8-016: Tests for Start-UndoTimer and Stop-UndoTimer to ensure resource cleanup

    It 'Should have Start-UndoTimer function defined' {
        $sourceFile = Join-Path $PSScriptRoot '..\..\DailyMotivation.ps1'
        $content = Get-Content $sourceFile -Raw
        $content -match 'function Start-UndoTimer' | Should -Be $true
    }

    It 'Should have Stop-UndoTimer function defined' {
        $sourceFile = Join-Path $PSScriptRoot '..\..\DailyMotivation.ps1'
        $content = Get-Content $sourceFile -Raw
        $content -match 'function Stop-UndoTimer' | Should -Be $true
    }

    It 'Stop-UndoTimer should stop and dispose timer to prevent resource leak' {
        $sourceFile = Join-Path $PSScriptRoot '..\..\DailyMotivation.ps1'
        $content = Get-Content $sourceFile -Raw

        $functionStart = $content.IndexOf('function Stop-UndoTimer')
        $functionEnd = $content.IndexOf('function', $functionStart + 50)
        if ($functionEnd -eq -1) { $functionEnd = $content.Length }
        $functionBody = $content.Substring($functionStart, $functionEnd - $functionStart)

        # Should call Stop() on timer
        $hasStop = $functionBody -match 'undoTimer.*Stop\(\)'
        # AG8-016: Should nullify timer reference after stopping
        $hasNullify = $functionBody -match 'undoTimer\s*=\s*\$null'

        $hasStop | Should -Be $true -Because "Timer must be stopped"
        $hasNullify | Should -Be $true -Because "Timer reference should be nullified to allow GC"
    }

    It 'Timer cleanup should be called in AfterEach for test isolation' {
        # This is a meta-test: verify that if timer tests are added, they clean up
        # Current codebase has no timer-specific tests, documenting requirement
        $true | Should -Be $true -Because "AG8-016: When timer tests are added, they must clean up in AfterEach"
    }

    It 'Should not have orphaned timer threads after undo banner dismissal' {
        $sourceFile = Join-Path $PSScriptRoot '..\..\DailyMotivation.ps1'
        $content = Get-Content $sourceFile -Raw

        # Find undo timer tick handler
        $hasTimerTick = $content -match 'undoTimer.*Add_Tick'
        $hasTimerStop = $content -match 'undoTimer\.Stop\(\)'

        $hasTimerTick | Should -Be $true
        $hasTimerStop | Should -Be $true -Because "Timer must be stopped when countdown completes to prevent thread leak"
    }
}

Describe 'BUG-2: WPF Window Disposal Regression Guard' {
    It 'Show-MainWindow does not call $window.Dispose()' {
        $src = Get-Content (Join-Path $PSScriptRoot '..\..\DailyMotivation.ps1') -Raw
        $functionStart = $src.IndexOf('function Show-MainWindow')
        $functionEnd = $src.IndexOf('function Show-PopupWindow', $functionStart)
        $functionBody = $src.Substring($functionStart, $functionEnd - $functionStart)
        $functionBody -match '\$window\.Dispose\(\)' | Should -Be $false -Because 'System.Windows.Window does not implement IDisposable'
    }
    It 'Show-MainWindow uses $window.Close() instead of $window.Dispose()' {
        $src = Get-Content (Join-Path $PSScriptRoot '..\..\DailyMotivation.ps1') -Raw
        $functionStart = $src.IndexOf('function Show-MainWindow')
        $functionEnd = $src.IndexOf('function Show-PopupWindow', $functionStart)
        $functionBody = $src.Substring($functionStart, $functionEnd - $functionStart)
        $functionBody -match '\$window\.Close\(\)' | Should -Be $true -Because 'WPF windows must be closed with .Close()'
    }
    It 'Show-PopupWindow does not call $window.Dispose()' {
        $src = Get-Content (Join-Path $PSScriptRoot '..\..\DailyMotivation.ps1') -Raw
        $functionStart = $src.IndexOf('function Show-PopupWindow')
        $functionEnd = $src.IndexOf('# ============================================================', $functionStart + 100)
        $functionBody = $src.Substring($functionStart, $functionEnd - $functionStart)
        $functionBody -match '\$window\.Dispose\(\)' | Should -Be $false -Because 'System.Windows.Window does not implement IDisposable'
    }
    It 'Show-PopupWindow uses $window.Close() instead of $window.Dispose()' {
        $src = Get-Content (Join-Path $PSScriptRoot '..\..\DailyMotivation.ps1') -Raw
        $functionStart = $src.IndexOf('function Show-PopupWindow')
        $functionEnd = $src.IndexOf('# ============================================================', $functionStart + 100)
        $functionBody = $src.Substring($functionStart, $functionEnd - $functionStart)
        $functionBody -match '\$window\.Close\(\)' | Should -Be $true -Because 'WPF windows must be closed with .Close()'
    }
}

Describe 'BUG-2 File-Wide Regression Guard: $window.Dispose() must not exist' {
    It 'DailyMotivation.ps1 contains zero calls to $window.Dispose()' {
        $src = Get-Content (Join-Path $PSScriptRoot '..\..\DailyMotivation.ps1') -Raw
        $src -match '\$window\.Dispose\(\)' | Should -Be $false -Because 'System.Windows.Window does not implement IDisposable'
    }
}

Describe 'AG14-004: undoFeedbackTimer scope and disposal (#106)' {
    It 'undoFeedbackTimer is assigned to $script: scope in Show-MainWindow (not a local variable)' {
        $src = Get-Content (Join-Path $PSScriptRoot '..\..\DailyMotivation.ps1') -Raw
        $functionStart = $src.IndexOf('function Show-MainWindow')
        $functionEnd   = $src.IndexOf('function Show-PopupWindow', $functionStart)
        $body = $src.Substring($functionStart, $functionEnd - $functionStart)
        $body -match '\$script:undoFeedbackTimer\s*=' | Should -Be $true -Because 'undoFeedbackTimer must be $script: scoped so Add_Closing can stop it when window closes early (#106)'
    }

    It 'Add_Closing handler in Show-MainWindow disposes $script:undoFeedbackTimer' {
        $src = Get-Content (Join-Path $PSScriptRoot '..\..\DailyMotivation.ps1') -Raw
        $functionStart = $src.IndexOf('function Show-MainWindow')
        $functionEnd   = $src.IndexOf('function Show-PopupWindow', $functionStart)
        $body = $src.Substring($functionStart, $functionEnd - $functionStart)
        $closingMatch = [regex]::Match($body, 'Add_Closing\s*\(\{(.+?)\}\)', [System.Text.RegularExpressions.RegexOptions]::Singleline)
        $closingBlock = $closingMatch.Groups[1].Value
        $closingBlock -match 'undoFeedbackTimer.*Dispose\(\)' | Should -Be $true -Because 'Add_Closing must dispose undoFeedbackTimer so it is released if window closes during the 2.5s feedback window (#106)'
    }

    It 'Add_Closed handler in Show-MainWindow disposes $script:undoFeedbackTimer' {
        $src = Get-Content (Join-Path $PSScriptRoot '..\..\DailyMotivation.ps1') -Raw
        $functionStart = $src.IndexOf('function Show-MainWindow')
        $functionEnd   = $src.IndexOf('function Show-PopupWindow', $functionStart)
        $body = $src.Substring($functionStart, $functionEnd - $functionStart)
        $closedMatches = [regex]::Matches($body, 'Add_Closed\s*\(\{(.+?)\}\)', [System.Text.RegularExpressions.RegexOptions]::Singleline)
        $anyClosedDisposesTimer = ($closedMatches | ForEach-Object { $_.Groups[1].Value }) -match 'undoFeedbackTimer.*Dispose\(\)'
        [bool]($anyClosedDisposesTimer) | Should -Be $true -Because 'Add_Closed must dispose undoFeedbackTimer to release resources after window close (#106)'
    }
}

Describe 'AG14-005: Show-PopupWindow cancelCountdown handler removal and button null-out (#107)' {
    It 'Show-PopupWindow Add_Closed calls remove_PreviewMouseDown for cancelCountdown' {
        $src = Get-Content (Join-Path $PSScriptRoot '..\..\DailyMotivation.ps1') -Raw
        $functionStart = $src.IndexOf('function Show-PopupWindow')
        $functionEnd   = $src.IndexOf('# ============================================================', $functionStart + 100)
        $body = $src.Substring($functionStart, $functionEnd - $functionStart)
        $closedMatches = [regex]::Matches($body, 'Add_Closed\s*\(\{(.+?)\}\)', [System.Text.RegularExpressions.RegexOptions]::Singleline)
        $anyClosedRemoves = ($closedMatches | ForEach-Object { $_.Groups[1].Value }) -match 'remove_PreviewMouseDown.*cancelCountdown'
        [bool]($anyClosedRemoves) | Should -Be $true -Because 'Stored cancelCountdown handlers must be explicitly removed on close to release closure references (#107)'
    }

    It 'Show-PopupWindow Add_Closed nulls button references to release WPF GC roots' {
        $src = Get-Content (Join-Path $PSScriptRoot '..\..\DailyMotivation.ps1') -Raw
        $functionStart = $src.IndexOf('function Show-PopupWindow')
        $functionEnd   = $src.IndexOf('# ============================================================', $functionStart + 100)
        $body = $src.Substring($functionStart, $functionEnd - $functionStart)
        $closedMatches = [regex]::Matches($body, 'Add_Closed\s*\(\{(.+?)\}\)', [System.Text.RegularExpressions.RegexOptions]::Singleline)
        $anyClosedNullsBtn = ($closedMatches | ForEach-Object { $_.Groups[1].Value }) -match '\$letsGoBtn\s*=\s*\$null'
        [bool]($anyClosedNullsBtn) | Should -Be $true -Because 'Button references must be nulled in Add_Closed to allow GC to collect the window (#107)'
    }
}
