# Traceability Matrix

**Last Updated:** 2026-06-03
**Last Reviewed**: 2026-06-09

## Original Requirements

| User Need | Requirement | Component | Acceptance Criteria | Test Case |
|-----------|-------------|-----------|--------------------|-----------| 
| Open folder tomorrow | FR-001–004 | Folder Picker, Task Scheduler | AC-001 | TC-001, TC-002 |
| Motivational popup | FR-005 | Notification Engine | AC-002 | TC-003 |
| Accept popup | FR-006, FR-009–010 | Notification Engine, Explorer Launcher | AC-003 | TC-004 |
| Snooze popup | FR-007–008 | Snooze Engine | AC-004 | TC-005, TC-010 |
| View tasks | — | Task Manager UI | — | — |
| Delete task | FR-011 | Task Scheduler Module | AC-005 | TC-006 |
| No file editing | FR-002 | Config Manager | AC-006 | — |

## New Requirements (B-01 through B-19)

| User Story | Requirement | Component | Acceptance Criteria | Test Case |
|-----------|-------------|-----------|--------------------|-----------| 
| US-008 (B-01) | FR-013 | Config Manager | AC-007 | TC-012 |
| US-009 (B-02) | FR-014 | Config Manager, Task Manager UI | — | TC-013 |
| US-010 (B-03) | FR-015 | Task Scheduler Module | AC-008 | TC-014 |
| US-011 (B-04) | FR-016 | Main Window | AC-009 | TC-015 |
| US-012 (B-05) | FR-017 | Notification Engine | AC-010 | TC-016 |
| US-013 (B-07) | FR-018 | Main Window | AC-011 | TC-017 |
| US-014 (B-09) | FR-019 | Folder Picker Module | AC-012 | TC-018 |
| US-004 updated (B-10) | FR-007–008 | Snooze Engine | AC-013 | TC-019 |
| US-015 (B-11) | FR-020 | Notification Engine | AC-014 | TC-020 |
| — (B-12) | FR-021 | Notification Engine | AC-015 | TC-021 |
| US-016 (B-13) | FR-022 | Shell Extension | — | — |
| — (B-16) | FR-023 | Task Scheduler Module | AC-016 | TC-022 |
| US-017 (B-18) | FR-024 | History Viewer | AC-017 | TC-023 |
| US-018 (B-19) | FR-025 | Main Window | AC-018 | TC-024 |

## Coverage Notes
- Rows with `—` in Acceptance Criteria or Test Case columns indicate gaps to be filled before release
- Shell Extension (B-13) AC and TC to be added when implementation is complete

## Status
> v1.1 DRAFT

---

## Module-Level Test Coverage Traceability

| Module | Functionality | Test File | Coverage |
|--------|--------------|-----------|----------|
| `ConfigManager.psm1` | `Initialize-AppData` directory creation | `Tests/Unit/ConfigManager.Tests.ps1` | ~90% |
| `ConfigManager.psm1` | Settings management (get/set/firstRun/lastFolder) | `Tests/Unit/ConfigManager.Tests.ps1` | ~90% |
| `ConfigManager.psm1` | Recent folders (FIFO, dedup, 5-item limit) | `Tests/Unit/ConfigManager.Tests.ps1` | ~90% |
| `ConfigManager.psm1` | Popup config (all 6 fields) | `Tests/Unit/ConfigManager.Tests.ps1` | ~90% |
| `ConfigManager.psm1` | Outcome log (write/read/parse/clear) | `Tests/Unit/ConfigManager.Tests.ps1` | ~90% |
| `ConfigManager.psm1` | UTF-8 encoding | `Tests/Unit/ConfigManager.Tests.ps1` | ~90% |
| `ConfigManager.psm1` | Corrupted file recovery | `Tests/Unit/ConfigManager.Tests.ps1` | ~90% |
| `TaskScheduler.psm1` | Task creation (IDs, timestamps, JSON) | `Tests/Unit/TaskScheduler.Tests.ps1` | ~85% |
| `TaskScheduler.psm1` | Duplicate detection (B-16) | `Tests/Unit/TaskScheduler.Tests.ps1` | ~85% |
| `TaskScheduler.psm1` | Task retrieval and cross-checking | `Tests/Unit/TaskScheduler.Tests.ps1` | ~85% |
| `TaskScheduler.psm1` | Task deletion (best-effort) | `Tests/Unit/TaskScheduler.Tests.ps1` | ~85% |
| `TaskScheduler.psm1` | Status updates (all 5 values) | `Tests/Unit/TaskScheduler.Tests.ps1` | ~85% |
| `TaskScheduler.psm1` | Network path detection (UNC) | `Tests/Unit/TaskScheduler.Tests.ps1` | ~85% |
| `DailyMotivation.ps1` | WPF popup display, state machine, buttons | None | **0% -- manual only** |
| `MainApp.ps1` | WPF window, event handlers, UI interaction | None | **0% -- manual only** |
