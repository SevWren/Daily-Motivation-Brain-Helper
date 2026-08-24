---
stepsCompleted: [1, 2, 3, 4]
inputDocuments:
  - source: GitHub Issues
  - issues: [142, 148, 147, 143, 136, 141, 146, 149, 115, 114, 116, 117, 118, 150]
  - branch: SevAI_installing_bmad
generatedBy: bmad-agent-pm (John) CE trigger
date: 2026-08-24
---

# Daily-Motivation-Brain-Helper - Sprint 2: Data Integrity and Logging

## Overview

14 issues decomposed into two epics targeting data corruption, concurrency races,
and broken observability. All changes are in `DailyMotivation.ps1` unless noted.

**Sprint goal:** Eliminate data-loss paths in tasks.json and config.json, fix the
logging pipeline from directory creation through write atomicity and format safety,
and stop raw exception messages reaching end users.

## Requirements Inventory

### Functional Requirements

- FR-01: Snooze handler must verify originating task exists before creating snooze task (#142)
- FR-02: Save-TasksJson and Save-Config must acquire a named mutex before writing (#148)
- FR-03: Tasks missing task_id or with UNKNOWN status must be filtered on load (#147)
- FR-04: Null elements in tasks array must be stripped before serialisation (#143)
- FR-05: Get-Config must strip BOM bytes before ConvertFrom-Json (#136)
- FR-06: Task list in UI must be sorted by scheduled_time ascending (#141)
- FR-07: scheduled_time must be stored with UTC offset or Z suffix (#146)
- FR-08: task_warning_threshold must have an upper bound guard (#149)
- FR-09: Write-OutcomeLog must create the log directory if it does not exist (#115)
- FR-10: Write-OutcomeLog must be atomic (no interleaved concurrent entries) (#114)
- FR-11: Outcome log timestamps must include millisecond precision (#116)
- FR-12: Popup config parse errors must be captured and logged, not silenced (#117)
- FR-13: Pipe characters in FolderName must be escaped in log entries (#118)
- FR-14: Error messages shown to users must pass through Get-SafeErrorMessage (#150)

### Non-Functional Requirements

- NFR-01: All mutex names must follow the existing Global\DailyMotivation* convention
- NFR-02: No new mocks of New-ScheduledTaskAction/Trigger/Settings/Principal (CLAUDE.md)
- NFR-03: Story 1.1 requires Windows 10/11 live test before closing (snooze path)
- NFR-04: Timezone change (FR-07) must not break existing tests that assert scheduled_time format

### FR Coverage Map

| FR | Epic | Story |
|---|---|---|
| FR-01 | Epic 1 | Story 1.1 |
| FR-02 | Epic 1 | Story 1.2 |
| FR-03 | Epic 1 | Story 1.3 |
| FR-04 | Epic 1 | Story 1.4 |
| FR-05 | Epic 1 | Story 1.5 |
| FR-06 | Epic 1 | Story 1.6 |
| FR-07 | Epic 1 | Story 1.7 |
| FR-08 | Epic 1 | Story 1.8 |
| FR-09 | Epic 2 | Story 2.1 |
| FR-10 | Epic 2 | Story 2.2 |
| FR-11 | Epic 2 | Story 2.3 |
| FR-12 | Epic 2 | Story 2.4 |
| FR-13 | Epic 2 | Story 2.5 |
| FR-14 | Epic 2 | Story 2.6 |

---

## Epic 1: Data Integrity and Write Safety

**Goal:** Close the eight data-corruption and race-condition gaps in the task and
config persistence layer. Story 1.1 requires Windows live validation; all others
are verifiable on Linux.

---

### Story 1.1: Fix Snooze Handler Race Condition (Zombie Tasks)

Closes: #142 AG18-017 (Critical)

As a developer,
I want the snooze button handler to verify the originating task still exists in
tasks.json before creating a replacement snooze task,
So that removing a task from another process between popup-load and snooze-click
does not create an orphaned zombie PENDING task.

**Acceptance Criteria:**

**Given** the popup is showing for task T and T is removed from tasks.json by another process before the user clicks Snooze,
**When** the snooze handler runs,
**Then** it reads tasks.json, confirms task T is absent, and exits without calling `New-MotivationTask`.

**Given** the popup is showing for task T and T still exists in tasks.json,
**When** the user clicks Snooze,
**Then** the normal snooze flow proceeds: T is removed after close and a new task is created at the snoozed time.

**Given** the snooze handler creates a new task,
**When** the new task creation is completed,
**Then** no duplicate PENDING task for the same folder and date exists in tasks.json (duplicate detection must still apply).

**Dev notes:** Location: `Show-PopupWindow` snooze click handler, lines 2642-2673. Before calling `New-MotivationTask -Force`, call `Get-MotivationTasks` and check that a task matching `$config.task_id` still has status PENDING. If not found, log a warning and abort the snooze. Must be Windows-only test per CLAUDE.md mandate (snooze path touches Register-ScheduledTask).

---

### Story 1.2: Add Write Mutex to Save-TasksJson and Save-Config

Closes: #148 AG18-012 (Medium)

As a developer,
I want Save-TasksJson and Save-Config to acquire a named mutex before writing,
So that two simultaneous scheduling processes cannot interleave reads and writes.

**Acceptance Criteria:**

**Given** `Save-TasksJson` is called,
**When** the function acquires the file write mutex,
**Then** concurrent calls from another process block until the first write completes and then succeed with a clean file.

**Given** the mutex name used in `Save-TasksJson`,
**Then** it matches the pattern `Global\DailyMotivationTasksLock` (or equivalent consistent name).

**Given** `Save-Config` is called,
**Then** it acquires a mutex named `Global\DailyMotivationConfigLock` before writing config.json, using the same acquire-write-release pattern as `Set-PopupConfig`.

**Dev notes:** `Set-PopupConfig` (around line 395-420) is the reference pattern: acquire mutex with timeout, write to temp file, rename atomically, release in `finally`. Apply the same pattern to `Save-TasksJson` and `Save-Config`. Mutex acquire timeout: 5000ms. Do not share the same mutex name across all three files -- use distinct names so writers to different files don't block each other unnecessarily.

---

### Story 1.3: Filter Invalid Tasks on Load

Closes: #147 AG18-010 (Medium)

As a developer,
I want tasks missing `task_id` or with `UNKNOWN` status to be filtered out when tasks.json is loaded,
So that downstream callers never receive task objects that would corrupt deletion or display logic.

**Acceptance Criteria:**

**Given** tasks.json contains `{"status":"PENDING"}` (no task_id field),
**When** `Get-TasksJson` or `Get-MotivationTasks` runs,
**Then** the entry is excluded from the returned collection.

**Given** tasks.json contains a task with `"status":"UNKNOWN"`,
**When** `Get-MotivationTasks` runs,
**Then** the UNKNOWN task is not returned to callers and does not appear in the task list UI.

**Given** all remaining tasks after filtering have non-empty task_id values,
**When** `Remove-MotivationTask` compares task_id values,
**Then** no NullOrEmpty task_id can match a valid TaskId parameter and cause unintended deletion.

**Dev notes:** Add filter in `Get-TasksJson` (read path): `Where-Object { -not [string]::IsNullOrEmpty($_.task_id) }`. Add filter in `Get-MotivationTasks`: exclude `status -eq 'UNKNOWN'` from results returned to callers (the raw collection can retain them for sync purposes). Add corresponding Pester tests verifiable on Linux.

---

### Story 1.4: Strip Null Elements Before Serialising Tasks

Closes: #143 AG18-018 (Medium)

As a developer,
I want `Save-TasksJson` to strip null elements from the tasks array before serialisation,
So that corrupt or partially-loaded nulls are never written as JSON `null` literals.

**Acceptance Criteria:**

**Given** `Save-TasksJson` receives a `$Tasks` array containing one or more `$null` entries,
**When** the function writes to disk,
**Then** the written JSON contains no `null` literals; only valid task objects are serialised.

**Given** `Get-TasksJson` loads tasks.json containing a JSON `null` literal in the array,
**When** the array is returned,
**Then** the null entry is excluded and the returned collection contains only non-null objects.

**Dev notes:** In `Save-TasksJson` (lines 573-590): filter before serialising -- `$Tasks = @($Tasks | Where-Object { $null -ne $_ })`. Also add the symmetric read-time guard in `Get-TasksJson` after `ConvertFrom-Json`. Pester tests verifiable on Linux (pure JSON manipulation).

---

### Story 1.5: Strip BOM Before Parsing Config File

Closes: #136 AG18-005 (High)

As a developer,
I want `Get-Config` to strip leading BOM bytes before passing content to `ConvertFrom-Json`,
So that config files written by tools that emit UTF-8-with-BOM or UTF-16LE do not silently fall back to hardcoded defaults.

**Acceptance Criteria:**

**Given** config.json has a UTF-8 BOM header (`EF BB BF`),
**When** `Get-Config` reads and parses it,
**Then** `ConvertFrom-Json` succeeds and returns the actual config values, not the hardcoded defaults.

**Given** config.json has no BOM,
**When** `Get-Config` reads it,
**Then** behaviour is identical to the current passing state (regression test).

**Dev notes:** After `Get-Content ... -Raw`, add: `$raw = $raw -replace '^\xEF\xBB\xBF',''` (UTF-8 BOM) and `$raw = $raw -replace '^\xFF\xFE',''` (UTF-16LE BOM). The PowerShell `-replace` operator works on the string representation; the BOM is best stripped at the byte level using `[System.Text.Encoding]::UTF8.GetString([System.Text.Encoding]::UTF8.GetPreamble())` comparison or simply `$raw.TrimStart([char]0xFEFF)`. Use the latter (single Unicode BOM codepoint U+FEFF). Pester tests verifiable on Linux.

---

### Story 1.6: Sort Task List by Scheduled Time

Closes: #141 AG18-016 (Medium)

As a developer,
I want `Update-TaskListUI` to sort pending tasks by `scheduled_time` ascending before binding to the list control,
So that the display order is consistent and predictable regardless of tasks.json array order.

**Acceptance Criteria:**

**Given** tasks.json contains three PENDING tasks in reverse chronological order,
**When** `Update-TaskListUI` runs,
**Then** the task list control displays them in ascending scheduled_time order (earliest first).

**Given** `Sync-TaskStatuses` appends a recovered task at the end of the array,
**When** the task list refreshes,
**Then** the recovered task appears at its correct chronological position, not at the bottom.

**Dev notes:** In `Update-TaskListUI` (lines 1003-1022): add `| Sort-Object { [datetime]$_.scheduled_time }` to the `$pending` pipeline before constructing `$displayTasks`. Guard against invalid scheduled_time with `try/catch` on the cast. Pester tests verifiable on Linux.

---

### Story 1.7: Store Scheduled Time with UTC Offset

Closes: #146 AG18-024 (High)

As a developer,
I want `New-MotivationTask` to store `scheduled_time` with a UTC offset or Z suffix,
So that the value is unambiguous across DST transitions and timezone changes.

**Acceptance Criteria:**

**Given** `New-MotivationTask` is called with a TriggerTime in the local timezone,
**When** the task is written to tasks.json,
**Then** the `scheduled_time` field is formatted as `yyyy-MM-ddTHH:mm:ssK` (includes timezone offset such as `+02:00` or `-06:00`) or as UTC with `Z` suffix.

**Given** the stored scheduled_time includes an offset,
**When** duplicate detection reads it with `([datetime]$_.scheduled_time).Date`,
**Then** duplicate detection still correctly matches tasks on the same calendar date.

**Given** existing tasks.json entries from before this fix (no offset in scheduled_time),
**When** the app loads them,
**Then** they are read without error (backward-compatible parse).

**Dev notes:** Change `$TriggerTime.ToString("yyyy-MM-ddTHH:mm:ss")` to `$TriggerTime.ToString("yyyy-MM-ddTHH:mm:ssK")`. The `K` specifier emits the local offset (`+HH:mm`) for Local DateTimeKind and `Z` for Utc. Verify that `([datetime]"2026-12-25T14:00:00+06:00").Date` still equals the correct local date in duplicate detection logic. Update TaskScheduler.Tests.ps1 raw-JSON format assertion (AG8-027 test at line 174) to match the new format. Windows gate required only if integration tests assert the stored value.

---

### Story 1.8: Add Upper Bound to task_warning_threshold

Closes: #149 AG18-025 (Low)

As a developer,
I want `Get-Config` to reject unreasonably large values for `task_warning_threshold`,
So that a manually-edited value of 999999 does not disable the warning permanently.

**Acceptance Criteria:**

**Given** config.json contains `task_warning_threshold: 999999`,
**When** `Get-Config` loads it,
**Then** the value is clamped or reset to the default (5), and the function does not propagate 999999 to callers.

**Given** config.json contains `task_warning_threshold: 20` (a reasonable non-default value),
**When** `Get-Config` loads it,
**Then** 20 is returned as-is (not clamped).

**Dev notes:** Add upper bound guard alongside the existing lower bound: `[int]$cfg.task_warning_threshold -gt 100`. Reset to default (5) on out-of-range. Define the upper bound as a constant or comment so it is self-documenting. Pester test verifiable on Linux.

---

## Epic 2: Logging and Observability

**Goal:** Fix the logging pipeline from directory creation through write atomicity,
timestamp precision, parse-error capture, and delimiter escaping. Also stop raw
exception strings reaching end users. All stories verifiable on Linux.

---

### Story 2.1: Ensure Log Directory Exists Before Writing

Closes: #115 AG15-007 (Medium)

As a developer,
I want `Write-OutcomeLog` to create the log directory if it does not exist before calling `Add-Content`,
So that the first log write after a fresh install or AppData redirect does not silently fail.

**Acceptance Criteria:**

**Given** `$script:AppDataDir` does not exist on disk,
**When** `Write-OutcomeLog` is called,
**Then** the directory is created with `New-Item -ItemType Directory -Force` before the `Add-Content` call, and the entry is written successfully.

**Given** the directory already exists,
**When** `Write-OutcomeLog` is called,
**Then** no error is thrown and the entry is written normally (regression test).

**Dev notes:** Add `if (-not (Test-Path (Split-Path $script:LogPath -Parent))) { New-Item -ItemType Directory -Path (Split-Path $script:LogPath -Parent) -Force | Out-Null }` at the top of `Write-OutcomeLog`, before any content write.

---

### Story 2.2: Make Log Writes Atomic

Closes: #114 AG15-006 (Medium)

As a developer,
I want `Write-OutcomeLog` to acquire a named mutex before appending to the log file,
So that concurrent popup instances cannot interleave their log entries.

**Acceptance Criteria:**

**Given** two popup instances call `Write-OutcomeLog` simultaneously with different entries,
**When** both writes complete,
**Then** the log file contains two complete, non-interleaved pipe-delimited entries on separate lines.

**Given** the log mutex is named,
**Then** it follows the pattern `Global\DailyMotivationLogLock`.

**Dev notes:** Apply the same mutex acquire/release pattern used in `Set-PopupConfig`. Because `Write-OutcomeLog` appends rather than overwrites, a simpler pattern is acceptable: acquire mutex, `Add-Content`, release in `finally`. The temp-file-rename pattern is not required for appends. Mutex timeout: 2000ms (log writes are lower priority than config writes); if mutex acquisition times out, write anyway (best-effort logging is acceptable over dropped entries).

---

### Story 2.3: Add Millisecond Precision to Outcome Log Timestamps

Closes: #116 AG15-013 (Medium)

As a developer,
I want `Write-OutcomeLog` timestamps to include milliseconds,
So that multiple snooze cycles within the same second produce distinguishable log entries.

**Acceptance Criteria:**

**Given** two log entries are written within the same second,
**When** the log is read,
**Then** their timestamps differ at the millisecond level (e.g., `2026-08-24 14:00:00.123` vs `2026-08-24 14:00:00.456`).

**Given** the timestamp format changes,
**When** existing log-reader code parses the history panel (if any),
**Then** it does not crash (backward compatibility check).

**Dev notes:** Change `Get-Date -Format "yyyy-MM-dd HH:mm:ss"` to `Get-Date -Format "yyyy-MM-dd HH:mm:ss.fff"`. Verify the History Panel display logic (if it parses the timestamp) handles the new format or displays it as a raw string without crashing.

---

### Story 2.4: Log Popup Config Parse Failures

Closes: #117 AG15-014 (Medium)

As a developer,
I want the `catch {}` block around `ConvertFrom-Json` in `Show-PopupWindow` to capture and log the parse error,
So that a corrupt popup_config.json produces a diagnostic entry rather than silently falling back to defaults.

**Acceptance Criteria:**

**Given** popup_config.json contains invalid JSON,
**When** `Show-PopupWindow` tries to parse it,
**Then** the catch block writes a warning to a debug log file (e.g., `popup_debug.txt` in AppDataDir) including the file path and the exception message.

**Given** popup_config.json is valid,
**When** `Show-PopupWindow` parses it,
**Then** no debug log entry is written (no noise on the happy path).

**Dev notes:** Replace `catch {}` (line ~2432) with a block that calls `Add-Content` on `popup_debug.txt` (the same debug log already used elsewhere in `Show-PopupWindow`, see line ~2855). Format: `"[timestamp] popup_config.json parse failed: $($_.Exception.Message)"`. Use `-ErrorAction SilentlyContinue` on the debug write so a secondary failure does not surface.

---

### Story 2.5: Escape Pipe Characters in Log Entries

Closes: #118 AG15-017 (Medium)

As a developer,
I want `Write-OutcomeLog` to escape pipe characters in the `FolderName` field before building the log entry,
So that folder names containing `|` do not corrupt the pipe-delimited log format.

**Acceptance Criteria:**

**Given** a folder named `C:\Work|Personal\Projects` is scheduled and an outcome is logged,
**When** the log entry is written,
**Then** the pipe character in the folder name is escaped (e.g., replaced with `\|` or `[PIPE]`) so the entry parses as exactly 6 fields.

**Given** a folder name with no pipe characters,
**When** the log entry is written,
**Then** the entry is identical to the current format (regression test).

**Dev notes:** In `Write-OutcomeLog`, before building `$entry`: `$safeFolderName = $FolderName -replace '\|', '[PIPE]'`. This matches the existing path-hash privacy approach (the path is hashed; the folder name is display-only). Document the escape convention in a comment. If the History Panel parses the log, verify it handles `[PIPE]` in FolderName correctly.

---

### Story 2.6: Route All User-Facing Errors Through Get-SafeErrorMessage

Closes: #150 AG19-003 (Medium)

As a developer,
I want the `Do-Schedule` error display path to call `Get-SafeErrorMessage` before showing the error in a MessageBox,
So that raw exception objects and stack traces are never shown to end users.

**Acceptance Criteria:**

**Given** `Invoke-FolderScheduling` returns a result with `.Error` set to a raw exception string containing a stack trace,
**When** `Do-Schedule` shows the error MessageBox,
**Then** the displayed message is the sanitized output of `Get-SafeErrorMessage`, not the raw string.

**Given** `Get-SafeErrorMessage` is passed a short, clean error string (no stack trace),
**When** the MessageBox is shown,
**Then** the displayed message is the clean string unchanged (no unnecessary truncation).

**Dev notes:** In `Show-MainWindow` `Do-Schedule` function (~line 1844-1846): change `[void][System.Windows.MessageBox]::Show($result.Error, ...)` to `[void][System.Windows.MessageBox]::Show((Get-SafeErrorMessage $result.Error), ...)`. `Get-SafeErrorMessage` already exists and is used correctly elsewhere; this is a single-line fix. Write a Pester test verifiable on Linux that asserts `Do-Schedule` (or the equivalent code path) calls `Get-SafeErrorMessage` when `.Error` is non-null.
