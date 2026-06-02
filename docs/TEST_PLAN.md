# Test Plan

## Scope
All functional requirements defined in PRD.md.

## Test Environments
- Windows 10 (build 19041+)
- Windows 11
- PowerShell 5.1

## Test Categories

### Manual UI Tests
| ID | Scenario | Expected Result |
|----|----------|----------------|
| TC-001 | Select folder via picker | Path shown in UI |
| TC-002 | Click Schedule For Tomorrow | Task created in Task Scheduler |
| TC-003 | Popup appears at 2 PM | Popup displays with correct content |
| TC-004 | Click Open Folder | Explorer opens at correct path |
| TC-005 | Click Snooze | Popup reappears in 5 minutes |
| TC-006 | Delete task from UI | Task removed from Task Scheduler |
| TC-007 | Countdown reaches 0 | Explorer opens automatically |

### Edge Cases
| ID | Scenario | Expected Result |
|----|----------|----------------|
| TC-008 | Machine off at 2 PM | Popup fires on next login |
| TC-009 | Folder path no longer exists | Graceful error message |
| TC-010 | Multiple snoozes | Popup continues to reappear |
| TC-011 | Task Scheduler service disabled | User shown actionable error |

## Regression
All TC-00x tests must pass before any release.

## Status
> DRAFT
