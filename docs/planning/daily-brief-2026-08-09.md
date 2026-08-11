# Daily Work Brief — 2026-08-09

**Project:** Daily Motivation Brain Helper
**Branch:** `project-restart-pwsh7` (now also `main` — overwritten 2026-08-08)
**Issue:** [#183 — Popup always logs Opened regardless of button clicked + MissingMethodException on close](https://github.com/SevWren/Daily-Motivation-Brain-Helper/issues/183)
**Date prepared:** 2026-08-08
**Prepared by:** Claude (automated brief)

---

## How to Start and Work Through This Brief

> Read this section first. Everything else in this document is reference material — come back to the sections below as you need them.

### The short version of what's broken

Your app has four bugs, all confirmed. Two are quick fixes (a wrong line of code each). One is a misleading error message. The fourth needs a short investigation to find exactly where it breaks. None of them require large rewrites — the hardest part is knowing where to look, and this brief tells you exactly that.

### Before you open any code

1. **Make sure you're on a Windows 10/11 machine.** Your tests and the app itself only work correctly on Windows. Running fixes on Linux will appear to work but won't actually confirm anything. This is a hard rule documented in the project.

2. **Open a PowerShell 7 (`pwsh`) terminal** in the project root folder (`Daily-Motivation-Brain-Helper`). Not Windows PowerShell — PowerShell 7.

3. **Run the test suite once to get a clean baseline** before touching anything:
   ```powershell
   .\Invoke-Tests.ps1
   ```
   You should see: `Passed=359  Failed=0  Skipped=7`. -  *Note: Confirmed & Verified as of 8/11/2026*

4. **Open `DailyMotivation.ps1`** in your editor. This is the single file where all four bugs live.

### The order to fix things — and why this order matters

Work through the bugs in this exact order. Each step is designed so you can confirm it works before moving to the next one.

---

**Step 1 — Fix the crash on close (BUG-2) — about 10 minutes**

This is the easiest fix and the one most likely to affect your confidence in the tool. Every time you close the app right now, a scary error dialog pops up. That stops today.

- Go to line **2137** in `DailyMotivation.ps1`. Change `$window.Dispose()` to `$window.Close()`.
- Go to line **2795**. Change the comment from *"Dispose WPF window"* to *"Close WPF window"*.
- Go to line **2798**. Change `$window.Dispose()` to `$window.Close()`.

That's three small edits. Before you save, also open `Tests/Unit/UIDisposal.Tests.ps1` and replace the `AG6-004` Describe block — it currently checks that `Dispose` is present, which is backwards. The replacement tests are written out in full in the **BUG-2** section below.

Run the tests. The new tests should pass. The error dialog on close should be gone.

---

**Step 2 — Fix the wrong history logging (BUG-1) — about 10 minutes**

Right now, no matter which button you click in the popup (Dismiss, Snooze, Exit, or Open Folder), the app records "Opened" in its history. This is caused by a single line resetting a variable after every button click.

- Go to line **2805** in `DailyMotivation.ps1`. Delete the line `$script:openExplorer = $true`.

That's it — one line removed. Add the new tests described in the **BUG-1** section below to `FolderScheduling.Tests.ps1` and `InputValidation.Tests.ps1`, then run the test suite again.

After this fix, clicking Dismiss should not open Explorer, and clicking Open Folder should. You can verify this with a live popup if you schedule a quick test task.

---

**Step 3 — Fix the misleading error message (BUG-3) — about 15 minutes**

When you try to schedule a reminder without running the app as administrator, you get an error dialog that says "Invalid Folder." That's wrong — the folder is fine, it's the Windows Task Scheduler registration that failed. The title needs to say "Schedule Failed" instead.

Find the catch block in `DailyMotivation.ps1` that handles the `Register-ScheduledTask` failure and shows this dialog. Change the title from "Invalid Folder" to "Schedule Failed" and update the message to say that the OS task registration failed — not the folder. The exact location is TBD (use the `/diagnosing-bugs` skill or search for "Invalid Folder" in the file). Full detail is in the **BUG-3** section below.

---

**Step 4 — Investigate why the app schedules the wrong folder (BUG-4) — 30–60 minutes, may carry over**

This one is trickier. When you click "Schedule Reminder," the task gets created in Windows Task Scheduler correctly — but the app doesn't update the config file that tells the popup which folder to open. So the popup fires but opens an old folder.

The investigation so far has ruled out nine possible causes (see Appendix). What's left: something in the button → schedule → config-write chain exits early or silently crashes before the config write happens. You need to add a few temporary log lines to find exactly where it stops.

The exact `Write-Host` lines to add as a diagnostic are in the **BUG-4** section below. Add them, run the app (elevated), click Schedule Reminder, and read the output. **Don't commit these log lines** — they're just to find the problem.

---

**Step 5 — Run the full test suite one final time on Windows**

```powershell
.\Invoke-Tests.ps1 -CI -Coverage $true
```

The pass count should be higher than 359 (the new tests you added in Steps 1 and 2 will add to it). Zero failures required.

**This Windows output is your proof.** Copy it and paste it as a comment on GitHub issue #183. The project rules require this before the issue can be closed — a Linux CI run alone is not enough.

---

**Step 6 — Commit and push**

Each fix can be its own commit. Commit messages to use are listed in the **Tomorrow's Work Plan** section below. Push to `project-restart-pwsh7` (which is also now `main`).

---

### If you get stuck

- **On BUG-3 (finding the catch block):** Search `DailyMotivation.ps1` for the text `Invalid Folder` — it will be in a `Show-ErrorDialog` or similar call inside a catch block near `Register-ScheduledTask`.
- **On BUG-4 (trace logging not showing anything):** The problem may be that the WPF button handler is swallowing exceptions silently. Wrap the entire `Do-Schedule` call in a try/catch that writes to a log file so you can see what's happening.
- **On any test failure you don't understand:** Use the `/diagnosing-bugs` skill — it's designed for exactly this kind of tight feedback loop.
- **If BUG-4 isn't resolved by end of session:** Use the `/handoff` skill to write a compact session summary so a fresh agent can pick it up without losing context.

### Skills available in this project

These are pre-built helper instructions for the AI assistant you work with. You can invoke them by typing the skill name (e.g. `/tdd`). Specific recommendations for each step are in the **Skill Recommendations** section below.

| Skill | What it does |
|-------|-------------|
| `/tdd` | Walks through a test-first fix cycle (write failing test → fix code → confirm pass) |
| `/diagnosing-bugs` | Structured approach to finding root causes you can't see yet |
| `/implement` | Apply code changes based on a spec or issue description |
| `/code-review` | Review your changes against the original issue spec before pushing |
| `/handoff` | Write a session summary so work can continue in a new session |

---

## Executive Summary

Issue #183 documents four confirmed bugs in `DailyMotivation.ps1`. All four are present in the current codebase (`project-restart-pwsh7` branch, now `main`). No code fixes have been committed yet. The diagnostic thread in the issue is complete for BUG-1 and BUG-2; BUG-3 and BUG-4 have partial root causes confirmed. Tomorrow's primary objective is to implement and test BUG-1 and BUG-2 fixes, resolve the inverse regression test in `UIDisposal.Tests.ps1`, and continue BUG-4 trace-logging investigation.

A live observation opportunity exists: scheduled task `afce0852e0764809` (folder: `Ai Test Aug 12`) is set to fire at **14:00 today (2026-08-08)**. If you are at your Windows machine at that time, observe whether the popup appears, which button you click, and what `popup_log.txt` records. This will confirm or deny BUG-1 in a real task-fire scenario.

---

## Current Bug Inventory

### BUG-1 — `openExplorer` unconditionally reset in `Show-PopupWindow` finally block
**Severity:** High (UX — all popup sessions log `Opened` regardless of button)
**File:** `DailyMotivation.ps1:2805`
**Status:** Root cause fully confirmed. Fix is one line removal.

```
$script:openExplorer = $true   ← line 2805, inside finally block — REMOVE THIS LINE
```

**What it breaks:** Every call to `Show-PopupWindow` ends with `$script:openExplorer = $true`, overriding what the button handlers set. The check at line 2831 (`if ($script:openExplorer -and $effectivePath)`) therefore always evaluates `$true`, causing Explorer to always attempt to open and history to always log `Opened`.

**Button handler truth table (all broken except Open Folder by accident):**

| Button | Handler sets `openExplorer` | finally resets to | Logged outcome |
|--------|----------------------------|-------------------|----------------|
| Open Folder (line 2710) | `$true` | `$true` | Correct (accidental) |
| Dismiss (line 2687) | `$false` | `$true` | **BUG: logs `Opened`** |
| Exit (line 2643) | `$false` | `$true` | **BUG: logs `Opened`** |
| Snooze (line 2654) | `$false` | `$true` | **BUG: logs `Opened`** |
| PathMissing Dismiss (line 2722) | `$false` | `$true` | **BUG: logs `Opened`** |

**Evidence from `popup_log.txt`:** All 17 entries show `Outcome=Opened`, `SnoozeCount=0`.

---

### BUG-2 — `$window.Dispose()` called on `System.Windows.Window`
**Severity:** High (Crash — error dialog on every close)
**Files:** `DailyMotivation.ps1:2137` and `DailyMotivation.ps1:2798`
**Status:** Root cause fully confirmed. Fix is two `.Dispose()` → `.Close()` substitutions + one comment correction.

**What it breaks:** `System.Windows.Window` does not implement `System.IDisposable`. Calling `.Dispose()` throws `MissingMethodException`, surfaced to the user as:
```
Method invocation failed because [System.Windows.Window] does not contain a method named 'Dispose'.
```

**Two locations in current code (verified via grep):**

**Location 1 — `Show-MainWindow` finally block (line 2135–2141):**
```powershell
# CURRENT (BROKEN)
finally {
    if ($window) {
        $window.Dispose()   ← line 2137
    }
}

# AFTER FIX
finally {
    if ($window) {
        $window.Close()
    }
}
```

**Location 2 — `Show-PopupWindow` finally block (lines 2794–2801):**
```powershell
# CURRENT (BROKEN)
finally {
    # Dispose WPF window to release resources   ← misleading comment
    if ($window) {
        try {
            $window.Dispose()   ← line 2798
        }
        catch {}
    }

# AFTER FIX
finally {
    # Close WPF window to release resources
    if ($window) {
        try {
            $window.Close()
        }
        catch {}
    }
```

**CLAUDE.md mandate reference:** CORRECT 2 — use `.Close()` for `System.Windows.Window`. Never call `.Dispose()` on it.

---

### BUG-3 — "Invalid Folder" dialog title for `Register-ScheduledTask` failure
**Severity:** Medium (UX — misleading error message)
**File:** `DailyMotivation.ps1` — `Show-MainWindow` scheduling error handler
**Status:** Root cause confirmed in comments. Fix direction known. Exact line number needs verification during tomorrow's session.

**What it breaks:** When `Register-ScheduledTask` fails (e.g., non-elevated context, service unavailable), the error dialog title says "Invalid Folder" — which is the title for folder-validation failures. Task registration is a separate operation and must surface its own title.

**Per CLAUDE.md CORRECT 4 / MANDATE 6:** Error messages must name the failing operation. `Register-ScheduledTask` failures must show "Schedule Failed", not "Invalid Folder".

**Observed dialog (non-elevated run):**
```
---------------------------
Invalid Folder
---------------------------
Access is denied.
---------------------------
```

**Expected after fix:**
```
---------------------------
Schedule Failed
---------------------------
OS task registration was denied. Ensure Task Scheduler is enabled for your account.
---------------------------
```

---

### BUG-4 — `Set-PopupConfig` not persisting new task data after Schedule Reminder
**Severity:** High (Data integrity — popup fires for wrong folder)
**Status:** Root cause narrowed but not fully confirmed. Trace logging diagnostic pending.

**What it breaks:** After clicking "Schedule Reminder" (when elevated), `popup_config.json` is not updated with the new task's `task_id`, `explorer_path`, or `folder_name`. When the task fires, the popup reads stale config and displays a reminder for the previously scheduled folder, not the newly scheduled one.

**Ruled out (from 8-comment diagnostic thread):**
- ✅ APPDATA path mismatch between elevated/non-elevated — ruled out (same `$env:APPDATA`, same `$env:USERNAME`)
- ✅ `Global\DailyMotivationPopupConfigLock` mutex throws from elevated context — ruled out (mutex acquired successfully)
- ✅ NTFS permission / file-lock issue — ruled out
- ✅ `Set-PopupConfig` function itself broken — ruled out (direct elevated call succeeds)
- ✅ JSON serialization error — ruled out

**Still open:** Something in the `scheduleBtn.Add_Click` → `Do-Schedule` → `Invoke-FolderScheduling` → `Set-PopupConfig` call chain either returns early before line 1247 or silently swallows an exception. The WPF dispatcher swallows unhandled exceptions from button handlers without surfacing an error dialog.

**Diagnostic required tomorrow:**
Add trace logging immediately before/after `Set-PopupConfig` call in `Invoke-FolderScheduling`:

```powershell
# Temporary diagnostic — DO NOT COMMIT
Write-Host "[DIAG] About to call Set-PopupConfig: TaskId=$($regResult.task_id), Path=$explorerPath"
Set-PopupConfig @popupConfigParams
Write-Host "[DIAG] Set-PopupConfig completed"
```

Or use the already-instrumented debug log at `%TEMP%\DailyMotivation_debug.log` in the current source.

---

## Test Infrastructure Problem

### `Tests/Unit/UIDisposal.Tests.ps1` — AG6-004 block is inverted

**Critical:** The existing `AG6-004` Describe block at approximately lines 163–192 asserts that `$window.Dispose()` **must be present**:
```powershell
# CURRENT (WRONG — this is the anti-pattern, not the correct pattern)
$hasDisposal = ($functionBody -match 'finally\s*\{[^\}]*\$window.*Dispose\(\)')
($hasShowDialog -and $hasDisposal) | Should -Be $true -Because "WPF Window implements IDisposable and must be disposed"
```

This assertion is factually incorrect. `System.Windows.Window` does **not** implement `IDisposable`. This test will fail once BUG-2 is fixed (correctly), meaning the test must be replaced before or simultaneously with the code fix — otherwise the CI will fail immediately after the fix is merged.

**Action required:** Replace the `AG6-004` Describe block with the regression-guard tests specified in issue #183, which assert the opposite: `$window.Dispose()` must NOT be present.

---

## Tomorrow's Work Plan

### Prerequisites
- [ ] Be on Windows 10/11 machine with PowerShell 7 installed for live validation
- [ ] `DailyMotivation.exe` compatibility flag "Run this program as an administrator" must be **unchecked**
- [ ] `Invoke-Tests.ps1` available and passing baseline (359 passed, 0 failed, 7 skipped per your last run)

---

### Step 1 — Fix BUG-2 first (lines 2137 and 2798)

BUG-2 first because:
1. It has no test dependency conflicts (fix requires replacing a broken test)
2. It is the simplest mechanical change
3. Per issue #183 "Implementation Sequence" — BUG-2 before BUG-1

**Changes to `DailyMotivation.ps1`:**
- Line 2137: `$window.Dispose()` → `$window.Close()`
- Line 2795: comment `# Dispose WPF window to release resources` → `# Close WPF window to release resources`
- Line 2798: `$window.Dispose()` → `$window.Close()`

**Changes to `Tests/Unit/UIDisposal.Tests.ps1`:**
- Replace entire `Describe 'AG6-004: Window Disposal After ShowDialog'` block (both It blocks that assert Dispose must be present)
- Replace with the four-test `BUG-2: WPF Window Disposal Regression Guard` block and the `BUG-2 File-Wide Regression Guard` block from issue #183

**Skill to invoke:** `/tdd` (test-first: write the new UIDisposal tests, see them fail on current code, apply fix, see them pass)

---

### Step 2 — Fix BUG-1 (line 2805)

**Change to `DailyMotivation.ps1`:**
- Line 2805: remove `$script:openExplorer = $true` from the finally block entirely

**New tests to add:**
- `Tests/Unit/FolderScheduling.Tests.ps1` — append the `BUG-1: Show-PopupWindow openExplorer state preservation` Describe block (5 It blocks verifying each button's handler and the finally block absence)
- `Tests/Unit/InputValidation.Tests.ps1` — append the `BUG-1 Structural Guard` Describe block (2 It blocks)

**Skill to invoke:** `/tdd` (same red-green cycle as Step 1)

---

### Step 3 — Fix BUG-3 (error title "Invalid Folder" for scheduling failure)

**Action:** Find the exact line in `Show-MainWindow` / `Do-Schedule` / `Invoke-FolderScheduling` where `Register-ScheduledTask` failure is caught and surfaced as "Invalid Folder". Change the dialog title to "Schedule Failed" and the message to name the operation per CLAUDE.md CORRECT 4.

**Skill to invoke:** `/diagnosing-bugs` (build a feedback loop — write a structural test that asserts the catch block near `Register-ScheduledTask` uses "Schedule Failed" not "Invalid Folder")

---

### Step 4 — BUG-4 trace logging diagnostic

**Action:** Add temporary `Write-Host` / `%TEMP%\DailyMotivation_debug.log` instrumentation around the `Set-PopupConfig` call in the scheduling call chain. Run the elevated `DailyMotivation.exe`, click Schedule Reminder, and read the log to identify exactly where execution exits before/at `Set-PopupConfig`.

**Do NOT commit the trace logging.** It is diagnostic only.

**Skill to invoke:** `/diagnosing-bugs` — Phase 1 (build a feedback loop via the HITL log pattern)

---

### Step 5 — Full test run

```powershell
.\Invoke-Tests.ps1 -CI -Coverage $true
```

Expected post-fix result: ≥ 359 passed, 0 failed, ≤ 7 skipped (new tests from Steps 1–2 add to the pass count).

**CLAUDE.md closure gate:** Per the Windows validation mandate, you must run this on Windows 10/11 and attach the output to issue #183 before closing the issue.

---

### Step 6 — Manual Windows validation

Per issue #183 acceptance criteria — must be checked on live Windows machine:

- [ ] Close `DailyMotivation.exe` main window → **no error dialog** (BUG-2 fix)
- [ ] Click Dismiss in popup → Explorer does NOT open; `popup_log.txt` logs `Dismissed` (BUG-1 fix)
- [ ] Click Snooze in popup → Explorer does NOT open; `popup_log.txt` logs `Snoozed` (BUG-1 fix)
- [ ] Click Exit in popup → Explorer does NOT open (BUG-1 fix)
- [ ] Click Open Folder in popup → correct scheduled folder opens; `popup_log.txt` logs `Opened` (BUG-1 correct path)
- [ ] `popup_log.txt` shows varied outcomes across sessions — not all `Opened` (BUG-1 fix confirmed)
- [ ] Schedule Reminder → confirm `popup_config.json` updated with correct `task_id` and `explorer_path` (BUG-4 diagnostic)
- [ ] "Schedule Reminder" failure dialog title reads "Schedule Failed", not "Invalid Folder" (BUG-3 fix)

---

### Step 7 — Commit and push

```
fix(popup): replace $window.Dispose() with $window.Close() (BUG-2)
fix(popup): remove $script:openExplorer reset from Show-PopupWindow finally block (BUG-1)
fix(scheduling): correct error dialog title for Register-ScheduledTask failure (BUG-3)
test(UIDisposal): replace AG6-004 Dispose-must-exist assertion with Dispose-must-NOT-exist regression guard
test(FolderScheduling): add BUG-1 behavioral tests for each button handler
test(InputValidation): add BUG-1 structural guard for finally block
```

Push to `project-restart-pwsh7` (which is now also `main`).

**Skill to invoke:** `/code-review` (review diff against issue #183 spec before pushing)

---

## Skill Recommendations

The following skills are available in `CLAUDE/skills/` and are directly applicable to tomorrow's work:

| Skill | Path | When to invoke |
|-------|------|----------------|
| **`/tdd`** | `CLAUDE/skills/engineering/tdd/SKILL.md` | Steps 1 and 2 — write failing tests first for BUG-1 and BUG-2, then apply fixes |
| **`/diagnosing-bugs`** | `CLAUDE/skills/engineering/diagnosing-bugs/SKILL.md` | Steps 3 and 4 — finding exact BUG-3 catch site; BUG-4 trace loop |
| **`/implement`** | `CLAUDE/skills/engineering/implement/SKILL.md` | Steps 1–3 — apply code changes after TDD cycle |
| **`/code-review`** | `CLAUDE/skills/engineering/code-review/SKILL.md` | Step 7 — review the full diff against issue #183 spec before pushing |
| **`/handoff`** | `CLAUDE/skills/productivity/handoff/SKILL.md` | End of session — compact the session into a handoff doc if BUG-4 is not resolved |
| **`/wayfinder`** | `CLAUDE/skills/engineering/wayfinder/SKILL.md` | If BUG-4 root cause is deeper than the call chain — map the investigation as child issues |
| **`/domain-modeling`** | `CLAUDE/skills/engineering/domain-modeling/SKILL.md` | If `popup_config.json` / `tasks.json` sync issues turn out to be a structural data-integrity problem |

### Suggested skill invocation order

```
session start → /diagnosing-bugs (BUG-3 catch site scan)
             → /tdd (BUG-2: new UIDisposal tests → fix)
             → /tdd (BUG-1: new FolderScheduling + InputValidation tests → fix)
             → /implement (BUG-3 title change)
             → /diagnosing-bugs (BUG-4 trace loop)
             → /code-review (full diff vs issue #183)
             → /handoff (if BUG-4 unresolved at session end)
```

---

## Key File and Line Reference

| Location | Line(s) | Bug | Action |
|----------|---------|-----|--------|
| `DailyMotivation.ps1` | 2137 | BUG-2 | `$window.Dispose()` → `$window.Close()` |
| `DailyMotivation.ps1` | 2795 | BUG-2 | Fix comment: "Dispose" → "Close" |
| `DailyMotivation.ps1` | 2798 | BUG-2 | `$window.Dispose()` → `$window.Close()` |
| `DailyMotivation.ps1` | 2805 | BUG-1 | Remove `$script:openExplorer = $true` |
| `DailyMotivation.ps1` | ~1820 | BUG-4 | Add trace logging around `Set-PopupConfig` call |
| `DailyMotivation.ps1` | ~1247 | BUG-4 | Wrap `Set-PopupConfig` call in try/catch (BUG-4b) |
| `DailyMotivation.ps1` | TBD | BUG-3 | Find + fix "Invalid Folder" title in scheduling catch |
| `Tests/Unit/UIDisposal.Tests.ps1` | ~163–192 | Test fix | Replace AG6-004 block (asserts Dispose must exist → invert to must NOT exist) |
| `Tests/Unit/FolderScheduling.Tests.ps1` | EOF | New test | Append BUG-1 behavioral tests (5 It blocks) |
| `Tests/Unit/InputValidation.Tests.ps1` | EOF | New test | Append BUG-1 structural guard (2 It blocks) |

---

## Constraints and Mandates (from CLAUDE.md)

1. **No `Register-ScheduledTask`-related bug may be closed without live Windows 10/11 validation.** Linux CI passing is necessary but not sufficient.
2. **Never call `.Dispose()` on `System.Windows.Window`.** Use `.Close()`. The fix for BUG-2 is already specified exactly.
3. **`$script:openExplorer` must not be assigned in the `Show-PopupWindow` finally block.** The fix for BUG-1 is a single line removal.
4. **Error messages must name the failing operation.** "Invalid Folder" must not appear for `Register-ScheduledTask` failures (BUG-3).
5. **Windows `Invoke-Pester` output must be attached to issue #183 as a comment before the issue is closed.** Screenshot or terminal paste from Windows 10/11 PowerShell 7.

---

## Appendix — Issue #183 Comment Thread Summary

| # | Author | Timestamp | Key finding |
|---|--------|-----------|-------------|
| 1 | SevWren | 2026-08-07T23:02 | BUG-3 confirmed (non-elevated). BUG-2 confirmed in standard user context. Reproduction matrix documented. |
| 2 | SevWren | 2026-08-07T23:10 | Run-as-admin unblocks task creation. `popup_log.txt` vs `tasks.json` cross-reference: 14/17 task_ids orphaned (historical). Rapid-fire triple popup execution observed (mutex question). |
| 3 | SevWren | 2026-08-07T23:13 | Prior "orphaned tasks still firing" hypothesis ruled out — only 1 task in Task Scheduler. Corrected: all popup_log entries read from whatever `popup_config.json` held at fire time. Stale config confirmed. |
| 4 | SevWren | 2026-08-07T23:15 | `popup_config.json` shows stale `d337a75afe434197` / `Daily-Motivation-Brain-Helper`. BUG-4 added. Root cause hypothesis: APPDATA mismatch or mutex throwing from elevated context. |
| 5 | SevWren | 2026-08-07T23:21 | APPDATA paths identical. Mutex constructor hypothesis: `UnauthorizedAccessException` from elevated context. Call chain analysis: `scheduleBtn.Add_Click` → `Do-Schedule` → exception swallowed by WPF dispatcher. |
| 6 | SevWren | 2026-08-08T00:36 | Mutex probe from elevated PowerShell: **acquired successfully**. BUG-4a (mutex throws) ruled out. Cause still in call chain. `Set-PopupConfig` direct test needed. |
| 7 | SevWren | 2026-08-08T02:01 | `Set-PopupConfig` called directly from elevated PS: **succeeds**. `popup_config.json` now patched for 14:00 task fire. Root cause is in the UI button handler call chain — something exits before `Set-PopupConfig` is reached. Trace logging diagnostic prescribed. |
| 8 | SevWren | 2026-08-08T02:43 | File lock, ACL, mutex, JSON serialization all ruled out. `scheduleBtn.Add_Click` is a one-liner with no error handling — any throw in `Do-Schedule` is silently swallowed. Four early-return points in `Invoke-FolderScheduling` mapped. Old-build BUG-1, BUG-2 fixed in `src/`; new `project-restart-pwsh7` monolith still has them. |

---

*Brief generated 2026-08-08. All line numbers verified against current `project-restart-pwsh7` HEAD (`46ac907`).*
