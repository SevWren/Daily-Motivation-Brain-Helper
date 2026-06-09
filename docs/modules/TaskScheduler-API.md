# TaskScheduler API Documentation

## Module Overview

**Module Name:** TaskScheduler.psm1
**Location:** `/src/Modules/TaskScheduler.psm1`
**Purpose:** Wrapper around Windows Task Scheduler for Daily Motivation Brain Helper. Manages scheduled task creation, retrieval, updates, and deletion with persistent storage in `tasks.json`.

This module handles:
- Creating Windows Scheduled Tasks with one-time triggers
- Persisting task metadata to `tasks.json`
- Retrieving and synchronizing tasks between Windows scheduler and JSON storage
- Detecting and handling network/UNC paths with elevated privileges
- Duplicate task detection (same folder + same day)
- Status updates (PENDING, COMPLETED, DISMISSED, DELETED, SNOOZED)

**Key Design Patterns:**
- All task operations are atomic (scheduler + JSON updated together)
- Task names prefixed with `DailyMotivation_` for easy identification
- Automatic status sync: PENDING tasks deleted from scheduler are marked DELETED
- Network path detection triggers elevated task registration (GAP-010)
- Defensive GUID collision handling (GAP-007)

---

## Task Lifecycle

```
┌─────────────┐
│   PENDING   │  ← Task created and scheduled
└──────┬──────┘
       │
       ├─→ Fires → Popup shown → User action
       │
       ├─→ [Opened] → COMPLETED
       ├─→ [Snoozed] → SNOOZED (reschedules)
       ├─→ [Dismissed] → DISMISSED
       └─→ [Deleted manually] → DELETED
```

---

## Script-Level Variables

| Variable | Purpose |
|----------|---------|
| `$script:TaskPrefix` | `"DailyMotivation_"` - prefix for all scheduled task names |
| `$script:LauncherPath` | Path to `LaunchMotivation.bat` (resolved from module install location) |

---

## Internal Functions

### Get-TasksJson

Loads and parses `tasks.json` from `%APPDATA%\DailyMotivationBrainHelper\`.

**Synopsis:**
```powershell
Get-TasksJson
```

**Parameters:** None

**Return Type:** `[array]` of task objects (empty array if file missing or invalid)

**Behavior:**
- Returns clean empty array if file doesn't exist
- Handles PowerShell 5.1 quirk where `ConvertFrom-Json` on `"[]"` returns `$null` (FIX-003)

**Error Conditions:**
- Parse errors return empty array
- Never throws exceptions

---

### Save-TasksJson

Persists task array to `tasks.json`.

**Synopsis:**
```powershell
Save-TasksJson -Tasks <object[]>
```

**Parameters:**
- **Tasks** (object[], mandatory): Array of task objects to save

**Return Type:** None (void)

**Behavior:**
- Handles `$null` and empty arrays by writing `"[]"` (FIX-003)
- Uses `-Depth 4` to preserve nested properties

**Error Conditions:**
- File write failure propagates to caller

---

## Public Functions

### New-MotivationTask

Creates a new Windows Scheduled Task and records it in `tasks.json`.

**Synopsis:**
```powershell
New-MotivationTask -FolderPath <string> -TriggerTime <datetime> [-Force]
```

**Parameters:**
- **FolderPath** (string, mandatory): Absolute Windows path to the folder to open
- **TriggerTime** (datetime, mandatory): DateTime when the popup should fire (caller decides today vs. tomorrow)
- **Force** (switch, optional): If set, skips duplicate check and creates regardless

**Return Type:** `[hashtable]` with keys:
- **Success** (bool): `$true` if task created, `$false` if duplicate or error
- **TaskId** (string): 16-character hex task identifier (null on failure)
- **IsDuplicate** (bool): `$true` if rejected due to duplicate
- **IsNetworkPath** (bool): `$true` if path is UNC or mapped network drive
- **Error** (string): Error message if registration failed

**Behavior:**
1. **Duplicate check (B-16):** Rejects if a PENDING task already exists for same folder path (case-insensitive, full path normalized) on same date, unless `-Force` is specified
2. **GUID generation (GAP-007):** Creates 16-character hex task ID from GUID, retries up to 5 times on collision
3. **Network path detection (GAP-010):** Detects UNC paths (`\\server\share`) and mapped network drives, registers task with `RunLevel Highest` for better access
4. **Scheduler registration:** Creates scheduled task with:
   - Action: `cmd.exe /c LaunchMotivation.bat`
   - Trigger: One-time at `TriggerTime`
   - Settings: `StartWhenAvailable` (run at next logon if missed, NPR-004), 10-minute timeout, ignore if already running
   - Principal: Interactive logon, elevated for network paths
5. **JSON persistence:** Adds task to `tasks.json` with initial status `PENDING`

**Usage Example:**
```powershell
$tomorrow9am = (Get-Date).AddDays(1).Date.AddHours(9)
$result = New-MotivationTask `
    -FolderPath "C:\Users\John\Documents\ProjectX" `
    -TriggerTime $tomorrow9am

if ($result.Success) {
    Write-Host "Task created: $($result.TaskId)"
    if ($result.IsNetworkPath) {
        Write-Host "Network path detected - task will run elevated"
    }
}
elseif ($result.IsDuplicate) {
    Write-Host "Task already exists for this folder today"
}
else {
    Write-Host "Error: $($result.Error)"
}
```

**Error Conditions:**
- **Duplicate:** Returns `Success=$false, IsDuplicate=$true` if duplicate detected (unless `-Force`)
- **Registration failure:** Returns `Success=$false, Error=<message>` if Windows scheduler registration fails
- **GUID collision:** Retries up to 5 times, then proceeds (collision is near-impossible)

**Task JSON Structure:**
```json
{
  "task_id": "abc123def4567890",
  "task_name": "DailyMotivation_abc123def4567890",
  "folder_path": "C:\\Users\\John\\Documents\\ProjectX",
  "folder_name": "ProjectX",
  "scheduled_time": "2026-06-10T09:00:00",
  "created_at": "2026-06-09T14:30:00.123Z",
  "status": "PENDING",
  "snooze_count": 0,
  "snooze_duration_minutes": 5
}
```

**Notes:**
- **Network paths (GAP-010):**
  - UNC paths: `\\server\share\folder`
  - Mapped drives: Detected via `DriveInfo.DriveType == Network`
  - Tasks for network paths run with `RunLevel Highest` (user's highest privilege, no UAC prompt on standard accounts)
- **LauncherPath:** Resolved from module install location, NOT `%APPDATA%` (the `.bat` lives beside scripts)
- **Duplicate detection:** Case-insensitive, compares normalized full paths

---

### Get-MotivationTasks

Returns all tasks from `tasks.json`, cross-checked against Windows Task Scheduler. Tasks no longer present in the scheduler are marked DELETED.

**Synopsis:**
```powershell
Get-MotivationTasks
```

**Parameters:** None

**Return Type:** `[array]` of `[PSCustomObject]` task objects with properties:
- **task_id** (string): 16-character hex identifier
- **task_name** (string): Windows Task Scheduler name
- **folder_path** (string): Absolute folder path
- **folder_name** (string): Display name
- **scheduled_time** (string): ISO 8601 timestamp
- **created_at** (string): ISO 8601 timestamp
- **status** (string): PENDING, COMPLETED, DISMISSED, DELETED, SNOOZED
- **snooze_count** (int): Number of times snoozed
- **snooze_duration_minutes** (int): Duration of last snooze

**Behavior:**
1. Loads tasks from `tasks.json`
2. For each PENDING task:
   - Queries Windows Task Scheduler
   - If task not found: marks status as DELETED (ERR-008)
   - If access denied: skips status update (task exists but unreadable)
   - If other error: logs warning and skips
3. Saves updated `tasks.json` if any status changed

**Usage Example:**
```powershell
$tasks = Get-MotivationTasks

# Show pending tasks
$pending = $tasks | Where-Object { $_.status -eq "PENDING" }
foreach ($task in $pending) {
    Write-Host "$($task.folder_name) - $($task.scheduled_time)"
}

# Show deleted tasks
$deleted = $tasks | Where-Object { $_.status -eq "DELETED" }
Write-Host "Found $($deleted.Count) deleted tasks"
```

**Error Conditions:**
- **Access denied (ERR-008):** Logs warning, does NOT mark task as DELETED (task exists but unreadable)
- **Unknown errors:** Logs warning, skips status update
- Never throws exceptions

**Notes:**
- Automatically synchronizes JSON state with Windows Task Scheduler
- Skips null or malformed entries in `tasks.json`
- Status updates are persisted immediately to disk

---

### Remove-MotivationTask

Deletes a scheduled task by `task_id` from both Windows Task Scheduler and `tasks.json`.

**Synopsis:**
```powershell
Remove-MotivationTask -TaskId <string>
```

**Parameters:**
- **TaskId** (string, mandatory): 16-character hex task identifier

**Return Type:** `[bool]` - `$true` if task found and removed, `$false` if task ID not found

**Behavior:**
1. Looks up task by `task_id` in `tasks.json`
2. Calls `Unregister-ScheduledTask` (logs warning if fails but continues - BUG-009)
3. Removes task from `tasks.json` array
4. Saves updated `tasks.json`

**Usage Example:**
```powershell
$taskId = "abc123def4567890"
if (Remove-MotivationTask -TaskId $taskId) {
    Write-Host "Task deleted successfully"
}
else {
    Write-Host "Task not found"
}
```

**Error Conditions:**
- **Task not found in JSON:** Returns `$false`
- **Scheduler unregister fails (BUG-009):** Logs warning but continues (task may already be fired/deleted, JSON is still cleaned up)

**Notes:**
- Removes from both scheduler and JSON to prevent orphaned entries
- If scheduler task is already gone (fired or manually deleted), cleanup still succeeds

---

### Get-MotivationTaskStatus

Retrieves the current status of a task by `task_id`.

**Synopsis:**
```powershell
Get-MotivationTaskStatus -TaskId <string>
```

**Parameters:**
- **TaskId** (string, mandatory): 16-character hex task identifier

**Return Type:** `[string]` - Task status (PENDING, COMPLETED, DISMISSED, DELETED, SNOOZED) or `$null` if not found

**Usage Example:**
```powershell
$status = Get-MotivationTaskStatus -TaskId "abc123def4567890"
if ($status -eq "PENDING") {
    Write-Host "Task is still scheduled"
}
```

**Error Conditions:**
- Returns `$null` if task ID not found
- Never throws exceptions

---

### Update-MotivationTaskStatus

Updates the status and optional snooze properties of a task.

**Synopsis:**
```powershell
Update-MotivationTaskStatus -TaskId <string> -Status <string> [-SnoozeCount <int>] [-SnoozeDurationMinutes <int>]
```

**Parameters:**
- **TaskId** (string, mandatory): 16-character hex task identifier
- **Status** (string, mandatory): New status (PENDING, COMPLETED, DISMISSED, DELETED, SNOOZED)
- **SnoozeCount** (int, optional): New snooze count (only updates if >= 0, default: -1)
- **SnoozeDurationMinutes** (int, optional): New snooze duration (only updates if >= 0, default: -1)

**Return Type:** None (void)

**Behavior:**
1. Loads `tasks.json`
2. Finds task by `task_id`
3. Updates status and optional snooze properties
4. Saves updated `tasks.json`

**Usage Example:**
```powershell
# Mark task as completed
Update-MotivationTaskStatus -TaskId "abc123def4567890" -Status "COMPLETED"

# Mark as snoozed with updated count and duration
Update-MotivationTaskStatus `
    -TaskId "abc123def4567890" `
    -Status "SNOOZED" `
    -SnoozeCount 3 `
    -SnoozeDurationMinutes 10
```

**Error Conditions:**
- Silently succeeds if task ID not found (no-op)
- File write failure propagates to caller

**Notes:**
- Does NOT update Windows Task Scheduler (caller must reschedule separately if needed)
- Snooze properties only updated if >= 0 (allows partial updates)

---

## Task Statuses

| Status | Meaning |
|--------|---------|
| **PENDING** | Task is scheduled and waiting to fire |
| **COMPLETED** | User opened the folder from the popup |
| **DISMISSED** | User dismissed the popup without opening |
| **SNOOZED** | User snoozed the popup (task rescheduled) |
| **DELETED** | Task was removed (manually or detected as missing from scheduler) |

---

## Network Path Handling (GAP-010)

The module detects network paths and registers tasks with elevated privileges for better access:

**UNC Path Detection:**
```powershell
$isUncPath = $FolderPath -match '^\\\\[^\\]'
```
- Matches paths starting with `\\` followed by server name
- Examples: `\\server\share\folder`, `\\192.168.1.10\data`

**Mapped Drive Detection:**
```powershell
$driveInfo = [System.IO.DriveInfo]::new([string]$FolderPath[0])
$isMappedDrive = $driveInfo.DriveType -eq [System.IO.DriveType]::Network
```
- Checks if drive letter (e.g., `Z:`) is mapped to network location
- Examples: `Z:\Projects`, `Y:\Shared`

**Elevated Registration:**
- Network paths register with `RunLevel Highest`
- On standard accounts: runs with user's highest privilege (no UAC prompt)
- On admin accounts: runs elevated
- Improves likelihood of successful access at task fire time

---

## Duplicate Detection Logic (B-16)

Prevents scheduling multiple tasks for the same folder on the same day:

**Comparison Rules:**
1. **Path normalization:** Uses `[System.IO.Path]::GetFullPath()` to resolve relative paths, `..`, etc.
2. **Case-insensitive:** Converts to lowercase via `.ToLowerInvariant()`
3. **Date comparison:** Compares `.Date` property (ignores time)
4. **Status check:** Only considers PENDING tasks (completed/dismissed don't block)

**Example:**
```powershell
# These are considered duplicates (same folder, same day):
New-MotivationTask -FolderPath "C:\Projects\MyApp" -TriggerTime "2026-06-10 09:00"
New-MotivationTask -FolderPath "c:\projects\myapp" -TriggerTime "2026-06-10 14:00"

# These are NOT duplicates (different days):
New-MotivationTask -FolderPath "C:\Projects\MyApp" -TriggerTime "2026-06-10 09:00"
New-MotivationTask -FolderPath "C:\Projects\MyApp" -TriggerTime "2026-06-11 09:00"
```

**Override:**
```powershell
# Force creation even if duplicate exists
New-MotivationTask -FolderPath "C:\Projects\MyApp" -TriggerTime "2026-06-10 14:00" -Force
```

---

## Task Scheduler Settings

Tasks are registered with these settings:

| Setting | Value | Purpose |
|---------|-------|---------|
| **Trigger** | Once at specified time | One-time popup |
| **Action** | `cmd.exe /c LaunchMotivation.bat` | Launches popup script |
| **StartWhenAvailable** | Enabled | Run at next logon if missed (NPR-004) |
| **ExecutionTimeLimit** | 10 minutes | Prevent hung tasks |
| **MultipleInstances** | IgnoreNew | Don't stack popups |
| **LogonType** | Interactive | Run in user session |
| **RunLevel** | Limited (local) or Highest (network) | Privilege level |

---

## Dependencies

- **PowerShell Version:** 5.1+
- **Windows Task Scheduler:** `ScheduledTasks` module (built-in on Windows 10/11, Server 2016+)
- **ConfigManager.psm1:** Uses `tasks.json` path from `$env:APPDATA\DailyMotivationBrainHelper\`
- **LaunchMotivation.bat:** Must exist in parent directory of module location

---

## Related Modules

- **ConfigManager.psm1:** Manages `tasks.json` file
- **Popup.ps1:** Calls `Get-MotivationTaskStatus`, `Update-MotivationTaskStatus`
- **MainWindow.ps1:** Calls `New-MotivationTask`, `Get-MotivationTasks`, `Remove-MotivationTask`

---

## Change History

| Reference | Description |
|-----------|-------------|
| B-16 | Duplicate detection for same folder + same day |
| GAP-006 | Case-insensitive path normalization |
| GAP-007 | GUID collision retry mechanism |
| FIX-003 | Handle PowerShell 5.1 `ConvertFrom-Json` null quirk |
| NPR-004 | StartWhenAvailable setting for missed tasks |
| GAP-010 | Network path detection and elevated task registration |
| ERR-008 | Handle access denied separately from not found |
| BUG-009 | Log but continue if Unregister-ScheduledTask fails |

---

## Testing Recommendations

1. **Duplicate detection:** Create two tasks for same folder/same day, verify second is rejected unless `-Force`
2. **Network paths:**
   - Test UNC path: `\\server\share\folder`
   - Test mapped drive: Create `Z:` mapping and schedule task
   - Verify `RunLevel Highest` in Task Scheduler GUI
3. **Status sync:** Manually delete task from Task Scheduler, call `Get-MotivationTasks`, verify status changes to DELETED
4. **StartWhenAvailable:** Set task in past, reboot, verify task runs at next logon
5. **Snooze updates:** Call `Update-MotivationTaskStatus` with partial updates, verify only specified fields change
6. **Launcher path:** Move module to different location, verify `$script:LauncherPath` resolves correctly
