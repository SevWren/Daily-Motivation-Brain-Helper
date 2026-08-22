#Requires -Modules Pester
<#
.SYNOPSIS
    Unit tests for UI/WPF resource disposal and lifecycle management (AG6-004, AG6-010, AG6-016, AG6-018).
    Tests window disposal, timer cleanup, and reader disposal.
#>

BeforeAll {
    . (Join-Path $PSScriptRoot '..\..\DailyMotivation.ps1') -NoRun
    $script:SourceContent = Get-Content (Join-Path $PSScriptRoot '..\..\DailyMotivation.ps1') -Raw
}

Describe 'AG6-018: XmlNodeReader Disposal' {
    It 'Should dispose XmlNodeReader after loading XAML in Show-MainWindow' {
        # Look for the Show-MainWindow function and check if reader is disposed
        $functionStart = $script:SourceContent.IndexOf('function Show-MainWindow')
        $functionEnd = $script:SourceContent.IndexOf('function Show-PopupWindow', $functionStart)
        $functionBody = $script:SourceContent.Substring($functionStart, $functionEnd - $functionStart)

        # Should have reader.Dispose() or finally block with reader cleanup
        $hasReaderDisposal = ($functionBody -match '\$reader\.Dispose\(\)') -or 
                             ($functionBody -match 'finally\s*\{[^\}]*\$reader')
        
        $hasReaderDisposal | Should -Be $true -Because "XmlNodeReader must be disposed to prevent memory leaks"
    }

    It 'Should dispose XmlNodeReader after loading XAML in Show-PopupWindow' {
        $functionStart = $script:SourceContent.IndexOf('function Show-PopupWindow')
        $functionEnd = $script:SourceContent.IndexOf('# ============================================================', $functionStart + 100)
        $functionBody = $script:SourceContent.Substring($functionStart, $functionEnd - $functionStart)
        
        $hasReaderDisposal = ($functionBody -match '\$reader\.Dispose\(\)') -or 
                             ($functionBody -match 'finally\s*\{[^\}]*\$reader')
        
        $hasReaderDisposal | Should -Be $true -Because "XmlNodeReader must be disposed to prevent memory leaks"
    }
}

Describe 'AG6-016: DispatcherTimer Interval Validation' {
    It 'Should validate timer interval before setting in Show-PopupWindow' {
        $functionStart = $script:SourceContent.IndexOf('function Show-PopupWindow')
        $functionEnd = $script:SourceContent.IndexOf('# ============================================================', $functionStart + 100)
        $functionBody = $script:SourceContent.Substring($functionStart, $functionEnd - $functionStart)
        
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
        $functionStart = $script:SourceContent.IndexOf('function Show-MainWindow')
        $functionEnd = $script:SourceContent.IndexOf('function Show-PopupWindow', $functionStart)
        $functionBody = $script:SourceContent.Substring($functionStart, $functionEnd - $functionStart)
        
        # Should have Add_Closing with timer cleanup
        $hasClosingHandler = ($functionBody -match 'Add_Closing') -and 
                            ($functionBody -match 'undoTimer.*Stop\(\)')
        
        $hasClosingHandler | Should -Be $true -Because "Timers must be stopped when window closes to prevent memory leaks"
    }

    It 'Should have Add_Closing handler in Show-PopupWindow to stop countdown timer' {
        $functionStart = $script:SourceContent.IndexOf('function Show-PopupWindow')
        $functionEnd = $script:SourceContent.IndexOf('# ============================================================', $functionStart + 100)
        $functionBody = $script:SourceContent.Substring($functionStart, $functionEnd - $functionStart)
        
        # Should have Add_Closing with timer stop
        $hasClosingHandler = ($functionBody -match 'Add_Closing') -and 
                            ($functionBody -match '\$timer.*Stop\(\)')
        
        $hasClosingHandler | Should -Be $true -Because "Countdown timer must be stopped when window closes"
    }

    It 'Should have Add_Closing handler to stop fallbackTimer in Show-PopupWindow' {
        $functionStart = $script:SourceContent.IndexOf('function Show-PopupWindow')
        $functionEnd = $script:SourceContent.IndexOf('# ============================================================', $functionStart + 100)
        $functionBody = $script:SourceContent.Substring($functionStart, $functionEnd - $functionStart)
        
        # Should clean up fallbackTimer too
        $hasFallbackCleanup = ($functionBody -match 'Add_Closing') -and 
                              ($functionBody -match 'fallbackTimer.*Stop\(\)')
        
        $hasFallbackCleanup | Should -Be $true -Because "Fallback animation timer must be stopped when window closes (AG6-024)"
    }
}

Describe 'AG8-016: Timer Object Cleanup in Tests' {
    # AG8-016: Tests for Start-UndoTimer and Stop-UndoTimer to ensure resource cleanup

    It 'Should have Start-UndoTimer function defined' {
        $script:SourceContent -match 'function Start-UndoTimer' | Should -Be $true
    }

    It 'Should have Stop-UndoTimer function defined' {
        $script:SourceContent -match 'function Stop-UndoTimer' | Should -Be $true
    }

    It 'Stop-UndoTimer should stop and dispose timer to prevent resource leak' {
        $functionStart = $script:SourceContent.IndexOf('function Stop-UndoTimer')
        $functionEnd = $script:SourceContent.IndexOf('function', $functionStart + 50)
        if ($functionEnd -eq -1) { $functionEnd = $script:SourceContent.Length }
        $functionBody = $script:SourceContent.Substring($functionStart, $functionEnd - $functionStart)

        # Should call Stop() on timer
        $hasStop = $functionBody -match 'undoTimer.*Stop\(\)'
        # AG8-016: Should nullify timer reference after stopping
        $hasNullify = $functionBody -match 'undoTimer\s*=\s*\$null'

        $hasStop | Should -Be $true -Because "Timer must be stopped"
        $hasNullify | Should -Be $true -Because "Timer reference should be nullified to allow GC"
    }

    It 'Should not have orphaned timer threads after undo banner dismissal' {
        # Find undo timer tick handler
        $hasTimerTick = $script:SourceContent -match 'undoTimer.*Add_Tick'
        $hasTimerStop = $script:SourceContent -match 'undoTimer\.Stop\(\)'

        $hasTimerTick | Should -Be $true
        $hasTimerStop | Should -Be $true -Because "Timer must be stopped when countdown completes to prevent thread leak"
    }
}

Describe 'BUG-2: WPF Window Disposal Regression Guard' {
    It 'Show-MainWindow does not call $window.Dispose()' {
        $functionStart = $script:SourceContent.IndexOf('function Show-MainWindow')
        $functionEnd = $script:SourceContent.IndexOf('function Show-PopupWindow', $functionStart)
        $functionBody = $script:SourceContent.Substring($functionStart, $functionEnd - $functionStart)
        $functionBody -match '\$window\.Dispose\(\)' | Should -Be $false -Because 'System.Windows.Window does not implement IDisposable'
    }
    It 'Show-MainWindow uses $window.Close() instead of $window.Dispose()' {
        $functionStart = $script:SourceContent.IndexOf('function Show-MainWindow')
        $functionEnd = $script:SourceContent.IndexOf('function Show-PopupWindow', $functionStart)
        $functionBody = $script:SourceContent.Substring($functionStart, $functionEnd - $functionStart)
        $functionBody -match '\$window\.Close\(\)' | Should -Be $true -Because 'WPF windows must be closed with .Close()'
    }
    It 'Show-PopupWindow does not call $window.Dispose()' {
        $functionStart = $script:SourceContent.IndexOf('function Show-PopupWindow')
        $functionEnd = $script:SourceContent.IndexOf('# ============================================================', $functionStart + 100)
        $functionBody = $script:SourceContent.Substring($functionStart, $functionEnd - $functionStart)
        $functionBody -match '\$window\.Dispose\(\)' | Should -Be $false -Because 'System.Windows.Window does not implement IDisposable'
    }
    It 'Show-PopupWindow uses $window.Close() instead of $window.Dispose()' {
        $functionStart = $script:SourceContent.IndexOf('function Show-PopupWindow')
        $functionEnd = $script:SourceContent.IndexOf('# ============================================================', $functionStart + 100)
        $functionBody = $script:SourceContent.Substring($functionStart, $functionEnd - $functionStart)
        $functionBody -match '\$window\.Close\(\)' | Should -Be $true -Because 'WPF windows must be closed with .Close()'
    }
}

Describe 'BUG-2 File-Wide Regression Guard: $window.Dispose() must not exist' {
    It 'DailyMotivation.ps1 contains zero calls to $window.Dispose()' {
        $script:SourceContent -match '\$window\.Dispose\(\)' | Should -Be $false -Because 'System.Windows.Window does not implement IDisposable'
    }
}
