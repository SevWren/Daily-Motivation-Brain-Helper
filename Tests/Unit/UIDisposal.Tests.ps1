#Requires -Modules Pester
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

Describe 'AG6-004: Window Disposal After ShowDialog' {
    It 'Should have try-finally with window disposal in Show-MainWindow' {
        $sourceFile = Join-Path $PSScriptRoot '..\..\DailyMotivation.ps1'
        $content = Get-Content $sourceFile -Raw
        
        $functionStart = $content.IndexOf('function Show-MainWindow')
        $functionEnd = $content.IndexOf('function Show-PopupWindow', $functionStart)
        $functionBody = $content.Substring($functionStart, $functionEnd - $functionStart)
        
        # Should wrap ShowDialog in try-finally with window disposal
        $hasShowDialog = $functionBody -match 'ShowDialog\(\)'
        $hasDisposal = ($functionBody -match 'finally\s*\{[^\}]*\$window.*Dispose\(\)') -or
                       ($functionBody -match '\$window\.Dispose\(\)[^\}]*\}[^\}]*$')  # At end before function close
        
        ($hasShowDialog -and $hasDisposal) | Should -Be $true -Because "WPF Window implements IDisposable and must be disposed"
    }

    It 'Should have try-finally with window disposal in Show-PopupWindow' {
        $sourceFile = Join-Path $PSScriptRoot '..\..\DailyMotivation.ps1'
        $content = Get-Content $sourceFile -Raw
        
        $functionStart = $content.IndexOf('function Show-PopupWindow')
        $functionEnd = $content.IndexOf('# ============================================================', $functionStart + 100)
        $functionBody = $content.Substring($functionStart, $functionEnd - $functionStart)
        
        $hasShowDialog = $functionBody -match 'ShowDialog\(\)'
        $hasDisposal = ($functionBody -match 'finally\s*\{[^\}]*\$window.*Dispose\(\)') -or
                       ($functionBody -match '\$window\.Dispose\(\)[^\}]*\}[^\}]*$')
        
        ($hasShowDialog -and $hasDisposal) | Should -Be $true -Because "WPF Window implements IDisposable and must be disposed"
    }
}
