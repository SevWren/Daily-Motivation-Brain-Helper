# Issue #183 — BUG-1 & BUG-4 Remaining Work

**Issue:** [#183](https://github.com/SevWren/Daily-Motivation-Brain-Helper/issues/183)
**Status:** Open — BUG-1 and BUG-4 unresolved as of 2026-08-20
**Script:** `DailyMotivation.ps1` (single-file monolith, 3062 lines)
**Platform:** Windows 10/11 PowerShell 7 (primary); Linux PowerShell 7 (platform-abstraction tests only)
**Source documents:** `docs/planning/daily-brief-2026-08-09-bug1-openexplorer-fix.md`, `docs/planning/daily-brief-2026-08-09-bug4-setpopupconfig-investigation.md`, `docs/planning/daily-brief-2026-08-09.md`

---

## Context: What Has Already Been Fixed in This Issue

The following bugs from issue #183 were resolved in commit `e0e0da6` (2026-08-18) and are **out of scope** for this document:

| Bug | Fix | Validation |
|-----|-----|------------|
| BUG-2: `$window.Dispose()` on `System.Windows.Window` | Both `Show-MainWindow:2137` and `Show-PopupWindow:2799` now call `$window.Close()` | Live Windows 10/11 — confirmed in issue #183 comment 2026-08-18 |
| BUG-3: `Do-Schedule` error dialog titled "Invalid Folder" for OS Task registration failures | `Do-Schedule:1854` now shows title `"Schedule Failed"` | Live Windows 10/11 — confirmed in issue #183 comment 2026-08-18 |
| BUG-3 (root): `LogonType S4U` failed with "Access is denied" for non-elevated users | `New-MotivationTask` principal changed to `LogonType Interactive` | Live Windows 10/11 — `Interactive` confirmed successful in issue #183 comment 2026-08-18 |

### Line Number Shift Note

Commit `e0e0da6` (2026-08-18, BUG-2 and BUG-3 fixes) made net additions to `DailyMotivation.ps1` that shifted line numbers throughout the file. All line numbers in this document reflect the **current post-`e0e0da6` state of `DailyMotivation.ps1`** (verified by direct `Read` of the file). The planning documents written on 2026-08-09 and 2026-08-11 cite line numbers that are off by at least +1 in the sections affected by `e0e0da6`. Do not use the planning doc line numbers directly — re-verify against the current file before applying any change.

---

## BUG-1 — `$script:openExplorer` Unconditionally Reset in `Show-PopupWindow` Finally Block

### Problem

`DailyMotivation.ps1:2806` sets `$script:openExplorer = $true` inside the `finally` block of `Show-PopupWindow`. This runs after every button click handler completes, overwriting whatever value the handler set. The post-close check at line 2832 (`if ($script:openExplorer -and $effectivePath)`) therefore always evaluates to `$true`, causing Explorer to be opened regardless of the user's action. The Outcome Log entry at lines 2844-2847 also always resolves to `Opened` because `$script:openExplorer` is always `$true` at that point.

### Current State of the Finally Block

```
DailyMotivation.ps1:2795  finally {
DailyMotivation.ps1:2796      # Close WPF window to release resources
DailyMotivation.ps1:2797      if ($window) {
DailyMotivation.ps1:2798          try {
DailyMotivation.ps1:2799              $window.Close()
DailyMotivation.ps1:2800          }
DailyMotivation.ps1:2801          catch {}
DailyMotivation.ps1:2802      }
DailyMotivation.ps1:2803
DailyMotivation.ps1:2804      # Reset state variables to prevent leakage between popup instances
DailyMotivation.ps1:2805      $script:pathMissing = $false
DailyMotivation.ps1:2806      $script:openExplorer = $true        ← REMOVE THIS LINE
DailyMotivation.ps1:2807      $script:newExplorerPath = ""
DailyMotivation.ps1:2808      $script:remaining = 20
DailyMotivation.ps1:2809      $script:snoozeCount = 0
DailyMotivation.ps1:2810      $script:windowClosed = $false
```

### Button Handlers Already Set `$script:openExplorer` Correctly

All six handlers set `$script:openExplorer` before calling `$window.Close()`. Removing line 2806 allows these values to survive to the post-close check at line 2832.

| Handler | Location | Value Set |
|---------|----------|-----------|
| Exit (`$exitItem.Add_Click`) | `DailyMotivation.ps1:2644` | `$false` |
| Snooze (`$snoozeBtn.Add_Click`) | `DailyMotivation.ps1:2655` | `$false` |
| Dismiss (`$dismissBtn.Add_Click`) | `DailyMotivation.ps1:2688` | `$false` |
| PathMissing Dismiss (`$pathDismissBtn.Add_Click`) | `DailyMotivation.ps1:2723` | `$false` |
| Open Folder (`$letsGoBtn.Add_Click`) | `DailyMotivation.ps1:2711` | `$true` |
| Re-pick folder (`$rePickBtn.Add_Click`) | `DailyMotivation.ps1:2747` | `$true` |

`$script:openExplorer` is correctly initialised to `$true` at `DailyMotivation.ps1:2529` before the window is shown. The `finally`-block reset at line 2806 is the sole cause of the bug.

The post-close logic that reads `$script:openExplorer`:

```
DailyMotivation.ps1:2832  if ($script:openExplorer -and $effectivePath) {
DailyMotivation.ps1:2844  $outcome = if ($script:pathMissing -and -not $script:openExplorer) { "PathMissing" }
DailyMotivation.ps1:2845             elseif ($script:openExplorer) { "Opened" }
DailyMotivation.ps1:2846             elseif ($script:snoozeCount -gt 0) { "Snoozed" }
DailyMotivation.ps1:2847             else { "Dismissed" }
```

### Required Code Change

**One line deletion in `DailyMotivation.ps1`:**

Remove line 2806: `$script:openExplorer = $true`

The surrounding state resets at lines 2805, 2807–2810 (`$script:pathMissing`, `$script:newExplorerPath`, `$script:remaining`, `$script:snoozeCount`, `$script:windowClosed`) are correct and must remain untouched.

### Required Test Changes

Add a new `Describe` block to `Tests/Unit/UIDisposal.Tests.ps1`. This file already contains the source-structure regression tests for `Show-PopupWindow` and `Show-MainWindow` (the BUG-2 guards). BUG-1 structural guards belong in the same file.

Six `It` blocks are required:

**Test A** — Finally block must NOT assign `$script:openExplorer`:
Locate the `Show-PopupWindow` function body. Extract its `finally` block. Assert that no assignment to `$script:openExplorer` exists in that block.

**Test B** — Exit handler must set `$script:openExplorer = $false`:
Assert that `Show-PopupWindow` contains `$exitItem.Add_Click` with `$script:openExplorer = $false`.

**Test C** — Snooze handler must set `$script:openExplorer = $false`:
Assert that `Show-PopupWindow` contains `$snoozeBtn.Add_Click` with `$script:openExplorer = $false`.

**Test D** — Dismiss handler must set `$script:openExplorer = $false`:
Assert that `Show-PopupWindow` contains `$dismissBtn.Add_Click` with `$script:openExplorer = $false`.

**Test E** — PathMissing Dismiss handler must set `$script:openExplorer = $false`:
Assert that `Show-PopupWindow` contains `$pathDismissBtn.Add_Click` with `$script:openExplorer = $false`.

**Test F** — Open Folder handler must set `$script:openExplorer = $true`:
Assert that `Show-PopupWindow` contains `$letsGoBtn.Add_Click` with `$script:openExplorer = $true`.

All six tests follow the file-read pattern already used in `UIDisposal.Tests.ps1`: `Get-Content` the script, locate the function boundary with `IndexOf`, extract the relevant substring, then use `-match` or `[regex]::Match` to assert structure.

**Note on planning doc discrepancy:** `daily-brief-2026-08-09-bug1-openexplorer-fix.md` §3.2 specifies splitting tests across `FolderScheduling.Tests.ps1` and `InputValidation.Tests.ps1`. The plan's own recommendation in the same section overrides this: consolidate all six into `UIDisposal.Tests.ps1` alongside the existing BUG-2 popup-structure guards. That recommendation is adopted here.

### Execution Steps

1. **Establish baseline on Windows 10/11 PowerShell 7:**
   ```powershell
   .\Invoke-Tests.ps1
   ```
   Record the actual `Passed=N Failed=0` count. The count from the planning doc (`359 passed`) predates the BUG-2 and BUG-3 fixes, which added tests; that number is no longer valid as the baseline.

2. **Apply code fix:** Delete `DailyMotivation.ps1:2806`.

3. **Add regression tests:** Append the six `It` blocks (Tests A–F) as a new `Describe 'BUG-1: Show-PopupWindow openExplorer state preservation'` block to `Tests/Unit/UIDisposal.Tests.ps1`.

4. **Run tests on Windows 10/11:**
   ```powershell
   .\Invoke-Tests.ps1
   ```
   Expected: baseline + 6 passed, 0 failed.

5. **Manual validation on Windows 10/11:**
   - Schedule a MotivationTask. Let the Popup fire.
   - Click **Open Folder** → Explorer opens the correct FolderPath. Outcome Log records `Opened`.
   - Schedule a MotivationTask. Let the Popup fire.
   - Click **Dismiss** → Explorer does NOT open. Outcome Log records `Dismissed`.
   - Schedule a MotivationTask. Let the Popup fire.
   - Click **Snooze** → Explorer does NOT open. Outcome Log records `Snoozed`.
   - Schedule a MotivationTask. Let the Popup fire.
   - Click the system-tray **Exit** item → Explorer does NOT open.
   - Verify the Outcome Log (`popup_log.txt`) contains varied Outcomes across the four sessions — not all `Opened`.

6. **Attach Windows evidence to issue #183:**
   Post the full `.\Invoke-Tests.ps1` terminal output from step 4 as a comment on issue #183 before the issue is closed. This is required by the GitHub Issue Closure Gate (CLAUDE.md).

7. **Commit message:**
   ```
   fix(popup): remove $script:openExplorer reset from Show-PopupWindow finally block (BUG-1, #183)
   test(UIDisposal): add BUG-1 regression guards for openExplorer state preservation
   ```

### Risks

| Risk | Mitigation |
|------|------------|
| State leakage between popup instances after removing the reset | All six handlers set `$script:openExplorer` before `$window.Close()`; the other state variables (`$script:pathMissing`, `$script:newExplorerPath`, `$script:remaining`, `$script:snoozeCount`, `$script:windowClosed`) are still reset in the finally block at lines 2805, 2807–2810. |
| Tests pass on Linux but behaviour differs on Windows | These are source-structure tests (file read + regex). They do not invoke Windows APIs and will produce identical results on Linux. However, per CLAUDE.md MANDATE 1, Windows Pester output is still required before issue closure for the manual validation steps. |

---

## BUG-4 — PopupConfig Handoff Not Completed After Schedule

### Problem

When the user clicks Schedule in the main window, `New-MotivationTask` succeeds (the OS Task is registered in Windows Task Scheduler and the MotivationTask is saved to `tasks.json`) but the PopupConfig (`popup_config.json`) is not updated. When the OS Task fires, `Show-PopupWindow` reads the stale PopupConfig and displays the wrong FolderPath. The root cause is an unhandled exception from `Set-PopupConfig` that propagates silently through the WPF dispatcher — confirmed by `popup_config.json` retaining a stale `task_id` after a successful Schedule in issue #183 comment 2026-08-07.

### Call Chain

```
scheduleBtn.Add_Click (DailyMotivation.ps1:1964)   ← no try/catch
  └─ Do-Schedule (DailyMotivation.ps1:1827)         ← no try/catch around Invoke-FolderScheduling call
       └─ Invoke-FolderScheduling (DailyMotivation.ps1:1146)
            ├─ New-MotivationTask (DailyMotivation.ps1:608) — SUCCEEDS, OS Task registered
            └─ Set-PopupConfig (DailyMotivation.ps1:1247)  ← throws (exact reason unconfirmed)
                 └─ exception propagates up the chain → WPF dispatcher swallows silently
                 └─ popup_config.json unchanged → Popup reads stale PopupConfig at TriggerTime
```

There is a second call path with the same vulnerability: the Enter key handler at `DailyMotivation.ps1:2054` (`$window.Add_KeyDown`) calls `Do-Schedule` at line 2059 with no try/catch. The same silent-swallow risk exists in that path.

### What Has Been Ruled Out

The following root causes were tested directly on Windows 10/11 (issue #183 comments 2026-08-07 through 2026-08-08):

| Hypothesis | Result |
|------------|--------|
| `Global\DailyMotivationPopupConfigLock` mutex throws `UnauthorizedAccessException` from elevated context | **Ruled out** — mutex acquired successfully from elevated PowerShell (`WaitOne` returned `True`) |
| APPDATA path mismatch between elevated and non-elevated processes | **Ruled out** — `$env:APPDATA` and `$env:USERNAME` identical in both contexts for user `mmuel` |
| `Set-PopupConfig` function broken when called from elevated context | **Ruled out** — direct invocation from elevated PowerShell with dot-sourced script succeeded; `popup_config.json` was updated correctly |

The exact throw site within the UI call chain has **not been confirmed** on Windows. Diagnostic instrumentation is required before a code fix can be written for the root cause.

### `Set-PopupConfig` Throw Points (lines 375–421)

`Set-PopupConfig` has two operations after the Mutex acquire that can throw with `-ErrorAction Stop`:

- `DailyMotivation.ps1:408` — `Set-Content -Path $tempPath -Encoding UTF8 -ErrorAction Stop`
- `DailyMotivation.ps1:409` — `Move-Item -Path $tempPath -Destination $script:PopupCfgPath -Force -ErrorAction Stop`

The `catch` block at line 411 deletes the temp file and **re-throws** (`throw` at line 413). This re-throw exits `Set-PopupConfig` and propagates to `Invoke-FolderScheduling:1247`, which has no try/catch, then to `Do-Schedule:1845`, which has no try/catch around that call, then to `scheduleBtn.Add_Click:1964`, which has no try/catch, then to the WPF dispatcher, which swallows it.

### Phase 1 — Required: Diagnostic Instrumentation (do NOT commit)

Apply the following temporary trace logging, rebuild the App (`.\build.ps1`), run elevated on Windows 10/11, click Schedule, and read `%TEMP%\DailyMotivation_bug4_diag.log`.

**1a. Inside `Set-PopupConfig` — after the param block, before `$tempPath` assignment (line 385):**

```powershell
$diagLog = Join-Path $script:TempDir "DailyMotivation_bug4_diag.log"
"[$(Get-Date -Format 'HH:mm:ss.fff')] Set-PopupConfig START: TaskId=$TaskId Path=$ExplorerPath" | Out-File -Append -FilePath $diagLog -Encoding UTF8
```

After the `Move-Item` line (408–409), before the `catch` block:

```powershell
"[$(Get-Date -Format 'HH:mm:ss.fff')] Set-PopupConfig SUCCESS" | Out-File -Append -FilePath $diagLog -Encoding UTF8
```

At the start of the `catch` block (line 411):

```powershell
"[$(Get-Date -Format 'HH:mm:ss.fff')] Set-PopupConfig THROW: $($_.Exception.GetType().FullName): $($_.Exception.Message)" | Out-File -Append -FilePath $diagLog -Encoding UTF8
```

**1b. In `Invoke-FolderScheduling` — surrounding the `Set-PopupConfig` call at line 1247:**

```powershell
$diagLog = Join-Path $script:TempDir "DailyMotivation_bug4_diag.log"
"[$(Get-Date -Format 'HH:mm:ss.fff')] Invoke-FolderScheduling: about to call Set-PopupConfig" | Out-File -Append -FilePath $diagLog -Encoding UTF8
Set-PopupConfig @popupConfigParams
"[$(Get-Date -Format 'HH:mm:ss.fff')] Invoke-FolderScheduling: Set-PopupConfig returned" | Out-File -Append -FilePath $diagLog -Encoding UTF8
```

**1c. In `Do-Schedule` — surrounding the `Invoke-FolderScheduling` call at line 1845:**

Before line 1845:
```powershell
$diagLog = Join-Path $script:TempDir "DailyMotivation_bug4_diag.log"
"[$(Get-Date -Format 'HH:mm:ss.fff')] Do-Schedule: calling Invoke-FolderScheduling" | Out-File -Append -FilePath $diagLog -Encoding UTF8
```

After line 1845 (before the `if (-not $result.Success ...)` check):
```powershell
"[$(Get-Date -Format 'HH:mm:ss.fff')] Do-Schedule: Invoke-FolderScheduling returned Success=$($result.Success)" | Out-File -Append -FilePath $diagLog -Encoding UTF8
```

**1d. In `scheduleBtn.Add_Click` — replace lines 1964–1966 temporarily:**

```powershell
$scheduleBtn.Add_Click({
    $diagLog = Join-Path $script:TempDir "DailyMotivation_bug4_diag.log"
    "[$(Get-Date -Format 'HH:mm:ss.fff')] scheduleBtn: clicked, selectedPath=$($script:selectedPath)" | Out-File -Append -FilePath $diagLog -Encoding UTF8
    if ($script:selectedPath) {
        try {
            Do-Schedule -FolderPath $script:selectedPath
            "[$(Get-Date -Format 'HH:mm:ss.fff')] scheduleBtn: Do-Schedule completed without throw" | Out-File -Append -FilePath $diagLog -Encoding UTF8
        } catch {
            "[$(Get-Date -Format 'HH:mm:ss.fff')] scheduleBtn: Do-Schedule THREW: $($_.Exception.GetType().FullName): $($_.Exception.Message)" | Out-File -Append -FilePath $diagLog -Encoding UTF8
            throw
        }
    }
})
```

**Reading the log:** The last line written before the log goes silent identifies the throw site. If `Set-PopupConfig SUCCESS` is the last entry, the PopupConfig write succeeded and the bug is elsewhere — see Phase 2 alternative branch below.

### Phase 2 — Root-Cause Fix (depends on Phase 1 output)

The correct fix depends on what the diagnostic log reveals.

**If the log ends at `Set-PopupConfig THROW` with a file I/O error (e.g., `Move-Item` fails due to destination locked):**

Replace the `Move-Item` at line 409 with a retry loop:

```powershell
$maxRetries = 3
$retryDelay = 200
for ($i = 0; $i -lt $maxRetries; $i++) {
    try {
        Copy-Item -Path $tempPath -Destination $script:PopupCfgPath -Force -ErrorAction Stop
        Remove-Item -Path $tempPath -ErrorAction SilentlyContinue
        break
    } catch {
        if ($i -lt $maxRetries - 1) { Start-Sleep -Milliseconds $retryDelay } else { throw }
    }
}
```

**If the log ends at `Set-PopupConfig THROW` with a Mutex timeout (`WaitOne` returned `$false` after 2000ms):**

Increase the `WaitOne` timeout at `DailyMotivation.ps1:390` from `2000` to `10000` and add a log entry identifying the contending process before re-throwing.

**If the log ends at `Set-PopupConfig THROW` with an encoding or serialization error:**

Sanitize `$FolderName` and message fields before `ConvertTo-Json` to strip characters that cause `Set-Content -Encoding UTF8` to fail.

**If `Set-PopupConfig SUCCESS` is the last log entry (Handoff was written):**

The PopupConfig write succeeded. The PopupConfig is being overwritten after Schedule time or `Get-PopupConfig` in popup mode reads from a different `$script:PopupCfgPath`. Verify that `Initialize-AppData` resolves `$script:PopupCfgPath` identically in main mode and popup mode. Check whether any other code path between Schedule time and TriggerTime writes to `popup_config.json`.

### Phase 3 — Required Regardless of Phase 2 Outcome: Defensive Error Handling

Add a try/catch to `scheduleBtn.Add_Click` so that any exception escaping `Do-Schedule` surfaces as a user-visible "Schedule Failed" dialog instead of being silently swallowed by the WPF dispatcher.

**Replace `DailyMotivation.ps1:1964–1966`:**

```powershell
# Current (lines 1964–1966):
$scheduleBtn.Add_Click({
        if ($script:selectedPath) { Do-Schedule -FolderPath $script:selectedPath }
    })
```

```powershell
# Required:
$scheduleBtn.Add_Click({
        if ($script:selectedPath) {
            try {
                Do-Schedule -FolderPath $script:selectedPath
            } catch {
                Show-ErrorDialog -Title "Schedule Failed" -Message "Could not complete scheduling (PopupConfig write failed): $($_.Exception.Message)"
            }
        }
    })
```

The title `"Schedule Failed"` and message text `"PopupConfig write failed"` satisfy CLAUDE.md MANDATE 6 (name the failing operation). If Phase 1 reveals the throw originates from a component other than `Set-PopupConfig`, update the message text to name that operation specifically.

The Enter key handler at `DailyMotivation.ps1:2054–2062` also calls `Do-Schedule` at line 2059 with no try/catch. Apply the same try/catch pattern there to close the same silent-swallow gap:

```powershell
# Affected block (lines 2057–2062):
([System.Windows.Input.Key]::Return) {
    if ($scheduleBtn.IsEnabled -and $script:selectedPath) {
        Do-Schedule -FolderPath $script:selectedPath   ← wrap in try/catch
        $ke.Handled = $true
    }
}
```

**Note on BUG-3 interaction:** BUG-3 added an inner catch to `Do-Schedule` at line 1854 that handles `Register-ScheduledTask` failures. That inner catch does not re-throw. The outer catch added in Phase 3 is a backstop for exceptions that escape `Do-Schedule`'s inner catch — specifically `Set-PopupConfig` throws and any other post-registration failures. The two dialogs will not both fire for the same error.

### Phase 4 — Required Tests

Add to `Tests/Unit/FolderScheduling.Tests.ps1`:

**Test 4a — `scheduleBtn.Add_Click` handler has try/catch (structural):**

Read `DailyMotivation.ps1`, locate the `scheduleBtn.Add_Click` block, assert it contains `try {` and `catch {`.

**Test 4b — `Invoke-FolderScheduling` propagates `Set-PopupConfig` failure:**

Mock `Set-PopupConfig` to throw `"Simulated PopupConfig write failure"`. Assert that calling `Invoke-FolderScheduling` with a valid FolderPath throws — i.e., the exception is not silently absorbed and `Success = $true` is not returned.

**Test 4c — `Set-PopupConfig` retry (if Phase 2 file-lock fix is applied):**

Mock `Move-Item` to throw on the first call and succeed on the second. Assert that `Set-PopupConfig` completes without throwing and `popup_config.json` is written.

### Phase 5 — Cleanup and Validation

1. Remove all Phase 1 diagnostic `Out-File` logging from `DailyMotivation.ps1`.
2. Rebuild: `.\build.ps1`
3. Run full test suite on Windows 10/11:
   ```powershell
   .\Invoke-Tests.ps1 -CI
   ```
4. Live Windows 10/11 validation:
   - Run non-elevated. Click Schedule Reminder.
   - Confirm no error dialog appears.
   - Confirm `popup_config.json` (`$env:APPDATA\DailyMotivationBrainHelper\popup_config.json`) contains the `task_id` and `explorer_path` of the task just created.
   - At TriggerTime, confirm the Popup displays the correct FolderName and opens the correct FolderPath.
5. **GitHub Issue Closure Gate (CLAUDE.md):** Post the full `.\Invoke-Tests.ps1 -CI` terminal output from step 3 as a comment on issue #183. Issue #183 must not be closed until this evidence is attached.

### Out-of-Scope Decisions (from planning doc — confirmed still valid)

- Do NOT change `Set-PopupConfig`'s Mutex name or timeout without fresh diagnostic evidence; the prior mutex hypothesis was ruled out.
- Do NOT refactor `Invoke-FolderScheduling`'s return contract; the function correctly returns for validation failures and the problem is only the unhandled exception from `Set-PopupConfig`.
- Do NOT add rollback of `New-MotivationTask` when `Set-PopupConfig` fails; the MotivationTask + `tasks.json` write atomicity is correct. Only the PopupConfig Handoff is missing.

---

## Issue #183 Acceptance Criteria — Remaining Items

The following acceptance criteria from issue #183 are not yet met:

- [ ] `$script:openExplorer = $true` does not appear in the `Show-PopupWindow` finally block (`DailyMotivation.ps1:2806`)
- [ ] `Tests/Unit/UIDisposal.Tests.ps1` — 6 new BUG-1 regression guards added and passing
- [ ] Manual Windows validation: Popup Dismiss → Explorer does NOT open, Outcome Log records `Dismissed`
- [ ] Manual Windows validation: Popup Snooze → Explorer does NOT open, Outcome Log records `Snoozed`
- [ ] Manual Windows validation: Popup Exit → Explorer does NOT open
- [ ] Manual Windows validation: Popup Open Folder → correct FolderPath opens in Explorer, Outcome Log records `Opened`
- [ ] Manual Windows validation: Outcome Log shows varied Outcomes across sessions (not all `Opened`)
- [ ] BUG-4 Phase 1 diagnostic run on Windows and root cause confirmed
- [ ] BUG-4 root-cause fix applied (specific fix depends on Phase 1 output)
- [ ] `scheduleBtn.Add_Click` and Enter key handler (`$window.Add_KeyDown`) wrapped in try/catch (`DailyMotivation.ps1:1964` and `2059`)
- [ ] `Tests/Unit/FolderScheduling.Tests.ps1` — BUG-4 structural and propagation tests added and passing
- [ ] Manual Windows validation: Schedule Reminder succeeds, `popup_config.json` updated with correct `task_id` and `explorer_path`
- [ ] Windows 10/11 `.\Invoke-Tests.ps1` terminal output (0 failures) attached to issue #183 as a comment before closure

---

## CLAUDE.md Mandates Applicable to This Work

- **MANDATE 1:** No bug in this issue may be declared resolved without live Windows 10/11 validation. Linux CI passing is necessary but not sufficient.
- **MANDATE 3:** `$window.Close()` is already in place (BUG-2 fixed). Do not re-introduce `$window.Dispose()`.
- **MANDATE 6:** All error dialogs must name the failing operation. "Schedule Failed" + "PopupConfig write failed" satisfies this for BUG-4's Phase 3 catch.
- **GitHub Issue Closure Gate:** Issue #183 must not be closed without a Windows 10/11 `Invoke-Pester` / `Invoke-Tests.ps1` output showing 0 failures attached as an issue comment.

---

_Last updated: 2026-08-20_
