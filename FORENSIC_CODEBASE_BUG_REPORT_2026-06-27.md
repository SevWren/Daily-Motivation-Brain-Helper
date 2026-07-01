# FORENSIC CODEBASE BUG REPORT
## Daily Motivation Brain Helper — PowerShell 7 Application
### Branch: project-restart-pwsh7

---

**Original Analysis Date:** 2026-06-27
**Last Refreshed:** 2026-07-01
**Repository:** Daily-Motivation-Brain-Helper
**Primary File:** DailyMotivation.ps1 (3,089 lines as of refresh)
**Analysis Scope:** Full codebase — 20 specialized forensic agents
**Total Bugs Found:** 494
**Refresh Method:** 3x parallel review agents cross-checking each bug against current code

---

## CAMPAIGN SUMMARY (as of 2026-07-01)

| Metric | Count | % of 494 |
|--------|-------|----------|
| **RESOLVED** | 209 | 42% |
| **OPEN (actionable)** | 197 | 40% |
| **WINDOWS-ONLY** (unverifiable on Linux) | 82 | 17% |
| **NEEDS-REVIEW / N/A** | 6 | 1% |

---

## SEVERITY LEGEND

| Severity | Meaning |
|----------|---------|
| **CRITICAL** | Data loss, crash, security compromise, privilege escalation |
| **HIGH** | Functional failure in normal use, config corruption, resource leak |
| **MEDIUM** | Degraded behavior, inconsistency, poor error messaging |
| **LOW** | Code quality, maintainability, minor UX |

---

## STATUS LEGEND

| Status | Meaning |
|--------|---------|
| `RESOLVED` | Fix confirmed present in current DailyMotivation.ps1 |
| `OPEN` | Bug still exists — actionable on Linux/cross-platform |
| `WINDOWS-ONLY` | Cannot verify without WPF/Task Scheduler/Registry runtime |
| `NEEDS-REVIEW` | Partially mitigated; human review required |
| `N/A` | Bug premise no longer applies to current code |

---

## TOP OPEN CRITICAL BUGS (Immediate Action Required)

| Bug ID | Severity | Title | Notes |
|--------|----------|-------|-------|
| AG7-011 | CRITICAL | `Escape-XmlText` not applied to `$config.title`/`$config.body` | `<`/`&` in user data will crash XAML parse |
| AG7-007 | CRITICAL | `$script:openExplorer=$true` default causes Explorer launch on exception | Set before `ShowDialog()`; never reset if it throws |
| AG2-016 | HIGH | `SHA256.Create()` never disposed — handle leak per task creation | Called in `Write-OutcomeLog`; IDisposable not honored |
| AG1-013 | HIGH | `[Console]::Error.WriteLine` throws on no-console ps2exe binary | `InvalidOperationException` on final assembly-load fallback |
| AG7-005 | HIGH | Snooze race — task removed from scheduler before new task confirmed | Window open during remove+reschedule |
| AG5-011 | HIGH | `Register-ContextMenu` leaves partial registry state on failure | No rollback if second key write fails |
| AG3-004 | HIGH | `Save-TasksJson`/`Save-Config` don't verify parent dir before atomic write | `Set-Content` throws if AppData dir was deleted post-init |
| AG2-023 | HIGH | Log rotation `Clear-Content` unguarded — entries lost between copy and clear | No mutex on log file during rotation |
| AG11-001 | HIGH | No DST handling — clocks spring forward/back cause missed/double triggers | All scheduling uses local time with no UTC conversion |
| AG15-006 | MEDIUM | Log writes not atomic — interleaved entries possible on concurrent access | `Add-Content` used without file locking |

---

## SECTION-BY-SECTION BUG STATUS

### Section 1: ERROR HANDLING & EXCEPTION SAFETY
**Total: 22 | Resolved: 16 | Open: 4 | Windows-only: 2**

| Bug ID | Severity | Title | Status |
|--------|----------|-------|--------|
| AG1-001 | CRITICAL | Mutex not released on early return | RESOLVED |
| AG1-002 | HIGH | Debug log path hardcoded to `/tmp` | RESOLVED |
| AG1-003 | MEDIUM | Debug log no encoding specified | RESOLVED (minor caveat: no explicit `-Encoding UTF8`) |
| AG1-004 | HIGH | Assembly load failures silently swallowed | RESOLVED |
| AG1-005 | HIGH | `XmlNodeReader` not disposed | RESOLVED |
| AG1-006 | MEDIUM | Platform detection missing `$PSVersionTable` guard | RESOLVED |
| AG1-007 | MEDIUM | `$script:ConfigDefaults` not defined early enough | RESOLVED |
| AG1-008 | HIGH | No validation on `$Mode` param | RESOLVED |
| AG1-009 | HIGH | `$FolderPath` param allows path traversal | RESOLVED (partial — see AG1-017) |
| AG1-010 | HIGH | Mutex handle never disposed | RESOLVED |
| AG1-011 | LOW | `Write-DLog` silently drops log failures | RESOLVED (intentional) |
| AG1-012 | MEDIUM | Assembly guard flag not reset on error | RESOLVED |
| AG1-013 | HIGH | `[Console]::Error.WriteLine` throws on no-console binary | **OPEN** |
| AG1-014 | MEDIUM | `HeadlessPlatform` not guarded by `$NoRun` | RESOLVED |
| AG1-015 | MEDIUM | `$script:IsWindowsPlatform` not used to guard WPF calls | WINDOWS-ONLY |
| AG1-016 | HIGH | `Initialize-AppData` called before assemblies on setfolder path | RESOLVED |
| AG1-017 | HIGH | `[ValidateScript]` doesn't reject `..` traversal sequences | **OPEN** |
| AG1-018 | MEDIUM | `Get-ScheduledTask` errors silently swallowed in Sync | **OPEN** |
| AG1-019 | MEDIUM | `Unregister-ContextMenu` returns no error signal | **OPEN** |
| AG1-020 | MEDIUM | `$hour` variable scope in `Show-MainWindow` | RESOLVED |
| AG1-021 | MEDIUM | `Write-DLog` missing `-Encoding UTF8` on `Add-Content` | **OPEN** |
| AG1-022 | LOW | `/tmp` fallback leaves Windows-incompatible path in log name | WINDOWS-ONLY |

---

### Section 2: INPUT VALIDATION & SANITIZATION
**Total: 25 | Resolved: 20 | Open: 3 | Windows-only: 2**

| Bug ID | Severity | Title | Status |
|--------|----------|-------|--------|
| AG2-001 | HIGH | No config file size limit | RESOLVED |
| AG2-002 | MEDIUM | Config cache uses mtime only — no content hash | RESOLVED |
| AG2-003 | HIGH | `Get-Config` doesn't reset out-of-range values to defaults | RESOLVED |
| AG2-004 | CRITICAL | `Save-Config` non-atomic write | RESOLVED |
| AG2-005 | HIGH | `Get-PopupConfig` returns raw `$null` on missing file | RESOLVED |
| AG2-006 | HIGH | `Set-PopupConfig` mutex not acquired with timeout | RESOLVED |
| AG2-007 | HIGH | `Set-PopupConfig` temp file not cleaned up on failure | RESOLVED |
| AG2-008 | MEDIUM | `Set-PopupConfig` mutex name conflicts across users | RESOLVED |
| AG2-009 | LOW | `Get-Config` cache invalidation race (TOCTOU) | WINDOWS-ONLY |
| AG2-010 | MEDIUM | `Save-Config` doesn't invalidate cache | RESOLVED |
| AG2-011 | HIGH | `Get-Config` returns `$null` on missing file | RESOLVED |
| AG2-012 | MEDIUM | `Get-PopupConfig` no field-length validation on title/body/glyph | **OPEN** |
| AG2-013 | LOW | `Save-Config` doesn't validate before writing | RESOLVED |
| AG2-014 | LOW | Config defaults defined inline in multiple places | RESOLVED |
| AG2-015 | HIGH | `Write-OutcomeLog` uses non-atomic append | RESOLVED |
| AG2-016 | HIGH | `Write-OutcomeLog` SHA256 object not disposed | **OPEN** |
| AG2-017 | MEDIUM | `Get-Config` ignores `task_warning_threshold` bounds for `0` | RESOLVED |
| AG2-018 | HIGH | `Show-ErrorDialog` not guarded if WPF fails | RESOLVED |
| AG2-019 | MEDIUM | `Get-Config` `$script:ConfigCacheMTime` not thread-safe | **OPEN** |
| AG2-020 | LOW | `Set-PopupConfig` accepts empty `ExplorerPath` without warning | RESOLVED |
| AG2-021 | MEDIUM | `Get-PopupConfig` returns stale data after `Set-PopupConfig` writes | RESOLVED |
| AG2-022 | LOW | `Get-SafeErrorMessage` truncation at 500 chars | RESOLVED |
| AG2-023 | HIGH | Log rotation `Clear-Content` without file lock — entries lost | **OPEN** |
| AG2-024 | LOW | `Write-OutcomeLog` pipe-delimited format doesn't escape `\|` | RESOLVED |
| AG2-025 | LOW | Log archive cleanup uses `LastWriteTime` not `CreationTime` | RESOLVED |

---

### Section 3: STATE MANAGEMENT & RACE CONDITIONS
**Total: 25 | Resolved: 19 | Open: 4 | Windows-only: 2**

| Bug ID | Severity | Title | Status |
|--------|----------|-------|--------|
| AG3-001 | HIGH | `DispatcherTimer` in main window not stopped on window close | RESOLVED |
| AG3-002 | HIGH | `Update-HistoryUI` crashes on empty log file | RESOLVED |
| AG3-003 | HIGH | `Get-TasksJson` doesn't validate `folder_path` field | **OPEN** |
| AG3-004 | HIGH | `Save-TasksJson` parent directory not checked before write | **OPEN** |
| AG3-005 | HIGH | State vars not reset between popup invocations | RESOLVED |
| AG3-006 | HIGH | `$script:windowClosed` not reset before new popup | RESOLVED |
| AG3-007 | MEDIUM | `$script:snoozeCount` not reset | RESOLVED |
| AG3-008 | CRITICAL | `Set-PopupConfig` not atomic | RESOLVED |
| AG3-009 | CRITICAL | `Save-TasksJson` non-atomic write | RESOLVED |
| AG3-010 | MEDIUM | `Update-TaskListUI` doesn't handle `null` task list | RESOLVED |
| AG3-011 | HIGH | `Get-TasksJson` returns unwrapped single object | RESOLVED |
| AG3-012 | MEDIUM | History list datetime format throws on invalid stored dates | RESOLVED |
| AG3-013 | HIGH | Popup `DispatcherTimer` not cleaned up on window close | RESOLVED |
| AG3-014 | HIGH | Fallback opacity timer not cleaned up | RESOLVED |
| AG3-015 | HIGH | Main window `Closing` handler not hooked | RESOLVED |
| AG3-016 | CRITICAL | `Save-Config` non-atomic write (dup of AG2-004) | RESOLVED |
| AG3-017 | HIGH | `$script:undoTimer` leaks if `Start-UndoTimer` called twice | RESOLVED |
| AG3-018 | MEDIUM | `$script:newExplorerPath` not reset between invocations | RESOLVED |
| AG3-019 | MEDIUM | `$script:firstTick` not reset | RESOLVED |
| AG3-020 | MEDIUM | `Clear-Content $script:LogPath` in main window missing `-ErrorAction` | **OPEN** |
| AG3-021 | LOW | `Update-TaskListUI` date parsing `catch {}` swallows info silently | **OPEN** |
| AG3-022 | HIGH | `Write-OutcomeLog` SHA256 resource leak (dup of AG2-016) | **OPEN** |
| AG3-023 | MEDIUM | `Get-TasksJson` status normalization silently changes data | RESOLVED |
| AG3-024 | HIGH | `Save-TasksJson` doesn't create parent directory (dup of AG3-004) | **OPEN** |
| AG3-025 | LOW | Log rotation archive naming uses `Get-Date` twice (time skew) | RESOLVED |

---

### Section 4: FILE SYSTEM & PATH HANDLING
**Total: 23 | Resolved: 17 | Open: 4 | N/A: 2**

| Bug ID | Severity | Title | Status |
|--------|----------|-------|--------|
| AG4-001 | CRITICAL | Task ID collision not retried | RESOLVED |
| AG4-002 | MEDIUM | `Write-DLog` missing `-Encoding UTF8` | **OPEN** |
| AG4-013 | HIGH | `Save-TasksJson` doesn't ensure parent directory exists | **OPEN** |
| AG4-009 | MEDIUM | `Sync-TaskStatuses` swallows `Get-ScheduledTask` errors with empty catch | **OPEN** |
| AG4-003 | MEDIUM | Debug log path hardcoded to `/tmp` | RESOLVED |
| AG4-004 | HIGH | `Register-ScheduledTask` return value discarded | RESOLVED |
| AG4-005 | CRITICAL | Rollback on `Save-TasksJson` failure not attempted | RESOLVED |
| AG4-006 | HIGH | Rollback itself not verified | RESOLVED |
| AG4-007 | HIGH | `Sync-TaskStatuses` recovers path from description but description now stores hash | RESOLVED |
| AG4-008 | HIGH | `Remove-MotivationTask` doesn't check `Sync-TaskStatuses` result | RESOLVED |
| AG4-010 | HIGH | `New-MotivationTask` doesn't validate exe path exists | RESOLVED |
| AG4-011 | MEDIUM | UNC path allowed without security warning | RESOLVED |
| AG4-012 | HIGH | `New-MotivationTask` description leaks full folder path | RESOLVED |
| AG4-016 | LOW | `Clear-Content` in `Remove-MotivationTask` missing `-ErrorAction` | N/A |
| AG4-017 | HIGH | `Remove-MotivationTask` skips unregister for DELETED status | RESOLVED |
| AG4-014 | HIGH | Task trigger time not validated before registration | RESOLVED |
| AG4-015 | LOW | `$env:USERNAME` used in principal without guard | RESOLVED |
| AG4-018 | MEDIUM | Exponential backoff cap 5000ms too long in UI thread | RESOLVED |
| AG4-019 | HIGH | `New-MotivationTask` path traversal check can return multiple values | RESOLVED |
| AG4-020 | HIGH | `Sync-TaskStatuses` modifies `$tasks` while iterating | RESOLVED |
| AG4-021 | MEDIUM | `Get-ScheduledTask "DailyMotivation_*"` may match other apps | RESOLVED |
| AG4-022 | HIGH | SHA256 object not disposed (dup of AG2-016) | N/A |
| AG4-023 | HIGH | `New-MotivationTask` returns `$null` on collision exhaustion | RESOLVED |

---

### Section 5: WINDOWS TASK SCHEDULER INTEGRATION
**Total: 25 | Resolved: 16 | Open: 5 | Windows-only: 4**

| Bug ID | Severity | Title | Status |
|--------|----------|-------|--------|
| AG5-003 | MEDIUM | Registry key creation not verified post-write | **OPEN** |
| AG5-004 | MEDIUM | `Unregister-ContextMenu` returns no success/failure signal | **OPEN** |
| AG5-011 | HIGH | `Register-ContextMenu` no rollback on partial registry failure | **OPEN** |
| AG5-016 | MEDIUM | Context menu command path not hardened for special chars in exe path | **OPEN** |
| AG5-017 | MEDIUM | `Unregister-ContextMenu` key path hardcoded | WINDOWS-ONLY |
| AG5-018 | LOW | `Start-UndoTimer` `$Minutes=0` bypass if param validation skipped | **OPEN** |
| AG5-019 | LOW | `Register-ContextMenu` `Test-Path` TOCTOU — symlink swap window | OPEN (low) |
| AG5-021 | MEDIUM | `S4U` LogonType requires user logged in at registration | WINDOWS-ONLY |
| AG5-020 | LOW | Task description truncated to 16 hex chars — collision risk | RESOLVED |
| AG5-023 | MEDIUM | `Get-ScheduleTime` doesn't account for DST transitions | WINDOWS-ONLY |
| AG5-022 | HIGH | `Register-ScheduledTask` `RunLevel` not set for network paths | RESOLVED |
| AG5-024 | LOW | `Unregister-ContextMenu` doesn't log success | RESOLVED |
| AG5-001 | HIGH | `Register-ScheduledTask` return value discarded | RESOLVED |
| AG5-002 | HIGH | `Register-ContextMenu` doesn't validate exe path | RESOLVED |
| AG5-005 | HIGH | Context menu command value uses unquoted path | RESOLVED |
| AG5-006 | HIGH | `Get-ScheduleTime` returns past time for today | RESOLVED |
| AG5-007 | MEDIUM | `Start-UndoTimer` interval not validated | RESOLVED |
| AG5-008 | HIGH | `Start-UndoTimer` leaks timer on second call | RESOLVED |
| AG5-009 | HIGH | `Start-UndoTimer` progress bar update throws on disposed controls | RESOLVED |
| AG5-010 | CRITICAL | Task Scheduler uses Interactive logon type | RESOLVED |
| AG5-012 | MEDIUM | `Get-ScheduleTime` doesn't guard `$null` config | RESOLVED |
| AG5-013 | HIGH | `Start-UndoTimer` doesn't dispose on undo confirm | RESOLVED |
| AG5-014 | MEDIUM | `Get-ScheduleTime` `TodayRadioControl` can be `$null` | RESOLVED |
| AG5-015 | MEDIUM | `Start-UndoTimer` `$undoFeedbackTimer` not scoped to function | RESOLVED |
| AG5-025 | LOW | `Register-ContextMenu` `New-Item -Force` overwrites key silently | RESOLVED |

---

### Section 6: UI/WPF/DIALOG RENDERING
**Total: 25 | Resolved: 15 | Open: 3 | Windows-only: 7**

| Bug ID | Severity | Title | Status |
|--------|----------|-------|--------|
| AG6-008 | MEDIUM | `Do-Schedule` captures `$hour` before config reload (stale) | **OPEN** |
| AG6-011 | MEDIUM | `$undoBanner.Visibility` set without null-check | **OPEN** |
| AG6-022 | MEDIUM | `Do-Schedule` calls `Get-Config` but result not cached locally | **OPEN** |
| AG6-001 | HIGH | `XmlNodeReader` not disposed in `Show-MainWindow` | RESOLVED |
| AG6-002 | HIGH | `XamlReader.Load` not wrapped in try-catch | RESOLVED |
| AG6-003 | HIGH | STA thread not verified before `ShowDialog()` | RESOLVED |
| AG6-004 | HIGH | `FindName()` return value not checked for `$null` | RESOLVED |
| AG6-005 | HIGH | Window `Closing` event not hooked for cleanup | RESOLVED |
| AG6-006 | HIGH | `DispatcherTimer` brush resources not disposed on window close | RESOLVED |
| AG6-007 | MEDIUM | XAML `x:Name` attribute left on local copy | RESOLVED |
| AG6-009 | HIGH | `Invoke-FolderScheduling` not extracted from `Show-MainWindow` | RESOLVED |
| AG6-010 | HIGH | `Select-Folder` dialog not disposed | RESOLVED |
| AG6-012 | HIGH | `Update-TaskListUI` called before window is shown | RESOLVED |
| AG6-013 | LOW | `Show-MainWindow` doesn't return structured result | RESOLVED |
| AG6-014 | HIGH | `FindName()` called without null guard | RESOLVED |
| AG6-015 | HIGH | `Show-MainWindow` assembly guard missing | RESOLVED |
| AG6-016 | MEDIUM | Fallback timer interval not validated | RESOLVED |
| AG6-017 | LOW | `TodayRadio` visibility hardcoded in XAML | WINDOWS-ONLY |
| AG6-018 | LOW | `ScheduleBtn.IsEnabled` not reset after schedule | RESOLVED |
| AG6-019 | MEDIUM | `Show-MainWindow` XAML has hardcoded `x:Name="MainWin"` | RESOLVED |
| AG6-020 | HIGH | Task list removes task without confirmation | WINDOWS-ONLY |
| AG6-021 | MEDIUM | `Update-TaskListUI` array wrap not applied consistently | RESOLVED |
| AG6-023 | LOW | `Add_Closing` vs `Add_Closed` — cleanup misses in-progress animations | WINDOWS-ONLY |
| AG6-024 | HIGH | `Start-UndoTimer` called before `$undoBanner` guaranteed visible | RESOLVED |
| AG6-025 | MEDIUM | `Show-MainWindow` brush disposal list populated conditionally | RESOLVED |

---

### Section 7: CONFIGURATION & PERSISTENCE
**Total: 23 | Resolved: 13 | Open: 8 | Windows-only: 2**

| Bug ID | Severity | Title | Status |
|--------|----------|-------|--------|
| AG7-005 | HIGH | Snooze race — task removed before new task confirmed written | **OPEN** |
| AG7-007 | CRITICAL | `$script:openExplorer=$true` default causes Explorer launch on exception | **OPEN** |
| AG7-008 | HIGH | `Remove-MotivationTask` failure logged but not surfaced to user | **OPEN** |
| AG7-011 | CRITICAL | `Escape-XmlText` not applied to `$config.title`/`$config.body` | **OPEN** |
| AG7-012 | MEDIUM | `Truncate-TextForDisplay` can split UTF-16 surrogate pairs | **OPEN** |
| AG7-014 | HIGH | Entry point doesn't check `Register-ContextMenu` result in setfolder mode | **OPEN** |
| AG7-019 | HIGH | `$fallbackTimer` not disposed if `ShowDialog()` throws (exception path) | **OPEN** |
| AG7-022 | LOW | `Escape-XmlText` chained `.Replace()` allocates excessive intermediate strings | **OPEN** |
| AG7-001 | CRITICAL | Popup mutex not released on early return | RESOLVED |
| AG7-002 | CRITICAL | `Set-PopupConfig` not atomic in popup flow | RESOLVED |
| AG7-003 | HIGH | `XmlNodeReader` not disposed in `Show-PopupWindow` | RESOLVED |
| AG7-004 | HIGH | `FindName()` null return not checked in popup | RESOLVED |
| AG7-006 | MEDIUM | Session-isolated mutex name not applied | RESOLVED |
| AG7-009 | HIGH | `Show-PopupWindow` state variables reset in wrong place | RESOLVED |
| AG7-010 | HIGH | Popup `Add_Closed` timer cleanup may double-dispose | RESOLVED |
| AG7-013 | HIGH | `Strip-MarkupText` doesn't handle all XML special chars | RESOLVED |
| AG7-015 | HIGH | `Show-PopupWindow` called without STA check | RESOLVED |
| AG7-016 | LOW | `Get-RandomMessage` not seeded — same message repeated | RESOLVED |
| AG7-017 | HIGH | `Show-PopupWindow` `$config` not validated before use | RESOLVED |
| AG7-018 | HIGH | `Write-OutcomeLog` called with stale `$config.explorer_path` | RESOLVED |
| AG7-020 | LOW | Explorer launch uses `ArgumentList` without `-WorkingDirectory` | RESOLVED |
| AG7-021 | MEDIUM | Popup outcome log entry missing snooze count | RESOLVED |
| AG7-023 | LOW | `Get-RandomMessage` can return `$null` if `$Messages` empty | RESOLVED |

---

### Section 8: TEST SUITE QUALITY & COVERAGE GAPS
**Total: 27 | Resolved: 14 | Open: 13**

| Bug ID | Severity | Title | Status |
|--------|----------|-------|--------|
| AG8-005 | MEDIUM | Task ID uniqueness untested (no collision retry assertion) | **OPEN** |
| AG8-006 | MEDIUM | Registry tests skipped instead of mocked cross-platform | **OPEN** |
| AG8-007 | HIGH | Integration test missing actual integration (mode switching) | **OPEN** |
| AG8-010 | MEDIUM | Test pollution — shared `$env:APPDATA` modification | **OPEN** |
| AG8-011 | MEDIUM | Parameter validation not tested — empty strings accepted | **OPEN** |
| AG8-015 | LOW | Assertion confusion — `-Be` vs `-BeExactly` | **OPEN** |
| AG8-016 | MEDIUM | Missing cleanup — timer objects not destroyed in tests | **OPEN** |
| AG8-017 | MEDIUM | Mock without behavior — `Get-RandomMessage` not validated | **OPEN** |
| AG8-021 | MEDIUM | State leakage between tests — registry not fully cleaned | **OPEN** |
| AG8-022 | MEDIUM | False idempotency — `Register-ContextMenu` not truly tested | **OPEN** |
| AG8-023 | MEDIUM | Platform adapter tests don't mock actual failures | **OPEN** |
| AG8-024 | MEDIUM | No cross-platform path coverage (Windows paths on Linux) | **OPEN** |
| AG8-025 | LOW | Incomplete assertion — task property validation too loose | **OPEN** |
| AG8-026 | HIGH | Missing integration test — config persistence across modes | **OPEN** |
| AG8-004 | MEDIUM | `Get-ScheduledTask` mock hides real collision detection bug | RESOLVED |
| AG8-008 | HIGH | False confidence — `Should -BeNullOrEmpty` missing return value check | RESOLVED |
| AG8-009 | MEDIUM | Mock scope issue — `Get-ScheduledTask` affects all tests | RESOLVED |
| AG8-012 | HIGH | Error path not tested (happy path only) | RESOLVED |
| AG8-001 | HIGH | Mock Not Verifiable — `Register-ScheduledTask` never validated | RESOLVED |
| AG8-002 | HIGH | Corrupted JSON test missing state check | RESOLVED |
| AG8-003 | HIGH | `Unregister-ScheduledTask` mock too broad | RESOLVED |
| AG8-013 | MEDIUM | Missing edge case — very long folder paths | RESOLVED |
| AG8-014 | MEDIUM | Missing edge case — special characters in paths | RESOLVED |
| AG8-018 | HIGH | Pester version incompatibility with `Should -Be` array behavior | RESOLVED |
| AG8-019 | HIGH | `Sync-TaskStatuses` never tested | RESOLVED |
| AG8-020 | HIGH | No negative tests — duplicate detection gaps | RESOLVED |
| AG8-027 | MEDIUM | Assertion on display format hides string processing bugs | RESOLVED |

---

### Section 9: POWERSHELL BEST PRACTICES
**Total: 23 | Resolved: 11 | Open: 9 | Windows-only: 3**

| Bug ID | Severity | Title | Status |
|--------|----------|-------|--------|
| AG9-002 | LOW | Missing `[OutputType()]` declarations | **OPEN** |
| AG9-004 | MEDIUM | `$null` comparison trap — mixed left/right patterns | **OPEN** |
| AG9-005 | LOW | `.Count` access without null safety | **OPEN** |
| AG9-006 | MEDIUM | Case-sensitive `-eq` for status strings when `-ieq` needed | **OPEN** |
| AG9-009 | MEDIUM | Inline `try-catch` in type conversions — bare catch | **OPEN** |
| AG9-010 | LOW | String interpolation with complex expressions | **OPEN** |
| AG9-012 | LOW | `.PSObject.Properties` check pattern is verbose | **OPEN** |
| AG9-013 | LOW | Platform check creates dead code path (PS 5.x else branch) | **OPEN** |
| AG9-016 | MEDIUM | No `-ErrorAction Stop` on critical operations | WINDOWS-ONLY |
| AG9-018 | LOW | Switch statement missing `break`/`return` | **OPEN** |
| AG9-019 | LOW | `catch` uses `$_` without context | **OPEN** |
| AG9-020 | LOW | Inconsistent array wrapping pattern | **OPEN** |
| AG9-021 | HIGH | `DateTime` casting without validation | WINDOWS-ONLY |
| AG9-022 | MEDIUM | Event handler delegate captures variables by reference | WINDOWS-ONLY |
| AG9-001 | HIGH | Missing `[CmdletBinding()]` on advanced functions | RESOLVED |
| AG9-003 | LOW | Inconsistent null suppression (`[void]` vs `Out-Null` vs `$null=`) | RESOLVED |
| AG9-007 | MEDIUM | Backtick line continuation (fragile) | RESOLVED |
| AG9-011 | MEDIUM | Return value pollution in side-effect functions | RESOLVED |
| AG9-014 | HIGH | Mutex not properly disposed (resource leak) | RESOLVED |
| AG9-015 | LOW | `[void]` vs `Out-Null` vs `$null=` inconsistency | RESOLVED |
| AG9-017 | MEDIUM | Complex logic without comments | RESOLVED |
| AG9-008 | HIGH | Missing `[Parameter()]` attributes on required parameters | RESOLVED |
| AG9-023 | HIGH | Function parameters accept `$null` without validation | RESOLVED |

---

### Section 10: SECURITY VULNERABILITIES
**Total: 22 | Resolved: 10 | Open: 7 | Windows-only: 5**

| Bug ID | Severity | Title | Status |
|--------|----------|-------|--------|
| AG10-006 | MEDIUM | Fallback AppData directory uses fixed name in temp | **OPEN** |
| AG10-007 | MEDIUM | No certificate validation for HTTPS | **OPEN** (no feature yet) |
| AG10-008 | MEDIUM | JSON config files have no integrity protection (no HMAC/checksum) | **OPEN** |
| AG10-014 | MEDIUM | Folder path directly embedded in popup UI | **OPEN** (by design) |
| AG10-015 | MEDIUM | No signature/authenticity check on `$MyInvocation.MyCommand.Path` | **OPEN** |
| AG10-018 | LOW | Process arguments visible in Task Manager/WMI | **OPEN** (by design) |
| AG10-019 | LOW | No execution policy check before running script | **OPEN** |
| AG10-020 | LOW | No code signing certificate validation | **OPEN** |
| AG10-001 | CRITICAL | Unquoted path / code injection via registry | RESOLVED |
| AG10-002 | HIGH | Sensitive folder paths written to plaintext config files | RESOLVED |
| AG10-003 | HIGH | No validation of folder paths before registry/Task Scheduler storage | RESOLVED |
| AG10-004 | HIGH | Task Scheduler RunLevel set to "Highest" for network paths | RESOLVED |
| AG10-005 | HIGH | Debug log in world-writable temp without unique name | RESOLVED |
| AG10-009 | MEDIUM | Registry keys written without ACL configuration | WINDOWS-ONLY |
| AG10-010 | HIGH | Task Scheduler description contains user-controlled data | RESOLVED |
| AG10-011 | MEDIUM | File permissions not explicitly set on config files | WINDOWS-ONLY |
| AG10-012 | HIGH | Mutex name provides no process/user isolation | RESOLVED |
| AG10-013 | HIGH | Error messages exposed without sanitization | RESOLVED |
| AG10-016 | HIGH | Sensitive folder paths in log file | RESOLVED |
| AG10-017 | HIGH | `ConvertFrom-Json` without schema validation | RESOLVED |
| AG10-021 | HIGH | Unquoted paths in `Start-Process` command | RESOLVED |
| AG10-022 | CRITICAL | Task creation race condition — collision retry loop | RESOLVED |

---

### Section 11: SCHEDULING LOGIC & TIME HANDLING
**Total: 22 | Resolved: 5 | Open: 14 | Windows-only: 3**

| Bug ID | Severity | Title | Status |
|--------|----------|-------|--------|
| AG11-001 | CRITICAL | No timezone/DST handling — missed/double triggers | **OPEN** |
| AG11-002 | HIGH | `DateTime.Date` truncation at midnight — edge case lost | **OPEN** |
| AG11-006 | MEDIUM | Midnight crossing not detected — tomorrow logic breaks at 23:00 | **OPEN** |
| AG11-007 | HIGH | DST spring forward — hour skipped | **OPEN** |
| AG11-008 | HIGH | DST fall back — hour fires twice | **OPEN** |
| AG11-009 | MEDIUM | `DateTime` parse mismatch — different formats in different paths | **OPEN** |
| AG11-010 | HIGH | Hour comparison logic error — "already past" check broken | **OPEN** |
| AG11-012 | LOW | Undo timer seconds never reach zero — off-by-one | **OPEN** |
| AG11-013 | MEDIUM | No validation for task time window overlap | **OPEN** |
| AG11-014 | LOW | No maximum trigger count validation | **OPEN** |
| AG11-015 | MEDIUM | Snooze creates duplicate task without timestamp check | **OPEN** |
| AG11-017 | MEDIUM | Snooze duration not persisted to config | **OPEN** |
| AG11-018 | MEDIUM | `created_at` vs `scheduled_time` format inconsistency | **OPEN** |
| AG11-019 | HIGH | No handling for system clock changes | **OPEN** |
| AG11-003 | HIGH | Snooze time can schedule in past | RESOLVED |
| AG11-004 | MEDIUM | `EndBoundary` calculation off-by-minute | RESOLVED |
| AG11-005 | HIGH | No validation that `TriggerTime > current time` | RESOLVED |
| AG11-011 | HIGH | Countdown timer race — fires after window closed | RESOLVED |
| AG11-016 | CRITICAL | GUID collision retry — typo in name concatenation | RESOLVED |
| AG11-020 | HIGH | No configuration for custom trigger hours — hardcoded defaults | RESOLVED |
| AG11-021 | MEDIUM | `StartBoundary` parsing from OS task fails silently | WINDOWS-ONLY |
| AG11-022 | LOW | No handling for recurring schedule requests | WINDOWS-ONLY |

---

### Section 12: NOTIFICATION & MESSAGE DISPLAY
**Total: 26 | Resolved: 9 | Open: 14 | Windows-only: 3**

| Bug ID | Severity | Title | Status |
|--------|----------|-------|--------|
| AG12-004 | LOW | Title `MaxWidth` insufficient for localization | **OPEN** |
| AG12-007 | HIGH | Mutation of global `$timer` — race condition | WINDOWS-ONLY |
| AG12-010 | MEDIUM | No validation that message file exists before loading | **OPEN** (moot) |
| AG12-011 | LOW | No localization support — hardcoded English strings | **OPEN** |
| AG12-012 | LOW | Message selection not truly random — insufficient seed | **OPEN** (by design) |
| AG12-014 | LOW | Body text wrapping without minimum width constraint | **OPEN** |
| AG12-015 | MEDIUM | Countdown text not bound to property — manual update | **OPEN** |
| AG12-016 | MEDIUM | Snooze button timer not cancellation-safe | **OPEN** |
| AG12-017 | MEDIUM | Missing validation for extremely long folder paths in popup | **OPEN** |
| AG12-018 | LOW | No system tray icon cleanup on exit | **OPEN** (N/A — no tray) |
| AG12-021 | MEDIUM | Button click handlers don't cancel animation state | **OPEN** |
| AG12-022 | MEDIUM | DND/Focus Assist not checked before showing popup | **OPEN** |
| AG12-023 | MEDIUM | No validation that config fields are populated | **OPEN** |
| AG12-024 | LOW | Message `Glyph` property name case sensitivity undocumented | **OPEN** |
| AG12-001 | CRITICAL | XML escape not applied to folder paths in popup | RESOLVED |
| AG12-002 | HIGH | Glyph text contains unescaped Unicode entities | RESOLVED |
| AG12-003 | MEDIUM | Body text not limited — overflow causes visual corruption | RESOLVED |
| AG12-005 | HIGH | Title and body not stripped of Markdown/HTML formatting | RESOLVED |
| AG12-006 | CRITICAL | No fallback when WPF assemblies fail to load | RESOLVED |
| AG12-008 | HIGH | Mutex release not guaranteed on exception paths | RESOLVED |
| AG12-009 | HIGH | Popup window `Opacity=0` — invisible on launch | RESOLVED |
| AG12-013 | HIGH | Folder name with special chars breaks display | RESOLVED |
| AG12-019 | MEDIUM | Notification not marked "Topmost" until after show | RESOLVED |
| AG12-020 | HIGH | Config JSON parse failure returns NULL — no fallback message | RESOLVED |
| AG12-025 | MEDIUM | Folder name display not validated for empty string | RESOLVED |
| AG12-026 | HIGH | Markdown characters in title/body not escaped | RESOLVED |

---

### Section 13: PLATFORM COMPATIBILITY
**Total: 28 | Resolved: 2 | Open: 7 | Windows-only: 19**

| Bug ID | Severity | Title | Status |
|--------|----------|-------|--------|
| AG13-011 | MEDIUM | Path separator inconsistency between Windows and Unix | **OPEN** |
| AG13-012 | LOW | `$env:APPDATA` not documented for unusual Windows setups | **OPEN** |
| AG13-018 | MEDIUM | `DateTimeOffset` ISO format inconsistency between `.NET` runtimes | **OPEN** |
| AG13-028 | LOW | `build.ps1` assumes ps2exe available on any PS version | **OPEN** |
| AG13-005 | LOW | Case-insensitive path comparison not guarded | **OPEN** |
| AG13-021 | LOW | `$env:APPDATA` not set in Windows Sandbox/container | **OPEN** |
| AG13-001 | HIGH | Missing PS version guard for WPF assembly loading | RESOLVED |
| AG13-002 | HIGH | Unguarded registry access without edition check | WINDOWS-ONLY |
| AG13-003 | HIGH | Task Scheduler service not checked on all Windows editions | WINDOWS-ONLY |
| AG13-004 | MEDIUM | `.NET Framework` vs `.NET Core`: `DriveType` not available | RESOLVED |
| AG13-006 | HIGH | `MessageBox` API not available on non-Windows PS7 | WINDOWS-ONLY |
| AG13-007 | HIGH | WPF namespace not available without `PresentationFramework` | WINDOWS-ONLY |
| AG13-008 | MEDIUM | `Register-ScheduledTask` params not available on PS 5.1 | WINDOWS-ONLY |
| AG13-009 | MEDIUM | `explorer.exe` not available on Server SKUs and ARM64 | WINDOWS-ONLY |
| AG13-010 | MEDIUM | Task Scheduler XML error not handled for different Windows versions | WINDOWS-ONLY |
| AG13-013 | MEDIUM | High DPI scaling not configured for WPF window | WINDOWS-ONLY |
| AG13-014 | LOW | XAML emoji rendering not supported on all Windows versions | WINDOWS-ONLY |
| AG13-015 | MEDIUM | `CimJobException` not caught on PS 5.1 | WINDOWS-ONLY |
| AG13-016 | MEDIUM | `FolderBrowserDialog` not available in Server Core | WINDOWS-ONLY |
| AG13-017 | LOW | Mutex `Global\` prefix not available on some editions | WINDOWS-ONLY |
| AG13-019 | MEDIUM | PS class syntax not available in PS 5.0 | RESOLVED |
| AG13-020 | MEDIUM | CIM cmdlets not available without `CimCmdlets` module | WINDOWS-ONLY |
| AG13-022 | MEDIUM | XML parsing error for legacy task descriptions | WINDOWS-ONLY |
| AG13-023 | LOW | `WScript.Shell` COM not available in Server Core | WINDOWS-ONLY |
| AG13-024 | LOW | 32-bit vs 64-bit registry paths not handled | WINDOWS-ONLY |
| AG13-025 | LOW | ARM64 process execution not detected | WINDOWS-ONLY |
| AG13-026 | MEDIUM | Thread-unsafe `$script:` access in `DispatcherTimer` callbacks | WINDOWS-ONLY |
| AG13-027 | MEDIUM | STA mode requirement not enforced on PS 5.1 | WINDOWS-ONLY |

---

### Section 14: PERFORMANCE & RESOURCE LEAKS
**Total: 24 | Resolved: 10 | Open: 9 | Windows-only: 5**

| Bug ID | Severity | Title | Status |
|--------|----------|-------|--------|
| AG14-008 | MEDIUM | `Get-Process` pipeline expensive in loop context | **OPEN** |
| AG14-010 | LOW | `Where-Object` pipeline inefficiency in task lookup | **OPEN** |
| AG14-011 | MEDIUM | `Get-MotivationTasks` called multiple times with duplicate reads | **OPEN** |
| AG14-012 | MEDIUM | `Get-HistoryData` reads entire log file into memory | **OPEN** |
| AG14-013 | MEDIUM | `FileShare` not set when reading log files — potential lock | **OPEN** |
| AG14-016 | LOW | `ConvertFrom-Json`/`ConvertTo-Json` pipeline repeated | **OPEN** |
| AG14-017 | LOW | Script-scoped variables accumulate without cleanup | **OPEN** |
| AG14-018 | MEDIUM | `Get-ScheduledTask` called in loop without caching | **OPEN** |
| AG14-019 | LOW | `Sync-TaskStatuses` enumerates all tasks twice | **OPEN** |
| AG14-020 | LOW | Regex compiled multiple times in loop | **OPEN** |
| AG14-021 | LOW | String concatenation in `ForEach` loop (history parsing) | **OPEN** |
| AG14-023 | LOW | `Start-Process explorer.exe` has no timeout | **OPEN** |
| AG14-024 | LOW | `Add-Content` no encoding consistency check | **OPEN** |
| AG14-001 | HIGH | Unmanaged `FolderBrowserDialog` — not disposed | RESOLVED |
| AG14-002 | HIGH | `XmlNodeReader` not disposed | RESOLVED |
| AG14-003 | HIGH | Mutex not disposed explicitly in all paths | RESOLVED |
| AG14-004 | HIGH | `DispatcherTimer` callbacks not unregistered — memory leak | RESOLVED |
| AG14-005 | LOW | Button click handlers never unregistered | WINDOWS-ONLY |
| AG14-006 | MEDIUM | `BrushConverter` objects never disposed | RESOLVED |
| AG14-007 | LOW | `DriveInfo` not disposed | RESOLVED (N/A — value type) |
| AG14-009 | HIGH | `Get-Config` called repeatedly without caching | RESOLVED |
| AG14-014 | LOW | `MessageBox` handle leak (rooted by event handler) | WINDOWS-ONLY |
| AG14-015 | LOW | `DoubleAnimation` not disposed after `BeginAnimation` | WINDOWS-ONLY |
| AG14-022 | LOW | `Window.ShowDialog()` not properly garbage collected | WINDOWS-ONLY |

---

### Section 15: LOGGING & DIAGNOSTICS
**Total: 28 | Resolved: 5 | Open: 23**

| Bug ID | Severity | Title | Status |
|--------|----------|-------|--------|
| AG15-002 | LOW | Debug log path not configurable | **OPEN** |
| AG15-004 | MEDIUM | Missing start/end log entries for long operations | **OPEN** |
| AG15-006 | MEDIUM | Log writes not atomic — interleaved entries possible | **OPEN** |
| AG15-007 | MEDIUM | Log directory not created before first write | **OPEN** |
| AG15-008 | LOW | Incorrect log level usage — debug noise in production | **OPEN** |
| AG15-009 | LOW | `$VerbosePreference` not respected | **OPEN** |
| AG15-010 | LOW | Missing `-Debug` support | **OPEN** |
| AG15-011 | MEDIUM | Exception details not logged — no stack trace | **OPEN** |
| AG15-012 | MEDIUM | Log file not flushed on abnormal exit | **OPEN** |
| AG15-013 | LOW | Missing timestamp precision (no milliseconds) | **OPEN** |
| AG15-014 | MEDIUM | Popup config parse failure not logged with file content | **OPEN** |
| AG15-015 | LOW | No Windows Event Log entries for important events | **OPEN** |
| AG15-016 | LOW | Version/environment info not logged at startup | **OPEN** |
| AG15-017 | LOW | No structured logging — hard to parse | **OPEN** |
| AG15-018 | MEDIUM | `Sync-TaskStatuses` warnings not at ERROR level | **OPEN** |
| AG15-020 | MEDIUM | `Write-Error` not captured in log file | **OPEN** |
| AG15-021 | MEDIUM | No timeout detection for long-running operations | **OPEN** |
| AG15-022 | LOW | Mutex errors not fully captured | **OPEN** |
| AG15-023 | LOW | Explorer launch failure not fully captured | **OPEN** |
| AG15-024 | LOW | Countdown timer error logged but recovery unclear | **OPEN** |
| AG15-025 | LOW | No correlation ID for multi-step operations | **OPEN** |
| AG15-026 | LOW | No log verbosity control at runtime | **OPEN** |
| AG15-027 | LOW | Mutex release error at WARN not ERROR level | **OPEN** |
| AG15-028 | MEDIUM | Config initialization silent failures | **OPEN** |
| AG15-001 | HIGH | Log file growing without bound | RESOLVED |
| AG15-003 | HIGH | Silent failure in assembly loading — error not fully logged | RESOLVED |
| AG15-005 | HIGH | Logging sensitive data — file paths in log | RESOLVED |
| AG15-019 | MEDIUM | Silent failures in config fallback | RESOLVED |

---

### Section 16: BUILD & CI/CD PIPELINE
**Total: 22 | Resolved: 14 | Open: 8**

| Bug ID | Severity | Title | Status |
|--------|----------|-------|--------|
| AG16-003 | MEDIUM | CI only tests on Windows — no cross-platform matrix | **OPEN** |
| AG16-004 | MEDIUM | No PowerShell version matrix in CI | **OPEN** |
| AG16-012 | LOW | No artifact retention policy | **OPEN** |
| AG16-013 | MEDIUM | Code coverage not enforced as quality gate | **OPEN** |
| AG16-014 | LOW | No changelog generated | **OPEN** |
| AG16-015 | MEDIUM | PSScriptAnalyzerSettings rules too permissive | **OPEN** |
| AG16-016 | LOW | No scheduled/nightly CI runs | **OPEN** |
| AG16-019 | MEDIUM | No pre-test validation of `DailyMotivation.ps1` syntax | **OPEN** |
| AG16-020 | MEDIUM | Tests don't fail when coverage drops | **OPEN** |
| AG16-001 | HIGH | `Invoke-ps2exe` exit code not checked | RESOLVED |
| AG16-002 | HIGH | Build doesn't exit on `Invoke-ps2exe` failure | RESOLVED |
| AG16-005 | HIGH | Missing Pester version pin | RESOLVED |
| AG16-006 | HIGH | Missing PSScriptAnalyzer version pin | RESOLVED |
| AG16-007 | HIGH | Missing ps2exe version pin | RESOLVED |
| AG16-008 | HIGH | Build artifact not validated before upload | RESOLVED |
| AG16-009 | HIGH | PSScriptAnalyzer violations not blocking | RESOLVED |
| AG16-010 | HIGH | `analyze` job not required for build | RESOLVED |
| AG16-011 | MEDIUM | No smoke test after build | RESOLVED |
| AG16-017 | MEDIUM | No job timeout defined | RESOLVED |
| AG16-018 | MEDIUM | `build.ps1` doesn't support `-WhatIf` | RESOLVED |
| AG16-021 | LOW | Pester config uses relative paths | RESOLVED |
| AG16-022 | HIGH | Missing dependency validation before build | RESOLVED |

---

### Section 17: CONTEXT MENU & SYSTEM TRAY
**Total: 25 | Resolved: 1 | Open: 12 | Windows-only: 12**

| Bug ID | Severity | Title | Status |
|--------|----------|-------|--------|
| AG17-004 | LOW | `ContextMenuStrip` vs WPF `ContextMenu` confusion | **OPEN** |
| AG17-007 | HIGH | Timer not properly disposed before window close | **OPEN** |
| AG17-008 | HIGH | `FallbackTimer` also not disposed | **OPEN** |
| AG17-011 | LOW | Context menu "Exit" item missing | **OPEN** (no system tray) |
| AG17-013 | MEDIUM | No busy state indicator during long operations | **OPEN** |
| AG17-016 | LOW | Missing separator between menu item groups | **OPEN** |
| AG17-017 | MEDIUM | Keyboard accessibility missing — no access keys | **OPEN** |
| AG17-018 | LOW | No tooltip or help text on context menu items | **OPEN** |
| AG17-022 | LOW | No icon file for system tray (if implemented) | **OPEN** (N/A) |
| AG17-023 | MEDIUM | No event handler deregistration on window close | **OPEN** |
| AG17-001 | MEDIUM | Context menu registered multiple times on each main window launch | WINDOWS-ONLY |
| AG17-002 | HIGH | Context menu registration doesn't verify successful write | WINDOWS-ONLY |
| AG17-003 | HIGH | No unregister on exit or uninstall path | WINDOWS-ONLY |
| AG17-005 | MEDIUM | Menu items not disabled based on state | WINDOWS-ONLY |
| AG17-006 | HIGH | Event handlers attached multiple times on repeated window calls | WINDOWS-ONLY |
| AG17-009 | HIGH | `UndoFeedbackTimer` not disposed | RESOLVED |
| AG17-010 | MEDIUM | Duplicate registry key creation in `Register-ContextMenu` | WINDOWS-ONLY |
| AG17-012 | LOW | Popup context menu on left-click instead of right-click | WINDOWS-ONLY |
| AG17-014 | MEDIUM | Menu item state not reflected when snooze duration changes | WINDOWS-ONLY |
| AG17-015 | MEDIUM | Snooze menu not showing on first right-click (WPF race) | WINDOWS-ONLY |
| AG17-019 | MEDIUM | Snooze menu created before WPF fully initialized | WINDOWS-ONLY |
| AG17-020 | MEDIUM | Stale state — menu items not updated when popup reappears | WINDOWS-ONLY |
| AG17-021 | HIGH | Context menu events not properly scoped — closure capture | WINDOWS-ONLY |
| AG17-024 | HIGH | Popup window close race condition | WINDOWS-ONLY |
| AG17-025 | MEDIUM | Missing null checks before accessing `ContextMenu` | RESOLVED |

---

### Section 18: DATA INTEGRITY & CORRUPTION RISKS
**Total: 26 | Resolved: 8 | Open: 13 | Windows-only: 1 | Needs-Review: 4**

| Bug ID | Severity | Title | Status |
|--------|----------|-------|--------|
| AG18-004 | HIGH | Single-item array flattening in `Get-TasksJson` | **OPEN** |
| AG18-005 | MEDIUM | Encoding mismatch on config read in `Get-Config` | **OPEN** |
| AG18-006 | HIGH | No backup before destructive delete in `Remove-MotivationTask` | **OPEN** |
| AG18-007 | MEDIUM | Integer overflow in snooze duration | **OPEN** |
| AG18-008 | LOW | Float precision in countdown timer | **OPEN** |
| AG18-013 | MEDIUM | Missing checksums for data integrity verification | **OPEN** |
| AG18-014 | LOW | Data truncation risk in string fields | **OPEN** |
| AG18-016 | LOW | Sort order not deterministic in task list | **OPEN** |
| AG18-017 | HIGH | Read-modify-write without locking in snooze handler | **OPEN** |
| AG18-020 | HIGH | No validation of scheduled time (past date) | **OPEN** |
| AG18-021 | MEDIUM | Missing data migration rollback | **OPEN** |
| AG18-022 | MEDIUM | Integer overflow in undo timer countdown | **OPEN** |
| AG18-024 | MEDIUM | Time zone conversion issues in scheduled time | **OPEN** |
| AG18-001 | CRITICAL | Non-atomic config write in `Save-Config` | RESOLVED |
| AG18-002 | CRITICAL | Non-atomic popup config write in `Set-PopupConfig` | RESOLVED |
| AG18-003 | CRITICAL | Non-atomic `tasks.json` write in `Save-TasksJson` | RESOLVED |
| AG18-009 | HIGH | String-to-number conversion without error handling | RESOLVED |
| AG18-010 | HIGH | No schema validation on loaded tasks | RESOLVED |
| AG18-011 | HIGH | No referential integrity check between tasks and OS | WINDOWS-ONLY |
| AG18-012 | HIGH | Concurrent write access without locking | NEEDS-REVIEW |
| AG18-015 | HIGH | Missing deduplication on task add (race condition) | NEEDS-REVIEW |
| AG18-018 | MEDIUM | Data loss when array contains null elements | NEEDS-REVIEW |
| AG18-019 | HIGH | No rollback on partial failure in `New-MotivationTask` | NEEDS-REVIEW |
| AG18-023 | HIGH | Orphaned temp files on failure | RESOLVED |
| AG18-025 | HIGH | Missing bounds check on `task_warning_threshold` | RESOLVED |
| AG18-026 | HIGH | No validation of folder existence before fallback directory write | RESOLVED |

---

### Section 19: USER EXPERIENCE & ACCESSIBILITY
**Total: 28 | Resolved: 1 | Open: 15 | Windows-only: 12**

| Bug ID | Severity | Title | Status |
|--------|----------|-------|--------|
| AG19-001 | LOW | Schedule button disabled by default with no guidance | **OPEN** |
| AG19-002 | MEDIUM | No loading/progress indicator during task creation | **OPEN** |
| AG19-003 | MEDIUM | Error messages display raw exception stack traces | **OPEN** |
| AG19-004 | MEDIUM | No confirmation dialog before destructive delete | **OPEN** |
| AG19-005 | LOW | No first-run onboarding or setup guide | **OPEN** |
| AG19-006 | MEDIUM | Window fixed size on high-DPI displays | WINDOWS-ONLY |
| AG19-007 | LOW | No visual feedback on button hover/click | WINDOWS-ONLY |
| AG19-008 | MEDIUM | Loading state not shown while tasks are fetched | **OPEN** |
| AG19-009 | LOW | Empty state not visually distinct | **OPEN** |
| AG19-010 | HIGH | Tab order/keyboard navigation not set | RESOLVED |
| AG19-011 | MEDIUM | Screen reader support missing (`AutomationProperties.Name`) | **OPEN** |
| AG19-012 | MEDIUM | No cancel button during long-running operations | **OPEN** |
| AG19-013 | LOW | Confusing button labels and action names | **OPEN** |
| AG19-014 | LOW | No way to dismiss notification without acting | **OPEN** |
| AG19-015 | LOW | Settings changes require restart but user isn't told | **OPEN** |
| AG19-016 | MEDIUM | Popup window focus not set correctly on launch | WINDOWS-ONLY |
| AG19-017 | MEDIUM | Long operation with no cancel button (task deletion) | **OPEN** |
| AG19-018 | LOW | Countdown timer cannot be paused | **OPEN** |
| AG19-019 | MEDIUM | No undo capability for accidental operations | **OPEN** |
| AG19-020 | LOW | Status messages too brief | **OPEN** |
| AG19-021 | LOW | Drag-drop visual feedback insufficient | WINDOWS-ONLY |
| AG19-022 | MEDIUM | Error dialog content not always visible (no scroll) | **OPEN** |
| AG19-023 | MEDIUM | No progress indication during `Sync-TaskStatuses` | WINDOWS-ONLY |
| AG19-024 | LOW | Keyboard shortcuts not documented or discoverable | **OPEN** |
| AG19-025 | LOW | Countdown text color low contrast | WINDOWS-ONLY |
| AG19-026 | LOW | Window title ambiguous | **OPEN** |
| AG19-027 | LOW | No audio/visual feedback when popup appears | WINDOWS-ONLY |
| AG19-028 | LOW | History list lacks timestamps or sorting options | **OPEN** |

---

### Section 20: INTEGRATION & REGRESSION TEST GAPS
**Total: 25 | Resolved: 3 | Open: 22**

| Bug ID | Severity | Title | Status |
|--------|----------|-------|--------|
| AG20-001 | HIGH | Integration tests never validate multi-folder scheduling | RESOLVED |
| AG20-002 | MEDIUM | No test for SYSTEM account execution context | **OPEN** |
| AG20-003 | HIGH | No test for fresh machine (first run — no config) | RESOLVED |
| AG20-004 | HIGH | No test for corrupted config file | **OPEN** |
| AG20-005 | HIGH | No test for full disk (config write fails) | **OPEN** |
| AG20-006 | HIGH | No test for DST transition | **OPEN** |
| AG20-007 | MEDIUM | No test for system clock change during execution | **OPEN** |
| AG20-008 | HIGH | No test for multiple simultaneous instances (race condition) | **OPEN** |
| AG20-009 | MEDIUM | No test for script path containing spaces | **OPEN** |
| AG20-010 | LOW | No test for non-English Windows locale | **OPEN** |
| AG20-011 | HIGH | No test verifying scheduled tasks fire at correct time | **OPEN** |
| AG20-012 | HIGH | No test for upgrade path (old config schema) | **OPEN** |
| AG20-013 | MEDIUM | No test for graceful shutdown / cleanup | **OPEN** |
| AG20-014 | MEDIUM | Tests don't verify Task Scheduler state in teardown | **OPEN** |
| AG20-015 | HIGH | Tests leave real scheduled tasks on test machine | RESOLVED |
| AG20-016 | MEDIUM | Missing contract tests between config schema and code expectations | **OPEN** |
| AG20-017 | LOW | No performance regression tests | **OPEN** |
| AG20-018 | HIGH | Missing test for readonly `$env:APPDATA` | **OPEN** |
| AG20-019 | HIGH | No contract test for `tasks.json` schema | **OPEN** |
| AG20-020 | MEDIUM | Missing test for network timeout (UNC paths) | **OPEN** |
| AG20-021 | HIGH | No test for Windows Features missing (Task Scheduler disabled) | **OPEN** |
| AG20-022 | HIGH | Missing test for concurrent task status updates | **OPEN** |
| AG20-023 | MEDIUM | No test for `-NoRun` parameter robustness | **OPEN** |
| AG20-024 | MEDIUM | Missing test for regex escape in `Sync-TaskStatuses` | **OPEN** |
| AG20-025 | HIGH | No integration test for real popup display logic | **OPEN** |

---

## RESOLUTION PROGRESS BY DOMAIN

| # | Domain | Total | Resolved | Open | Win-only | % Done |
|---|--------|-------|----------|------|----------|--------|
| 1 | Error Handling & Exception Safety | 22 | 16 | 4 | 2 | 73% |
| 2 | Input Validation & Sanitization | 25 | 20 | 3 | 2 | 80% |
| 3 | State Management & Race Conditions | 25 | 19 | 4 | 2 | 76% |
| 4 | File System & Path Handling | 23 | 17 | 4 | 0 | 74% |
| 5 | Windows Task Scheduler Integration | 25 | 16 | 5 | 4 | 64% |
| 6 | UI/WPF/Dialog Rendering | 25 | 15 | 3 | 7 | 60% |
| 7 | Configuration & Persistence | 23 | 13 | 8 | 2 | 57% |
| 8 | Test Suite Quality & Coverage Gaps | 27 | 14 | 13 | 0 | 52% |
| 9 | PowerShell Best Practices | 23 | 11 | 9 | 3 | 48% |
| 10 | Security Vulnerabilities | 22 | 10 | 7 | 5 | 45% |
| 11 | Scheduling Logic & Time Handling | 22 | 5 | 14 | 3 | 23% |
| 12 | Notification & Message Display | 26 | 9 | 14 | 3 | 35% |
| 13 | Platform Compatibility | 28 | 2 | 7 | 19 | 7% |
| 14 | Performance & Resource Leaks | 24 | 10 | 9 | 5 | 42% |
| 15 | Logging & Diagnostics | 28 | 5 | 23 | 0 | 18% |
| 16 | Build & CI/CD Pipeline | 22 | 14 | 8 | 0 | 64% |
| 17 | Context Menu & System Tray | 25 | 1 | 12 | 12 | 4% |
| 18 | Data Integrity & Corruption Risks | 26 | 8 | 13 | 1 | 31% |
| 19 | User Experience & Accessibility | 28 | 1 | 15 | 12 | 4% |
| 20 | Integration & Regression Test Gaps | 25 | 3 | 22 | 0 | 12% |
| **TOTAL** | | **494** | **209** | **197** | **82** | **42%** |

---

## RECOMMENDED NEXT PRIORITIES

### Tier 1 — Fix Now (Critical/High, cross-platform, few lines)
1. **AG7-011** — Apply `Escape-XmlText` to `$config.title` and `$config.body` in `Show-PopupWindow`
2. **AG7-007** — Default `$script:openExplorer` to `$false`; set `$true` only after successful window setup
3. **AG2-016** — Dispose `SHA256` object in `Write-OutcomeLog` (wrap in `using` block or `try/finally`)
4. **AG3-004** — Add `[void](New-Item -ItemType Directory -Force (Split-Path $script:TasksPath))` guard in `Save-TasksJson`
5. **AG1-021** — Add `-Encoding UTF8` to `Write-DLog`'s `Add-Content` call (1-line fix)
6. **AG7-019** — Move `$fallbackTimer` disposal into the `finally` block, not only `Add_Closed`

### Tier 2 — Fix Soon (High, scheduling correctness)
7. **AG11-001 / AG11-007 / AG11-008** — Convert all scheduling to UTC; use `[System.TimeZoneInfo]::ConvertTimeToUtc()`
8. **AG2-023** — Add a named mutex around the log rotation copy+clear sequence
9. **AG5-011** — Add registry rollback in `Register-ContextMenu` on partial failure
10. **AG7-005** — Restructure snooze handler: create new task first, only remove old task on success

### Tier 3 — Track (Medium/Low, or broad refactors)
- AG15 (Logging) — Structured logging, stack traces, verbosity control
- AG20 (Integration tests) — DST, corrupt-config, clock-change, concurrent-access tests
- AG11 (Time handling) — DST, midnight crossing, `created_at`/`scheduled_time` format unification
- AG8 (Test gaps) — Mode-switching integration, config persistence, platform path coverage

---

*Report refreshed 2026-07-01 by 3x parallel review agents. Original 740KB report condensed to token-efficient format.*
*For full code snippets, fix implementations, and historical context see `Archive/` docs and git history.*
