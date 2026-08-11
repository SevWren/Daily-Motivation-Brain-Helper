# Plan: Fix BUG-2 — Replace $window.Dispose() with $window.Close() in Show-MainWindow and Show-PopupWindow

## Context
BUG-2 causes `MissingMethodException` on every app close because `System.Windows.Window` does not implement `System.IDisposable`. The fix is two `.Dispose()` → `.Close()` substitutions plus one comment correction, plus replacing an inverted regression test. BUG-1's single-line fix (line 2805) is bundled here because it shares the same `finally` block.

## Prerequisites
- Windows 10/11 machine
- PowerShell 7 (`pwsh`) terminal in project root
- Clean test baseline: `.\Invoke-Tests.ps1` (expected: Passed=359, Failed=0, Skipped=7)

## Changes (in order)

### 1. Fix `Show-MainWindow` finally block — `DailyMotivation.ps1:2137`
Change:
```powershell
$window.Dispose()
```
To:
```powershell
$window.Close()
```

### 2. Fix `Show-PopupWindow` finally block — `DailyMotivation.ps1:2795-2798`
- Line 2795: change comment from `# Dispose WPF window to release resources` to `# Close WPF window to release resources`
- Line 2798: change `$window.Dispose()` to `$window.Close()`

### 3. Remove BUG-1 line — `DailyMotivation.ps1:2805`
Remove the line `$script:openExplorer = $true` from the `finally` block. This line unconditionally resets state after every popup, overriding the button handlers.

**Coordination note:** The BUG-1 plan (`daily-brief-2026-08-09-bug1-openexplorer-fix.md`) also describes this deletion as a standalone fix. This BUG-2 plan bundles it for commit atomicity (both changes are in the same `finally` block). If BUG-1 is applied independently first, skip this step. Confirm with the BUG-1 owner before executing to avoid double-deletion.

### 4. Replace inverted regression test — `Tests/Unit/UIDisposal.Tests.ps1:163-193`
Remove the `Describe 'AG6-004: Window Disposal After ShowDialog'` block entirely. It currently asserts `$window.Dispose()` must exist (anti-pattern).

Replace with a regression guard that asserts:
- `$window.Dispose()` must NOT appear in `Show-MainWindow` or `Show-PopupWindow`
- `$window.Close()` must appear in both functions

**Test source:** The exact replacement block is documented in issue #183. Fetch the `BUG-2: WPF Window Disposal Regression Guard` and `BUG-2 File-Wide Regression Guard` test blocks from the issue comments. If unavailable, author equivalent structural tests using the same substring/regex pattern as the current block, but inverted to assert absence of `Dispose` and presence of `Close`.

## Validation

1. Run `.\Invoke-Tests.ps1` on Windows 10/11 PowerShell 7.
   - Expected: Passed ≥ 359, Failed = 0, Skipped ≤ 7
   - New/modified UIDisposal tests must pass
   - No new failures introduced
   - Attach the full terminal output as a comment on issue #183 before closing (required per CLAUDE.md GitHub Issue Closure Gate).

2. Live Windows validation (manual, required before closing issue #183):
   - Run `DailyMotivation.exe` (non-elevated)
   - Close the main window → **no error dialog** should appear
   - Verify `Method invocation failed because [System.Windows.Window] does not contain a method named 'Dispose'` no longer surfaces

## Files Modified
- `DailyMotivation.ps1` (lines 2137, 2795, 2798, 2805)
- `Tests/Unit/UIDisposal.Tests.ps1` (replace lines 163-193)

## Risk
Low. Changes are mechanical substitutions. The test replacement must happen atomically with the code fix or CI will fail (current test asserts the anti-pattern).

## Rollout
Direct commit to `main`. No migration or backward-compat concerns.

## Suggested Commit Messages
```
fix(popup): replace $window.Dispose() with $window.Close() (BUG-2)
fix(popup): remove $script:openExplorer reset from Show-PopupWindow finally block (BUG-1)
test(UIDisposal): replace AG6-004 Dispose-must-exist assertion with Dispose-must-NOT-exist regression guard
```
