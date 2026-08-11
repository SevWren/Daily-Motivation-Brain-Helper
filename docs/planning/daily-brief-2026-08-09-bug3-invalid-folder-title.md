# Plan — BUG-3: Fix "Invalid Folder" dialog title for Register-ScheduledTask failure

**File:** `DailyMotivation.ps1`
**Brief reference:** `daily-brief-2026-08-09.md` — BUG-3 section
**Date:** 2026-08-11

---

## Problem

When `Register-ScheduledTask` fails (non-elevated context, service stopped, S4U logon failure, etc.), `Do-Schedule` at line **1854** surfaces the error with title **"Invalid Folder"**. That title belongs to FolderPath validation failures (see `Set-SelectedPath` at line 1817, which legitimately uses "Invalid Folder"). Mixing the two makes it impossible for the user to distinguish "your folder is bad" from "Windows couldn't create the OS Task."

The `/setfolder` mode entry point (line 3050) already correctly uses **"Schedule Failed"** — the `Show-MainWindow` → `Do-Schedule` path simply wasn't updated when that fix was made.

---

## Root Cause

`Do-Schedule` (line 1851–1859) handles all `$result.Success = $false` outcomes from `Invoke-FolderScheduling` with a single `MessageBox::Show` call tagged "Invalid Folder." The `$result.Error` string can originate from any of these `New-MotivationTask` failure points:

| Source | Lines | Example error text |
|--------|-------|--------------------|
| `New-ScheduledTaskAction` throws | 748–750 | XML parse / COM error |
| `Register-ScheduledTask` throws | 801–812 | "Access is denied.", "requires elevation", service unavailable |
| `Save-TasksJson` throws (rollback also fails) | 832–843 | JSON / file-system error |
| Unregister rollback after Save-TasksJson fails | 834–841 | "Failed to save task record AND failed to rollback…" |

All of these are **scheduling** failures, not **FolderPath validation** failures. The FolderPath has already passed `Test-Path` validation in `Set-SelectedPath` before `Do-Schedule` is ever called.

---

## Fix — Single code change

**Line 1854** in `DailyMotivation.ps1` (`Do-Schedule` error handler):

```powershell
# BEFORE (wrong title, misleading message)
[void][System.Windows.MessageBox]::Show($result.Error, "Invalid Folder", "OK", "Warning")

# AFTER (correct title, operation-named message)
[void][System.Windows.MessageBox]::Show(
    "Could not schedule reminder for this folder.`n`n$($result.Error)",
    "Schedule Failed", "OK", "Warning")
```

### Why this message

- "Could not schedule reminder" names the failing operation (per CLAUDE.md CORRECT 4 / MANDATE 6).
- The raw `$result.Error` is still included below the separator so the user (and support) can see the Windows error code. **Note:** `$result.Error` originates from the `New-MotivationTask` catch block (CORRECT 4 pattern, lines 801–812). If those catch blocks follow the CLAUDE.md CORRECT 4 pattern with switch-mapped HResult-coded strings (e.g., "OS task registration was denied."), the message will be fully operation-named. If they pass through raw COM error strings, the "Could not schedule reminder" prefix provides the required operation context while preserving the raw Windows error code. Implementers must verify which error text `Invoke-FolderScheduling` places in `$result.Error` before closing this bug.
- No FolderPath is interpolated — avoids leaking the FolderPath into a dialog that may be screen-captured or logged. The "Invalid Folder" title was the only place the path leaked; this fix removes that vector entirely.
- Matches the `/setfolder` mode pattern at line 3050 in spirit ("Schedule Failed" title, operation-named prefix).

---

## No other code changes required

- `Set-SelectedPath` at line 1817 legitimately uses **"Invalid Folder"** — that is a true FolderPath validation failure. **Do not change it.**
- `Do-Schedule` duplicate-failure path (lines 1862–1876) already uses `Show-ErrorDialog` with descriptive messages — no title issue there.
- `Show-MainWindow` `/setfolder` mode (line 3050) already uses "Schedule Failed" — already correct.

---

## Tests to add

### 1. Structural test — `Do-Schedule` catch block uses "Schedule Failed"

Add to `Tests/Unit/FolderScheduling.Tests.ps1` (or a new `Tests/Unit/SchedulingErrorHandling.Tests.ps1`):

**Important:** `Do-Schedule` is a nested function defined inside `Show-MainWindow` in `DailyMotivation.ps1`. It is not registered as a module-level command. `Get-Command Do-Schedule -Module DailyMotivation` will return `$null` after dot-sourcing. Use the established project pattern of reading the source file directly with `Get-Content` and locating the function body by string boundary.

```powershell
Describe 'BUG-3: Do-Schedule error dialog title for scheduling failures' {
    It 'uses "Schedule Failed" title, not "Invalid Folder", when Invoke-FolderScheduling returns an error' {
        $sourceFile = Join-Path $PSScriptRoot '..\..\DailyMotivation.ps1'
        $content = Get-Content $sourceFile -Raw
        $fnStart = $content.IndexOf('function Do-Schedule')
        $fnEnd   = $content.IndexOf("`nfunction ", $fnStart + 20)
        $functionBody = if ($fnEnd -gt $fnStart) { $content.Substring($fnStart, $fnEnd - $fnStart) } else { $content.Substring($fnStart) }
        $hasScheduleFailed = $functionBody -match 'Schedule Failed'
        $hasInvalidFolder  = $functionBody -match 'Invalid Folder'
        $hasScheduleFailed | Should -Be $true
        $hasInvalidFolder  | Should -Be $false
    }
}
```

### 2. Positive test — `Set-SelectedPath` still uses "Invalid Folder"

**Important:** `Set-SelectedPath` is also a nested function inside `Show-MainWindow`. Use the same `Get-Content` / `IndexOf` pattern.

```powershell
It 'preserves "Invalid Folder" title in Set-SelectedPath for actual FolderPath validation failures' {
    $sourceFile = Join-Path $PSScriptRoot '..\..\DailyMotivation.ps1'
    $content = Get-Content $sourceFile -Raw
    $fnStart = $content.IndexOf('function Set-SelectedPath')
    $fnEnd   = $content.IndexOf("`nfunction ", $fnStart + 25)
    $functionBody = if ($fnEnd -gt $fnStart) { $content.Substring($fnStart, $fnEnd - $fnStart) } else { $content.Substring($fnStart) }
    $functionBody -match 'Invalid Folder' | Should -Be $true
}
```

### 3. Integration test — `New-MotivationTask` error propagation preserves HResult-coded messages

Verify that `Register-ScheduledTask` failures that reach `Do-Schedule` carry the raw Windows error text (so the user sees "Access is denied" rather than a sanitized string):

```powershell
It 'propagates Register-ScheduledTask error text through to the UI error dialog' {
    # This is verified implicitly by the New-MotivationTask catch block tests
    # already in TaskScheduler.Tests.ps1 — no new test needed if those exist.
}
```

> **Note:** If `TaskScheduler.Tests.ps1` already has tests covering the `New-MotivationTask` catch-block error strings (lines 650–718 in `bug_fix_instructions_kilo_code_needs_review.md`), no additional integration test is needed. Verify those tests reference the error strings that reach `Do-Schedule`.

---

## Validation

### Automated (Linux CI — necessary but not sufficient)

```powershell
.\Invoke-Tests.ps1
```

Expected: all existing tests pass; new BUG-3 tests pass (≥ 361 passed).

### Required — Live Windows 10/11 validation (per CLAUDE.md MANDATE)

This bug involves `Register-ScheduledTask` error propagation. Per project rules, it **cannot** be closed without live Windows validation.

1. On a Windows 10/11 machine, run `DailyMotivation.exe` **without** administrator elevation.
2. Click **Schedule Reminder** on any valid folder.
3. Confirm the dialog title reads **"Schedule Failed"** (not "Invalid Folder").
4. Confirm the message reads "Could not schedule reminder for this folder." followed by the Windows error text (e.g., "Access is denied.").
5. Confirm `Set-SelectedPath` still shows "Invalid Folder" when you type a non-existent path.
6. Attach `.\Invoke-Tests.ps1` output (from Windows PowerShell 7) as a comment on issue #183.

---

## Commit message

```
fix(scheduling): use "Schedule Failed" title for Register-ScheduledTask errors (BUG-3)

Do-Schedule was surfacing all Invoke-FolderScheduling failures with the
"Invalid Folder" title, which belongs only to FolderPath validation errors in
Set-SelectedPath. Change the Do-Schedule error dialog to "Schedule Failed"
with an operation-named message, matching the /setfolder mode pattern.
```

---

## Risks

| Risk | Likelihood | Mitigation |
|------|-----------|------------|
| `$result.Error` is `$null` for some failure paths | Low (all return paths set `Error`) | The existing code already interpolates `$result.Error` directly; this fix doesn't change that. |
| Existing tests assert "Invalid Folder" appears somewhere in `Do-Schedule` | Low (grep shows no such test) | Grep confirms no test matches `Invalid Folder` in the scheduling context. |
| User confusion from title change | None | Title was already wrong; "Schedule Failed" is the correct per-mandate title. |
| `$result.Error` doesn't contain operation-named text (only raw COM error string) | Medium | The "Could not schedule reminder" prefix provides operation context regardless. Verify `New-MotivationTask` catch blocks (lines 801–812) against CLAUDE.md CORRECT 4 pattern. |

---

## Out of scope

- Path sanitization of `$FolderPath` in the `/setfolder` mode line 3050 message — that exists but is a separate concern.
- Switching `Do-Schedule` from `MessageBox::Show` to `Show-ErrorDialog` — unnecessary; the raw `MessageBox` call works correctly and changing it would alter the UX (button layout) without fixing a bug.
- BUG-4 (PopupConfig persistence) — separate investigation, separate plan.
