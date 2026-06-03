# Product Requirements Document (PRD)

**Last Updated:** 2026-06-03
**Version:** 1.1 — updated for approved brainstorm features B-01 through B-19

---

## FR-001 — Folder Selection
The system shall provide a native Windows folder picker dialog for folder selection.

## FR-002 — Folder Path Storage
The system shall persist the selected folder path in a local configuration file without requiring user interaction with that file.

## FR-003 — Task Creation
The system shall create a Windows Scheduled Task upon folder selection confirmation.

## FR-004 — Scheduling Time
The system shall schedule the task for 2:00 PM on the following calendar day by default.

## FR-005 — Motivational Popup Display
The system shall display a popup containing a motivational message at the scheduled time.

## FR-006 — Popup Acceptance
The system shall provide an "Open Folder" button that dismisses the popup and opens Windows Explorer.

## FR-007 — Popup Snooze
The system shall provide a "Snooze" split-button that dismisses the popup temporarily.
**Updated (B-10):** The snooze split-button shall offer duration options: 5 min (default), 15 min, 30 min, 1 hour.

## FR-008 — Snooze Repeat Interval
The system shall reschedule the popup to reappear after the user-selected snooze duration.
**Updated (B-10):** Duration is selected per snooze action; default is 5 minutes.

## FR-009 — Windows Explorer Launch
The system shall launch Windows Explorer pointed at the scheduled folder path upon acceptance.

## FR-010 — Folder Opening Confirmation
The system shall open the folder directly in Explorer without additional user steps.

## FR-011 — Task Deletion
The system shall allow users to delete scheduled tasks via the main UI.

## FR-012 — Message Management
The system shall display a default library of motivational messages. Custom add/edit/delete deferred to v1.1.

## FR-013 — Remember Last Folder (B-01)
The system shall persist the most recently scheduled folder path. On subsequent launches, the app shall display a one-click banner: "Schedule same folder as last time? [Yes, Schedule] [Choose Different]"

## FR-014 — Recent Folders List (B-02)
The system shall maintain a list of up to 5 recently scheduled folders. Each entry shall be displayed with a "Schedule Again" button.

## FR-015 — Schedule For Today (B-03)
When current local time is before 14:00, the system shall offer "Today at 2:00 PM" as a scheduling option alongside "Tomorrow at 2:00 PM".

## FR-016 — Undo Schedule (B-04)
After a successful task creation, the system shall display an undo banner for 30 seconds with an [Undo] button and countdown. Clicking [Undo] shall delete the task and restore the UI.

## FR-017 — Moved Folder Re-Pick Prompt (B-05)
At popup time, if the scheduled folder path is invalid, the popup shall transform to show: "This folder was moved or deleted." with [Choose New Location] and [Dismiss] buttons.

## FR-018 — First-Run Welcome Screen (B-07)
On first launch, the system shall display a fullscreen onboarding overlay explaining Pick Folder → Schedule → Opens at 2 PM. Dismissed by "Got it" and never shown again.

## FR-019 — Drag-and-Drop Folder Selection (B-09)
The main window shall accept folders dragged from Windows Explorer and treat them as if selected via the picker dialog.

## FR-020 — Dismiss for Today (B-11)
The popup shall provide a "Dismiss for Today" button that cancels all snooze re-triggers for the current task without opening the folder.

## FR-021 — Show Folder Name in Popup (B-12)
The popup shall display the scheduled folder's leaf name as a subtitle: "Opening: [FolderName]"

## FR-022 — Windows Explorer Shell Extension (B-13)
The system shall provide an optional shell extension adding "Schedule for Tomorrow at 2 PM" to the Explorer right-click context menu on folders.

## FR-023 — Duplicate Schedule Warning (B-16)
Before creating a new task, the system shall check for an existing task with the same folder and date. If found, show a confirmation dialog before proceeding.

## FR-024 — Task History / Outcome Log Viewer (B-18)
The main window shall include a History panel showing past task outcomes: Date, Folder Name, Outcome (Opened / Snoozed N times / Dismissed / Missed), newest first, max 30 entries.

## FR-025 — Tooltips on All UI Controls (B-19)
Every interactive control shall have a plain-English ToolTip with no technical jargon.

## Status
> v1.1 DRAFT

---

## Requirements Validation Matrix

This matrix links requirements to automated test coverage (as of commit 4ba633a).
"Validated" means a Pester test exercises the described behavior. "Manual only" means
the requirement is validated by manual test cases in `docs/TEST_PLAN.md`.

| FR | Requirement Summary | Automated Coverage | Test Reference |
|----|--------------------|--------------------|----------------|
| FR-002 | Schedule a folder for tomorrow at 2 PM | Validated | `Tests/Unit/TaskScheduler.Tests.ps1` -- task creation, trigger time |
| FR-003 | Duplicate schedule warning | Validated | `Tests/Unit/TaskScheduler.Tests.ps1` -- duplicate detection (case-insensitive, Force flag) |
| FR-011 | Persist settings across launches | Validated | `Tests/Unit/ConfigManager.Tests.ps1` -- settings get/save |
| FR-013 | Remember last 5 folders (FIFO) | Validated | `Tests/Unit/ConfigManager.Tests.ps1` -- FIFO, dedup, max-5 cap |
| FR-014 | Log popup outcomes | Validated | `Tests/Unit/ConfigManager.Tests.ps1` -- write/read/clear/parse |
| FR-015 | UTF-8 encoding for all paths | Validated | `Tests/Unit/ConfigManager.Tests.ps1` -- international paths, emoji glyphs |
| FR-018 | Recover gracefully from corrupted config | Validated | `Tests/Unit/ConfigManager.Tests.ps1` -- corrupted file fallback |
| FR-023 | Task status state machine | Validated | `Tests/Unit/TaskScheduler.Tests.ps1` -- all 5 status values |
| FR-024 | Network path detection | Validated | `Tests/Unit/TaskScheduler.Tests.ps1` -- UNC path detection |
| FR-001 | Folder picker dialog | Manual only | TC-001 |
| FR-004 | Drag-and-drop folder | Manual only | TC-018 |
| FR-005 | Schedule today option (before 2 PM) | Manual only | TC-014 |
| FR-006 | Undo schedule (30s grace period) | Manual only | TC-015 |
| FR-007 | First-run welcome screen | Manual only | TC-017 |
| FR-008 | Remember last folder banner | Manual only | TC-012 |
| FR-009 | Recent folders list | Manual only | TC-013 |
| FR-010 | Snooze duration choice | Manual only | TC-019 |
| FR-012 | Popup display at scheduled time | Manual only | TC-003 |
| FR-016 | Open folder via Explorer | Manual only | TC-004 |
| FR-017 | Moved folder re-pick prompt | Manual only | TC-016 |
| FR-019 | Dismiss for Today | Manual only | TC-020 |
| FR-020 | Task history viewer | Manual only | TC-023 |
| FR-021 | Tooltips on all controls | Manual only | TC-024 |
| FR-022 | Named mutex (single popup) | Manual only | SSOT-006 manual verification |
| FR-025 | Shell extension right-click | Manual only | Manual install + context menu check |

**Coverage summary:** 9/25 requirements (36%) have automated Pester validation.
The unvalidated requirements are UI-driven and require a live Windows WPF session to test.
