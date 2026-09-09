---
stepsCompleted: [1, 2, 3, 4]
inputDocuments:
  - source: GitHub Issues
  - issues: [183, 14, 15, 19, 102]
  - mandate: CLAUDE.md WRONG 5 (catch block open violation)
  - branch: SevAI_installing_bmad
generatedBy: bmad-agent-pm (John) CE trigger
date: 2026-08-24
---

# Daily-Motivation-Brain-Helper - Sprint 5: Popup Robustness and Error Handling

## Overview

6 issues + 1 mandate fix: close #183 with regression tests, fix the open
Register-ScheduledTask catch-block mandate violation, add explorer path
pre-validation, harden Write-OutcomeLog, guard Update-TaskListUI property
access, and add explicit exception types in Sync-TaskStatuses.

**Sprint goal:** Close confirmed-fixed bug #183 with tests, satisfy the
open CLAUDE.md WRONG 5 mandate, and fix six defensive-coding gaps in
popup and scheduling code paths.

## Epic List

1. **Epic 1: Bug Closure and Mandate Fix** - #183 regression tests + WRONG 5 catch block.
2. **Epic 2: Popup and Scheduling Robustness** - Explorer pre-validation, OutcomeLog
   hardening, property-existence guards, Sync exception types.

---

## Epic 1: Bug Closure and Mandate Fix

### Story 1.1: Add BUG-1 Regression Tests for #183
Closes: #183 (partial - code fixes already in place from Sprint 4)
Add `Describe 'BUG-1: Show-PopupWindow openExplorer state preservation'` to
`Tests/Unit/FolderScheduling.Tests.ps1` asserting that:
- The Show-PopupWindow finally block does NOT assign `$script:openExplorer`
- The Open Folder button sets openExplorer=true
- Dismiss/Snooze/Exit buttons set openExplorer=false
Add structural guard to `Tests/Unit/InputValidation.Tests.ps1` asserting that:
- No `$script:openExplorer =` assignment exists in the Show-PopupWindow finally block
- openExplorer is initialized to $true before ShowDialog

### Story 1.2: Fix Register-ScheduledTask Catch Block (WRONG 5 Open Violation)
Closes: open mandate violation in CLAUDE.md WRONG 5
Replace the if/elseif/else catch block at lines 962-973 in `New-MotivationTask`
with a `switch -Regex` covering all five Windows Task Scheduler error conditions:
"Access is denied.", "requested operation requires elevation",
"logon session does not exist", "Task Scheduler service is not available",
"cannot find the file specified", plus "already exists" and a default.
Each case includes the HResult via `[0x{0:X8}]` format.
Add a static-analysis test in `Tests/Unit/TaskScheduler.Tests.ps1`.

---

## Epic 2: Popup and Scheduling Robustness

### Story 2.1: Explorer Launch Path Pre-Validation (#14)
Closes: #14 AG1-012 (Medium)
In Show-PopupWindow post-close block, wrap the `Start-Process explorer.exe`
call with a `Test-Path -LiteralPath $effectivePath -PathType Container` check.
If the path does not exist, show a MessageBox "Folder not found" instead of
silently launching Explorer to a missing path.
Add a static-analysis test in `Tests/Unit/PopupOutcome.Tests.ps1`.

### Story 2.2: Harden Write-OutcomeLog Error Handling (#15)
Closes: #15 AG1-016 (Medium)
Replace the bare `Add-Content ... -ErrorAction SilentlyContinue` in
`Write-OutcomeLog` with a try/catch that calls `Write-Warning` on failure.
Add a test asserting the try/catch is present via static source analysis.

### Story 2.3: Update-TaskListUI Property Existence Guards (#19)
Closes: #19 AG2-017 (High)
In `Update-TaskListUI`, guard `$t.task_id`, `$t.scheduled_time`, and
`$t.folder_name` with `PSObject.Properties` existence checks before
accessing them. Pass a task object with missing fields; must not throw.
Add a Linux-safe unit test in `Tests/Unit/AG7-Sprint3.Tests.ps1`.

### Story 2.4: Sync-TaskStatuses Explicit Exception Types (#102)
Closes: #102 AG13-015 (Medium)
Add `catch [System.InvalidOperationException]` and
`catch [System.Management.ManagementException]` as explicit clauses before
the generic catch in `Sync-TaskStatuses`. Both set `$t.status = "DELETED"`.
Add a static-analysis test confirming both types are caught.
