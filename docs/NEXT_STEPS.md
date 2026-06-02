# Next Steps — Prioritized Implementation Backlog

**Generated:** 2026-06-02  
**Source:** GAP_ANALYSIS.md multi-agent review  
**Target:** v1.0 MVP (all 6 Acceptance Criteria passing)

---

## Priority Order

The following order is determined by dependency chain:
> Main App Window → Folder Picker → Task Scheduler Module → Snooze Engine → Task Management UI → Message Library

Nothing else can be tested until the Main Application Window and Folder Picker exist.

---

## Sprint 1 — The Core User Promise *(Blocks everything)*

### TASK-001: Build Main Application Window (WPF)
**Unblocks:** All other tasks  
**AC unlocked:** AC-001, AC-006  
**Spec refs:** `UX_SPEC.md` (Home screen wireframe), `ARCHITECTURE.md`

Build a WPF window with:
- "Select Folder" button → triggers FolderBrowserDialog
- Folder path display label
- "Schedule For Tomorrow" button (disabled until folder selected)
- Scheduled Tasks list panel (empty for now)
- "Manage Messages" button (placeholder for now)

---

### TASK-002: Implement Folder Picker Module
**Depends on:** TASK-001  
**AC unlocked:** AC-001  
**Spec refs:** `PRD.md` FR-001, `UX_SPEC.md`

Wire the "Select Folder" button to a native `System.Windows.Forms.FolderBrowserDialog`. On confirmation, store the path in app state and display it in the UI. Do not write any file yet — just hold it in memory until the user clicks Schedule.

---

### TASK-003: Refactor Task Scheduler Module into a callable function
**Depends on:** TASK-002  
**AC unlocked:** AC-001  
**Spec refs:** `TASK_SCHEDULER_SPEC.md`, `PRD.md` FR-003/004

Extract `UpdateScheduledTask.ps1` logic into a parameterizable PowerShell function (or C# class):
```
CreateTask(folderPath, scheduleTime) -> taskId
ListTasks() -> Task[]
DeleteTask(taskId) -> bool
```
The Main App calls `CreateTask` with the selected folder path and `tomorrow @ 14:00`. The user never runs a script manually.

**Also:** Add `RunAtLogon` missed-trigger recovery (NPR-004, TC-008 UNKNOWN → PASS).

---

### TASK-004: Write popup_config.json from the app (not the user)
**Depends on:** TASK-002, TASK-003  
**AC unlocked:** AC-001, AC-006  
**Spec refs:** `CONFIGURATION_SPEC.md`, `SSOT-007`

On "Schedule For Tomorrow" click, the app writes `popup_config.json` to `%APPDATA%\DailyMotivationBrainHelper\` with the selected folder path. Update `LaunchMotivation.bat` and `DailyMotivation.ps1` to read from the new location.

This is the single most important fix — it closes NPR-001 and SSOT-007 violations.

---

## Sprint 2 — Complete the Popup Loop

### TASK-005: Implement Snooze Engine (5-minute re-trigger)
**Depends on:** TASK-003  
**AC unlocked:** AC-004  
**Spec refs:** `NOTIFICATION_ENGINE_SPEC.md`, `PRD.md` FR-007/008, `SSOT-008`

When "Snooze" is clicked, create a new one-time scheduled task for `now + 5 minutes` using the same `LaunchMotivation.bat` chain. The snooze loop requires no counter — it simply re-registers each time.

---

### TASK-006: Add named mutex to enforce SSOT-006
**Depends on:** TASK-005  
**Spec refs:** `SSOT.md` SSOT-006, `Security` LOW finding

At startup of `DailyMotivation.ps1`, acquire a named system mutex (e.g. `Global\DailyMotivationPopup`). If already held, exit immediately. Release on window close. Prevents duplicate popups.

---

### TASK-007: Validate explorer_path before launching
**Depends on:** TASK-004  
**Spec refs:** `Security` MEDIUM finding, TC-009

Before calling `Start-Process explorer.exe`, check that `$config.explorer_path` is a valid, existing directory (`Test-Path -PathType Container`). If invalid, show an error message in the popup rather than silently failing.

---

## Sprint 3 — Task Management UI

### TASK-008: Task list display in Main App Window
**Depends on:** TASK-003  
**AC unlocked:** AC-005  
**Spec refs:** `USER_STORIES.md` US-005, `PRD.md` FR-011

Call `ListTasks()` on app load and display results in the Scheduled Tasks panel. Show folder path and scheduled time for each task.

---

### TASK-009: Task deletion from UI
**Depends on:** TASK-008  
**AC unlocked:** AC-005  
**Spec refs:** `USER_STORIES.md` US-006, `PRD.md` FR-011, `USE_CASES.md` UC-004

Add a "Delete" button (or right-click context menu) for each task row. Calls `DeleteTask(taskId)` and refreshes the list.

---

## Sprint 4 — Polish & Hardening

### TASK-010: Message library with random selection
**Spec refs:** `MOTIVATION_SYSTEM_SPEC.md`, `PRD.md` FR-012 (partial)

Bundle 10 default motivational messages in `messages.json`. At task creation time, select one randomly and store it in `popup_config.json`. This gives variety without requiring any user action.

### TASK-011: Success confirmation UX
**Spec refs:** `UX_SPEC.md`

After scheduling, show a brief confirmation banner: "Scheduled! Your folder will open tomorrow at 2 PM." Auto-dismiss after 3 seconds.

### TASK-012: Task Scheduler availability check at startup
**Spec refs:** TC-011

On app launch, verify the Windows Task Scheduler service is running. If not, show a clear error with a single-click fix link (opens `services.msc`).

### TASK-013: Move config to %APPDATA%
**Spec refs:** `CONFIGURATION_SPEC.md`, Security LOW finding

Move all JSON files from the script directory to `%APPDATA%\DailyMotivationBrainHelper\`. TASK-004 should implement this; this task is a verification/cleanup task.

---

## Dependency Graph

```
TASK-001 (Main Window)
  └── TASK-002 (Folder Picker)
        └── TASK-003 (Task Scheduler Module)
              ├── TASK-004 (Write config from app)   ← closes NPR-001, SSOT-007
              ├── TASK-005 (Snooze Engine)            ← closes AC-004
              │     └── TASK-006 (Mutex)
              ├── TASK-007 (Path validation)
              └── TASK-008 (Task list UI)
                    └── TASK-009 (Delete task)        ← closes AC-005

Independent:
  TASK-010 (Message library)
  TASK-011 (Success UX)
  TASK-012 (Scheduler check)
  TASK-013 (Config location)
```

---

## v1.0 MVP Definition of Done

All of the following must be true:

- [ ] TASK-001 through TASK-009 complete
- [ ] AC-001 through AC-006 all PASS
- [ ] TC-001 through TC-011 all PASS or N/A
- [ ] NPR-001 through NPR-007 all Met
- [ ] SSOT-001 through SSOT-008 all Compliant
- [ ] No user ever edits a JSON, script, or config file
- [ ] Security MEDIUM finding resolved (path validation)
