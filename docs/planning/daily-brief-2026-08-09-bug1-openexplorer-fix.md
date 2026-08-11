# Plan: BUG-1 Fix — Remove Unconditional `openExplorer = $true` Reset

**Issue:** #183
**File:** `DailyMotivation.ps1`
**Date:** 2026-08-11
**Status:** Implementation-ready

---

## 1. Context

`Show-PopupWindow` has a `finally` block (line 2794–2819) that resets module-level state after every popup session. Line 2805 unconditionally sets `$script:openExplorer = $true`, overriding whatever value the button handlers set. This causes every popup session to log `Opened` and attempt to open Explorer, regardless of which button the user clicked.

**Coordination required with BUG-2:** The BUG-2 plan (`daily-brief-2026-08-09-bug-2-wpf-dispose-fix.md`) also claims the deletion of line 2805 as part of its own scope ("Remove BUG-1 line — `DailyMotivation.ps1:2805`"). Before executing BUG-1 independently, confirm with the BUG-2 owner whether: (a) BUG-1's deletion will be removed from BUG-2's plan so BUG-1 owns it exclusively, or (b) both fixes will be merged into a single commit. If BUG-2 is applied first and modifies the `finally` block (e.g., by replacing `$window.Dispose()` at line 2798 with `$window.Close()`), the line numbers will shift and Step 2 of BUG-1 must be re-verified against the updated file before execution.

## 2. Code Change

**Single-line removal in `DailyMotivation.ps1`.**

| Line | Current | After |
|------|---------|-------|
| 2805 | `$script:openExplorer = $true` | *(delete)* |

The surrounding state resets (`pathMissing`, `newExplorerPath`, `remaining`, `snoozeCount`, `windowClosed`) remain untouched — only `openExplorer` is removed from the finally block.

**Why this is safe:** All five button handlers already set `$script:openExplorer` explicitly before closing the window:
- Exit (2643): `$false`
- Snooze (2654): `$false`
- Dismiss (2687): `$false`
- PathMissing Dismiss (2722): `$false`
- Open Folder (2710): `$true`
- Re-pick folder (2746): `$true`

Removing the finally-block reset allows these handler-assigned values to survive to the post-close check at line 2831.

## 3. Regression Tests

Add source-code structural guards to prevent this pattern from re-entering. These tests read `DailyMotivation.ps1` and assert on its text structure, matching the existing pattern in `UIDisposal.Tests.ps1` (AG6-004).

### 3.1 Test Design

**Test A — Finally block must NOT reset `openExplorer`**
- Locate the `Show-PopupWindow` function body.
- Assert that no line in its `finally` block assigns to `$script:openExplorer`.

**Test B — Exit handler must set `openExplorer = $false`**
- Assert `Show-PopupWindow` contains an Exit button handler that assigns `$script:openExplorer = $false`.

**Test C — Snooze handler must set `openExplorer = $false`**
- Assert `Show-PopupWindow` contains a Snooze button handler that assigns `$script:openExplorer = $false`.

**Test D — Dismiss handler must set `openExplorer = $false`**
- Assert `Show-PopupWindow` contains a Dismiss button handler that assigns `$script:openExplorer = $false`.

**Test E — PathMissing Dismiss handler must set `openExplorer = $false`**
- Assert `Show-PopupWindow` contains a PathMissing Dismiss handler that assigns `$script:openExplorer = $false`.

**Test F — Open Folder handler must set `openExplorer = $true`**
- Assert `Show-PopupWindow` contains an Open Folder button handler that assigns `$script:openExplorer = $true`.

### 3.2 Test File Placement

The daily brief (`daily-brief-2026-08-09.md`) recommends:
- `FolderScheduling.Tests.ps1` — 5 It blocks (button handlers + finally block)
- `InputValidation.Tests.ps1` — 2 It blocks (structural guard)

**Brief deviation (requires acknowledgment):** The daily brief specifies 5 It blocks in `FolderScheduling.Tests.ps1` and 2 in `InputValidation.Tests.ps1` (7 total across 2 files). This plan consolidates all 6 It blocks (Tests A–F) into `UIDisposal.Tests.ps1`. The count difference (7 vs. 6) must be reconciled before implementation: either the brief's split contains a duplicate that maps to the same assertion as one of Tests A–F, or a seventh test block is missing from this plan and must be authored. Implementers must resolve this discrepancy against the brief before executing this plan.

**Recommendation:** Place all 6 tests in `UIDisposal.Tests.ps1` instead. That file already contains the AG6-004 source-code pattern tests for `Show-PopupWindow` and `Show-MainWindow`. Adding BUG-1 guards there keeps all source-structure regression tests for the popup lifecycle in one file. `FolderScheduling.Tests.ps1` tests `Invoke-FolderScheduling` runtime behavior; `InputValidation.Tests.ps1` tests input validation. Neither is a natural home for `Show-PopupWindow` structural assertions.

If the brief's placement is a hard requirement, the same 6 tests can be appended to `FolderScheduling.Tests.ps1` as a new `Describe` block — the tests will still pass, they just won't be colocated with the other popup-structure tests.

## 4. Execution Steps

1. **Run baseline** on Windows 10/11 PowerShell 7:
   ```powershell
   .\Invoke-Tests.ps1
   ```
   Expected: `Passed=359 Failed=0 Skipped=7`

2. **Apply code fix:** Delete line 2805 in `DailyMotivation.ps1`.

3. **Add regression tests:** Append the 6 It blocks described in §3 to `UIDisposal.Tests.ps1` (or `FolderScheduling.Tests.ps1` if following the brief verbatim).

4. **Run tests:**
   ```powershell
   .\Invoke-Tests.ps1
   ```
   Expected: ≥365 passed, 0 failed.

5. **Manual validation on Windows:**
   - Schedule a reminder, let the Popup fire.
   - Click **Dismiss** → confirm Explorer does NOT open and the Outcome Log records `Dismissed`.
   - Click **Snooze** → confirm Explorer does NOT open and the Outcome Log records `Snoozed`.
   - Click **Exit** → confirm Explorer does NOT open.
   - Click **Open Folder** → confirm Explorer opens the correct folder and the Outcome Log records `Opened`.

5a. **Attach Windows validation evidence to issue #183:** Run `.\Invoke-Tests.ps1` on a Windows 10/11 PowerShell 7 machine and post the full terminal output showing ≥365 passed, 0 failed as a comment on issue #183. Issue must not be closed before this evidence is posted (GitHub Issue Closure Gate — CLAUDE.md mandate).

6. **Commit:**
   ```
   fix(popup): remove $script:openExplorer reset from Show-PopupWindow finally block (BUG-1)
   test(UIDisposal): add BUG-1 regression guards for openExplorer state preservation
   ```

## 5. Risks

| Risk | Mitigation |
|------|------------|
| Removing the reset re-introduces state leakage between popup instances | All button handlers set `openExplorer` explicitly; the other state vars (`pathMissing`, `newExplorerPath`, `remaining`, `snoozeCount`, `windowClosed`) are still reset in finally. |
| Test placement mismatch with brief | Tests are identical regardless of file; only the `Describe` block location changes. |
| Tests pass on Linux but behavior differs on Windows | The fix is source-structure only and does not invoke any Windows API. However, per CLAUDE.md MANDATE 1, Linux CI passing is not sufficient for closure. Windows 10/11 Pester output must be collected and attached to issue #183 before the issue may be closed. |
| BUG-2 plan also claims line 2805 deletion | Coordinate with BUG-2 owner before committing. If BUG-2 is applied first, line numbers in the `finally` block may shift. Re-verify the target line number in the updated file. |

## 6. Out of Scope

- BUG-2 (`$window.Dispose()` crash) — separate fix, separate commit. **Note:** The `$window.Dispose()` call at line 2798 (same `finally` block) is a CLAUDE.md MANDATE 3 violation tracked as BUG-2. The BUG-1 commit must leave line 2798 untouched — do not remove it, do not replace it with `.Close()`. That change belongs exclusively in the BUG-2 commit to maintain a clean, attributable fix history.
- BUG-3 ("Invalid Folder" dialog title) — separate fix
- BUG-4 (stale PopupConfig) — separate investigation
