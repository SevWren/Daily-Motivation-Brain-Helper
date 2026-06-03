# Sprint Plan — Daily Motivation Brain Helper

**Last Updated:** 2026-06-02
**Source:** NEXT_STEPS.md (original 13 tasks) + multi-agent brainstorm (20 features proposed, 14 approved)
**Approval Record:** See [FEATURE_BRAINSTORM.md](FEATURE_BRAINSTORM.md) for full approval/rejection log.

---

## Approved Brainstorm Features (14 of 20)

| ID | Feature | Sprint | Merged Into |
|----|---------|--------|------------|
| B-01 | Remember Last Folder (Quick Reschedule) | 1 | TASK-004 |
| B-02 | Recent Folders List | 3 | TASK-008 |
| B-03 | Schedule For Today (Before 2 PM) | 1 | TASK-003 |
| B-04 | Undo Schedule (30-Second Grace Period) | 2 | TASK-NEW-01 |
| B-05 | Folder No Longer Exists — Re-Pick Prompt | 2 | TASK-007 |
| B-07 | First-Run Welcome Screen | 1 | TASK-001 |
| B-09 | Drag-and-Drop Folder Onto App Window | 1 | TASK-002 |
| B-10 | Snooze Duration Choice | 2 | TASK-005 |
| B-11 | Dismiss for Today | 2 | TASK-005 |
| B-12 | Show Folder Name in Popup | 1 | TASK-004 |
| B-13 | Windows Explorer Right-Click Shell Extension | 4 | TASK-NEW-02 |
| B-16 | Duplicate Schedule Warning | 2 | TASK-003 |
| B-18 | Task History / Outcome Log Viewer | 3 | TASK-NEW-03 |
| B-19 | Tooltip Explanations on All UI Controls | 1 | TASK-001 |

## Rejected Features (6 of 20)

| ID | Feature | Reason |
|----|---------|--------|
| B-06 | Preview Popup Button | Not approved |
| B-08 | System Tray Icon | Not approved |
| B-14 | Auto-Start on Windows Login | Not approved |
| B-15 | Paste Path from Clipboard | Not approved |
| B-17 | Missed Task Recovery UI | Not approved |
| B-20 | "What Happens Next" Panel | Not approved |

---

## Sprint 1 — Core User Promise + Onboarding Foundation

**Definition of Done for Sprint 1:** User can open the app, see the welcome screen on first run, select or drag-drop a folder, see the "today vs. tomorrow" scheduling option, and schedule it — all without editing any file. The popup then fires at the right time showing the folder name.

---

### TASK-001 — Main Application Window (WPF)
**Incorporates:** B-07 (First-Run Welcome Screen), B-19 (Tooltips)
**AC unlocked:** AC-001, AC-006
**Spec refs:** `UX_SPEC.md`, `ARCHITECTURE.md`

Build the root WPF window (`MainWindow.xaml` / `MainApp.ps1`):
- Home screen with: Select Folder button, folder path display, Schedule button (disabled until folder selected), Scheduled Tasks panel (empty stub), Manage Messages placeholder
- **B-07:** On first launch (flag in `%APPDATA%`), display a fullscreen onboarding overlay card explaining the 3-step loop (Pick → Schedule → Opens at 2 PM). Single "Got it" button dismisses and sets `firstRun=false`
- **B-19:** Every button and input has a `ToolTip` property with plain-English description

**Deliverables:**
- `src/MainApp.ps1` — WPF main window launcher
- `src/MainWindow.xaml` — UI layout
- `src/data/app_settings.json` — schema stub (firstRun, theme, etc.)

---

### TASK-002 — Folder Picker Module + Drag-and-Drop
**Incorporates:** B-09 (Drag-and-Drop)
**AC unlocked:** AC-001
**Spec refs:** `PRD.md` FR-001, `UX_SPEC.md`

- Wire "Select Folder" button to `System.Windows.Forms.FolderBrowserDialog`
- **B-09:** Register `AllowDrop="True"` on the drop zone panel; handle `PreviewDragOver` and `Drop` events — extract folder path from `DataObject.GetFileDropList()`, validate it is a directory
- Display the resolved path in the path label
- Enable "Schedule" button only when a valid path is held in memory

**Deliverables:**
- Updated `src/MainApp.ps1` (folder picker and drag-drop logic implemented inline)

---

### TASK-003 — Task Scheduler Module Refactor + Schedule For Today + Duplicate Warning
**Incorporates:** B-03 (Schedule For Today), B-16 (Duplicate Schedule Warning)
**AC unlocked:** AC-001
**Spec refs:** `TASK_SCHEDULER_SPEC.md`, `PRD.md` FR-003/004

Refactor `UpdateScheduledTask.ps1` into a parameterizable PowerShell module:
```
New-MotivationTask -FolderPath <string> -TriggerTime <datetime> -> task_id
Get-MotivationTasks -> Task[]
Remove-MotivationTask -TaskId <string> -> bool
```
- **B-03:** If current time is before 14:00 on the current day, the Schedule button UI shows two options: "Today at 2:00 PM" and "Tomorrow at 2:00 PM" (radio buttons or split button). App passes the correct `TriggerTime`
- **B-16:** Before calling `New-MotivationTask`, query `Get-MotivationTasks` and check for any existing task with the same `FolderPath` scheduled for the same date. If found, show a confirmation dialog: "This folder is already scheduled for [date]. Schedule again anyway? [Yes] [Cancel]"
- Add `RunAtLogon` missed-trigger recovery (fixes TC-008 UNKNOWN)

**Deliverables:**
- `src/Modules/TaskScheduler.psm1`
- Updated `src/UpdateScheduledTask.ps1` (now just a thin wrapper calling the module)

---

### TASK-004 — App Writes popup_config.json + Remember Last Folder + Show Folder Name in Popup
**Incorporates:** B-01 (Remember Last Folder), B-12 (Show Folder Name in Popup)
**AC unlocked:** AC-001, AC-006 — closes NPR-001, SSOT-007
**Spec refs:** `CONFIGURATION_SPEC.md`, `SSOT.md`

- On "Schedule" confirm, app writes `popup_config.json` to `%APPDATA%\DailyMotivationBrainHelper\` — user never touches this file
- Update `LaunchMotivation.bat` and `DailyMotivation.ps1` to read from the new `%APPDATA%` path
- **B-01:** After writing config, save `lastFolder` to `app_settings.json`. On next app launch, if `lastFolder` exists, show a one-click banner at the top: "Schedule same folder as last time? [Yes, Schedule] [Choose Different]"
- **B-12:** Add `folder_name` field to `popup_config.json` (just `Split-Path -Leaf` of the path). Update `DailyMotivation.ps1` XAML to display a subtitle line: "Opening: {folder_name}" below the body text

**Deliverables:**
- Updated `src/DailyMotivation.ps1` (new `%APPDATA%` path + folder_name subtitle)
- Updated `src/LaunchMotivation.bat` (new config path)
- Updated `src/Modules/ConfigManager.psm1`

---

## Sprint 2 — Complete the Popup Loop + Recovery

**Definition of Done for Sprint 2:** The snooze loop is fully functional with duration choices. "Dismiss for Today" works. Duplicate tasks are warned. Undo works. Invalid paths are caught at popup time with a re-pick prompt.

---

### TASK-005 — Snooze Engine + Snooze Duration Choice + Dismiss for Today
**Incorporates:** B-10 (Snooze Duration Choice), B-11 (Dismiss for Today)
**AC unlocked:** AC-004, closes SSOT-008
**Spec refs:** `NOTIFICATION_ENGINE_SPEC.md`, `PRD.md` FR-007/008

- **Core:** When "Snooze" is clicked, create a new one-time scheduled task for `now + selectedDuration` using `New-MotivationTask` with the same `popup_config.json` path
- **B-10:** Replace the "Snooze" button with a split-button: primary label shows "Snooze 5 min"; a dropdown arrow reveals [5 min ✓] [15 min] [30 min] [1 hour]. Selection persists for the session
- **B-11:** Add a third button "Dismiss for Today" (styled subtle/grey). On click: stop countdown, delete all pending snooze tasks for this config's `task_id`, close popup, write `outcome=Dismissed` to log. Does NOT open Explorer

**Deliverables:**
- Updated `src/DailyMotivation.ps1` (split snooze button + Dismiss for Today button)
- Updated `src/Modules/TaskScheduler.psm1` (snooze re-register logic)

---

### TASK-006 — Named Mutex (One Popup at a Time)
**AC unlocked:** closes SSOT-006
**Spec refs:** `SSOT.md`, Security LOW finding

At startup of `DailyMotivation.ps1`, acquire a named system mutex `Global\DailyMotivationPopup`. If already held, log "duplicate suppressed" and `exit 0`. Release mutex in `finally` block on window close.

**Deliverables:**
- Updated `src/DailyMotivation.ps1` (mutex acquisition at top, release in finally)

---

### TASK-007 — Path Validation + Moved Folder Re-Pick Prompt
**Incorporates:** B-05 (Moved Folder Recovery)
**Spec refs:** Security MEDIUM finding, TC-009

- Before calling `Start-Process explorer.exe`, call `Test-Path $config.explorer_path -PathType Container`
- **B-05:** If path is invalid, instead of error/silent fail, transform the popup: hide the countdown and "Open Folder" button; show the message "This folder was moved or deleted." with two buttons: "[Choose New Location]" (opens FolderBrowserDialog inline via Add-Type, updates config and opens Explorer) and "[Dismiss]" (closes popup, logs `outcome=PathMissing`)
- If path is valid, proceed normally

**Deliverables:**
- Updated `src/DailyMotivation.ps1` (path validation + re-pick branch)

---

### TASK-NEW-01 — Undo Schedule (30-Second Grace Period)
**Incorporates:** B-04
**Spec refs:** `UX_SPEC.md`, `PRD.md`

After a successful `New-MotivationTask` call, the main app shows an Undo banner (animated slide-in at bottom of window):

```
✓ Scheduled for tomorrow at 2:00 PM    [Undo]   ▓▓▓▓▓▓░░░░░░ 18s
```

- A `DispatcherTimer` counts down 30 seconds, filling a progress bar; banner auto-dismisses at 0
- Clicking [Undo] calls `Remove-MotivationTask` with the just-created task_id, dismisses the banner, and restores the "Schedule" button state
- If [Undo] is not clicked within 30 seconds, the task stands

**Deliverables:**
- Updated `src/MainApp.ps1` / `src/MainWindow.xaml` (undo banner XAML + timer logic)

---

## Sprint 3 — Task Management UI + History

**Definition of Done for Sprint 3:** User can see all scheduled tasks, delete them, see recently used folders for one-click re-scheduling, and view a clean history of past outcomes.

---

### TASK-008 — Task List Display + Recent Folders List
**Incorporates:** B-02 (Recent Folders List)
**AC unlocked:** AC-005
**Spec refs:** `USER_STORIES.md` US-005, `PRD.md`

- On app load, call `Get-MotivationTasks` and render results in the Scheduled Tasks panel: folder name, scheduled date/time, status badge (Pending / Snoozed / Completed)
- **B-02:** Below the picker area, render a "Recent Folders" section showing up to 5 previously scheduled folders (stored in `app_settings.json` as `recentFolders[]`). Each row: folder name + path tooltip + "[Schedule Again]" button. Clicking "Schedule Again" pre-fills the path and triggers the duplicate-check flow (TASK-003)
- Update `recentFolders[]` on every successful `New-MotivationTask` call (FIFO, max 5 entries)

**Deliverables:**
- Updated `src/MainApp.ps1` + `src/MainWindow.xaml`
- Updated `src/Modules/ConfigManager.psm1` (recentFolders read/write)

---

### TASK-009 — Task Deletion
**AC unlocked:** AC-005
**Spec refs:** `USER_STORIES.md` US-006, `USE_CASES.md` UC-004

- Each task row in the list has a "×" delete button
- On click: confirm dialog "Remove this scheduled task? This cannot be undone. [Remove] [Cancel]"
- On confirm: call `Remove-MotivationTask`, refresh the task list

**Deliverables:**
- Updated `src/MainApp.ps1` + `src/MainWindow.xaml`

---

### TASK-NEW-03 — History / Outcome Log Viewer
**Incorporates:** B-18
**Spec refs:** `DATA_MODEL.md`, Security Agent recommendation

- Add a "History" tab or collapsible panel in the main window
- Reads `popup_log.txt` from `%APPDATA%\DailyMotivationBrainHelper\`; parses each line into: Date | Folder Name | Outcome (Opened / Snoozed N times / Dismissed / Missed)
- Displayed as a read-only styled list, newest first, max 30 entries shown
- A "Clear History" button at the bottom (with confirmation dialog)

**Deliverables:**
- Updated `src/MainApp.ps1` + `src/MainWindow.xaml` (History panel)
- Updated `src/DailyMotivation.ps1` (write structured log entries with snooze count)

---

## Sprint 4 — Polish, Hardening + Advanced Features

**Definition of Done for Sprint 4:** App passes all 6 Acceptance Criteria. All 11 test cases pass or are N/A. Shell extension is registered and working.

---

### TASK-010 — Message Library (10 Defaults, Random Selection)
**Spec refs:** `MOTIVATION_SYSTEM_SPEC.md`, `PRD.md` FR-012 (partial)

- Bundle `src/data/messages.json` with 10 default messages (glyph + title + body each)
- At `New-MotivationTask` time, pick a random message from the active pool and write it to `popup_config.json`
- Default messages are read-only; user cannot delete them in v1.0

**Deliverables:**
- `src/data/messages.json` (10 messages)
- Updated `src/Modules/ConfigManager.psm1` (random selection logic)

---

### TASK-011 — Scheduling Confirmation UX
**Spec refs:** `UX_SPEC.md`

Refine the success state of the main window:
- After scheduling, the folder path label changes to green with a checkmark icon
- Scheduled Tasks panel auto-refreshes to show the new task immediately
- (Undo banner from TASK-NEW-01 is the primary feedback; this is visual state reinforcement)

**Deliverables:**
- Updated `src/MainWindow.xaml` (success state styles)

---

### TASK-012 — Task Scheduler Availability Check at Startup
**Spec refs:** TC-011

On `MainApp.ps1` startup:
```powershell
$svc = Get-Service -Name Schedule -ErrorAction SilentlyContinue
if ($svc.Status -ne 'Running') { # show error card }
```
If not running, show a non-dismissable error card in the main window:
"Windows Task Scheduler is not running. [Fix This →]" — clicking the button runs `Start-Service Schedule` (elevated if needed) or opens `services.msc`.

**Deliverables:**
- Updated `src/MainApp.ps1` (startup health check)

---

### TASK-013 — Config Location → %APPDATA% (Verification + Cleanup)
**Spec refs:** `CONFIGURATION_SPEC.md`, Security LOW finding

Verify all JSON file reads/writes across all modules use `%APPDATA%\DailyMotivationBrainHelper\` (established in TASK-004). Remove any remaining references to the script directory for config files. Ensure the directory is created on first run if it does not exist.

**Deliverables:**
- Audit pass across all `src/` files
- `src/Modules/ConfigManager.psm1` — `Initialize-AppData` function called at startup

---

### TASK-NEW-02 — Windows Explorer Right-Click Shell Extension
**Incorporates:** B-13
**Complexity:** HIGH
**Spec refs:** `ARCHITECTURE.md`, `TASK_SCHEDULER_SPEC.md`

Adds "Schedule for Tomorrow at 2 PM" to the right-click context menu on folders in Windows Explorer. Implemented as a small C# COM shell extension DLL registered via registry.

**Approach:**
- `src/ShellExtension/MotivationShellExt.cs` — implements `IContextMenu` and `IShellExtInit`
- Build target: `MotivationShellExt.dll` (.NET Framework 4.x, COM-visible)
- Registration script: `src/ShellExtension/Register-ShellExtension.ps1` (writes registry keys; requires one-time admin)
- On menu click: calls `New-MotivationTask` via a lightweight PowerShell bridge (`src/ShellExtension/ShellBridge.ps1`)
- Shows a Windows toast notification confirming: "Scheduled! [FolderName] will open tomorrow at 2 PM"

**Deliverables:**
- `src/ShellExtension/MotivationShellExt.cs`
- `src/ShellExtension/Register-ShellExtension.ps1`
- `src/ShellExtension/ShellBridge.ps1`

---

## Full Task Dependency Graph

```
TASK-001  Main Window + Onboarding (B-07) + Tooltips (B-19)
  └── TASK-002  Folder Picker + Drag-Drop (B-09)
        └── TASK-003  Scheduler Module + Schedule Today (B-03) + Dupe Warning (B-16)
              ├── TASK-004  Write Config + Last Folder (B-01) + Folder Name in Popup (B-12)
              │     ├── TASK-005  Snooze Engine + Duration (B-10) + Dismiss Today (B-11)
              │     │     └── TASK-006  Named Mutex
              │     ├── TASK-007  Path Validation + Re-Pick (B-05)
              │     ├── TASK-NEW-01  Undo Schedule (B-04)
              │     └── TASK-008  Task List + Recent Folders (B-02)
              │           └── TASK-009  Task Deletion
              └── TASK-NEW-03  History Log Viewer (B-18)

Independent (after core loop):
  TASK-010  Message Library
  TASK-011  Confirmation UX
  TASK-012  Scheduler Health Check
  TASK-013  Config location audit
  TASK-NEW-02  Shell Extension (B-13)  [Sprint 4, high complexity]
```

---

## Revised Acceptance Criteria Coverage

| AC | Criterion | Closed By |
|----|-----------|-----------|
| AC-001 | Folder scheduling, no file editing | TASK-001, 002, 003, 004 |
| AC-002 | Popup at 2 PM | Existing (passes) |
| AC-003 | Accept → Explorer opens | Existing (passes) |
| AC-004 | Snooze → reappear in 5 min | TASK-005 |
| AC-005 | Task deletion via UI | TASK-009 |
| AC-006 | No file editing ever | TASK-004 |

## v1.0 MVP Definition of Done

- [x] TASK-001 through TASK-013 + TASK-NEW-01 + TASK-NEW-03 complete
- [x] All 6 Acceptance Criteria PASS
- [x] All 11 Test Cases PASS or N/A
- [x] All 7 NPR requirements Met
- [x] All 8 SSOT rules Compliant
- [x] Security MEDIUM finding resolved (TASK-007)
- [x] No user ever edits a JSON, script, or config file
