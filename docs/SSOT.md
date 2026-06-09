# Single Source of Truth (SSOT)

**Last Updated:** 2026-06-03
**Last Reviewed**: 2026-06-09

These are the canonical rules of the system. All components must conform to them.

## SSOT-001
A scheduled task references exactly one folder path.

## SSOT-002
A scheduled task fires at exactly one time: either today at 14:00 or tomorrow at 14:00, determined at the moment of creation.
**Updated (B-03):** TriggerTime is caller-specified; it is no longer always next-day.

## SSOT-003
Clicking "Open Folder" is the only action that completes a task with outcome=Opened.

## SSOT-004
Clicking "Snooze" does not complete a task. It defers it by the user-selected duration.

## SSOT-005
Folder opening in Windows Explorer is the definitive completion condition.

## SSOT-006
Only one motivational popup may be visible on screen at any time. Enforced by a named system mutex.

## SSOT-007
The user never edits configuration files directly. All state is managed through the UI.

## SSOT-008
The snooze loop has no maximum iteration count. It repeats until the user accepts or dismisses.

## SSOT-009 (B-11)
DISMISSED is a terminal state. A dismissed task does not re-trigger. Dismissal is not completion — the folder is not opened and the task is not marked COMPLETED.

## Status
> v1.1 RATIFIED
