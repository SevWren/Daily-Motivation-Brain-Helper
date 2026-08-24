---
stepsCompleted: [1, 2, 3, 4]
inputDocuments:
  - source: GitHub Issues
  - issues: [33, 22, 24, 23, 29, 30, 32, 31, 28, 27, 26, 25]
  - branch: SevAI_installing_bmad
generatedBy: bmad-agent-pm (John) CE trigger
date: 2026-08-24
---

# Daily-Motivation-Brain-Helper - Sprint 4: Concurrency and Task Registration

## Overview

12 issues: 4 concurrency/race conditions, 8 task-registration and defensive-coding fixes.
Epic 1 is purely cross-platform (Linux-safe). Epic 2 has Windows-only stories (Task Scheduler).

**Sprint goal:** Eliminate all remaining read-modify-write races on tasks.json, add task
existence verification after registration, and close all remaining small defensive-coding gaps.

## Epic List

1. **Epic 1: Concurrency Fixes** - Atomic RMW for tasks.json; stale popup state reset.
2. **Epic 2: Task Registration and Defensive Coding** - Verify, retry settings, UNC fix, guards.

---

## Epic 1: Concurrency Fixes

### Story 1.1: Make New-MotivationTask and Remove-MotivationTask Atomic (RMW)
Closes: #33 AG5-016 (Critical), #22 AG3-010 (High)
Acquire `Global\DailyMotivationScheduleLock` (a new outer lock, distinct from the inner
`DailyMotivationTasksLock` in Save-TasksJson) before the duplicate check in New-MotivationTask
and before Get-TasksJson in Remove-MotivationTask. Release in finally. This prevents two
simultaneous scheduling attempts from both passing the duplicate check.

### Story 1.2: Make Sync-TaskStatuses Atomic
Closes: #24 AG3-021 (High)
Acquire `Global\DailyMotivationScheduleLock` before Get-TasksJson in Sync-TaskStatuses and
release after Save-TasksJson (only on the $changed path). No-op if platform adapter is active.

### Story 1.3: Reset Popup State Flags at Show-PopupWindow Entry
Closes: #23 AG3-019 (Medium)
Add explicit reset of $script:windowClosed, $script:openExplorer, $script:snoozeCount,
$script:snoozeMinutes, $script:remaining, $script:timerPaused, and $script:newExplorerPath
at the top of Show-PopupWindow (before mutex acquisition) to prevent stale values from a
prior invocation influencing a second popup session.

---

## Epic 2: Task Registration and Defensive Coding

### Story 2.1: Verify Task Exists After Register-ScheduledTask
Closes: #29 AG5-001 (High), #30 AG5-002 (High)
After Register-ScheduledTask succeeds, call Get-ScheduledTask to confirm the task is actually
present in the OS. If Get-ScheduledTask fails or returns null, roll back (Unregister +
remove from JSON) and return an error. This catches silent no-ops from corrupted registration.

### Story 2.2: Add Restart Settings to New-ScheduledTaskSettingsSet
Closes: #32 AG5-011 (High)
Add `-RestartCount 1 -RestartInterval (New-TimeSpan -Minutes 1)` to the settingsParams
hashtable so the OS retries the popup once if it fails to launch.

### Story 2.3: Fix UNC Regex and Guard DriveType for Non-Windows
Closes: #31 AG5-009 (Medium)
Extend UNC regex to cover extended-length UNC paths (`\\?\UNC\`). Guard the DriveInfo/DriveType
check with `$IsWindows` so it never runs on Linux (where DriveType always returns Unknown).

### Story 2.4: Guard Split-Path Leaf for Empty Result in Sync-TaskStatuses
Closes: #28 AG4-023 (Medium)
When `Split-Path -Leaf $folderPath` returns empty (UNC root with no sub-path), fall back to
using $folderPath itself as the display name.

### Story 2.5: Add Windows Platform Check to Register-ContextMenu
Closes: #27 AG4-021 (Medium)
Add `if (-not $IsWindows) { return @{ Success = $false; Reason = 'Registry not available on this platform' } }`
at the top of Register-ContextMenu. Registry HKCU: access is Windows-only.

### Story 2.6: Add -Path Parameter to Clear-Content in History Clear Handler
Closes: #26 AG4-016 (Medium)
Change `Clear-Content $script:LogPath` to `Clear-Content -Path $script:LogPath` to
eliminate ambiguity when path contains special characters.

### Story 2.7: Validate $script:TempDir After Initialization
Closes: #25 AG4-003 (Medium)
After the $script:TempDir assignment at script-level initialization, verify the path exists
and is accessible; fall back to [System.IO.Path]::GetTempPath() if not.
