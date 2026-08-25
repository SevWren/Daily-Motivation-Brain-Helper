---
stepsCompleted: [1, 2, 3, 4]
inputDocuments:
  - source: GitHub Issues
  - issues: [145, 112, 111, 110, 109, 104, 157, 130]
  - branch: SevAI_installing_bmad
generatedBy: bmad-agent-pm (John) CE trigger
date: 2026-08-25
---

# Daily-Motivation-Brain-Helper - Sprint 6: Performance and Resilience

## Overview

8 issues across 2 epics: fix undo timer accumulation, eliminate
redundant I/O and regex recompilation in the hot path, harden the
Initialize-AppData tilde fallback, prevent history data loss, and
remove duplicate registry key creation.

**Sprint goal:** Eliminate the most impactful performance regressions
(double file reads, regex recompilation per loop iteration, double
task enumeration) and close three data-safety gaps.

## Epic List

1. **Epic 1: Performance and Resource Management** - Undo timer, regex,
   Sync enumeration, duplicate reads.
2. **Epic 2: Data Safety and AppData Robustness** - Tilde expansion,
   history backup, duplicate registry.

---

## Epic 1: Performance and Resource Management

### Story 1.1: Fix Undo Timer Multiple Instance Accumulation (#145)
Closes: #145 AG18-022 (Medium)
At the top of `Start-UndoTimer`, call `Stop-UndoTimer` before creating
a new DispatcherTimer. Prevents `$script:undoSeconds` being written by
two concurrent countdown instances when the user schedules tasks within
30 seconds of each other.

### Story 1.2: Pre-Compile Regex in Sync-TaskStatuses (#112)
Closes: #112 AG14-020 (Low)
Hoist `[regex]::new('^Daily Motivation Brain Helper - (.+)$')` out of
the `foreach` loop in `Sync-TaskStatuses`. Store in a local variable.
Similarly in `Get-HistoryData`, hoist the pipe-split pattern if a
compiled regex is beneficial. Linux-safe.

### Story 1.3: Eliminate Double Enumeration in Sync-TaskStatuses (#111)
Closes: #111 AG14-019 (Low)
`$knownNames` is built from `$tasks` inside a second pipeline after the
first `foreach` loop. Replace with a `[HashSet[string]]` built in the
same pass. Linux-safe.

### Story 1.4: Eliminate Duplicate Reads in New-MotivationTask (#110, #109)
Closes: #110 AG14-011 (Medium), #109 AG14-010 (Medium)
Pre-compute `$normalizedInput` once before the `Where-Object` predicate.
The current code re-calls `[System.IO.Path]::GetFullPath` and
`ToLowerInvariant` inside the pipeline for every task object on every
invocation. Also, the duplicate check already reads `Get-MotivationTasks`
once; remove the second `Get-TasksJson` call that follows immediately.
Linux-safe.

---

## Epic 2: Data Safety and AppData Robustness

### Story 2.1: Expand Tilde in Initialize-AppData Fallback (#104)
Closes: #104 AG13-021 (Medium)
When `$env:APPDATA` is absent, the fallback resolves `~` using
`$env:HOME` or `[System.Environment]::GetFolderPath('UserProfile')`.
Currently if both are absent the fallback path stays `~`, which
`Join-Path` does not expand on Windows. Add explicit expansion. Linux-safe.

### Story 2.2: Backup Before History Clear (#157)
Closes: #157 AG19-019 (Medium)
Before `Clear-Content $script:LogPath`, write a timestamped backup copy
to `$script:AppDataDir` (e.g. `popup_log_backup_YYYYMMDD_HHmmss.txt`).
Add a comment explaining the backup location to the user. Linux-safe.

### Story 2.3: Fix Duplicate Registry Key Creation in Register-ContextMenu (#130)
Closes: #130 AG17-010 (Medium)
`Register-ContextMenu` calls `New-Item -Force` for both `verbKey` and
`cmdKey` unconditionally on every Schedule. If keys already exist,
`-Force` recreates them, resetting any OS-level modifications. Guard
with `Test-Path` checks: skip `New-Item` if the key already contains
the correct value. Windows-only; static-analysis test is Linux-safe.
