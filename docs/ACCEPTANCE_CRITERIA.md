# Acceptance Criteria

## AC-001 — Folder Scheduling
- GIVEN the app is open
- WHEN the user selects a folder and clicks "Schedule For Tomorrow"
- THEN a Windows Scheduled Task exists for 2:00 PM the next calendar day
- AND a success message is shown in the UI
- AND no files were manually edited by the user

## AC-002 — Popup Display
- GIVEN a scheduled task exists for today at 2 PM
- WHEN 2:00 PM arrives
- THEN the motivational popup appears on screen
- AND the popup displays a title, body text, and countdown

## AC-003 — Popup Acceptance
- GIVEN the popup is displayed
- WHEN the user clicks "Open Folder"
- THEN the popup closes
- AND Windows Explorer opens with the scheduled folder
- AND the task is marked complete

## AC-004 — Snooze Behavior
- GIVEN the popup is displayed
- WHEN the user clicks "Snooze"
- THEN the popup closes
- AND 5 minutes later the popup reappears
- AND this repeats until "Open Folder" is clicked

## AC-005 — Task Deletion
- GIVEN at least one scheduled task exists
- WHEN the user selects it and clicks "Delete"
- THEN the task is removed from Windows Task Scheduler
- AND it no longer appears in the task list

## AC-006 — No Code Required
- GIVEN any core user action
- THEN no JSON, script, or config file is opened, edited, or shown to the user

## Status
> DRAFT
