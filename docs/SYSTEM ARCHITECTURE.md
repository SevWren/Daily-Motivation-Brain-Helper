# HIGH-LEVEL: SYSTEM ARCHITECTURE

### 1.1 System Architecture Diagram

```ascii
┌─────────────────────────────────────────────────────────────────────────┐
│                        RUNTIME ARCHITECTURE                             │
│                                                                         │
│  ┌──────────────┐    ┌───────────────┐    ┌────────────────────────┐    │
│  │  MainApp.exe │    │  Popup.exe    │    │  Windows Task          │    │
│  │  (PS2EXE)    │    │  (PS2EXE)     │    │  Scheduler             │    │
│  │  WPF GUI     │    │  WPF Popup    │    │  (schtasks.exe)        │    │
│  └──────┬───────┘    └──────┬────────┘    └───────────┬────────────┘    │
│         │                   │                         │                 │
│         │  imports          │  imports                │  fires          │
│         ▼                   ▼                         ▼                 │
│  ┌─────────────────────────────────────────────────────────────────┐    │
│  │                    %APPDATA%\DailyMotivationBrainHelper\        │    │
│  │  Modules\ConfigManager.psm1  (JSON I/O: 252 lines)              │    │
│  │  Modules\TaskScheduler.psm1  (Scheduler CRUD: 237 lines)        │    │
│  │  popup_config.json           (active task)                      │    │
│  │  tasks.json                  (task records, source of truth)    │    │
│  │  app_settings.json         (firstRun, lastFolder, recentFolders)│    │
│  │  messages.json               (10 default motivational messages) │    │
│  │  popup_log.txt               (pipe-delimited outcome log)       │    │
│  └─────────────────────────────────────────────────────────────────┘    │
│                                                                         │
│  ┌─────────────────────────────────────────────────────────────────┐    │
│  │  src/ (developer workspace — the .exe's "companion" files)      │    │
│  │  LaunchMotivation.bat    (PS2EXE output's launcher companion)   │    │
│  │  MainWindow.xaml         (WPF UI markup)                        │    │
│  │  data/messages.json      (source copy for first-run install)    │    │
│  └─────────────────────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────────────────┘
```

### 1.2 Module Responsibility Matrix

| Module           | File                       | Lines | Responsibilities                                                                                   | Key Exports                                                                                             | Imports                      |
| ---------------- | -------------------------- | ----- | -------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------- | ---------------------------- |
| Main App         | MainApp.ps1                | 562   | WPF entry point, all UI event handlers, undo timer, welcome overlay                                | (script entry point)                                                                                    | ConfigManager, TaskScheduler |
| Popup Engine     | DailyMotivation.ps1        | 549   | WPF popup, countdown timer, snooze re-trigger, dismiss-for-today, path missing branch, named mutex | (script entry point)                                                                                    | ConfigManager, TaskScheduler |
| Config Manager   | Modules/ConfigManager.psm1 | 252   | All JSON reads/writes, %APPDATA% initialization, log parsing, error dialog helper                  | Initialize-AppData, Set-PopupConfig, Get-OutcomeLog, Set-LastFolder, Add-RecentFolder, Show-ErrorDialog | (none — leaf module)         |
| Task Scheduler   | Modules/TaskScheduler.psm1 | 237   | Windows Task Scheduler CRUD, duplicate detection, network path detection, launcher path resolution | New-MotivationTask, Get-MotivationTasks, Remove-MotivationTask, Update-MotivationTaskStatus             | (none — leaf module)         |
| Launcher Wrapper | LaunchMotivation.bat       | 59    | Resolves PowerShell path, passes -STA, logs launch, invokes DailyMotivation.ps1                    | (batch entry point)                                                                                     | none                         |
| One-Time Setup   | UpdateScheduledTask.ps1    | 97    | Copies modules/data to %APPDATA%, initializes config, registers placeholder Task Scheduler task    | (admin script)                                                                                          | ConfigManager (indirect)     |

**Dependency direction**: Strictly downward. MainApp → both modules. DailyMotivation → both modules. UpdateScheduledTask → ConfigManager only. Modules never import each other.

### 1.3 State Machines

**Task Lifecycle**:

```
PENDING ──(2 PM fires)──> SNOOZED ──(snooze duration)──> SNOOZED (loop, no max)
   │                                                              │
   │                                                              ▼
   │                                                         SNOOZED (user clicks Open Folder)
   │                                                              │
   │                                                              ▼
   │                                                         COMPLETED
   │
   ├──(user deletes from UI)──> DELETED
   └──(user clicks Dismiss)──> DISMISSED (terminal — no re-trigger)
```

**Popup Display Lifecycle**:

```
HIDDEN ──(Task Scheduler fires)──> MUTEX CHECK ──(acquired)──> DISPLAYED
                                          └─(held)──> EXIT SILENTLY (SSOT-006)

DISPLAYED ──(click Open Folder)──> EXPLORER LAUNCH → CLOSE → Opened
         ├──(click Snooze)─────────> CREATE RE-TRIGGER TASK → CLOSE → Snoozed
         ├──(click Dismiss)────────> CANCEL ALL PENDING → CLOSE → Dismissed
         ├──(countdown hits 0)─────> SAME AS Open Folder
         └──(path missing)─────────> PATH_MISSING UI
                                       ├──(re-pick)──> UPDATE PATH → EXPLORER → CLOSE
                                       └──(dismiss)──> CLOSE → PathMissing
```

### 1.4 Runtime File Layout (What the .exe needs to find)

**Developer layout (source tree)**:

```text
src/
  DailyMotivation.exe        ← compiled MainApp
  Modules/
    ConfigManager.psm1
    TaskScheduler.psm1
  MainWindow.xaml
  DailyMotivation.ps1
  LaunchMotivation.bat
  data/
    messages.json
```

**Expected compiled layout**:

```text
<output_dir>/
  DailyMotivation.exe
  DailyMotivationBrainHelper.exe  ← popup .exe (optional)
  LaunchMotivation.bat
  Modules/
    ConfigManager.psm1
    TaskScheduler.psm1
  MainWindow.xaml
  data/
    messages.json
```

> **Critical mismatch**: `.build.ps1` currently copies dependencies to `Output/src/Modules/` and `Output/src/data/` — a subdirectory the runtime code never searches.

### 1.5 Build Pipeline

| Script           | Type          | Output                                                             | Admin required | Canonical?              |
| ---------------- | ------------- | ------------------------------------------------------------------ | -------------- | ----------------------- |
| build.ps1 (root) | ps2exe direct | src\DailyMotivation.exe                                            | Yes            | Documented in CLAUDE.md |
| .build.ps1       | Invoke-Build  | Output\DailyMotivation.exe + Output\DailyMotivationBrainHelper.exe | No             | CI/CD uses this         |

Both scripts run `Invoke-ps2exe`. Neither applies the PS2EXE-safe path resolution pattern before compiling.

### 1.6 Configuration Schema Inventory

| File              | Location                               | Format                        | Key Fields                                                                                                                                                                       |
| ----------------- | -------------------------------------- | ----------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| app_settings.json | %APPDATA%\DailyMotivationBrainHelper\  | JSON ordered hashtable        | firstRun:bool, lastFolder:string, recentFolders:string[], theme:string                                                                                                           |
| tasks.json        | same                                   | JSON array of PSCustomObjects | task_id:16-hex, task_name:string, folder_path:string, folder_name:string, scheduled_time:ISO8601, created_at:ISO8601, status:enum, snooze_count:int, snooze_duration_minutes:int |
| popup_config.json | same                                   | JSON ordered hashtable        | glyph:string, title:string, body:string, explorer_path:string, folder_name:string, task_id:string                                                                                |
| messages.json     | %APPDATA%\... or src\data\             | JSON array                    | message_id:string, glyph:string, title:string, body:string, is_default:bool                                                                                                      |
| popup_log.txt     | same                                   | Pipe-delimited text           | `[timestamp] \| ...`                                                                                                                                                             |

**Status enum**: `PENDING | COMPLETED | SNOOZED | DISMISSED | DELETED`

### 1.7 Test Infrastructure Map

| Layer       | File                       | Tests              | Framework      | Coverage Target |
| ----------- | -------------------------- | ------------------ | -------------- | --------------- |
| Unit        | ConfigManager.Tests.ps1    | 40+ It blocks      | Pester 5.x     | ~90%            |
| Unit        | TaskScheduler.Tests.ps1    | 35+ It blocks      | Pester 5.x     | ~85%            |
| Integration | Initialization.Tests.ps1   | 16 Describe blocks | Pester 5.x     | N/A             |
| E2E         | (none)                     | —                  | Manual only    | —               |
| CI          | .github/workflows/test.yml | 3 jobs             | GitHub Actions | —               |

**Coverage gap**: `DailyMotivation.ps1` (0%) and `MainApp.ps1` (0%) — WPF components require live Windows desktop session.

---

## LOW-LEVEL: FILE-BY-FILE ANALYSIS

### 2.1 src/MainApp.ps1 (562 lines)

**Purpose**: WPF entry point. Imports both modules, initializes %APPDATA%, loads XAML, wires all 16+ event handlers.

**Key sections**:

- **Path resolution** (lines 36–41): Has fallback but still broken under PS2EXE.
- **Module import**: Wrapped in try/catch with good error handling.
- **Service health check**: Prompts to start Task Scheduler if needed.
- **XAML loading**: Strips `x:Class`, validates Window object.
- **Event handlers**: Extensive drag-drop, recent folders, undo, welcome overlay, etc.

### 2.2 src/Modules/ConfigManager.psm1 (252 lines)

**Purpose**: Single authority for all JSON I/O and %APPDATA% initialization.

**Highlights**:

- Three-tier error dialog fallback (WPF → WinForms → Console).
- Robust `Initialize-AppData` with %TEMP% fallback.
- `Add-RecentFolder`: FIFO list (max 5), deduplicated using `List[string]`.

### 2.3 src/Modules/TaskScheduler.psm1 (237 lines)

**Purpose**: Windows Task Scheduler CRUD wrapper.

**Key logic**:

- Duplicate detection (full path + time + status).
- Network/UNC path handling with different RunLevel.
- Robust task status syncing with error tolerance.

### 2.4 src/DailyMotivation.ps1 (549 lines)

**Purpose**: Popup engine — fired by Task Scheduler via `LaunchMotivation.bat`.

**Critical issues**:

- Path resolution for Modules (PS2EXE breakage).
- Silent module import failures on Snooze/Dismiss.
- Mutex protection and debug logging.

### 2.5 src/LaunchMotivation.bat (59 lines)

**Purpose**: Robust batch wrapper for PowerShell invocation.

- Uses `%~dp0` for reliable directory detection.
- Smart PowerShell.exe discovery.
- Correct flags for WPF (`-STA`).

### 2.6 src/UpdateScheduledTask.ps1 (97 lines)

One-time admin setup script that copies files and registers placeholder task.

### 2.7 src/MainWindow.xaml (296 lines)

WPF UI markup with styles, templates for recent folders, tasks, and history.

### 2.8 src/ShellExtension/ (Out of Scope)

Shell extension for right-click context menu — currently not in scope.

---

## BUG CATALOG (Exact Line References)

| ID         | Severity | File:Line               | Description                             | Fixed? |
| ---------- | -------- | ----------------------- | --------------------------------------- | ------ |
| PS2EXE-01  | CRITICAL | MainApp.ps1:36–41       | $scriptDir fallback broken under PS2EXE | No     |
| PS2EXE-02  | CRITICAL | DailyMotivation.ps1:85  | ModulesPath resolution fails in PS2EXE  | No     |
| PS2EXE-03  | CRITICAL | TaskScheduler.psm1:10   | LauncherPath resolution fails           | No     |
| BUILD-01   | CRITICAL | .build.ps1:179–193      | Wrong copy destination for dependencies | No     |
| BUILD-02   | HIGH     | build.ps1:40            | Unnecessary UAC on every launch         | No     |
| RUNTIME-01 | HIGH     | DailyMotivation.ps1:430 | Silent failure on Snooze                | No     |
| RUNTIME-02 | HIGH     | DailyMotivation.ps1:448 | Silent failure on Dismiss               | No     |
