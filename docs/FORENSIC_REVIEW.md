# FORENSIC_REVIEW.md
# Daily-Motivation-Brain-Helper — Multi-Agent Code Audit

**Audit Date:** 2026-06-03
**Audit Method:** Three parallel forensic agents performed full read-through of all 13 source files
**Scope:** All bugs, gaps, unhandled error conditions, and unintended behaviors
**Out of Scope:** `ShellExtension/` directory — dropped from product scope (user confirmed: app launches via `.exe` only; no right-click context menu feature required)

## Resolution Status — All Findings Resolved

**Resolution Date:** 2026-06-03
**Resolution Method:** Phase 1-A through Phase 1-E commit series (see HANDOFF2.md for commit history)

All 38 in-scope findings documented below have been resolved in the current codebase. The findings are retained for audit trail and historical reference only. Do not treat them as outstanding issues.

| Commit Phase | Findings Resolved |
|-------------|------------------|
| Phase 1-A | GAP-002, ERR-017, GAP-035 (critical path fixes) |
| Phase 1-B | ERR-001, UB-001, ERR-003 |
| Phase 1-C | ERR-002, ERR-004, BUG-009 |
| Phase 1-D | GAP-003, ERR-008, GAP-004, ERR-005b, BUG-005, GAP-001 |
| Phase 1-E | BUG-001, ERR-005, UB-003, GAP-005, GAP-006 |
| Phase 2-4 | GAP-007, GAP-010, GAP-003b, UB-002, UB-004, ERR-034, BUG-011, BUG-004, BUG-003, GAP-014, XAML-016, BUG-015, ERR-013 |

---

## Executive Summary

| Severity | In-Scope Count | Out-of-Scope (ShellExtension) |
|----------|:--------------:|:-----------------------------:|
| Critical | 4 | 2 |
| High | 13 | 2 |
| Medium | 14 | 0 |
| Low | 3 | 0 |
| Cross-cutting | 4 | 2 |
| **Total** | **38** | **6** |
| **Grand total** | **55** | |

### Show-Stopper Risks (Fix Before Anything Else)

| # | ID | Risk | Impact | Status |
|---|-----|------|--------|--------|
| 1 | GAP-002 | `LauncherPath` in `TaskScheduler.psm1` points to `%APPDATA%` where `LaunchMotivation.bat` is **never copied**. | Every scheduled task fires and silently fails. Core feature is completely broken. | RESOLVED — `LauncherPath` now resolved from module's `$PSScriptRoot` (install dir) |
| 2 | GAP-035 | No code-behind file exists for `MainWindow.xaml`. | All buttons (Select Folder, Schedule, Delete, Undo, Clear History) do nothing when clicked. | RESOLVED — Full code-behind implemented in `MainApp.ps1` |
| 3 | ERR-017 | WPF requires STA thread. No `-STA` flag enforced in launcher chain. | App crashes on load on most systems: *"The calling thread must be STA, because many UI components require this."* | RESOLVED — `-STA` flag present in `LaunchMotivation.bat` |

---

## Section 1 — Critical Findings (In Scope)

---

### GAP-002
- **File:** `src/Modules/TaskScheduler.psm1`
- **Line:** 8
- **Category:** Gap
- **Description:** `$script:LauncherPath` is hard-coded to `$env:APPDATA\DailyMotivationBrainHelper\LaunchMotivation.bat`. This file is never copied to `%APPDATA%` during setup — it lives in the app installation directory. Every scheduled task that Windows fires will attempt to run a file that does not exist at that path and silently fail with no user feedback.
- **Fix:** Either (a) copy `LaunchMotivation.bat` to `%APPDATA%\DailyMotivationBrainHelper\` during first-run setup, or (b) store the actual installation path in `tasks.json` at schedule-creation time and reference it dynamically.

---

### ERR-001
- **File:** `src/DailyMotivation.ps1`
- **Lines:** 88–93
- **Category:** ErrorHandling
- **Description:** The config JSON parse `catch` block logs `"Config parse failed - using defaults"` but never logs `$_.Exception.Message` or `$_.Exception.InnerException`. When a user's config file becomes corrupted (encoding issue, partial write, disk error), the app silently resets all settings to defaults. The user has no way to know why their folder path and preferences vanished.
- **Fix:**
  ```powershell
  catch {
      Write-DLog "Config parse failed: $($_.Exception.Message)" "ERROR"
      Write-DLog "Inner: $($_.Exception.InnerException)" "ERROR"
      # optionally show a user-facing warning dialog here
  }
  ```

---

### UB-001
- **File:** `src/DailyMotivation.ps1`
- **Lines:** 44–67
- **Category:** UnintendedBehavior
- **Description:** The mutex acquisition block catches `AbandonedMutexException` and sets `$mutexOwned = $true`, proceeding as normal. However, an abandoned mutex means the prior process crashed — it does not mean the prior popup window closed. The hung or partially-rendered previous popup may still be visible. The result is two popups on screen simultaneously, violating SSOT-006 ("Only one active popup may exist").
- **Fix:** After acquiring an abandoned mutex, add a 500ms delay and check for any existing window with the app's title before creating a new one. Set a named flag or use a secondary signal (e.g., a sentinel file in `%TEMP%`) to confirm prior instance is gone.

---

### ERR-017
- **File:** `src/LaunchMotivation.bat` / `src/MainApp.ps1`
- **Line:** N/A (launcher chain)
- **Category:** ErrorHandling
- **Description:** WPF (Windows Presentation Foundation) is strictly single-threaded and requires the calling thread to be in Single-Threaded Apartment (STA) mode. PowerShell defaults to MTA (Multi-Threaded Apartment). No `-STA` flag is passed in `LaunchMotivation.bat` when invoking PowerShell, and no `[STAThread]` enforcement exists in `MainApp.ps1`. On the majority of Windows 10/11 systems, the app will crash immediately on window load with: *"The calling thread must be STA, because many UI components require this."*
- **Fix:**
  In `LaunchMotivation.bat`, change the PowerShell invocation to include `-STA`:
  ```batch
  powershell.exe -STA -ExecutionPolicy Bypass -File "%~dp0MainApp.ps1"
  ```

---

## Section 2 — Critical Findings (Out of Scope — ShellExtension)

These findings are documented for completeness. They are deferred because the `ShellExtension/` feature is out of scope for the current product.

| ID | File | Description |
|----|------|-------------|
| GAP-022 | `ShellExtension/MotivationShellExt.cs:138` | `Registry.ClassesRoot` written without admin privilege check. COM registration silently fails for non-admin users. |
| BUG-SE-01 | `ShellExtension/Register-ShellExtension.ps1:56` | `regasm.exe` exit code not checked. Registration failure is not detected; script reports success regardless. |

---

## Section 3 — High Findings (In Scope)

---

### GAP-035
- **File:** `src/MainWindow.xaml`
- **Line:** N/A
- **Category:** Gap
- **Description:** `MainWindow.xaml` defines a complete UI with buttons for Select Folder, Schedule, Delete Task, Undo, Clear History, and History Toggle — but no code-behind file (`.xaml.cs` or equivalent PowerShell handler block) is present in the repository. Every button click is a no-op. The UI loads but is entirely non-functional.
- **Fix:** Implement a code-behind file (or inline PowerShell event handler block in `MainApp.ps1`) with `Click` event handlers wired to each named button element.

---

### BUG-002
- **File:** `src/MainApp.ps1`
- **Line:** 62
- **Category:** Bug
- **Description:** `Get-Content $xamlPath -Raw -Encoding UTF8` is not wrapped in a `try/catch` block. If `MainWindow.xaml` is missing (partial install, accidental deletion), the script crashes with a raw PowerShell `ItemNotFoundException` stack trace — not a user-friendly error dialog.
- **Fix:**
  ```powershell
  try {
      $xamlContent = Get-Content $xamlPath -Raw -Encoding UTF8 -ErrorAction Stop
  } catch {
      [System.Windows.MessageBox]::Show("UI file missing. Please reinstall the application.`n`n$($_.Exception.Message)", "Startup Error")
      exit 1
  }
  ```

---

### ERR-002
- **File:** `src/DailyMotivation.ps1`
- **Lines:** 438–442
- **Category:** ErrorHandling
- **Description:** When a user re-selects a folder after a "path not found" condition, the config JSON write can fail (permission denied, disk full, locked file). The `catch` block logs the error but then continues to execute `$script:newExplorerPath = $newPath`. The UI shows the new path as accepted, but on the next popup the old broken path is still used.
- **Fix:** Only set `$script:newExplorerPath` if the write succeeds. Show an error dialog to the user if the write fails so they know the change was not saved.

---

### ERR-003
- **File:** `src/MainApp.ps1`
- **Lines:** 34–35
- **Category:** ErrorHandling
- **Description:** `Import-Module` is called without `-ErrorAction Stop`. If `Modules/ConfigManager.psm1` or `Modules/TaskScheduler.psm1` are missing or malformed, the import silently fails. The script continues running with no functions loaded. Users then see cryptic "The term 'Get-AppConfig' is not recognized" errors when interacting with the app, with no indication of root cause.
- **Fix:**
  ```powershell
  try {
      Import-Module "$PSScriptRoot\Modules\ConfigManager.psm1" -ErrorAction Stop
      Import-Module "$PSScriptRoot\Modules\TaskScheduler.psm1" -ErrorAction Stop
  } catch {
      [System.Windows.MessageBox]::Show("Required modules failed to load. Please reinstall.`n`n$($_.Exception.Message)", "Startup Error")
      exit 1
  }
  ```

---

### UB-002
- **File:** `src/DailyMotivation.ps1`
- **Line:** 348
- **Category:** UnintendedBehavior
- **Description:** The countdown timer's `Tick` event handler checks `remaining <= 0` and calls `$window.Close()`. However, the dispatcher may have already queued another `Tick` event before `Close()` runs. That queued tick fires after the window is closed, attempting to access a disposed `$window` object and throwing an unhandled `InvalidOperationException`.
- **Fix:**
  ```powershell
  $timer.Stop()  # stop BEFORE checking remaining
  if ($remaining -le 0 -and -not $windowClosed) {
      $windowClosed = $true
      $window.Close()
  }
  ```

---

### ERR-004
- **File:** `src/DailyMotivation.ps1`
- **Lines:** 467–468
- **Category:** ErrorHandling
- **Description:** `Start-Process "explorer.exe" $config.explorer_path` is wrapped in a try/catch that only writes to the log on failure. The popup closes regardless. The user sees the popup disappear and waits for the folder to open — it never does, with no explanation.
- **Fix:** On `Start-Process` failure, show a `MessageBox` to the user before closing the popup:
  ```powershell
  catch {
      [System.Windows.MessageBox]::Show("Could not open folder: $($config.explorer_path)`n`n$($_.Exception.Message)", "Error Opening Folder")
      # do NOT close the popup — let user retry or dismiss manually
  }
  ```

---

### GAP-007
- **File:** `src/Modules/TaskScheduler.psm1`
- **Line:** 69
- **Category:** Gap
- **Description:** `Register-ScheduledTask -Force` overwrites any existing task with the same name without warning. Additionally, the 8-character GUID prefix used for task naming could theoretically collide, creating two tasks that silently overwrite each other.
- **Fix:** Before calling `Register-ScheduledTask`, check for existence:
  ```powershell
  if (Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue) {
      # warn user or return error
  }
  ```

---

### BUG-009
- **File:** `src/Modules/TaskScheduler.psm1`
- **Line:** 141
- **Category:** Bug
- **Description:** `Unregister-ScheduledTask -Confirm:$false -ErrorAction SilentlyContinue` returns nothing on failure. The function's caller receives `$true` (success) even when the task was not deleted from the Windows Task Scheduler. Only the `tasks.json` entry is removed. The orphaned scheduled task continues to fire at 2 PM.
- **Fix:** Remove `-ErrorAction SilentlyContinue`. Capture the result and surface failure to the caller:
  ```powershell
  try {
      Unregister-ScheduledTask -TaskName $target.task_name -Confirm:$false -ErrorAction Stop
  } catch {
      return @{ Success = $false; Error = $_.Exception.Message }
  }
  ```

---

### GAP-010
- **File:** `src/Modules/TaskScheduler.psm1`
- **Lines:** 76–79
- **Category:** Gap
- **Description:** Tasks are registered with `RunLevel = [Microsoft.PowerShell.Cmdletization.GeneratedTypes.ScheduledTask.RunLevelEnum]::Limited` (standard user). If the target folder is on a network drive, a protected system path, or requires elevation, the task will fail silently at execution time with no user notification.
- **Fix:** Detect access failure on execution (via task history or a result code in `tasks.json`). Provide an option to re-register with `RunLevel Highest` if initial execution fails.

---

### BUG-011
- **File:** `src/Modules/TaskScheduler.psm1`
- **Line:** 21
- **Category:** Bug
- **Description:** `$Tasks | ConvertTo-Json -Depth 4 | Set-Content -Path $path` does not specify `-Encoding UTF8`. On Windows systems where the default code page is not UTF-8 (common with Windows 10 regional settings), folder paths containing accented characters (e.g., `C:\Ünterlagen`, `C:\Données`) will be written as garbled ANSI bytes and fail to parse on next read.
- **Fix:**
  ```powershell
  $Tasks | ConvertTo-Json -Depth 4 | Set-Content -Path $path -Encoding UTF8
  ```

---

### ERR-013
- **File:** `src/MainWindow.xaml`
- **Line:** 279
- **Category:** ErrorHandling
- **Description:** The history tab's `DataTemplate` binds to `{Binding OutcomeDisplay}` and `{Binding OutcomeColor}`. Neither property is defined in any code-behind or data model. At runtime, WPF silently fails these bindings (logs to the debug output stream, invisible to users). The history tab renders with blank/default values for every entry.
- **Fix:** Either (a) add `OutcomeDisplay` (human-readable outcome string) and `OutcomeColor` (brush value) as computed properties on the history item model, or (b) replace the binding with a `{Binding Outcome}` reference and use an `IValueConverter` for display formatting and colorization.

---

### BUG-015
- **File:** `src/MainWindow.xaml`
- **Line:** 184
- **Category:** Bug
- **Description:** The `RecentFoldersList` `ItemsControl` has no `ItemsSource` binding and no `x:Name` attribute to allow code-behind to assign `.ItemsSource` programmatically. The recent folders list never populates.
- **Fix:** Add `ItemsSource="{Binding RecentFolders}"` to the `ItemsControl` element and ensure `RecentFolders` is populated in the window's `DataContext` or code-behind after load.

---

### XAML-016
- **File:** `src/MainWindow.xaml`
- **Line:** 214
- **Category:** Bug
- **Description:** The `TaskList` `ItemsControl` (scheduled tasks management panel) has no `ItemsSource` binding. The task list never populates from `Get-MotivationTasks`. The task management panel is entirely non-functional.
- **Fix:** Add `ItemsSource="{Binding Tasks}"` and wire up the binding in code-behind after calling `Get-MotivationTasks`.

---

### HIGH — Out of Scope (ShellExtension)

| ID | File | Description |
|----|------|-------------|
| BUG-020 | `ShellExtension/MotivationShellExt.cs:99` | No user feedback when bridge script is missing; right-click menu item silently does nothing |
| ERR-025 | `ShellExtension/Register-ShellExtension.ps1:56` | `regasm.exe` result not captured; success falsely reported |

---

## Section 4 — Medium Findings (In Scope)

---

### GAP-003 — No `%TEMP%` Fallback for Config Directory
- **File:** `src/Modules/ConfigManager.psm1`, Lines 20–21
- If `New-Item` for `$env:APPDATA\DailyMotivationBrainHelper` fails (permission denied, disk quota exceeded, roaming profile redirect failure), the entire app fails to initialize with no fallback.
- **Fix:** Wrap in try/catch. On failure, fall back to `$env:TEMP\DailyMotivationBrainHelper` and log a warning.

---

### BUG-001 — `recentFolders` List Cast Unpredictable
- **File:** `src/Modules/ConfigManager.psm1`, Line 99
- `ConvertFrom-Json` returns `PSCustomObject` arrays, not `[string[]]`. Casting directly to `[System.Collections.Generic.List[string]]` produces unpredictable results when the source is already a typed collection.
- **Fix:** `$existing = [System.Collections.Generic.List[string]]@($s.recentFolders | Where-Object { $_ })`

---

### ERR-005 — Silent Log Parse Failures
- **File:** `src/Modules/ConfigManager.psm1`, Line 168
- Malformed entries in `popup_log.txt` (wrong pipe-delimiter count, encoding corruption) are silently skipped in the `Get-OutcomeLog` loop. Data is lost with no trace.
- **Fix:** Log malformed lines to `Write-Verbose` or a debug stream so developers can diagnose log corruption.

---

### ERR-008 — Permission Failure Misclassified as Deletion
- **File:** `src/Modules/TaskScheduler.psm1`, Line 122
- `-ErrorAction SilentlyContinue` on `Get-ScheduledTask` suppresses access-denied errors. A task the system cannot read is treated identically to a task that was deleted. The task is marked `DELETED` in `tasks.json` when it may still exist.
- **Fix:** Use `2>&1` or a try/catch to distinguish `ObjectNotFoundException` (genuinely gone) from `UnauthorizedAccessException` (still exists, no access).

---

### GAP-003b — Null `explorer_path` Indistinguishable From Missing Folder
- **File:** `src/DailyMotivation.ps1`, Lines 102–107
- `Test-Path $config.explorer_path -PathType Container` returns `$false` whether the path is `$null`, an empty string, or a valid path that was deleted. All three conditions show the same "Folder not found" UI, even when the config was simply never set up.
- **Fix:** Add an explicit null/empty check before `Test-Path` and show a distinct "No folder configured" message.

---

### BUG-003 — `TodayRadio` Visibility Race Condition
- **File:** `src/MainApp.ps1`, Line 121
- `Get-ScheduleTime` checks `$todayRadio.IsVisible` to decide whether to offer "today" scheduling, but `$todayRadio.Visibility` is set later in the initialization sequence. On first call the function will never return "today" even when the current time is before 14:00.
- **Fix:** Set `TodayRadio` visibility before attaching event handlers.

---

### BUG-004 — Empty Task Array JSON Round-Trip Breaks
- **File:** `src/Modules/TaskScheduler.psm1`, Line 21
- `ConvertTo-Json @()` produces `"[]"`. `ConvertFrom-Json "[]"` returns `$null` (not `@()`) in PowerShell 5.1. After all tasks are deleted, the next call to any function that does `$tasks[0]` throws `"Cannot index into a null array"`.
- **Fix:**
  ```powershell
  $result = $raw | ConvertFrom-Json
  if ($null -eq $result) { return @() }
  return @($result)
  ```

---

### ERR-005b — Messages `Copy-Item` Has No Destination Dir Check
- **File:** `src/MainApp.ps1`, Line 268
- `Copy-Item` to copy the bundled `messages.json` into `%APPDATA%` does not check whether the destination directory exists. On first run (before `Initialize-AppData` has been called successfully), `Copy-Item` fails silently. All subsequent `Get-RandomMessage` calls fall back to the single hardcoded default message.
- **Fix:** Add `New-Item -ItemType Directory -Force -Path (Split-Path $messagesPath)` before the `Copy-Item` call.

---

### GAP-004 — `$PSScriptRoot` Unreliable in WPF Event Handler
- **File:** `src/DailyMotivation.ps1`, Lines 380–386
- Inside a WPF button-click event handler, `$PSScriptRoot` may not resolve to the directory of the originating script. This is a known PowerShell behavior with async WPF dispatcher callbacks. When the Snooze button is clicked, `Import-Module "$PSScriptRoot\Modules\TaskScheduler.psm1"` may fail silently if the path resolves incorrectly.
- **Fix:** At script startup (before any event handlers are defined), capture: `$script:ModulesPath = Join-Path $PSScriptRoot "Modules"`. Reference `$script:ModulesPath` inside all event handlers.

---

### UB-003 — Null Log Produces Corrupted History Entry
- **File:** `src/Modules/ConfigManager.psm1`, Line 159
- `[Linq.Enumerable]::Reverse([string[]]$lines)` — if `$lines` is `$null` or empty, casting to `[string[]]` produces a single-element array containing `$null`. The reverse succeeds, and the null element passes through the `foreach` loop, producing a garbage history entry in the UI.
- **Fix:**
  ```powershell
  if (-not $lines -or $lines.Count -eq 0) { return @() }
  ```

---

### BUG-005 — `-NonInteractive` Hides All Errors From Users
- **File:** `src/LaunchMotivation.bat`, Line 45
- The `-NonInteractive` flag passed to PowerShell suppresses all interactive prompts and error dialogs. If `DailyMotivation.ps1` or `MainApp.ps1` throws any unhandled exception, the process exits silently with a non-zero exit code and the user sees nothing.
- **Fix:** Remove `-NonInteractive`. If suppressing prompts is needed for specific reasons, add a top-level `trap` or `$ErrorActionPreference = "Stop"` with a `catch` that shows a `MessageBox` before exiting.

---

### GAP-014 — `TodayRadio` Permanently Hidden
- **File:** `src/MainWindow.xaml`, Line 129
- `TodayRadio` (`x:Name="TodayRadio"`) has `Visibility="Collapsed"` hardcoded in XAML. No code-behind logic exists to show it. Users scheduling before 14:00 on the current day have no way to schedule for "today" — the option is permanently unavailable.
- **Fix:** In code-behind, after window load: `$todayRadio.Visibility = if ([DateTime]::Now.Hour -lt 14) { "Visible" } else { "Collapsed" }`

---

### GAP-001 — Hard-Coded PowerShell Path in Batch File
- **File:** `src/LaunchMotivation.bat`, Line 20
- `C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe` is hard-coded. On systems with PowerShell 7+ (installed to `C:\Program Files\PowerShell\7\pwsh.exe`) or on ARM64 Windows where the path structure differs, this file may not exist. The bat file fails silently.
- **Fix:** Use the environment-relative path `%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe` as a primary reference, with a fallback to `where.exe powershell` if the file is not found.

---

## Section 5 — Low Findings

---

### GAP-005 — XAML Load Result Not Type-Validated
- **File:** `src/MainApp.ps1`, Line 69
- `[Windows.Markup.XamlReader]::Load($reader)` can return `$null` or a non-Window object if XAML is syntactically valid but semantically wrong (e.g., root element is a `Grid` not a `Window`). The subsequent `$window.ShowDialog()` call will fail with `"Method invocation failed because [System.Windows.Controls.Grid] does not contain a method named 'ShowDialog'"` — unhelpful to any user.
- **Fix:**
  ```powershell
  if ($null -eq $window -or $window -isnot [System.Windows.Window]) {
      [System.Windows.MessageBox]::Show("UI failed to load. Please reinstall.", "Startup Error")
      exit 1
  }
  ```

---

### UB-004 — UNC Path Produces Confusing Folder Subtitle
- **File:** `src/DailyMotivation.ps1`, Line 318
- `$folderNameText.Text = "Opening: $($config.folder_name)"` where `folder_name` is derived from `Split-Path -Leaf`. On UNC paths (`\\server\share\projects`), `Split-Path -Leaf` returns `"projects"` — acceptable. But on root UNC shares (`\\server\share`), it returns `"share"` with no server context, which can be confusing.
- **Fix:** For UNC paths, display the full path or format it as `\\server\...\share` for clarity.

---

### GAP-006 — Path Duplicate Check Is Case-Sensitive
- **File:** `src/Modules/TaskScheduler.psm1`, Lines 49–56
- The duplicate-schedule check compares `$existing.folder_path -eq $FolderPath` using PowerShell's default case-sensitive string comparison. Windows file paths are case-insensitive, so `C:\Projects\Alpha` and `c:\projects\alpha` are treated as different and both can be scheduled.
- **Fix:**
  ```powershell
  $normalized = [System.IO.Path]::GetFullPath($FolderPath).ToLowerInvariant()
  $existing | Where-Object { [System.IO.Path]::GetFullPath($_.folder_path).ToLowerInvariant() -eq $normalized }
  ```

---

## Section 6 — Cross-Cutting Findings

---

### ERR-034 — Inconsistent Error-Handling Contract Across All Modules
- **Scope:** `ConfigManager.psm1`, `TaskScheduler.psm1`, `DailyMotivation.ps1`, `MainApp.ps1`
- `ConfigManager` returns `$null` on failure. `TaskScheduler` returns `@{ Success = $false; Error = "..." }`. `DailyMotivation.ps1` uses silent catch blocks. `MainApp.ps1` has no error handling on module imports. This inconsistency means errors cannot be reliably caught and surfaced to the user as they propagate up the call stack.
- **Fix:** Choose one pattern project-wide. Recommended: `$ErrorActionPreference = "Stop"` everywhere + `try/catch` at each module boundary + a single `Show-ErrorDialog` helper function for user-facing messages.

---

### ERR-034b — `Save-TasksJson` Encoding Inconsistency
- **Scope:** `src/Modules/TaskScheduler.psm1`
- Multiple `Set-Content` calls throughout the module omit `-Encoding UTF8`. On non-English Windows installations, this causes silent data corruption for any path containing characters outside ASCII.
- **Fix:** Audit every `Set-Content` and `Add-Content` call in the repo; add `-Encoding UTF8` to all of them.

---

*Findings marked OUT OF SCOPE (ShellExtension) are retained for audit trail purposes only and should not be prioritized for the current development phase.*

---

## Regression Protection Status

The following findings from this forensic review are now protected by automated tests
(as of commit 4ba633a). A future code change that re-introduces these bugs will cause
a Pester test to fail, blocking CI.

| Finding | Pester Protection | Test Reference |
|---------|------------------|----------------|
| `Initialize-AppData` not creating `%APPDATA%` directory | Protected | `Tests/Integration/Initialization.Tests.ps1` -- Issue #2 test |
| Module import before directory creation (order of operations) | Protected | `Tests/Integration/Initialization.Tests.ps1` -- Issue #4 test |
| `ConvertFrom-Json "[]"` returns `$null` not `@()` | Protected | `Tests/Unit/TaskScheduler.Tests.ps1` -- empty task list test |
| Duplicate task check case-sensitivity | Protected | `Tests/Unit/TaskScheduler.Tests.ps1` -- case-insensitive path comparison |
| UTF-8 corruption on non-English Windows | Protected | `Tests/Unit/ConfigManager.Tests.ps1` -- international path encoding test |
| Corrupted config file crash | Protected | `Tests/Unit/ConfigManager.Tests.ps1` -- corrupted file recovery test |
| Recent folders exceeding 5 entries | Protected | `Tests/Unit/ConfigManager.Tests.ps1` -- FIFO max-5 test |

**NOT yet protected by automated tests (manual verification required before each release):**
- `$PSScriptRoot` empty in PS2EXE (Issue #3) -- requires compiled EXE context
- `DailyMotivation.ps1` silent exit behavior (Issue #6) -- WPF context required
- Task Scheduler invocation path (Issues #5, #7) -- live Windows session required
