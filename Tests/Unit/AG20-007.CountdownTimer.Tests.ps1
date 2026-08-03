#Requires -Modules Pester
<#
.SYNOPSIS
    TDD tests for AG20-007 — system clock change during popup countdown execution.

.DESCRIPTION
    Issue #162: The popup countdown uses $script:remaining-- on each DispatcherTimer tick
    (1-second interval). If the system clock is adjusted backward the timer continues ticking
    but perceived elapsed time diverges from wall time. No wall-clock fallback exists.

    Test coverage in this file:
      1. Cross-platform: Get-PopupConfig returns an object that does NOT carry a
         countdown_seconds field — documenting that no config-driven countdown duration
         is wired up (the hardcoded value of 20 is used instead).
      2. Cross-platform (Pending): Get-CountdownElapsed / wall-clock fallback interface
         does not exist — this pending test is the TDD red specification.
      3. Cross-platform (Pending): Set-CountdownDuration public seam does not exist —
         pending test expresses the desired interface.
      4. Windows-only (-Skip): Show-PopupWindow countdown initialises from a configurable
         value — currently hardcoded; skipped on non-Windows because WPF requires Windows/STA.
#>

BeforeAll {
    . (Join-Path $PSScriptRoot '..\..\DailyMotivation.ps1') -NoRun
    $script:OriginalAppData = $env:APPDATA
    $env:APPDATA = Join-Path ([System.IO.Path]::GetTempPath()) "DMBH_Countdown_$(New-Guid)"
    Initialize-AppData
}

AfterAll {
    if (Test-Path $env:APPDATA) { Remove-Item -Path $env:APPDATA -Recurse -Force -ErrorAction SilentlyContinue }
    $env:APPDATA = $script:OriginalAppData
}

# ---------------------------------------------------------------------------
# 1. Config schema — countdown_seconds is absent from popup_config.json
#    (cross-platform, always runs)
# ---------------------------------------------------------------------------
Describe 'Get-PopupConfig — countdown duration field' {
    Context 'When popup_config.json does not exist' {
        It 'Returns the default fallback object without a countdown_seconds field' {
            # Remove any pre-existing popup config so we get the hardcoded fallback path.
            $cfgPath = Join-Path $env:APPDATA 'DailyMotivationBrainHelper\popup_config.json'
            if (Test-Path $cfgPath) { Remove-Item $cfgPath -Force }

            $cfg = Get-PopupConfig

            # The default fallback has these mandatory fields ...
            $cfg.glyph         | Should -Not -BeNullOrEmpty -Because 'glyph must always be present'
            $cfg.PSObject.Properties.Name | Should -Contain 'explorer_path'

            # ... but no countdown_seconds field — documenting the gap described in AG20-007.
            # The countdown is hardcoded to 20 inside Show-PopupWindow; it is not driven by config.
            $cfg.PSObject.Properties.Name | Should -Not -Contain 'countdown_seconds' `
                -Because 'AG20-007: countdown duration is currently hardcoded, not config-driven; this test documents the gap'
        }
    }

    Context 'When popup_config.json is written by Set-PopupConfig' {
        It 'Written config still does not include a countdown_seconds field' {
            Set-PopupConfig -Glyph '[*]' -Title 'Test Title' -Body 'Test body' `
                            -ExplorerPath 'C:\TestFolder' -TaskId 'task-abc'

            $cfg = Get-PopupConfig

            $cfg.PSObject.Properties.Name | Should -Not -Contain 'countdown_seconds' `
                -Because 'AG20-007: Set-PopupConfig does not accept or persist a countdown duration'
        }

        It 'Written config round-trips the expected fields intact' {
            Set-PopupConfig -Glyph '[>]' -Title 'Focus Time' -Body 'Just start.' `
                            -ExplorerPath 'C:\Work' -TaskId 'task-xyz'

            $cfg = Get-PopupConfig

            $cfg.glyph         | Should -Be '[>]'
            $cfg.title         | Should -Be 'Focus Time'
            $cfg.body          | Should -Be 'Just start.'
            $cfg.explorer_path | Should -Be 'C:\Work'
            $cfg.task_id       | Should -Be 'task-xyz'
        }
    }
}

# ---------------------------------------------------------------------------
# 2. Pending (red) — wall-clock fallback public interface does not yet exist
#    TDD specification: a Get-CountdownElapsed function must be added so that
#    the popup timer can detect clock skew and correct $script:remaining.
# ---------------------------------------------------------------------------
Describe 'Get-CountdownElapsed — wall-clock fallback seam' {
    It 'Get-CountdownElapsed command exists as a public function' -Pending {
        # AG20-007 TDD red test.
        # This test will pass once a wall-clock-based fallback is implemented.
        # Expected contract:
        #   Get-CountdownElapsed -StartTime <DateTime> returns elapsed seconds as [int].
        # The popup timer tick handler should compare this value against $script:remaining
        # to detect backward clock adjustments and correct the countdown accordingly.
        $cmd = Get-Command -Name 'Get-CountdownElapsed' -ErrorAction SilentlyContinue
        $cmd | Should -Not -BeNullOrEmpty -Because 'AG20-007: wall-clock fallback requires a public Get-CountdownElapsed seam'
    }
}

# ---------------------------------------------------------------------------
# 3. Pending (red) — configurable countdown duration public seam does not exist
#    TDD specification: a Set-CountdownDuration (or equivalent) function should
#    allow callers to specify how many seconds the popup countdown runs, enabling
#    tests to exercise the timer logic with short durations.
# ---------------------------------------------------------------------------
Describe 'Set-CountdownDuration — configurable duration seam' {
    It 'Set-CountdownDuration command exists as a public function' -Pending {
        # AG20-007 TDD red test.
        # Currently $script:remaining is hardcoded to 20 in Show-PopupWindow.
        # A Set-CountdownDuration function (or a -CountdownSeconds parameter on
        # Show-PopupWindow) would allow unit tests to inject a 1-second countdown
        # and verify timer behaviour without waiting 20 real seconds.
        $cmd = Get-Command -Name 'Set-CountdownDuration' -ErrorAction SilentlyContinue
        $cmd | Should -Not -BeNullOrEmpty -Because 'AG20-007: testable countdown requires a configurable duration seam'
    }
}

# ---------------------------------------------------------------------------
# 4. Windows-only — wall-clock fallback behaviour during backward clock skew
#    Skipped on non-Windows because Show-PopupWindow requires WPF / STA thread.
# ---------------------------------------------------------------------------
Describe 'Show-PopupWindow — wall-clock fallback for system clock change' -Skip:(-not $IsWindows) {
    It 'Wall-clock fallback for system clock changes is not yet implemented — this test documents the missing behaviour specification' {
        Set-ItResult -Skipped -Because 'AG20-007: No wall-clock fallback mechanism exists. The DispatcherTimer tick handler decrements $script:remaining by 1 on every tick regardless of actual elapsed wall time. A backward system-clock adjustment will cause the countdown to display a remaining time that does not match real elapsed seconds. This test is the TDD specification: once a wall-clock seam (e.g. Get-CountdownElapsed) is added and wired into the tick handler, replace this Skip with a real assertion that verifies $script:remaining is corrected when the clock is set back.'
    }
}
