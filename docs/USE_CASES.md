# Use Cases

**Last Reviewed**: 2026-06-09

## UC-001 — End of Day Scheduling
**Actor:** User  
**Precondition:** Application is installed and running  
**Main Flow:**
1. User launches the app
2. User clicks "Select Folder"
3. User navigates to their working folder and confirms
4. User clicks "Schedule For Tomorrow"
5. App stores the folder path and creates a scheduled task
6. App confirms scheduling with a brief success message

**Postcondition:** Task is registered to fire at 2 PM the next day

---

## UC-002 — Popup Acceptance at 2 PM
**Actor:** Windows Task Scheduler (automated), User  
**Precondition:** Scheduled task exists for today at 2 PM  
**Main Flow:**
1. Task Scheduler fires the task at 2 PM
2. Motivational popup appears on screen
3. User reads the message and clicks "Open Folder"
4. Popup closes
5. Windows Explorer opens with the scheduled folder

**Postcondition:** Task marked complete; folder is open

---

## UC-003 — Snooze Loop
**Actor:** User  
**Precondition:** Popup is displayed  
**Main Flow:**
1. User clicks "Snooze"
2. Popup closes
3. After 5 minutes, popup reappears
4. Loop continues until user clicks "Open Folder"

**Postcondition:** Folder opens; snooze loop terminates

---

## UC-004 — Task Deletion
**Actor:** User  
**Precondition:** At least one scheduled task exists  
**Main Flow:**
1. User opens the app
2. User views the scheduled task list
3. User selects a task and clicks "Delete"
4. App removes the task from Windows Task Scheduler

**Postcondition:** Task no longer fires

## Status
> DRAFT
