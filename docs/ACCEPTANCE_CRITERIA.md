# Acceptance Criteria

**Last Updated:** 2026-06-03
**Last Reviewed**: 2026-06-09

## Original Criteria

### AC-001 — Folder Scheduling
- GIVEN the app is open
- WHEN the user selects a folder and clicks "Schedule For Tomorrow"
- THEN a Windows Scheduled Task exists for 2:00 PM the next calendar day
- AND a success message is shown
- AND no files were manually edited by the user

### AC-002 — Popup Display
- GIVEN a scheduled task exists for today at 2 PM
- WHEN 2:00 PM arrives
- THEN the motivational popup appears on screen with title, body, and countdown

### AC-003 — Popup Acceptance
- GIVEN the popup is displayed
- WHEN the user clicks "Open Folder"
- THEN the popup closes AND Windows Explorer opens at the scheduled folder AND the task is marked complete

### AC-004 — Snooze Behavior
- GIVEN the popup is displayed
- WHEN the user selects a snooze duration and clicks "Snooze"
- THEN the popup closes AND reappears after the selected duration AND this repeats until "Open Folder" is clicked

### AC-005 — Task Deletion
- GIVEN at least one scheduled task exists
- WHEN the user selects it and clicks "Delete"
- THEN the task is removed from Windows Task Scheduler AND no longer appears in the list

### AC-006 — No Code Required
- GIVEN any core user action
- THEN no JSON, script, or config file is opened, edited, or shown to the user

---

## New Criteria

### AC-007 — Last Folder Banner (B-01)
- GIVEN the user has previously scheduled a folder
- WHEN the app is opened a second time
- THEN a banner appears offering to schedule the same folder in one click

### AC-008 — Schedule For Today (B-03)
- GIVEN the current local time is before 14:00
- WHEN the scheduling UI is displayed
- THEN a "Today at 2:00 PM" option is visible alongside "Tomorrow at 2:00 PM"

### AC-009 — Undo Schedule (B-04)
- GIVEN a task was just created
- WHEN the undo banner is visible
- THEN clicking [Undo] removes the task and the banner disappears
- AND if not clicked within 30 seconds, the task remains

### AC-010 — Moved Folder Re-Pick (B-05)
- GIVEN a scheduled task exists
- WHEN the popup fires and the folder path no longer exists
- THEN the popup displays a re-pick prompt instead of the normal open flow

### AC-011 — First-Run Welcome (B-07)
- GIVEN the app has never been launched before
- WHEN the app opens
- THEN the welcome overlay appears
- AND on the second launch, the overlay does NOT appear

### AC-012 — Drag-and-Drop (B-09)
- GIVEN the app is open
- WHEN the user drags a folder from Windows Explorer onto the drop zone
- THEN the folder path is populated in the UI as if selected via the picker

### AC-013 — Snooze Duration (B-10)
- GIVEN the popup is displayed
- WHEN the user selects "30 min" from the snooze dropdown and clicks Snooze
- THEN the popup reappears after exactly 30 minutes

### AC-014 — Dismiss for Today (B-11)
- GIVEN the popup is displayed
- WHEN the user clicks "Dismiss for Today"
- THEN the popup closes AND no further snooze re-triggers fire for that task today

### AC-015 — Folder Name in Popup (B-12)
- GIVEN a task is scheduled for folder "D:\Projects\ClientA"
- WHEN the popup fires
- THEN the popup displays "Opening: ClientA" as a subtitle

### AC-016 — Duplicate Warning (B-16)
- GIVEN a task already exists for folder X on date Y
- WHEN the user tries to schedule folder X for date Y again
- THEN a warning dialog appears before the task is created

### AC-017 — History Panel (B-18)
- GIVEN the user has completed or dismissed at least one task
- WHEN the user opens the History panel
- THEN past outcomes are displayed with date, folder name, and result

### AC-018 — Tooltips (B-19)
- GIVEN the app is open
- WHEN the user hovers over any interactive control
- THEN a tooltip appears within 1 second with a plain-English description

## Status
> v1.1 DRAFT
