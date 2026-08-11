# BUG-4 Investigation & Fix Plan

**Brief:** daily-brief-2026-08-09 — BUG-4: `Set-PopupConfig` not completing the Handoff after Schedule
**Source of truth:** `DailyMotivation.ps1` (single-file monolith), lines 375–421, 1146–1264, 1827–1889, 1963–1965
**Platform:** Windows 10/11 (live validation required; Linux CI tests use platform adapter and will not reproduce this)

---

## Validation: Brief Claims vs. Actual Code

| Brief Claim | Code Reality | Verdict |
|---|---|---|
| "Four early-return points in `Invoke-FolderScheduling`" | Early returns at lines 1169, 1188, 1217, 1230 — but all occur **before** `New-MotivationTask` succeeds | **Ruled out as cause.** The brief says the OS Task IS created in Windows Task Scheduler, so execution reaches line 1247. |
| "something exits early before `Set-PopupConfig`" | No early return exists after line 1237. Execution reaches line 1247 linearly. | **Wrong framing.** The actual mechanism is `Set-PopupConfig` throwing, and the throw bypasses the return at line 1258. |
| "WPF dispatcher swallows exceptions silently" | `scheduleBtn.Add_Click` (line 1963) has **zero** try/catch. `Do-Schedule` (line 1827) has **zero** try/catch. | **Confirmed.** Any throw from `Invoke-FolderScheduling` propagates to the WPF dispatcher and is silently swallowed. |

**Revised root-cause hypothesis:**
`New-MotivationTask` succeeds (OS Task registered in Windows Task Scheduler, MotivationTask saved to `tasks.json`). Then `Set-PopupConfig` at line 1247 throws. The throw propagates through `Invoke-FolderScheduling` → `Do-Schedule` → `scheduleBtn.Add_Click` → WPF dispatcher. The dispatcher silently consumes the exception. The user sees no error. The PopupConfig is never updated. The Popup later fires and reads stale PopupConfig.

---

## Phase 1 — Diagnostic Instrumentation (30 min, do NOT commit)

Add temporary trace logging at three points in the call chain to confirm the throw and capture the exact error message.

### 1a. Log inside `Set-PopupConfig` itself

Insert at the top of `Set-PopupConfig` (after the param block, before the Mutex):

```powershell
$diagLog = Join-Path $script:TempDir "DailyMotivation_bug4_diag.log"
"[$(Get-Date -Format 'HH:mm:ss.fff')] Set-PopupConfig START: TaskId=$TaskId Path=$ExplorerPath" | Out-File -Append -FilePath $diagLog -Encoding UTF8
```

Insert at the end of the `try` block (after `Move-Item`, before the `catch`):

```powershell
"[$(Get-Date -Format 'HH:mm:ss.fff')] Set-PopupConfig SUCCESS" | Out-File -Append -FilePath $diagLog -Encoding UTF8
```

Insert at the start of the `catch` block:

```powershell
"[$(Get-Date -Format 'HH:mm:ss.fff')] Set-PopupConfig THROW: $($_.Exception.Message)" | Out-File -Append -FilePath $diagLog -Encoding UTF8
```

### 1b. Log around the call site in `Invoke-FolderScheduling`

Around line 1247:

```powershell
$diagLog = Join-Path $script:TempDir "DailyMotivation_bug4_diag.log"
"[$(Get-Date -Format 'HH:mm:ss.fff')] Invoke-FolderScheduling: about to call Set-PopupConfig" | Out-File -Append -FilePath $diagLog -Encoding UTF8
Set-PopupConfig @popupConfigParams
"[$(Get-Date -Format 'HH:mm:ss.fff')] Invoke-FolderScheduling: Set-PopupConfig returned" | Out-File -Append -FilePath $diagLog -Encoding UTF8
```

### 1c. Log inside `Do-Schedule` and the button handler

In `Do-Schedule` before line 1845:

```powershell
$diagLog = Join-Path $script:TempDir "DailyMotivation_bug4_diag.log"
"[$(Get-Date -Format 'HH:mm:ss.fff')] Do-Schedule: starting Invoke-FolderScheduling" | Out-File -Append -FilePath $diagLog -Encoding UTF8
```

In `Do-Schedule` after line 1845 (before the `if (-not $result.Success ...)` check):

```powershell
"[$(Get-Date -Format 'HH:mm:ss.fff')] Do-Schedule: Invoke-FolderScheduling returned Success=$($result.Success)" | Out-File -Append -FilePath $diagLog -Encoding UTF8
```

In `scheduleBtn.Add_Click` (line 1963):

```powershell
$scheduleBtn.Add_Click({
    $diagLog = Join-Path $script:TempDir "DailyMotivation_bug4_diag.log"
    "[$(Get-Date -Format 'HH:mm:ss.fff')] scheduleBtn: clicked, selectedPath=$($script:selectedPath)" | Out-File -Append -FilePath $diagLog -Encoding UTF8
    if ($script:selectedPath) {
        try {
            Do-Schedule -FolderPath $script:selectedPath
            "[$(Get-Date -Format 'HH:mm:ss.fff')] scheduleBtn: Do-Schedule completed without throw" | Out-File -Append -FilePath $diagLog -Encoding UTF8
        } catch {
            "[$(Get-Date -Format 'HH:mm:ss.fff')] scheduleBtn: Do-Schedule THREW: $($_.Exception.Message)" | Out-File -Append -FilePath $diagLog -Encoding UTF8
            throw
        }
    }
})
```

**Note:** The try/catch in 1c is intentional — it will capture the throw that would otherwise be silently swallowed, log it, and then re-throw so the WPF dispatcher still sees it (this is diagnostic only; the fix in Phase 3 will handle it properly).

**Validation:** Run elevated, click Schedule Reminder, read `%TEMP%\DailyMotivation_bug4_diag.log`. The log will show exactly where execution stops and the exact exception text.

---

## Phase 2 — Root Cause Fix (after diagnostics reveal the error)

The fix depends on what the diagnostic log shows. Possible root causes and their fixes:

### If the log shows `Set-PopupConfig` succeeds: brief hypothesis is wrong
- The bug is elsewhere (e.g., the PopupConfig is being overwritten by another process, or popup mode reads from a different path).
- Investigate: check if `Get-PopupConfig` in popup mode reads the same `$script:PopupCfgPath`. Verify no other code path writes the PopupConfig between Schedule time and Popup trigger time.

### If the log shows `Set-PopupConfig` throws with a file I/O error (e.g., `Move-Item` fails)
- Likely cause: destination file locked by another process (e.g., the popup process still has the file open, or an antivirus scanner).
- Fix: Replace `Move-Item` with a copy-and-delete pattern that retries on transient lock:

```powershell
$maxRetries = 3
$retryDelay = 200
for ($i = 0; $i -lt $maxRetries; $i++) {
    try {
        Copy-Item -Path $tempPath -Destination $script:PopupCfgPath -Force -ErrorAction Stop
        Remove-Item -Path $tempPath -ErrorAction Stop
        break
    } catch {
        if ($i -lt $maxRetries - 1) { Start-Sleep -Milliseconds $retryDelay } else { throw }
    }
}
```

### If the log shows `Set-PopupConfig` throws with a Mutex timeout (`WaitOne` returns false after 2s)
- This means another process holds `Global\DailyMotivationPopupConfigLock` for >2 seconds.
- Fix: Increase timeout to 10 seconds, or add retry logic. Also add logging inside the Mutex wait to identify the contending process.

### If the log shows `Set-PopupConfig` throws with an encoding/serialization error
- Likely cause: `ConvertTo-Json` or `Set-Content -Encoding UTF8` fails on a specific character in the FolderName or message.
- Fix: Sanitize the FolderName and message text before serialization, or use `UTF8NoBOM` encoding.

---

## Phase 3 — Defensive Error Handling in the UI Chain (10 min)

Regardless of the root cause found in Phase 2, the WPF dispatcher MUST not silently swallow exceptions from the scheduling button handler. Add try/catch at the button handler level.

### 3a. Wrap `scheduleBtn.Add_Click` in try/catch

Replace line 1963–1965:

```powershell
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

**Rationale:** This is the outermost boundary where user action meets business logic. Any exception from `Do-Schedule` that is not already caught by inner handlers (e.g., BUG-3's `Register-ScheduledTask` catch at line 1854) will surface as a user-visible error dialog instead of being silently consumed. The title "Schedule Failed" and the message "PopupConfig write failed" are distinct from BUG-3's `Register-ScheduledTask` error message, satisfying MANDATE 6 (name the failing operation). If diagnostic Phase 1 reveals the throw originates from a different component, update the message text to name that operation specifically.

**Cross-dependency with BUG-3:** BUG-3 modifies line 1854 inside `Do-Schedule` to show a "Schedule Failed" dialog for `Register-ScheduledTask` failures. If BUG-3 is applied first, its inner catch will handle OS Task registration failures before they reach this outer catch. This outer catch is a backstop for exceptions that escape BUG-3's inner catch (specifically `Set-PopupConfig` throws and other post-registration failures). The two dialogs will not both fire for the same error because the inner catch does not re-throw.

### 3b. Add a `DispatcherUnhandledException` handler as a safety net (optional but recommended)

Add near the top of `Show-MainWindow`, after the window is created:

```powershell
$window.Add_DispatcherUnhandledException({
        param($sender, $e)
        Show-ErrorDialog -Title "Unexpected Error" -Message "An unexpected error occurred: $($e.Exception.Message)"
        $e.Handled = $true
    })
```

**Rationale:** Provides a last-resort safety net for any other unhandled exceptions in the WPF dispatcher. Prevents silent failures from any future event handler that forgets try/catch.

---

## Phase 4 — Tests

### 4a. Test that `scheduleBtn.Add_Click` surfaces errors

Add to `FolderScheduling.Tests.ps1`:

```powershell
Describe "BUG-4: Schedule button error surfacing" {
    It "Should not silently swallow exceptions from Do-Schedule" {
        # This is a structural test: verify the button handler has try/catch
        $content = Get-Content -Path $script:ProjectRoot -Raw
        $handlerPattern = '(?s)scheduleBtn\.Add_Click\(\{[\s\S]*?Do-Schedule[\s\S]*?\}\)'
        $handlerMatch = [regex]::Match($content, $handlerPattern)
        $handlerBody = $handlerMatch.Value
        $handlerBody | Should -Match 'try\s*\{'
        $handlerBody | Should -Match 'catch\s*\{'
    }
}
```

### 4b. Test that `Invoke-FolderScheduling` propagates `Set-PopupConfig` failures

This requires mocking `Set-PopupConfig` to throw. Verify that `Invoke-FolderScheduling` does NOT return `Success=$true` when `Set-PopupConfig` throws — it should propagate the exception so the caller can handle it.

```powershell
It "Should propagate Set-PopupConfig failure rather than returning success" {
    Mock Set-PopupConfig { throw "Simulated PopupConfig write failure" }
    { $result = Invoke-FolderScheduling -FolderPath "/tmp/test" -TriggerTime (Get-Date).AddHours(1) } | Should -Throw
}
```

### 4c. Test that `Set-PopupConfig` retry logic works (if Phase 2b fix is applied)

Mock `Move-Item` to fail on first call, succeed on second. Verify `Set-PopupConfig` eventually succeeds.

---

## Phase 5 — Cleanup and Validation

1. Remove all diagnostic `Write-Host` / `Out-File` logging from Phase 1.
2. Run full test suite: `.\Invoke-Tests.ps1 -CI -Coverage $true`
3. **Live Windows validation required:**
   - Run elevated, click Schedule Reminder → confirm the PopupConfig is updated with correct `task_id`, `explorer_path`, `folder_name`
   - Confirm no error dialog appears
   - Confirm no silent failure (diag log removed, but behavior observed)
4. **GitHub Issue Closure Gate (CLAUDE.md MANDATE):** Do not close issue #183 or declare BUG-4 resolved until Windows-validated Pester output (from a real Windows 10/11 PowerShell 7 session) is attached as a comment to issue #183. Linux CI passing is necessary but not sufficient.
5. If BUG-4 is NOT resolved after Phase 2, use `/handoff` skill to write a session summary with the diagnostic log findings for the next agent.

---

## Commit Sequence

```
fix(scheduling): add try/catch to schedule button handler to surface errors (BUG-4)
fix(scheduling): add retry logic to Set-PopupConfig Move-Item for transient file locks (BUG-4)
test(FolderScheduling): add BUG-4 error-propagation and retry tests
```

(Adjust commit messages based on which Phase 2 fix is applied.)

---

## Out-of-Scope Decisions

- **Do NOT change `Set-PopupConfig`'s Mutex timeout or Mutex name** — ruled out by issue comment 6 (Mutex acquires successfully from elevated context).
- **Do NOT refactor `Invoke-FolderScheduling` return contract** — the function correctly returns for validation failures; the only issue is the unhandled exception from `Set-PopupConfig`.
- **Do NOT change `New-MotivationTask` rollback behavior** — the MotivationTask + `tasks.json` atomicity is correct; the problem is the missing PopupConfig Handoff write.
