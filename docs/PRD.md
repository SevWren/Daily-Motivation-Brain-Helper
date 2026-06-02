# Product Requirements Document (PRD)

## FR-001 — Folder Selection
The system shall provide a native Windows folder picker dialog for folder selection.

## FR-002 — Folder Path Storage
The system shall persist the selected folder path in a local configuration file without requiring user interaction with that file.

## FR-003 — Task Creation
The system shall create a Windows Scheduled Task upon folder selection confirmation.

## FR-004 — Scheduling Time
The system shall schedule the task for 2:00 PM on the following calendar day.

## FR-005 — Motivational Popup Display
The system shall display a popup containing a motivational message at the scheduled time.

## FR-006 — Popup Acceptance
The system shall provide an "Open Folder" button that dismisses the popup and opens Windows Explorer.

## FR-007 — Popup Snooze
The system shall provide a "Snooze" button that dismisses the popup temporarily.

## FR-008 — Snooze Repeat Interval
The system shall reschedule the popup to reappear exactly 5 minutes after snooze is activated.

## FR-009 — Windows Explorer Launch
The system shall launch Windows Explorer pointed at the scheduled folder path upon acceptance.

## FR-010 — Folder Opening Confirmation
The system shall open the folder directly in Explorer without additional user steps.

## FR-011 — Task Deletion
The system shall allow users to delete scheduled tasks via the main UI.

## FR-012 — Message Management
The system shall allow users to view, add, edit, and delete motivational messages via the main UI.

## Status
> DRAFT
