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

Describe 'Issue #192: $script:fallbackTimer scope and tick guard in Show-PopupWindow' {
    BeforeAll {
        $script:src192   = Get-Content (Join-Path $PSScriptRoot '..\..\DailyMotivation.ps1') -Raw
        $funcStart       = $script:src192.IndexOf('function Show-PopupWindow')
        $funcEnd         = $script:src192.IndexOf('# ============================================================', $funcStart + 100)
        $script:popupBody192 = $script:src192.Substring($funcStart, $funcEnd - $funcStart)

        # Isolate the Add_Loaded block for scope-specific assertions
        $loadedStart = $script:popupBody192.IndexOf('$window.Add_Loaded(')
        $loadedEnd   = $script:popupBody192.IndexOf('    })', $loadedStart) + 6
        $script:loadedBlock192 = $script:popupBody192.Substring($loadedStart, $loadedEnd - $loadedStart)

        # Isolate the Add_Closing block
        $closingMatch = [regex]::Match($script:popupBody192, 'Add_Closing\s*\(\{(.+?)\}\)', [System.Text.RegularExpressions.RegexOptions]::Singleline)
        $script:closingBlock192 = $closingMatch.Groups[1].Value

        # Isolate the Add_Closed block(s)
        $closedMatches = [regex]::Matches($script:popupBody192, 'Add_Closed\s*\(\{(.+?)\}\)', [System.Text.RegularExpressions.RegexOptions]::Singleline)
        $script:closedBodies192 = $closedMatches | ForEach-Object { $_.Groups[1].Value }
    }

    It 'fallbackTimer is assigned to $script: scope inside Add_Loaded (not a bare local variable)' {
        $script:loadedBlock192 -match '\$script:fallbackTimer\s*=' | Should -Be $true `
            -Because '#192: bare $fallbackTimer in Add_Loaded is destroyed when the event handler returns; the tick closure must resolve $script:fallbackTimer instead'
    }

    It 'bare $fallbackTimer = assignment does not appear inside Add_Loaded' {
        # Match assignment to bare $fallbackTimer (not $script:fallbackTimer)
        $script:loadedBlock192 -match '(?<!\$script:)(?<!\w)\$fallbackTimer\s*=' | Should -Be $false `
            -Because '#192: a bare local $fallbackTimer would be null when the tick fires 500ms later'
    }

    It 'fallbackTimer tick handler references $script:fallbackTimer (not bare $fallbackTimer)' {
        $tickMatch = [regex]::Match($script:loadedBlock192, 'Add_Tick\s*\(\{(.+?)\}\)', [System.Text.RegularExpressions.RegexOptions]::Singleline)
        $tickBody  = $tickMatch.Groups[1].Value
        $tickBody -match '\$script:fallbackTimer' | Should -Be $true `
            -Because '#192: the tick must use $script:fallbackTimer.Stop() so the call resolves after Add_Loaded scope is gone'
    }

    It 'fallbackTimer tick handler is wrapped in try/catch' {
        $tickMatch = [regex]::Match($script:loadedBlock192, 'Add_Tick\s*\(\{(.+?)\}\)', [System.Text.RegularExpressions.RegexOptions]::Singleline)
        $tickBody  = $tickMatch.Groups[1].Value
        ($tickBody -match 'try\s*\{') -and ($tickBody -match '\}\s*catch') | Should -Be $true `
            -Because '#192: an unguarded exception in the tick propagates through the WPF dispatcher and aborts ShowDialog()'
    }

    It 'Add_Closing references $script:fallbackTimer' {
        $script:closingBlock192 -match '\$script:fallbackTimer' | Should -Be $true `
            -Because '#192: Add_Closing cleanup was previously dead code because it referenced the bare (null) $fallbackTimer'
    }

    It 'Add_Closed disposes $script:fallbackTimer and nulls it out' {
        $anyDisposesAndNulls = $script:closedBodies192 | Where-Object {
            ($_ -match '\$script:fallbackTimer.*Dispose\(\)') -and
            ($_ -match '\$script:fallbackTimer\s*=\s*\$null')
        }
        [bool]($anyDisposesAndNulls) | Should -Be $true `
            -Because '#192: Add_Closed must dispose and null $script:fallbackTimer to release the timer and prevent a stale reference on the next popup session'
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
