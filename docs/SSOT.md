# Single Source of Truth (SSOT)

These are the canonical rules of the system. All components must conform to them.

## SSOT-001
A scheduled task references exactly one folder path.

## SSOT-002
A scheduled task fires at exactly one time: 2:00 PM on the day after it was created.

## SSOT-003
Clicking "Open Folder" is the only action that completes a task.

## SSOT-004
Clicking "Snooze" does not complete a task. It defers it by exactly 5 minutes.

## SSOT-005
Folder opening in Windows Explorer is the definitive completion condition.

## SSOT-006
Only one motivational popup may be visible on screen at any time.

## SSOT-007
The user never edits configuration files directly. All state is managed through the UI.

## SSOT-008
The snooze loop has no maximum iteration count. It repeats until the user accepts.

## Status
> RATIFIED
