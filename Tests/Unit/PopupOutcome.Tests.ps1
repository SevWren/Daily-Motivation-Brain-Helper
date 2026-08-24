#Requires -Modules Pester
<#
.SYNOPSIS
    BUG-1 regression tests (issue #183): the Popup Outcome must reflect the
    action the user actually took (or the countdown auto-open), never a fixed
    "Opened" default.

.DESCRIPTION
    Root cause: Show-PopupWindow's finally block reset $script:openExplorer /
    $script:snoozeCount / $script:pathMissing / $script:newExplorerPath to their
    defaults AFTER ShowDialog() returned but BEFORE the post-close cleanup and
    outcome-logging logic read them. As a result the outcome was always forced
    to "Opened" and the RePick effective path reverted to the stale folder.

    The state variables are already initialised once at the top of the function
    (the "# State" block), so the finally-block resets are both redundant and
    actively wrong.

    Coverage in this file (cross-platform, no WPF needed):
      1. Get-PopupOutcome  -  the pure state-to-outcome mapping (deterministic).
      2. Show-PopupWindow cleanup-region guard  -  the region between ShowDialog()
         and the post-close logic must NOT reassign any outcome-determining
         state variable (the exact BUG-1 regression).
#>

BeforeAll {
    . (Join-Path $PSScriptRoot '..\..\DailyMotivation.ps1') -NoRun
}

Describe 'Get-PopupOutcome  -  state to outcome mapping' {
    BeforeAll {
        # Stored in BeforeAll, not the Describe body: Pester 5 runs Describe-body
        # statements only during discovery, so a plain assignment there is invisible
        # to the It body at run time and throws "variable not set" under the
        # runner's Set-StrictMode -Version Latest.
        $script:cases = @(
            # Open Folder button, countdown auto-open, or RePick success
            @{ Name = 'open folder / countdown / re-pick';     PathMissing = $false; OpenExplorer = $true;  SnoozeCount = 0; Expected = 'Opened'      },
            # Dismiss for Today / Exit item  -  closed without opening
            @{ Name = 'dismiss / exit (no open)';              PathMissing = $false; OpenExplorer = $false; SnoozeCount = 0; Expected = 'Dismissed'   },
            # Snooze once (or more) then close
            @{ Name = 'snooze once then close';                PathMissing = $false; OpenExplorer = $false; SnoozeCount = 1; Expected = 'Snoozed'    },
            @{ Name = 'snooze multiple times then close';      PathMissing = $false; OpenExplorer = $false; SnoozeCount = 3; Expected = 'Snoozed'    },
            # Folder missing, user closed without re-picking
            @{ Name = 'path missing, user closed';             PathMissing = $true;  OpenExplorer = $false; SnoozeCount = 0; Expected = 'PathMissing' },
            # Folder missing but user re-picked a new folder
            @{ Name = 'path missing, user re-picked';          PathMissing = $true;  OpenExplorer = $true;  SnoozeCount = 0; Expected = 'Opened'      }
        )
    }

    It 'Maps every documented session state to its canonical outcome' {
        foreach ($c in $script:cases) {
            $actual = Get-PopupOutcome -PathMissing $c.PathMissing -OpenExplorer $c.OpenExplorer -SnoozeCount $c.SnoozeCount
            $actual | Should -Be $c.Expected -Because "case: $($c.Name)"
        }
    }

    It 'Opens the folder when OpenExplorer is true even if snoozes occurred' {
        # Precedence: Opened wins over Snoozed (user snoozed then opened).
        Get-PopupOutcome -PathMissing $false -OpenExplorer $true -SnoozeCount 2 | Should -Be 'Opened'
    }
}

Describe 'BUG-1 regression  -  Show-PopupWindow cleanup must not clobber outcome state' {
    BeforeAll {
        $src = Get-Content (Join-Path $PSScriptRoot '..\..\DailyMotivation.ps1') -Raw
        $functionStart = $src.IndexOf('function Show-PopupWindow')
        $functionEnd   = $src.IndexOf('# ============================================================', $functionStart + 100)
        $script:popupBody = $src.Substring($functionStart, $functionEnd - $functionStart)

        # The cleanup region is everything between the window's ShowDialog() call
        # and the post-close comment  -  i.e. the try/catch/finally wrapper around
        # the modal dialog. Anchor on $window.ShowDialog() specifically (the RePick
        # folder handler calls a different $dialog.ShowDialog() earlier).
        $showDialogIdx = $script:popupBody.IndexOf('$window.ShowDialog()')
        $postCloseIdx  = $script:popupBody.IndexOf('# Post-close')
        $script:cleanupRegion = $script:popupBody.Substring(
            $showDialogIdx, $postCloseIdx - $showDialogIdx)
    }

    It 'Cleanup region does not reassign $script:openExplorer' {
        $script:cleanupRegion -match '\$script:openExplorer\s*=' | Should -Be $false -Because 'resetting openExplorer here forces the outcome to "Opened" regardless of the button clicked (BUG-1)'
    }

    It 'Cleanup region does not reassign $script:snoozeCount' {
        $script:cleanupRegion -match '\$script:snoozeCount\s*=' | Should -Be $false -Because 'resetting snoozeCount here makes Snoozed/unable-to-distinguish from Dismissed'
    }

    It 'Cleanup region does not reassign $script:pathMissing' {
        $script:cleanupRegion -match '\$script:pathMissing\s*=' | Should -Be $false -Because 'resetting pathMissing here loses the PathMissing outcome'
    }

    It 'Cleanup region does not reassign $script:newExplorerPath' {
        $script:cleanupRegion -match '\$script:newExplorerPath\s*=' | Should -Be $false -Because 'resetting newExplorerPath here reverts a RePick folder to the stale path'
    }

    It 'Outcome is derived by Get-PopupOutcome in the post-close section' {
        # Guard the fix shape: the post-close logic obtains the outcome from the
        # pure helper rather than an inline if/else that can be clobbered.
        $postCloseIdx = $script:popupBody.IndexOf('# Post-close')
        $tail = $script:popupBody.Substring($postCloseIdx)
        $tail -match 'Get-PopupOutcome' | Should -Be $true -Because 'post-close logic should call Get-PopupOutcome so the mapping is unit-tested'
    }
}

Describe 'AG1-012: Explorer launch includes Test-Path pre-validation' {
    It 'Show-PopupWindow post-close block uses Test-Path before Start-Process explorer' {
        $src = Get-Content (Join-Path $PSScriptRoot '..\..\DailyMotivation.ps1') -Raw
        $postCloseIdx = $src.IndexOf('# Post-close: open Explorer')
        $postCloseEnd = $src.IndexOf('# Log outcome', $postCloseIdx)
        $explorerBlock = $src.Substring($postCloseIdx, $postCloseEnd - $postCloseIdx)
        $explorerBlock -match 'Test-Path' | Should -Be $true -Because 'AG1-012: must validate path exists before launching Explorer'
    }
    It 'Test-Path check precedes Start-Process in the explorer launch block' {
        $src = Get-Content (Join-Path $PSScriptRoot '..\..\DailyMotivation.ps1') -Raw
        $postCloseIdx = $src.IndexOf('# Post-close: open Explorer')
        $postCloseEnd = $src.IndexOf('# Log outcome', $postCloseIdx)
        $explorerBlock = $src.Substring($postCloseIdx, $postCloseEnd - $postCloseIdx)
        $testPathPos   = $explorerBlock.IndexOf('Test-Path')
        $startProcPos  = $explorerBlock.IndexOf('Start-Process')
        $testPathPos   | Should -BeLessThan $startProcPos -Because 'Test-Path guard must come before Start-Process'
    }
}
