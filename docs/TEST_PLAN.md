# Test Plan

**Last Updated:** 2026-06-03

## Scope
All functional requirements in PRD.md (FR-001 through FR-025).

**Automated tests** cover core module functionality (ConfigManager, TaskScheduler, initialization).
**Manual test cases** below cover end-to-end user workflows and UI interactions.

## Test Environments
- Windows 10 (build 19041+)
- Windows 11
- PowerShell 5.1

## Automated Testing

This project uses **Pester 5.x** for automated testing with **180+ tests** covering critical functionality.

### Test Suites

| Suite | Location | Coverage |
|-------|----------|----------|
| ConfigManager Unit Tests | `Tests/Unit/ConfigManager.Tests.ps1` | 100+ tests: Initialize-AppData, settings management, recent folders, popup config, outcome logging, UTF-8 encoding, error recovery |
| TaskScheduler Unit Tests | `Tests/Unit/TaskScheduler.Tests.ps1` | 80+ tests: Task CRUD operations, duplicate detection, status management, network path detection |
| Integration Tests | `Tests/Integration/Initialization.Tests.ps1` | End-to-end initialization scenarios (Issues #2-#8), module import order, error handling |

### Test Coverage
- **ConfigManager.psm1**: ~90% coverage
- **TaskScheduler.psm1**: ~85% coverage
- **Overall Target**: 80%+ coverage maintained via CI

### Running Automated Tests
```powershell
# All tests
.\Invoke-Tests.ps1

# Unit tests only
.\Invoke-Tests.ps1 -Tag Unit

# Integration tests only
.\Invoke-Tests.ps1 -Tag Integration

# CI mode (generates NUnit XML and JaCoCo coverage reports)
.\Invoke-Tests.ps1 -CI
```

See `TESTING.md` for complete testing guide.

### Continuous Integration
- All commits automatically tested via GitHub Actions (`.github/workflows/test.yml`)
- PR merges blocked if tests fail or PSScriptAnalyzer warnings exist
- Code coverage tracked (target: 80%+)
- Test results published as PR comments

### Known Gaps
- **Notification Engine (DailyMotivation.ps1)**: 0% coverage - WPF popup requires manual testing
- **UI Components (MainApp.ps1)**: WPF interactions not covered by automated tests

---

## Manual Test Cases

The following test cases require manual execution as they involve UI interaction, Windows Task Scheduler integration, and timing-dependent scenarios.

### Original Test Cases

| ID | Scenario | Expected Result |
|----|----------|----------------|
| TC-001 | Select folder via picker | Path shown in UI |
| TC-002 | Click Schedule For Tomorrow | Task created in Task Scheduler |
| TC-003 | Popup appears at 2 PM | Popup displays with correct content |
| TC-004 | Click Open Folder | Explorer opens at correct path |
| TC-005 | Click Snooze | Popup reappears after selected duration |
| TC-006 | Delete task from UI | Task removed from Task Scheduler |
| TC-007 | Countdown reaches 0 | Explorer opens automatically |
| TC-008 | Machine off at 2 PM | Popup fires on next login |
| TC-009 | Folder path no longer exists | Re-pick prompt shown |
| TC-010 | Multiple snoozes | Popup continues to reappear |
| TC-011 | Task Scheduler service disabled | User shown actionable error |

## New Test Cases

| ID | Scenario | Expected Result |
|----|----------|----------------|
| TC-012 | Second app open after scheduling | Last folder banner appears |
| TC-013 | Open app after 3 prior schedules | Recent folders list shows up to 5 entries |
| TC-014 | Open app at 13:00 | "Today at 2:00 PM" option is visible |
| TC-014b | Open app at 15:00 | "Today at 2:00 PM" option is NOT visible |
| TC-015 | Click Undo within 30s | Task deleted; banner dismissed |
| TC-015b | Wait 30s after scheduling | Banner dismisses; task persists |
| TC-016 | Schedule folder; move folder; wait for 2 PM | Re-pick prompt shown in popup |
| TC-017 | First launch | Welcome overlay shown |
| TC-017b | Second launch | Welcome overlay NOT shown |
| TC-018 | Drag folder from Explorer onto app | Path populated in UI |
| TC-019 | Select 30 min snooze; click Snooze | Popup reappears after 30 min |
| TC-020 | Click Dismiss for Today | Popup closes; no re-trigger fires |
| TC-021 | Schedule folder "ClientA" | Popup shows "Opening: ClientA" |
| TC-022 | Schedule same folder twice same day | Duplicate warning dialog appears |
| TC-022b | Click Yes on duplicate warning | Task created |
| TC-022c | Click Cancel on duplicate warning | Task NOT created |
| TC-023 | View History panel | Past outcomes displayed correctly |
| TC-024 | Hover over Schedule button | Tooltip appears within 1 second |

## Regression
All TC-001 through TC-024 must pass before any release.

## Status
> v1.1 DRAFT
